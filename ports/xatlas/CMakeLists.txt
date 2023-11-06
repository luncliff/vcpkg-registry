cmake_minimum_required(VERSION 3.13)
project(xatlas LANGUAGES CXX)
include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 11)

list(APPEND headers xatlas/xatlas.h xatlas/xatlas_c.h)

add_library(xatlas
    ${headers}
    xatlas/xatlas.cpp
)

set_target_properties(xatlas
PROPERTIES
    PUBLIC_HEADER "${headers}"
)

if(BUILD_SHARED_LIBS)
    target_compile_definitions(xatlas PRIVATE XATLAS_EXPORT_API=1)
else()
    target_compile_definitions(xatlas PRIVATE XATLAS_EXPORT_API=0)
endif()

install(TARGETS xatlas
        EXPORT xatlas-config # minor trick to support `find_package(xatlas)`
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)
install(EXPORT xatlas-config
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/xatlas # share/xatlas
)
