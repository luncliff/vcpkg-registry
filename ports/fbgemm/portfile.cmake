# The project's CMakeLists.txt uses Python to select source files. Check if it is available in advance.
vcpkg_find_acquire_program(PYTHON3)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/fbgemm
    REF v${VERSION}
    SHA512 d8f5963bc118aad2c38e41eac18b0ef5c8973a01fa24cb376a39d666ab4d08518650fd5f1bda3f4968b539d195f307dea6920304bec616f73739ab26b0a5e51f
    PATCHES
        fix-cmakelists.patch
        fix-asmjit-1.24.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        gpu FBGEMM_BUILD_FBGEMM_GPU
)

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
message(STATUS "Using python3: ${PYTHON3}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DFBGEMM_LIBRARY_TYPE=default
        -DUSE_SANITIZER=OFF
        -DFBGEMM_BUILD_TESTS=OFF
        -DFBGEMM_BUILD_BENCHMARKS=OFF
        -DFBGEMM_BUILD_DOCS=OFF
        "-DPython_EXECUTABLE:FILEPATH=${PYTHON3}" # inject the path instead of find_package(Python)
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(PACKAGE_NAME fbgemmLibrary CONFIG_PATH "share/cmake/${PORT}")

# this internal header is required by pytorch
file(INSTALL     "${SOURCE_PATH}/src/RefImplementations.h"
     DESTINATION "${CURRENT_PACKAGES_DIR}/include/fbgemm/src")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
