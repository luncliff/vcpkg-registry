set(VCPKG_POLICY_EMPTY_PACKAGE enabled)

message(STATUS "hint:")
message(STATUS "  Python3_USE_STATIC_LIBS: ${Python3_USE_STATIC_LIBS}")
message(STATUS "  Python3_VERSION: ${Python3_VERSION}")
message(STATUS "  Python3_EXECUTABLE: ${Python3_EXECUTABLE}")
message(STATUS "  Python3_INTERPRETER_ID: ${Python3_INTERPRETER_ID}")
message(STATUS "  Python3_INCLUDE_DIRS: ${Python3_INCLUDE_DIRS}")
message(STATUS "  Python3_LIBRARIES: ${Python3_LIBRARIES}")
message(STATUS "  Python3_LIBRARY_DIRS: ${Python3_LIBRARY_DIRS}")
message(STATUS)
message(STATUS "variables:")
message(STATUS "  PY3_LIBRARY_ROOT_DIR: ${PY3_LIBRARY_ROOT_DIR}")
message(STATUS "  PY3_USER_SITE_PACKAGE_DIR: ${PY3_USER_SITE_PACKAGE_DIR}")
message(STATUS)

message(STATUS "vcpkg_pip_install_requirement:")
vcpkg_pip_install_requirement(
     FOLDER    ${CURRENT_PORT_DIR}
     FILENAME  requirements.txt
)
message(STATUS)

message(STATUS "vcpkg_pip_install:")
vcpkg_pip_install(PACKAGE "pyyaml")

vcpkg_pip_install(PACKAGE "numpy"
                  INSTALL_OPTIONS --user --quiet)
message(STATUS "  Python3_NumPy_INCLUDE_DIRS: ${Python3_NumPy_INCLUDE_DIRS}")
message(STATUS)

vcpkg_pip_install(PACKAGE "pybind11"
                  INSTALL_OPTIONS --user)
message(STATUS "  pybind11_DIR: ${pybind11_DIR}")
message(STATUS)

get_filename_component(LICENSE_PATH ${CURRENT_PORT_DIR}/../vcpkg-host-python3/LICENSE ABSOLUTE)
file(INSTALL     ${LICENSE_PATH}
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright
)
file(INSTALL     ${CURRENT_PORT_DIR}/vcpkg-port-config.cmake
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT}
)
