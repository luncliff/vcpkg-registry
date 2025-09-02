# OpenCLHeaders
vcpkg_from_github(
    OUT_SOURCE_PATH CL_SOURCE_PATH
    REPO KhronosGroup/OpenCL-Headers
    REF ${VERSION}
    SHA512 e8a338e501783d778ced2e5d0cf5ed735a2372ba9bbd809cc6a1f2d6c7c0d16ded731272fbb5ffe4fd7ce37aa5d739d898869843149f861937aa35890b23c69a
    HEAD_REF main
    PATCHES
        fix-headers.patch
)

vcpkg_cmake_configure(
  SOURCE_PATH "${CL_SOURCE_PATH}"
  OPTIONS
    -DOPENCL_HEADERS_BUILD_CXX_TESTS=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share/cmake/OpenCLHeaders PACKAGE_NAME OpenCLHeaders)
vcpkg_fixup_pkgconfig() # OpenCL-Headers

# OpenCLHeadersCpp
vcpkg_from_github(
    OUT_SOURCE_PATH CLHPP_SOURCE_PATH
    REPO KhronosGroup/OpenCL-CLHPP
    REF ${VERSION}
    SHA512 00afb03aa9ab5bf40dc3ce724f7559581587334d266a379b24de2118d2baa0d4ab792fd631ae18df3e5bccbaae3804c8ea05de2509709cad52e3946ca8db336f
    HEAD_REF main
)

vcpkg_cmake_configure(
  SOURCE_PATH "${CLHPP_SOURCE_PATH}"
  OPTIONS
    -DOpenCLHeaders_DIR:PATH=${CURRENT_PACKAGES_DIR}/share/OpenCLHeaders
    -DBUILD_DOCS=OFF
    -DBUILD_TESTING=OFF
    -DBUILD_EXAMPLES=OFF
    -DCLHPP_BUILD_TESTS=OFF
    -DOPENCL_CLHPP_BUILD_TESTING=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share/cmake/OpenCLHeadersCpp PACKAGE_NAME OpenCLHeadersCpp)
vcpkg_fixup_pkgconfig() # OpenCL-CLHPP

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

vcpkg_install_copyright(FILE_LIST "${CL_SOURCE_PATH}/LICENSE")
