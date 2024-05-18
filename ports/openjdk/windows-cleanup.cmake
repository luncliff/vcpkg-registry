file(GLOB UNUSED_FILES
    "${CURRENT_PACKAGES_DIR}/bin/api-ms*.dll"
    "${CURRENT_PACKAGES_DIR}/bin/ucrtbase*.dll"
    "${CURRENT_PACKAGES_DIR}/bin/vcruntime*.dll"
    "${CURRENT_PACKAGES_DIR}/bin/msvc*.dll"
    "${CURRENT_PACKAGES_DIR}/bin/*.map"
    "${CURRENT_PACKAGES_DIR}/bin/*.pdb"
    "${CURRENT_PACKAGES_DIR}/bin/server/*.map"
    "${CURRENT_PACKAGES_DIR}/bin/server/*.pdb"
    "${CURRENT_PACKAGES_DIR}/_optimize_image_exec*"
    "${CURRENT_PACKAGES_DIR}/release"
)
file(REMOVE_RECURSE ${UNUSED_FILES})

file(GLOB EXE_FILES "${CURRENT_PACKAGES_DIR}/bin/*.exe")
foreach(EXE_FILE ${EXE_FILES})
    get_filename_component(EXE_NAME "${EXE_FILE}" NAME_WE)
    list(APPEND TOOLS ${EXE_NAME})
endforeach()
vcpkg_copy_tools(TOOL_NAMES ${TOOLS} AUTO_CLEAN)
