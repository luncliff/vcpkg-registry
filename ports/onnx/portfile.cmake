vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO onnx/onnx
    REF v1.14.0
    SHA512 8a525b365fd203f0a59bcf82fa7f2e29d7e0563885ebe38269c596cd4eb949bcfc65d848b92b7abafa7ddecedcfc019f8779097ffcb5087f06037cace24462fc
    PATCHES
        fix-cmakelists.patch
)

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_STATIC_RUNTIME)

# ONNX_USE_PROTOBUF_SHARED_LIBS: find the library and check its file extension
find_library(PROTOBUF_LIBPATH NAMES protobuf PATHS "${CURRENT_INSTALLED_DIR}/bin" "${CURRENT_INSTALLED_DIR}/lib" REQUIRED)
get_filename_component(PROTOBUF_LIBNAME "${PROTOBUF_LIBPATH}" NAME)
if(PROTOBUF_LIBNAME MATCHES "${CMAKE_SHARED_LIBRARY_SUFFIX}")
    set(USE_PROTOBUF_SHARED ON)
else()
    set(USE_PROTOBUF_SHARED OFF)
endif()
find_program(PROTOC_EXECUTABLE NAMES protoc PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf" REQUIRED)
message(STATUS "Using protoc: ${PROTOC_EXECUTABLE}")

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        python BUILD_ONNX_PYTHON
        protobuf-lite ONNX_USE_LITE_PROTO
)

# Like protoc, python is required for codegen.
x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    PACKAGES numpy pybind11
    OUT_PYTHON_VAR PYTHON3
)
message(STATUS "Using python3: ${PYTHON3}")
get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
get_filename_component(PYTHON_ROOT "${PYTHON_PATH}" PATH)
# PATH for .bat scripts so it can find 'python'
vcpkg_add_to_path(PREPEND "${PYTHON_PATH}")

if("python" IN_LIST FEATURES)
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
        -DPython3_EXECUTABLE:FILEPATH=${PYTHON3}
        -DPython3_ROOT_DIR=${PYTHON_ROOT}
        -DProtobuf_PROTOC_EXECUTABLE=${PROTOC_EXECUTABLE}
        -DONNX_CUSTOM_PROTOC_EXECUTABLE=${PROTOC_EXECUTABLE}
        -DONNX_ML=ON
        -DONNX_GEN_PB_TYPE_STUBS=ON
        -DONNX_USE_PROTOBUF_SHARED_LIBS=${USE_PROTOBUF_SHARED}
        -DONNX_USE_MSVC_STATIC_RUNTIME=${USE_STATIC_RUNTIME}
        -DONNX_BUILD_TESTS=OFF
        -DONNX_BUILD_BENCHMARKS=OFF
    MAYBE_UNUSED_VARIABLES
        ONNX_USE_MSVC_STATIC_RUNTIME
        ONNX_CUSTOM_PROTOC_EXECUTABLE
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/ONNX)

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/include/onnx/reference"
    # the others are empty
    "${CURRENT_PACKAGES_DIR}/include/onnx/backend"
    "${CURRENT_PACKAGES_DIR}/include/onnx/bin"
    "${CURRENT_PACKAGES_DIR}/include/onnx/defs/controlflow"
    "${CURRENT_PACKAGES_DIR}/include/onnx/defs/generator"
    "${CURRENT_PACKAGES_DIR}/include/onnx/defs/logical"
    "${CURRENT_PACKAGES_DIR}/include/onnx/defs/math"
    "${CURRENT_PACKAGES_DIR}/include/onnx/defs/nn"
    "${CURRENT_PACKAGES_DIR}/include/onnx/defs/object_detection"
    "${CURRENT_PACKAGES_DIR}/include/onnx/defs/optional"
    "${CURRENT_PACKAGES_DIR}/include/onnx/defs/quantization"
    "${CURRENT_PACKAGES_DIR}/include/onnx/defs/reduction"
    "${CURRENT_PACKAGES_DIR}/include/onnx/defs/rnn"
    "${CURRENT_PACKAGES_DIR}/include/onnx/defs/sequence"
    "${CURRENT_PACKAGES_DIR}/include/onnx/defs/traditionalml"
    "${CURRENT_PACKAGES_DIR}/include/onnx/defs/training"
    "${CURRENT_PACKAGES_DIR}/include/onnx/examples"
    "${CURRENT_PACKAGES_DIR}/include/onnx/frontend"
    "${CURRENT_PACKAGES_DIR}/include/onnx/onnx_cpp2py_export"
    "${CURRENT_PACKAGES_DIR}/include/onnx/test"
    "${CURRENT_PACKAGES_DIR}/include/onnx/tools"
    "${CURRENT_PACKAGES_DIR}/include/onnx/onnx_ml"
    "${CURRENT_PACKAGES_DIR}/include/onnx/onnx_data"
    "${CURRENT_PACKAGES_DIR}/include/onnx/onnx_operators_ml"
)
