cmake_minimum_required(VERSION 3.22)
project(smol-v CXX)
include(GNUInstallDirs)

add_library(smol-v
  source/smolv.h
  source/smolv.cpp
)

install(TARGETS smol-v
        DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES source/smolv.h
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)
