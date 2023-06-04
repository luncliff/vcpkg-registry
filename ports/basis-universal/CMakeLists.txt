cmake_minimum_required(VERSION 3.19)
project(basis-universal LANGUAGES CXX)
include(GNUInstallDirs)

option(SAN "sanitize" FALSE)

# For MSVC builds default to SSE enabled, and determine if it's a 64-bit (-A x64) vs. 32-bit (-A Win32) build.
if (MSVC)
	option(SSE "SSE 4.1 support" TRUE)
	if ( CMAKE_SYSTEM_PROCESSOR MATCHES 64 )
		set(BUILD_X64 1)
	else()
		set(BUILD_X64 0)
	endif()
else()
	option(SSE "SSE 4.1 support" FALSE)
	option(BUILD_X64 "build 64-bit" TRUE)
endif()

option(ZSTD "ZSTD support for KTX2 transcoding/encoding" TRUE)
option(OPENCL "OpenCL support in encoder" FALSE)

message(STATUS "Initial BUILD_X64=${BUILD_X64}")
message(STATUS "Initial CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
message(STATUS "Initial SSE=${SSE}")
message(STATUS "Initial ZSTD=${ZSTD}")
message(STATUS "Initial OPENCL=${OPENCL}")
message(STATUS "Initial SAN=${SAN}")

if (NOT MSVC)
	# With MSVC builds we use the Khronos lib/include files in the project's "OpenCL" directory, to completely avoid requiring fiddly to install vendor SDK's.
	# Otherwise we use the system's (if any).
	find_package( OpenCL )
	message(STATUS "OpenCL found: ${OPENCL_FOUND}")
	if(OPENCL_FOUND)
		message(STATUS "OpenCL includes: ${OpenCL_INCLUDE_DIRS}")
		message(STATUS "OpenCL libraries: ${OpenCL_LIBRARIES}")
		include_directories(${OpenCL_INCLUDE_DIRS})
		link_libraries(${OpenCL_LIBRARIES})
		add_compile_definitions(BASISU_SUPPORT_OPENCL=1)
	endif()
endif()

if (BUILD_X64)
	message(STATUS "Building 64-bit")
else()
	message(STATUS "Building 32-bit")
endif()

if (SSE)
	message(STATUS "SSE enabled")
	add_compile_definitions(BASISU_SUPPORT_SSE=1)
else()
	message(STATUS "SSE disabled")
	add_compile_definitions(BASISU_SUPPORT_SSE=0)
endif()

if (ZSTD)
	message(STATUS "Zstandard enabled")
	find_path(ZSTD_INCLUDE_DIR NAMES "zstd.h" REQUIRED)
	find_library(ZSTD_LIBRARY NAMES zstd REQUIRED)
	include_directories(${ZSTD_INCLUDE_DIR})
	link_libraries(${ZSTD_LIBRARY})
	add_compile_definitions(BASISD_SUPPORT_KTX2_ZSTD=1)
else()
	message(STATUS "Zstandard disabled")
	add_compile_definitions(BASISD_SUPPORT_KTX2_ZSTD=0)
endif()

set(CMAKE_CXX_STANDARD 14)
if (NOT MSVC)
	list(APPEND GCC_COMPILE_FLAGS -fvisibility=hidden -fPIC -fno-strict-aliasing -D_LARGEFILE64_SOURCE=1 -D_FILE_OFFSET_BITS=64 -Wall -Wextra -Wno-unused-local-typedefs -Wno-unused-value -Wno-unused-parameter -Wno-unused-variable)
	if (NOT BUILD_X64)
		list(APPEND GCC_COMPILE_FLAGS -m32)
	endif()

	if (EMSCRIPTEN)
		set(CMAKE_C_FLAGS	"${CMAKE_C_FLAGS} -s ALLOW_MEMORY_GROWTH=1")
		set(CMAKE_CXX_FLAGS	"${CMAKE_CXX_FLAGS} -s ALLOW_MEMORY_GROWTH=1")
	elseif (BUILD_SHARED_LIBS)
		if (SSE)
			add_compile_options(-msse4.1)
		endif()
		list(APPEND CMAKE_EXE_LINKER_FLAGS -static-libgcc -static-libstdc++ -static)
	else()
		if (SSE)
			add_compile_options(-msse4.1)
		endif()
	endif()

	list(APPEND CMAKE_C_FLAGS	${GCC_COMPILE_FLAGS})
	list(APPEND CMAKE_CXX_FLAGS	${GCC_COMPILE_FLAGS})
endif()

add_library(basisu_encoder STATIC
	encoder/basisu_backend.cpp
	encoder/basisu_basis_file.cpp
	encoder/basisu_comp.cpp
	encoder/basisu_enc.cpp
	encoder/basisu_etc.cpp
	encoder/basisu_frontend.cpp
	encoder/basisu_gpu_texture.cpp
	encoder/basisu_pvrtc1_4.cpp
	encoder/basisu_resampler.cpp
	encoder/basisu_resample_filters.cpp
	encoder/basisu_ssim.cpp
	encoder/basisu_uastc_enc.cpp
	encoder/basisu_bc7enc.cpp
	encoder/jpgd.cpp
	encoder/basisu_kernels_sse.cpp
	encoder/basisu_opencl.cpp
	encoder/pvpngreader.cpp
)

add_library(basisu_transcoder STATIC
	transcoder/basisu_transcoder.cpp
)

add_executable(basisu basisu_tool.cpp)
target_link_libraries(basisu PRIVATE basisu_encoder basisu_transcoder)

if (NOT MSVC)
	target_link_libraries(basisu PRIVATE m pthread)
endif()

if (NOT EMSCRIPTEN)
	install(TARGETS basisu_encoder basisu_transcoder basisu
		LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
		ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
		RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
	)
	file(GLOB TRANSCODER_HEADERS "transcoder/basisu*.h")
	install(FILES ${TRANSCODER_HEADERS} DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/basisu/transcoder")
	file(GLOB ENCODER_HEADERS "encoder/basisu*.h")
	install(FILES ${ENCODER_HEADERS} DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/basisu/encoder")
endif()
