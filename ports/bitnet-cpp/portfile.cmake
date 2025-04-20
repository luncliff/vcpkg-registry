vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO microsoft/BitNet
    REF fd9f1d6e46b476d449417d49851f50a569165835
    SHA512 0
    HEAD_REF main
    # PATCHES
    #     fix-cmake.patch
    #     fix-sources.patch
)

# see ${SOURCE_PATH}/setup.py
# see https://github.com/ggml-org/llama.cpp/tree/master/requirements
x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    PACKAGES 
        numpy~=1.26.4
        sentencepiece~=0.2.0
        transformers>=4.45.1,<5.0.0
        gguf>=0.1.0
        protobuf>=4.21.0,<5.0.0
        torch~=2.2.1
    OUT_PYTHON_VAR PYTHON3
)
message(STATUS "Using python3: ${PYTHON3}")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        "-DPYTHON_EXECUTABLE:FILEPATH=${PYTHON3}"
        -DBITNET_ARM_TL1=OFF
        -DBITNET_X86_TL2=OFF
)
vcpkg_cmake_install()

file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
