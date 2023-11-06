vcpkg_check_linkage(ONLY_STATIC_LIBRARY) 

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO snape/RVO2-3D
    REF 4475188be8708b38cc3271f2fca6039a639686cc
    SHA512 fa1b5e0bbf3b769cc2891395b96092c0cf5d6829acc2b75bcb337402877fef00aed6013226531d3da8a8066cac77e2c7d79644da5369e166568bd90ff10be020
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
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/RVO3D PACKAGE_NAME RVO3D)
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
