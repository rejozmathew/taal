cmake_minimum_required(VERSION 3.22.1)

project(taal_metronome LANGUAGES CXX)

add_library(taal_metronome SHARED
  metronome_audio_engine.cpp
)

target_compile_features(taal_metronome PRIVATE cxx_std_17)

find_library(log-lib log)

target_link_libraries(taal_metronome PRIVATE
  aaudio
  ${log-lib}
)
