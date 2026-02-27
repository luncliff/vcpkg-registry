vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO triton-inference-server/common
    REF c09e98a47d721fea51913eb3737d37a45d34b431
    SHA512 35e112796158d013fea0df50c216a071a17e3b60f0280c737fdf8e1a81cc0dd7b8c0242687b7b479154e0e349059d7041eff58d2eead2330aa7d9d0bae9dff6c
    HEAD_REF main
    PATCHES
        fix-cmake.patch
)

vcpkg_find_acquire_program(PYTHON3)
message(STATUS "Using python3: ${PYTHON3}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DPython_EXECUTABLE:FILEPATH=${PYTHON3}
        -DTRITON_COMMON_ENABLE_PROTOBUF=ON
        -DTRITON_COMMON_ENABLE_GRPC=ON
        -DTRITON_COMMON_ENABLE_JSON=ON
        -DTRITON_MIN_CXX_STANDARD=17
        -DCMAKE_CXX_STANDARD=17 # it's 2024...
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/TritonCommon PACKAGE_NAME TritonCommon)
vcpkg_copy_pdbs()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
