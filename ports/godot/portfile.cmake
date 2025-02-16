vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO godotengine/godot
    REF "${VERSION}-stable"
    SHA512 ce20235f1a5f8a5dc22f4bec6c4b5ab7c66aa3b35733f9fc26f905e564c4671df370c68db1ea65b205e00f29863d6d6f5ea6878996a4d69d32f728ecc91c8726
    HEAD_REF 4.3
)

# https://scons.org/
x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    PACKAGES SCons
    OUT_PYTHON_VAR PYTHON3
)

function(get_python_version PYTHON OUT_VERSION)
    execute_process(
        COMMAND "${PYTHON}" --version
        OUTPUT_VARIABLE output OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    string(REGEX MATCH "([0-9]+\\.[0-9]+\\.[0-9]+)" output "${output}")
    set(${OUT_VERSION} "${output}" PARENT_SCOPE)
endfunction()
get_python_version("${PYTHON3}" PYTHON_VERSION)
message(STATUS "Using python3: ${PYTHON3} ${PYTHON_VERSION}")

function(get_python_site_packages PYTHON OUT_PATH)
    execute_process(
        COMMAND "${PYTHON}" -c "import site; print(site.getsitepackages()[0])"
        OUTPUT_VARIABLE output OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    set(${OUT_PATH} "${output}" PARENT_SCOPE)
endfunction()
get_python_site_packages("${PYTHON3}" SITE_PACKAGES_DIR)
message(STATUS "Using site-packages: ${SITE_PACKAGES_DIR}")

find_program(SCONS NAMES scons PATHS "${SITE_PACKAGES_DIR}/Scripts" NO_DEFAULT_PATH REQUIRED)
message(STATUS "Using scons: ${SCONS}")

# https://scons.org/doc/latest/HTML/scons-user/index.html
# https://github.com/godotengine/godot/blob/4.3-stable/.github/workflows/runner.yml
set(ENV{SCONS_CACHE} "${CURRENT_BUILDTREES_DIR}/scons-cache")
set(ENV{SCONSFLAGS} "--jobs=${VCPKG_CONCURRENCY}")
if(VCPKG_TARGET_IS_WINDOWS)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(ARCH_OPT "arch=x86_64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(ARCH_OPT "arch=arm64")
    endif()
endif()

# scons platform=${{ inputs.platform }} target=${{ inputs.target }} tests=false ${{ env.SCONSFLAGS }}

message(STATUS "Building target=template_release")
vcpkg_execute_required_process(
    COMMAND "${SCONS}" ${ARCH_OPT} --ignore-errors # --enable-virtualenv
        platform=windows target=template_release
        tests=false
        debug_symbols=no vsproj=yes vsproj_gen_only=no
    LOGNAME target-template
    WORKING_DIRECTORY "${SOURCE_PATH}"
)

message(STATUS "Building target=editor")
vcpkg_execute_required_process(
    COMMAND "${SCONS}" ${ARCH_OPT} --ignore-errors
        platform=windows target=editor
        tests=false
        debug_symbols=no vsproj=yes vsproj_gen_only=no windows_subsystem=console
    LOGNAME target-editor
    WORKING_DIRECTORY "${SOURCE_PATH}"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
