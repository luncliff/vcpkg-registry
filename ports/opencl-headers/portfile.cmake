set(VCPKG_BUILD_TYPE release)
# This header-only package has no ELF binaries to fix up.
set(VCPKG_FIXUP_ELF_RPATH OFF)

vcpkg_from_github(
    OUT_SOURCE_PATH CL_SOURCE_PATH
    REPO KhronosGroup/OpenCL-Headers
    REF "v${VERSION}"
    SHA512 65908880c36e75fe7d11cf326f4a6e67d2b36b06a405eb331b66d02a8ea43c9eee8b82be955cfb2c4538332b6ca1586af76dfcd44ec92aed5cf9131142aead34
    HEAD_REF main
    PATCHES
        fix-headers.patch
)

vcpkg_from_github(
    OUT_SOURCE_PATH CLHPP_SOURCE_PATH
    REPO KhronosGroup/OpenCL-CLHPP
    REF "v${VERSION}"
    SHA512 bc20aad03c374bcdba1bcffe5156d6b38337d84d60ae41bdd05be2f3281e0fb12c6b0b7513d8d6b538a04b72b288dff1046027e9e2e89d3a54585e0604c95b1a
    HEAD_REF main
    PATCHES
        fix-cmake-dependencies.patch
)

vcpkg_cmake_configure(
  SOURCE_PATH "${CMAKE_CURRENT_LIST_DIR}"
  OPTIONS
    "-DCL_SOURCE_PATH:PATH=${CL_SOURCE_PATH}"
    "-DCLHPP_SOURCE_PATH:PATH=${CLHPP_SOURCE_PATH}"
    -DBUILD_DOCS=OFF
    -DBUILD_TESTING=OFF
    -DBUILD_EXAMPLES=OFF
    -DOPENCL_HEADERS_BUILD_TESTING=OFF
    -DOPENCL_HEADERS_BUILD_CXX_TESTS=OFF
    -DCLHPP_BUILD_TESTS=OFF
    -DOPENCL_CLHPP_BUILD_TESTING=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share/cmake/OpenCLHeaders PACKAGE_NAME OpenCLHeaders DO_NOT_DELETE_PARENT_CONFIG_PATH)
vcpkg_cmake_config_fixup(CONFIG_PATH share/cmake/OpenCLHeadersCpp PACKAGE_NAME OpenCLHeadersCpp)
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${CL_SOURCE_PATH}/LICENSE" "${CLHPP_SOURCE_PATH}/LICENSE.txt")
