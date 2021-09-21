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
#   - https://developer.android.com/ndk/guides/graphics/getting-started
#   - https://cmake.org/cmake/help/latest/module/FindVulkan.html
#
# Updates
#   1. Initial setup (2021/04/22)
#       - port: vulkan
#   2. Add NDK_API_LEVEL, NDK_VULKAN_LIB_PATH (2021/04/30)
#
# To Do
#   - API level injection. Major target will be 26~30
#
# Expects
#   Environment variables
#   - ANDROID_NDK_HOME(required): /.../Android/sdk/ndk/21.3.6528147
#   - NDK_API_LEVEL(optional):
#       Variable to inject API level for this triplet. Expect 24 to 30
#
# Ensures
#   CMake variables
#   - NDK_HOST_NAME: windows, linux, darwin
#   - NDK_HOST_PROCESSOR: x86_64
#   - NDK_HOST_TAG: ${NDK_HOST_NAME}-{NDK_HOST_PROCESSOR}. 
#       Expect "windows-x86_64", "linux-x86_64", and "darwin-x86_64"
#   - NDK_MAJOR_VERSION:
#       If detected NDK version is 21.3.6528147, the value is 21
#   - NDK_MINOR_VERSION:
#       If detected NDK version is 21.3.6528147, the value is 3
#   - NDK_VERSION_OVER_21:
#       Hint variable wheter NDK_MAJOR_VERSION is GREATER than 21.
#       Affects library search path
#       
#   - NDK_API_LEVEL:
#       API level of the detected NDK
#   - NDK_VULKAN_LIB_PATH:
#       Path to `libvulkan.so`. Use the value for `Vulkan_LIBRARY`
#       Check https://cmake.org/cmake/help/latest/module/FindVulkan.html for more detail.
#
#   Environment variables
#   - VULKAN_SDK: required for `find_package(Vulkan)`
#
cmake_minimum_required(VERSION 3.13)

set(VCPKG_TARGET_ARCHITECTURE x86)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_CMAKE_SYSTEM_NAME Android)

get_filename_component(TRIPLET_NAME ${CMAKE_CURRENT_LIST_FILE} NAME)

# Expect: Windows, Linux, Darwin
string(TOLOWER ${CMAKE_HOST_SYSTEM_NAME} NDK_HOST_NAME)

# Expect: x86_64
cmake_host_system_information(RESULT NDK_HOST_PROCESSOR QUERY OS_PLATFORM)
if(NDK_HOST_PROCESSOR MATCHES "x86" OR NDK_HOST_PROCESSOR STREQUAL "AMD64")
    set(NDK_HOST_PROCESSOR x86_64)
endif()
set(NDK_HOST_TAG "${NDK_HOST_NAME}-${NDK_HOST_PROCESSOR}")
message(STATUS "Using NDK_HOST_TAG: ${NDK_HOST_TAG}")

if(NOT DEFINED ENV{ANDROID_NDK_HOME})
    message(FATAL_ERROR "Requires ANDROID_NDK_HOME environment variable")
endif()

if(NOT DEFINED NDK_API_LEVEL)
    if(NOT DEFINED ENV{NDK_API_LEVEL})
        message(STATUS "NDK_API_LEVEL environment variable not defined. Using 24...")
        set(NDK_API_LEVEL 24) # see https://developer.android.com/ndk/guides/graphics/getting-started
    else()
        set(NDK_API_LEVEL $ENV{NDK_API_LEVEL})
    endif()
endif()
message(STATUS "Using NDK_API_LEVEL: ${NDK_API_LEVEL}")

#
# We expect 23.0.7196353, 22.1.7171670, 21.3.6528147 ...
# For their file organization, see https://android.googlesource.com/platform/ndk/+/master/docs/BuildSystemMaintainers.md#sysroot
# 
get_filename_component(NDK_DIR_NAME $ENV{ANDROID_NDK_HOME} NAME)
if(NDK_DIR_NAME STREQUAL "ndk-bundle")
    message(FATAL_ERROR "ANDROID_NDK_HOME doesn't have expected pattern. Expect /.../Android/sdk/ndk/21.3.6528147")
endif()
string(REGEX MATCH "([0-9]+)\\.([0-9]+)\\.([0-9]+)" NDK_VERSION ${NDK_DIR_NAME})
set(NDK_MAJOR_VERSION ${CMAKE_MATCH_1})
set(NDK_MINOR_VERSION ${CMAKE_MATCH_2})
message(STATUS "Found NDK: ${NDK_DIR_NAME} (${NDK_MAJOR_VERSION}.${NDK_MINOR_VERSION})")

# Provide some paths to help using Vulkan SDK
string(COMPARE GREATER ${NDK_MAJOR_VERSION} 21 NDK_VERSION_OVER_21)
if(NDK_VERSION_OVER_21)
    set(ENV{VULKAN_SDK} $ENV{ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${NDK_HOST_TAG}/sysroot/usr)
    # If your API level is 30, libvulkan.so is at 
    #  $ENV{ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/30
    get_filename_component(NDK_VULKAN_LIB_PATH $ENV{VULKAN_SDK}/lib/i686-linux-android/${NDK_API_LEVEL}/libvulkan.so ABSOLUTE)
else()
    # If your API level is 30, libvulkan.so is at 
    #  $ENV{ANDROID_NDK_HOME}/platforms/android-30/arch-arm64/usr/lib
    get_filename_component(NDK_VULKAN_LIB_PATH $ENV{ANDROID_NDK_HOME}/platforms/android-${NDK_API_LEVEL}/arch-${VCPKG_TARGET_ARCHITECTURE}/usr/lib/libvulkan.so ABSOLUTE)
endif()
message(STATUS "Using ENV{VULKAN_SDK}: $ENV{VULKAN_SDK}")
if(NOT EXISTS ${NDK_VULKAN_LIB_PATH})
    message(WARNING "libvulkan.so not found: ${NDK_VULKAN_LIB_PATH}")
else()
    message(STATUS "Found libvulkan.so: ${NDK_VULKAN_LIB_PATH}")
endif()

unset(TRIPLET_NAME)
unset(NDK_DIR_NAME)
message(STATUS) # trailing LF for readability
