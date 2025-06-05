
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO v8/v8
    REF 13.9.90
    SHA512 0
)

# vcpkg_get_windows_sdk(WINDOWS_SDK)
# if (WINDOWS_SDK MATCHES "10.")
#     set(LIBFILEPATH "$ENV{WindowsSdkDir}Lib\\${WINDOWS_SDK}\\um\\${TRIPLET_SYSTEM_ARCH}\\Ws2_32.Lib")
#     set(HEADERSPATH "$ENV{WindowsSdkDir}Include\\${WINDOWS_SDK}\\um")
# else()
#     message(FATAL_ERROR "Portfile not yet configured for Windows SDK with version: ${WINDOWS_SDK}")
# endif()

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
