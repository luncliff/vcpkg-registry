cmake_minimum_required(VERSION 3.18)
project(XNVCtrl LANGUAGES C)

find_package(X11 REQUIRED)

add_library(XNVCtrl NVCtrl.c)

set_target_properties(XNVCtrl
PROPERTIES
  C_STANDARD 11
)

target_include_directories(XNVCtrl
PRIVATE
  ${X11_INCLUDE_DIR}
)

target_compile_options(XNVCtrl
PRIVATE
  -Wno-format-zero-length -Wno-unused-parameter
)

target_link_libraries(XNVCtrl
PRIVATE
  X11::xcb # /usr/lib/x86_64-linux-gnu/libxcb.so
)

include(GNUInstallDirs)
install(FILES NVCtrl.h NVCtrlLib.h nv_control.h
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)
install(TARGETS XNVCtrl DESTINATION ${CMAKE_INSTALL_LIBDIR})
