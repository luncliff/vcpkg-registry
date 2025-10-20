if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/XNNPACK
    REF efdfb7ebf2e38492061e788df8a1ee7544d06ccc
    SHA512 f951b1ecb8ada17f0790910c0c2ddac027275a02cfac07b7de7db0984c7ba6eb3944e0fca0df43dadb0b4bc1e96a7c925ade46ff7ef5e9f434de92c0a8ce48b9
    HEAD_REF master
    PATCHES
        fix-cmake.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        kleidiai XNNPACK_ENABLE_KLEIDIAI
)

vcpkg_find_acquire_program(PYTHON3)
message(STATUS "Using Python3: ${PYTHON3}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    WINDOWS_USE_MSBUILD
    OPTIONS
        ${FEATURE_OPTIONS}
        "-DPython_EXECUTABLE:FILEPATH=${PYTHON3}"
        -DXNNPACK_USE_SYSTEM_LIBS=ON
        -DXNNPACK_ENABLE_ASSEMBLY=ON
        -DXNNPACK_ENABLE_MEMOPT=ON
        -DXNNPACK_ENABLE_SPARSE=ON
        -DXNNPACK_ENABLE_WASM_REVECTORIZE=${VCPKG_TARGET_IS_EMSCRIPTEN}
        -DXNNPACK_BUILD_TESTS=OFF
        -DXNNPACK_BUILD_BENCHMARKS=OFF
    MAYBE_UNUSED_VARIABLES
        XNNPACK_ENABLE_WASM_REVECTORIZE
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/bin"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
