cmake_minimum_required(VERSION 3.18)
project(mediapipe LANGUAGES CXX VERSION 0.8.8)

include(GNUInstallDirs)

option(USE_EGL      "Build with OpenGL ES API"      ON)
option(USE_METAL    "Build with Apple Metal API"    OFF)
option(USE_TFLITE   "Build with TensorFlow Lite"    ON)
option(USE_OPENCV4  "Build with OpenCV 4.x"         OFF)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED true)

find_package(protobuf CONFIG REQUIRED) # protobuf::libprotobuf, Protobuf_PROTOC_EXECUTABLE

find_package(absl CONFIG REQUIRED)
find_package(gflags CONFIG REQUIRED)
find_package(glog CONFIG REQUIRED)
find_package(Eigen3 CONFIG REQUIRED)
find_package(libyuv CONFIG REQUIRED)
if(USE_OPENCV4)
    find_package(OpenCV 4 REQUIRED COMPONENTS imgproc highgui)
endif()

if(USE_TFLITE)
    find_library(TFLITE_LIBPATH NAMES tensorflow-lite REQUIRED)
endif()
if(WIN32 OR USE_EGL)
    find_library(PTHREAD_LIBPATH NAMES pthreadVC3 REQUIRED)
    find_package(unofficial-angle CONFIG REQUIRED) # unofficial::angle::libEGL unofficial::angle::libGLESv2
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

list(APPEND framework_stream_handler_proto_files
    mediapipe/framework/stream_handler/default_input_stream_handler.proto
    mediapipe/framework/stream_handler/fixed_size_input_stream_handler.proto
    mediapipe/framework/stream_handler/sync_set_input_stream_handler.proto
    mediapipe/framework/stream_handler/timestamp_align_input_stream_handler.proto
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

list(APPEND calculator_proto_files
    # mediapipe/calculator/internal/callback_packet_calculator.cc
    mediapipe/calculators/internal/callback_packet_calculator.proto
    # mediapipe/calculator/tflite
    mediapipe/calculators/tflite/ssd_anchors_calculator.proto
    mediapipe/calculators/tflite/tflite_converter_calculator.proto
    mediapipe/calculators/tflite/tflite_custom_op_resolver_calculator.proto
    mediapipe/calculators/tflite/tflite_inference_calculator.proto
    mediapipe/calculators/tflite/tflite_tensors_to_classification_calculator.proto
    mediapipe/calculators/tflite/tflite_tensors_to_detections_calculator.proto
    mediapipe/calculators/tflite/tflite_tensors_to_landmarks_calculator.proto
    mediapipe/calculators/tflite/tflite_tensors_to_segmentation_calculator.proto
)

list(APPEND util_proto_files
    mediapipe/util/audio_decoder.proto
    mediapipe/util/color.proto
    mediapipe/util/render_data.proto
)

foreach(proto_file  ${framework_proto_files}
                    ${framework_deps_proto_files}
                    ${framework_stream_handler_proto_files}
                    ${framework_formats_proto_files}
                    ${framework_formats_annotation_proto_files}
                    ${framework_formats_motion_proto_files}
                    ${framework_formats_object_detection_proto_files}
                    ${framework_tool_proto_files}
                    ${gpu_proto_files}
                    ${calculator_proto_files}
                    ${util_proto_files}
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

add_library(mediapipe
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
    # mediapipe/framework/stream_handler
    ${default_input_stream_handler_SRCS}
    ${fixed_size_input_stream_handler_SRCS}
    ${sync_set_input_stream_handler_SRCS}
    ${timestamp_align_input_stream_handler_SRCS}
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
    # # mediapipe/framework/tool
    ${calculator_graph_template_SRCS}
    ${field_data_SRCS}
    ${node_chain_subgraph_SRCS}
    ${packet_generator_wrapper_calculator_SRCS}
    ${source_SRCS}
    ${switch_container_SRCS}
    # mediapipe/calculators/internal
    ${callback_packet_calculator_SRCS}
    # mediapipe/util
    ${audio_decoder_SRCS}
    ${color_SRCS}
    ${render_data_SRCS}
)

target_sources(mediapipe
PRIVATE
    # mediapipe/framework
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
    # mediapipe/framework/test_service.h
    # mediapipe/framework/test_service.cc
    mediapipe/framework/thread_pool_executor.h
    mediapipe/framework/thread_pool_executor.cc
    mediapipe/framework/throttler.h
    mediapipe/framework/timestamp.h
    mediapipe/framework/timestamp.cc
    mediapipe/framework/type_map.h
    mediapipe/framework/validated_graph_config.h
    mediapipe/framework/validated_graph_config.cc
    # mediapipe/framework/api2
    mediapipe/framework/api2/builder.h
    mediapipe/framework/api2/const_str.h
    mediapipe/framework/api2/contract.h
    mediapipe/framework/api2/node.h
    mediapipe/framework/api2/node.cc
    mediapipe/framework/api2/packet.h
    mediapipe/framework/api2/packet.cc
    mediapipe/framework/api2/port.h
    mediapipe/framework/api2/tag.h
    mediapipe/framework/api2/tuple.h
    mediapipe/framework/api2/type_list.h
    # mediapipe/framework/deps
    mediapipe/framework/deps/aligned_malloc_and_free.h
    mediapipe/framework/deps/canonical_errors.h
    mediapipe/framework/deps/cleanup.h
    mediapipe/framework/deps/clock.h
    mediapipe/framework/deps/clock.cc
    mediapipe/framework/deps/file_helpers.h
    mediapipe/framework/deps/file_helpers.cc
    mediapipe/framework/deps/file_path.h
    mediapipe/framework/deps/file_path.cc
    # mediapipe/framework/deps/image_resizer.h
    mediapipe/framework/deps/map_util.h
    mediapipe/framework/deps/mathutil.h
    mediapipe/framework/deps/message_matchers.h
    mediapipe/framework/deps/monotonic_clock.h
    mediapipe/framework/deps/monotonic_clock.cc
    mediapipe/framework/deps/no_destructor.h
    mediapipe/framework/deps/numbers.h
    mediapipe/framework/deps/point2.h
    mediapipe/framework/deps/random_base.h
    mediapipe/framework/deps/re2.h
    mediapipe/framework/deps/rectangle.h
    mediapipe/framework/deps/registration_token.h
    mediapipe/framework/deps/registration_token.cc
    mediapipe/framework/deps/registration.h
    mediapipe/framework/deps/registration.cc
    mediapipe/framework/deps/ret_check.h
    mediapipe/framework/deps/ret_check.cc
    mediapipe/framework/deps/safe_int.h
    mediapipe/framework/deps/singleton.h
    mediapipe/framework/deps/source_location.h
    mediapipe/framework/deps/status_builder.h
    mediapipe/framework/deps/status_builder.cc
    mediapipe/framework/deps/status_macros.h
    mediapipe/framework/deps/status_matchers.h
    mediapipe/framework/deps/status.h
    mediapipe/framework/deps/status.cc
    mediapipe/framework/deps/strong_int.h
    mediapipe/framework/deps/thread_options.h
    # mediapipe/framework/deps/threadpool_pthread_impl.cc
    mediapipe/framework/deps/threadpool_std_thread_impl.cc
    mediapipe/framework/deps/threadpool.h
    mediapipe/framework/deps/topologicalsorter.cc
    mediapipe/framework/deps/topologicalsorter.h
    mediapipe/framework/deps/vector.h
    # mediapipe/framework/formats
    mediapipe/framework/formats/affine_transform.cc
    mediapipe/framework/formats/affine_transform.h
    mediapipe/framework/formats/deleting_file.cc
    mediapipe/framework/formats/deleting_file.h
    mediapipe/framework/formats/detection.proto
    mediapipe/framework/formats/image_frame_opencv.cc
    mediapipe/framework/formats/image_frame_opencv.h
    mediapipe/framework/formats/image_frame_pool.cc
    mediapipe/framework/formats/image_frame_pool.h
    mediapipe/framework/formats/image_frame.cc
    mediapipe/framework/formats/image_frame.h
    mediapipe/framework/formats/image_multi_pool.cc
    mediapipe/framework/formats/image_multi_pool.h
    mediapipe/framework/formats/image_opencv.cc
    mediapipe/framework/formats/image_opencv.h
    mediapipe/framework/formats/image.cc
    mediapipe/framework/formats/image.h
    mediapipe/framework/formats/location.cc
    mediapipe/framework/formats/location.h
    mediapipe/framework/formats/matrix.cc
    mediapipe/framework/formats/matrix.h
    mediapipe/framework/formats/tensor.cc
    mediapipe/framework/formats/tensor.h
    mediapipe/framework/formats/video_stream_header.h
    mediapipe/framework/formats/yuv_image.h
    # mediapipe/framework/formats/motion/optical_flow_field.cc
    # mediapipe/framework/formats/motion/optical_flow_field.h
    mediapipe/framework/stream_handler/barrier_input_stream_handler.cc
    mediapipe/framework/stream_handler/default_input_stream_handler.cc
    mediapipe/framework/stream_handler/default_input_stream_handler.h
    mediapipe/framework/stream_handler/early_close_input_stream_handler.cc
    mediapipe/framework/stream_handler/fixed_size_input_stream_handler.cc
    mediapipe/framework/stream_handler/immediate_input_stream_handler.cc
    mediapipe/framework/stream_handler/in_order_output_stream_handler.cc
    mediapipe/framework/stream_handler/in_order_output_stream_handler.h
    mediapipe/framework/stream_handler/mux_input_stream_handler.cc
    mediapipe/framework/stream_handler/sync_set_input_stream_handler.cc
    mediapipe/framework/stream_handler/timestamp_align_input_stream_handler.cc
    # mediapipe/util
    # mediapipe/util/resource_util_android.cc
    # mediapipe/util/resource_util_apple.cc
    # mediapipe/util/resource_util_custom.h
    # mediapipe/util/resource_util_default.cc
    # mediapipe/util/resource_util_internal.h
    mediapipe/util/annotation_renderer.cc
    mediapipe/util/annotation_renderer.h
    # mediapipe/util/audio_decoder.cc
    # mediapipe/util/audio_decoder.h
    mediapipe/util/cpu_util.cc
    mediapipe/util/cpu_util.h
    mediapipe/util/header_util.cc
    mediapipe/util/header_util.h
    mediapipe/util/image_frame_util.cc
    mediapipe/util/image_frame_util.h
    mediapipe/util/resource_cache.h
    mediapipe/util/resource_util.cc
    mediapipe/util/resource_util.h
    # mediapipe/util/tensor_to_detection.cc # requires TensorFlow, not TF Lite
    # mediapipe/util/tensor_to_detection.h
    mediapipe/util/time_series_util.cc
    mediapipe/util/time_series_util.h
    # mediapipe/framework/tool
    mediapipe/framework/tool/tag_map.cc
    mediapipe/framework/tool/tag_map.h
)

target_sources(mediapipe
PRIVATE
    # mediapipe/gpu
    ${copy_calculator_SRCS}
    ${gl_context_options_SRCS}
    ${gl_scaler_calculator_SRCS}
    ${gl_surface_sink_calculator_SRCS}
    ${gpu_origin_SRCS}
    ${scale_mode_SRCS}
    mediapipe/gpu/gpu_buffer_format.cc
    mediapipe/gpu/gpu_buffer_format.h
    mediapipe/gpu/gpu_buffer_multi_pool.cc
    mediapipe/gpu/gpu_buffer_multi_pool.h
    mediapipe/gpu/gpu_buffer_to_image_frame_calculator.cc
    mediapipe/gpu/gpu_buffer.cc
    mediapipe/gpu/gpu_buffer.h
    mediapipe/gpu/gpu_service.cc
    mediapipe/gpu/gpu_service.h
    mediapipe/gpu/gpu_shared_data_internal.cc
    mediapipe/gpu/gpu_shared_data_internal.h
    mediapipe/gpu/graph_support.h
    mediapipe/gpu/image_frame_to_gpu_buffer_calculator.cc
    mediapipe/gpu/shader_util.cc
    mediapipe/gpu/shader_util.h
)

if(USE_EGL)
    target_sources(mediapipe
    PRIVATE
        mediapipe/gpu/egl_surface_holder.h
        mediapipe/gpu/gl_base.h
        mediapipe/gpu/gl_calculator_helper_impl_common.cc
        mediapipe/gpu/gl_calculator_helper_impl.h
        mediapipe/gpu/gl_calculator_helper.cc
        mediapipe/gpu/gl_calculator_helper.h
        mediapipe/gpu/gl_context_internal.h
        mediapipe/gpu/gl_context_egl.cc
        # mediapipe/gpu/gl_context_eagl.cc
        # mediapipe/gpu/gl_context_nsgl.cc
        # mediapipe/gpu/gl_context_webgl.cc
        mediapipe/gpu/gl_context.cc
        mediapipe/gpu/gl_context.h
        mediapipe/gpu/gl_quad_renderer.cc
        mediapipe/gpu/gl_quad_renderer.h
        mediapipe/gpu/gl_scaler_calculator.cc
        mediapipe/gpu/gl_simple_calculator.cc
        mediapipe/gpu/gl_simple_calculator.h
        mediapipe/gpu/gl_simple_shaders.cc
        mediapipe/gpu/gl_simple_shaders.h
        mediapipe/gpu/gl_surface_sink_calculator.cc
        mediapipe/gpu/gl_texture_buffer_pool.cc
        mediapipe/gpu/gl_texture_buffer_pool.h
        mediapipe/gpu/gl_texture_buffer.cc
        mediapipe/gpu/gl_texture_buffer.h
        mediapipe/gpu/gl_thread_collector.h
    )
elseif(USE_METAL)
    # see mediapipe/gpu/metal.bzl
    target_sources(mediapipe
    PRIVATE
        mediapipe/gpu/metal_shader_base.h
        mediapipe/gpu/MPPGraphGPUData.h
        mediapipe/gpu/MPPGraphGPUData.mm
        mediapipe/gpu/MPPMetalHelper.h
        mediapipe/gpu/MPPMetalHelper.mm
        mediapipe/gpu/MPPMetalUtil.h
        mediapipe/gpu/MPPMetalUtil.mm
        mediapipe/gpu/pixel_buffer_pool_util.h
        mediapipe/gpu/pixel_buffer_pool_util.mm
    )
endif()

if(USE_TFLITE)
    # see mediapipe/gpu/metal.bzl
    target_sources(mediapipe
    PRIVATE
        # mediapipe/calculator/tflite
        ${ssd_anchors_calculator_SRCS}
        ${tflite_converter_calculator_SRCS}
        ${tflite_custom_op_resolver_calculator_SRCS}
        ${tflite_inference_calculator_SRCS}
        ${tflite_tensors_to_classification_calculator_SRCS}
        ${tflite_tensors_to_detections_calculator_SRCS}
        ${tflite_tensors_to_landmarks_calculator_SRCS}
        ${tflite_tensors_to_segmentation_calculator_SRCS}
        mediapipe/calculators/tflite/ssd_anchors_calculator.cc
        mediapipe/calculators/tflite/tflite_converter_calculator.cc
        mediapipe/calculators/tflite/tflite_custom_op_resolver_calculator.cc
        mediapipe/calculators/tflite/tflite_inference_calculator.cc
        mediapipe/calculators/tflite/tflite_model_calculator.cc
        mediapipe/calculators/tflite/tflite_tensors_to_classification_calculator.cc
        mediapipe/calculators/tflite/tflite_tensors_to_detections_calculator.cc
        mediapipe/calculators/tflite/tflite_tensors_to_floats_calculator.cc
        mediapipe/calculators/tflite/tflite_tensors_to_landmarks_calculator.cc
        mediapipe/calculators/tflite/tflite_tensors_to_segmentation_calculator.cc
    )
endif()

target_include_directories(mediapipe
PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}
)

target_compile_definitions(mediapipe
PRIVATE
    NOMINMAX _USE_MATH_DEFINES
    _SILENCE_CXX17_OLD_ALLOCATOR_MEMBERS_DEPRECATION_WARNING
    _SILENCE_CXX17_RESULT_OF_DEPRECATION_WARNING
    PROTOBUF_USE_DLLS
)

target_link_libraries(mediapipe
PRIVATE
    absl::base absl::debugging absl::flags
    glog::glog gflags::gflags protobuf::libprotobuf Eigen3::Eigen
    yuv
)

if(USE_OPENCV4)
    target_link_libraries(mediapipe
    PRIVATE
        opencv_highgui opencv_imgproc
    )
endif()

if(WIN32)
    target_include_directories(mediapipe
    PRIVATE
        ${EGL_INCLUDE_DIR} ${GLES_INCLUDE_DIR}
    )

    target_compile_definitions(mediapipe
    PRIVATE
        NOMINMAX
        MEDIAPIPE_DISABLE_GL_COMPUTE # todo: remove this
    )

    target_compile_options(mediapipe
    PRIVATE
        /wd4251 # mute protobuf DLL interface related warnings
        /wd4267 # possible lose of data
        /wd4244
        /wd4005 # macro redefinition
    )

    target_link_libraries(mediapipe
    PRIVATE
        ${PTHREAD_LIBPATH} ${TFLITE_LIBPATH}
        unofficial::angle::libEGL unofficial::angle::libGLESv2
    )

endif()

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

install(FILES   # mediapipe/framework/api2/README.md
                mediapipe/framework/api2/builder.h
                mediapipe/framework/api2/const_str.h
                mediapipe/framework/api2/contract.h
                mediapipe/framework/api2/node.h
                mediapipe/framework/api2/packet.h
                mediapipe/framework/api2/port.h
                mediapipe/framework/api2/tag.h
                mediapipe/framework/api2/tuple.h
                mediapipe/framework/api2/type_list.h
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/mediapipe/framework/api2
)

install(TARGETS mediapipe
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# mediapipe/framework/tool
if(NOT BUILD_TOOLS)
    return()
endif()
# mediapipe/framework/tool/container_util.cc
# mediapipe/framework/tool/container_util.h
# mediapipe/framework/tool/encode_as_c_string.cc
# mediapipe/framework/tool/executor_util.cc
# mediapipe/framework/tool/executor_util.h
# mediapipe/framework/tool/fill_packet_set.cc
# mediapipe/framework/tool/fill_packet_set.h
# mediapipe/framework/tool/mediapipe_graph.bzl
# mediapipe/framework/tool/message_type_util.cc
# mediapipe/framework/tool/name_util.cc
# mediapipe/framework/tool/name_util.h
# mediapipe/framework/tool/options_field_util.cc
# mediapipe/framework/tool/options_field_util.h
# # mediapipe/framework/tool/options_lib_template.cc
# mediapipe/framework/tool/options_map.h
# mediapipe/framework/tool/options_registry.cc
# mediapipe/framework/tool/options_registry.h
# mediapipe/framework/tool/options_syntax_util.cc
# mediapipe/framework/tool/options_syntax_util.h
# mediapipe/framework/tool/options_util.cc
# mediapipe/framework/tool/options_util.h
# mediapipe/framework/tool/packet_generator_wrapper_calculator.cc
# mediapipe/framework/tool/proto_util_lite.cc
# mediapipe/framework/tool/proto_util_lite.h
# # mediapipe/framework/tool/simple_subgraph_template.cc      
# mediapipe/framework/tool/simulation_clock_executor.cc     
# mediapipe/framework/tool/simulation_clock_executor.h      
# mediapipe/framework/tool/simulation_clock.cc
# mediapipe/framework/tool/simulation_clock.h
# mediapipe/framework/tool/sink.cc
# mediapipe/framework/tool/sink.h
# mediapipe/framework/tool/source.cc
# mediapipe/framework/tool/status_util.cc
# mediapipe/framework/tool/status_util.h
# mediapipe/framework/tool/subgraph_expansion.cc
# mediapipe/framework/tool/subgraph_expansion.h
# mediapipe/framework/tool/switch_container.cc
# mediapipe/framework/tool/switch_demux_calculator.cc       
# mediapipe/framework/tool/switch_mux_calculator.cc
# mediapipe/framework/tool/tag_map_helper.cc
# mediapipe/framework/tool/tag_map_helper.h
# mediapipe/framework/tool/tag_map.cc
# mediapipe/framework/tool/tag_map.h
# mediapipe/framework/tool/template_expander.cc
# mediapipe/framework/tool/template_expander.h
# mediapipe/framework/tool/template_parser.cc
# mediapipe/framework/tool/template_parser.h
# mediapipe/framework/tool/text_to_binary_graph.cc
# mediapipe/framework/tool/type_util.h
# mediapipe/framework/tool/validate_name.cc
# mediapipe/framework/tool/validate_name.h
# mediapipe/framework/tool/validate_type.cc
# mediapipe/framework/tool/validate_type.h
# mediapipe/framework/tool/validate.cc
# mediapipe/framework/tool/validate.h
