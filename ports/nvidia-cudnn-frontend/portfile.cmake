vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO NVIDIA/cudnn-frontend
    REF v${VERSION}
    SHA512 012aae3d81a92a19b4fd3067c1bf253dbfb820e852edba0150625aa733244d57001eeedf3c0e7382fb3b42dd10f385075c279470208d49199b02d5df45f712b1
    HEAD_REF main
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        test    CUDNN_FRONTEND_BUILD_UNIT_TESTS
        samples CUDNN_FRONTEND_BUILD_SAMPLES
        python  CUDNN_FRONTEND_BUILD_PYTHON_BINDINGS
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DCUDNN_FRONTEND_SKIP_JSON_LIB=OFF
)
vcpkg_cmake_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
    "${CURRENT_PACKAGES_DIR}/share"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
