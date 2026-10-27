get_filename_component(_emdawnwebgpu_pkg_dir "${CMAKE_CURRENT_LIST_DIR}/../emdawnwebgpu" ABSOLUTE)

if(NOT TARGET dawn::webgpu_dawn)
    add_library(dawn::webgpu_dawn INTERFACE IMPORTED)
    set_target_properties(dawn::webgpu_dawn PROPERTIES
        INTERFACE_COMPILE_OPTIONS "--use-port=${_emdawnwebgpu_pkg_dir}/emdawnwebgpu.port.py"
        INTERFACE_LINK_OPTIONS "--use-port=${_emdawnwebgpu_pkg_dir}/emdawnwebgpu.port.py"
    )
endif()

# C++20 named module 'wgpu', like the 'dawn::cpp_module' of Dawn's CMake.
# The module interface unit is compiled by the importer (requires CMake 3.28+ and a generator with C++ modules support).
if(NOT TARGET dawn::cpp_module AND NOT CMAKE_VERSION VERSION_LESS 3.28)
    add_library(dawn::cpp_module INTERFACE IMPORTED)
    set_target_properties(dawn::cpp_module PROPERTIES
        IMPORTED_CXX_MODULES_COMPILE_FEATURES "cxx_std_20"
        IMPORTED_CXX_MODULES_COMPILE_OPTIONS "--use-port=${_emdawnwebgpu_pkg_dir}/emdawnwebgpu.port.py"
        IMPORTED_CXX_MODULES_LINK_LIBRARIES "dawn::webgpu_dawn"
        INTERFACE_COMPILE_FEATURES "cxx_std_20"
        INTERFACE_LINK_LIBRARIES "dawn::webgpu_dawn"
    )
    target_sources(dawn::cpp_module INTERFACE
        FILE_SET CXX_MODULES
        BASE_DIRS "${_emdawnwebgpu_pkg_dir}/webgpu_cpp/include"
        FILES "${_emdawnwebgpu_pkg_dir}/webgpu_cpp/include/webgpu/webgpu.ixx"
    )
    # Before CMake 4.4, the BMI is always compiled with the default '-std=gnu++20' instead of the importer's flags,
    # which causes -Wmodule-file-config-mismatch. Follow the CMAKE_CXX_STANDARD/CMAKE_CXX_EXTENSIONS variables instead.
    if(CMAKE_VERSION VERSION_LESS 4.4)
        set(_emdawnwebgpu_cxx_std 20)
        if(CMAKE_CXX_STANDARD GREATER 20 AND NOT CMAKE_CXX_STANDARD GREATER_EQUAL 98)
            set(_emdawnwebgpu_cxx_std "${CMAKE_CXX_STANDARD}")
        endif()
        set(_emdawnwebgpu_cxx_ext "gnu++")
        if(DEFINED CMAKE_CXX_EXTENSIONS AND NOT CMAKE_CXX_EXTENSIONS)
            set(_emdawnwebgpu_cxx_ext "c++")
        endif()
        set_property(TARGET dawn::cpp_module APPEND PROPERTY
            IMPORTED_CXX_MODULES_COMPILE_OPTIONS "-std=${_emdawnwebgpu_cxx_ext}${_emdawnwebgpu_cxx_std}"
        )
        unset(_emdawnwebgpu_cxx_std)
        unset(_emdawnwebgpu_cxx_ext)
    endif()
endif()

unset(_emdawnwebgpu_pkg_dir)
