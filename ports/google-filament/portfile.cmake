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
        fix-sources2.patch
)
file(APPEND "${SOURCE_PATH}/.gitignore" "\nthird_party\n")

file(REMOVE_RECURSE
    "${SOURCE_PATH}/android"
    "${SOURCE_PATH}/ios"
    "${SOURCE_PATH}/web"
    "${SOURCE_PATH}/docs"
    "${SOURCE_PATH}/site"
    "${SOURCE_PATH}/third_party/basisu"
    "${SOURCE_PATH}/third_party/civetweb"
    "${SOURCE_PATH}/third_party/benchmark"
    "${SOURCE_PATH}/third_party/cgltf"
    "${SOURCE_PATH}/third_party/clang"
    # "${SOURCE_PATH}/third_party/getopt"
    # "${SOURCE_PATH}/third_party/glslang"
    "${SOURCE_PATH}/third_party/imgui"
    "${SOURCE_PATH}/third_party/jsmn"
    # "${SOURCE_PATH}/third_party/libassimp"
    "${SOURCE_PATH}/third_party/libgtest"
    # "${SOURCE_PATH}/third_party/libpng"
    "${SOURCE_PATH}/third_party/libsdl2"
    # "${SOURCE_PATH}/third_party/libz"
    # "${SOURCE_PATH}/third_party/meshoptimizer"
    "${SOURCE_PATH}/third_party/robin-map"
    # "${SOURCE_PATH}/third_party/spirv-cross"
    # "${SOURCE_PATH}/third_party/spirv-tools"
    # "${SOURCE_PATH}/third_party/stb"
    "${SOURCE_PATH}/third_party/draco"
    "${SOURCE_PATH}/third_party/gl-matrix"
    "${SOURCE_PATH}/third_party/gltumble"
    "${SOURCE_PATH}/third_party/markdeep"
    "${SOURCE_PATH}/third_party/vkmemalloc"
    # "${SOURCE_PATH}/third_party/tinyexr"
    "${SOURCE_PATH}/third_party/mikktspace"
)

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

if(NOT VCPKG_CROSSCOMPILING)
    # some targets requires tools for resource generation
    list(APPEND TOOL_TARGET_NAMES resgen glslminifier matc cmgen mipgen uberz filamesh)
    foreach(NAME ${TOOL_TARGET_NAMES})
        message(STATUS "Target: ${NAME} ...")
        vcpkg_cmake_build(TARGET ${NAME} ADD_BIN_TO_PATH LOGFILE_BASE build-${NAME})
    endforeach()
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