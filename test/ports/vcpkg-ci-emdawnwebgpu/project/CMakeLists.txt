cmake_minimum_required(VERSION 3.25...3.28)
project(vcpkg_ci_emdawnwebgpu LANGUAGES CXX)

if(NOT DEFINED CMAKE_CXX_STANDARD)
    set(CMAKE_CXX_STANDARD 20)
endif()
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT DEFINED CMAKE_CXX_EXTENSIONS)
    set(CMAKE_CXX_EXTENSIONS OFF)
endif()

find_package(Dawn CONFIG REQUIRED)

# C++20 with #include <webgpu/webgpu_cpp.h>
add_executable(test_header main.cpp)
set_target_properties(test_header PROPERTIES CXX_SCAN_FOR_MODULES OFF)
target_link_libraries(test_header PRIVATE dawn::webgpu_dawn)

# C++20 with import wgpu;
if(TARGET dawn::cpp_module AND CMAKE_GENERATOR MATCHES "Ninja")
    add_executable(test_module main_module.cpp)
    target_link_libraries(test_module PRIVATE dawn::cpp_module)
else()
    message(WARNING "Skip C++ module test: CMake ${CMAKE_VERSION}, ${CMAKE_GENERATOR}")
endif()
