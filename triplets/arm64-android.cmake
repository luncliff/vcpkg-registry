#[===[.md:
# arm64-android.cmake

Customized triplet to build NDK(arm64-v8a)

### Requires

* `ENV{ANDROID_NDK_HOME}`

### Defines

* `NDK_VERSION_OVER_21`: `true` if `VCPKG_CMAKE_SYSTEM_VERSION` is GREATER than 21

Some varialbe to help [FindVulkan.cmake](https://cmake.org/cmake/help/latest/module/FindVulkan.html) in NDK

* `ENV{VULKAN_SDK}`: /path/to/sysroot/usr
* `NDK_VULKAN_LIB_PATH`, `Vulkan_LIBRARY`: result of `find_file` for `libvulkan.so`

### See Also

* https://learn.microsoft.com/en-us/vcpkg/users/platforms/android
* https://android.googlesource.com/platform/ndk/+/master/docs/BuildSystemMaintainers.md#sysroot
* https://developer.android.com/ndk/guides/graphics/getting-started

#]===]
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME Android)

if(NOT DEFINED VCPKG_CMAKE_SYSTEM_VERSION)
    set(VCPKG_CMAKE_SYSTEM_VERSION 26)
endif()

set(VCPKG_MAKE_BUILD_TRIPLET "--host=aarch64-linux-android")
set(VCPKG_CMAKE_CONFIGURE_OPTIONS -DANDROID_ABI=arm64-v8a)

# Expect: Windows, Linux, Darwin
string(TOLOWER ${CMAKE_HOST_SYSTEM_NAME} NDK_HOST_NAME)

# Expect: x86_64
cmake_host_system_information(RESULT NDK_HOST_PROCESSOR QUERY OS_PLATFORM)
if(NDK_HOST_PROCESSOR MATCHES "x86" OR NDK_HOST_PROCESSOR STREQUAL "AMD64")
    set(NDK_HOST_PROCESSOR x86_64)
endif()
set(NDK_HOST_TAG "${NDK_HOST_NAME}-${NDK_HOST_PROCESSOR}")

# Provide some paths to help using Vulkan SDK
set(ENV{VULKAN_SDK} $ENV{ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/${NDK_HOST_TAG}/sysroot/usr)
message(STATUS "Using ENV{VULKAN_SDK}: $ENV{VULKAN_SDK}")

string(COMPARE GREATER ${VCPKG_CMAKE_SYSTEM_VERSION} 21 NDK_VERSION_OVER_21)
if(NDK_VERSION_OVER_21)
    # If your API level is 30, libvulkan.so is at 
    #  $ENV{ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/30
    find_file(NDK_VULKAN_LIB_PATH NAME libvulkan.so
        PATHS $ENV{VULKAN_SDK}/lib/aarch64-linux-android/${NDK_API_LEVEL}
    )
else()
    # If your API level is 30, libvulkan.so is at 
    #  $ENV{ANDROID_NDK_HOME}/platforms/android-30/arch-arm64/usr/lib
    find_file(NDK_VULKAN_LIB_PATH NAME libvulkan.so
        PATHS $ENV{ANDROID_NDK_HOME}/platforms/android-${NDK_API_LEVEL}/arch-${VCPKG_TARGET_ARCHITECTURE}/usr/lib/
    )
endif()
if(NDK_VULKAN_LIB_PATH)
    message(STATUS "Found libvulkan.so: ${NDK_VULKAN_LIB_PATH}")
    set(Vulkan_LIBRARY ${NDK_VULKAN_LIB_PATH})
endif()

message(STATUS) # trailing LF for readability
