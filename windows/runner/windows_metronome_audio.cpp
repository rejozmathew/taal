#include "windows_metronome_audio.h"

#include <avrt.h>
#include <flutter/standard_method_codec.h>
#include <ksmedia.h>
#include <mmreg.h>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <iomanip>
#include <limits>
#include <sstream>
#include <variant>

namespace {

constexpr char kChannelName[] = "taal/metronome_audio";
constexpr REFERENCE_TIME kRequestedBufferDuration = 50'000;  // 5ms in 100ns units.
constexpr double kPi = 3.14159265358979323846;

std::string HResultToString(HRESULT hr) {
  std::ostringstream message;
  message << "HRESULT 0x" << std::hex << std::setw(8) << std::setfill('0')
          << static_cast<unsigned long>(hr);
  return message.str();
}

const flutter::EncodableValue* MapValue(const flutter::EncodableMap& map,
                                        const char* key) {
  const auto found = map.find(flutter::EncodableValue(key));
  if (found == map.end()) {
    return nullptr;
  }
  return &found->second;
}

bool ValueToInt64(const flutter::EncodableValue& value, int64_t* output) {
  if (const auto* int32_value = std::get_if<int32_t>(&value)) {
    *output = *int32_value;
    return true;
  }
  if (const auto* int64_value = std::get_if<int64_t>(&value)) {
    *output = *int64_value;
    return true;
  }
  return false;
}

bool ValueToDouble(const flutter::EncodableValue& value, double* output) {
  if (const auto* double_value = std::get_if<double>(&value)) {
    *output = *double_value;
    return true;
  }
  if (const auto* int32_value = std::get_if<int32_t>(&value)) {
    *output = static_cast<double>(*int32_value);
    return true;
  }
  if (const auto* int64_value = std::get_if<int64_t>(&value)) {
    *output = static_cast<double>(*int64_value);
    return true;
  }
  return false;
}

bool ValueToString(const flutter::EncodableValue& value, std::string* output) {
  if (const auto* string_value = std::get_if<std::string>(&value)) {
    *output = *string_value;
    return true;
  }
  return false;
}

bool IsSupportedPreset(const std::string& preset) {
  return preset == "classic" || preset == "woodblock" || preset == "hihat";
}

float NoiseAt(uint64_t seed) {
  uint32_t value = static_cast<uint32_t>(seed * 1103515245ULL + 12345ULL);
  value ^= value << 13;
  value ^= value >> 17;
  value ^= value << 5;
  return (static_cast<float>(value & 0xffff) / 32768.0f) - 1.0f;
}

}  // namespace

WindowsMetronomeAudio::WindowsMetronomeAudio(
    flutter::BinaryMessenger* messenger) {
  QueryPerformanceFrequency(&qpc_frequency_);
  RegisterMethodChannel(messenger);
  RenderSamplesForPreset(preset_);
}

WindowsMetronomeAudio::~WindowsMetronomeAudio() {
  Stop();
  ShutdownStream();
}

void WindowsMetronomeAudio::RegisterMethodChannel(
    flutter::BinaryMessenger* messenger) {
  method_channel_ = std::make_unique<flutter::MethodChannel<>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());

  method_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        const auto* arguments = call.arguments();
        const auto* map =
            arguments ? std::get_if<flutter::EncodableMap>(arguments) : nullptr;

        if (call.method_name() == "configure") {
          if (!map) {
            result->Error("invalid_argument",
                          "configure expects a map argument.");
            return;
          }
          const std::string error = Configure(*map);
          if (!error.empty()) {
            result->Error("audio_configure_failed", error);
            return;
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (call.method_name() == "scheduleClicks") {
          if (!map) {
            result->Error("invalid_argument",
                          "scheduleClicks expects a map argument.");
            return;
          }
          const std::string error = ScheduleClicks(*map);
          if (!error.empty()) {
            result->Error("audio_schedule_failed", error);
            return;
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (call.method_name() == "scheduleDrumHits") {
          if (!map) {
            result->Error("invalid_argument",
                          "scheduleDrumHits expects a map argument.");
            return;
          }
          const std::string error = ScheduleDrumHits(*map);
          if (!error.empty()) {
            result->Error("audio_schedule_failed", error);
            return;
          }
          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (call.method_name() == "stop") {
          Stop();
          result->Success();
          return;
        }

        result->NotImplemented();
      });
}

std::string WindowsMetronomeAudio::Configure(
    const flutter::EncodableMap& arguments) {
  const auto* volume_value = MapValue(arguments, "volume");
  const auto* preset_value = MapValue(arguments, "preset");
  double volume = 0.0;
  std::string preset;
  if (!volume_value || !ValueToDouble(*volume_value, &volume) || volume < 0.0 ||
      volume > 1.0) {
    return "configure.volume must be a number between 0 and 1.";
  }
  if (!preset_value || !ValueToString(*preset_value, &preset) ||
      !IsSupportedPreset(preset)) {
    return "configure.preset must be classic, woodblock, or hihat.";
  }

  {
    std::lock_guard<std::mutex> lock(state_mutex_);
    volume_ = static_cast<float>(volume);
    preset_ = preset;
    RenderSamplesForPreset(preset_);
  }

  return EnsureStream();
}

std::string WindowsMetronomeAudio::ScheduleClicks(
    const flutter::EncodableMap& arguments) {
  const std::string stream_error = EnsureStream();
  if (!stream_error.empty()) {
    return stream_error;
  }

  const auto* start_value = MapValue(arguments, "session_start_time_ns");
  int64_t session_start_time_ns = 0;
  if (!start_value || !ValueToInt64(*start_value, &session_start_time_ns)) {
    return "scheduleClicks.session_start_time_ns must be an integer.";
  }

  const auto* clicks_value = MapValue(arguments, "clicks");
  const auto* clicks = clicks_value
                           ? std::get_if<flutter::EncodableList>(clicks_value)
                           : nullptr;
  if (!clicks) {
    return "scheduleClicks.clicks must be a list.";
  }

  std::vector<ScheduledClick> parsed_clicks;
  parsed_clicks.reserve(clicks->size());
  for (const auto& click_value : *clicks) {
    const auto* click = std::get_if<flutter::EncodableMap>(&click_value);
    if (!click) {
      return "Each scheduled click must be a map.";
    }

    const auto* t_ms_value = MapValue(*click, "t_ms");
    int64_t t_ms = 0;
    if (!t_ms_value || !ValueToInt64(*t_ms_value, &t_ms) || t_ms < 0) {
      return "Each scheduled click needs a non-negative t_ms.";
    }

    const auto* accent_value = MapValue(*click, "accent");
    const auto* accent = accent_value ? std::get_if<bool>(accent_value) : nullptr;
    if (!accent) {
      return "Each scheduled click needs a boolean accent.";
    }

    if (t_ms > std::numeric_limits<int64_t>::max() / 1'000'000) {
      return "Scheduled click timestamp overflows int64 nanoseconds.";
    }
    const int64_t click_offset_ns = t_ms * 1'000'000;
    if (session_start_time_ns >
        std::numeric_limits<int64_t>::max() - click_offset_ns) {
      return "Scheduled click timestamp overflows int64 nanoseconds.";
    }
    const int64_t target_ns = session_start_time_ns + click_offset_ns;
    parsed_clicks.push_back(ScheduledClick{
        FrameForTimestampNs(target_ns),
        *accent,
    });
  }

  std::lock_guard<std::mutex> lock(state_mutex_);
  scheduled_clicks_.insert(scheduled_clicks_.end(), parsed_clicks.begin(),
                           parsed_clicks.end());
  std::sort(scheduled_clicks_.begin(), scheduled_clicks_.end(),
            [](const ScheduledClick& left, const ScheduledClick& right) {
              return left.target_frame < right.target_frame;
            });
  return "";
}

std::string WindowsMetronomeAudio::ScheduleDrumHits(
    const flutter::EncodableMap& arguments) {
  const std::string stream_error = EnsureStream();
  if (!stream_error.empty()) {
    return stream_error;
  }

  const auto* start_value = MapValue(arguments, "session_start_time_ns");
  int64_t session_start_time_ns = 0;
  if (!start_value || !ValueToInt64(*start_value, &session_start_time_ns)) {
    return "scheduleDrumHits.session_start_time_ns must be an integer.";
  }

  const auto* hits_value = MapValue(arguments, "hits");
  const auto* hits =
      hits_value ? std::get_if<flutter::EncodableList>(hits_value) : nullptr;
  if (!hits) {
    return "scheduleDrumHits.hits must be a list.";
  }

  std::vector<ScheduledDrumHit> parsed_hits;
  parsed_hits.reserve(hits->size());
  for (const auto& hit_value : *hits) {
    const auto* hit = std::get_if<flutter::EncodableMap>(&hit_value);
    if (!hit) {
      return "Each scheduled drum hit must be a map.";
    }

    const auto* t_ms_value = MapValue(*hit, "t_ms");
    int64_t t_ms = 0;
    if (!t_ms_value || !ValueToInt64(*t_ms_value, &t_ms) || t_ms < 0) {
      return "Each scheduled drum hit needs a non-negative t_ms.";
    }

    std::string lane_id;
    const auto* lane_value = MapValue(*hit, "lane_id");
    if (!lane_value || !ValueToString(*lane_value, &lane_id) ||
        lane_id.empty()) {
      return "Each scheduled drum hit needs a lane_id.";
    }

    int64_t velocity = 0;
    const auto* velocity_value = MapValue(*hit, "velocity");
    if (!velocity_value || !ValueToInt64(*velocity_value, &velocity) ||
        velocity < 1 || velocity > 127) {
      return "Each scheduled drum hit needs velocity in 1..127.";
    }

    std::string articulation = "normal";
    if (const auto* articulation_value = MapValue(*hit, "articulation")) {
      if (!ValueToString(*articulation_value, &articulation) ||
          articulation.empty()) {
        return "Scheduled drum hit articulation must be a non-empty string.";
      }
    }

    if (t_ms > std::numeric_limits<int64_t>::max() / 1'000'000) {
      return "Scheduled drum hit timestamp overflows int64 nanoseconds.";
    }
    const int64_t hit_offset_ns = t_ms * 1'000'000;
    if (session_start_time_ns >
        std::numeric_limits<int64_t>::max() - hit_offset_ns) {
      return "Scheduled drum hit timestamp overflows int64 nanoseconds.";
    }
    const int64_t target_ns = session_start_time_ns + hit_offset_ns;
    parsed_hits.push_back(ScheduledDrumHit{
        FrameForTimestampNs(target_ns),
        lane_id,
        articulation,
        static_cast<uint8_t>(velocity),
    });
  }

  std::lock_guard<std::mutex> lock(state_mutex_);
  scheduled_drum_hits_.insert(scheduled_drum_hits_.end(), parsed_hits.begin(),
                              parsed_hits.end());
  std::sort(scheduled_drum_hits_.begin(), scheduled_drum_hits_.end(),
            [](const ScheduledDrumHit& left, const ScheduledDrumHit& right) {
              return left.target_frame < right.target_frame;
            });
  return "";
}

void WindowsMetronomeAudio::Stop() {
  std::lock_guard<std::mutex> lock(state_mutex_);
  scheduled_clicks_.clear();
  scheduled_drum_hits_.clear();
}

std::string WindowsMetronomeAudio::EnsureStream() {
  if (running_.load()) {
    return "";
  }
  return InitializeStream();
}

std::string WindowsMetronomeAudio::InitializeStream() {
  HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
    return "CoInitializeEx failed: " + HResultToString(hr);
  }

  Microsoft::WRL::ComPtr<IMMDeviceEnumerator> enumerator;
  hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                        IID_PPV_ARGS(&enumerator));
  if (FAILED(hr)) {
    return "Unable to create WASAPI device enumerator: " + HResultToString(hr);
  }

  Microsoft::WRL::ComPtr<IMMDevice> device;
  hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
  if (FAILED(hr)) {
    return "Unable to open default render endpoint: " + HResultToString(hr);
  }

  hr = device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                        reinterpret_cast<void**>(audio_client_.GetAddressOf()));
  if (FAILED(hr)) {
    audio_client_.Reset();
    return "Unable to activate WASAPI audio client: " + HResultToString(hr);
  }

  WAVEFORMATEX* mix_format = nullptr;
  hr = audio_client_->GetMixFormat(&mix_format);
  if (FAILED(hr) || mix_format == nullptr) {
    audio_client_.Reset();
    return "Unable to read WASAPI mix format: " + HResultToString(hr);
  }

  sample_rate_ = mix_format->nSamplesPerSec;
  channels_ = mix_format->nChannels;
  bytes_per_sample_ = mix_format->wBitsPerSample / 8;
  bool supported_format = false;
  if (mix_format->wFormatTag == WAVE_FORMAT_IEEE_FLOAT &&
      mix_format->wBitsPerSample == 32) {
    sample_format_ = SampleFormat::Float32;
    supported_format = true;
  } else if (mix_format->wFormatTag == WAVE_FORMAT_PCM &&
             mix_format->wBitsPerSample == 16) {
    sample_format_ = SampleFormat::Int16;
    supported_format = true;
  } else if (mix_format->wFormatTag == WAVE_FORMAT_EXTENSIBLE) {
    const auto* extensible =
        reinterpret_cast<const WAVEFORMATEXTENSIBLE*>(mix_format);
    if (extensible->SubFormat == KSDATAFORMAT_SUBTYPE_IEEE_FLOAT &&
        mix_format->wBitsPerSample == 32) {
      sample_format_ = SampleFormat::Float32;
      supported_format = true;
    } else if (extensible->SubFormat == KSDATAFORMAT_SUBTYPE_PCM &&
               mix_format->wBitsPerSample == 16) {
      sample_format_ = SampleFormat::Int16;
      supported_format = true;
    }
  }

  if (!supported_format || channels_ == 0) {
    CoTaskMemFree(mix_format);
    audio_client_.Reset();
    return "Default WASAPI endpoint format is not 32-bit float or 16-bit PCM.";
  }

  REFERENCE_TIME default_period = 0;
  REFERENCE_TIME minimum_period = 0;
  hr = audio_client_->GetDevicePeriod(&default_period, &minimum_period);
  if (FAILED(hr)) {
    CoTaskMemFree(mix_format);
    audio_client_.Reset();
    return "Unable to read WASAPI device period: " + HResultToString(hr);
  }
  const REFERENCE_TIME buffer_duration =
      std::max(kRequestedBufferDuration, minimum_period);

  hr = audio_client_->Initialize(
      AUDCLNT_SHAREMODE_EXCLUSIVE, AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
      buffer_duration, buffer_duration, mix_format, nullptr);
  CoTaskMemFree(mix_format);
  if (FAILED(hr)) {
    audio_client_.Reset();
    return "Unable to initialize WASAPI exclusive event stream: " +
           HResultToString(hr);
  }

  render_event_ = CreateEvent(nullptr, FALSE, FALSE, nullptr);
  if (render_event_ == nullptr) {
    audio_client_.Reset();
    return "Unable to create WASAPI render event.";
  }

  hr = audio_client_->SetEventHandle(render_event_);
  if (FAILED(hr)) {
    ShutdownStream();
    return "Unable to attach WASAPI render event: " + HResultToString(hr);
  }

  hr = audio_client_->GetBufferSize(&buffer_frame_count_);
  if (FAILED(hr)) {
    ShutdownStream();
    return "Unable to read WASAPI buffer size: " + HResultToString(hr);
  }

  hr = audio_client_->GetService(IID_PPV_ARGS(&render_client_));
  if (FAILED(hr)) {
    ShutdownStream();
    return "Unable to obtain WASAPI render client: " + HResultToString(hr);
  }

  {
    std::lock_guard<std::mutex> lock(state_mutex_);
    RenderSamplesForPreset(preset_);
    scheduled_clicks_.clear();
    scheduled_drum_hits_.clear();
  }
  rendered_frames_.store(0);

  BYTE* buffer = nullptr;
  hr = render_client_->GetBuffer(buffer_frame_count_, &buffer);
  if (SUCCEEDED(hr)) {
    std::memset(buffer, 0,
                buffer_frame_count_ * channels_ * bytes_per_sample_);
    render_client_->ReleaseBuffer(buffer_frame_count_, 0);
  }

  running_.store(true);
  hr = audio_client_->Start();
  if (FAILED(hr)) {
    running_.store(false);
    ShutdownStream();
    return "Unable to start WASAPI stream: " + HResultToString(hr);
  }

  render_thread_ = std::thread(&WindowsMetronomeAudio::RenderLoop, this);
  return "";
}

void WindowsMetronomeAudio::ShutdownStream() {
  running_.store(false);
  if (render_event_ != nullptr) {
    SetEvent(render_event_);
  }
  if (render_thread_.joinable()) {
    render_thread_.join();
  }
  if (audio_client_) {
    audio_client_->Stop();
  }
  render_client_.Reset();
  audio_client_.Reset();
  buffer_frame_count_ = 0;
  rendered_frames_.store(0);
  if (render_event_ != nullptr) {
    CloseHandle(render_event_);
    render_event_ = nullptr;
  }
}

void WindowsMetronomeAudio::RenderLoop() {
  DWORD task_index = 0;
  HANDLE avrt_handle =
      AvSetMmThreadCharacteristicsW(L"Pro Audio", &task_index);

  while (running_.load()) {
    const DWORD wait_result = WaitForSingleObject(render_event_, 2000);
    if (!running_.load()) {
      break;
    }
    if (wait_result != WAIT_OBJECT_0) {
      continue;
    }

    uint32_t padding = 0;
    if (FAILED(audio_client_->GetCurrentPadding(&padding))) {
      continue;
    }
    if (padding >= buffer_frame_count_) {
      continue;
    }
    const uint32_t frames_available = buffer_frame_count_ - padding;
    if (frames_available > 0) {
      RenderBuffer(frames_available);
    }
  }

  if (avrt_handle != nullptr) {
    AvRevertMmThreadCharacteristics(avrt_handle);
  }
}

bool WindowsMetronomeAudio::RenderBuffer(uint32_t frame_count) {
  BYTE* buffer = nullptr;
  HRESULT hr = render_client_->GetBuffer(frame_count, &buffer);
  if (FAILED(hr)) {
    return false;
  }

  MixClickBuffer(buffer, frame_count);
  hr = render_client_->ReleaseBuffer(frame_count, 0);
  return SUCCEEDED(hr);
}

void WindowsMetronomeAudio::MixClickBuffer(uint8_t* buffer,
                                           uint32_t frame_count) {
  std::memset(buffer, 0, frame_count * channels_ * bytes_per_sample_);

  const uint64_t start_frame = rendered_frames_.load();
  {
    std::lock_guard<std::mutex> lock(state_mutex_);
    const size_t sample_length =
        std::max(accent_sample_.size(), normal_sample_.size());
    scheduled_clicks_.erase(
        std::remove_if(scheduled_clicks_.begin(), scheduled_clicks_.end(),
                       [start_frame, sample_length](const ScheduledClick& click) {
                         return click.target_frame + sample_length <= start_frame;
                       }),
        scheduled_clicks_.end());
    scheduled_drum_hits_.erase(
        std::remove_if(scheduled_drum_hits_.begin(),
                       scheduled_drum_hits_.end(),
                       [this, start_frame](const ScheduledDrumHit& hit) {
                         return hit.target_frame + DrumSampleLengthFrames(hit) <=
                                start_frame;
                       }),
        scheduled_drum_hits_.end());

    for (uint32_t frame_offset = 0; frame_offset < frame_count; ++frame_offset) {
      const uint64_t frame = start_frame + frame_offset;
      float sample = 0.0f;
      for (const auto& click : scheduled_clicks_) {
        sample += SampleAtFrame(click, frame);
      }
      for (const auto& hit : scheduled_drum_hits_) {
        sample += DrumSampleAtFrame(hit, frame);
      }
      sample = std::clamp(sample * volume_, -1.0f, 1.0f);

      for (uint16_t channel = 0; channel < channels_; ++channel) {
        const size_t index =
            static_cast<size_t>(frame_offset) * channels_ + channel;
        if (sample_format_ == SampleFormat::Float32) {
          reinterpret_cast<float*>(buffer)[index] = sample;
        } else {
          reinterpret_cast<int16_t*>(buffer)[index] =
              static_cast<int16_t>(sample * 32767.0f);
        }
      }
    }
  }

  rendered_frames_.fetch_add(frame_count);
}

int64_t WindowsMetronomeAudio::QueryPerformanceCounterNs() const {
  LARGE_INTEGER counter = {};
  QueryPerformanceCounter(&counter);
  const long double nanos =
      static_cast<long double>(counter.QuadPart) * 1000000000.0L /
      static_cast<long double>(qpc_frequency_.QuadPart);
  return static_cast<int64_t>(nanos);
}

uint64_t WindowsMetronomeAudio::FrameForTimestampNs(
    int64_t timestamp_ns) const {
  const int64_t now_ns = QueryPerformanceCounterNs();
  const uint64_t current_frame = rendered_frames_.load();
  if (timestamp_ns <= now_ns) {
    return current_frame;
  }

  const long double delta_ns =
      static_cast<long double>(timestamp_ns - now_ns);
  const long double delta_frames =
      delta_ns * static_cast<long double>(sample_rate_) / 1000000000.0L;
  return current_frame + static_cast<uint64_t>(delta_frames);
}

void WindowsMetronomeAudio::RenderSamplesForPreset(
    const std::string& preset) {
  const size_t sample_count = static_cast<size_t>(sample_rate_ * 0.06);
  accent_sample_.assign(sample_count, 0.0f);
  normal_sample_.assign(sample_count, 0.0f);

  for (size_t index = 0; index < sample_count; ++index) {
    const double t = static_cast<double>(index) / sample_rate_;
    const double fast_decay = std::exp(-t * 90.0);
    const double slow_decay = std::exp(-t * 55.0);

    if (preset == "woodblock") {
      normal_sample_[index] = static_cast<float>(
          0.55 * std::sin(2.0 * kPi * 760.0 * t) * fast_decay);
      accent_sample_[index] = static_cast<float>(
          (0.72 * std::sin(2.0 * kPi * 980.0 * t) +
           0.24 * std::sin(2.0 * kPi * 1560.0 * t)) *
          fast_decay);
    } else if (preset == "hihat") {
      const uint32_t noise =
          static_cast<uint32_t>(index * 1103515245u + 12345u);
      const double noise_sample =
          (static_cast<double>((noise >> 16) & 0x7fff) / 16384.0) - 1.0;
      normal_sample_[index] = static_cast<float>(0.36 * noise_sample * fast_decay);
      accent_sample_[index] = static_cast<float>(0.54 * noise_sample * slow_decay);
    } else {
      normal_sample_[index] = static_cast<float>(
          0.50 * std::sin(2.0 * kPi * 1200.0 * t) * fast_decay);
      accent_sample_[index] = static_cast<float>(
          (0.70 * std::sin(2.0 * kPi * 1800.0 * t) +
           0.25 * std::sin(2.0 * kPi * 900.0 * t)) *
          slow_decay);
    }
  }
}

float WindowsMetronomeAudio::SampleAtFrame(const ScheduledClick& click,
                                           uint64_t frame) const {
  if (frame < click.target_frame) {
    return 0.0f;
  }
  const uint64_t offset = frame - click.target_frame;
  const auto& sample = click.accent ? accent_sample_ : normal_sample_;
  if (offset >= sample.size()) {
    return 0.0f;
  }
  return sample[static_cast<size_t>(offset)];
}

uint64_t WindowsMetronomeAudio::DrumSampleLengthFrames(
    const ScheduledDrumHit& hit) const {
  double seconds = 0.18;
  if (hit.lane_id == "kick") {
    seconds = 0.24;
  } else if (hit.lane_id == "hihat" && hit.articulation == "open") {
    seconds = 0.30;
  } else if (hit.lane_id == "hihat") {
    seconds = 0.08;
  } else if (hit.lane_id == "ride" || hit.lane_id == "crash") {
    seconds = hit.lane_id == "crash" ? 0.42 : 0.30;
  }
  return static_cast<uint64_t>(sample_rate_ * seconds);
}

float WindowsMetronomeAudio::DrumSampleAtFrame(
    const ScheduledDrumHit& hit,
    uint64_t frame) const {
  if (frame < hit.target_frame) {
    return 0.0f;
  }

  const uint64_t offset = frame - hit.target_frame;
  if (offset >= DrumSampleLengthFrames(hit)) {
    return 0.0f;
  }

  const double t = static_cast<double>(offset) / sample_rate_;
  const float velocity_gain =
      std::clamp(static_cast<float>(hit.velocity) / 127.0f, 0.0f, 1.0f);

  if (hit.lane_id == "kick") {
    const double pitch = 86.0 * std::exp(-t * 14.0) + 42.0;
    const double envelope = std::exp(-t * 18.0);
    return static_cast<float>(
        0.95 * velocity_gain * std::sin(2.0 * kPi * pitch * t) * envelope);
  }

  if (hit.lane_id == "snare") {
    const double body = std::sin(2.0 * kPi * 185.0 * t) * std::exp(-t * 22.0);
    const double noise = NoiseAt(offset + 17) * std::exp(-t * 30.0);
    const double rim_boost = hit.articulation == "rim" ? 1.18 : 1.0;
    return static_cast<float>(
        velocity_gain * rim_boost * (0.36 * body + 0.62 * noise));
  }

  if (hit.lane_id == "hihat") {
    const double decay = hit.articulation == "open" ? 8.5 : 48.0;
    const double noise = NoiseAt(offset + 29) * std::exp(-t * decay);
    const double tick = std::sin(2.0 * kPi * 6900.0 * t) * std::exp(-t * 90.0);
    return static_cast<float>(velocity_gain * (0.42 * noise + 0.18 * tick));
  }

  if (hit.lane_id == "ride" || hit.lane_id == "crash") {
    const double decay = hit.lane_id == "crash" ? 6.0 : 9.0;
    const double metallic =
        std::sin(2.0 * kPi * 2600.0 * t) +
        0.52 * std::sin(2.0 * kPi * 4100.0 * t) +
        0.34 * std::sin(2.0 * kPi * 5800.0 * t);
    const double noise = NoiseAt(offset + 43);
    return static_cast<float>(
        velocity_gain * (0.22 * metallic + 0.24 * noise) *
        std::exp(-t * decay));
  }

  double tom_pitch = 140.0;
  if (hit.lane_id == "tom_high") {
    tom_pitch = 210.0;
  } else if (hit.lane_id == "tom_floor") {
    tom_pitch = 105.0;
  }
  const double tone =
      std::sin(2.0 * kPi * tom_pitch * t) * std::exp(-t * 13.0);
  const double attack = NoiseAt(offset + 59) * std::exp(-t * 50.0);
  return static_cast<float>(velocity_gain * (0.72 * tone + 0.22 * attack));
}
