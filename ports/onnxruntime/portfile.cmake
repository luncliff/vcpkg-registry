if(VCPKG_TARGET_IS_WINDOWS)
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
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        training onnxruntime_ENABLE_TRAINING
        training onnxruntime_ENABLE_TRAINING_OPS
        cuda     onnxruntime_USE_CUDA
        cuda     onnxruntime_USE_NCCL
        tensorrt onnxruntime_USE_TENSORRT
        tensorrt onnxruntime_TENSORRT_PLACEHOLDER_BUILDER
        directml onnxruntime_USE_DML
        winml    onnxruntime_USE_WINML
        mimalloc onnxruntime_USE_MIMALLOC
        valgrind onnxruntime_USE_VALGRIND
        xnnpack  onnxruntime_USE_XNNPACK
    INVERTED_FEATURES
        abseil onnxruntime_DISABLE_ABSEIL

)

if(VCPKG_TARGET_IS_WINDOWS)
    # target platform should be informed to activate SIMD properly
    if(TARGET_TRIPLET MATCHES [Xx]64)
        list(APPEND PLATFORM_OPTIONS -DCMAKE_GENERATOR_PLATFORM="x64")
    elseif(TARGET_TRIPLET MATCHES [Xx]86)
        list(APPEND PLATFORM_OPTIONS -DCMAKE_GENERATOR_PLATFORM="Win32")
    endif()
endif()

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" BUILD_SHARED)

vcpkg_find_acquire_program(PYTHON3)
message(STATUS "Using Python3: ${PYTHON3}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/cmake"
    WINDOWS_USE_MSBUILD
    GENERATOR Ninja
    OPTIONS
        ${FEATURE_OPTIONS}
        ${PLATFORM_OPTIONS}
        -DPython_EXECUTABLE="${PYTHON3}"
        # -DProtobuf_USE_STATIC_LIBS=OFF
        -DBUILD_PKGCONFIG_FILES=ON
        -Donnxruntime_BUILD_SHARED_LIB=${BUILD_SHARED}
        -Donnxruntime_BUILD_UNIT_TESTS=OFF
        -Donnxruntime_CROSS_COMPILING=${VCPKG_CROSSCOMPILING}
        -Donnxruntime_ENABLE_MICROSOFT_INTERNAL=${VCPKG_TARGET_IS_WINDOWS}
        -Donnxruntime_PREFER_SYSTEM_LIB=ON
        -Donnxruntime_USE_FULL_PROTOBUF=ON
        -Donnxruntime_USE_PREINSTALLED_EIGEN=ON -Deigen_SOURCE_PATH="${CURRENT_INSTALLED_DIR}/include"
        -Donnxruntime_USE_EXTENSIONS=OFF
        -Donnxruntime_USE_MPI=${VCPKG_TARGET_IS_LINUX}
        -Donnxruntime_ENABLE_BITCODE=${VCPKG_TARGET_IS_IOS}
        -Donnxruntime_ENABLE_PYTHON=OFF
        -Donnxruntime_ENABLE_EXTERNAL_CUSTOM_OP_SCHEMAS=OFF
    OPTIONS_DEBUG
        -Donnxruntime_ENABLE_MEMLEAK_CHECKER=OFF
        -Donnxruntime_ENABLE_MEMORY_PROFILE=OFF
        -Donnxruntime_ENABLE_CUDA_PROFILING=ON
        -Donnxruntime_DEBUG_NODE_INPUTS_OUTPUTS=ON
)
if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_cmake_build(TARGET onnxruntime)
endif()
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig() # pkg_check_modules(libonnxruntime)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

file(INSTALL "${SOURCE_PATH}/LICENSE"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright
)
