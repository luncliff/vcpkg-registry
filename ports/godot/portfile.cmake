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

x_vcpkg_get_python_packages(PYTHON_VERSION 3 OUT_PYTHON_VAR PYTHON3
    PACKAGES SCons
)

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
        COMMAND "${SCONS}" target=${arg_TARGET} ${arg_SCONS_FLAGS}
            tests=false deprecated=no debug_symbols=no
        LOGNAME "build-${arg_TARGET}"
        WORKING_DIRECTORY "${arg_DIRECTORY}"
    )
endfunction()

# https://scons.org/doc/latest/HTML/scons-user/index.html
set(ENV{SCONS_CACHE} "${CURRENT_BUILDTREES_DIR}/scons-cache")
set(ENV{SCONSFLAGS} "--jobs=${VCPKG_CONCURRENCY}")

# https://github.com/godotengine/godot/blob/4.3-stable/.github/workflows/runner.yml
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(ARCH_NAME "x86_64")
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(ARCH_NAME "arm64")
endif()

# ${SOURCE_PATH}/.github/workflows
# todo: android, ios, web
if(VCPKG_TARGET_IS_WINDOWS) # windows_build.yml
    scons_build(TARGET template_release
        SCONS_FLAGS platform=windows arch=${ARCH_NAME} vsproj=yes vsproj_gen_only=no
    )
    scons_build(TARGET editor
        SCONS_FLAGS platform=windows arch=${ARCH_NAME} vsproj=yes vsproj_gen_only=no windows_subsystem=console
    )
    vcpkg_copy_tools(
        TOOL_NAMES  godot.windows.template_release.${ARCH_NAME}
                    godot.windows.editor.${ARCH_NAME}
        SEARCH_DIR "${SOURCE_PATH}/bin" AUTO_CLEAN
    )

elseif(VCPKG_TARGET_IS_OSX) # macos_build.yml
    scons_build(TARGET template_release
        SCONS_FLAGS platform=macos arch=${ARCH_NAME} optimize=size vulkan=false
    )
    scons_build(TARGET editor
        SCONS_FLAGS platform=macos arch=${ARCH_NAME} optimize=size vulkan=false
    )
    vcpkg_copy_tools(
        TOOL_NAMES  godot.macos.template_release.${ARCH_NAME}
                    godot.macos.editor.${ARCH_NAME}
        SEARCH_DIR "${SOURCE_PATH}/bin" AUTO_CLEAN
    )

elseif(VCPKG_TARGET_IS_LINUX) # linux_build.yml
    scons_build(TARGET template_release
        SCONS_FLAGS platform=linuxbsd arch=${ARCH_NAME} optimize=size
    )
    scons_build(TARGET editor
        SCONS_FLAGS platform=linuxbsd arch=${ARCH_NAME} optimize=size
    )
    vcpkg_copy_tools(
        TOOL_NAMES  godot.linuxbsd.template_release.${ARCH_NAME}
                    godot.linuxbsd.editor.${ARCH_NAME}
        SEARCH_DIR "${SOURCE_PATH}/bin" AUTO_CLEAN
    )

endif()

file(INSTALL "${SOURCE_PATH}/README.md" "${SOURCE_PATH}/CHANGELOG.md" "${SOURCE_PATH}/AUTHORS.md"
             "${SOURCE_PATH}/LOGO_LICENSE.txt" "${SOURCE_PATH}/logo.png" "${SOURCE_PATH}/icon.png"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
