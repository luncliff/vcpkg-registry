vcpkg_find_acquire_program(PKGCONFIG)
message(STATUS "Using pkgconfig: ${PKGCONFIG}")

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/filament
    REF v1.37.0
    SHA512 c3bae22a0e96f5793b731bcc1d3be3a8c7ecc7d234bae2cd90446286b019c806bc72effebe23621888d6fcf0b0a14fad847048e97b79924d56c84fbd65edf557
    PATCHES
        fix-cmake.patch
        disable-static-lib-combine.patch
        enable-windows-gles3.patch
        fix-sources.patch
        fix-libs-viewer.patch
        fix-libs-matdbg.patch
        fix-cmake2.patch
)
file(APPEND "${SOURCE_PATH}/.gitignore" "\nthird_party\n")

function(leave_license SRC_PORT DST_NAME)
    get_filename_component(DST_DIR "${SOURCE_PATH}/third_party/${DST_NAME}" ABSOLUTE)
    get_filename_component(DST_PATH "${DST_DIR}/LICENSE" ABSOLUTE)
    file(REMOVE_RECURSE "${DST_DIR}")
    file(MAKE_DIRECTORY "${DST_DIR}")
    file(COPY_FILE "${CURRENT_INSTALLED_DIR}/share/${SRC_PORT}/copyright" "${DST_PATH}")
endfunction()

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
if(TRUE)
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
endif()
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

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    GENERATOR Ninja
    # WINDOWS_USE_MSBUILD
    OPTIONS
        -DDIST_DIR= # empty lib/bin suffix
        -DPKG_CONFIG_EXECUTABLE:FILEPATH=${PKGCONFIG}
        -DCMAKE_CROSSCOMPILING=${VCPKG_CROSSCOMPILING}
        ${FEATURE_OPTIONS}
        -DFILAMENT_SKIP_SDL2=ON
        -DFILAMENT_SKIP_SAMPLES=ON
        -DFILAMENT_SUPPORTS_XCB=${VCPKG_TARGET_IS_LINUX}
        -DFILAMENT_SUPPORTS_XLIB=${VCPKG_TARGET_IS_LINUX}
        -DFILAMENT_SUPPORTS_WAYLAND=${VCPKG_TARGET_IS_LINUX}
        -DFILAMENT_SUPPORTS_METAL=${VCPKG_TARGET_IS_OSX}
        -DFILAMENT_ENABLE_ASAN_UBSAN=OFF
        -DFILAMENT_ENABLE_LTO=ON
        -DFILAMENT_ENABLE_MATDBG=OFF
    OPTIONS_DEBUG
        -DFILAMENT_DISABLE_MATOPT=ON
    OPTIONS_RELEASE
        -DFILAMENT_DISABLE_MATOPT=OFF
)

vcpkg_cmake_build(TARGET uberarchive    LOGFILE_BASE build-uberarchive  DISABLE_PARALLEL ADD_BIN_TO_PATH)
vcpkg_cmake_build(TARGET gltfio         LOGFILE_BASE build-gltfio       ADD_BIN_TO_PATH)

# some targets requires tools for resource generation
if(VCPKG_CROSSCOMPILING)
    vcpkg_add_to_path(PREPEND "${CURRENT_HOST_INSTALLED_DIR}/bin")
    vcpkg_add_to_path(PREPEND "${CURRENT_HOST_INSTALLED_DIR}/tools/${PORT}")
else()
    list(APPEND TOOL_TARGET_NAMES resgen glslminifier matc cmgen mipgen uberz filamesh matinfo)
    foreach(NAME ${TOOL_TARGET_NAMES})
        message(STATUS "Target: ${NAME} ... ${CURRENT_BUILDTREES_DIR}/${PORT}/${TARGET_TRIPLET}-dbg/tools/${NAME}")
        vcpkg_cmake_build(TARGET ${NAME} LOGFILE_BASE build-${NAME} ADD_BIN_TO_PATH)
    endforeach()
    message(STATUS "Finished building tool targets")
endif()

vcpkg_cmake_install(ADD_BIN_TO_PATH)
vcpkg_copy_pdbs()
# vcpkg_cmake_config_fixup(PACKAGE_NAME ... CONFIG_PATH share/cmake/${PORT})

if(NOT VCPKG_CROSSCOMPILING)
    vcpkg_copy_tools(TOOL_NAMES ${TOOL_TARGET_NAMES} AUTO_CLEAN)
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
     
file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME "copyright")