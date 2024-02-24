set(VCPKG_BUILD_TYPE debug) # Work In Progress
vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY) 

# See https://openjdk.org/groups/build/doc/building.html or doc/building.md
# Prepare toolchains like BASH, MAKE, and BOOTJDK_PATH...
if(VCPKG_TARGET_IS_WINDOWS)
    include(${CMAKE_CURRENT_LIST_DIR}/setup-windows.cmake)
endif()
if(NOT DEFINED BOOTJDK_PATH)
    message(FATAL_ERROR "BOOTJDK_PATH is required")
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO openjdk/jdk
    REF jdk-23+10
    SHA512 cccb0150c3662426a668b11f3d4b0652df53a421c39a42d88fc177f25f04df0ced6cb7ba5e47a44edb79d13d1677ca5877e066b2f98a7edac49ed7975fa61736
    HEAD_REF master
)
# todo: use "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}|rel"?

vcpkg_execute_required_process(
    COMMAND ${BASH} configure --help
    LOGNAME configure-help-${TARGET_TRIPLET}
    WORKING_DIRECTORY "${SOURCE_PATH}"
)

# todo: replace zip, freetype, etc

message(STATUS "Configuring ${TARGET_TRIPLET}")
vcpkg_execute_required_process(
    COMMAND ${BASH} configure
        "--prefix=${CURRENT_PACKAGES_DIR}"
        "--exec-prefix=${CURRENT_PACKAGES_DIR}"
        "--enable-debug" # replaces "--with-debug-level=fastdebug"
        "--with-version-string=23+10"
        "--with-boot-jdk=${BOOTJDK_PATH}"
        "--with-jvm-variants=server" # client, minimal, etc
        "--with-target-bits=64"
        "--with-stdc++lib=${VCPKG_CRT_LINKAGE}" # dynamic, static, default        
        "--with-source-date=version"
    LOGNAME config-${TARGET_TRIPLET}
    WORKING_DIRECTORY "${SOURCE_PATH}"
)

vcpkg_execute_required_process(
    COMMAND ${MAKE} -f Makefile
        help
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME make-help-${TARGET_TRIPLET}
)

message(STATUS "Building ${TARGET_TRIPLET}")
vcpkg_execute_required_process(
    COMMAND ${MAKE} -f Makefile JOBS=${VCPKG_CONCURRENCY} LOG=info
        images docs # all
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME build-${TARGET_TRIPLET}
)

# message(STATUS "Testing ${TARGET_TRIPLET}")
# vcpkg_execute_required_process(
#     COMMAND ${MAKE} -f Makefile TEST_JOBS=${VCPKG_CONCURRENCY} LOG=info
#         check
#     WORKING_DIRECTORY "${SOURCE_PATH}"
#     LOGNAME test-${TARGET_TRIPLET}
# )

if(VCPKG_TARGET_IS_WINDOWS)
    set(OUTPUT_NAME "windows-x86_64-server-fastdebug")
endif()
get_filename_component(OUTPUT_DIR "${SOURCE_PATH}/build/${OUTPUT_NAME}/jdk" ABSOLUTE)

file(COPY "${OUTPUT_DIR}/" DESTINATION "${CURRENT_PACKAGES_DIR}")
if(VCPKG_TARGET_IS_WINDOWS)
    file(GLOB UNUSED_FILES
        "${CURRENT_PACKAGES_DIR}/bin/api-ms*.dll"
        "${CURRENT_PACKAGES_DIR}/bin/ucrtbase*.dll"
        "${CURRENT_PACKAGES_DIR}/bin/vcruntime*.dll"
        "${CURRENT_PACKAGES_DIR}/bin/msvc*.dll"
        "${CURRENT_PACKAGES_DIR}/bin/*.map"
        "${CURRENT_PACKAGES_DIR}/bin/*.pdb"
        "${CURRENT_PACKAGES_DIR}/bin/server/*.map"
        "${CURRENT_PACKAGES_DIR}/bin/server/*.pdb"
        "${CURRENT_PACKAGES_DIR}/_optimize_image_exec*"
        "${CURRENT_PACKAGES_DIR}/release"
    )
    file(REMOVE_RECURSE ${UNUSED_FILES})

    list(APPEND TOOLS
        jabswitch jaccessinspector jaccesswalker jar
        jarsigner java javac javadoc
        javap javaw jcmd jconsole
        jdb jdeprscan jdeps jfr
        jhsdb jimage jinfo jlink
        jmap jmod jpackage jps
        jrunscript jshell jstack jstat
        jstatd jwebserver keytool kinit
        klist ktab rmiregistry serialver
    )
    vcpkg_copy_tools(TOOL_NAMES ${TOOLS} AUTO_CLEAN)
endif()

file(INSTALL "${SOURCE_PATH}/README.md" "${SOURCE_PATH}/ADDITIONAL_LICENSE_INFO" 
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
