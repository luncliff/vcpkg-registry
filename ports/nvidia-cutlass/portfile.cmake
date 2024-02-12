if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO NVIDIA/cutlass
    REF v3.4.0
    SHA512 6debdfa0ffbb9c14293619a281e864ac16592f64856e4a54ae456a79cbce3ec2f5068031f4eae589e72fb10c3c61f1fa6d3fa14650754a27c4b12e14774e7f75
    PATCHES
        fix-cmake.patch
    HEAD_REF main
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        tools CUTLASS_ENABLE_TOOLS
        tools CUTLASS_ENABLE_PROFILER
        test  CUTLASS_ENABLE_TESTS
        test  CUTLASS_ENABLE_GTEST_UNIT_TESTS
        test  CUTLASS_INSTALL_TESTS
)

if("tools" IN_LIST FEATURES)
    x_vcpkg_get_python_packages(
        PYTHON_VERSION 3
        PACKAGES numpy
        OUT_PYTHON_VAR PYTHON3
    )
    get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
else()
    vcpkg_find_acquire_program(PYTHON3)
    get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
endif()
vcpkg_add_to_path(PREPEND "${PYTHON_PATH}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DCUTLASS_REVISION:STRING=v3.4.0
        -DCUTLASS_ENABLE_HEADERS_ONLY=ON
        -DCUTLASS_ENABLE_LIBRARY=ON
        -DCUTLASS_ENABLE_EXAMPLES=OFF
        -DCUTLASS_ENABLE_PERFORMANCE=OFF
        -DCUTLASS_LIBRARY_OPERATIONS:STRING=all
        -DCUTLASS_LIBRARY_KERNELS:STRING=all
        -DPython3_EXECUTABLE:FILEPATH=${PYTHON3}
    MAYBE_UNUSED_VARIABLES
        CUTLASS_LIBRARY_OPERATIONS
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/NvidiaCutlass PACKAGE_NAME NvidiaCutlass)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
    "${CURRENT_PACKAGES_DIR}/test"
    "${CURRENT_PACKAGES_DIR}/lib"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
