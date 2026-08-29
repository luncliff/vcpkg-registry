# https://github.com/vllm-project/vllm/tree/v0.28.0

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO vllm-project/vllm
    REF "v${VERSION}"
    SHA512 a19f02dce272e9621902bf254cd4b555aa9c350316368c458d1f50ae57d624eed42ac8a160ba8a84b03afac60f9146053c1802382310bb2856608e589fa7d554
    HEAD_REF main
)

# see ${SOURCE_PATH}/setup.py
x_vcpkg_get_python_packages(
    PYTHON_VERSION 3
    PACKAGES numpy torch
    OUT_PYTHON_VAR PYTHON3
)
message(STATUS "Using python3: ${PYTHON3}")

vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}"
  OPTIONS
    "-DVLLM_PYTHON_EXECUTABLE:EXECUTABLE=${PYTHON3}"
)
vcpkg_cmake_install()
# vcpkg_cmake_config_fixup(CONFIG_PATH share/cmake/OpenCLICDLoader PACKAGE_NAME OpenCLICDLoader)
vcpkg_copy_pdbs()

file(REMOVE_RECURSE
  "${CURRENT_PACKAGES_DIR}/debug/include"
  "${CURRENT_PACKAGES_DIR}/debug/share"
  "${CURRENT_PACKAGES_DIR}/include"
)
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
  file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/bin" "${CURRENT_PACKAGES_DIR}/bin")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
