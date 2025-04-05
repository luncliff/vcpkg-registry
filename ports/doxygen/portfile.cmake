vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO doxygen/doxygen
    REF Release_1_13_2
    SHA512 ec9e0c40c87a2a9477203b6df66323ca221468013094980e17965fa5a631d97af6286a66d7010c5ed94b825dd4e7bc8db18a48f30aa48b9a2e4f0ca6d9a5ddf0
    HEAD_REF master
    PATCHES
        fix-cmake.patch
)
# todo: replace libmd5, libmscgen, lodepng embedded dependencies 
file(REMOVE_RECURSE
    "${SOURCE_PATH}/deps/iconv_winbuild"
    "${SOURCE_PATH}/deps/spdlog"
    "${SOURCE_PATH}/deps/sqlite3"
    # "${SOURCE_PATH}/deps/lodepng" # required by libmscgen
    "${SOURCE_PATH}/deps/filesystem" # use 'ghc-filesystem' in vcpkg
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        clang   use_libclang
        gui     build_wizard # Build the GUI frontend for doxygen
        docs    build_doc
        docs    build_doc_chm
)

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_MT)

vcpkg_find_acquire_program(PYTHON3)
message(STATUS "using python3: ${PYTHON3}")
vcpkg_find_acquire_program(BISON)
message(STATUS "using bison: ${BISON}")
vcpkg_find_acquire_program(FLEX)
message(STATUS "using flex: ${FLEX}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -Duse_sys_spdlog=ON
        -Duse_sys_sqlite3=ON
        -Dwin_static=USE_MT
        "-DPYTHON_EXECUTABLE=${PYTHON3}"
        "-DPython_EXECUTABLE=${PYTHON3}"
        "-DBISON_EXECUTABLE=${BISON}"
        "-DFLEX_EXECUTABLE=${FLEX}"
        -DICONV_DIR=${CURRENT_INSTALLED_DIR}
    OPTIONS_DEBUG
        -Denable_lex_debug=ON
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME absl CONFIG_PATH lib/cmake/absl)
vcpkg_fixup_pkgconfig()

vcpkg_copy_pdbs()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share"
                    "${CURRENT_PACKAGES_DIR}/debug/include"
                    "${CURRENT_PACKAGES_DIR}/include/absl/copts"
                    "${CURRENT_PACKAGES_DIR}/include/absl/strings/testdata"
                    "${CURRENT_PACKAGES_DIR}/include/absl/time/internal/cctz/testdata"
)

if(VCPKG_TARGET_IS_WINDOWS AND VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/absl/base/config.h" "defined(ABSL_CONSUME_DLL)" "1")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/absl/base/internal/thread_identity.h" "defined(ABSL_CONSUME_DLL)" "1")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
