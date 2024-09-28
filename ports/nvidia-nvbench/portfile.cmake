if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH RAPIDS_SOURCE_PATH
    REPO rapidsai/rapids-cmake
    REF v24.08.00
    SHA512 140cebd0a42114bb58b6c6e694b98de118b1d58c62187f57036ad75407fd51c0e3c012e8f7312bc0a86ab592cf4033184260899d3e1894b9848e3c84ddebc9d9
    HEAD_REF main
)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO NVIDIA/nvbench
    REF a171514056e5d6a7f52a035dd6c812fa301d4f4f
    SHA512 5a5fb4886495fa0682c7331ac12610b0c09caa95a1f31b8a2c5af69ebaa1965a841b6f23c1226c29c9020e7db6988926db142d36792d32b7cce04edae2b0cc08
    PATCHES
        fix-cmake.patch
    HEAD_REF main
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    DISABLE_PARALLEL_CONFIGURE
    OPTIONS
        "-Drapids-cmake-dir:PATH=${RAPIDS_SOURCE_PATH}/rapids-cmake"
        "-DCMAKE_MODULE_PATH:PATH=${RAPIDS_SOURCE_PATH}/rapids-cmake"
        -DNVBench_ENABLE_NVML=ON
        -DNVBench_ENABLE_CUPTI=ON
        -DNVBench_ENABLE_INSTALL_RULES=ON
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
