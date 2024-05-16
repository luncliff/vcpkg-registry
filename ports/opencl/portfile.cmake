# Check `opencl` port of https://github.com/microsoft/vcpkg

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO KhronosGroup/OpenCL-ICD-Loader
    REF v2024.05.08
    SHA512 12d62183e49c5a1f813807291744d816008afca55b09f5acf2eef1bce50a453bf35a8dfbeb5f433022b0c5517f0a210d7123a3bac7a15ea63cc10f3bc71510f0
    HEAD_REF main
)

vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}"
  OPTIONS
    -DENABLE_OPENCL_LAYERINFO=OFF
    -DOPENCL_ICD_LOADER_HEADERS_DIR:PATH=${CURRENT_INSTALLED_DIR}/include
)

vcpkg_cmake_build(TARGET OpenCL)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share/cmake/OpenCLICDLoader PACKAGE_NAME OpenCLICDLoader)
if(NOT VCPKG_TARGET_IS_WINDOWS)
  vcpkg_fixup_pkgconfig()
endif()
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
