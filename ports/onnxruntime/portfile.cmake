if(NOT VCPKG_TARGET_IS_IOS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()
if(VCPKG_TARGET_IS_OSX AND ("framework" IN_LIST FEATURES))
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()
vcpkg_find_acquire_program(NUGET)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/onnxruntime
    REF v1.16.0 # e7a0495a874251e9747b2ce0683e0580282c54df
    SHA512 ff448f7bcd0d91f129ff7d5bf54ab0ed8f4aed79c79a6e52043138d5cba180099fce5aaf00e7f959e2b3e9a3376bf4ec933428c076b097a2e4a96e1adfd9b05f
    PATCHES
        fix-cmake.patch
        fix-source-flatbuffers.patch
)

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
    COMMAND ${FLATC} --cpp --scoped-enums --filename-suffix ".fbs" ort.fbs
    LOGNAME codegen-flatc-cpp
    WORKING_DIRECTORY "${SCHEMA_DIR}"
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        python    onnxruntime_ENABLE_PYTHON
        python    onnxruntime_ENABLE_LANGUAGE_INTEROP_OPS
        training  onnxruntime_ENABLE_TRAINING
        training  onnxruntime_ENABLE_TRAINING_OPS # todo: port `tensorboard`
        cuda      onnxruntime_USE_CUDA
        cuda      onnxruntime_USE_NCCL
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
    INVERTED_FEATURES
        abseil   onnxruntime_DISABLE_ABSEIL
)

if(VCPKG_TARGET_IS_WINDOWS OR VCPKG_TARGET_IS_UWP)
    # For some reason CUDA compiler detection is not working in WINDOWS_USE_MSBUILD
    # set(GENERATOR_OPTIONS WINDOWS_USE_MSBUILD)
elseif(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
    set(GENERATOR_OPTIONS GENERATOR Xcode)
else()
    set(GENERATOR_OPTIONS GENERATOR Ninja)
endif()

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

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" BUILD_SHARED)

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
    message(STATUS "Using CUDA: $ENV{CUDA_PATH}")
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/cmake"
    ${GENERATOR_OPTIONS}
    OPTIONS
        ${ARCH_OPTIONS}
        ${FEATURE_OPTIONS}
        -DNUGET_EXE:FILEPATH:=${NUGET}
        -DPython_EXECUTABLE:FILEPATH=${PYTHON3}
        -DProtobuf_PROTOC_EXECUTABLE:FILEPATH=${PROTOC}
        # -DProtobuf_USE_STATIC_LIBS=OFF
        -DBUILD_PKGCONFIG_FILES=ON
        -Donnxruntime_BUILD_SHARED_LIB=${BUILD_SHARED}
        -Donnxruntime_BUILD_WEBASSEMBLY=OFF
        -Donnxruntime_CROSS_COMPILING=${VCPKG_CROSSCOMPILING}
        -Donnxruntime_USE_FULL_PROTOBUF=ON
        -Donnxruntime_USE_PREINSTALLED_EIGEN=ON
        -Donnxruntime_USE_EXTENSIONS=OFF
        -Donnxruntime_USE_MPI=OFF # ${VCPKG_TARGET_IS_LINUX}
        -Donnxruntime_ENABLE_CPUINFO=ON
        -Donnxruntime_ENABLE_MICROSOFT_INTERNAL=OFF
        -Donnxruntime_ENABLE_BITCODE=${VCPKG_TARGET_IS_IOS}
        -Donnxruntime_ENABLE_PYTHON=OFF
        -Donnxruntime_ENABLE_EXTERNAL_CUSTOM_OP_SCHEMAS=OFF
        -Donnxruntime_ENABLE_LAZY_TENSOR=OFF
        # for ORT_BUILD_INFO
        -DORT_GIT_COMMIT:STRING="e7a0495a874251e9747b2ce0683e0580282c54df"
        -DORT_GIT_BRANCH:STRING="v1.16.0"
    OPTIONS_DEBUG
        -Donnxruntime_ENABLE_MEMLEAK_CHECKER=OFF
        -Donnxruntime_ENABLE_MEMORY_PROFILE=OFF
        -Donnxruntime_ENABLE_CUDA_PROFILING=ON
        -Donnxruntime_DEBUG_NODE_INPUTS_OUTPUTS=ON
    MAYBE_UNUSED_VARIABLES
        NUGET_EXE
        onnxruntime_BUILD_WEBASSEMBLY
        onnxruntime_TENSORRT_PLACEHOLDER_BUILDER
        onnxruntime_USE_CUSTOM_DIRECTML
)
if("training" IN_LIST FEATURES)
    vcpkg_cmake_build(TARGET onnxruntime_training LOGFILE_BASE build-training)
endif()
vcpkg_cmake_build(TARGET onnxruntime LOGFILE_BASE build-onnxruntime)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/onnxruntime PACKAGE_NAME onnxruntime)
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig() # pkg_check_modules(libonnxruntime)

if("test" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES onnx_test_runner AUTO_CLEAN)
endif()
if("framework" IN_LIST FEATURES)
    set(FRAMEWORK_NAME "onnxruntime.framework")
    file(RENAME "${CURRENT_PACKAGES_DIR}/debug/bin/${FRAMEWORK_NAME}"
                "${CURRENT_PACKAGES_DIR}/debug/lib/${FRAMEWORK_NAME}"
    )
    file(RENAME "${CURRENT_PACKAGES_DIR}/bin/${FRAMEWORK_NAME}"
                "${CURRENT_PACKAGES_DIR}/lib/${FRAMEWORK_NAME}"
    )
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    file(REMOVE_RECURSE
        "${CURRENT_PACKAGES_DIR}/debug/bin"
        "${CURRENT_PACKAGES_DIR}/bin"
    )
endif()

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
