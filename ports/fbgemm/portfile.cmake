# The project's CMakeLists.txt uses Python to select source files. Check if it is available in advance.
vcpkg_find_acquire_program(PYTHON3)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/fbgemm
    REF v0.5.0
    SHA512 b200a174b493cf2540ca993f42405ed9c7af00a56788af3b5e1a3c1b1a27fb0f3b2189f809c6e7a8322e39e56fe74f249e4e93aa672d643df83b0e8d55339c35
    PATCHES
        fix-cmakelists.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        gpu FBGEMM_BUILD_FBGEMM_GPU
    INVERTED_FEATURES
        gpu FBGEMM_CPU_ONLY
        gpu USE_ROCM
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DUSE_SANITIZER=OFF
        -DFBGEMM_BUILD_TESTS=OFF
        -DFBGEMM_BUILD_BENCHMARKS=OFF
        -DFBGEMM_BUILD_DOCS=OFF
        -DFBGEMM_LIBRARY_TYPE:STRING="default"
        -DPYTHON_EXECUTABLE=${PYTHON3} # inject the path instead of find_package(Python)
    MAYBE_UNUSED_VARIABLES
        FBGEMM_CPU_ONLY
        USE_ROCM
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(PACKAGE_NAME fbgemmLibrary CONFIG_PATH "share/cmake/${PORT}")

# this internal header is required by pytorch
file(INSTALL     "${SOURCE_PATH}/src/RefImplementations.h"
     DESTINATION "${CURRENT_PACKAGES_DIR}/include/fbgemm/src")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
