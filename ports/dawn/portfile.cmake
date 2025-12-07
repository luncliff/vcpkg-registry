#
# NOTE:
#  - spirv-tools, spirv-headers: dawn uses internal(generated with python command) header file
#  - glslang: use embedded sources
#

# BUILD_SHARED_LIBS=OFF. Dawn's intent seems like it's preventing problems with DLLs
vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    set(DAWN_BUILD_MONOLITHIC_LIBRARY "SHARED")
else()
    set(DAWN_BUILD_MONOLITHIC_LIBRARY "STATIC")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/dawn
    REF "v${VERSION}"
    SHA512 f0b2a614c2a275864e4e78a5ac686f347f7a27b022e796955a9cf6633a30ff3690229c4577458b46ffa31118ed9ec4ec25eddf38de3c6d99f92ef93bf2ee59d4
    HEAD_REF main
    PATCHES
        fix-cmake.patch # to change CMakeLists.txt file in the SOURCE_PATH, working with editable mode
)

vcpkg_find_acquire_program(GIT)
get_filename_component(GIT_PATH "${GIT}" PATH)
vcpkg_add_to_path("${GIT_PATH}" PREPEND)

# Download the third-party repository sources with the script.
# TODO: The dependencies will be replaced to use other vcpkg ports. Need detailed review with the developers.
vcpkg_find_acquire_program(PYTHON3)
vcpkg_execute_required_process(
    COMMAND "${PYTHON3}" tools/fetch_dawn_dependencies.py # requires git
    LOGNAME fetch-dependencies
    WORKING_DIRECTORY "${SOURCE_PATH}"
)
if(FALSE) # if(NOT _VCPKG_EDITABLE) # These will be used when the port becomes stable
    file(REMOVE_RECURSE
        "${SOURCE_PATH}/third_party/abseil-cpp"
        "${SOURCE_PATH}/third_party/glfw"
        "${SOURCE_PATH}/third_party/khronos"
    )
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        d3d11   DAWN_ENABLE_D3D11
        d3d12   DAWN_ENABLE_D3D12
        gl      DAWN_ENABLE_DESKTOP_GL
        gles    DAWN_ENABLE_OPENGLES
        metal   DAWN_ENABLE_METAL
        vulkan  DAWN_ENABLE_VULKAN
        wayland DAWN_USE_WAYLAND
        x11     DAWN_USE_X11
        glfw    DAWN_USE_GLFW
        tools   TINT_BUILD_CMD_TOOLS
        tint    TINT_ENABLE_INSTALL
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    # WINDOWS_USE_MSBUILD
    OPTIONS
        ${FEATURE_OPTIONS}
        -DBUILD_SHARED_LIBS=OFF # Force static linking to avoid DLL linking issues on Windows
        "-DPython3_EXECUTABLE:FILEPATH=${PYTHON3}"
        -DDAWN_FETCH_DEPENDENCIES=OFF # call in portfile.cmake for explicit management
        -DDAWN_ENABLE_INSTALL=ON
        -DDAWN_ENABLE_NULL=ON # Null backend
        # -DDAWN_ENABLE_WEBGPU_ON_WEBGPU=${VCPKG_TARGET_IS_EMSCRIPTEN}
        -DDAWN_BUILD_MONOLITHIC_LIBRARY=${DAWN_BUILD_MONOLITHIC_LIBRARY}
        -DDAWN_BUILD_PROTOBUF=OFF
        -DDAWN_USE_WINDOWS_UI=${VCPKG_TARGET_IS_WINDOWS}
        -DDAWN_USE_BUILT_DXC=OFF # todo: use 'directx-dxc' port
        -DDAWN_BUILD_SAMPLES=OFF
        -DDAWN_BUILD_TESTS=OFF
        -DDAWN_FORCE_SYSTEM_COMPONENT_LOAD=ON
        -DTINT_BUILD_TESTS=OFF
        -DTINT_BUILD_TINTD=OFF # todo: WGSL language server
        -DTINT_BUILD_IR_BINARY=OFF
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/Dawn PACKAGE_NAME Dawn)

if("tint" IN_LIST FEATURES)
    if("tools" IN_LIST FEATURES)
        vcpkg_copy_tools(TOOL_NAMES
            tint # TARGET tint_cmd_tint_cmd
            tint_info # TARGET tint_cmd_info_cmd
            DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}" AUTO_CLEAN
        )
    endif()
    # The installed DawnConfig.cmake won't use include/tint folder.
    # Manual configuration is required if the library user wants the files.
    # THIS IS INTENDED because these are internal headers.
    # Move the folder because tint/tint.h is using relative include "src/tint/..."
    if(EXISTS "${CURRENT_PACKAGES_DIR}/include/src/tint/src")
        file(COPY "${CURRENT_PACKAGES_DIR}/include/src/tint/src" DESTINATION "${CURRENT_PACKAGES_DIR}/include/tint/")
    endif()
endif()
file(INSTALL "${SOURCE_PATH}/include/webgpu" DESTINATION "${CURRENT_PACKAGES_DIR}/include")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/include/src" # possible leftover of internal headers
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
