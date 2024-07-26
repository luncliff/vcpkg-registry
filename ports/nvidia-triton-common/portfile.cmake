vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO triton-inference-server/common
    REF e827f28a4815ec3a4caa859b333fa67b4ad848ac
    SHA512 932139aa52ec03fcce2c2c16eaae034ffe7b8e5e06f142305ed97def7ee3307076286617e5a886a31e7d7553c0fe3eafd183b5e8dfd8f1a2a1c2aa6a0f913b66
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
