# https://v8.dev/docs/build

vcpkg_find_acquire_program(GIT)
get_filename_component(GIT_PATH "${GIT}" DIRECTORY)
vcpkg_add_to_path(PREPEND "${GIT_PATH}")

vcpkg_find_acquire_program(GN)
get_filename_component(GN_PATH "${GN}" DIRECTORY)
vcpkg_add_to_path(PREPEND "${GN_PATH}")

vcpkg_find_acquire_program(NINJA)
get_filename_component(NINJA_PATH "${NINJA}" DIRECTORY)
vcpkg_add_to_path(PREPEND "${NINJA_PATH}")

vcpkg_find_acquire_program(PKGCONFIG)
get_filename_component(PKGCONFIG_PATH "${PKGCONFIG}" DIRECTORY)
vcpkg_add_to_path(PREPEND "${PKGCONFIG_PATH}")

x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    OUT_PYTHON_VAR PYTHON3
    PACKAGES httplib2
)
message(STATUS "Using python: ${PYTHON3}")
get_filename_component(PYTHON_PATH "${PYTHON3}" DIRECTORY)
vcpkg_add_to_path(PREPEND "${PYTHON_PATH}")

vcpkg_from_git(
    OUT_SOURCE_PATH TOOLS_SOURCE_PATH
    URL "https://chromium.googlesource.com/chromium/tools/depot_tools.git"
    REF 6d52c22ee313eb5701f326a9eca98acb41b669b4
)
vcpkg_add_to_path(PREPEND "${TOOLS_SOURCE_PATH}")

find_program(GCLIENT NAMES gclient.py PATHS "${TOOLS_SOURCE_PATH}" REQUIRED)
message(STATUS "Using gclient: ${GCLIENT}")

vcpkg_download_distfile(ARCHIVE
    URLS "https://github.com/v8/v8/archive/refs/tags/${VERSION}.zip"
    FILENAME "v8-${VERSION}.zip"
    SHA512 3d8ce9f2071cbba26788d3d570a92ca609700bdf4094563e9c654d3e26a10dfee150b1412870f6a051cdb6511b122de3aa3d98d9a7b751a83cd8b5d9f3f6c950
)

vcpkg_extract_source_archive(SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    # PATCHES
    #     # ...
)

vcpkg_execute_required_process(
    COMMAND "${PYTHON3}" "${GCLIENT}" sync
    WORKING_DIRECTORY ${SOURCE_PATH}
    LOGNAME gclient-sync
)

# vcpkg_get_windows_sdk(WINDOWS_SDK)
# if (WINDOWS_SDK MATCHES "10.")
#     set(LIBFILEPATH "$ENV{WindowsSdkDir}Lib\\${WINDOWS_SDK}\\um\\${TRIPLET_SYSTEM_ARCH}\\Ws2_32.Lib")
#     set(HEADERSPATH "$ENV{WindowsSdkDir}Include\\${WINDOWS_SDK}\\um")
# else()
#     message(FATAL_ERROR "Portfile not yet configured for Windows SDK with version: ${WINDOWS_SDK}")
# endif()

vcpkg_add_to_path(PREPEND "${CURRENT_INSTALLED_DIR}/bin")
vcpkg_add_to_path(PREPEND "${CURRENT_INSTALLED_DIR}/debug/bin")

if(VCPKG_LIBRARY_LINKAGE STREQUAL dynamic)
    set(is_component_build true)
    set(v8_monolithic false)
    set(v8_use_external_startup_data true)
    set(targets :v8_libbase :v8_libplatform :v8)
else()
    set(is_component_build false)
    set(v8_monolithic true)
    set(v8_use_external_startup_data false)
    set(targets :v8_monolith)
endif()

vcpkg_gn_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS "is_component_build=${is_component_build} target_cpu=\"${VCPKG_TARGET_ARCHITECTURE}\" v8_monolithic=${v8_monolithic} v8_use_external_startup_data=${v8_use_external_startup_data} use_sysroot=false is_clang=false use_custom_libcxx=false v8_enable_verify_heap=false icu_use_data_file=false" 
    OPTIONS_DEBUG "is_debug=true enable_iterator_debugging=true pkg_config_libdir=\"${UNIX_CURRENT_INSTALLED_DIR}/debug/lib/pkgconfig\""
    OPTIONS_RELEASE "is_debug=false enable_iterator_debugging=false pkg_config_libdir=\"${UNIX_CURRENT_INSTALLED_DIR}/lib/pkgconfig\""
)
vcpkg_gn_install(
    SOURCE_PATH "${SOURCE_PATH}"
    TARGETS ${targets}
)
# file(INSTALL "${SOURCE_PATH}/include" DESTINATION "${CURRENT_PACKAGES_DIR}/include" FILES_MATCHING PATTERN "*.h")


# vcpkg_copy_pdbs()
# vcpkg_fixup_pkgconfig(SYSTEM_LIBRARIES m dl pthread Winmm DbgHelp v8_libbase v8_libplatform v8)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
