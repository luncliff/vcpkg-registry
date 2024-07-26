vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO triton-inference-server/core
    REF a9048db96d270ec0adb75e27b00997f8e9e383cd
    SHA512 44f428c937b827ea5e43be70b285d5d9a04fead354a1511e3cce3d6ce1fdc64fac67ee1cf15663378195a7d30c71d2d1307b3620e1c63a53c7bfb095707089d5
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
