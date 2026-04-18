#include <aaudio/AAudio.h>
#include <android/log.h>
#include <jni.h>
#include <time.h>

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <limits>
#include <mutex>
#include <string>
#include <vector>

namespace {

constexpr char kLogTag[] = "TaalMetronomeAudio";
constexpr double kPi = 3.14159265358979323846;

int64_t MonotonicNowNs() {
  timespec ts{};
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return static_cast<int64_t>(ts.tv_sec) * 1'000'000'000LL + ts.tv_nsec;
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

jstring ToJString(JNIEnv* env, const std::string& value) {
  if (value.empty()) {
    return nullptr;
  }
  return env->NewStringUTF(value.c_str());
}

}  // namespace

class MetronomeAudioEngine {
 public:
  MetronomeAudioEngine() {
    RenderSamplesForPreset(preset_);
  }

  ~MetronomeAudioEngine() {
    CloseStream();
  }

  std::string Configure(float volume, const std::string& preset) {
    if (volume < 0.0f || volume > 1.0f) {
      return "configure.volume must be between 0 and 1.";
    }
    if (!IsSupportedPreset(preset)) {
      return "configure.preset must be classic, woodblock, or hihat.";
    }

    {
      std::lock_guard<std::mutex> lock(state_mutex_);
      volume_ = volume;
      preset_ = preset;
      RenderSamplesForPreset(preset_);
    }

    return EnsureStream();
  }

  std::string ScheduleClicks(int64_t session_start_time_ns,
                             const std::vector<int64_t>& click_times_ms,
                             const std::vector<bool>& accents) {
    if (click_times_ms.size() != accents.size()) {
      return "click_times_ms and accents length mismatch.";
    }
    const std::string stream_error = EnsureStream();
    if (!stream_error.empty()) {
      return stream_error;
    }

    std::vector<ScheduledClick> parsed_clicks;
    parsed_clicks.reserve(click_times_ms.size());
    for (size_t index = 0; index < click_times_ms.size(); ++index) {
      const int64_t t_ms = click_times_ms[index];
      if (t_ms < 0) {
        return "Scheduled click t_ms must be non-negative.";
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
          accents[index],
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

  std::string ScheduleDrumHits(
      int64_t session_start_time_ns,
      const std::vector<int64_t>& hit_times_ms,
      const std::vector<std::string>& lane_ids,
      const std::vector<uint8_t>& velocities,
      const std::vector<std::string>& articulations) {
    if (hit_times_ms.size() != lane_ids.size() ||
        hit_times_ms.size() != velocities.size() ||
        hit_times_ms.size() != articulations.size()) {
      return "scheduled drum hit array length mismatch.";
    }
    const std::string stream_error = EnsureStream();
    if (!stream_error.empty()) {
      return stream_error;
    }

    std::vector<ScheduledDrumHit> parsed_hits;
    parsed_hits.reserve(hit_times_ms.size());
    for (size_t index = 0; index < hit_times_ms.size(); ++index) {
      const int64_t t_ms = hit_times_ms[index];
      if (t_ms < 0) {
        return "Scheduled drum hit t_ms must be non-negative.";
      }
      if (lane_ids[index].empty()) {
        return "Scheduled drum hit lane_id must be non-empty.";
      }
      if (velocities[index] == 0 || velocities[index] > 127) {
        return "Scheduled drum hit velocity must be in 1..127.";
      }
      if (articulations[index].empty()) {
        return "Scheduled drum hit articulation must be non-empty.";
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
          lane_ids[index],
          articulations[index],
          velocities[index],
      });
    }

    std::lock_guard<std::mutex> lock(state_mutex_);
    scheduled_drum_hits_.insert(scheduled_drum_hits_.end(),
                                parsed_hits.begin(),
                                parsed_hits.end());
    std::sort(scheduled_drum_hits_.begin(), scheduled_drum_hits_.end(),
              [](const ScheduledDrumHit& left, const ScheduledDrumHit& right) {
                return left.target_frame < right.target_frame;
              });
    return "";
  }

  void Stop() {
    std::lock_guard<std::mutex> lock(state_mutex_);
    scheduled_clicks_.clear();
    scheduled_drum_hits_.clear();
  }

 private:
  struct ScheduledClick {
    uint64_t target_frame;
    bool accent;
  };

  struct ScheduledDrumHit {
    uint64_t target_frame;
    std::string lane_id;
    std::string articulation;
    uint8_t velocity;
  };

  static aaudio_data_callback_result_t DataCallback(
      AAudioStream* stream,
      void* user_data,
      void* audio_data,
      int32_t num_frames) {
    (void)stream;
    auto* engine = static_cast<MetronomeAudioEngine*>(user_data);
    engine->Render(static_cast<float*>(audio_data), num_frames);
    return AAUDIO_CALLBACK_RESULT_CONTINUE;
  }

  static void ErrorCallback(AAudioStream* stream,
                            void* user_data,
                            aaudio_result_t error) {
    (void)stream;
    (void)user_data;
    __android_log_print(ANDROID_LOG_WARN, kLogTag, "AAudio stream error: %s",
                        AAudio_convertResultToText(error));
  }

  std::string EnsureStream() {
    if (stream_ != nullptr) {
      return "";
    }

    AAudioStreamBuilder* builder = nullptr;
    aaudio_result_t result = AAudio_createStreamBuilder(&builder);
    if (result != AAUDIO_OK) {
      return std::string("Unable to create AAudio stream builder: ") +
             AAudio_convertResultToText(result);
    }

    AAudioStreamBuilder_setDirection(builder, AAUDIO_DIRECTION_OUTPUT);
    AAudioStreamBuilder_setSharingMode(builder, AAUDIO_SHARING_MODE_EXCLUSIVE);
    AAudioStreamBuilder_setPerformanceMode(
        builder,
        AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);
    AAudioStreamBuilder_setFormat(builder, AAUDIO_FORMAT_PCM_FLOAT);
    AAudioStreamBuilder_setChannelCount(builder, 2);
    AAudioStreamBuilder_setDataCallback(builder, DataCallback, this);
    AAudioStreamBuilder_setErrorCallback(builder, ErrorCallback, this);

    result = AAudioStreamBuilder_openStream(builder, &stream_);
    AAudioStreamBuilder_delete(builder);
    if (result != AAUDIO_OK) {
      stream_ = nullptr;
      return std::string("Unable to open AAudio output stream: ") +
             AAudio_convertResultToText(result);
    }

    sample_rate_ = AAudioStream_getSampleRate(stream_);
    channel_count_ = AAudioStream_getChannelCount(stream_);
    if (sample_rate_ <= 0 || channel_count_ <= 0) {
      CloseStream();
      return "AAudio returned an invalid sample rate or channel count.";
    }

    {
      std::lock_guard<std::mutex> lock(state_mutex_);
      RenderSamplesForPreset(preset_);
      scheduled_clicks_.clear();
      scheduled_drum_hits_.clear();
    }
    rendered_frames_.store(0);

    result = AAudioStream_requestStart(stream_);
    if (result != AAUDIO_OK) {
      CloseStream();
      return std::string("Unable to start AAudio output stream: ") +
             AAudio_convertResultToText(result);
    }

    return "";
  }

  void CloseStream() {
    if (stream_ == nullptr) {
      return;
    }
    AAudioStream_requestStop(stream_);
    AAudioStream_close(stream_);
    stream_ = nullptr;
    rendered_frames_.store(0);
  }

  void Render(float* output, int32_t num_frames) {
    const uint64_t start_frame = rendered_frames_.load();
    std::fill(output, output + (num_frames * channel_count_), 0.0f);

    {
      std::lock_guard<std::mutex> lock(state_mutex_);
      const size_t sample_length =
          std::max(accent_sample_.size(), normal_sample_.size());
      scheduled_clicks_.erase(
          std::remove_if(scheduled_clicks_.begin(), scheduled_clicks_.end(),
                         [start_frame, sample_length](
                             const ScheduledClick& click) {
                          return click.target_frame + sample_length <=
                                 start_frame;
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

      for (int32_t frame_offset = 0; frame_offset < num_frames; ++frame_offset) {
        const uint64_t frame = start_frame + frame_offset;
        float sample = 0.0f;
        for (const auto& click : scheduled_clicks_) {
          sample += SampleAtFrame(click, frame);
        }
        for (const auto& hit : scheduled_drum_hits_) {
          sample += DrumSampleAtFrame(hit, frame);
        }
        sample = std::clamp(sample * volume_, -1.0f, 1.0f);
        for (int32_t channel = 0; channel < channel_count_; ++channel) {
          output[frame_offset * channel_count_ + channel] = sample;
        }
      }
    }

    rendered_frames_.fetch_add(num_frames);
  }

  uint64_t FrameForTimestampNs(int64_t timestamp_ns) const {
    const int64_t now_ns = MonotonicNowNs();
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

  void RenderSamplesForPreset(const std::string& preset) {
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
        normal_sample_[index] =
            static_cast<float>(0.36 * noise_sample * fast_decay);
        accent_sample_[index] =
            static_cast<float>(0.54 * noise_sample * slow_decay);
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

  float SampleAtFrame(const ScheduledClick& click, uint64_t frame) const {
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

  uint64_t DrumSampleLengthFrames(const ScheduledDrumHit& hit) const {
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

  float DrumSampleAtFrame(const ScheduledDrumHit& hit, uint64_t frame) const {
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
      const double body =
          std::sin(2.0 * kPi * 185.0 * t) * std::exp(-t * 22.0);
      const double noise = NoiseAt(offset + 17) * std::exp(-t * 30.0);
      const double rim_boost = hit.articulation == "rim" ? 1.18 : 1.0;
      return static_cast<float>(
          velocity_gain * rim_boost * (0.36 * body + 0.62 * noise));
    }

    if (hit.lane_id == "hihat") {
      const double decay = hit.articulation == "open" ? 8.5 : 48.0;
      const double noise = NoiseAt(offset + 29) * std::exp(-t * decay);
      const double tick =
          std::sin(2.0 * kPi * 6900.0 * t) * std::exp(-t * 90.0);
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

  AAudioStream* stream_ = nullptr;
  std::atomic<uint64_t> rendered_frames_{0};
  int32_t sample_rate_ = 48000;
  int32_t channel_count_ = 2;

  mutable std::mutex state_mutex_;
  float volume_ = 0.8f;
  std::string preset_ = "classic";
  std::vector<float> accent_sample_;
  std::vector<float> normal_sample_;
  std::vector<ScheduledClick> scheduled_clicks_;
  std::vector<ScheduledDrumHit> scheduled_drum_hits_;
};

extern "C" JNIEXPORT jlong JNICALL
Java_dev_taal_taal_MetronomeAudioController_nativeCreate(JNIEnv* env,
                                                         jobject thiz) {
  (void)env;
  (void)thiz;
  return reinterpret_cast<jlong>(new MetronomeAudioEngine());
}

extern "C" JNIEXPORT void JNICALL
Java_dev_taal_taal_MetronomeAudioController_nativeDestroy(JNIEnv* env,
                                                          jobject thiz,
                                                          jlong handle) {
  (void)env;
  (void)thiz;
  delete reinterpret_cast<MetronomeAudioEngine*>(handle);
}

extern "C" JNIEXPORT jstring JNICALL
Java_dev_taal_taal_MetronomeAudioController_nativeConfigure(
    JNIEnv* env,
    jobject thiz,
    jlong handle,
    jfloat volume,
    jstring preset) {
  (void)thiz;
  auto* engine = reinterpret_cast<MetronomeAudioEngine*>(handle);
  if (engine == nullptr) {
    return ToJString(env, "Native audio engine is not initialized.");
  }

  const char* preset_chars = env->GetStringUTFChars(preset, nullptr);
  const std::string preset_value = preset_chars ? preset_chars : "";
  if (preset_chars != nullptr) {
    env->ReleaseStringUTFChars(preset, preset_chars);
  }

  return ToJString(env, engine->Configure(volume, preset_value));
}

extern "C" JNIEXPORT jstring JNICALL
Java_dev_taal_taal_MetronomeAudioController_nativeScheduleClicks(
    JNIEnv* env,
    jobject thiz,
    jlong handle,
    jlong session_start_time_ns,
    jlongArray click_times_ms,
    jbooleanArray accents) {
  (void)thiz;
  auto* engine = reinterpret_cast<MetronomeAudioEngine*>(handle);
  if (engine == nullptr) {
    return ToJString(env, "Native audio engine is not initialized.");
  }

  const jsize click_count = env->GetArrayLength(click_times_ms);
  if (click_count != env->GetArrayLength(accents)) {
    return ToJString(env, "click_times_ms and accents length mismatch.");
  }

  std::vector<int64_t> click_times(static_cast<size_t>(click_count));
  std::vector<bool> accent_values(static_cast<size_t>(click_count));
  std::vector<jlong> raw_click_times(static_cast<size_t>(click_count));
  std::vector<jboolean> raw_accents(static_cast<size_t>(click_count));
  env->GetLongArrayRegion(click_times_ms, 0, click_count,
                          raw_click_times.data());
  env->GetBooleanArrayRegion(accents, 0, click_count, raw_accents.data());
  for (jsize index = 0; index < click_count; ++index) {
    click_times[static_cast<size_t>(index)] = raw_click_times[index];
    accent_values[static_cast<size_t>(index)] = raw_accents[index] == JNI_TRUE;
  }

  return ToJString(env, engine->ScheduleClicks(
                            session_start_time_ns,
                            click_times,
                            accent_values));
}

extern "C" JNIEXPORT jstring JNICALL
Java_dev_taal_taal_MetronomeAudioController_nativeScheduleDrumHits(
    JNIEnv* env,
    jobject thiz,
    jlong handle,
    jlong session_start_time_ns,
    jlongArray hit_times_ms,
    jobjectArray lane_ids,
    jintArray velocities,
    jobjectArray articulations) {
  (void)thiz;
  auto* engine = reinterpret_cast<MetronomeAudioEngine*>(handle);
  if (engine == nullptr) {
    return ToJString(env, "Native audio engine is not initialized.");
  }

  const jsize hit_count = env->GetArrayLength(hit_times_ms);
  if (hit_count != env->GetArrayLength(lane_ids) ||
      hit_count != env->GetArrayLength(velocities) ||
      hit_count != env->GetArrayLength(articulations)) {
    return ToJString(env, "scheduled drum hit array length mismatch.");
  }

  std::vector<int64_t> hit_times(static_cast<size_t>(hit_count));
  std::vector<std::string> lane_values(static_cast<size_t>(hit_count));
  std::vector<uint8_t> velocity_values(static_cast<size_t>(hit_count));
  std::vector<std::string> articulation_values(static_cast<size_t>(hit_count));
  std::vector<jlong> raw_hit_times(static_cast<size_t>(hit_count));
  std::vector<jint> raw_velocities(static_cast<size_t>(hit_count));
  env->GetLongArrayRegion(hit_times_ms, 0, hit_count, raw_hit_times.data());
  env->GetIntArrayRegion(velocities, 0, hit_count, raw_velocities.data());

  for (jsize index = 0; index < hit_count; ++index) {
    hit_times[static_cast<size_t>(index)] = raw_hit_times[index];
    const jint velocity = raw_velocities[index];
    if (velocity < 1 || velocity > 127) {
      return ToJString(env, "Scheduled drum hit velocity must be in 1..127.");
    }
    velocity_values[static_cast<size_t>(index)] =
        static_cast<uint8_t>(velocity);

    auto* lane_string = static_cast<jstring>(
        env->GetObjectArrayElement(lane_ids, index));
    auto* articulation_string = static_cast<jstring>(
        env->GetObjectArrayElement(articulations, index));
    if (lane_string == nullptr || articulation_string == nullptr) {
      if (lane_string != nullptr) {
        env->DeleteLocalRef(lane_string);
      }
      if (articulation_string != nullptr) {
        env->DeleteLocalRef(articulation_string);
      }
      return ToJString(env, "Scheduled drum hit strings must be non-null.");
    }

    const char* lane_chars = env->GetStringUTFChars(lane_string, nullptr);
    const char* articulation_chars =
        env->GetStringUTFChars(articulation_string, nullptr);
    lane_values[static_cast<size_t>(index)] =
        lane_chars != nullptr ? lane_chars : "";
    articulation_values[static_cast<size_t>(index)] =
        articulation_chars != nullptr ? articulation_chars : "";
    if (lane_chars != nullptr) {
      env->ReleaseStringUTFChars(lane_string, lane_chars);
    }
    if (articulation_chars != nullptr) {
      env->ReleaseStringUTFChars(articulation_string, articulation_chars);
    }
    env->DeleteLocalRef(lane_string);
    env->DeleteLocalRef(articulation_string);
  }

  return ToJString(env, engine->ScheduleDrumHits(
                            session_start_time_ns,
                            hit_times,
                            lane_values,
                            velocity_values,
                            articulation_values));
}

extern "C" JNIEXPORT void JNICALL
Java_dev_taal_taal_MetronomeAudioController_nativeStop(JNIEnv* env,
                                                       jobject thiz,
                                                       jlong handle) {
  (void)env;
  (void)thiz;
  auto* engine = reinterpret_cast<MetronomeAudioEngine*>(handle);
  if (engine != nullptr) {
    engine->Stop();
  }
}
