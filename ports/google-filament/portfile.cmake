if(VCPKG_CROSSCOMPILING)
    message(WARNING "Cross compiling is NOT tested")
endif()
vcpkg_find_acquire_program(PKGCONFIG)
message(STATUS "Using pkgconfig: ${PKGCONFIG}")

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/filament
    REF v1.40.0
    SHA512 479e90710f140f05e07b29fde361ce25841d46da80c123ef99594a2dc253588c6bb561a1ad93580c26280793b1a47c1f89b32e31ac52b00a2fb744c15ee515ba
    PATCHES
        fix-cmake.patch
        fix-sources.patch
)

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

message(STATUS "Editing third_party folder ...")
function(edit_third_party SRC_PORT DST_NAME)
    get_filename_component(DST_DIR "${SOURCE_PATH}/third_party/${DST_NAME}" ABSOLUTE)
    get_filename_component(DST_PATH "${DST_DIR}/LICENSE" ABSOLUTE)
    file(REMOVE_RECURSE "${DST_DIR}")
    file(MAKE_DIRECTORY "${DST_DIR}")
    file(COPY_FILE "${CURRENT_INSTALLED_DIR}/share/${SRC_PORT}/copyright" "${DST_PATH}")
endfunction()
edit_third_party(glslang glslang)
edit_third_party(assimp libassimp)
edit_third_party(libpng libpng)
edit_third_party(spirv-cross spirv-cross)
edit_third_party(spirv-tools spirv-tools)
edit_third_party(stb stb)
edit_third_party(mikktspace mikktspace)
edit_third_party(meshoptimizer meshoptimizer)
edit_third_party(tinyexr tinyexr)
edit_third_party(zlib libz)
edit_third_party(sdl2 libsdl2)
edit_third_party(draco draco)
edit_third_party(gtest libgtest)
edit_third_party(benchmark benchmark)
edit_third_party(civetweb civetweb)
edit_third_party(basis-universal basisu)
edit_third_party(cgltf cgltf)
edit_third_party(imgui imgui)
edit_third_party(jsmn jsmn)
edit_third_party(robin-map robin-map)

if(VCPKG_TARGET_IS_WINDOWS)
    edit_third_party(getopt-win32 getopt)
endif()
if("vulkan" IN_LIST FEATURES)
    edit_third_party(vulkan-memory-allocator vkmemalloc)
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        gles3   FILAMENT_USE_EXTERNAL_GLES3
        gles3   FILAMENT_SUPPORTS_OPENGL
        vulkan  FILAMENT_SUPPORTS_VULKAN
        metal   FILAMENT_SUPPORTS_METAL
    INVERTED_FEATURES
        samples FILAMENT_SKIP_SDL2
        samples FILAMENT_SKIP_SAMPLES
)

if(VCPKG_TARGET_IS_WINDOWS)
    list(APPEND GENERATOR_OPTIONS WINDOWS_USE_MSBUILD)
else()
    list(APPEND GENERATOR_OPTIONS GENERATOR Ninja)
endif()

# todo: more precise control for gles3/vulkan features
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    ${GENERATOR_OPTIONS}
    OPTIONS
        ${FEATURE_OPTIONS}
        -DPKG_CONFIG_EXECUTABLE:FILEPATH=${PKGCONFIG}
        -DCMAKE_CROSSCOMPILING=${VCPKG_CROSSCOMPILING}
        -DFILAMENT_SUPPORTS_XCB=${VCPKG_TARGET_IS_LINUX}
        -DFILAMENT_SUPPORTS_XLIB=${VCPKG_TARGET_IS_LINUX}
        -DFILAMENT_SUPPORTS_WAYLAND=${VCPKG_TARGET_IS_LINUX}
        -DFILAMENT_SUPPORTS_EGL_ON_LINUX=${VCPKG_TARGET_IS_LINUX}
        -DFILAMENT_ENABLE_ASAN_UBSAN=OFF
        -DFILAMENT_ENABLE_LTO=ON
        -DFILAMENT_ENABLE_MATDBG=OFF # matdbg, matdbg_resources
        -DFILAMENT_BUILD_FILAMAT=ON
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
    message(STATUS "Building tools ...")
    list(APPEND TOOL_TARGET_NAMES
        resgen glslminifier matc cmgen mipgen uberz filamesh # matinfo
        normal-blending roughness-prefilter specular-color
    )
    foreach(NAME ${TOOL_TARGET_NAMES})
        vcpkg_cmake_build(TARGET ${NAME} LOGFILE_BASE build-${NAME} ADD_BIN_TO_PATH)
    endforeach()
    message(STATUS "Building shaders ...")
    vcpkg_cmake_build(TARGET shaders LOGFILE_BASE build-shaders ADD_BIN_TO_PATH)
endif()

message(STATUS "Building libraries ...")
vcpkg_cmake_build(TARGET filament LOGFILE_BASE build-filament ADD_BIN_TO_PATH)
vcpkg_cmake_install(ADD_BIN_TO_PATH)
vcpkg_copy_pdbs()

if(NOT VCPKG_CROSSCOMPILING)
    vcpkg_copy_tools(TOOL_NAMES ${TOOL_TARGET_NAMES} AUTO_CLEAN)
    if("samples" IN_LIST FEATURES)
        vcpkg_copy_tools(TOOL_NAMES gltf_viewer material_sandbox AUTO_CLEAN)
    endif()
endif()

file(COPY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/shaders/minified"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
file(COPY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/filament/generated/material"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

file(INSTALL "${SOURCE_PATH}/README.md" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/debug/docs"
    "${CURRENT_PACKAGES_DIR}/share/LICENSE"
    "${CURRENT_PACKAGES_DIR}/share/README.md"
)
file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME "copyright")
