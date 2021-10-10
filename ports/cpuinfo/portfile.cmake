# On Windows, we can get a cpuinfo.dll, but it exports no symbols.
if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO luncliff/cpuinfo
    REF 66f5e3e5794b4cca6db0f51a3f26c05233ac12a1
    SHA512 87382b189e335832678e165918a827a8c5bba18adde56426156c327241ac3e81702746291b35c81cb448fa9fa35d0d3f757901f38f8c23276b10b6569cca951b
    HEAD_REF master
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        tools CPUINFO_BUILD_TOOLS
)

if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    list(APPEND LINK_OPTIONS -DCPUINFO_LIBRARY_TYPE=shared)
else()
    list(APPEND LINK_OPTIONS -DCPUINFO_LIBRARY_TYPE=static)
endif()

if(VCPKG_CRT_LINKAGE STREQUAL "dynamic")
    list(APPEND LINK_OPTIONS -DCPUINFO_RUNTIME_TYPE=shared)
else()
    list(APPEND LINK_OPTIONS -DCPUINFO_RUNTIME_TYPE=static)
endif()

if(VCPKG_TARGET_IS_WINDOWS AND (VCPKG_TARGET_ARCHITECTURE MATCHES "arm"))
    # no sources for this case...
    list(APPEND PLATFORM_OPTIONS -DCPUINFO_SUPPORTED_PLATFORM=OFF)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        ${LINK_OPTIONS} ${PLATFORM_OPTIONS}
        -DCPUINFO_BUILD_UNIT_TESTS=OFF
        -DCPUINFO_BUILD_MOCK_TESTS=OFF
        -DCPUINFO_BUILD_BENCHMARKS=OFF
    OPTIONS_DEBUG
        -DCPUINFO_LOG_LEVEL=debug
    OPTIONS_RELEASE
        -DCPUINFO_LOG_LEVEL=default
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
