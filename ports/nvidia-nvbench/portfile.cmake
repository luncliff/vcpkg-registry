if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH RAPIDS_SOURCE_PATH
    REPO rapidsai/rapids-cmake
    REF v24.02.00
    SHA512 d9701353e7a11c339ed11e9867ca22fc937ef399820960bc8c4f4a8a78efa7a24e2ff46080b3ac6ff84cfd3c34780331d8c9a4aeaf4ccee565e3953260bb37ae
    HEAD_REF main
)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO NVIDIA/nvbench
    REF d8dced8a64d9ce305add92fa6d274fd49b569b7e
    SHA512 ff9b8379b7e0d39f31d0635a15bfcbf818592c4e8e85471592a6b50407a74088f4cfe9c7876009b1ef99693a4a4d380815af1505a2e9d413662087f6da46ec10
    PATCHES
        fix-cmake.patch
    HEAD_REF main
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
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
