cmake_minimum_required(VERSION 3.19)

if(PORT STREQUAL vcpkg-host-python3)
    # for portfile.cmake
    get_filename_component(HINT_FILE ${CURRENT_BUILDTREES_DIR}/triplet-hint.cmake ABSOLUTE)
else()
    # for consumers
    get_filename_component(HINT_FILE ${CMAKE_CURRENT_LIST_DIR}/triplet-hint.cmake ABSOLUTE)
    message(STATUS "Using hint: ${HINT_FILE}")
    include("${HINT_FILE}")
endif()

# todo: if virtualenv specified, extend CMAKE_PREFIX_PATH ...
if(Python3_INTERPRETER_ID STREQUAL Python)
    # get_filename_component(PY3_LIBRARY_ROOT_DIR "${Python3_INCLUDE_DIRS}/../Library" ABSOLUTE)
    # get_filename_component(PY3_CONFIG_DIR_0 "${PY3_LIBRARY_ROOT_DIR}/cmake" ABSOLUTE)
    # get_filename_component(PY3_CONFIG_DIR_1 "${PY3_LIBRARY_ROOT_DIR}/lib/cmake" ABSOLUTE)
    # get_filename_component(PY3_CONFIG_DIR_2 "${PY3_LIBRARY_ROOT_DIR}/share/cmake" ABSOLUTE)
    # list(APPEND CMAKE_PREFIX_PATH ${PY3_LIBRARY_ROOT_DIR})
else()
    # message(WARNING "Unhandled: ${Python3_INTERPRETER_ID}")
endif()

include("${CMAKE_CURRENT_LIST_DIR}/vcpkg_pip_install.cmake")
