if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
else()
    message(FATAL_ERROR "Work in progress")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO godotengine/godot
    REF 4.1.2-stable
    SHA512 691a225fbcd5fc242a20b4e49394728ab7db58669e1badfb81d36bad2d4bee3f85d4e99805332d6e97aca48c3f592b1c36bbfc18a3a5a40fb5809f8d8b0f42c7
    HEAD_REF master
)

# vcpkg_find_acquire_program(PYTHON3)
x_vcpkg_get_python_packages(
      PYTHON_VERSION 3
      PACKAGES scons
      OUT_PYTHON_VAR PYTHON3
)
message(STATUS "Using python3: ${PYTHON3}")

get_filename_component(PYTHON_PATH "${PYTHON3}" DIRECTORY)
vcpkg_add_to_path(PREPEND "${PYTHON_PATH}")

find_program(SCONS_EXE NAMES scons PATHS "${PYTHON_PATH}" REQUIRED )
message(STATUS "Using scons: ${SCONS_EXE}")

# see https://github.com/godotengine/godot/blob/master/.github/workflows/
set(ENV{SCONS_CACHE_MSVC_CONFIG} "false")

# scons platform=${{ inputs.platform }} target=${{ inputs.target }} tests=${{ inputs.tests }} ${{ env.SCONSFLAGS }}
message(STATUS "Building ${TARGET_TRIPLET}-dbg")
set(BUILDTREES_DIR_DBG "${SOURCE_PATH}")
vcpkg_execute_required_process(
    COMMAND ${SCONS_EXE} verbose=yes target=template_debug debug_symbols=yes
        platform=windows vsproj=yes windows_subsystem=console
        module_text_server_fb_enabled=yes
    WORKING_DIRECTORY "${BUILDTREES_DIR_DBG}"
    LOGNAME "install-${TARGET_TRIPLET}-dbg"
)

message(STATUS "Building ${TARGET_TRIPLET}-rel")
set(BUILDTREES_DIR_REL "${SOURCE_PATH}")
vcpkg_execute_required_process(
    COMMAND ${SCONS_EXE} verbose=yes target=template_release
        platform=windows vsproj=yes windows_subsystem=console
        module_text_server_fb_enabled=yes
    WORKING_DIRECTORY "${BUILDTREES_DIR_REL}"
    LOGNAME "install-${TARGET_TRIPLET}-rel"
)

vcpkg_copy_pdbs()
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
