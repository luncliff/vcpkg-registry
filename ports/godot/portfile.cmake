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
)

# 1. Prepare required tools: https://scons.org/
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
# set(ENV{SCONS_FLAGS} "--tree=all")
list(APPEND SCONS_ARGS verbose=yes)
if(VCPKG_TARGET_IS_WINDOWS)
    set(ENV{SCONS_CACHE_MSVC_CONFIG} "false")
    list(APPEND SCONS_ARGS platform=windows vsproj=yes windows_subsystem=console)
endif()

message(STATUS "Building template_debug")
set(BUILDTREES_DIR_DBG "${SOURCE_PATH}")
vcpkg_execute_required_process(
    COMMAND "${SCONS_EXE}" -j ${VCPKG_CONCURRENCY} debug_symbols=yes target=template_debug
        ${SCONS_ARGS} module_text_server_fb_enabled=yes
    WORKING_DIRECTORY "${BUILDTREES_DIR_DBG}"
    LOGNAME "template-${TARGET_TRIPLET}-dbg"
)

message(STATUS "Building template_release")
set(BUILDTREES_DIR_REL "${SOURCE_PATH}")
vcpkg_execute_required_process(
    COMMAND "${SCONS_EXE}" -j ${VCPKG_CONCURRENCY} debug_symbols=no target=template_release
        ${SCONS_ARGS} module_text_server_fb_enabled=yes
    WORKING_DIRECTORY "${BUILDTREES_DIR_REL}"
    LOGNAME "template-${TARGET_TRIPLET}-rel"
)

message(STATUS "Building editor")
vcpkg_execute_required_process(
    COMMAND "${SCONS_EXE}" -j ${VCPKG_CONCURRENCY} debug_symbols=no target=editor
        ${SCONS_ARGS} module_text_server_fb_enabled=yes
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
