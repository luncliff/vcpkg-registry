# OpenCLHeaders
vcpkg_from_github(
    OUT_SOURCE_PATH CL_SOURCE_PATH
    REPO KhronosGroup/OpenCL-Headers
    REF v2024.05.08
    SHA512 2f1a46d58a5a9329470bab4c3662f17e81aab9558bfd9e1aafa14d3e1ab129513ab9493eeeb3cc48f0f91f0bc6b61bd54e28d7083eed58af9f34cd973cc93de1
    HEAD_REF main
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
    REF v2024.05.08
    SHA512 6396cd67a2edef6a76695857e3e45f7eeb8cdaa8c729197357c6374ac58b41caa37bbe8c3b7a1724d43d3805f8cd5edd53a8ed833d6415bf072745800b744572
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
