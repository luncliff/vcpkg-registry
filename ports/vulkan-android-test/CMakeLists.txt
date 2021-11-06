cmake_minimum_required(VERSION 3.18)
project(vulkan_for_android VERSION 2021.11.06 LANGUAGES CXX)

find_package(Vulkan REQUIRED)

add_library(test_target SHARED libmain.cpp)

set_target_properties(test_target
PROPERTIES
    CXX_STANDARD 17
)

target_link_libraries(test_target
PRIVATE
    Vulkan::Vulkan
)
