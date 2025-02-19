vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO onnx/onnx
    REF v${VERSION}
    SHA512 5a18e2b19ec9c18c8b115fb7e12ed98eddaa581c95f15c4dd420cd6c86e7caa04f9a393da589e76b89cf9b3544abd3749a8c77c2446782f37502eb74e9b1f661
    PATCHES
        fix-cmake.patch
        fix-cmake-protobuf.patch
        support-test.patch
)

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_STATIC_RUNTIME)

find_program(PROTOC NAMES protoc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf"
    REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH
)
message(STATUS "Using protoc: ${PROTOC}")

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        test    ONNX_BUILD_TESTS
        python  BUILD_ONNX_PYTHON
        protobuf-lite   ONNX_USE_LITE_PROTO
        disable-exception   ONNX_DISABLE_EXCEPTIONS
        disable-static-registration ONNX_DISABLE_STATIC_REGISTRATION
)

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
message(STATUS "Using python3: ${PYTHON3}")
vcpkg_add_to_path(PREPEND "${PYTHON_PATH}")

if("python" IN_LIST FEATURES)
    get_filename_component(PYTHON_ROOT "${PYTHON_PATH}" PATH)
    find_path(pybind11_DIR NAMES pybind11Targets.cmake PATHS "${PYTHON_ROOT}/Lib/site-packages/pybind11/share/cmake/pybind11" REQUIRED)
    message(STATUS "Using pybind11: ${pybind11_DIR}")
    list(APPEND FEATURE_OPTIONS "-Dpybind11_DIR:PATH=${pybind11_DIR}")
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        "-DPYTHON_EXECUTABLE:FILEPATH=${PYTHON3}"
        "-D_PROTOBUF_INSTALL_PREFIX=${CURRENT_INSTALLED_DIR}"
        "-DProtobuf_PROTOC_EXECUTABLE:FILEPATH=${PROTOC}"
        "-DONNX_CUSTOM_PROTOC_EXECUTABLE=${PROTOC}"
        -DONNX_VERIFY_PROTO3=ON # --protoc_path for gen_proto.py
        -DONNX_ML=ON
        -DONNX_GEN_PB_TYPE_STUBS=ON
        -DONNX_USE_MSVC_STATIC_RUNTIME=${USE_STATIC_RUNTIME}
        -DONNX_BUILD_BENCHMARKS=OFF
    MAYBE_UNUSED_VARIABLES
        ONNX_USE_MSVC_STATIC_RUNTIME
        ONNX_CUSTOM_PROTOC_EXECUTABLE
        PROTOBUF_SEARCH_DIRS
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/ONNX PACKAGE_NAME ONNX)
if("test" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES onnx_gtests AUTO_CLEAN)
endif()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

# Traverse the folder and remove "some" empty folders
function(cleanup_once folder)
    if(NOT IS_DIRECTORY "${folder}")
        return()
    endif()
    file(GLOB paths LIST_DIRECTORIES true "${folder}/*")
    list(LENGTH paths count)
    # 1. remove if the given folder is empty
    if(count EQUAL 0)
        file(REMOVE_RECURSE "${folder}")
        message(VERBOSE "Removed ${folder}")
        return()
    endif()
    # 2. repeat the operation for hop 1 sub-directories 
    foreach(path ${paths})
        cleanup_once(${path})
    endforeach()
endfunction()

# Some folders may contain empty folders. They will become empty after `cleanup_once`.
# Repeat given times to delete new empty folders.
function(cleanup_repeat folder repeat)
    if(NOT IS_DIRECTORY "${folder}")
        return()
    endif()
    while(repeat GREATER_EQUAL 1)
        math(EXPR repeat "${repeat} - 1" OUTPUT_FORMAT DECIMAL)
        cleanup_once("${folder}")
    endwhile()
endfunction()

# https://github.com/microsoft/vcpkg PR 30230
cleanup_repeat("${CURRENT_PACKAGES_DIR}/include" 4)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")