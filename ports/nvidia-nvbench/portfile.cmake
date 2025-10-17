if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO NVIDIA/nvbench
    REF 98d701c054b9c9dfa22d2b7bd811213f070bbebf
    SHA512 b31e6b708dd5a529042db367fe1701c165485df1abb57f1d5f965dc3cd1ee4c6d6bfdef2ad05cf4ba3a22896f60e2369a6d0ae74db55c3a05f60c2937df45b3d
    PATCHES
        fix-cmake.patch
    HEAD_REF main
)

vcpkg_find_cuda(OUT_CUDA_TOOLKIT_ROOT cuda_toolkit_root)

# No Debug configuration
set(VCPKG_BUILD_TYPE release)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    DISABLE_PARALLEL_CONFIGURE
    OPTIONS
        "-DCMAKE_CUDA_COMPILER=${NVCC}"
        "-DCUDAToolkit_ROOT=${cuda_toolkit_root}"
        -Drapids-cmake-version=25.10 # https://github.com/rapidsai/rapids-cmake/releases/tag/v25.10.00
        # -DFETCHCONTENT_FULLY_DISCONNECTED=OFF
        -DNVBench_ENABLE_CUPTI=ON
        # -DNVBench_ENABLE_DEVICE_TESTING=ON
        # -DNVBench_ENABLE_HEADER_TESTING=ON
        -DNVBench_ENABLE_INSTALL_RULES=ON
        -DNVBench_ENABLE_NVML=ON
        -DNVBench_ENABLE_TESTING=OFF
        -DNVBench_ENABLE_EXAMPLES=OFF
        -DNVBench_ENABLE_WERROR=OFF
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/nvbench PACKAGE_NAME nvbench)

vcpkg_copy_tools(TOOL_NAMES nvbench-ctl AUTO_CLEAN)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
