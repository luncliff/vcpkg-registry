cmake_minimum_required(VERSION 3.21)
project(miniaudio CXX)
include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(APPLE)
  enable_language(OBJCXX)
  set(CMAKE_OBJCXX_STANDARD 11)
  set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)
endif()

add_library(miniaudio STATIC
  miniaudio.h
)

set_target_properties(miniaudio
PROPERTIES
  PUBLIC_HEADER "miniaudio.h"
)

target_include_directories(miniaudio
PRIVATE
  ${PROJECT_SOURCE_DIR}
)

target_compile_definitions(miniaudio
PRIVATE
  MA_USE_STDINT
  # MA_NO_THREADING
  # MA_USE_EXPERIMENTAL_LOCK_FREE_JOB_QUEUE
  # MA_USE_REFERENCE_CONVERSION_APIS
  MINIAUDIO_IMPLEMENTATION
  MA_IMPLEMENTATION
)

if(ANDROID)
  target_compile_definitions(miniaudio
  PRIVATE
    MA_ENABLE_AAUDIO
    MA_ENABLE_OPENSL
  )
endif()

if(APPLE)
  target_compile_definitions(miniaudio
  PRIVATE
    MA_ENABLE_COREAUDIO
  )
endif()

if(WIN32)
  target_compile_definitions(miniaudio
  PRIVATE
    MA_USE_WIN32_FILEIO
    MA_ENABLE_DSOUND
  )
endif()

if(CMAKE_SYSTEM_NAME MATCHES "WindowsStore")
  target_compile_definitions(miniaudio
  PRIVATE
    MA_FORCE_UWP
  )
endif()

if(APPLE)
  file(GENERATE
    OUTPUT miniaudio.mm
    CONTENT "#include \"miniaudio.h\""
  )
  target_sources(miniaudio PRIVATE miniaudio.mm)
  target_compile_options(miniaudio PRIVATE -fobjc-arc)
else()
  file(GENERATE
    OUTPUT miniaudio.cpp
    CONTENT "#include \"miniaudio.h\""
  )
  target_sources(miniaudio PRIVATE miniaudio.cpp)
endif()

install(TARGETS miniaudio
  PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
