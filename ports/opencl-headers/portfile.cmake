# OpenCLHeaders
vcpkg_from_github(
    OUT_SOURCE_PATH CL_SOURCE_PATH
    REPO KhronosGroup/OpenCL-Headers
    REF ${VERSION}
    SHA512 9d2ed2a8346bc3f967989091d8cc36148ffe5ff13fe30e12354cc8321c09328bbe23e74817526b99002729c884438a3b1834e175a271f6d36e8341fd86fc1ad5
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
    SHA512 7cdadc8ef182d1556346bd34b5a9ffe6e239ab61ec527e5609d69e1bcaf81a88f3fc534f5bdeed037236e1b0e61f1544d2a95c06df55f9cd8e03e13baf4143ba
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
