if(NOT VCPKG_TARGET_IS_IOS)
    vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/onnxruntime
    REF v1.12.1
    SHA512 fc2e8be54fbeb32744c8882e61aa514be621eb621a073d05a85c6e2deac8c9bf1103e746711f5c33a4fa55a257807ba0159d9f23684f4926ff38b40591575d91
    PATCHES
        fix-cmake.patch
        fix-sources.patch
        # https://learn.microsoft.com/en-us/cpp/porting/modifying-winver-and-win32-winnt
        # support-windows10.patch
)

find_program(FLATC NAMES flatc
    PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/flatbuffers"
    REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH
)
message(STATUS "Using flatc: ${FLATC}")

set(SCHEMA_DIR "${SOURCE_PATH}/onnxruntime/core/flatbuffers/schema")
vcpkg_execute_required_process(
    COMMAND ${FLATC} --cpp ort.fbs
    LOGNAME codegen-flatc-cpp
    WORKING_DIRECTORY "${SCHEMA_DIR}"
)
file(REMOVE "${SCHEMA_DIR}/ort.fbs.h")
file(RENAME "${SCHEMA_DIR}/ort_generated.h" "${SCHEMA_DIR}/ort.fbs.h")

if("xnnpack" IN_LIST FEATURES)
    # see https://github.com/microsoft/onnxruntime/pull/11798
    set(PROVIDERS_DIR "${SOURCE_PATH}/include/onnxruntime/core/providers")
    file(MAKE_DIRECTORY "${PROVIDERS_DIR}/xnnpack")
    file(WRITE "${PROVIDERS_DIR}/xnnpack/xnnpack_provider_factory.h" "#pragma once")
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        training  onnxruntime_ENABLE_TRAINING
        training  onnxruntime_ENABLE_TRAINING_OPS
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
        test      onnxruntime_BUILD_UNIT_TESTS
        framework onnxruntime_BUILD_APPLE_FRAMEWORK
    INVERTED_FEATURES
        abseil   onnxruntime_DISABLE_ABSEIL

)

if(VCPKG_TARGET_IS_UWP)
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

vcpkg_find_acquire_program(PYTHON3)
message(STATUS "Using Python3: ${PYTHON3}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/cmake"
    ${CONFIG_OPTIONS}
    OPTIONS
        ${GENERATOR_OPTIONS}
        ${FEATURE_OPTIONS}
        -DPython_EXECUTABLE:FILEPATH=${PYTHON3}
        # -DProtobuf_USE_STATIC_LIBS=OFF
        -DBUILD_PKGCONFIG_FILES=ON
        -Donnxruntime_BUILD_SHARED_LIB=${BUILD_SHARED}
        -Donnxruntime_BUILD_OBJC=${VCPKG_TARGET_IS_IOS}
        -Donnxruntime_BUILD_NODEJS=OFF
        -Donnxruntime_BUILD_JAVA=OFF
        -Donnxruntime_BUILD_CSHARP=OFF
        -Donnxruntime_BUILD_WEBASSEMBLY=OFF
        -Donnxruntime_CROSS_COMPILING=${VCPKG_CROSSCOMPILING}
        -Donnxruntime_PREFER_SYSTEM_LIB=ON
        -Donnxruntime_USE_FULL_PROTOBUF=ON
        -Donnxruntime_USE_PREINSTALLED_EIGEN=ON -Deigen_SOURCE_PATH="${CURRENT_INSTALLED_DIR}/include"
        -Donnxruntime_USE_EXTENSIONS=OFF
        -Donnxruntime_USE_MPI=OFF # ${VCPKG_TARGET_IS_LINUX}
        -Donnxruntime_ENABLE_CPUINFO=ON
        -Donnxruntime_ENABLE_MICROSOFT_INTERNAL=${VCPKG_TARGET_IS_WINDOWS}
        -Donnxruntime_ENABLE_BITCODE=${VCPKG_TARGET_IS_IOS}
        -Donnxruntime_ENABLE_PYTHON=OFF
        -Donnxruntime_ENABLE_EXTERNAL_CUSTOM_OP_SCHEMAS=OFF
    OPTIONS_DEBUG
        -Donnxruntime_ENABLE_MEMLEAK_CHECKER=OFF
        -Donnxruntime_ENABLE_MEMORY_PROFILE=OFF
        -Donnxruntime_ENABLE_CUDA_PROFILING=ON
        -Donnxruntime_DEBUG_NODE_INPUTS_OUTPUTS=ON
)
vcpkg_cmake_build(TARGET onnxruntime)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig() # pkg_check_modules(libonnxruntime)

if(VCPKG_TARGET_IS_IOS)
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
