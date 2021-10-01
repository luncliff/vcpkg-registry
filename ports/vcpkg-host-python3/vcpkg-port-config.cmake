cmake_minimum_required(VERSION 3.19)

find_program(Python3_EXECUTABLE NAMES python3 python REQUIRED)
message(STATUS "Using Python3: ${Python3_EXECUTABLE}")

find_package(Python3 REQUIRED
COMPONENTS
    Interpreter Development NumPy
)

include("${CMAKE_CURRENT_LIST_DIR}/vcpkg_pip_install.cmake")
