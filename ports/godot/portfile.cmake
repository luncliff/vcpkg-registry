# see https://docs.godotengine.org/en/latest/contributing/development/compiling/index.html
# see https://github.com/godotengine/godot/blob/master/.github/workflows/
if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
else()
    message(FATAL_ERROR "Work in progress")
endif()

# todo: replace ${SOURCE_PATH}/thirdparty to vcpkg installed libraries
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO godotengine/godot
    REF "${VERSION}-stable"
    SHA512 23d7a1c1f1d26266313b4abdb113854efd2567c5c210445c9b544e10289906494eb33a6169c0d48f71436bad5a7a55cc4ed98b8842b39d41969274ea3ab67cd0
    HEAD_REF master
    PATCHES
        fix-scons.patch
)

# todo: move thirdparty to ports
if(FALSE)
file(REMOVE_RECURSE
    # ${SOURCE_PATH}/thirdparty/amd-fsr
    # ${SOURCE_PATH}/thirdparty/amd-fsr2
    ${SOURCE_PATH}/thirdparty/angle
    # ${SOURCE_PATH}/thirdparty/astcenc
    ${SOURCE_PATH}/thirdparty/basis_universal
    ${SOURCE_PATH}/thirdparty/brotli
    ${SOURCE_PATH}/thirdparty/certs
    ${SOURCE_PATH}/thirdparty/clipper2
    # ${SOURCE_PATH}/thirdparty/cvtt
    ${SOURCE_PATH}/thirdparty/doctest
    ${SOURCE_PATH}/thirdparty/embree
    ${SOURCE_PATH}/thirdparty/enet
    ${SOURCE_PATH}/thirdparty/etcpak
    ${SOURCE_PATH}/thirdparty/fonts
    ${SOURCE_PATH}/thirdparty/freetype
    ${SOURCE_PATH}/thirdparty/glad
    ${SOURCE_PATH}/thirdparty/glslang
    ${SOURCE_PATH}/thirdparty/graphite
    ${SOURCE_PATH}/thirdparty/harfbuzz
    ${SOURCE_PATH}/thirdparty/icu4c
    # ${SOURCE_PATH}/thirdparty/jpeg-compressor
    ${SOURCE_PATH}/thirdparty/libktx
    ${SOURCE_PATH}/thirdparty/libogg
    ${SOURCE_PATH}/thirdparty/libpng
    ${SOURCE_PATH}/thirdparty/libtheora
    ${SOURCE_PATH}/thirdparty/libvorbis
    ${SOURCE_PATH}/thirdparty/libwebp
    # ${SOURCE_PATH}/thirdparty/linuxbsd_headers
    ${SOURCE_PATH}/thirdparty/mbedtls
    ${SOURCE_PATH}/thirdparty/meshoptimizer
    ${SOURCE_PATH}/thirdparty/mingw-std-threads
    ${SOURCE_PATH}/thirdparty/minimp3
    ${SOURCE_PATH}/thirdparty/miniupnpc
    ${SOURCE_PATH}/thirdparty/minizip
    # ${SOURCE_PATH}/thirdparty/misc
    ${SOURCE_PATH}/thirdparty/msdfgen
    ${SOURCE_PATH}/thirdparty/noise
    # ${SOURCE_PATH}/thirdparty/nvapi
    ${SOURCE_PATH}/thirdparty/openxr
    ${SOURCE_PATH}/thirdparty/pcre2
    ${SOURCE_PATH}/thirdparty/recastnavigation
    ${SOURCE_PATH}/thirdparty/rvo2
    ${SOURCE_PATH}/thirdparty/spirv-reflect
    ${SOURCE_PATH}/thirdparty/squish
    ${SOURCE_PATH}/thirdparty/thorvg
    ${SOURCE_PATH}/thirdparty/tinyexr
    # ${SOURCE_PATH}/thirdparty/vhacd
    ${SOURCE_PATH}/thirdparty/volk
    ${SOURCE_PATH}/thirdparty/vulkan
    # ${SOURCE_PATH}/thirdparty/wslay
    ${SOURCE_PATH}/thirdparty/xatlas
    ${SOURCE_PATH}/thirdparty/zlib
    ${SOURCE_PATH}/thirdparty/zstd
)
endif()

# 1. Prepare required tools: https://scons.org/
vcpkg_find_acquire_program(PKGCONFIG)
get_filename_component(PKGCONFIG_PATH "${PKGCONFIG}" DIRECTORY)
vcpkg_add_to_path(PREPEND "${PKGCONFIG_PATH}")
message(STATUS "Using pkg-config: ${PKGCONFIG}")

# vcpkg_find_acquire_program(PYTHON3)
x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    PACKAGES scons
    OUT_PYTHON_VAR PYTHON3
)
get_filename_component(PYTHON_PATH "${PYTHON3}" DIRECTORY)
vcpkg_add_to_path(PREPEND "${PYTHON_PATH}")
message(STATUS "Using python3: ${PYTHON3}")

find_program(SCONS_EXE NAMES scons PATHS "${PYTHON_PATH}" REQUIRED )
message(STATUS "Using scons: ${SCONS_EXE}")

# 2. Run build of targets
# Check "${SOURCE_PATH}/SConstruct" for detailed options
set(ENV{VCPKG_INSTALLED_DIR} "${CURRENT_INSTALLED_DIR}")

# set(ENV{SCONS_FLAGS} "--tree=all")
list(APPEND SCONS_ARGS verbose=true
    module_text_server_fb_enabled=true
    builtin_brotli=false
    builtin_certs=false
    builtin_embree=false
    builtin_enet=false
    builtin_freetype=false
    builtin_msdfgen=false
    builtin_glslang=false
    builtin_graphite=false
    builtin_harfbuzz=false
    builtin_icu4c=false
    builtin_libogg=false
    builtin_libpng=false
    builtin_libtheora=false
    builtin_libvorbis=false
    builtin_libwebp=false
    builtin_wslay=false
    builtin_mbedtls=false
    builtin_miniupnpc=false
    builtin_openxr=false
    builtin_pcre2=false
    builtin_pcre2_with_jit=false
    builtin_recastnavigation=false
    builtin_rvo2_2d=false
    builtin_rvo2_3d=false
    builtin_squish=false
    builtin_xatlas=false
    builtin_zlib=false
    builtin_zstd=false
)
if ("test" IN_LIST FEATURES)
    list(APPEND SCONS_ARGS tests=true)
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    set(ENV{SCONS_CACHE_MSVC_CONFIG} "false")
    list(APPEND SCONS_ARGS platform=windows vsproj=true windows_subsystem=console)
endif()

message(STATUS "Building template_debug")
set(BUILDTREES_DIR_DBG "${SOURCE_PATH}")
set(ENV{PKG_CONFIG_PATH} "${CURRENT_INSTALLED_DIR}/debug/lib/pkgconfig")
vcpkg_execute_required_process(
    COMMAND "${SCONS_EXE}" -j ${VCPKG_CONCURRENCY} debug_symbols=true target=template_debug
        ${SCONS_ARGS}
    WORKING_DIRECTORY "${BUILDTREES_DIR_DBG}"
    LOGNAME "template-${TARGET_TRIPLET}-dbg"
)

message(STATUS "Building template_release")
set(BUILDTREES_DIR_REL "${SOURCE_PATH}")
set(ENV{PKG_CONFIG_PATH} "${CURRENT_INSTALLED_DIR}/lib/pkgconfig")
vcpkg_execute_required_process(
    COMMAND "${SCONS_EXE}" -j ${VCPKG_CONCURRENCY} debug_symbols=false target=template_release
        ${SCONS_ARGS}
    WORKING_DIRECTORY "${BUILDTREES_DIR_REL}"
    LOGNAME "template-${TARGET_TRIPLET}-rel"
)

message(STATUS "Building editor")
vcpkg_execute_required_process(
    COMMAND "${SCONS_EXE}" -j ${VCPKG_CONCURRENCY} debug_symbols=false target=editor
        ${SCONS_ARGS}
    WORKING_DIRECTORY "${BUILDTREES_DIR_REL}"
    LOGNAME "editor-${TARGET_TRIPLET}-rel"
)

# 3. Installation
if(VCPKG_TARGET_IS_WINDOWS)
    file(GLOB GODOT_BIN_DBG "${BUILDTREES_DIR_DBG}/bin/godot.*.template_debug.*.exe"
                            "${BUILDTREES_DIR_DBG}/bin/godot.*.template_debug.*.pdb"
    )
    file(INSTALL ${GODOT_BIN_DBG} DESTINATION "${CURRENT_PACKAGES_DIR}/debug/bin")
    vcpkg_copy_tools(
        TOOL_NAMES "godot.windows.template_debug.x86_64"
        SEARCH_DIR "${CURRENT_PACKAGES_DIR}/debug/bin"
        AUTO_CLEAN
    )

    file(GLOB GODOT_BIN_REL "${BUILDTREES_DIR_REL}/bin/godot.*.template_release.*.exe"
                            "${BUILDTREES_DIR_REL}/bin/godot.*.template_release.*.pdb"
                            "${BUILDTREES_DIR_REL}/bin/godot.*.editor.*.exe"
    )
    file(INSTALL ${GODOT_BIN_REL} DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
    vcpkg_copy_tools(
        TOOL_NAMES "godot.windows.template_release.x86_64" "godot.windows.editor.x86_64"
        SEARCH_DIR "${CURRENT_PACKAGES_DIR}/bin"
        AUTO_CLEAN
    )

    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
