cmake_minimum_required(VERSION 3.16)
project(OpenCLHeadersVcpkg LANGUAGES C CXX)

# Configure both header projects once, preserving their shared CMake targets.
add_subdirectory("${CL_SOURCE_PATH}" OpenCL-Headers)
add_subdirectory("${CLHPP_SOURCE_PATH}" OpenCL-CLHPP)
