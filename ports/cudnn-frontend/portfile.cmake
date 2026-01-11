vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO NVIDIA/cudnn-frontend
    REF v${VERSION}
    SHA512 712c35584fd243792f2ef35c0aec7dde8f37c7c7709b1fa530bf0516208cc9fb0c2f44e736fb9ebde53de78659b22fdc05db4821e583197fb59cb7ca106e4fdb
    HEAD_REF main
    PATCHES
        fix-thirdparty.patch
)
file(REMOVE_RECURSE "${SOURCE_PATH}/include/cudnn_frontend/thirdparty")

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        python  CUDNN_FRONTEND_BUILD_PYTHON_BINDINGS
)

vcpkg_find_cuda(OUT_CUDA_TOOLKIT_ROOT cuda_toolkit_root)

# header only, INTERFACE library
set(VCPKG_BUILD_TYPE release)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        "-DCMAKE_CUDA_COMPILER:FILEPATH=${NVCC}"
        "-DCUDAToolkit_ROOT=${cuda_toolkit_root}"
        -DCUDNN_FRONTEND_FETCH_PYBINDS_IN_CMAKE=OFF
        -DCUDNN_FRONTEND_BUILD_TESTS=OFF
        -DCUDNN_FRONTEND_BUILD_SAMPLES=OFF
        -DCUDNN_FRONTEND_SKIP_JSON_LIB=OFF
    MAYBE_UNUSED_VARIABLES
        CUDNN_FRONTEND_FETCH_PYBINDS_IN_CMAKE
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/cudnn_frontend PACKAGE_NAME cudnn_frontend)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
    "${CURRENT_PACKAGES_DIR}/lib"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
