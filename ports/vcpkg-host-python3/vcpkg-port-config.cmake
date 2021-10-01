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
elseif(Python3_INTERPRETER_ID STREQUAL Anaconda)
endif()

include("${CMAKE_CURRENT_LIST_DIR}/vcpkg_pip_install.cmake")
