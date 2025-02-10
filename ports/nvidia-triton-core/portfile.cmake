vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO triton-inference-server/core
    REF 236e461dabfdd7897543f3c77576fcd572e2787b
    SHA512 5436f279e6c366e1f79deaab9515a79a0c0558013523da4a4fb40639e2bba928fdd497caa72a924b775c38f51c88892fa19ba60ab81dddbbf92032bf4f23bd49
    HEAD_REF main
    PATCHES
        fix-cmake.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        google-cloud-storage    TRITON_ENABLE_GCS
        aws-s3                  TRITON_ENABLE_S3
        azure-storage           TRITON_ENABLE_AZURE_STORAGE
        mali-gpu                TRITON_ENABLE_MALI_GPU
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/src"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DTRITON_MIN_CXX_STANDARD=17
        -DTRITON_CORE_HEADERS_ONLY=OFF
        -DTRITON_ENABLE_LOGGING=ON
        -DTRITON_ENABLE_STATS=ON
        -DTRITON_ENABLE_METRICS=ON
        -DTRITON_ENABLE_NVTX=ON
        -DTRITON_ENABLE_GPU=ON
        -DTRITON_MIN_COMPUTE_CAPABILITY:STRING="6.0"
    MAYBE_UNUSED_VARIABLES
        TRITON_CORE_HEADERS_ONLY
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
