# The project's CMakeLists.txt uses Python to select source files. Check if it is available in advance.
vcpkg_find_acquire_program(PYTHON3)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/fbgemm
    REF v0.7.0
    SHA512 e969697f0dd864bf904ee0c762351b3a3486a699156926934c37beae09f9c9bb53e27cb0f4804376a7087c37e00772061b5f697595317392215d1b64d1f18cff
    PATCHES
        fix-cmakelists.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        gpu FBGEMM_BUILD_FBGEMM_GPU
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DUSE_SANITIZER=OFF
        -DFBGEMM_BUILD_TESTS=OFF
        -DFBGEMM_BUILD_BENCHMARKS=OFF
        -DFBGEMM_BUILD_DOCS=OFF
        -DPYTHON_EXECUTABLE=${PYTHON3} # inject the path instead of find_package(Python)
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(PACKAGE_NAME fbgemmLibrary CONFIG_PATH "share/cmake/${PORT}")

# this internal header is required by pytorch
file(INSTALL     "${SOURCE_PATH}/src/RefImplementations.h"
     DESTINATION "${CURRENT_PACKAGES_DIR}/include/fbgemm/src")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
