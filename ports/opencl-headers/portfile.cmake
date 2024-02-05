# OpenCLHeaders
vcpkg_from_github(
    OUT_SOURCE_PATH CL_SOURCE_PATH
    REPO KhronosGroup/OpenCL-Headers
    REF v2023.12.14
    SHA512 71a21f32cc2d956ef52ea197a95f21a3df5cf4e6888b533eb8cc66be0025fafe9b6477d3de813cb1ae6303032c80bc10b5e5ab1c71074f1662a6b5296fffd3d3
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
    REF v2023.12.14
    SHA512 a90152d2f9c57d4724ef3ea33e1311914e49659042e916e467a9f16877d348ed62f909fe8423589976669b25241a3b996fbd7ac235a44e35947d1b87d3e3ef2b
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
