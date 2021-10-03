#[===[.md:
# vcpkg-host-python3

The port installs some CMake scripts which helps to install Python3 packages from PIP.
It works with CMake module [FindPython3](https://cmake.org/cmake/help/latest/module/FindPython3.html).

Requires CMake 3.19+

### See Also

* https://cmake.org/cmake/help/latest/module/FindPython3.html
* vcpkg_pip_install.cmake

#]===]
set(VCPKG_POLICY_EMPTY_PACKAGE enabled)
cmake_minimum_required(VERSION 3.19)

# https://cmake.org/cmake/help/latest/module/FindPython3.html#hints
# - Python3_ROOT_DIR
# - Python3_USE_STATIC_LIBS
string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "static" Python3_USE_STATIC_LIBS)
# - Python3_FIND_ABI
# - Python3_FIND_STRATEGY
# - Python3_FIND_REGISTRY
# - Python3_FIND_FRAMEWORK
# - Python3_FIND_VIRTUALENV
# - Python3_FIND_IMPLEMENTATIONS
# - Python3_FIND_UNVERSIONED_NAMES
find_package(Python3 REQUIRED
COMPONENTS
    Interpreter Development
OPTIONAL_COMPONENTS 
    NumPy
)

include(${CURRENT_PORT_DIR}/vcpkg-port-config.cmake)

if(NOT DEFINED PY3_USER_SITE_PACKAGE_DIR)
    # run `python -m site --user-site`
    execute_process(
        COMMAND ${Python3_EXECUTABLE} -m site --user-site
        WORKING_DIRECTORY ${CURRENT_BUILDTREES_DIR}
        OUTPUT_VARIABLE PY3_USER_SITE_PACKAGE_DIR
        ERROR_VARIABLE  ERROR_MESSAGE
        OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_STRIP_TRAILING_WHITESPACE
        ENCODING UTF-8
    )
    if(ERROR_MESSAGE)
        message(FATAL_ERROR "${ERROR_MESSAGE}")
    endif()
    # change path separaters in the variable
    get_filename_component(PY3_USER_SITE_PACKAGE_DIR "${PY3_USER_SITE_PACKAGE_DIR}" ABSOLUTE)
    message(STATUS "Detected: ${PY3_USER_SITE_PACKAGE_DIR}")
endif()

string(TIMESTAMP INSTALL_TIMEPOINT UTC)
file(WRITE ${HINT_FILE}  "# timestamp: ${INSTALL_TIMEPOINT}\n")
file(APPEND ${HINT_FILE} "set(Python3_USE_STATIC_LIBS ${Python3_USE_STATIC_LIBS})\n")

file(APPEND ${HINT_FILE} "# triplet: ${TARGET_TRIPLET}\n")
file(APPEND ${HINT_FILE} "set(Python3_VERSION \"${Python3_VERSION}\")\n")
file(APPEND ${HINT_FILE} "set(Python3_VERSION_MAJOR \"${Python3_VERSION_MAJOR}\")\n")
file(APPEND ${HINT_FILE} "set(Python3_VERSION_MINOR \"${Python3_VERSION_MINOR}\")\n")

file(APPEND ${HINT_FILE} "set(Python3_EXECUTABLE \"${Python3_EXECUTABLE}\")\n")
file(APPEND ${HINT_FILE} "set(Python3_INTERPRETER_ID ${Python3_INTERPRETER_ID})\n")

file(APPEND ${HINT_FILE} "\n")
file(APPEND ${HINT_FILE} "set(Python3_INCLUDE_DIRS \"${Python3_INCLUDE_DIRS}\")\n")
file(APPEND ${HINT_FILE} "set(Python3_LIBRARIES \"${Python3_LIBRARIES}\")\n")
file(APPEND ${HINT_FILE} "set(Python3_LIBRARY_DIRS \"${Python3_LIBRARY_DIRS}\")\n")
if(Python3_NumPy_FOUND)
     file(APPEND ${HINT_FILE} "set(Python3_NumPy_INCLUDE_DIRS \"${Python3_NumPy_INCLUDE_DIRS}\")\n")
endif()

file(APPEND ${HINT_FILE} "\n")
set(PY3_NAME "python${Python3_VERSION_MAJOR}.${Python3_VERSION_MINOR}")
file(APPEND ${HINT_FILE} "set(PY3_NAME \"${PY3_NAME}\")\n")
if(DEFINED PY3_USER_SITE_PACKAGE_DIR)
     file(APPEND ${HINT_FILE} "set(PY3_USER_SITE_PACKAGE_DIR \"${PY3_USER_SITE_PACKAGE_DIR}\")\n")
endif()

file(INSTALL     ${CURRENT_PORT_DIR}/LICENSE
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT} RENAME copyright
)
file(INSTALL     ${CURRENT_PORT_DIR}/vcpkg-port-config.cmake
                 ${HINT_FILE}
                 ${CURRENT_PORT_DIR}/vcpkg_pip_install.cmake
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT}
)
