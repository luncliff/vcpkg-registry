vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO KhronosGroup/glslang
    REF ${VERSION}
    SHA512 b246c6f280891b7c9b6cd0b5e85e03ccf1fe173cdfc40e566339a5698176cbcfe23eb7aeaba277f071222d76b9f2a00376d790d4d604aedad82e6196fab7fc70
    HEAD_REF main
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
      -DENABLE_OPT=OFF # requires spirv-tools
      -DENABLE_GLSLANG_JS=OFF
      -DGLSLANG_TESTS=OFF
      -DGLSLANG_ENABLE_INSTALL=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/glslang)

if("tools" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES glslang glslangValidator spirv-remap AUTO_CLEAN)
endif()

file(REMOVE_RECURSE
  "${CURRENT_PACKAGES_DIR}/debug/include"
  "${CURRENT_PACKAGES_DIR}/debug/share"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
