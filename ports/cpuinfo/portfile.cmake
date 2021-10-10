# On Windows, we can get a cpuinfo.dll, but it exports no symbols.
if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO luncliff/cpuinfo
    REF 7324ba5f690cd7fb873b583bc2bf9eeae28a6e76
    SHA512 69848ec772a10f7cccdfa3d4d5c3efd1833bae79c954838e87645f647c2dcae65fe332a63d98ba54e39f2e3f2af22c53da79c52783eaad80056041dc0f7e8fa0
    HEAD_REF master
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        tools CPUINFO_BUILD_TOOLS
)

# CPUINFO_TARGET_PROCESSOR
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS_DEBUG
        -DCPUINFO_BUILD_TOOLS=OFF
        -DCPUINFO_LOG_LEVEL=debug
    OPTIONS_RELEASE
        ${FEATURE_OPTIONS}
        -DCPUINFO_LOG_LEVEL=default
    OPTIONS
        -DCPUINFO_RUNTIME_TYPE=${VCPKG_CRT_LINKAGE}
        -DCPUINFO_BUILD_UNIT_TESTS=OFF
        -DCPUINFO_BUILD_MOCK_TESTS=OFF
        -DCPUINFO_BUILD_BENCHMARKS=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "share/${PORT}")
vcpkg_fixup_pkgconfig() # pkg_check_modules(libcpuinfo)

if("tools" IN_LIST FEATURES)
    vcpkg_copy_tools(
        TOOL_NAMES cache-info cpuid-dump cpu-info isa-info
        AUTO_CLEAN
    )
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

file(INSTALL "${SOURCE_PATH}/LICENSE"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright
)
