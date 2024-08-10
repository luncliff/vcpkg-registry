cmake_minimum_required(VERSION 3.24)
project(google-jni-bind LANGUAGES CXX)
include(GNUInstallDirs)

option(BUILD_TESTING "Build test programs" OFF)

find_package(JNI REQUIRED) # JNI::JNI

install(FILES jni_bind_release.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

if(NOT BUILD_TESTING)
    return()
endif()
find_package(GTest REQUIRED) # GTest::GTest

file(GLOB implementations implementation/*.h)
file(GLOB class_defs class_defs/*.h)

add_library(jni_bind INTERFACE
    ${PROJECT_SOURCE_DIR}
    ${implementations}
    ${class_defs}
)

target_link_libraries(jni_bind INTERFACE JNI::JNI)

add_executable(jni_bind_test)

file(GLOB implementation_tests implementation/*test.cc)

target_sources(jni_bind_test PRIVATE
    ${implementation_tests}
    ${implementations}
    ${class_defs}
)

target_include_directories(jni_bind_test PRIVATE ${PROJECT_SOURCE_DIR})

target_compile_features(jni_bind_test PRIVATE cxx_std_17)

target_link_libraries(jni_bind_test PRIVATE
    jni_bind
    GTest::gtest GTest::gmock
    # GTest::Main
)
