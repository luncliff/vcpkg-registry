vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO triton-inference-server/core
    REF 5280db8a43f8b6eb9e97858808b8e751d1a2c74e
    SHA512 f877207b555477697f436a3552731973acb6b4e9dc4f91da3d3c09914c72c4284cfe5d4a9287cb5d9d003d931a11adc258a08c91af4353e5d6b0a886dd794bbe
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
