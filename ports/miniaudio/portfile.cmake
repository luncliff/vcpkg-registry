vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mackron/miniaudio
    REF 0.11.23
    SHA512 b12566432e0167082dd9ad5b5c5fc3d80a80c7803016a59c670f5fb3436c2db8b16411e3f10571eafbf6791c53b761c3deeabb22b6329f80bbe891c760365c3c
)

# Build as a C++ or Objective-C++. Not in C language
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
