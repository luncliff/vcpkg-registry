message(STATUS "Using Dependencies from vcpkg...")

# ABSL should be included before protobuf because protobuf may use absl
find_package(absl CONFIG REQUIRED)
list(APPEND onnxruntime_EXTERNAL_LIBRARIES absl::base)

find_package(re2 CONFIG REQUIRED) # re2::re2
list(APPEND onnxruntime_EXTERNAL_LIBRARIES re2::re2)

if (onnxruntime_BUILD_UNIT_TESTS)
  # gtest and gmock
  find_package(GTest CONFIG REQUIRED) # GTest::gtest GTest::gtest_main GTest::gmock GTest::gmock_main
endif()

if (onnxruntime_BUILD_BENCHMARKS)
  find_package(benchmark CONFIG REQUIRED) # benchmark::benchmark benchmark::benchmark_main
endif()

# Flatbuffers
find_package(flatbuffers CONFIG REQUIRED) # flatbuffers::flatbuffers
list(APPEND onnxruntime_EXTERNAL_DEPENDENCIES flatbuffers::flatbuffers)

find_package(Protobuf CONFIG REQUIRED) # protobuf::libprotobuf protobuf::libprotobuf-lite
if (onnxruntime_USE_FULL_PROTOBUF)
  set(PROTOBUF_LIB protobuf::libprotobuf)
else()
  set(PROTOBUF_LIB protobuf::libprotobuf-lite)
endif()
list(APPEND onnxruntime_EXTERNAL_LIBRARIES ${PROTOBUF_LIB})

if(NOT DEFINED Protobuf_PROTOC_EXECUTABLE)
  find_program(Protobuf_PROTOC_EXECUTABLE NAMES protoc REQUIRED)
endif()
get_filename_component(ONNX_CUSTOM_PROTOC_EXECUTABLE "${Protobuf_PROTOC_EXECUTABLE}" ABSOLUTE)
include(external/protobuf_function.cmake)

find_package(date CONFIG REQUIRED)
list(APPEND onnxruntime_EXTERNAL_DEPENDENCIES date::date)

find_package(Boost REQUIRED)
find_path(BOOST_INCLUDEDIR "boost/mp11.hpp" REQUIRED)
add_library(Boost::mp11 ALIAS Boost::headers)
list(APPEND onnxruntime_EXTERNAL_LIBRARIES Boost::mp11)

find_package(nlohmann_json CONFIG REQUIRED)
list(APPEND onnxruntime_EXTERNAL_LIBRARIES nlohmann_json::nlohmann_json)

#TODO: include clog first
if (onnxruntime_ENABLE_CPUINFO)
  find_package(cpuinfo CONFIG REQUIRED)
  list(APPEND onnxruntime_EXTERNAL_LIBRARIES cpuinfo::cpuinfo)
endif()

if (NOT WIN32)
  find_package(nsync CONFIG REQUIRED)
  list(APPEND onnxruntime_EXTERNAL_LIBRARIES nsync::nsync_cpp)
endif()

find_package(Microsoft.GSL CONFIG REQUIRED)
list(APPEND onnxruntime_EXTERNAL_LIBRARIES Microsoft.GSL::GSL)

# ONNX
find_package(ONNX CONFIG REQUIRED)
list(APPEND onnxruntime_EXTERNAL_LIBRARIES onnx onnx_proto)

find_package(Eigen3 CONFIG REQUIRED)
list(APPEND onnxruntime_EXTERNAL_LIBRARIES Eigen3::Eigen)

find_package(wil CONFIG REQUIRED)
list(APPEND onnxruntime_EXTERNAL_LIBRARIES WIL::WIL)

add_library(safeint_interface INTERFACE)
find_path(SAFEINT_INCLUDE_DIRS "SafeInt.hpp" REQUIRED)
target_include_directories(safeint_interface INTERFACE ${SAFEINT_INCLUDE_DIRS})
list(APPEND onnxruntime_EXTERNAL_LIBRARIES safeint_interface)

# XNNPACK EP
if (onnxruntime_USE_XNNPACK)
  if (onnxruntime_DISABLE_CONTRIB_OPS)
    message(FATAL_ERROR "XNNPACK EP requires the internal NHWC contrib ops to be available "
                         "but onnxruntime_DISABLE_CONTRIB_OPS is ON")
  endif()
  find_package(cpuinfo CONFIG REQUIRED)
  find_library(PTHREADPOOL_LIBRARY NAMES pthreadpool REQUIRED)
  find_package(xnnpack CONFIG REQUIRED) # xnnpack
  list(APPEND onnxruntime_EXTERNAL_LIBRARIES cpuinfo::cpuinfo ${PTHREADPOOL_LIBRARY} xnnpack)
endif()

if (onnxruntime_USE_MIMALLOC)
  add_compile_definitions(USE_MIMALLOC)
  find_package(mimalloc CONFIG REQUIRED)
  list(APPEND onnxruntime_EXTERNAL_LIBRARIES mimalloc)
endif()

if(onnxruntime_ENABLE_ATEN)
  message(STATUS "Aten fallback is enabled.")
  find_package(dlpack CONFIG REQUIRED)
  list(APPEND onnxruntime_EXTERNAL_LIBRARIES dlpack::dlpack)
endif()

if(onnxruntime_ENABLE_TRAINING OR (onnxruntime_ENABLE_TRAINING_APIS AND onnxruntime_BUILD_UNIT_TESTS))
  find_package(cxxopts CONFIG REQUIRED)
  list(APPEND onnxruntime_EXTERNAL_LIBRARIES cxxopts::cxxopts)
endif()

if (onnxruntime_USE_CUDA)
  find_package(CUDAToolkit REQUIRED)
  include_directories(${CUDAToolkit_INCLUDE_DIRS})
  list(APPEND onnxruntime_LINK_DIRS ${CUDAToolkit_LIBRARY_DIR})
  set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -diag-suppress 2803")
endif()
