# The project's CMakeLists.txt uses Python to select source files. Check if it is available in advance.
vcpkg_find_acquire_program(PYTHON3)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/fbgemm
    REF v${VERSION}
    SHA512 eb1e59c78b802852690272396f6db409ece7cdd8603a87d981a437edf2eea02895a9ecef09b9f3092ee207bc88bb6200a10f777589b31efa4af72b46fe989980
    PATCHES
        fix-cmakelists.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        gpu FBGEMM_BUILD_FBGEMM_GPU
)

if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    set(LIBRARY_TYPE "shared")
elseif(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    set(LIBRARY_TYPE "static")
else()
    set(LIBRARY_TYPE "default")
endif()

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
message(STATUS "Using python3: ${PYTHON3}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DFBGEMM_LIBRARY_TYPE=${LIBRARY_TYPE}
        -DUSE_SANITIZER=OFF
        -DFBGEMM_BUILD_TESTS=OFF
        -DFBGEMM_BUILD_BENCHMARKS=OFF
        -DFBGEMM_BUILD_DOCS=OFF
        "-DPYTHON_EXECUTABLE:FILEPATH=${PYTHON3}" # inject the path instead of find_package(Python)
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(PACKAGE_NAME fbgemmLibrary CONFIG_PATH "share/cmake/${PORT}")

# this internal header is required by pytorch
file(INSTALL     "${SOURCE_PATH}/src/RefImplementations.h"
     DESTINATION "${CURRENT_PACKAGES_DIR}/include/fbgemm/src")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
