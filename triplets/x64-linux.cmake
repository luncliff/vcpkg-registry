set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_CMAKE_SYSTEM_NAME Linux)

set(VCPKG_LIBRARY_LINKAGE static)
list(APPEND dynamic_library_ports
    angle # expect libEGL.so, libGLESv2.so
    xnnpack
)
foreach(p IN ITEMS ${dynamic_library_ports})
    if(PORT STREQUAL "${p}")
        set(VCPKG_LIBRARY_LINKAGE dynamic)
        message(STATUS "Port '${PORT}' will be '${VCPKG_LIBRARY_LINKAGE}'")
        break()
    endif()
endforeach()
