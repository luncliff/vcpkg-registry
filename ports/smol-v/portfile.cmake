vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO aras-p/smol-v
    REF 1de5258f0d55b160be5fabb1e3c88ef3dac19eba
    SHA512 6a829de84c5e6c68a5efd78c8a2ae192db4a1ea97e8529d405b1e46391e3955c3779d2b12c47eee881edc7f1ba63ce8662077caf12b566680451ee2a1ad7f698
    HEAD_REF main
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_cmake_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/license.txt")
