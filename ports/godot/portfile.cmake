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
    REF 4.1.2-stable
    SHA512 691a225fbcd5fc242a20b4e49394728ab7db58669e1badfb81d36bad2d4bee3f85d4e99805332d6e97aca48c3f592b1c36bbfc18a3a5a40fb5809f8d8b0f42c7
    HEAD_REF master
    # PATCHES
    #     fix-scons.patch
)

# todo: move thirdparty to ports
# file(GLOB_RECURSE THIRD_SOURCES
#     "${SOURCE_PATH}/thirdparty/*.h"
#     "${SOURCE_PATH}/thirdparty/*.c"
#     "${SOURCE_PATH}/thirdparty/*.hpp"
#     "${SOURCE_PATH}/thirdparty/*.cpp"
# )
# if(THIRD_SOURCES)
#     file(REMOVE ${THIRD_SOURCES})
# endif()

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
