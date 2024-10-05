if(VCPKG_CROSSCOMPILING)
    message(WARNING "Cross compiling is NOT tested")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/filament
    REF v1.54.5
    SHA512 63f43987bd00fbc752f29755a49e0f65bc1ceeb0b6510d43d6da3964ccd06f20fe7f02f631dacd5c0387918e389416cf7818eaf1d3bcc70f7fb98ff2fbdbf59e
    PATCHES
        fix-cmake.patch
        fix-sources.patch
)

message(STATUS "Editing third_party folder ...")
function(edit_third_party SRC_PORT DST_NAME)
    if(NOT DEFINED FILENAME)
        set(FILENAME LICENSE)
    endif()
    get_filename_component(DST_DIR "${SOURCE_PATH}/third_party/${DST_NAME}" ABSOLUTE)
    file(REMOVE_RECURSE "${DST_DIR}")
    file(MAKE_DIRECTORY "${DST_DIR}")
    file(COPY_FILE "${CURRENT_INSTALLED_DIR}/share/${SRC_PORT}/copyright" "${DST_DIR}/${FILENAME}")
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
edit_third_party(sdl2 libsdl2)
edit_third_party(draco draco)
edit_third_party(civetweb civetweb)
edit_third_party(basis-universal basisu)
edit_third_party(cgltf cgltf)
edit_third_party(imgui imgui)
edit_third_party(jsmn jsmn)
edit_third_party(robin-map robin-map)
edit_third_party(smol-v smol-v)

if(VCPKG_TARGET_IS_WINDOWS)
    edit_third_party(getopt-win32 getopt)
endif()
if("vulkan" IN_LIST FEATURES)
    edit_third_party(vulkan-memory-allocator vkmemalloc) # LICENSE.txt
endif()
if("test" IN_LIST FEATURES)
    edit_third_party(gtest libgtest)
    edit_third_party(benchmark benchmark)
endif()

function(copy_license DST_NAME FILE)
    get_filename_component(DST_DIR "${SOURCE_PATH}/third_party/${DST_NAME}" ABSOLUTE)
    file(REMOVE_RECURSE "${DST_DIR}")
    file(MAKE_DIRECTORY "${DST_DIR}")
    file(COPY_FILE "${FILE}" "${DST_DIR}/LICENSE")
endfunction()
copy_license(libz ${CMAKE_CURRENT_LIST_DIR}/copyrights/libz.txt)

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
    # list(APPEND GENERATOR_OPTIONS WINDOWS_USE_MSBUILD)
else()
    list(APPEND GENERATOR_OPTIONS GENERATOR Ninja)
endif()

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_STATIC_CRT)

# todo: more precise control for gles3/vulkan features
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    ${GENERATOR_OPTIONS}
    OPTIONS
        ${FEATURE_OPTIONS}
        -DUSE_STATIC_CRT=${USE_STATIC_CRT}
        -DCMAKE_CROSSCOMPILING=${VCPKG_CROSSCOMPILING}
        -DFILAMENT_SUPPORTS_XCB=${VCPKG_TARGET_IS_LINUX}
        -DFILAMENT_SUPPORTS_XLIB=${VCPKG_TARGET_IS_LINUX}
        -DFILAMENT_SUPPORTS_WAYLAND=${VCPKG_TARGET_IS_LINUX}
        -DFILAMENT_SUPPORTS_EGL_ON_LINUX=${VCPKG_TARGET_IS_LINUX}
        -DFILAMENT_BUILD_FILAMAT=OFF
        -DFILAMENT_ENABLE_MATDBG=OFF # material debugger: matdbg, matdbg_resources
        -DFILAMENT_DISABLE_MATOPT=ON # material optimization
        -DFILAMENT_SHORTEN_MSVC_COMPILATION=OFF # disable _ITERATOR_DEBUG_LEVEL customization
)

# some targets requires tools for resource generation
if(VCPKG_CROSSCOMPILING)
    vcpkg_add_to_path(PREPEND "${CURRENT_HOST_INSTALLED_DIR}/bin")
    vcpkg_add_to_path(PREPEND "${CURRENT_HOST_INSTALLED_DIR}/tools/${PORT}")
else()
    message(STATUS "Building shaders ...")
    vcpkg_cmake_build(TARGET shaders LOGFILE_BASE build-shaders ADD_BIN_TO_PATH)
endif()
message(STATUS "Building filament ...")
vcpkg_cmake_build(TARGET filament LOGFILE_BASE build-filament ADD_BIN_TO_PATH)
vcpkg_cmake_install(ADD_BIN_TO_PATH)
vcpkg_copy_pdbs()

if(NOT VCPKG_CROSSCOMPILING)
    list(APPEND TOOL_TARGET_NAMES
        resgen glslminifier matc cmgen mipgen uberz filamesh # matinfo
        normal-blending roughness-prefilter specular-color
    )
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
