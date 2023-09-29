vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mackron/miniaudio
    REF 0.11.18
    SHA512 3e4a08c326f1a3e8beef962fcb525739734b22572857fe5323d2e72c3e1890edd5d26d3e1264ca5e8ad1c691fb5c312cfb9d1f09484c72353c92b20619c9f678
)

# Build as a C++ or Objective-C++. Not in C language
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
