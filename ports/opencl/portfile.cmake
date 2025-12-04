# Check `opencl` port of https://github.com/microsoft/vcpkg

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO KhronosGroup/OpenCL-ICD-Loader
    REF ${VERSION}
    SHA512 29043eff21076440046314edf62bb488b7e4e17d9fbdac4c3727d8e2523c0c8fbf89ee7fcf762528af761ddbcb4be24e5f062ffa82f778401d6365faa35344a8
    HEAD_REF main
)

vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}"
  OPTIONS
    -DENABLE_OPENCL_LAYERINFO=OFF
    "-DOPENCL_ICD_LOADER_HEADERS_DIR:PATH=${CURRENT_INSTALLED_DIR}/include"
)

vcpkg_cmake_build(TARGET OpenCL)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share/cmake/OpenCLICDLoader PACKAGE_NAME OpenCLICDLoader)
vcpkg_fixup_pkgconfig()
vcpkg_copy_pdbs()

file(REMOVE_RECURSE
  "${CURRENT_PACKAGES_DIR}/debug/include"
  "${CURRENT_PACKAGES_DIR}/debug/share"
  "${CURRENT_PACKAGES_DIR}/include"
)
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
  file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/bin" "${CURRENT_PACKAGES_DIR}/bin")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
