# On Windows, we can get a cpuinfo.dll, but it exports no symbols.
if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
endif()

if(VCPKG_TARGET_IS_OSX)
    list(LENGTH VCPKG_OSX_ARCHITECTURES arch_count)
    set(OSX_ARCHS ${VCPKG_OSX_ARCHITECTURES})
    unset(VCPKG_OSX_ARCHITECTURES)
else()
    set(arch_count 1)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/cpuinfo
    REF 3c8b1533ac03dd6531ab6e7b9245d488f13a82a5
    SHA512 8e86495bf68cd4bf68d96b317094bf6048bb94cb0b53406d19fa37570b54f4136a88bd06d2520edd756db7a30086db31d4c5ab2a0ca9b61641bf4c6ab790ae5d
    HEAD_REF main
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        tools CPUINFO_BUILD_TOOLS
)

macro(install_cpuinfo)
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
endmacro()

if(VCPKG_TARGET_IS_OSX AND (arch_count GREATER 1))
    # remember original install location
    get_filename_component(PACKAGES_DIR "${CURRENT_PACKAGES_DIR}" ABSOLUTE)
    # build for each architecture...
    foreach(VCPKG_TARGET_ARCHITECTURE ${OSX_ARCHS})
        set(VCPKG_OSX_ARCHITECTURES ${VCPKG_TARGET_ARCHITECTURE})
        set(CURRENT_PACKAGES_DIR "${PACKAGES_DIR}/${VCPKG_TARGET_ARCHITECTURE}")
        file(REMOVE_RECURSE
            "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg"
            "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
        )
        install_cpuinfo()
    endforeach()
    get_filename_component(CURRENT_PACKAGES_DIR "${PACKAGES_DIR}" ABSOLUTE)
    # combine ...
    # ...
else()
    install_cpuinfo()
endif()
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
