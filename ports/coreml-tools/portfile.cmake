
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/coremltools
    REF ${VERSION}
    SHA512 4d2e61c39cb23d7cef1942d3117ca644d8046f952c484317e4a30ac2a16c04ea5d6defd029c4a04654a4d02a72c394186835c55d477ee89a1d9010307fa9aa81
    HEAD_REF main
    PATCHES
        fix-cmake.patch
        fix-sources.patch
)
file(REMOVE_RECURSE "${SOURCE_PATH}/deps" "${SOURCE_PATH}/mlmodel/build/format")
file(CREATE_LINK "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/mlmodel/format" "${SOURCE_PATH}/mlmodel/build/format" SYMBOLIC)

find_program(PROTOC NAMES protoc PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf" REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH)
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
        OUTPUT_VARIABLE output OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    string(REGEX MATCH "([0-9]+\\.[0-9]+\\.[0-9]+)" output "${output}")
    set(${OUT_VERSION} "${output}" PARENT_SCOPE)
endfunction()
get_python_version("${PYTHON3}" PYTHON_VERSION)

function(get_python_site_packages PYTHON OUT_PATH)
    execute_process(
        COMMAND "${PYTHON}" -c "import site; print(site.getsitepackages()[0])"
        OUTPUT_VARIABLE output OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    set(${OUT_PATH} "${output}" PARENT_SCOPE)
endfunction()
get_python_site_packages("${PYTHON3}" SITE_PACKAGES_DIR)

message(STATUS "Using python3: ${PYTHON3} '${PYTHON_VERSION}'")
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
    OPTIONS
        "-DProtobuf_PROTOC_EXECUTABLE:FILEPATH=${PROTOC}"
        "-DPYTHON_EXECUTABLE:FILEPATH=${PYTHON3}"
        "-Dpybind11_DIR:PATH=${SITE_PACKAGES_DIR}/pybind11/share/cmake/pybind11"
        -DCMAKE_CROSSCOMPILING=${VCPKG_CROSSCOMPILING}
        -DOVERWRITE_PB_SOURCE=ON
)
vcpkg_cmake_build(TARGET protosrc LOGFILE_BASE build-protosrc)
if(VCPKG_TARGET_IS_OSX)
    vcpkg_cmake_build(TARGET enumgen LOGFILE_BASE build-enumgen)
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
    "${SOURCE_PATH}/mlmodel/build/format/*.h" # *.pb.h and *_enum.h
)
file(INSTALL ${proto_files} ${generated_headers} DESTINATION "${CURRENT_PACKAGES_DIR}/include/mlmodel/format")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
