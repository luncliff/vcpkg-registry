# https://sourceforge.net/projects/lzmautils/
# https://sourceforge.net/projects/lzmautils/files/xz-5.6.2.tar.xz/download
vcpkg_from_sourceforge(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO lzmautils
    FILENAME xz-5.6.2.tar.xz
    SHA512 af3fd021a9c8eaacfb1ae2af3f7e2a0b0554068461de5be3e2c631174cf5fe15425b739832e826c0fb158484b8cea53701be8c568d7ce1f6113b4630205f5c26
)

if(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
    # https://cmake.org/cmake/help/latest/module/FindLibLZMA.html
    message(WARNING "Forcing system built-in LibLZMA")
    message(STATUS "Installing LibLZMA headers")
    set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
    file(INSTALL "${SOURCE_PATH}/src/liblzma/api/" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
    file(REMOVE
        "${CURRENT_PACKAGES_DIR}/include/Makefile.am"
        "${CURRENT_PACKAGES_DIR}/include/Makefile.in"
    )
    return()
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBUILD_TESTING=OFF
        -DCREATE_XZ_SYMLINKS=OFF
        -DCREATE_LZMA_SYMLINKS=OFF
        -DENABLE_SMALL=${VCPKG_TARGET_IS_ANDROID}
        -DHAVE_GETOPT_LONG=OFF
    MAYBE_UNUSED_VARIABLES
        CREATE_XZ_SYMLINKS
        CREATE_LZMA_SYMLINKS
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
if(NOT VCPKG_TARGET_IS_WINDOWS)
    vcpkg_fixup_pkgconfig()
endif()
# https://cmake.org/cmake/help/latest/module/FindLibLZMA.html
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/liblzma PACKAGE_NAME LibLZMA)

if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_copy_tools(TOOL_NAMES lzmadec lzmainfo xz xzdec AUTO_CLEAN)
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/share/man"
)

if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    file(REMOVE_RECURSE
        "${CURRENT_PACKAGES_DIR}/bin"
        "${CURRENT_PACKAGES_DIR}/debug/bin"
    )
endif()

file(INSTALL "${SOURCE_PATH}/README" "${SOURCE_PATH}/THANKS"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
