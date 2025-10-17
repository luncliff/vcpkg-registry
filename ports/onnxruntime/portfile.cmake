vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

set(ORT_GIT_COMMIT "be835efc56aca19b8e810538ec93c8e150e0fc61")
set(ORT_GIT_BRANCH "v${VERSION}")

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/onnxruntime
    REF ${ORT_GIT_BRANCH}
    SHA512 65685eb7d8d832961a83e21e8e4a7a93b9189f13ef2456e4b265efa8d70d20b4064b1bb62a6f46271cb3c91742051fee473acf7b9f7e9d62926e1da07f772acb
    # PATCHES
    #     fix-sources.patch
    #     fix-cmake.patch
    #     fix-cmake-cuda.patch
    #     fix-cmake-training.patch
    #     fix-cmake-tensorrt.patch
)

find_program(PROTOC NAMES protoc PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf" REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH)
message(STATUS "Using protoc: ${PROTOC}")

find_program(FLATC NAMES flatc PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/flatbuffers" REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH)
message(STATUS "Using flatc: ${FLATC}")

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
message(STATUS "Using python3: ${PYTHON3}")
vcpkg_add_to_path(PREPEND "${PYTHON_PATH}")

vcpkg_execute_required_process(
    COMMAND "${PYTHON3}" onnxruntime/core/flatbuffers/schema/compile_schema.py --flatc "${FLATC}"
    LOGNAME compile_schema_core
    WORKING_DIRECTORY "${SOURCE_PATH}"
)
vcpkg_execute_required_process(
    COMMAND "${PYTHON3}" onnxruntime/lora/adapter_format/compile_schema.py --flatc "${FLATC}"
    LOGNAME compile_schema_lora
    WORKING_DIRECTORY "${SOURCE_PATH}"
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        python    onnxruntime_ENABLE_PYTHON
        training  onnxruntime_ENABLE_TRAINING
        training  onnxruntime_ENABLE_TRAINING_APIS
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
        test      onnxruntime_BUILD_UNIT_TESTS
        test      onnxruntime_BUILD_BENCHMARKS
        test      onnxruntime_RUN_ONNX_TESTS
        framework onnxruntime_BUILD_APPLE_FRAMEWORK
        framework onnxruntime_BUILD_OBJC
        nccl      onnxruntime_USE_NCCL
    INVERTED_FEATURES
        cuda      onnxruntime_USE_MEMORY_EFFICIENT_ATTENTION
)

if("training" IN_LIST FEATURES)
    vcpkg_from_github(
        OUT_SOURCE_PATH TENSORBOARD_SOURCE_PATH
        REPO tensorflow/tensorboard
        REF 2.16.2
        SHA512 0dc57928d55ebd46386d0f0852b3b4e9078222bd4378655abb16f6bc0e5ed2969600071d5d2ae9a3f2aa6bb327fe567869a01a69fdda35c261dc44a1eadd18ce
    )
    list(APPEND FEATURE_OPTIONS "-DTENSORBOARD_ROOT:PATH=${TENSORBOARD_SOURCE_PATH}")
endif()

if("cuda" IN_LIST FEATURES)
    vcpkg_find_cuda(OUT_CUDA_TOOLKIT_ROOT cuda_toolkit_root)
    message(STATUS "Using nvcc: ${NVCC}")
    list(APPEND FEATURE_OPTIONS
        "-DCMAKE_CUDA_COMPILER=${NVCC}"
        "-DCUDAToolkit_ROOT=${cuda_toolkit_root}"
        # "-DCMAKE_CUDA_ARCHITECTURES=native"
        # too much warnings about attribute
        "-DCMAKE_CUDA_FLAGS=-Xcudafe --diag_suppress=2803 -Wno-deprecated-gpu-targets"
    )
endif()

if("tensorrt" IN_LIST FEATURES)
    if(DEFINED ENV{TENSORRT_HOME})
        set(TENSORRT_HOME "$ENV{TENSORRT_HOME}")
    endif()
    if(DEFINED TENSORRT_HOME)
        message(STATUS "Using TensorRT: ${TENSORRT_HOME}")
        list(APPEND FEATURE_OPTIONS "-Donnxruntime_TENSORRT_HOME:PATH=${TENSORRT_HOME}")
    else()
        message(WARNING "Define TENSORRT_HOME in the triplet or environment variables. If the environment variable is not visible, check the VCPKG_KEEP_ENV_VARS.")
    endif()
endif()

# see vcpkg_check_linkage above ...
string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" BUILD_SHARED)

# future works?
# onnxruntime_ORT_MINIMAL_BUILD=${BUILD_MINIMAL}

# see tools/ci_build/build.py
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/cmake"
    WINDOWS_USE_MSBUILD
    OPTIONS
        ${FEATURE_OPTIONS}
        "-DPython_EXECUTABLE:FILEPATH=${PYTHON3}"
        "-DProtobuf_PROTOC_EXECUTABLE:FILEPATH=${PROTOC}"
        "-DONNX_CUSTOM_PROTOC_EXECUTABLE:FILEPATH=${PROTOC}"
        -DBUILD_PKGCONFIG_FILES=ON
        -Donnxruntime_BUILD_SHARED_LIB=${BUILD_SHARED}
        -Donnxruntime_CROSS_COMPILING=${VCPKG_CROSSCOMPILING}
        -Donnxruntime_USE_EXTENSIONS=OFF
        -Donnxruntime_USE_NNAPI_BUILTIN=${VCPKG_TARGET_IS_ANDROID}
        -Donnxruntime_USE_VCPKG=ON
        -Donnxruntime_ENABLE_CPUINFO=ON
        -Donnxruntime_ENABLE_MICROSOFT_INTERNAL=OFF
        -Donnxruntime_ENABLE_BITCODE=OFF
        -Donnxruntime_ENABLE_PYTHON=OFF
        -Donnxruntime_ENABLE_EXTERNAL_CUSTOM_OP_SCHEMAS=OFF
        -Donnxruntime_ENABLE_MEMORY_PROFILE=OFF
        -Donnxruntime_ENABLE_LAZY_TENSOR=OFF
        -Donnxruntime_DISABLE_RTTI=OFF
        -Donnxruntime_DISABLE_ABSEIL=OFF
        # for ORT_BUILD_INFO
        -DORT_GIT_COMMIT=${ORT_GIT_COMMIT}
        -DORT_GIT_BRANCH=${ORT_GIT_BRANCH}
        # some other customizations ...
        --compile-no-warning-as-error
    OPTIONS_DEBUG
        -Donnxruntime_ENABLE_MEMLEAK_CHECKER=OFF
        -Donnxruntime_ENABLE_MEMORY_PROFILE=OFF
        -Donnxruntime_DEBUG_NODE_INPUTS_OUTPUTS=1
    MAYBE_UNUSED_VARIABLES
        onnxruntime_TENSORRT_PLACEHOLDER_BUILDER
        onnxruntime_USE_CUSTOM_DIRECTML
        onnxruntime_NVCC_THREADS
        CMAKE_CUDA_FLAGS
)
if("cuda" IN_LIST FEATURES)
    vcpkg_cmake_build(TARGET onnxruntime_providers_cuda LOGFILE_BASE build-cuda)
endif()
if("tensorrt" IN_LIST FEATURES)
    vcpkg_cmake_build(TARGET onnxruntime_providers_tensorrt LOGFILE_BASE build-tensorrt)
endif()
if("directml" IN_LIST FEATURES)
    vcpkg_cmake_build(TARGET onnxruntime_providers_dml LOGFILE_BASE build-directml)
endif()
if("training" IN_LIST FEATURES)
    vcpkg_cmake_build(TARGET tensorboard LOGFILE_BASE build-tensorboard)
endif()
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/onnxruntime PACKAGE_NAME onnxruntime)
vcpkg_fixup_pkgconfig() # pkg_check_modules(libonnxruntime)

# cmake function which relocates the onnxruntime_providers_* library before vcpkg_copy_pdbs()
function(reolocate_ort_providers)
    if(VCPKG_TARGET_IS_WINDOWS AND (VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic"))
        # the target is expected to be used without the .lib files
        file(GLOB PROVIDE_BINS_DBG  "${CURRENT_PACKAGES_DIR}/debug/lib/onnxruntime_providers_*.dll")
        file(COPY ${PROVIDE_BINS_DBG} DESTINATION "${CURRENT_PACKAGES_DIR}/debug/bin")
        file(GLOB PROVIDE_BINS_REL "${CURRENT_PACKAGES_DIR}/lib/onnxruntime_providers_*.dll")
        file(COPY ${PROVIDE_BINS_REL} DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
        file(REMOVE ${PROVIDE_BINS_DBG} ${PROVIDE_BINS_REL})
    endif()
endfunction()

reolocate_ort_providers()
vcpkg_copy_pdbs()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/bin" "${CURRENT_PACKAGES_DIR}/bin")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
