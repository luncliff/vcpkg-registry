vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO KhronosGroup/glslang
    REF ${VERSION}
    SHA512 8ba7e5f73746b221ff39387282e2d929d1142c60d1c79019f4c21c84b105fb59253e88f2f649a25e9bb7ab01094e455f002c7412aeea882548fac4a426eee809
    HEAD_REF main
    PATCHES
        private-headers.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        tools ENABLE_GLSLANG_BINARIES
)

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON_PATH "${PYTHON3}" DIRECTORY)
vcpkg_add_to_path("${PYTHON_PATH}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DBUILD_EXTERNAL=OFF
        -DENABLE_HLSL=${VCPKG_TARGET_IS_WINDOWS}
        -DENABLE_SPIRV=ON
        -DENABLE_RTTI=OFF
        -DENABLE_EXCEPTIONS=OFF
        -DALLOW_EXTERNAL_SPIRV_TOOLS=ON # requires spirv-tools
        -DENABLE_GLSLANG_JS=OFF
        -DGLSLANG_TESTS=OFF
        -DGLSLANG_ENABLE_INSTALL=ON       
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/glslang)

# see https://github.com/microsoft/vcpkg/blob/master/ports/glslang/portfile.cmake
vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/${PORT}/glslang-config.cmake"
    [[${PACKAGE_PREFIX_DIR}/lib/cmake/glslang/glslang-targets.cmake]]
    [[${CMAKE_CURRENT_LIST_DIR}/glslang-targets.cmake]]
)

if("tools" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES glslang glslangValidator spirv-remap AUTO_CLEAN)
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
