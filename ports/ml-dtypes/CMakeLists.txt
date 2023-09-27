cmake_minimum_required(VERSION 3.13)
project(ml_dtypes CXX)

include(GNUInstallDirs)

list(APPEND headers
    include/float8.h
    include/int4.h
)

add_library(ml_dtypes INTERFACE)

set_target_properties(ml_dtypes PROPERTIES
    PUBLIC_HEADER "${headers}"
)

install(TARGETS ml_dtypes
        EXPORT ml_dtypes-config
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/ml_dtypes
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(EXPORT EXPORT ml_dtypes-config
        DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/ml_dtypes
)
