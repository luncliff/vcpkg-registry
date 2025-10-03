# Check `opencl` port of https://github.com/microsoft/vcpkg

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO KhronosGroup/OpenCL-ICD-Loader
    REF ${VERSION}
    SHA512 86e7aa831d3278645cd40c01b7e4262ed9cbfaa2ee8ffb4e9e012dd5bde7b29725508342f05178e09c496dbe3483e5e9b40e46a767d7f5bab504be931eaa95ef
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

# see opencl-headers port
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)