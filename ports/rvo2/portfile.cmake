vcpkg_check_linkage(ONLY_STATIC_LIBRARY) 

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO snape/RVO2
    REF 8063b5c4551f26320f35a3a7f8723902a3837076
    SHA512 2abf84c76af2b56cd918562a7bd16d58b7ba258c5578cfdb7f83140407a97a97f127b843a0d10f1f638469d3ec6033da563e807273c0b2dc08682226d70ef4a1
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBUILD_TESTING=OFF
        -DBUILD_DOCUMENTATION=OFF
        -DENABLE_OPENMP=ON
        -DENABLE_INTERPROCEDURAL_OPTIMIZATION=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/RVO PACKAGE_NAME RVO)
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
