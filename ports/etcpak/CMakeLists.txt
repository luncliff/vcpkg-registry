cmake_minimum_required(VERSION 3.13)
project(etcpak LANGUAGES CXX)
include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 14)

list(APPEND headers
    Bitmap.hpp
    BitmapDownsampled.hpp
    BlockData.hpp
    ColorSpace.hpp
    DataProvider.hpp
    Debug.hpp
    Dither.hpp
    Error.hpp
    ForceInline.hpp
    Math.hpp
    MipMap.hpp
    mmap.hpp
    ProcessCommon.hpp
    ProcessDxtc.hpp
    ProcessRGB.hpp
    Semaphore.hpp
    System.hpp
    Tables.hpp
    TaskDispatch.hpp
    Timing.hpp
    Vector.hpp
)

add_library(etcpak STATIC
    ${headers}
    Application.cpp
    Bitmap.cpp
    BitmapDownsampled.cpp
    BlockData.cpp
    ColorSpace.cpp
    DataProvider.cpp
    Debug.cpp
    Dither.cpp
    Error.cpp
    mmap.cpp
    ProcessDxtc.cpp
    ProcessRGB.cpp
    System.cpp
    Tables.cpp
    TaskDispatch.cpp
    Timing.cpp
)

set_target_properties(etcpak
PROPERTIES
    PUBLIC_HEADER "${headers}"
)

if(WIN32)
    target_compile_definitions(etcpak PRIVATE NOMINMAX)
endif()

install(TARGETS etcpak
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/etcpak
)
