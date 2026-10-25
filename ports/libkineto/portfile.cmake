vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/kineto
    REF ae1f4eb2db483b0e31952566d6b834f339501dcf
    SHA512 d5717a5175e07650682f4d2b81d974bf28101b8f0a2a7c82e53b0bac0a672ee95d110ba58e258e0cd09368039a20913ca9e6ddfaa3f280e7e981484ed21f9e60
    HEAD_REF main
    PATCHES
        fix-cmake.patch
        fix-sources.patch
)

vcpkg_find_acquire_program(PYTHON3)
message(STATUS "Using Python3: ${PYTHON3}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/libkineto"
    OPTIONS
        -DPYTHON_EXECUTABLE:FILEPATH=${PYTHON3}
        -DKINETO_BUILD_TESTS=OFF
        -DKINETO_BACKEND=cpu
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME kinetoLibrary CONFIG_PATH "share/cmake/kineto")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
