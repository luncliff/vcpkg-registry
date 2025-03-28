@PACKAGE_INIT@
get_filename_component(_DIR "${CMAKE_CURRENT_LIST_FILE}" PATH)
include("${_DIR}/cudnn-frontend-targets.cmake")