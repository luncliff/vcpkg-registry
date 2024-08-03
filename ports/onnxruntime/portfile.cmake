vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" BUILD_SHARED)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/onnxruntime
    REF v1.18.1
    SHA512 192cb95e131d7a7796f29556355d0c9055c05723e1120e21155ed21e05301d862f2ba3fd613d8f9289b61577f64cc4b406db7bb25d1bd666b75c29a0f29cc9d8
    PATCHES
        fix-cmake.patch
        fix-cmake-cuda.patch
        fix-sources.patch
        # fix-clang-cl-simd-compile.patch
        fix-llvm-rc-unicode.patch
)
# https://github.com/microsoft/onnxruntime/pull/21348
file(COPY "${CMAKE_CURRENT_LIST_DIR}/onnxruntime_external_deps.cmake" DESTINATION "${SOURCE_PATH}/cmake/external")

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

vcpkg_execute_required_process(
    COMMAND "${FLATC}" --cpp --scoped-enums --filename-suffix ".fbs" ort.fbs ort_training_checkpoint.fbs
    LOGNAME codegen-flatc-cpp
    WORKING_DIRECTORY "${SOURCE_PATH}/onnxruntime/core/flatbuffers/schema"
)
if("test" IN_LIST FEATURES)
    vcpkg_execute_required_process(
        COMMAND "${FLATC}" --cpp --scoped-enums --filename-suffix ".fbs" flatbuffers_utils_test.fbs
        LOGNAME codegen-flatc-test-cpp
        WORKING_DIRECTORY "${SOURCE_PATH}/onnxruntime/test/flatbuffers"
    )
endif()

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
        cuda      onnxruntime_USE_MEMORY_EFFICIENT_ATTENTION
)

if(VCPKG_TARGET_IS_WINDOWS OR VCPKG_TARGET_IS_UWP)
    set(GENERATOR_OPTIONS WINDOWS_USE_MSBUILD)
    if("cuda" IN_LIST FEATURES)
        unset(GENERATOR_OPTIONS) # use Ninja for CUDA build
    endif()
elseif(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
    set(GENERATOR_OPTIONS GENERATOR Xcode)
endif()

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
message(STATUS "Using python3: ${PYTHON3}")
vcpkg_add_to_path(PREPEND "${PYTHON_PATH}")

# see tools/ci_build/build.py
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/cmake"
    ${GENERATOR_OPTIONS}
    OPTIONS
        ${FEATURE_OPTIONS}
        -DPython_EXECUTABLE:FILEPATH=${PYTHON3}
        -DProtobuf_PROTOC_EXECUTABLE:FILEPATH=${PROTOC}
        # -DProtobuf_USE_STATIC_LIBS=OFF
        -DBUILD_PKGCONFIG_FILES=ON
        -Donnxruntime_BUILD_SHARED_LIB=${BUILD_SHARED}
        -Donnxruntime_BUILD_WEBASSEMBLY=OFF
        -Donnxruntime_CROSS_COMPILING=${VCPKG_CROSSCOMPILING}
        -Donnxruntime_USE_FULL_PROTOBUF=ON
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
        -Donnxruntime_DISABLE_ABSEIL=OFF
        -Donnxruntime_USE_NEURAL_SPEED=OFF
        -DUSE_NEURAL_SPEED=OFF
        # for ORT_BUILD_INFO
        -DORT_GIT_COMMIT:STRING="387127404e6c1d84b3468c387d864877ed1c67fe"
        -DORT_GIT_BRANCH:STRING="v1.18.1"
        --compile-no-warning-as-error
    OPTIONS_DEBUG
        -Donnxruntime_ENABLE_MEMLEAK_CHECKER=OFF
        -Donnxruntime_ENABLE_MEMORY_PROFILE=OFF
        -Donnxruntime_DEBUG_NODE_INPUTS_OUTPUTS=1
    MAYBE_UNUSED_VARIABLES
        onnxruntime_BUILD_WEBASSEMBLY
        onnxruntime_TENSORRT_PLACEHOLDER_BUILDER
        onnxruntime_USE_CUSTOM_DIRECTML
        onnxruntime_NVCC_THREADS
)
if("cuda" IN_LIST FEATURES)
    vcpkg_cmake_build(TARGET onnxruntime_providers_cuda LOGFILE_BASE build-cuda)
endif()
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/onnxruntime PACKAGE_NAME onnxruntime)
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig() # pkg_check_modules(libonnxruntime)

if("test" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES onnx_test_runner AUTO_CLEAN)
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/bin" "${CURRENT_PACKAGES_DIR}/bin")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
