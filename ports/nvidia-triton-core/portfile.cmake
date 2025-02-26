vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO triton-inference-server/core
    REF d53c1f7f8bceb891041e85f0bbf96837fd5cd0bf
    SHA512 4cde77607512fa05f78830b4aa1cbc549d9fefef6088ec3f49b994f1ac0b12f6675e7d0d485ec1d8d768cccfd79e8382fdbeb3a1bd7cdbfcf924150043b97724
    HEAD_REF main
    PATCHES
        fix-cmake.patch
        fix-sources.patch
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
    OPTIONS_DEBUG
        -DTRITON_ENABLE_TRACING=ON
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
