vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO triton-inference-server/core
    REF f0ff1e5de579e7c2322c78002b09b22463581f4c
    SHA512 437a47ce9a97212869cc19b152174b390f83e7c55c8f152a848b2fc76c5fc651eeb9349d0024d15df84405620c994e7a717d698eb2934c3e3b0c2a283cb14393
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
