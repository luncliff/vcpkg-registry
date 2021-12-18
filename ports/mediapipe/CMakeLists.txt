cmake_minimum_required(VERSION 3.18)
project(mediapipe LANGUAGES CXX VERSION 0.8.8)

include(GNUInstallDirs)

option(USE_OPENCV4 "Build with OpenCV 4.x" OFF)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED true)

find_package(protobuf CONFIG REQUIRED) # protobuf::libprotobuf, Protobuf_PROTOC_EXECUTABLE

find_package(absl CONFIG REQUIRED)
find_package(gflags CONFIG REQUIRED)
find_package(glog CONFIG REQUIRED)
if(USE_OPENCV4)
    find_package(OpenCV 4 REQUIRED COMPONENTS imgproc highgui)
endif()

find_library(TFLITE_LIBPATH NAMES tensorflow-lite REQUIRED)
if(WIN32)
    find_path(EGL_INCLUDE_DIR EGL/egl.h REQUIRED)
    find_path(GLES_INCLUDE_DIR GLES3/gl32.h REQUIRED)
endif()

# for protobuf_generate
get_filename_component(codegen_dir ${CMAKE_CURRENT_BINARY_DIR}/mediapipe/framework ABSOLUTE)
file(MAKE_DIRECTORY ${codegen_dir})

list(APPEND framework_proto_files
    mediapipe/framework/calculator.proto
    mediapipe/framework/calculator_options.proto
    mediapipe/framework/calculator_profile.proto
    mediapipe/framework/mediapipe_options.proto
    mediapipe/framework/packet_factory.proto
    mediapipe/framework/packet_generator.proto
    mediapipe/framework/status_handler.proto
    mediapipe/framework/stream_handler.proto
    mediapipe/framework/thread_pool_executor.proto
)

list(APPEND framework_deps_proto_files
    mediapipe/framework/deps/proto_descriptor.proto
)

list(APPEND framework_formats_proto_files
    mediapipe/framework/formats/affine_transform_data.proto
    mediapipe/framework/formats/classification.proto
    mediapipe/framework/formats/detection.proto
    mediapipe/framework/formats/image_file_properties.proto
    mediapipe/framework/formats/image_format.proto
    mediapipe/framework/formats/landmark.proto
    mediapipe/framework/formats/location_data.proto
    mediapipe/framework/formats/matrix_data.proto
    mediapipe/framework/formats/rect.proto
    mediapipe/framework/formats/time_series_header.proto
)

list(APPEND framework_formats_annotation_proto_files
    mediapipe/framework/formats/annotation/locus.proto
    mediapipe/framework/formats/annotation/rasterization.proto
)

list(APPEND framework_formats_motion_proto_files
    mediapipe/framework/formats/motion/optical_flow_field_data.proto
)

list(APPEND framework_formats_object_detection_proto_files
    mediapipe/framework/formats/object_detection/anchor.proto
)

list(APPEND framework_tool_proto_files
    mediapipe/framework/tool/calculator_graph_template.proto
    mediapipe/framework/tool/field_data.proto
    mediapipe/framework/tool/node_chain_subgraph.proto
    mediapipe/framework/tool/packet_generator_wrapper_calculator.proto
    mediapipe/framework/tool/source.proto
    mediapipe/framework/tool/switch_container.proto
)

list(APPEND gpu_proto_files
    mediapipe/gpu/copy_calculator.proto
    mediapipe/gpu/gl_context_options.proto
    mediapipe/gpu/gl_scaler_calculator.proto
    mediapipe/gpu/gl_surface_sink_calculator.proto
    mediapipe/gpu/gpu_origin.proto
    mediapipe/gpu/scale_mode.proto
)

foreach(proto_file  ${framework_proto_files}
                    ${framework_deps_proto_files}
                    ${framework_formats_proto_files}
                    ${framework_formats_annotation_proto_files}
                    ${framework_formats_motion_proto_files}
                    ${framework_formats_object_detection_proto_files}
                    ${framework_tool_proto_files}
                    ${gpu_proto_files}
        )
    get_filename_component(protocol_name ${proto_file} NAME_WLE)
    protobuf_generate(${_append_arg}
        LANGUAGE cpp
        IMPORT_DIRS ${CMAKE_CURRENT_SOURCE_DIR}
        PROTOC_OUT_DIR ${CMAKE_CURRENT_BINARY_DIR}
        PROTOS ${proto_file}
        OUT_VAR ${protocol_name}_SRCS
    )
endforeach()

add_library(mediapipe)

target_sources(mediapipe
PRIVATE
    # mediapipe/framework
    ${calculator_options_SRCS}
    ${calculator_profile_SRCS}
    ${calculator_SRCS}
    ${mediapipe_options_SRCS}
    ${packet_factory_SRCS}
    ${packet_generator_SRCS}
    ${status_handler_SRCS}
    ${stream_handler_SRCS}
    ${thread_pool_executor_SRCS}
    # mediapipe/framework/deps
    ${proto_descriptor_SRCS}
    # mediapipe/framework/formats
    ${affine_transform_data_SRCS}
    ${classification_SRCS}
    ${detection_SRCS}
    ${image_file_properties_SRCS}
    ${image_format_SRCS}
    ${landmark_SRCS}
    ${location_data_SRCS}
    ${matrix_data_SRCS}
    ${rect_SRCS}
    ${time_series_header_SRCS}
    # mediapipe/framework/formats/annotation
    ${locus_SRCS}
    ${rasterization_SRCS}
    # mediapipe/framework/formats/motion
    ${optical_flow_field_data_SRCS}
    # mediapipe/framework/formats/object_detection
    ${anchor_SRCS}
    # mediapipe/framework/tool
    ${calculator_graph_template_SRCS}
    ${field_data_SRCS}
    ${node_chain_subgraph_SRCS}
    ${packet_generator_wrapper_calculator_SRCS}
    ${source_SRCS}
    ${switch_container_SRCS}
    # mediapipe/gpu
    ${copy_calculator_SRCS}
    ${gl_context_options_SRCS}
    ${gl_scaler_calculator_SRCS}
    ${gl_surface_sink_calculator_SRCS}
    ${gpu_origin_SRCS}
    ${scale_mode_SRCS}
)

target_sources(mediapipe
PRIVATE
    mediapipe/framework/basic_types_registration.cc
    mediapipe/framework/calculator_base.h
    mediapipe/framework/calculator_base.cc
    mediapipe/framework/calculator_context_manager.h
    mediapipe/framework/calculator_context_manager.cc
    mediapipe/framework/calculator_context.h
    mediapipe/framework/calculator_context.cc
    mediapipe/framework/calculator_contract.h
    mediapipe/framework/calculator_contract.cc
    mediapipe/framework/calculator_framework.h
    mediapipe/framework/calculator_graph.h
    mediapipe/framework/calculator_graph.cc
    mediapipe/framework/calculator_node.h
    mediapipe/framework/calculator_node.cc
    mediapipe/framework/calculator_registry.h
    mediapipe/framework/calculator_runner.h
    mediapipe/framework/calculator_runner.cc
    mediapipe/framework/calculator_state.h
    mediapipe/framework/calculator_state.cc
    mediapipe/framework/camera_intrinsics.h
    mediapipe/framework/collection_item_id.h
    mediapipe/framework/collection_item_id.cc
    mediapipe/framework/collection.h
    mediapipe/framework/counter_factory.h
    mediapipe/framework/counter_factory.cc
    mediapipe/framework/counter.h
    mediapipe/framework/delegating_executor.h
    mediapipe/framework/delegating_executor.cc
    mediapipe/framework/demangle.h
    mediapipe/framework/executor.h
    mediapipe/framework/executor.cc
    mediapipe/framework/graph_output_stream.h
    mediapipe/framework/graph_output_stream.cc
    mediapipe/framework/graph_service_manager.h
    mediapipe/framework/graph_service_manager.cc
    mediapipe/framework/graph_service.h
    mediapipe/framework/graph_validation.h
    mediapipe/framework/input_side_packet_handler.h
    mediapipe/framework/input_side_packet_handler.cc
    mediapipe/framework/input_stream_handler.h
    mediapipe/framework/input_stream_handler.cc
    mediapipe/framework/input_stream_manager.h
    mediapipe/framework/input_stream_manager.cc
    mediapipe/framework/input_stream_shard.h
    mediapipe/framework/input_stream_shard.cc
    mediapipe/framework/input_stream.h
    mediapipe/framework/legacy_calculator_support.h
    mediapipe/framework/legacy_calculator_support.cc
    mediapipe/framework/lifetime_tracker.h
    mediapipe/framework/mediapipe_profiling.h
    mediapipe/framework/output_side_packet_impl.h
    mediapipe/framework/output_side_packet_impl.cc
    mediapipe/framework/output_side_packet.h
    mediapipe/framework/output_stream_handler.h
    mediapipe/framework/output_stream_handler.cc
    mediapipe/framework/output_stream_manager.h
    mediapipe/framework/output_stream_manager.cc
    mediapipe/framework/output_stream_poller.h
    mediapipe/framework/output_stream_shard.h
    mediapipe/framework/output_stream_shard.cc
    mediapipe/framework/output_stream.h
    mediapipe/framework/packet_generator_graph.h
    mediapipe/framework/packet_generator_graph.cc
    mediapipe/framework/packet_generator.h
    mediapipe/framework/packet_type.h
    mediapipe/framework/packet_type.cc
    mediapipe/framework/packet.h
    mediapipe/framework/packet.cc
    mediapipe/framework/platform_specific_profiling.h
    mediapipe/framework/port.h
    mediapipe/framework/scheduler_queue.h
    mediapipe/framework/scheduler_queue.cc
    mediapipe/framework/scheduler_shared.h
    mediapipe/framework/scheduler.h
    mediapipe/framework/scheduler.cc
    mediapipe/framework/subgraph.h
    mediapipe/framework/subgraph.cc
    mediapipe/framework/test_service.h
    mediapipe/framework/test_service.cc
    mediapipe/framework/thread_pool_executor.h
    mediapipe/framework/thread_pool_executor.cc
    mediapipe/framework/throttler.h
    mediapipe/framework/timestamp.h
    mediapipe/framework/timestamp.cc
    mediapipe/framework/type_map.h
    mediapipe/framework/validated_graph_config.h
    mediapipe/framework/validated_graph_config.cc
)

target_include_directories(mediapipe
PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}
)
if(WIN32)
    target_include_directories(mediapipe PRIVATE ${EGL_INCLUDE_DIR} ${GLES_INCLUDE_DIR})
endif()

target_compile_definitions(mediapipe
PRIVATE
    NOMINMAX
    _SILENCE_CXX17_OLD_ALLOCATOR_MEMBERS_DEPRECATION_WARNING
    _SILENCE_CXX17_RESULT_OF_DEPRECATION_WARNING
)

target_link_libraries(mediapipe
PRIVATE
    absl::base glog::glog gflags::gflags protobuf::libprotobuf
    ${TFLITE_LIBPATH}
)

install(FILES ${framework_proto_files}
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/mediapipe/framework
)
install(FILES ${framework_deps_proto_files}
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/mediapipe/framework/deps
)
install(FILES ${framework_formats_proto_files}
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/mediapipe/framework/formats
)
install(FILES ${framework_formats_annotation_proto_files}
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/mediapipe/framework/formats/annotation
)
install(FILES ${framework_formats_motion_proto_files}
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/mediapipe/framework/formats/motion
)
install(FILES ${framework_formats_object_detection_proto_files}
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/mediapipe/framework/formats/object_detection
)
install(FILES ${framework_tool_proto_files}
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/mediapipe/framework/tools
)
install(FILES ${gpu_proto_files}
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/mediapipe/gpu
)

install(DIRECTORY mediapipe/models
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/mediapipe
)

install(TARGETS mediapipe
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
