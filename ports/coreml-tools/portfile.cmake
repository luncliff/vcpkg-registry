
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO apple/coremltools
    REF 6.1
    SHA512 d739f6d8c021c5f2586122b9c4f3a0d96490dd83d4fa0c8e010d558ce32f272ac190f6d973116b896c5c27304890b63fc497b3043d3697d547e63418c417e21b
    HEAD_REF master
)

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
message(STATUS "Using Python3: ${PYTHON3}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DPYTHON_EXECUTABLE:FILEPATH=${PYTHON3}
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup()
# vcpkg_fixup_pkgconfig() # pkg_check_modules(libcpuinfo)
vcpkg_copy_tools(TOOL_NAMES cache-info cpuid-dump cpu-info isa-info AUTO_CLEAN)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

file(INSTALL "${SOURCE_PATH}/LICENSE.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
