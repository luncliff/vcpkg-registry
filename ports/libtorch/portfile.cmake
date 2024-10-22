vcpkg_check_linkage(ONLY_DYNAMIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO pytorch/pytorch
    REF "v${VERSION}"
    SHA512 7e9b4485e242eaf0d648765c6621d73d95e7107b766646a098175436d1ab2e2b864badd0757a3bab6b7c318233f2120bad9ac07b39bb9e357897919580c87631
    HEAD_REF main
    PATCHES
        fix-cmake.patch
        fix-sources.patch
        # todo: XNNPACK version update
)

file(REMOVE_RECURSE "${SOURCE_PATH}/caffe2/core/macros.h") # We must use generated header files

file(REMOVE
  "${SOURCE_PATH}/cmake/Modules/FindBLAS.cmake"
  "${SOURCE_PATH}/cmake/Modules/FindLAPACK.cmake"
  "${SOURCE_PATH}/cmake/Modules/FindCUDA.cmake"
  "${SOURCE_PATH}/cmake/Modules/FindCUDAToolkit.cmake"
  "${SOURCE_PATH}/cmake/Modules/Findpybind11.cmake"
)

find_program(FLATC NAMES flatc PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/flatbuffers" REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH)
message(STATUS "Using flatc: ${FLATC}")

vcpkg_execute_required_process(
    COMMAND ${FLATC} --cpp --no-prefix --scoped-enums --gen-mutable mobile_bytecode.fbs
    LOGNAME codegen-flatc-mobile_bytecode
    WORKING_DIRECTORY "${SOURCE_PATH}/torch/csrc/jit/serialization"
)

find_program(PROTOC NAMES protoc PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/protobuf" REQUIRED NO_DEFAULT_PATH NO_CMAKE_PATH)
message(STATUS "Using protoc: ${PROTOC}")

x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    PACKAGES typing-extensions pyyaml numpy pybind11
    OUT_PYTHON_VAR PYTHON3
)
message(STATUS "Using Python3: ${PYTHON3}")

get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
get_filename_component(PYTHON_ROOT "${PYTHON_PATH}" PATH)
find_path(SITE_PACKAGES_DIR
    NAMES "typing_extensions.py"
    PATHS "${PYTHON_ROOT}/Lib/site-packages"
          "${PYTHON_ROOT}/lib/python3.11/site-packages"
          "${PYTHON_ROOT}/lib/python3.12/site-packages"
    REQUIRED
)
get_filename_component(pybind11_DIR "${SITE_PACKAGES_DIR}/pybind11/share/cmake/pybind11" ABSOLUTE)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
  FEATURES
    dist    USE_DISTRIBUTED # MPI, Gloo, TensorPipe
    fbgemm  USE_FBGEMM
    # These are alternatives !
    # openmp  USE_OPENMP
    # openmp  AT_PARALLEL_OPENMP # AT_PARALLEL_ are alternatives
    opencl  USE_OPENCL
    cuda    USE_CUDA
    cuda    USE_CUDNN
    cuda    USE_NCCL
    cuda    USE_SYSTEM_NCCL
    cuda    USE_NVRTC
    cuda    AT_CUDA_ENABLED
    cuda    AT_CUDNN_ENABLED
    cuda    USE_MAGMA
    vulkan  USE_VULKAN
    vulkan  USE_VULKAN_RELAXED_PRECISION
    rocm    USE_ROCM  # This is an alternative to cuda not a feature! (Not in vcpkg.json!) -> disabled
    llvm    USE_LLVM
    mpi     USE_MPI
    nnpack  USE_NNPACK  # todo: check use of `DISABLE_NNPACK_AND_FAMILY`
    nnpack  AT_NNPACK_ENABLED
    qnnpack USE_PYTORCH_QNNPACK
    # No feature in vcpkg yet so disabled. -> Requires numpy build by vcpkg itself
    python  BUILD_PYTHON
    python  USE_NUMPY
)

if("dist" IN_LIST FEATURES)
    if(VCPKG_TARGET_IS_LINUX OR VCPKG_TARGET_IS_OSX)
        list(APPEND FEATURE_OPTIONS -DUSE_TENSORPIPE=ON)
    endif()
    if(VCPKG_TARGET_IS_OSX)
        list(APPEND FEATURE_OPTIONS -DUSE_LIBUV=ON)
    endif()
    list(APPEND FEATURE_OPTIONS -DUSE_GLOO=${VCPKG_TARGET_IS_LINUX})
endif()

if(VCPKG_TARGET_IS_ANDROID OR VCPKG_TARGET_IS_IOS)
    set(IS_MOBILE ON)
else()
    set(IS_MOBILE OFF)
endif()

if(VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_IOS)
    set(IS_APPLE ON)
else()
    set(IS_APPLE OFF)
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
        -Dpybind11_DIR:PATH=${pybind11_DIR}
        -DCAFFE2_USE_MSVC_STATIC_RUNTIME=${USE_STATIC_RUNTIME}
        -DBUILD_CUSTOM_PROTOBUF=OFF
        -DUSE_LITE_PROTO=OFF
        -DUSE_SYSTEM_LIBS=ON
        -DUSE_PYTORCH_METAL=${IS_APPLE}
        -DUSE_PYTORCH_METAL_EXPORT=${IS_APPLE}
        -DUSE_GFLAGS=ON
        -DUSE_GLOG=ON
        -DUSE_XNNPACK=ON
        -DUSE_ITT=OFF
        -DUSE_OBSERVERS=OFF
        -DUSE_KINETO=ON
        -DUSE_LITE_INTERPRETER_PROFILER=OFF
        -DBUILD_LITE_INTERPRETER=OFF
        -DUSE_NUMA=${VCPKG_TARGET_IS_LINUX}
        -DUSE_MIMALLOC=${VCPKG_TARGET_IS_WINDOWS}
        -DINTERN_BUILD_MOBILE=${IS_MOBILE}
        -DBUILD_JNI=${VCPKG_TARGET_IS_ANDROID}
        -DUSE_NNAPI=${VCPKG_TARGET_IS_ANDROID}
        # BLAS=MKL not supported in this port
        -DUSE_MKLDNN=OFF
        -DUSE_MKLDNN_CBLAS=OFF
        -DAT_MKLDNN_ENABLED=OFF
    MAYBE_UNUSED_VARIABLES
        PYTHON_EXECUTABLE
        USE_NUMA
)

vcpkg_cmake_install()
vcpkg_copy_pdbs()

vcpkg_cmake_config_fixup(PACKAGE_NAME Caffe2 CONFIG_PATH "share/cmake/Caffe2" DO_NOT_DELETE_PARENT_CONFIG_PATH)
vcpkg_cmake_config_fixup(PACKAGE_NAME Torch CONFIG_PATH "share/cmake/Torch")

# vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/Torch/TorchConfig.cmake" "/../../../" "/../../")
# vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/Caffe2/Caffe2Config.cmake" "/../../../" "/../../")
# vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/share/Caffe2/Caffe2Config.cmake"
#   "set(Caffe2_MAIN_LIBS torch_library)"
#   "set(Caffe2_MAIN_LIBS torch_library)\nfind_dependency(Eigen3)")

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

cleanup_repeat("${CURRENT_PACKAGES_DIR}/include" 5)
cleanup_repeat("${CURRENT_PACKAGES_DIR}/lib/site-packages" 13)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")

# Cannot build python bindings yet
#if("python" IN_LIST FEATURES)
#  set(ENV{USE_SYSTEM_LIBS} 1)
#  vcpkg_replace_string("${SOURCE_PATH}/setup.py" "@TARGET_TRIPLET@" "${TARGET_TRIPLET}-rel")
#  vcpkg_replace_string("${SOURCE_PATH}/tools/setup_helpers/env.py" "@TARGET_TRIPLET@" "${TARGET_TRIPLET}-rel")
#  vcpkg_replace_string("${SOURCE_PATH}/torch/utils/cpp_extension.py" "@TARGET_TRIPLET@" "${TARGET_TRIPLET}-rel")
#  vcpkg_python_build_and_install_wheel(SOURCE_PATH "${SOURCE_PATH}" OPTIONS -x)
#endif()

set(VCPKG_POLICY_DLLS_WITHOUT_EXPORTS enabled) # torch_global_deps.dll is empty.c and just for linking deps

set(config "${CURRENT_PACKAGES_DIR}/share/torch/TorchConfig.cmake")
file(READ "${config}" contents)
string(REGEX REPLACE "set\\\(NVTOOLEXT_HOME[^)]+" "set(NVTOOLEXT_HOME \"\$ENV{CUDA_PATH}\"" contents "${contents}")
#string(REGEX REPLACE "set\\\(NVTOOLEXT_HOME[^)]+" "set(NVTOOLEXT_HOME \"\${CMAKE_CURRENT_LIST_DIR}/../../tools/cuda/\"" contents "${contents}")
string(REGEX REPLACE "\\\${NVTOOLEXT_HOME}/lib/x64/nvToolsExt64_1.lib" "" contents "${contents}")
file(WRITE "${config}" "${contents}")

vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/torch/csrc/autograd/custom_function.h" "struct TORCH_API Function" "struct Function")
