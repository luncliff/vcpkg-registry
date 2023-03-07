cmake_minimum_required(VERSION 3.24)
project(google-jni-bind LANGUAGES CXX)
include(GNUInstallDirs)

option(BUILD_TESTING "Build test programs" ON)

find_package(JNI REQUIRED) # JNI::JNI

install(FILES jni_bind_release.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

if(NOT BUILD_TESTING)
    return()
endif()

