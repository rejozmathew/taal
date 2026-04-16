#include "windows_midi_adapter.h"

#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cstdint>
#include <sstream>
#include <variant>
#include <vector>

namespace {

constexpr char kMethodChannelName[] = "taal/windows_midi";
constexpr char kEventChannelName[] = "taal/windows_midi/events";

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return "";
  }

  const int size = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, nullptr,
                                       0, nullptr, nullptr);
  if (size <= 1) {
    return "";
  }

  std::string result(static_cast<size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, result.data(), size,
                      nullptr, nullptr);
  return result;
}

std::optional<UINT> DeviceIdFromArguments(
    const flutter::EncodableValue* arguments) {
  if (!arguments) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<int32_t>(arguments)) {
    if (*value >= 0) {
      return static_cast<UINT>(*value);
    }
  }
  if (const auto* value = std::get_if<int64_t>(arguments)) {
    if (*value >= 0 &&
        *value <= static_cast<int64_t>(std::numeric_limits<UINT>::max())) {
      return static_cast<UINT>(*value);
    }
  }
  return std::nullopt;
}

std::string MidiErrorToString(MMRESULT result) {
  wchar_t buffer[MAXERRORLENGTH] = {};
  if (midiInGetErrorTextW(result, buffer, MAXERRORLENGTH) == MMSYSERR_NOERROR) {
    return WideToUtf8(buffer);
  }

  std::ostringstream fallback;
  fallback << "WinMM MIDI error " << result;
  return fallback.str();
}

}  // namespace

WindowsMidiAdapter::WindowsMidiAdapter(flutter::BinaryMessenger* messenger,
                                       HWND message_window)
    : message_window_(message_window) {
  QueryPerformanceFrequency(&qpc_frequency_);
  RegisterMethodChannel(messenger);
  RegisterEventChannel(messenger);
}

WindowsMidiAdapter::~WindowsMidiAdapter() {
  CloseDevice();
}

void WindowsMidiAdapter::RegisterMethodChannel(
    flutter::BinaryMessenger* messenger) {
  method_channel_ = std::make_unique<flutter::MethodChannel<>>(
      messenger, kMethodChannelName, &flutter::StandardMethodCodec::GetInstance());

  method_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() == "listDevices") {
          result->Success(ListDevices());
          return;
        }

        if (call.method_name() == "openDevice") {
          const std::optional<UINT> device_id =
              DeviceIdFromArguments(call.arguments());
          if (!device_id.has_value()) {
            result->Error("invalid_argument",
                          "openDevice expects a non-negative MIDI device id.");
            return;
          }

          const std::string error = OpenDevice(device_id.value());
          if (!error.empty()) {
            result->Error("midi_open_failed", error);
            return;
          }

          result->Success(flutter::EncodableValue(true));
          return;
        }

        if (call.method_name() == "closeDevice") {
          CloseDevice();
          result->Success();
          return;
        }

        result->NotImplemented();
      });
}

void WindowsMidiAdapter::RegisterEventChannel(
    flutter::BinaryMessenger* messenger) {
  event_channel_ = std::make_unique<flutter::EventChannel<>>(
      messenger, kEventChannelName, &flutter::StandardMethodCodec::GetInstance());

  auto handler = std::make_unique<flutter::StreamHandlerFunctions<>>(
      [this](const flutter::EncodableValue*,
             std::unique_ptr<flutter::EventSink<>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        std::lock_guard<std::mutex> lock(event_sink_mutex_);
        event_sink_ = std::move(events);
        return nullptr;
      },
      [this](const flutter::EncodableValue*)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        std::lock_guard<std::mutex> lock(event_sink_mutex_);
        event_sink_.reset();
        return nullptr;
      });

  event_channel_->SetStreamHandler(std::move(handler));
}

flutter::EncodableValue WindowsMidiAdapter::ListDevices() {
  flutter::EncodableList devices;
  const UINT device_count = midiInGetNumDevs();
  devices.reserve(device_count);

  for (UINT id = 0; id < device_count; ++id) {
    MIDIINCAPSW caps = {};
    const MMRESULT result = midiInGetDevCapsW(id, &caps, sizeof(caps));
    if (result != MMSYSERR_NOERROR) {
      continue;
    }

    flutter::EncodableMap device;
    device[flutter::EncodableValue("id")] =
        flutter::EncodableValue(static_cast<int32_t>(id));
    device[flutter::EncodableValue("name")] =
        flutter::EncodableValue(WideToUtf8(caps.szPname));
    device[flutter::EncodableValue("manufacturer_id")] =
        flutter::EncodableValue(static_cast<int32_t>(caps.wMid));
    device[flutter::EncodableValue("product_id")] =
        flutter::EncodableValue(static_cast<int32_t>(caps.wPid));
    device[flutter::EncodableValue("driver_version")] =
        flutter::EncodableValue(static_cast<int32_t>(caps.vDriverVersion));
    devices.push_back(flutter::EncodableValue(device));
  }

  return flutter::EncodableValue(devices);
}

std::string WindowsMidiAdapter::OpenDevice(UINT device_id) {
  CloseDevice();

  const UINT device_count = midiInGetNumDevs();
  if (device_id >= device_count) {
    return "MIDI input device id is out of range.";
  }

  HMIDIIN midi_in = nullptr;
  MMRESULT result = midiInOpen(
      &midi_in, device_id, reinterpret_cast<DWORD_PTR>(&MidiInProc),
      reinterpret_cast<DWORD_PTR>(this), CALLBACK_FUNCTION);
  if (result != MMSYSERR_NOERROR) {
    return MidiErrorToString(result);
  }

  result = midiInStart(midi_in);
  if (result != MMSYSERR_NOERROR) {
    midiInClose(midi_in);
    return MidiErrorToString(result);
  }

  midi_in_ = midi_in;
  open_device_id_ = device_id;
  return "";
}

void WindowsMidiAdapter::CloseDevice() {
  if (!midi_in_) {
    return;
  }

  midiInStop(midi_in_);
  midiInReset(midi_in_);
  midiInClose(midi_in_);
  midi_in_ = nullptr;
}

void CALLBACK WindowsMidiAdapter::MidiInProc(HMIDIIN midi_in,
                                             UINT message,
                                             DWORD_PTR instance,
                                             DWORD_PTR param1,
                                             DWORD_PTR param2) {
  (void)midi_in;
  (void)param2;

  if (message != MIM_DATA || instance == 0) {
    return;
  }

  auto* adapter = reinterpret_cast<WindowsMidiAdapter*>(instance);
  adapter->OnMidiData(param1);
}

void WindowsMidiAdapter::OnMidiData(DWORD_PTR packed_message) {
  const auto message = static_cast<DWORD>(packed_message);
  const int status = static_cast<int>(message & 0xFF);
  const int message_type = status & 0xF0;
  const int channel = status & 0x0F;
  const int note = static_cast<int>((message >> 8) & 0xFF);
  const int velocity = static_cast<int>((message >> 16) & 0xFF);

  if (message_type != 0x90 || velocity == 0) {
    return;
  }

  auto* event = new PendingMidiEvent{
      open_device_id_,
      channel,
      note,
      velocity,
      QueryPerformanceCounterNs(),
  };

  if (!PostMessage(message_window_, kMidiEventMessage, 0,
                   reinterpret_cast<LPARAM>(event))) {
    delete event;
  }
}

int64_t WindowsMidiAdapter::QueryPerformanceCounterNs() const {
  LARGE_INTEGER counter = {};
  QueryPerformanceCounter(&counter);
  const long double nanos =
      static_cast<long double>(counter.QuadPart) * 1000000000.0L /
      static_cast<long double>(qpc_frequency_.QuadPart);
  return static_cast<int64_t>(nanos);
}

bool WindowsMidiAdapter::HandleWindowMessage(UINT message,
                                             WPARAM wparam,
                                             LPARAM lparam) {
  (void)wparam;

  if (message != kMidiEventMessage) {
    return false;
  }

  std::unique_ptr<PendingMidiEvent> event(
      reinterpret_cast<PendingMidiEvent*>(lparam));
  if (event) {
    EmitNoteOn(*event);
  }
  return true;
}

void WindowsMidiAdapter::EmitNoteOn(const PendingMidiEvent& event) {
  flutter::EncodableMap payload;
  payload[flutter::EncodableValue("type")] =
      flutter::EncodableValue("note_on");
  payload[flutter::EncodableValue("device_id")] =
      flutter::EncodableValue(static_cast<int32_t>(event.device_id));
  payload[flutter::EncodableValue("channel")] =
      flutter::EncodableValue(static_cast<int32_t>(event.channel));
  payload[flutter::EncodableValue("note")] =
      flutter::EncodableValue(static_cast<int32_t>(event.note));
  payload[flutter::EncodableValue("velocity")] =
      flutter::EncodableValue(static_cast<int32_t>(event.velocity));
  payload[flutter::EncodableValue("timestamp_ns")] =
      flutter::EncodableValue(event.timestamp_ns);

  std::lock_guard<std::mutex> lock(event_sink_mutex_);
  if (event_sink_) {
    event_sink_->Success(flutter::EncodableValue(payload));
  }
}
