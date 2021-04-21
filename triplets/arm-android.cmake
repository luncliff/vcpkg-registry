#
# Note
#   Customized triplet for ${port}:arm-android
#
# Authors
#   - github.com/luncliff (luncliff@gmail.com)
#
# References
#   - https://github.com/microsoft/vcpkg/blob/master/docs/users/android.md
#   - https://android.googlesource.com/platform/ndk/+/master/docs/BuildSystemMaintainers.md#sysroot
#
# Updates
#   1. Initial setup (2021/04/22)
#       - port: vulkan
#
# To Do
#   - API level injection. Major target will be 26~30
#
# Expects
#   Environment variables
#   - ANDROID_NDK_HOME: /.../Android/sdk/ndk/21.3.6528147
#
# Ensures
#   CMake variables
#   - NDK_HOST_NAME: windows, linux, darwin
#   - NDK_HOST_PROCESSOR: x86_64
#   - NDK_HOST_TAG: ${NDK_HOST_NAME}-{NDK_HOST_PROCESSOR}. 
#                   Like "windows-x86_64", "linux-x86_64", and "darwin-x86_64"
#   - NDK_MAJOR_VERSION: 21, if detected NDK version is 21.3.6528147
#   - NDK_MINOR_VERSION: 3, if detected NDK version is 21.3.6528147
#
#   Environment variables
#   - VULKAN_SDK: required for 'vulkan' port
#
cmake_minimum_required(VERSION 3.13)

set(VCPKG_TARGET_ARCHITECTURE arm)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_CMAKE_SYSTEM_NAME Android)

get_filename_component(TRIPLET_NAME ${CMAKE_CURRENT_LIST_FILE} NAME)
message(VERBOSE "Using triplet: ${TRIPLET_NAME}")

# Expect: Windows, Linux, Darwin
string(TOLOWER ${CMAKE_HOST_SYSTEM_NAME} NDK_HOST_NAME)

# Expect: x86_64
cmake_host_system_information(RESULT NDK_HOST_PROCESSOR QUERY OS_PLATFORM)
set(NDK_HOST_TAG "${NDK_HOST_NAME}-${NDK_HOST_PROCESSOR}")
message(STATUS "Using NDK_HOST_TAG: ${NDK_HOST_TAG}")

if(NOT DEFINED ENV{ANDROID_NDK_HOME})
    message(FATAL_ERROR "Requires ANDROID_NDK_HOME environment variable")
endif()
get_filename_component(NDK_DIR_NAME $ENV{ANDROID_NDK_HOME} NAME)
message(STATUS "Using NDK_DIR_NAME: ${NDK_DIR_NAME}")

#
# We expect 23.0.7196353, 22.1.7171670, 21.3.6528147 ...
# For their file organization, see https://android.googlesource.com/platform/ndk/+/master/docs/BuildSystemMaintainers.md#sysroot
# 
if(NDK_DIR_NAME STREQUAL "ndk-bundle")
    message(FATAL_ERROR "ANDROID_NDK_HOME doesn't have expected pattern. Expect /.../Android/sdk/ndk/21.3.6528147")
endif()
string(REGEX MATCH "([0-9]+)\\.([0-9]+)\\.([0-9]+)" NDK_VERSION ${NDK_DIR_NAME})
set(NDK_MAJOR_VERSION ${CMAKE_MATCH_1})
set(NDK_MINOR_VERSION ${CMAKE_MATCH_2})

# Provide path for Vulkan SDK. see
string(COMPARE GREATER ${NDK_MAJOR_VERSION} 21 NDK_OVER_21)
if(NDK_OVER_21)
    # If your API level is 30, libvulkan.so is at 
    #  $ENV{ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/30
    set(ENV{VULKAN_SDK} $ENV{ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${NDK_HOST_NAME}-x86_64/sysroot/usr)
else()
    # If your API level is 30, libvulkan.so is at 
    #  $ENV{ANDROID_NDK_HOME}/platforms/android-30/arch-arm64/usr/lib
    set(ENV{VULKAN_SDK} $ENV{ANDROID_NDK_HOME}/sysroot/usr)
endif()
message(STATUS "Using ENV{VULKAN_SDK}: $ENV{VULKAN_SDK}")

message(STATUS) # trailing LF for readability
