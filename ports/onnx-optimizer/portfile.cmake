vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO onnx/optimizer
    REF "v${VERSION}"
    SHA512 552d6fa261c3ce2db2e0938a5b5261676335bce9bd828b46a1e2631f3b362c748ae9a6cfe7d62072fc3774b3f506bc54aa5827b52241e6f48d78a08dea1d9316
    HEAD_REF master
    PATCHES
        fix-cmakelists.patch
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        python  BUILD_ONNX_PYTHON
)

if("python" IN_LIST FEATURES)
    x_vcpkg_get_python_packages(
        PYTHON_VERSION 3
        PACKAGES typing-extensions pyyaml numpy pybind11
        OUT_PYTHON_VAR PYTHON3
    )
    message(STATUS "Using Python3: ${PYTHON3}")

    function(get_python_site_packages PYTHON OUT_PATH)
        execute_process(
            COMMAND "${PYTHON}" -c "import site; print(site.getsitepackages()[0])"
            OUTPUT_VARIABLE output OUTPUT_STRIP_TRAILING_WHITESPACE
        )
        set(${OUT_PATH} "${output}" PARENT_SCOPE)
    endfunction()
    get_python_site_packages("${PYTHON3}" SITE_PACKAGES_DIR)

    get_filename_component(pybind11_DIR "${SITE_PACKAGES_DIR}/pybind11/share/cmake/pybind11" ABSOLUTE)
    message(STATUS "Using pybind11: ${pybind11_DIR}")

    list(APPEND FEATURE_OPTIONS
        "-DPython_EXECUTABLE:FILEPATH=${PYTHON3}"
        "-Dpybind11_DIR:PATH=${pybind11_DIR}"
    )
endif()

string(COMPARE EQUAL "${VCPKG_CRT_LINKAGE}" "static" USE_STATIC_RUNTIME)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DONNX_USE_MSVC_STATIC_RUNTIME=${USE_STATIC_RUNTIME}
        -DONNX_OPT_USE_SYSTEM_PROTOBUF=ON
        -DONNX_TARGET_NAME=ONNX::onnx
        ${FEATURE_OPTIONS}
    MAYBE_UNUSED_VARIABLES
        ONNX_USE_MSVC_STATIC_RUNTIME # use in add_msvc_runtime_flag
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(PACKAGE_NAME ONNXOptimizer CONFIG_PATH lib/cmake/ONNXOptimizer)

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/include/onnxoptimizer/test"
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
