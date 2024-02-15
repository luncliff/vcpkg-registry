vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

# todo: https://github.com/pytorch/pytorch/tree/v2.2.0
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/pytorch
    REF "v${VERSION}"
    SHA512 e2fec0fa5e7c6f7445ba16f795578629646ca78c94c74ef89bf1748e98db21fba23aa98f7cce23bcda5420eae89400e02fc3dd047129916cecbc36e579a03908
    PATCHES
        fix-build.patch
        fix-windows.patch # https://github.com/pytorch/pytorch/issues/87957
        fix-linkage.patch
)
file(REMOVE_RECURSE "${SOURCE_PATH}/caffe2/core/macros.h") # We must use generated header files

# Editing ${SOURCE_PATH}/cmake/Dependencies.cmake makes HORRIBLE readability...
file(COPY "${CMAKE_CURRENT_LIST_DIR}/vcpkg-dependencies.cmake" DESTINATION "${SOURCE_PATH}/cmake")

find_program(FLATC NAMES flatc PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/flatbuffers" REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH)
message(STATUS "Using flatc: ${FLATC}")

vcpkg_execute_required_process(
    COMMAND ${FLATC} --cpp --gen-mutable --scoped-enums --no-prefix mobile_bytecode.fbs
    LOGNAME codegen-flatc-mobile_bytecode
    WORKING_DIRECTORY "${SOURCE_PATH}/torch/csrc/jit/serialization"
)

find_program(PROTOC NAMES protoc PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf" REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH)
message(STATUS "Using protoc: ${PROTOC}")

# vcpkg_find_acquire_program(PYTHON3)
x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    PACKAGES numpy typing-extensions pyyaml sympy
    OUT_PYTHON_VAR PYTHON3
)
message(STATUS "Using Python3: ${PYTHON3}")
get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
vcpkg_add_to_path(PREPEND "${PYTHON_PATH}")

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
  FEATURES
    dist    USE_DISTRIBUTED # MPI, Gloo, TensorPipe
    zstd    USE_ZSTD
    fftw3   USE_FFTW
    fftw3   AT_FFTW_ENABLED
    fbgemm  USE_FBGEMM
    opencv  USE_OPENCV
    tbb     USE_TBB
    tbb     AT_PARALLEL_NATIVE_TBB
    openmp  USE_OPENMP
    openmp  AT_PARALLEL_OPENMP
    leveldb USE_LEVELDB
    opencl  USE_OPENCL
    cuda    USE_CUDA
    cuda    USE_CUDNN
    cuda    USE_NCCL
    cuda    USE_SYSTEM_NCCL
    cuda    USE_NVRTC
    cuda    AT_CUDA_ENABLED
    cuda    AT_CUDNN_ENABLED
    vulkan  USE_VULKAN
    vulkan  USE_VULKAN_FP16_INFERENCE
    vulkan  USE_VULKAN_RELAXED_PRECISION
    nnpack  USE_NNPACK  # todo: check use of `DISABLE_NNPACK_AND_FAMILY`
    nnpack  AT_NNPACK_ENABLED
    xnnpack USE_XNNPACK
    xnnpack USE_SYSTEM_XNNPACK
    qnnpack USE_QNNPACK # todo: check use of `USE_PYTORCH_QNNPACK`
)

if(NOT VCPKG_TARGET_IS_WINDOWS)
    list(APPEND FEATURE_OPTIONS -DUSE_NATIVE_ARCH=ON)
endif()
if("dist" IN_LIST FEATURES)
    if(VCPKG_TARGET_IS_LINUX OR VCPKG_TARGET_IS_OSX)
        list(APPEND FEATURE_OPTIONS -DUSE_TENSORPIPE=ON)
    endif()
    if(VCPKG_TARGET_IS_WINDOWS OR VCPKG_TARGET_IS_OSX)
        list(APPEND FEATURE_OPTIONS -DUSE_LIBUV=ON)
    endif()
    list(APPEND FEATURE_OPTIONS -DUSE_GLOO=${VCPKG_TARGET_IS_LINUX})
endif()

# BLAS: MKL, OpenBLAS, or Accelerate
#   The feature will be disabled if "generic" BLAS is not found
if(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
    list(APPEND BLAS_OPTIONS -DBLAS=Accelerate -DUSE_BLAS=ON)
elseif(VCPKG_TARGET_IS_WINDOWS)
    list(APPEND BLAS_OPTIONS -DBLAS=OpenBLAS -DUSE_BLAS=ON)
elseif(VCPKG_TARGET_IS_LINUX)
    list(APPEND BLAS_OPTIONS -DBLAS=generic -DUSE_BLAS=ON)
endif()

if("tbb" IN_LIST FEATURES)
    list(APPEND FEATURE_OPTIONS -DMKLDNN_CPU_RUNTIME=TBB)
endif()

if(VCPKG_TARGET_IS_ANDROID OR VCPKG_TARGET_IS_IOS)
    list(APPEND FEATURE_OPTIONS -DINTERN_BUILD_MOBILE=ON)
else()
    list(APPEND FEATURE_OPTIONS -DINTERN_BUILD_MOBILE=OFF)
endif()

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_STATIC_RUNTIME)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    DISABLE_PARALLEL_CONFIGURE
    OPTIONS
        ${FEATURE_OPTIONS}
        -DProtobuf_PROTOC_EXECUTABLE:FILEPATH=${PROTOC}
        -DCAFFE2_CUSTOM_PROTOC_EXECUTABLE:FILEPATH=${PROTOC}
        -DPYTHON_EXECUTABLE:FILEPATH=${PYTHON3}
        -DPython3_EXECUTABLE:FILEPATH=${PYTHON3}
        -DCAFFE2_USE_MSVC_STATIC_RUNTIME=${USE_STATIC_RUNTIME}
        -DBUILD_CUSTOM_PROTOBUF=OFF
        -DUSE_LITE_PROTO=OFF
        -DBUILD_CAFFE2=ON
        -DBUILD_TEST=OFF
        -DATEN_NO_TEST=ON
        -DUSE_SYSTEM_LIBS=ON
        -DBUILD_PYTHON=OFF
        -DUSE_NUMPY=OFF
        -DUSE_METAL=${VCPKG_TARGET_IS_OSX}
        -DUSE_PYTORCH_METAL=${VCPKG_TARGET_IS_OSX}
        -DUSE_PYTORCH_METAL_EXPORT=${VCPKG_TARGET_IS_OSX}
        -DUSE_GFLAGS=ON
        -DUSE_GLOG=ON
        -DUSE_LMDB=ON
        -DUSE_ROCKSDB=OFF
        -DUSE_OBSERVERS=OFF 
        -DUSE_PYTORCH_QNNPACK=OFF
        -DUSE_KINETO=OFF
        -DUSE_ITT=OFF
        -DBUILD_LITE_INTERPRETER=OFF
        -DUSE_LITE_INTERPRETER_PROFILER=OFF
        -DUSE_ROCM=OFF
        -DUSE_DEPLOY=OFF
        -DUSE_FFTW=OFF
        -DUSE_NUMA=OFF
        -DUSE_MPI=${VCPKG_TARGET_IS_LINUX}
        -DUSE_MIMALLOC=${VCPKG_TARGET_IS_WINDOWS}
        -DBUILD_JNI=${VCPKG_TARGET_IS_ANDROID}
        -DUSE_NNAPI=${VCPKG_TARGET_IS_ANDROID}
        ${BLAS_OPTIONS}
        # BLAS=MKL not supported in this port
        -DUSE_MKLDNN=OFF
        -DUSE_MKLDNN_CBLAS=OFF
        -DCAFFE2_USE_MKL=OFF
    MAYBE_UNUSED_VARIABLES
        USE_NUMA
        USE_SYSTEM_BIND11
        USE_VULKAN_WRAPPER
        MKLDNN_CPU_RUNTIME
        USE_DEPLOY
)
vcpkg_cmake_build(TARGET __aten_op_header_gen LOGFILE_BASE build-header_gen) # explicit codegen is required
vcpkg_cmake_build(TARGET torch_cpu  LOGFILE_BASE build-torch_cpu)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME Torch CONFIG_PATH "share/cmake/Torch" DO_NOT_DELETE_PARENT_CONFIG_PATH)
vcpkg_cmake_config_fixup(PACKAGE_NAME Caffe2 CONFIG_PATH "share/cmake/Caffe2")
vcpkg_copy_pdbs()

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
        message(STATUS "Removed ${folder}")
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

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/share/cmake/ATen"
)
cleanup_repeat("${CURRENT_PACKAGES_DIR}/include" 5)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
