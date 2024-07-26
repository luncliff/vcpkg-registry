vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO triton-inference-server/common
    REF 1ef550b8ec9793a053290147bc330128f5b5f7d0
    SHA512 026aca7328011faa29cf07481de3ddfbf4c10e3fa13562789e7204faf40c0c333ca18a8cf82228262441fcb1e71fe9313ed2cc1199a75398c01668bf3a346260
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
