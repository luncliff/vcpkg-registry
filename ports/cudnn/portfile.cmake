# Current port targets CUDA 12.x and 13.x
# Check the manifests in https://developer.download.nvidia.com/compute/cudnn/redist/
# - redistrib_9.0.0.json: CUDA 11,12
# - redistrib_9.10.2.json: CUDA 11,12
# - redistrib_9.11.1.json: CUDA 12
# - redistrib_9.12.0.json: CUDA 12,13
set(MINIMUM_CUDNN_VERSION "9.11.1")

# vcpkg_find_cuda function is from 'cuda' port
vcpkg_find_cuda(OUT_CUDA_TOOLKIT_ROOT CUDA_TOOLKIT_ROOT OUT_CUDA_VERSION CUDA_VERSION)

# if CUDA_TOOLKIT_ROOT is not found, we will use several environment variables: e.g. CUDNN_ROOT_DIR

# NVIDIA CUDA Deep Neural Network library
# https://developer.nvidia.com/cudnn-archive
# https://docs.nvidia.com/deeplearning/cudnn/backend/latest/api/overview.html#api-overview
include("${CURRENT_PORT_DIR}/FindCUDNN.cmake")

if (CUDNN_INCLUDE_DIR AND CUDNN_LIBRARY AND _CUDNN_VERSION VERSION_GREATER_EQUAL MINIMUM_CUDNN_VERSION)
  message(STATUS "Found CUDNN ${_CUDNN_VERSION} on system: (include: \"${CUDNN_INCLUDE_DIR}\", lib: \"${CUDNN_LIBRARY}\")")
  set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
elseif(VCPKG_TARGET_IS_WINDOWS)
  message(FATAL_ERROR "Please download CUDNN from official sources (https://developer.nvidia.com/cudnn) and install it")
else()
  message(FATAL_ERROR "Please install CUDNN using your system package manager (the same way you installed CUDA)")
endif()

file(
  INSTALL "${CURRENT_PORT_DIR}/FindCUDNN.cmake"
          "${CURRENT_PORT_DIR}/usage"
          "${CURRENT_PORT_DIR}/vcpkg-cmake-wrapper.cmake"
  DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}"
)

vcpkg_download_distfile(CUDNN_LICENSE_FILE
  URLS "https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/LICENSE.txt"
  FILENAME nvidia-cudnn-LICENSE.txt
  SHA512 2de487fe464a2d2aab03c1310d290039f9e3c7bc2720245c58ab2cdd290f34dc62b09346d7f77e17ea1f6d25d0ad1b325cb96631962550d84e8fa35d4556223a
)
vcpkg_install_copyright(FILE_LIST "${CUDNN_LICENSE_FILE}")
