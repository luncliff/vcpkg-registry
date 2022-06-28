# uwp: LOAD_LIBRARY_SEARCH_DEFAULT_DIRS undefined identifier
vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO onnx/onnx
    REF v1.12.0
    SHA512 ab0c4f92358e904c2f28d98b35eab2d6eac22dd0a270e4f45ee590aa1ad22d09e92b32225efd7e98edb1531743f150526d26e0cbdc537757784bef2bc93efa8e
    PATCHES
        fix-cmakelists.patch
)

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_STATIC_RUNTIME)

# ONNX_USE_PROTOBUF_SHARED_LIBS: find the library and check its file extension
find_library(PROTOBUF_LIBPATH NAMES protobuf PATHS ${CURRENT_INSTALLED_DIR}/bin ${CURRENT_INSTALLED_DIR}/lib REQUIRED)
get_filename_component(PROTOBUF_LIBNAME ${PROTOBUF_LIBPATH} NAME)
if(PROTOBUF_LIBNAME MATCHES ${CMAKE_SHARED_LIBRARY_SUFFIX})
    set(USE_PROTOBUF_SHARED ON)
else()
    set(USE_PROTOBUF_SHARED OFF)
endif()

find_program(PROTOC NAMES protoc PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf" REQUIRED)
message(STATUS "Using protoc: ${PROTOC}")

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON_DIR "${PYTHON3}" PATH)
vcpkg_add_to_path(PREPEND "${PYTHON_DIR}") # PATH for .bat scripts
message(STATUS "Using python3: ${PYTHON3}")

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        pybind11      BUILD_ONNX_PYTHON
        protobuf-lite ONNX_USE_LITE_PROTO
        onnxifi       ONNXIFI_ENABLE_EXT
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DPython3_EXECUTABLE=${PYTHON3}
        -DProtobuf_PROTOC_EXECUTABLE=${PROTOC}
        -DONNX_ML=ON
        -DONNX_GEN_PB_TYPE_STUBS=ON
        -DONNX_USE_PROTOBUF_SHARED_LIBS=${USE_PROTOBUF_SHARED}
        -DONNX_USE_MSVC_STATIC_RUNTIME=${USE_STATIC_RUNTIME}
        -DONNX_BUILD_TESTS=OFF
        -DONNX_BUILD_BENCHMARKS=OFF
    MAYBE_UNUSED_VARIABLES
        ONNX_USE_MSVC_STATIC_RUNTIME
)

if("pybind11" IN_LIST FEATURES)
    # This target is not in install/export
    vcpkg_cmake_build(TARGET onnx_cpp2py_export)
endif()
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/ONNX)

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include"
                    "${CURRENT_PACKAGES_DIR}/debug/share"
                    # the others are empty
                    "${CURRENT_PACKAGES_DIR}/include/onnx/onnx_ml"
                    "${CURRENT_PACKAGES_DIR}/include/onnx/onnx_data"
                    "${CURRENT_PACKAGES_DIR}/include/onnx/onnx_operators_ml"
                    "${CURRENT_PACKAGES_DIR}/include/onnx/onnx_cpp2py_export"
                    "${CURRENT_PACKAGES_DIR}/include/onnx/backend"
                    "${CURRENT_PACKAGES_DIR}/include/onnx/tools"
                    "${CURRENT_PACKAGES_DIR}/include/onnx/test"
                    "${CURRENT_PACKAGES_DIR}/include/onnx/bin"
                    "${CURRENT_PACKAGES_DIR}/include/onnx/examples"
                    "${CURRENT_PACKAGES_DIR}/include/onnx/frontend"
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
)
