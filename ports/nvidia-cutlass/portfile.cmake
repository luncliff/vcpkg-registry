if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO NVIDIA/cutlass
    REF v3.4.1
    SHA512 c2ff60af28de951cf4420b163ba2dfc46d30c98fe9e6e765cd1e0be89bf9292e057542ec7061c043c42225b74d970f95f675d366db64105a5c103bb165183ab5
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
