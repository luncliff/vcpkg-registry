vcpkg_find_acquire_program(PKGCONFIG)
message(STATUS "Using pkgconfig: ${PKGCONFIG}")

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/filament
    REF v1.37.0
    SHA512 570f1167140c81653bb389a8057c47bc957fcd705e585dad925d6d6015f272dba94ac152f678f821a1e6b59f9dc5be03a4ec3188645f54170bbc3414d5566c8e
    PATCHES
        fix-cmake.patch
        disable-static-lib-combine.patch
        enable-windows-gles3.patch
        fix-sources.patch
        fix-libs-viewer.patch
        fix-libs-matdbg.patch
        fix-cmake2.patch
        fix-cmake3.patch
)
file(APPEND "${SOURCE_PATH}/.gitignore" "\nthird_party\n")

file(REMOVE_RECURSE
    "${SOURCE_PATH}/android"
    "${SOURCE_PATH}/ios"
    "${SOURCE_PATH}/web"
    "${SOURCE_PATH}/docs"
    "${SOURCE_PATH}/site"
    "${SOURCE_PATH}/third_party/clang"
    "${SOURCE_PATH}/third_party/markdeep"
    "${SOURCE_PATH}/third_party/vkmemalloc"
)

function(leave_license SRC_PORT DST_NAME)
    get_filename_component(DST_DIR "${SOURCE_PATH}/third_party/${DST_NAME}" ABSOLUTE)
    get_filename_component(DST_PATH "${DST_DIR}/LICENSE" ABSOLUTE)
    file(REMOVE_RECURSE "${DST_DIR}")
    file(MAKE_DIRECTORY "${DST_DIR}")
    file(COPY_FILE "${CURRENT_INSTALLED_DIR}/share/${SRC_PORT}/copyright" "${DST_PATH}")
endfunction()
leave_license(glslang glslang)
leave_license(assimp libassimp)
leave_license(libpng libpng)
leave_license(spirv-cross spirv-cross)
leave_license(spirv-tools spirv-tools)
leave_license(stb stb)
leave_license(mikktspace mikktspace)
leave_license(meshoptimizer meshoptimizer)
leave_license(tinyexr tinyexr)
leave_license(zlib libz)
# ...
leave_license(sdl2 libsdl2)
leave_license(draco draco)
leave_license(gtest libgtest)
leave_license(benchmark benchmark)
leave_license(civetweb civetweb)
leave_license(basis-universal basisu)
leave_license(cgltf cgltf)
leave_license(imgui imgui)
leave_license(jsmn jsmn)
leave_license(robin-map robin-map)

if(VCPKG_TARGET_IS_WINDOWS)
    leave_license(getopt-win32 getopt)
endif()
if("vulkan" IN_LIST FEATURES)
    leave_license(vulkan-memory-allocator vkmemalloc)
endif()

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_STATIC_CRT)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        gles3   FILAMENT_USE_EXTERNAL_GLES3
        gles3   FILAMENT_SUPPORTS_EGL_ON_LINUX
        vulkan  FILAMENT_SUPPORTS_VULKAN
)

if(VCPKG_TARGET_IS_WINDOWS)
    list(APPEND GENERATOR_OPTIONS WINDOWS_USE_MSBUILD)
elseif(VCPKG_TARGET_IS_OSX)
    list(APPEND GENERATOR_OPTIONS GENERATOR Xcode)
else()
    list(APPEND GENERATOR_OPTIONS GENERATOR Ninja)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    ${GENERATOR_OPTIONS}
    OPTIONS
        ${FEATURE_OPTIONS}
        -DUSE_STATIC_CRT=${USE_STATIC_CRT}
        -DPKG_CONFIG_EXECUTABLE:FILEPATH=${PKGCONFIG}
        -DCMAKE_CROSSCOMPILING=${VCPKG_CROSSCOMPILING}
        -DFILAMENT_SKIP_SDL2=ON
        -DFILAMENT_SKIP_SAMPLES=ON
        -DFILAMENT_SUPPORTS_XCB=${VCPKG_TARGET_IS_LINUX}
        -DFILAMENT_SUPPORTS_XLIB=${VCPKG_TARGET_IS_LINUX}
        -DFILAMENT_SUPPORTS_WAYLAND=${VCPKG_TARGET_IS_LINUX}
        -DFILAMENT_SUPPORTS_METAL=${VCPKG_TARGET_IS_OSX}
        -DFILAMENT_ENABLE_ASAN_UBSAN=OFF
        -DFILAMENT_ENABLE_LTO=ON
        -DFILAMENT_ENABLE_MATDBG=OFF # disable matdbg, matdbg_resources
    OPTIONS_DEBUG
        -DFILAMENT_DISABLE_MATOPT=ON
    OPTIONS_RELEASE
        -DFILAMENT_DISABLE_MATOPT=OFF
)

# some targets requires tools for resource generation
if(VCPKG_CROSSCOMPILING)
    vcpkg_add_to_path(PREPEND "${CURRENT_HOST_INSTALLED_DIR}/bin")
    vcpkg_add_to_path(PREPEND "${CURRENT_HOST_INSTALLED_DIR}/tools/${PORT}")
else()
    message(STATUS "Building tools first...")
    vcpkg_cmake_build(TARGET resgen         LOGFILE_BASE build-resgen       ADD_BIN_TO_PATH)
    vcpkg_cmake_build(TARGET glslminifier   LOGFILE_BASE build-glslminifier ADD_BIN_TO_PATH)
    vcpkg_cmake_build(TARGET shaders        LOGFILE_BASE build-shaders      ADD_BIN_TO_PATH)
    list(APPEND TOOL_TARGET_NAMES
        resgen glslminifier matc cmgen mipgen uberz filamesh
        normal-blending roughness-prefilter specular-color
    )
endif()

message(STATUS "Starting build/install...")
vcpkg_cmake_install(ADD_BIN_TO_PATH)
vcpkg_copy_pdbs()
# vcpkg_cmake_config_fixup(PACKAGE_NAME ... CONFIG_PATH share/cmake/${PORT})

if(NOT VCPKG_CROSSCOMPILING)
    vcpkg_copy_tools(TOOL_NAMES ${TOOL_TARGET_NAMES} AUTO_CLEAN)
endif()

file(INSTALL "${SOURCE_PATH}/README.md" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/debug/docs"
    "${CURRENT_PACKAGES_DIR}/debug/LICENSE"
    "${CURRENT_PACKAGES_DIR}/debug/README.md"
    "${CURRENT_PACKAGES_DIR}/LICENSE"
)
file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME "copyright")
