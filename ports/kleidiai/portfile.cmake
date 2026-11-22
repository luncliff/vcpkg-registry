vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO ARM-software/kleidiai
    REF "v${VERSION}"
    SHA512 d28f9e9001dd58bf6402efcfb4377e3096ff969d5acdc06b874c7198186498b839e145dd6dae9be53a4a31d15d82e7523128e8d215e0085efa42bcc99122b963
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
    "${CURRENT_PACKAGES_DIR}/include/kai/ukernels/softmax/softmax_f32_f32"
)

file(GLOB LICENSE_FILES
    "${SOURCE_PATH}/LICENSES/*"
)
vcpkg_install_copyright(
    FILE_LIST ${LICENSE_FILES}
)
