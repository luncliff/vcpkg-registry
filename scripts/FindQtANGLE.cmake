# 
# Authors
#   - github.com/luncliff (luncliff@gmail.com)
#
# References
#   - https://cmake.org/cmake/help/latest/manual/cmake-qt.7.html
#   - https://wiki.qt.io/Qt_5_on_Windows_ANGLE_and_OpenGL
# 
# Note
#   - Qt 6.0 is not tested yet...
#
# Tested 'Qt5_DIR's
#   - Anaconda3 (Qt 5.9): "C:\\tools\\Anaconda3\\Library\\lib\\cmake\\Qt5"
#   - Qt 5.12: "C:\\Qt\\Qt5.12.9\\5.12.9\\msvc2017_64\lib\\cmake\\Qt5"
#   - Qt 5.15: "C:\\Qt\\5.15.2\\msvc2019_64\\lib\\cmake\\Qt5"
#
cmake_minimum_required(VERSION 3.18)
if(QtANGLE_FOUND)
    return()
endif()
set(QtANGLE_FOUND FALSE)

find_package(Qt5 COMPONENTS OpenGL)
if(NOT Qt5_FOUND)
    message(WARNING "Failed: find_package(Qt5)")
    return()
endif()

message(STATUS "Found Qt5::OpenGL ${Qt5_VERSION}")
foreach(dirpath ${Qt5OpenGL_INCLUDE_DIRS})
    message(STATUS " - ${dirpath}")
endforeach()
foreach(libpath ${Qt5OpenGL_LIBRARIES})
    if(TARGET ${libpath})
        get_target_property(LIB_DBG ${libpath} IMPORTED_IMPLIB_DEBUG)
        get_target_property(LIB_REL ${libpath} IMPORTED_IMPLIB_RELEASE)
        if(WIN32)
            get_target_property(BIN_DBG ${libpath} IMPORTED_LOCATION_DEBUG)
            get_target_property(BIN_REL ${libpath} IMPORTED_LOCATION_RELEASE)
            message(STATUS " - ${LIB_DBG} -> ${BIN_DBG}")
            message(STATUS " - ${LIB_REL} -> ${BIN_REL}")
        else()
            message(STATUS " - ${LIB_DBG}")
            message(STATUS " - ${LIB_REL}")
        endif()
        unset(LIB_DBG)
        unset(LIB_REL)
        unset(BIN_DBG)
        unset(BIN_REL)
    else()
        message(STATUS " - ${libpath}")
    endif()
endforeach()
get_target_property(QtANGLE_COMPILE_DEFINITIONS Qt5::OpenGL INTERFACE_COMPILE_DEFINITIONS)
message(STATUS " - ${QtANGLE_COMPILE_DEFINITIONS}")

if(NOT DEFINED QtANGLE_ROOT_DIR)
    get_filename_component(QtANGLE_CMAKE_DIR ${Qt5_DIR} DIRECTORY)          # CMAKE_DIR <-- msvc2017_64/lib/cmake/
    get_filename_component(QtANGLE_LIB_DIR   ${QtANGLE_CMAKE_DIR} DIRECTORY)# LIB_DIR   <-- msvc2017_64/lib/
    get_filename_component(QtANGLE_ROOT_DIR  ${QtANGLE_LIB_DIR} DIRECTORY)  # ROOT_DIR  <-- msvc2017_64/
endif()

find_path(QtANGLE_INCLUDE_DIR NAMES QtANGLE PATHS ${Qt5OpenGL_INCLUDE_DIRS} NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH)
if(QtANGLE_INCLUDE_DIR_FOUND)
    # If we found QtANGLE folder, use it without any concern.
    get_filename_component(QtANGLE_INCLUDE_DIR ${QtANGLE_INCLUDE_DIR}/QtANGLE ABSOLUTE)
elseif(Qt5_DIR MATCHES Anaconda3)
    # Anaconda Qt 5.9 has a different include dir
    # EGL 1.4 + OpenGL ES 3.0
    get_filename_component(QtANGLE_INCLUDE_DIR ${QtANGLE_ROOT_DIR}/include/qt/QtANGLE ABSOLUTE)
else()
    # Qt 5.12+
    # EGL 1.4 + OpenGL ES 3.1
    get_filename_component(QtANGLE_INCLUDE_DIR ${QtANGLE_ROOT_DIR}/include/QtANGLE ABSOLUTE)
endif()

if(WIN32)
    find_library(QtANGLE_EGL_LIB_DBG  NAME libEGLd    libEGL    PATHS ${QtANGLE_LIB_DIR} REQUIRED NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH)
    find_library(QtANGLE_GLES_LIB_DBG NAME libGLESv2d libGLESv2 PATHS ${QtANGLE_LIB_DIR} REQUIRED NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH)
    find_library(QtANGLE_EGL_LIB_REL  NAME libEGL     PATHS ${QtANGLE_LIB_DIR} REQUIRED NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH)
    find_library(QtANGLE_GLES_LIB_REL NAME libGLESv2  PATHS ${QtANGLE_LIB_DIR} REQUIRED NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH)
    list(APPEND QtANGLE_LIBRARIES
        ${QtANGLE_EGL_LIB_DBG}  ${QtANGLE_EGL_LIB_REL}
        ${QtANGLE_GLES_LIB_DBG} ${QtANGLE_GLES_LIB_REL}
    )

    get_filename_component(QtANGLE_RUNTIME_DIR ${QtANGLE_LIB_DIR}/../bin ABSOLUTE)
    find_file(QtANGLE_EGL_BIN_DBG
        NAMES libEGLd.dll
              libEGL.dll
        PATHS ${QtANGLE_RUNTIME_DIR}
        REQUIRED NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH
    )
    get_filename_component(QtANGLE_EGL_PDB_DBG ${QtANGLE_RUNTIME_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}libEGLd.pdb ABSOLUTE)
    find_file(QtANGLE_EGL_BIN_REL
        NAMES libEGL.dll
        PATHS ${QtANGLE_RUNTIME_DIR}
        REQUIRED NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH
    )
    get_filename_component(QtANGLE_EGL_PDB_REL ${QtANGLE_RUNTIME_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}libEGL.pdb ABSOLUTE)
    if(NOT EXISTS ${QtANGLE_EGL_PDB_DBG})
        unset(QtANGLE_EGL_PDB_DBG)
    endif()
    if(NOT EXISTS ${QtANGLE_EGL_PDB_REL})
        unset(QtANGLE_EGL_PDB_REL)
    endif()
    find_file(QtANGLE_GLES_BIN_DBG
        NAMES libGLESv2d.dll
              libGLESv2.dll
        PATHS ${QtANGLE_RUNTIME_DIR}
        REQUIRED NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH
    )
    get_filename_component(QtANGLE_GLES_PDB_DBG ${QtANGLE_RUNTIME_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}libGLESv2d.pdb ABSOLUTE)
    find_file(QtANGLE_GLES_BIN_REL
        NAMES libGLESv2.dll
        PATHS ${QtANGLE_RUNTIME_DIR}
        REQUIRED NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH
    )
    get_filename_component(QtANGLE_GLES_PDB_REL ${QtANGLE_RUNTIME_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}libGLESv2.pdb ABSOLUTE)
    if(NOT EXISTS ${QtANGLE_GLES_PDB_DBG})
        unset(QtANGLE_GLES_PDB_DBG)
    endif()
    if(NOT EXISTS ${QtANGLE_GLES_PDB_REL})
        unset(QtANGLE_GLES_PDB_REL)
    endif()
    list(APPEND QtANGLE_BINARIES
        ${QtANGLE_EGL_BIN_DBG}  ${QtANGLE_EGL_PDB_DBG}
        ${QtANGLE_EGL_BIN_REL}  ${QtANGLE_EGL_PDB_REL}
        ${QtANGLE_GLES_BIN_DBG} ${QtANGLE_GLES_PDB_DBG}
        ${QtANGLE_GLES_BIN_REL} ${QtANGLE_GLES_PDB_REL}
    )
endif()

set(QtANGLE_FOUND TRUE)
message(STATUS "Found QtANGLE ${Qt5_VERSION}")
message(STATUS " - ${QtANGLE_INCLUDE_DIR}")
message(STATUS " - ${QtANGLE_LIB_DIR}")
if(WIN32)
message(STATUS "   - ${QtANGLE_EGL_LIB_DBG}")
message(STATUS "   - ${QtANGLE_EGL_LIB_REL}")
message(STATUS "   - ${QtANGLE_GLES_LIB_DBG}")
message(STATUS "   - ${QtANGLE_GLES_LIB_REL}")
message(STATUS " - ${QtANGLE_RUNTIME_DIR}")
message(STATUS "   - ${QtANGLE_EGL_BIN_DBG}")
if(DEFINED QtANGLE_EGL_PDB_DBG)
message(STATUS "   - ${QtANGLE_EGL_PDB_DBG}")
endif()
message(STATUS "   - ${QtANGLE_EGL_BIN_REL}")
if(DEFINED QtANGLE_EGL_PDB_REL)
message(STATUS "   - ${QtANGLE_EGL_PDB_REL}")
endif()
message(STATUS "   - ${QtANGLE_GLES_BIN_DBG}")
if(DEFINED QtANGLE_GLES_PDB_DBG)
message(STATUS "   - ${QtANGLE_GLES_PDB_DBG}")
endif()
message(STATUS "   - ${QtANGLE_GLES_BIN_REL}")
if(DEFINED QtANGLE_GLES_PDB_REL)
message(STATUS "   - ${QtANGLE_GLES_PDB_REL}")
endif()
endif()

if(WIN32)
    # libEGL.dll
    add_library(libEGL SHARED IMPORTED GLOBAL)
    add_library(Qt5::libEGL ALIAS libEGL)
    set_target_properties(libEGL
    PROPERTIES
        IMPORTED_IMPLIB "${QtANGLE_EGL_LIB_REL}"
        IMPORTED_IMPLIB_DEBUG   "${QtANGLE_EGL_LIB_DBG}"
        IMPORTED_IMPLIB_RELEASE "${QtANGLE_EGL_LIB_REL}"
        IMPORTED_LOCATION   "${QtANGLE_EGL_LOCATION}"
        IMPORTED_LOCATION_DEBUG     "${QtANGLE_EGL_LIB_REL}"
        IMPORTED_LOCATION_RELEASE   "${QtANGLE_EGL_LIB_REL}"
    )
    target_include_directories(libEGL
    INTERFACE
        ${QtANGLE_INCLUDE_DIR}
    )
    message(STATUS "Imported: Qt5::libEGL")
    # libGLESv2.dll
    add_library(libGLESv2 SHARED IMPORTED GLOBAL)
    add_library(Qt5::libGLESv2 ALIAS libGLESv2)
    set_target_properties(libGLESv2
    PROPERTIES
        IMPORTED_IMPLIB "${QtANGLE_GLES_LIB_REL}"
        IMPORTED_IMPLIB_DEBUG   "${QtANGLE_GLES_LIB_DBG}"
        IMPORTED_IMPLIB_RELEASE "${QtANGLE_GLES_LIB_REL}"
        IMPORTED_LOCATION   "${QtANGLE_GLES_LOCATION}"
        IMPORTED_LOCATION_DEBUG     "${QtANGLE_GLES_LIB_REL}"
        IMPORTED_LOCATION_RELEASE   "${QtANGLE_GLES_LIB_REL}"
    )
    target_include_directories(libGLESv2
    INTERFACE
        ${QtANGLE_INCLUDE_DIR}
    )
    target_compile_definitions(libGLESv2
    INTERFACE
        ${QtANGLE_COMPILE_DEFINITIONS}
    )
    message(STATUS "Imported: Qt5::libGLESv2")
endif()
