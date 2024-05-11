vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" BUILD_SHARED)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/onnxruntime
    REF v1.17.3
    SHA512 f24e333ad113e15733867fae237c3495f93e373b2998508deeebb061ce9a56c444bf68fc49ae251bcc45539d0695f3ae758d73dc3c42bc01bbd7cfaa8561c793
    PATCHES
        fix-onnxruntime-pr-19966.patch # https://github.com/microsoft/onnxruntime/pull/19966 for OpenVINO 2024.0+
        fix-cmake.patch
        fix-sources.patch
        fix-xnnpack.patch # todo: check xnnpack updates & tests
        fix-clang-cl-simd-compile.patch
        fix-llvm-rc-unicode.patch
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/onnxruntime_vcpkg_deps.cmake" DESTINATION "${SOURCE_PATH}/cmake/external")

find_program(PROTOC NAMES protoc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf"
    REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH
)
message(STATUS "Using protoc: ${PROTOC}")

find_program(FLATC NAMES flatc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/flatbuffers"
    REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH
)
message(STATUS "Using flatc: ${FLATC}")

set(SCHEMA_DIR "${SOURCE_PATH}/onnxruntime/core/flatbuffers/schema")
vcpkg_execute_required_process(
    COMMAND ${FLATC} --cpp --scoped-enums --filename-suffix ".fbs" ort.fbs ort_training_checkpoint.fbs
    LOGNAME codegen-flatc-cpp
    WORKING_DIRECTORY "${SCHEMA_DIR}"
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        python    onnxruntime_ENABLE_PYTHON
        python    onnxruntime_ENABLE_LANGUAGE_INTEROP_OPS
        training  onnxruntime_ENABLE_TRAINING
        training  onnxruntime_ENABLE_TRAINING_APIS
        # training  onnxruntime_ENABLE_TRAINING_OPS
        cuda      onnxruntime_USE_CUDA
        cuda      onnxruntime_USE_CUDA_NHWC_OPS
        openvino  onnxruntime_USE_OPENVINO
        tensorrt  onnxruntime_USE_TENSORRT
        tensorrt  onnxruntime_USE_TENSORRT_BUILTIN_PARSER
        directml  onnxruntime_USE_DML
        directml  onnxruntime_USE_CUSTOM_DIRECTML
        winml     onnxruntime_USE_WINML
        coreml    onnxruntime_USE_COREML
        mimalloc  onnxruntime_USE_MIMALLOC
        valgrind  onnxruntime_USE_VALGRIND
        xnnpack   onnxruntime_USE_XNNPACK
        nnapi     onnxruntime_USE_NNAPI_BUILTIN
        azure     onnxruntime_USE_AZURE
        llvm      onnxruntime_USE_LLVM
        test      onnxruntime_BUILD_UNIT_TESTS
        test      onnxruntime_BUILD_BENCHMARKS
        test      onnxruntime_RUN_ONNX_TESTS
        framework onnxruntime_BUILD_APPLE_FRAMEWORK
        framework onnxruntime_BUILD_OBJC
        nccl      onnxruntime_USE_NCCL
        mpi       onnxruntime_USE_MPI
    INVERTED_FEATURES
        abseil    onnxruntime_DISABLE_ABSEIL
        cuda      onnxruntime_USE_MEMORY_EFFICIENT_ATTENTION
)

if(VCPKG_TARGET_IS_WINDOWS OR VCPKG_TARGET_IS_UWP)
    # For some reason CUDA compiler detection is not working in WINDOWS_USE_MSBUILD
    if(NOT ("cuda" IN_LIST FEATURES))
        set(GENERATOR_OPTIONS WINDOWS_USE_MSBUILD)
    endif()
elseif(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
    set(GENERATOR_OPTIONS GENERATOR Xcode)
else()
    set(GENERATOR_OPTIONS GENERATOR Ninja)
endif()

# todo: provide options for SIMD
if(VCPKG_TARGET_IS_WINDOWS)
    # target platform should be informed to activate SIMD properly
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        list(APPEND ARCH_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="x64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        list(APPEND ARCH_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="Win32")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        list(APPEND ARCH_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="ARM64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        list(APPEND ARCH_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="ARM")
    else()
        message(WARNING "Unexpected architecture: ${VCPKG_TARGET_ARCHITECTURE}")
        list(APPEND ARCH_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="${VCPKG_TARGET_ARCHITECTURE}")
    endif()
endif()

if("python" IN_LIST FEATURES)
    x_vcpkg_get_python_packages(
        PYTHON_VERSION 3
        PACKAGES numpy sympy # flatbuffers protobuf
        OUT_PYTHON_VAR PYTHON3
    )
    get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
else()
    vcpkg_find_acquire_program(PYTHON3)
    get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
endif()
message(STATUS "Using python3: ${PYTHON3}")
vcpkg_add_to_path(PREPEND "${PYTHON_PATH}")

if("cuda" IN_LIST FEATURES)
    # https://cmake.org/cmake/help/latest/module/FindCUDAToolkit.html
    if(NOT DEFINED ENV{CUDA_PATH})
        message(FATAL_ERROR "ENV{CUDA_PATH} is required. Please check the environment variable")
    endif()
    message(STATUS "Using CUDA: $ENV{CUDA_PATH}")
    get_filename_component(CUDA_VERSION "$ENV{CUDA_PATH}" NAME)
    string(REPLACE "v" "" CUDA_VERSION "${CUDA_VERSION}") # "v12.0" -> "12.0"
    message(STATUS "  version: ${CUDA_VERSION}")
endif()

# see tools/ci_build/build.py
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/cmake"
    ${GENERATOR_OPTIONS}
    OPTIONS
        ${ARCH_OPTIONS}
        ${FEATURE_OPTIONS}
        -DPython_EXECUTABLE:FILEPATH=${PYTHON3}
        -DProtobuf_PROTOC_EXECUTABLE:FILEPATH=${PROTOC}
        -DInferenceEngine_DIR:PATH=${CURRENT_INSTALLED_DIR}/share/openvino
        -Dngraph_DIR:PATH=${CURRENT_INSTALLED_DIR}/share/openvino
        # -DProtobuf_USE_STATIC_LIBS=OFF
        -DBUILD_PKGCONFIG_FILES=ON
        -Donnxruntime_BUILD_SHARED_LIB=${BUILD_SHARED}
        -Donnxruntime_BUILD_WEBASSEMBLY=OFF
        -Donnxruntime_CROSS_COMPILING=${VCPKG_CROSSCOMPILING}
        -Donnxruntime_USE_FULL_PROTOBUF=OFF # minimalize protoc execution
        -Donnxruntime_USE_PREINSTALLED_EIGEN=ON
        -Donnxruntime_USE_EXTENSIONS=OFF
        -Donnxruntime_USE_NNAPI_BUILTIN=${VCPKG_TARGET_IS_ANDROID}
        -Donnxruntime_ENABLE_CPUINFO=ON
        -Donnxruntime_ENABLE_MICROSOFT_INTERNAL=OFF
        -Donnxruntime_ENABLE_BITCODE=${VCPKG_TARGET_IS_IOS}
        -Donnxruntime_ENABLE_PYTHON=OFF
        -Donnxruntime_ENABLE_EXTERNAL_CUSTOM_OP_SCHEMAS=OFF
        -Donnxruntime_ENABLE_LAZY_TENSOR=OFF
        -Donnxruntime_NVCC_THREADS=1 # parallel compilation
        -Donnxruntime_DISABLE_RTTI=OFF
        -Donnxruntime_USE_NEURAL_SPEED=OFF
        -DUSE_NEURAL_SPEED=OFF
        # for ORT_BUILD_INFO
        -DORT_GIT_COMMIT:STRING="56b660f36940a919295e6f1e18ad3a9a93a10bf7"
        -DORT_GIT_BRANCH:STRING="v1.17.3"
    OPTIONS_DEBUG
        -Donnxruntime_ENABLE_MEMLEAK_CHECKER=OFF
        -Donnxruntime_ENABLE_MEMORY_PROFILE=OFF
        -Donnxruntime_DEBUG_NODE_INPUTS_OUTPUTS=1
    MAYBE_UNUSED_VARIABLES
        onnxruntime_BUILD_WEBASSEMBLY
        onnxruntime_TENSORRT_PLACEHOLDER_BUILDER
        onnxruntime_USE_CUSTOM_DIRECTML
        onnxruntime_NVCC_THREADS
        InferenceEngine_DIR
        ngraph_DIR
)
vcpkg_cmake_build(TARGET onnxruntime LOGFILE_BASE build-onnxruntime)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/onnxruntime PACKAGE_NAME onnxruntime)
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig() # pkg_check_modules(libonnxruntime)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/bin" "${CURRENT_PACKAGES_DIR}/bin")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
