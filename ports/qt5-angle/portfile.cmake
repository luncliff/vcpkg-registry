#[===[.md:
# qt-angle

Requires CMake 3.19+, Python3

#]===]
set(VCPKG_POLICY_EMPTY_PACKAGE enabled)

find_package(Python3 REQUIRED COMPONENTS Interpreter Development)
get_filename_component(PYTHON_PATH "${Python3_EXECUTABLE}" PATH)

find_path(PYTHON_CMAKE_SEARCH_DIR "Qt5OpenGL/Qt5OpenGLConfig.cmake"
     PATHS "${PYTHON_PATH}/Library/lib/cmake"
     REQUIRED
)
get_filename_component(CACHED_Qt5_DIR "${PYTHON_CMAKE_SEARCH_DIR}/Qt5" ABSOLUTE)

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
     # ... reserved section for architecture details ...
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
     # ... reserved section for architecture details ...
endif()
configure_file(${CMAKE_CURRENT_LIST_DIR}/FindQtANGLE.cmake.in
               ${CURRENT_BUILDTREES_DIR}/FindQtANGLE.cmake @ONLY)

# Install `qt5-angle-config.cmake` for `find_package(qt5-angle CONFIG REQUIRED)`
file(INSTALL     ${CURRENT_BUILDTREES_DIR}/FindQtANGLE.cmake
     DESTINATION ${CURRENT_PACKAGES_DIR}/share/${PORT}
     RENAME      "${PORT}-config.cmake"
)
