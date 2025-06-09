#[===[.md:

## References
- https://learn.microsoft.com/en-us/vcpkg/users/triplets
- https://learn.microsoft.com/en-us/cpp/build/reference/compiler-options
- https://learn.microsoft.com/en-us/cpp/build/reference/linker-options
- https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/

#]===]

# ----- mandatory variables comes below -----
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)

# If target system is Windows, we don't set this variable.
# set(VCPKG_CMAKE_SYSTEM_NAME WindowsStore) # for UWP build

# ----- buildsystem file generation comes below -----

set(VCPKG_CMAKE_SYSTEM_VERSION 10.0.22621.0)

list(APPEND VCPKG_CMAKE_CONFIGURE_OPTIONS
    # Some old packages will error with CMake 4.0+ see https://cmake.org/cmake/help/latest/release/4.0.html
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    # "-DCMAKE_CXX_STANDARD=20"
)
# list(APPEND VCPKG_MESON_CONFIGURE_OPTIONS ...)

set(VCPKG_PLATFORM_TOOLSET v143) # CMAKE_VS_PLATFORM_TOOLSET
set(VCPKG_LOAD_VCVARS_ENV ON)

# ----- compiler/linker behavior customization comes below -----

# set(VCPKG_CXX_FLAGS ...)
# set(VCPKG_C_FLAGS ...)
# set(VCPKG_LINKER_FLAGS ...)
