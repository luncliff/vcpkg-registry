vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mackron/miniaudio
    REF 0.11.26
    SHA512 5b5031bc41e57c8f46a3a27c240bc69a7e2e3180d914329c0b73122ad7d678a77dfb5e5018042ef36ccd25bf00151802908dc8166c906edbf739029bf6017c29
)

# Build as a C++ or Objective-C++. Not in C language
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
