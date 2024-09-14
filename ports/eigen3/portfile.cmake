vcpkg_buildpath_length_warning(40)

vcpkg_from_gitlab(
    GITLAB_URL https://gitlab.com
    OUT_SOURCE_PATH SOURCE_PATH
    REPO libeigen/eigen
    REF 9df21dc8b4b576a7aa5c0094daa8d7e8b8be60f0
    SHA512 c79724f5e0a97f9e96601248acab804fb5e7bda77f6c05d1b6b933b60c35d1f644214640bec74bac95104a74677b391624c7e0cc202ec2759ba74170bd5d34e8
    HEAD_REF 3.4
)
# check ${SOURCE_PATH}/Eigen/src/Core/Util/Macros.h
#  EIGEN_WORLD_VERSION, EIGEN_MAJOR_VERSION, EIGEN_MINOR_VERSION

if(VCPKG_TARGET_IS_ANDROID)
    list(APPEND PLATFORM_OPTIONS -DCMAKE_Fortran_COMPILER=OFF)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBUILD_TESTING=OFF
        -DEIGEN_BUILD_DOC=OFF
        -DEIGEN_BUILD_PKGCONFIG=ON
        ${PLATFORM_OPTIONS}
    OPTIONS_RELEASE
        -DCMAKEPACKAGE_INSTALL_DIR=${CURRENT_PACKAGES_DIR}/lib/cmake/${PORT}
        -DPKGCONFIG_INSTALL_DIR=${CURRENT_PACKAGES_DIR}/lib/pkgconfig
    OPTIONS_DEBUG
        -DCMAKEPACKAGE_INSTALL_DIR=${CURRENT_PACKAGES_DIR}/debug/lib/cmake/${PORT}
        -DPKGCONFIG_INSTALL_DIR=${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/${PORT} PACKAGE_NAME Eigen3)
vcpkg_fixup_pkgconfig()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

file(INSTALL "${SOURCE_PATH}/COPYING.README" DESTINATION "${CURRENT_PACKAGES_DIR}/share")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING.MPL2")
