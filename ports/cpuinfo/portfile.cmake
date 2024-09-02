# On Windows, we can get a cpuinfo.dll, but it exports no symbols.
if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/cpuinfo
    REF fa1c679da8d19e1d87f20175ae1ec10995cd3dd3
    SHA512 02e14115b2f91dc555b6181b7f9b422506e8db8ca0858e936045711cc93e0313bc2416298cf0f9619ced6c497a34fd4a4a4bcadcacfc0fe68a1c1ced2bd00558
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
