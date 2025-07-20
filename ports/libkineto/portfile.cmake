vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/kineto
    REF 54ffcd4fb0bd77a5ecea46d11b4ed12d393c7fe3
    SHA512 5346f9d97e12ac200b5d9d5e96fa6c6b9e4b84736d0beea51050725949f6fca31af020aff287468426c2b04588428fc67fbb1c8eb1f50fbef2f5e6ad002c58de
    HEAD_REF main
    PATCHES
        fix-cmake.patch
)

# todo: extract to another port
vcpkg_from_github(
    OUT_SOURCE_PATH DYNOLOG_SOURCE_PATH
    REPO facebookincubator/dynolog
    REF 31a73dce4470bbf6aa684fc2bc72a7330360c50e # 2025-07-19
    SHA512 1ae1ec2e5d83c38df7c385b1fab8b0a08a0680e0bfeadc32a8f253ed83c1d81c95d8192650f5e1b08f8b433cf467ad38f3025cfd4d4ce4bb3b6d0d54e90e56b0
    HEAD_REF main
)
file(REMOVE_RECURSE "${SOURCE_PATH}/libkineto/third_party/dynolog")
file(RENAME "${DYNOLOG_SOURCE_PATH}" "${SOURCE_PATH}/libkineto/third_party/dynolog")

vcpkg_find_acquire_program(PYTHON3)
message(STATUS "Using Python3: ${PYTHON3}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/libkineto"
    OPTIONS
        "-DPython3_EXECUTABLE:FILEPATH=${PYTHON3}"
        -DKINETO_BUILD_TESTS=OFF
        -DLIBKINETO_NOCUPTI=ON # todo: support CUDA feature
        -DLIBKINETO_NOROCTRACER=ON
        -DLIBKINETO_NOXPUPTI=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME kinetoLibrary CONFIG_PATH "share/cmake/kineto")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
