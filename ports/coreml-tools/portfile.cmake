
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/coremltools
    REF 6.1
    SHA512 d739f6d8c021c5f2586122b9c4f3a0d96490dd83d4fa0c8e010d558ce32f272ac190f6d973116b896c5c27304890b63fc497b3043d3697d547e63418c417e21b
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

file(GLOB MLMODEL_PROTO_FILES "${SOURCE_PATH}/mlmodel/format/*.proto")
# vcpkg_execute_required_process(
#     COMMAND ${PROTOC}
#         --cpp_out "${SOURCE_PATH}/mlmodel/build/format"
#         --proto_path "${SOURCE_PATH}/mlmodel/format"
#         ${MLMODEL_PROTO_FILES}
#     LOGNAME codegen-protoc
#     WORKING_DIRECTORY "${SOURCE_PATH}/mlmodel/format"
# )
file(INSTALL ${MLMODEL_PROTO_FILES} DESTINATION "${CURRENT_PACKAGES_DIR}/include/mlmodel/format")

# see ${SOURCE_PATH}/setup.py
x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    PACKAGES numpy pybind11 sympy tqdm
    OUT_PYTHON_VAR PYTHON3
)
message(STATUS "Using python3: ${PYTHON3}")

get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
get_filename_component(PYTHON_ROOT "${PYTHON_PATH}" PATH)

# ${PYTHON3} -m site --user-site
find_path(SITE_PACKAGES_DIR
    NAMES "isympy.py"
    PATHS "${PYTHON_ROOT}/lib/python3.9/site-packages"
          "${PYTHON_ROOT}/lib/python3.10/site-packages"
          "${PYTHON_ROOT}/lib/python3.11/site-packages"
    REQUIRED
)
message(STATUS "  site-packages: ${SITE_PACKAGES_DIR}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DProtobuf_PROTOC_EXECUTABLE:FILE_PATH="${PROTOC}"
        -DPython3_ROOT_DIR:PATH="${PYTHON_ROOT}"
        -DPython3_EXECUTABLE:FILEPATH="${PYTHON3}"
        -Dpybind11_DIR:PATH="${SITE_PACKAGES_DIR}/pybind11/share/cmake/pybind11"
        -DOVERWRITE_PB_SOURCE=ON
)
vcpkg_cmake_build(TARGET protosrc   LOGFILE_BASE build-protosrc)
vcpkg_cmake_build(TARGET enumgen    LOGFILE_BASE build-enumgen)
vcpkg_cmake_install()
vcpkg_copy_tools(TOOL_NAMES enumgen mlmodel_test_runner AUTO_CLEAN)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

file(GLOB MLMODEL_GENERATED_HEADERS
    "${SOURCE_PATH}/mlmodel/build/format/*.h" # *.pb.h
)
file(INSTALL ${MLMODEL_GENERATED_HEADERS} DESTINATION "${CURRENT_PACKAGES_DIR}/include/mlmodel/format")

file(INSTALL "${SOURCE_PATH}/LICENSE.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
