
include(FindPackageHandleStandardArgs)

find_path(Foundation_INCLUDE_DIR "Foundation/Foundation.hpp" REQUIRED)
find_library(Foundation_LIBRARY NAMES Foundation REQUIRED)

find_path(QuartzCore_INCLUDE_DIR "QuartzCore/QuartzCore.hpp" REQUIRED)
find_library(QuartzCore_LIBRARY NAMES QuartzCore REQUIRED)

find_path(MetalCpp_INCLUDE_DIRS   "Metal/Metal.hpp" REQUIRED)
find_library(MetalCpp_LIBRARY   NAMES Metal REQUIRED)

list(APPEND MetalCpp_LIBRARIES ${Foundation_LIBRARY} ${QuartzCore_LIBRARY} ${MetalCpp_LIBRARY})

find_package_handle_standard_args(MetalCpp
    REQUIRED_VARS MetalCpp_INCLUDE_DIRS MetalCpp_LIBRARY
)
