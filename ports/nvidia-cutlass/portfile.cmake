if(VCPKG_TARGET_IS_WINDOWS)
    vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
    vcpkg_buildpath_length_warning(50)
endif()

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO NVIDIA/cutlass
    REF v${VERSION}
    SHA512 b02775b7a364a708388fd7ce1c5526453cfb42f35fd9143aad0b0efd2dc10b66feb1539ad08f0f9089fd241e0bdb2002fdeea2604cfdba7a519aceb4f0df0557
    HEAD_REF main
    PATCHES
        fix-find-cudnn.patch
)

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON_PATH "${PYTHON3}" PATH)
vcpkg_add_to_path(PREPEND "${PYTHON_PATH}")

vcpkg_find_cuda(OUT_CUDA_TOOLKIT_ROOT cuda_toolkit_root)

# In some CMake version, the enable_language(CUDA) may report architecture error
set(CUDA_ARCHS "native")

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        tests   CUTLASS_ENABLE_TESTS
        tests   CUTLASS_ENABLE_GTEST_UNIT_TESTS
        tests   CUTLASS_INSTALL_TESTS
        tests   CUTLASS_TEST_UNIT_ENABLE_WARNINGS
        samples CUTLASS_ENABLE_EXAMPLES
        tools   CUTLASS_ENABLE_TOOLS
        library CUTLASS_ENABLE_LIBRARY # too many .cu files
)

# Simple header-only library. With "library" feature, just release artifacts
set(VCPKG_BUILD_TYPE release)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        "-DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCHS}"
        "-DCMAKE_CUDA_COMPILER=${NVCC}"
        "-DCMAKE_CUDA_FLAGS=-Xcudafe --diag_suppress=20012"
        "-DCUDAToolkit_ROOT=${cuda_toolkit_root}"
        "-DCUTLASS_REVISION:STRING=v${VERSION}"
        "-DPython3_EXECUTABLE:FILEPATH=${PYTHON3}"
        -DCUTLASS_LIBRARY_OPERATIONS:STRING=all
        -DCUTLASS_LIBRARY_KERNELS:STRING=all
        -DCUTLASS_ENABLE_HEADERS_ONLY=ON
        -DCUTLASS_ENABLE_PERFORMANCE=OFF
        -DCUTLASS_ENABLE_CUBLAS=ON
        -DCUTLASS_ENABLE_CUDNN=ON
        -DCUTLASS_ENABLE_PROFILER=OFF
    MAYBE_UNUSED_VARIABLES
        CUTLASS_LIBRARY_OPERATIONS
        CMAKE_CUDA_COMPILER
        CUDAToolkit_ROOT
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/NvidiaCutlass" PACKAGE_NAME "NvidiaCutlass")

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
    "${CURRENT_PACKAGES_DIR}/test"
)
if(NOT("library" IN_LIST FEATURES))
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/lib")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
