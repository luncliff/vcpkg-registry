vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mackron/miniaudio
    REF 0.11.17
    SHA512 18f5cc7a77cd68567f3f44c517fb05981551f0a875f0d446ff54ad4d8ac56f106e59c935370a8c654a02507cfe01f834f5166698c13824ab1498d5879aba9e84
)

# Build as a C++ or Objective-C++. Not in C language
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
