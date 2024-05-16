vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mackron/miniaudio
    REF 0.11.21
    SHA512 0c67ff7d9112409fea5af7756c1bc14bca4acfa45a97896ea339cdab228ac3dcc843c492e6da9dc75d4cd6f6b795ee80fe3ad9c4c746d7db691b1216f86e456d
)

# Build as a C++ or Objective-C++. Not in C language
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
