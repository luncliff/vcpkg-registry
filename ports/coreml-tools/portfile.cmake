
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/coremltools
    REF 7.2
    SHA512 0b86c3a424376a432985d327935439ce215257201372d781f710ea4177b94bb404c315fb3a00e4efa2d8c4c8693fe97ec0f969d62c2e86f465a92f1c8074d158
    HEAD_REF master
    PATCHES
        fix-cmake.patch
        fix-sources.patch
)
file(REMOVE_RECURSE "${SOURCE_PATH}/deps")

find_program(PROTOC NAMES protoc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf"
    REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH
)
message(STATUS "Using protoc: ${PROTOC}")

# see ${SOURCE_PATH}/setup.py
x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    PACKAGES numpy pybind11 sympy tqdm
    OUT_PYTHON_VAR PYTHON3
)

function(get_python_version PYTHON OUT_VERSION)
    execute_process(
        COMMAND "${PYTHON}" --version
        OUTPUT_VARIABLE output
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    string(REGEX MATCH "([0-9]+\\.[0-9]+\\.[0-9]+)" python_version "${output}")
    set(${OUT_VERSION} ${python_version} PARENT_SCOPE)
endfunction()
get_python_version("${PYTHON3}" PYTHON_VERSION)

message(STATUS "Using python3: ${PYTHON3} ${PYTHON_VERSION}")

function(get_python_site_packages PYTHON OUT_PATH)
    execute_process(
        COMMAND "${PYTHON}" -c "import site; print(site.getsitepackages()[0])"
        OUTPUT_VARIABLE output
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    set(${OUT_PATH} "${output}" PARENT_SCOPE)
endfunction()

get_python_site_packages("${PYTHON3}" SITE_PACKAGES_DIR)
message(STATUS "  site-packages: ${SITE_PACKAGES_DIR}")

if(VCPKG_CROSSCOMPILING)
    find_program(ENUMGEN NAMES enumgen
        PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/coreml-tools"
        REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH
    )
    message(STATUS "Using enumgen: ${ENUMGEN}")
    get_filename_component(ENUMGEN_DIR "${ENUMGEN}" PATH)
    vcpkg_add_to_path(PREPEND "${ENUMGEN_DIR}")
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    # GENERATOR Xcode
    OPTIONS
        -DProtobuf_PROTOC_EXECUTABLE:FILEPATH=${PROTOC}
        -DPython3_EXECUTABLE:FILEPATH=${PYTHON3}
        -DPython3_ROOT_DIR:PATH="${PYTHON_ROOT}"
        -Dpybind11_DIR:PATH="${SITE_PACKAGES_DIR}/pybind11/share/cmake/pybind11"
        -DCMAKE_CROSSCOMPILING=${VCPKG_CROSSCOMPILING}
        -DOVERWRITE_PB_SOURCE=ON
)
vcpkg_cmake_build(TARGET protosrc   LOGFILE_BASE build-protosrc)
if(VCPKG_TARGET_IS_OSX)
    vcpkg_cmake_build(TARGET enumgen   LOGFILE_BASE build-enumgen)
endif()
vcpkg_cmake_install()

if(VCPKG_TARGET_IS_OSX)
    vcpkg_copy_tools(TOOL_NAMES enumgen mlmodel_test_runner AUTO_CLEAN)
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
if(VCPKG_TARGET_IS_IOS)
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/bin" "${CURRENT_PACKAGES_DIR}/debug/bin")
endif()

file(GLOB proto_files
    "${SOURCE_PATH}/mlmodel/format/*.proto"
)
file(GLOB generated_headers
    "${SOURCE_PATH}/mlmodel/build/format/*.h" # *.pb.h
)
file(INSTALL ${proto_files} ${generated_headers} DESTINATION "${CURRENT_PACKAGES_DIR}/include/mlmodel/format")

file(INSTALL "${SOURCE_PATH}/LICENSE.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
