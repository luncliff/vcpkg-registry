# On Windows, we can get a cpuinfo.dll, but it exports no symbols.
if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/cpuinfo
    REF 959002f82d7962a473d8bf301845f2af720e0aa4
    SHA512 9aedaac08493e67d339fdffd430f39b2f3a2bf231d0454b9e5193a2c22b51fe728e89ea6066a2915a718b27c0741471f27489e1ea6f36c01dec59ea2c499eeb5
    HEAD_REF main
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        tools CPUINFO_BUILD_TOOLS
)

if(VCPKG_TARGET_IS_WINDOWS)
    # It checks CMAKE_SYSTEM_NAME ...
    if(DEFINED VCPKG_CMAKE_SYSTEM_NAME) # ex) WindowsStore
        list(APPEND PLATFORM_OPTIONS -DCMAKE_SYSTEM_NAME=${VCPKG_CMAKE_SYSTEM_NAME})
    else()
        list(APPEND PLATFORM_OPTIONS -DCMAKE_SYSTEM_NAME=Windows)
    endif()
    # And CPUINFO_TARGET_PROCESSOR ...
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        list(APPEND PLATFORM_OPTIONS -DCPUINFO_TARGET_PROCESSOR="x64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        list(APPEND PLATFORM_OPTIONS -DCPUINFO_TARGET_PROCESSOR="Win32")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        list(APPEND PLATFORM_OPTIONS -DCPUINFO_TARGET_PROCESSOR="ARM64")
    else()
        # Let the project detect the architecture
        message(WARNING "Unexpected architecture: ${VCPKG_TARGET_ARCHITECTURE}")
        list(APPEND PLATFORM_OPTIONS -DCPUINFO_TARGET_PROCESSOR=${VCPKG_TARGET_ARCHITECTURE})
    endif()
    list(APPEND GENERATOR_OPTIONS WINDOWS_USE_MSBUILD)
else()
    list(APPEND GENERATOR_OPTIONS GENERATOR Ninja)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    ${GENERATOR_OPTIONS}
    OPTIONS
        ${FEATURE_OPTIONS}
        ${PLATFORM_OPTIONS}
        -DCPUINFO_LIBRARY_TYPE:STRING=default
        -DCPUINFO_RUNTIME_TYPE:STRING=default
        -DCPUINFO_BUILD_UNIT_TESTS=OFF
        -DCPUINFO_BUILD_MOCK_TESTS=OFF
        -DCPUINFO_BUILD_BENCHMARKS=OFF
    OPTIONS_DEBUG
        -DCPUINFO_LOG_LEVEL=debug
    OPTIONS_RELEASE
        -DCPUINFO_LOG_LEVEL=default
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig() # pkg_check_modules(libcpuinfo)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

if("tools" IN_LIST FEATURES)
    find_program(CPUID_DUMP NAMES cpuid-dump PATHS "${CURRENT_PACKAGES_DIR}/bin")
    if(CPUID_DUMP)
        vcpkg_copy_tools(TOOL_NAMES cpuid-dump AUTO_CLEAN)
    endif()
    vcpkg_copy_tools(TOOL_NAMES cache-info cpu-info isa-info AUTO_CLEAN)
endif()

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
