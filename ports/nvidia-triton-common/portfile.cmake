vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO triton-inference-server/common
    REF a6b410343234f9acaa5d615c19f5b38690b45dff
    SHA512 0e2a142ca1c5203c175439fa0080da81e0335f9df05bc38bcbf3b4f4c98a39d35546a5748a4864aff121406824b3e74ac593de4ec6eb1a0dbc241af32c996aa0
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
