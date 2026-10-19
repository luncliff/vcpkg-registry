# Check `opencl` port of https://github.com/microsoft/vcpkg

set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO KhronosGroup/OpenCL-ICD-Loader
    REF "v${VERSION}"
    SHA512 10135363ee04dedf034a617e272eb538639add90f0e821f3a12cee78fa27578b18b466568bd613f1d4bd29f77f09521df98bfd6a9af0fe0041d145fdad21bf27
    HEAD_REF main
    PATCHES
        fix-cmake-dependencies.patch
)

vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}"
  OPTIONS
    -DBUILD_TESTING=OFF
    -DENABLE_OPENCL_LAYERINFO=OFF
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share/cmake/OpenCLICDLoader PACKAGE_NAME OpenCLICDLoader)
vcpkg_fixup_pkgconfig()
vcpkg_copy_pdbs()

file(REMOVE_RECURSE
  "${CURRENT_PACKAGES_DIR}/debug/include"
  "${CURRENT_PACKAGES_DIR}/debug/share"
  "${CURRENT_PACKAGES_DIR}/include"
)
if(NOT VCPKG_TARGET_IS_WINDOWS OR VCPKG_LIBRARY_LINKAGE STREQUAL "static")
  file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/bin" "${CURRENT_PACKAGES_DIR}/bin")
endif()

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
