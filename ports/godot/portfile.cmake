set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)
# set(VCPKG_POLICY_ALLOW_EXES_IN_BIN enabled)
# set(VCPKG_POLICY_CMAKE_HELPER_PORT enabled)

# https://www.reddit.com/r/godot/comments/1gw220q/latest_visual_studio_update_1712_broke_scons/
# https://github.com/godotengine/godot issue 95861
vcpkg_download_distfile(GODOT_PR_96167_PATCH
    URLS "https://github.com/godotengine/godot/pull/96167.diff?full_index=1"
    FILENAME "godot-fix-pr-96167.patch"
    SHA512 c0438cd49b0d7f2a39b95f4064e89ccea79e6ff4a9d5b3291af5f1c11f5bd4935b8b4b99c332947ad65e1d3f172adc03979717b74db0ea389da692b494fd8061
)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO godotengine/godot
    REF "${VERSION}-stable"
    SHA512 ce20235f1a5f8a5dc22f4bec6c4b5ab7c66aa3b35733f9fc26f905e564c4671df370c68db1ea65b205e00f29863d6d6f5ea6878996a4d69d32f728ecc91c8726
    HEAD_REF 4.3
    PATCHES
        "${GODOT_PR_96167_PATCH}"
)

function(make_linker_flag LIBNAME OUTPUT)
    if(VCPKG_TARGET_IS_WINDOWS)
        # for MSVC linker, use the library file's name
        find_library(LIBRARY NAMES ${LIBNAME} PATHS "${CURRENT_INSTALLED_DIR}/lib" NO_DEFAULT_PATH REQUIRED)
        get_filename_component(OPTION "${LIBRARY}" NAME)
    else()
        # for other linkers, use -l${LIBNAME}
        set(OPTION "-l${LIBNAME}")    
    endif()
    set(${OUTPUT} "${OPTION}" PARENT_SCOPE)
endfunction()

if("spine-runtimes" IN_LIST FEATURES)
    vcpkg_from_github(
        OUT_SOURCE_PATH SPINE_SOURCE_PATH
        REPO EsotericSoftware/spine-runtimes
        REF 1cdbf9be1a92e0a3015af8e0f0e1b05b872e33c9
        SHA512 444c8409c25e92b6c02a4d05f3ec84fced9622b62fbe68a4c4ce813b1451da5188b08be6df37dacde7da7a0bd01cb7d476afc531574793871b850025ec3c505a
        HEAD_REF 4.2
    )
    # using 'spine-runtimes' port. exclude the sources from the build
    file(REMOVE_RECURSE "${SPINE_SOURCE_PATH}/spine-cpp")
    # path to the custom module. see SCsub file
    get_filename_component(SPINE_GODOT_PATH "${SPINE_SOURCE_PATH}/spine-godot" ABSOLUTE)
    list(APPEND CUSTOM_MODULES "${SPINE_GODOT_PATH}")
    # see linkflags in scons_build function
    make_linker_flag("spine-cpp" SPINE_FLAG)
    list(APPEND LINKER_FLAGS ${SPINE_FLAG})
endif()
if(DEFINED CUSTOM_MODULES)
    set(CUSTOM_MODULE_OPTIONS "custom_modules=${CUSTOM_MODULES}")
    string(REPLACE ";" "," CUSTOM_MODULE_OPTIONS "${CUSTOM_MODULE_OPTIONS}")
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    # https://learn.microsoft.com/en-us/cpp/build/reference/compiler-options-listed-by-category
    # https://learn.microsoft.com/en-us/cpp/build/reference/linker-options
    set(CCFLAGS "ccflags=/I${CURRENT_INSTALLED_DIR}/include")
    set(LINKFLAGS "linkflags=/LIBPATH:${CURRENT_INSTALLED_DIR}/lib ${LINKER_FLAGS}")
else()
    set(CCFLAGS "ccflags=-I${CURRENT_INSTALLED_DIR}/include")
    set(LINKFLAGS "linkflags=-L${CURRENT_INSTALLED_DIR}/lib;${LINKER_FLAGS}")
endif()
string(REPLACE ";" " " LINKFLAGS "${LINKFLAGS}")

message(STATUS "Using CCFLAGS: ${CCFLAGS}")
message(STATUS "Using LINKFLAGS: ${LINKFLAGS}")

x_vcpkg_get_python_packages(PYTHON_VERSION 3 OUT_PYTHON_VAR PYTHON3 PACKAGES SCons)
function(get_python_site_packages PYTHON OUT_PATH)
    execute_process(
        COMMAND "${PYTHON}" -c "import site; print(site.getsitepackages()[0])"
        OUTPUT_VARIABLE output OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    set(${OUT_PATH} "${output}" PARENT_SCOPE)
endfunction()
get_python_site_packages("${PYTHON3}" SITE_PACKAGES_DIR)
message(STATUS "Using site-packages: ${SITE_PACKAGES_DIR}")
get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)

# https://scons.org/
find_program(SCONS NAMES scons PATHS "${SITE_PACKAGES_DIR}/Scripts" "${PYTHON_PATH}" NO_DEFAULT_PATH REQUIRED)
message(STATUS "Using scons: ${SCONS}")

# see ${SOURCE_PATH}/SConstruct
function(scons_build)
    cmake_parse_arguments(PARSE_ARGV 0 arg "" "TARGET;DIRECTORY" "SCONS_FLAGS")
    if(NOT arg_DIRECTORY)
        set(arg_DIRECTORY "${SOURCE_PATH}")
    endif()
    message(STATUS "Building target ${arg_TARGET}")
    vcpkg_execute_required_process(
        COMMAND "${SCONS}" target=${arg_TARGET} ${arg_SCONS_FLAGS} ${CCFLAGS} ${LINKFLAGS}
            tests=false deprecated=no debug_symbols=no optimize=size
        LOGNAME "build-${arg_TARGET}"
        WORKING_DIRECTORY "${arg_DIRECTORY}"
    )
endfunction()

# https://scons.org/doc/production/TEXT/scons-man.txt
set(ENV{SCONS_CACHE} "${CURRENT_BUILDTREES_DIR}/scons-cache")
set(ENV{SCONSFLAGS} "--jobs=${VCPKG_CONCURRENCY}")

# see detect.py scripts
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(ARCH "x86_64")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(ARCH "arm64")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
    set(ARCH "x86_32")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
    set(ARCH "arm32")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "wasm32")
    set(ARCH "wasm32")
else()
    message(FATAL_ERROR "Unknown arch: ${VCPKG_TARGET_ARCHITECTURE}")
endif()

vcpkg_find_acquire_program(PKGCONFIG)
message(STATUS "Using pkgconfig: ${PKGCONFIG}")
get_filename_component(PKGCONFIG_PATH "${PKGCONFIG}" PATH)
vcpkg_add_to_path(PREPEND "${PKGCONFIG_PATH}")

# ${SOURCE_PATH}/.github/workflows
# todo: android, ios, web
if(VCPKG_TARGET_IS_WINDOWS) # windows_build.yml
    set(PLATFORM windows)
    if(VCPKG_CRT_LINKAGE STREQUAL "static")
        set(CRT_FLAG "use_static_cpp=true") # /MT
    else()
        set(CRT_FLAG "use_static_cpp=false") # /MD            
    endif()
    scons_build(TARGET template_release
        SCONS_FLAGS platform=${PLATFORM} arch=${ARCH} vsproj=yes vsproj_gen_only=no ${CRT_FLAG} ${CUSTOM_MODULE_OPTIONS}
    )
    scons_build(TARGET editor
        SCONS_FLAGS platform=${PLATFORM} arch=${ARCH} vsproj=yes vsproj_gen_only=no windows_subsystem=console ${CRT_FLAG} ${CUSTOM_MODULE_OPTIONS}
    )

elseif(VCPKG_TARGET_IS_OSX) # macos_build.yml
    set(PLATFORM macos)
    scons_build(TARGET template_release
        SCONS_FLAGS platform=${PLATFORM} arch=${ARCH} vulkan=false ${CUSTOM_MODULE_OPTIONS}
    )
    scons_build(TARGET editor
        SCONS_FLAGS platform=${PLATFORM} arch=${ARCH} vulkan=false ${CUSTOM_MODULE_OPTIONS}
    )

elseif(VCPKG_TARGET_IS_LINUX) # linux_build.yml
    set(PLATFORM linuxbsd)
    scons_build(TARGET template_release
        SCONS_FLAGS platform=${PLATFORM} arch=${ARCH} ${CUSTOM_MODULE_OPTIONS}
    )
    scons_build(TARGET editor
        SCONS_FLAGS platform=${PLATFORM} arch=${ARCH} ${CUSTOM_MODULE_OPTIONS}
    )

endif()

vcpkg_copy_tools(
    TOOL_NAMES  godot.${PLATFORM}.template_release.${ARCH}
                godot.${PLATFORM}.editor.${ARCH}
    SEARCH_DIR "${SOURCE_PATH}/bin" AUTO_CLEAN
)

file(INSTALL "${SOURCE_PATH}/README.md" "${SOURCE_PATH}/CHANGELOG.md" "${SOURCE_PATH}/AUTHORS.md"
             "${SOURCE_PATH}/LOGO_LICENSE.txt" "${SOURCE_PATH}/logo.png" "${SOURCE_PATH}/icon.png"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
