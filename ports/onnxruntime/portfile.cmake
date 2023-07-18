if(NOT VCPKG_TARGET_IS_IOS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()
vcpkg_find_acquire_program(NUGET)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/onnxruntime
    REF v1.14.1
    SHA512 d8f7ea161e850a738b9a22187662218871f88ad711282c58631196a74f4a4567184047bab0001b973f841a3b63c7dc7e350f92306cc5fa9a7adc4db2ce09766f
    PATCHES
        fix-cmake.patch
        import-flatbuffers.patch
        fix-cmake2.patch
        fix-cmake3.patch
        fix-cmake4.patch # todo: use downloaded NuGet.exe
)

if("training" IN_LIST FEATURES)
    vcpkg_from_github(
        OUT_SOURCE_PATH TENSORBOARD_SOURCE_PATH # just for .proto files
        REPO tensorflow/tensorboard
        REF 2.13.0
        SHA512 c4c2770552dc0816cde1350ba2676f4660d2c9e0a911544620b5e93089d94dedd328efe23316801f1959c40706519141aeb30cdb5072fca231443d11a1ffb2eb
    )
endif()

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

if("xnnpack" IN_LIST FEATURES)
    # see https://github.com/microsoft/onnxruntime/pull/11798
    set(PROVIDERS_DIR "${SOURCE_PATH}/include/onnxruntime/core/providers")
    file(MAKE_DIRECTORY "${PROVIDERS_DIR}/xnnpack")
    file(WRITE "${PROVIDERS_DIR}/xnnpack/xnnpack_provider_factory.h" "#pragma once")
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        python    onnxruntime_ENABLE_PYTHON
        python    onnxruntime_ENABLE_LANGUAGE_INTEROP_OPS
        training  onnxruntime_ENABLE_TRAINING
        training  onnxruntime_ENABLE_TRAINING_OPS # todo: port `tensorboard`
        cuda      onnxruntime_USE_CUDA
        cuda      onnxruntime_USE_NCCL
        tensorrt  onnxruntime_USE_TENSORRT
        tensorrt  onnxruntime_TENSORRT_PLACEHOLDER_BUILDER
        directml  onnxruntime_USE_DML
        winml     onnxruntime_USE_WINML
        coreml    onnxruntime_USE_COREML
        mimalloc  onnxruntime_USE_MIMALLOC
        valgrind  onnxruntime_USE_VALGRIND
        xnnpack   onnxruntime_USE_XNNPACK
        nnapi     onnxruntime_USE_NNAPI_BUILTIN
        azure     onnxruntime_USE_AZURE
        llvm      onnxruntime_USE_LLVM
        test      onnxruntime_BUILD_UNIT_TESTS
        framework onnxruntime_BUILD_APPLE_FRAMEWORK
        framework onnxruntime_BUILD_OBJC
    INVERTED_FEATURES
        abseil   onnxruntime_DISABLE_ABSEIL
)

if(VCPKG_TARGET_IS_WINDOWS OR VCPKG_TARGET_IS_UWP)
    set(CONFIG_OPTIONS WINDOWS_USE_MSBUILD)
else()
    set(CONFIG_OPTIONS GENERATOR Ninja)
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    # target platform should be informed to activate SIMD properly
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        list(APPEND GENERATOR_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="x64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
        list(APPEND GENERATOR_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="Win32")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        list(APPEND GENERATOR_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="ARM64")
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm")
        list(APPEND GENERATOR_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="ARM")
    else()
        message(WARNING "Unexpected architecture: ${VCPKG_TARGET_ARCHITECTURE}")
        list(APPEND GENERATOR_OPTIONS -DCMAKE_SYSTEM_PROCESSOR="${VCPKG_TARGET_ARCHITECTURE}")
    endif()
endif()

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" BUILD_SHARED)

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

if("training" IN_LIST FEATURES)
    # todo: dlpack in onnxruntime_provider. see `onnxruntime_ENABLE_ATEN`, https://github.com/dmlc/dlpack
    list(APPEND FEATURE_OPTIONS
        -DTENSORBOARD_ROOT:PATH=${TENSORBOARD_SOURCE_PATH}
    )
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/cmake"
    ${CONFIG_OPTIONS}
    OPTIONS
        ${GENERATOR_OPTIONS}
        ${FEATURE_OPTIONS}
        -Dnuget_exe:FILEPATH:=${NUGET}
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
        -Donnxruntime_ENABLE_MICROSOFT_INTERNAL=${VCPKG_TARGET_IS_WINDOWS}
        -Donnxruntime_ENABLE_BITCODE=${VCPKG_TARGET_IS_IOS}
        -Donnxruntime_ENABLE_PYTHON=OFF
        -Donnxruntime_ENABLE_EXTERNAL_CUSTOM_OP_SCHEMAS=OFF
        -Donnxruntime_ENABLE_LAZY_TENSOR=OFF
    OPTIONS_DEBUG
        -Donnxruntime_ENABLE_MEMLEAK_CHECKER=OFF
        -Donnxruntime_ENABLE_MEMORY_PROFILE=OFF
        -Donnxruntime_ENABLE_CUDA_PROFILING=ON
        -Donnxruntime_DEBUG_NODE_INPUTS_OUTPUTS=ON
)
if("training" IN_LIST FEATURES)
    vcpkg_cmake_build(TARGET onnxruntime_training LOGFILE_BASE build-training)
endif()
vcpkg_cmake_build(TARGET onnxruntime LOGFILE_BASE build-onnxruntime)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig() # pkg_check_modules(libonnxruntime)

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
