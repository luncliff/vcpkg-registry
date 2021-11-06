#[===[.md:
# arm64-android.cmake

Customized triplet to build NDK(arm64-v8a)

### Requires

* `ENV{ANDROID_NDK_HOME}`

### Defines

* `NDK_MAJOR_VERSION`: If detected NDK is 22.1.7171670, the value will be 22
* `NDK_MINOR_VERSION`: If detected NDK is 22.1.7171670, the value will be 1
* `NDK_VERSION_OVER_21`: `true` if  NDK_MAJOR_VERSION is GREATER than 21

Some varialbe to help [FindVulkan.cmake](https://cmake.org/cmake/help/latest/module/FindVulkan.html) in NDK

* `ENV{VULKAN_SDK}`: /path/to/sysroot/usr
* `NDK_VULKAN_LIB_PATH`, `Vulkan_LIBRARY`: result of `find_file` for `libvulkan.so`

### See Also

* https://github.com/microsoft/vcpkg/blob/master/docs/users/android.md
* https://android.googlesource.com/platform/ndk/+/master/docs/BuildSystemMaintainers.md#sysroot
* https://developer.android.com/ndk/guides/graphics/getting-started

#]===]
cmake_minimum_required(VERSION 3.13)

set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_CMAKE_SYSTEM_NAME Android)

# Expect: Windows, Linux, Darwin
string(TOLOWER ${CMAKE_HOST_SYSTEM_NAME} NDK_HOST_NAME)

# Expect: x86_64
cmake_host_system_information(RESULT NDK_HOST_PROCESSOR QUERY OS_PLATFORM)
if(NDK_HOST_PROCESSOR MATCHES "x86" OR NDK_HOST_PROCESSOR STREQUAL "AMD64")
    set(NDK_HOST_PROCESSOR x86_64)
endif()
set(NDK_HOST_TAG "${NDK_HOST_NAME}-${NDK_HOST_PROCESSOR}")

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

# For their file organization, see https://android.googlesource.com/platform/ndk/+/master/docs/BuildSystemMaintainers.md#sysroot
get_filename_component(NDK_DIR_NAME $ENV{ANDROID_NDK_HOME} NAME)
if(NDK_DIR_NAME STREQUAL "ndk-bundle")
    # This is what android.toolchain.cmake do ...
    file(READ "$ENV{ANDROID_NDK_HOME}/source.properties" ANDROID_NDK_SOURCE_PROPERTIES)
    set(ANDROID_NDK_REVISION_REGEX
      "^Pkg\\.Desc = Android NDK\nPkg\\.Revision = ([0-9]+)\\.([0-9]+)\\.([0-9]+)(-beta([0-9]+))?")
    if(NOT ANDROID_NDK_SOURCE_PROPERTIES MATCHES "${ANDROID_NDK_REVISION_REGEX}")
      message(SEND_ERROR "Failed to parse Android NDK revision: source.properties.\n${ANDROID_NDK_SOURCE_PROPERTIES}")
    endif()
    set(NDK_MAJOR_VERSION "${CMAKE_MATCH_1}")
    set(NDK_MINOR_VERSION "${CMAKE_MATCH_2}")

else()
    # regex the folder's name
    string(REGEX MATCH "([0-9]+)\\.([0-9]+)\\.([0-9]+)" NDK_VERSION ${NDK_DIR_NAME})
    set(NDK_MAJOR_VERSION ${CMAKE_MATCH_1})
    set(NDK_MINOR_VERSION ${CMAKE_MATCH_2})

endif()
message(STATUS "Found NDK: ${NDK_DIR_NAME} (${NDK_MAJOR_VERSION}.${NDK_MINOR_VERSION})")
unset(NDK_DIR_NAME)

# Provide some paths to help using Vulkan SDK
string(COMPARE GREATER ${NDK_MAJOR_VERSION} 21 NDK_VERSION_OVER_21)
if(NDK_VERSION_OVER_21)
    set(ENV{VULKAN_SDK} $ENV{ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${NDK_HOST_TAG}/sysroot/usr)
    message(STATUS "Using ENV{VULKAN_SDK}: $ENV{VULKAN_SDK}")
    # If your API level is 30, libvulkan.so is at 
    #  $ENV{ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/30
    find_file(NDK_VULKAN_LIB_PATH NAME libvulkan.so PATHS $ENV{VULKAN_SDK}/lib/x86_64-linux-android/${NDK_API_LEVEL})
else()
    # If your API level is 30, libvulkan.so is at 
    #  $ENV{ANDROID_NDK_HOME}/platforms/android-30/arch-arm64/usr/lib
    find_file(NDK_VULKAN_LIB_PATH NAME vulkan PATHS $ENV{ANDROID_NDK_HOME}/platforms/android-${NDK_API_LEVEL}/arch-${VCPKG_TARGET_ARCHITECTURE}/usr/lib/)
endif()
if(NDK_VULKAN_LIB_PATH)
    message(STATUS "Found libvulkan.so: ${NDK_VULKAN_LIB_PATH}")
    set(Vulkan_LIBRARY ${NDK_VULKAN_LIB_PATH})
endif()

message(STATUS) # trailing LF for readability
