#ifndef RUNNER_WINDOWS_MIDI_ADAPTER_H_
#define RUNNER_WINDOWS_MIDI_ADAPTER_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <mutex>
#include <string>

#include <mmsystem.h>

class WindowsMidiAdapter {
 public:
  WindowsMidiAdapter(flutter::BinaryMessenger* messenger, HWND message_window);
  ~WindowsMidiAdapter();

  WindowsMidiAdapter(const WindowsMidiAdapter&) = delete;
  WindowsMidiAdapter& operator=(const WindowsMidiAdapter&) = delete;

  bool HandleWindowMessage(UINT message, WPARAM wparam, LPARAM lparam);

 private:
  struct PendingMidiEvent {
    UINT device_id;
    int channel;
    int note;
    int velocity;
    int64_t timestamp_ns;
  };

  static constexpr UINT kMidiEventMessage = WM_APP + 0x51;

  static void CALLBACK MidiInProc(HMIDIIN midi_in,
                                  UINT message,
                                  DWORD_PTR instance,
                                  DWORD_PTR param1,
                                  DWORD_PTR param2);

  void RegisterMethodChannel(flutter::BinaryMessenger* messenger);
  void RegisterEventChannel(flutter::BinaryMessenger* messenger);
  flutter::EncodableValue ListDevices();
  std::string OpenDevice(UINT device_id);
  void CloseDevice();
  void OnMidiData(DWORD_PTR packed_message);
  int64_t QueryPerformanceCounterNs() const;
  void EmitNoteOn(const PendingMidiEvent& event);

  HWND message_window_ = nullptr;
  HMIDIIN midi_in_ = nullptr;
  UINT open_device_id_ = 0;
  LARGE_INTEGER qpc_frequency_{};

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>>
      event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  std::mutex event_sink_mutex_;
};

#endif  // RUNNER_WINDOWS_MIDI_ADAPTER_H_
