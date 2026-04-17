#ifndef RUNNER_WINDOWS_METRONOME_AUDIO_H_
#define RUNNER_WINDOWS_METRONOME_AUDIO_H_

#include <audioclient.h>
#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <mmdeviceapi.h>
#include <windows.h>
#include <wrl/client.h>

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

class WindowsMetronomeAudio {
 public:
  explicit WindowsMetronomeAudio(flutter::BinaryMessenger* messenger);
  ~WindowsMetronomeAudio();

  WindowsMetronomeAudio(const WindowsMetronomeAudio&) = delete;
  WindowsMetronomeAudio& operator=(const WindowsMetronomeAudio&) = delete;

 private:
  enum class SampleFormat {
    Float32,
    Int16,
  };

  struct ScheduledClick {
    uint64_t target_frame;
    bool accent;
  };

  void RegisterMethodChannel(flutter::BinaryMessenger* messenger);
  std::string Configure(const flutter::EncodableMap& arguments);
  std::string ScheduleClicks(const flutter::EncodableMap& arguments);
  void Stop();

  std::string EnsureStream();
  std::string InitializeStream();
  void ShutdownStream();
  void RenderLoop();
  bool RenderBuffer(uint32_t frame_count);
  void MixClickBuffer(uint8_t* buffer, uint32_t frame_count);

  int64_t QueryPerformanceCounterNs() const;
  uint64_t FrameForTimestampNs(int64_t timestamp_ns) const;
  void RenderSamplesForPreset(const std::string& preset);
  float SampleAtFrame(const ScheduledClick& click, uint64_t frame) const;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;

  LARGE_INTEGER qpc_frequency_{};
  std::atomic<bool> running_{false};
  std::atomic<uint64_t> rendered_frames_{0};
  std::thread render_thread_;
  HANDLE render_event_ = nullptr;

  Microsoft::WRL::ComPtr<IAudioClient> audio_client_;
  Microsoft::WRL::ComPtr<IAudioRenderClient> render_client_;
  uint32_t buffer_frame_count_ = 0;
  uint32_t sample_rate_ = 48000;
  uint16_t channels_ = 2;
  uint16_t bytes_per_sample_ = 4;
  SampleFormat sample_format_ = SampleFormat::Float32;

  mutable std::mutex state_mutex_;
  float volume_ = 0.8f;
  std::string preset_ = "classic";
  std::vector<float> accent_sample_;
  std::vector<float> normal_sample_;
  std::vector<ScheduledClick> scheduled_clicks_;
};

#endif  // RUNNER_WINDOWS_METRONOME_AUDIO_H_
