vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ARM-software/kleidiai
    REF "v${VERSION}"
    SHA512 af021720668a7b86b8b994d9a2c433a2179d9c3fdd984385f33f26cf0014a08469dd634f62a1c19f8ddb4bac5cbe9f5429a6debca51c9b9e20d12e07d7f18c12
    HEAD_REF main
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    WINDOWS_USE_MSBUILD
    OPTIONS
        -DKLEIDIAI_BUILD_TESTS=OFF
        -DKLEIDIAI_BUILD_BENCHMARK=OFF
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(
    CONFIG_PATH "lib/cmake/KleidiAI"
)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/include/kai/ukernels/matmul/matmul_clamp_f32_f16p_qai4c32p"
    "${CURRENT_PACKAGES_DIR}/include/kai/ukernels/matmul/matmul_clamp_f32_u8p_u8p"
    "${CURRENT_PACKAGES_DIR}/include/kai/ukernels/matmul/matmul_clamp_qai8_qai8_qsi4cxp"
    "${CURRENT_PACKAGES_DIR}/include/kai/ukernels/matmul/matmul_clamp_qai8_qai8_qsu2cxp"
    "${CURRENT_PACKAGES_DIR}/include/kai/ukernels/matmul/matmul_clamp_qai8_qai8p_qsi4cxp"
    "${CURRENT_PACKAGES_DIR}/include/kai/ukernels/matmul/matmul_clamp_qai8_qai8p_qsu2cxp"
    "${CURRENT_PACKAGES_DIR}/include/kai/ukernels/matmul/matmul_i32_u8p_u8p"
)

file(GLOB LICENSE_FILES
    "${SOURCE_PATH}/LICENSES/*"
)
vcpkg_install_copyright(
    FILE_LIST ${LICENSE_FILES}
)
