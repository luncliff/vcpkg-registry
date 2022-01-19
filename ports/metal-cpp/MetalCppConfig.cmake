#[===[.md:
# MetalCppConfig.cmake

Expects CMake 3.19+

The module finds path and libraries to import [metal-cpp]().
Several variables can be shared with [leetal/ios-cmake](https://github.com/leetal/ios-cmake/blob/4.2.0/ios.toolchain.cmake).

### Result Variables

* `MetalCpp_SDK_VERSION_REQUIRED`: Required version of target platform SDK. 12.0 for Mac, 15.0 for iOS. `CMAKE_SYSTEM_NAME` may affect the value of this variable.
* `MetalCpp_INCLUDE_DIR`: Header search paths to import `<Metal/Metal.hpp>`
* `MetalCpp_LIBRARIES`: Required libraries to successfully link for [Metal C++](https://developer.apple.com/metal/cpp/)

#### Foundation.framework

* `Foundation_INCLUDE_DIR`: Header search path of `<Foundation/Foundation.hpp>`
* `Foundation_LIBRARY`: Path of the `Foundation.framework`

#### QuartzCore.framework

* `QuartzCore_INCLUDE_DIR`: Header search path of `<QuartzCore/QuartzCore.hpp>`
* `QuartzCore_LIBRARY`: Path of the `QuartzCore.framework`

#### Metal.framework

* `MetalCpp_LIBRARY`: Path of the `Metal.framework`

### Cache variables

* `XCODEBUILD_EXECUTABLE`: Path of the xcodebuild program. Won't be modified if it's defined before `find_package(MetalCpp)`.
* `SDK_NAME`: `macosx` or `iphoneos`. Won't be modified if it's defined before `find_package(MetalCpp)`.

### Hints

Currently no hints are being used.

### Imported Targets

Currently no imported targets being created.

### Examples

Notice that metal-cpp is header-only.
There should be some macro to define implementations in a C++ translation unit.

```cmake
find_package(MetalCpp CONFIG REQUIRED)

set_source_files_properties(main.cpp
PROPERTIES
    COMPILE_DEFINITIONS "NS_PRIVATE_IMPLEMENTATION;CA_PRIVATE_IMPLEMENTATION;MTL_PRIVATE_IMPLEMENTATION"
)
```

To build the program, use `MetalCpp_INCLUDE_DIRS` and `MetalCpp_LIBRARIES`

```cmake
find_package(MetalCpp CONFIG REQUIRED)

target_include_directories(main
PUBLIC
    ${MetalCpp_INCLUDE_DIRS}
)

target_link_libraries(main
PUBLIC
    ${MetalCpp_LIBRARIES}
)
```

### See Also

* https://developer.apple.com/metal/cpp/
* https://cmake.org/cmake/help/latest/module/FindPackageHandleStandardArgs.html
* https://github.com/leetal/ios-cmake/blob/4.2.0/ios.toolchain.cmake
* https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html?#cross-compiling-for-ios-tvos-or-watchos
* https://cmake.org/cmake/help/latest/variable/CMAKE_OSX_SYSROOT.html
* https://cmake.org/cmake/help/latest/variable/CMAKE_OSX_DEPLOYMENT_TARGET.html

### License

The CMake module is wriiten by luncliff@gmail.com.
You can do everything what you want with this file.

#]===]
cmake_minimum_required(VERSION 3.19)
include(FindPackageHandleStandardArgs)

find_path(Foundation_INCLUDE_DIR "Foundation/Foundation.hpp" REQUIRED)
find_library(Foundation_LIBRARY NAMES Foundation REQUIRED)

find_path(QuartzCore_INCLUDE_DIR "QuartzCore/QuartzCore.hpp" REQUIRED)
find_library(QuartzCore_LIBRARY NAMES QuartzCore REQUIRED)

find_path(MetalCpp_INCLUDE_DIRS   "Metal/Metal.hpp" REQUIRED)
find_library(MetalCpp_LIBRARY   NAMES Metal REQUIRED)

list(APPEND MetalCpp_LIBRARIES ${Foundation_LIBRARY} ${QuartzCore_LIBRARY} ${MetalCpp_LIBRARY})

if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
    if(NOT DEFINED SDK_NAME)
        set(SDK_NAME macosx) # -sdk macosx12.0
    endif()
    set(MetalCpp_SDK_VERSION_REQUIRED 12.0)
elseif(CMAKE_SYSTEM_NAME STREQUAL iOS)
    if(NOT DEFINED SDK_NAME)
        set(SDK_NAME iphoneos) # -sdk iphoneos15.0, -sdk iphonesimulator15.0
    endif()
    set(MetalCpp_SDK_VERSION_REQUIRED 15.0)
else()
    message(WARNING "Expect CMAKE_SYSTEM_NAME: \"Darwin\" or \"iOS\"")
    message(FATAL_ERROR "The target system is not supported")
endif()

# The variables should follow https://github.com/leetal/ios-cmake/blob/master/ios.toolchain.cmake
if(NOT DEFINED XCODEBUILD_EXECUTABLE)
    find_program(XCODEBUILD_EXECUTABLE xcodebuild REQUIRED)
endif()
if(NOT DEFINED CMAKE_OSX_SYSROOT_INT)
    # Check CMAKE_OSX_SYSROOT
    execute_process(COMMAND ${XCODEBUILD_EXECUTABLE} -version -sdk ${SDK_NAME} Path
        OUTPUT_VARIABLE CMAKE_OSX_SYSROOT_INT
        COMMAND_ECHO NONE
        ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
        ENCODING UTF-8
    )
endif()
if(NOT DEFINED SDK_VERSION)
    # Check CMAKE_OSX_DEPLOYMENT_TARGET
    execute_process(COMMAND ${XCODEBUILD_EXECUTABLE} -sdk ${CMAKE_OSX_SYSROOT_INT} -version SDKVersion
        OUTPUT_VARIABLE SDK_VERSION
        COMMAND_ECHO NONE
        ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
        ENCODING UTF-8
    )
endif()

# macosx, iphoneos, iphonesimulator
if(SDK_NAME MATCHES macos)
    if(SDK_VERSION VERSION_LESS ${MetalCpp_SDK_VERSION_REQUIRED})
        message(WARNING "Metal C++ may require MacOSX12.0.sdk or later")
    endif()
elseif(SDK_NAME MATCHES iphone)
    if(SDK_VERSION VERSION_LESS ${MetalCpp_SDK_VERSION_REQUIRED})
        message(WARNING "Metal C++ may require iPhoneOS15.0.sdk or later")
    endif()
endif()

find_package_handle_standard_args(MetalCpp
    REQUIRED_VARS MetalCpp_INCLUDE_DIRS MetalCpp_LIBRARY
)
