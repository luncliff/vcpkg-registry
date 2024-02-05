# Check `opencl` port of https://github.com/microsoft/vcpkg

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO KhronosGroup/OpenCL-ICD-Loader
    REF v2023.12.14
    SHA512 b30aa0b856e6c73450fc23f768201ac01d3c5519a14305c79127debc6407be656b68ae2bd527bb7225d4268865f7bdf0b384279eb78b2806725d37ab940bf56e
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
