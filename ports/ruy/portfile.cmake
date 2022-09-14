vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/ruy
    REF 97ebb72aa0655c0af98896b317476a5d0dacad9c
    SHA512 ab37ef41ff94882f6133275398e7a8529c3d8286c5702140cdbbeb63ad23f2b2090cec04f0d49d169eeb063f7943578204352c149e261a8ff68b8d619896b81e
    HEAD_REF master
    PATCHES
        fix-cmake.patch
)

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        -DRUY_MINIMAL_BUILD=ON
        -DRUY_ENABLE_INSTALL=ON
        -DRUY_FIND_CPUINFO=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/${PORT})

file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/include 
                    ${CURRENT_PACKAGES_DIR}/debug/share
)
file(INSTALL ${SOURCE_PATH}/LICENSE
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright
)
