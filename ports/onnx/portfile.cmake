vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO onnx/onnx
    REF v1.16.0
    SHA512 ef641447d8d6c4ed9f083793fe14a8568d6aa7b9b7e7b859a4082e9b892acd801230da2027d097ceaa0d68bbd37b2422b89bb7d1d55d5c3b5955c0f9c7c657c5
    PATCHES
        fix-cmake.patch
        support-test.patch
)

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_STATIC_RUNTIME)

# ONNX_USE_PROTOBUF_SHARED_LIBS: find the library and check its file extension
find_library(PROTOBUF_LIBPATH NAMES protobuf PATHS "${CURRENT_INSTALLED_DIR}/bin" "${CURRENT_INSTALLED_DIR}/lib" REQUIRED)
message(STATUS "Found protobuf: ${PROTOBUF_LIBPATH}")

get_filename_component(PROTOBUF_LIBNAME "${PROTOBUF_LIBPATH}" NAME)
if(PROTOBUF_LIBNAME MATCHES "${CMAKE_SHARED_LIBRARY_SUFFIX}")
    set(USE_PROTOBUF_SHARED ON)
else()
    set(USE_PROTOBUF_SHARED OFF)
endif()

find_program(PROTOC NAMES protoc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf"
    REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH
)
message(STATUS "Using protoc: ${PROTOC}")

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        python              BUILD_ONNX_PYTHON
        protobuf-lite       ONNX_USE_LITE_PROTO
        test                ONNX_BUILD_TESTS
        disable-exception           ONNX_DISABLE_EXCEPTIONS
        disable-static-registration ONNX_DISABLE_STATIC_REGISTRATION
)

if("python" IN_LIST FEATURES)
    x_vcpkg_get_python_packages(
        PYTHON_VERSION 3
        PACKAGES numpy pybind11
        OUT_PYTHON_VAR PYTHON3
    )
    get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
else()
    vcpkg_find_acquire_program(PYTHON3)
    get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
endif()
message(STATUS "Using python3: ${PYTHON3}")
vcpkg_add_to_path(PREPEND "${PYTHON_PATH}")

if("python" IN_LIST FEATURES)
    get_filename_component(PYTHON_ROOT "${PYTHON_PATH}" PATH)
    find_path(pybind11_DIR NAMES pybind11Targets.cmake PATHS "${PYTHON_ROOT}/Lib/site-packages/pybind11/share/cmake/pybind11" REQUIRED)
    message(STATUS "Using pybind11: ${pybind11_DIR}")
    list(APPEND FEATURE_OPTIONS
        -Dpybind11_DIR:PATH=${pybind11_DIR}
    )
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DPYTHON_EXECUTABLE:FILEPATH=${PYTHON3}
        -DProtobuf_PROTOC_EXECUTABLE=${PROTOC}
        -DONNX_CUSTOM_PROTOC_EXECUTABLE=${PROTOC}
        -DONNX_VERIFY_PROTO3=ON # --protoc_path for gen_proto.py
        -DONNX_ML=ON
        -DONNX_GEN_PB_TYPE_STUBS=ON
        -DONNX_USE_PROTOBUF_SHARED_LIBS=${USE_PROTOBUF_SHARED}
        -DONNX_USE_MSVC_STATIC_RUNTIME=${USE_STATIC_RUNTIME}
        -DONNX_BUILD_BENCHMARKS=OFF
    MAYBE_UNUSED_VARIABLES
        ONNX_USE_MSVC_STATIC_RUNTIME
        ONNX_CUSTOM_PROTOC_EXECUTABLE
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