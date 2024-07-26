#[===[.md:
# x64-ios-simulator.cmake

Strongly recommends to handle iOS related builds with VCPKG_CHAINLOAD_TOOLCHAIN_FILE and leetal/ios-cmake project.
This triplet is for the minimal works to try iOS Simulator build

### Defines

* `VCPKG_TARGET_IS_SIMULATOR`: always `true`
* `VCPKG_OSX_SYSROOT`: Run xcodebuild to acuire SDK folder for `iphonesimulator`
* `VCPKG_CMAKE_SYSTEM_VERSION`: Minimum SDK version. Fixed to 16.0
* `VCPKG_CXX_FLAGS`: Will be set to `-mios-simulator-version-min=${VCPKG_DEPLOYMENT_TARGET}`
* `VCPKG_C_FLAGS`: Same with the `VCPKG_CXX_FLAGS`

### See Also

* https://github.com/leetal/ios-cmake (Strongly Recommended)
* Vcpkg
    * [scripts/toolchains/ios.cmake](https://github.com/microsoft/vcpkg/blob/master/scripts/toolchains/ios.cmake)
    * [triplets/community/ios.cmake](https://github.com/microsoft/vcpkg/blob/master/triplets/community/arm64-ios.cmake)
    * [VCPKG_CHAINLOAD_TOOLCHAIN_FILE](https://github.com/microsoft/vcpkg/blob/master/docs/users/triplets.md)
* CMake Manual
    * [CMake Toolchains](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html)
    * [Cross Compiling for iOS, tvOS, or watchOS](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#cross-compiling-for-ios-tvos-or-watchos)

#]===]
cmake_minimum_required(VERSION 3.13)

set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME iOS)


set(VCPKG_TARGET_IS_SIMULATOR true)

find_program(XCODEBUILD_EXE xcodebuild REQUIRED)
execute_process(
    COMMAND ${XCODEBUILD_EXE} -version -sdk iphonesimulator Path
    OUTPUT_VARIABLE VCPKG_OSX_SYSROOT
    ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
)
message(STATUS "Detected SDK: ${VCPKG_OSX_SYSROOT}")

if(NOT DEFINED VCPKG_CMAKE_SYSTEM_VERSION)
    set(VCPKG_CMAKE_SYSTEM_VERSION 16.0) 
endif()
set(VCPKG_CXX_FLAGS "-mios-simulator-version-min=${VCPKG_CMAKE_SYSTEM_VERSION}")
set(VCPKG_C_FLAGS "${VCPKG_CXX_FLAGS}")
