# On Windows, we can get a cpuinfo.dll, but it exports no symbols.
if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/cpuinfo
    REF dff2616ddd49122b63abcf44d2c097483b77f861
    SHA512 de681a8cdc0e33cac7b875fabcb05aef8f41cfdeeeb3a1231ae145e6c39c2d5b2b96ad768dc55141b34e0d60291f1e4ef4283bbc2678d04155629a05e9c0f9b0
    HEAD_REF main
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        tools CPUINFO_BUILD_TOOLS
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DCPUINFO_BUILD_UNIT_TESTS=OFF
        -DCPUINFO_BUILD_MOCK_TESTS=OFF
        -DCPUINFO_BUILD_BENCHMARKS=OFF
        -DCPUINFO_BUILD_PKG_CONFIG=ON
    OPTIONS_DEBUG
        -DCPUINFO_LOG_LEVEL=debug
    OPTIONS_RELEASE
        -DCPUINFO_LOG_LEVEL=default
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share/cpuinfo PACKAGE_NAME ${PORT})
vcpkg_fixup_pkgconfig() # pkg_check_modules(libcpuinfo)

if("tools" IN_LIST FEATURES)
    find_program(CPUID_DUMP NAMES cpuid-dump PATHS "${CURRENT_PACKAGES_DIR}/bin")
    if(CPUID_DUMP)
        vcpkg_copy_tools(TOOL_NAMES cpuid-dump AUTO_CLEAN)
    endif()
    vcpkg_copy_tools(TOOL_NAMES cache-info cpu-info isa-info AUTO_CLEAN)
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
