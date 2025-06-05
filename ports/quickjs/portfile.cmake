vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO bellard/quickjs
    REF 638ec8ca5e1d4aed002a9fb3ef3358e2a6bc42ab
    SHA512 d3fc9cf4d6f7eb17ca8edca5ef5a4bd9eb66fe8b506c2e36bb12c98ed6a1d3dd7550ad6331e03eaf1ebcc5cfa54e1cac74df45837d2d4a1942b354fdf90abf9d
    HEAD_REF master
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

set(VCPKG_PLATFORM_TOOLSET ClangCL) # CMAKE_GENERATOR_TOOLSET

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    WINDOWS_USE_MSBUILD
)
vcpkg_cmake_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/debug/include"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
