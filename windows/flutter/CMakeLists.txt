# This file is managed by Flutter. Do not edit.

# Location of the Flutter tool CMake logic.
set(FLUTTER_ROOT "$ENV{FLUTTER_ROOT}")
if(NOT FLUTTER_ROOT)
  message(FATAL_ERROR "FLUTTER_ROOT environment variable not set.")
endif()

set(FLUTTER_EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Include the ephemeral generated CMake files.
include("${FLUTTER_EPHEMERAL_DIR}/generated_config.cmake" OPTIONAL)

if(NOT TARGET flutter_assemble)
  add_custom_target(flutter_assemble ALL
    COMMAND ${CMAKE_COMMAND} -E echo "Flutter assemble"
  )
endif()

# Forward line-editing option to the build system.
set(FLUTTER_TARGET_PLATFORM "windows-x64")

# Set build settings for Flutter components.
set(FLUTTER_LIBRARY "${FLUTTER_EPHEMERAL_DIR}/flutter_windows.dll")
set(FLUTTER_LIBRARY_HEADER "${FLUTTER_EPHEMERAL_DIR}/flutter_windows.h")
set(FLUTTER_ICU_DATA_FILE "${FLUTTER_EPHEMERAL_DIR}/icudtl.dat")
set(FLUTTER_WRAPPER_HEADER "${FLUTTER_EPHEMERAL_DIR}/cpp_client_wrapper/include")

# Function to apply standard compiler and linker flags for Windows targets.
function(apply_standard_settings TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:/W4 /WX /wd"4100" /wd"4127" /wd"4512" /wd"4996" /wd"4324" /EHsc>
    $<$<COMPILE_LANGUAGE:C>:/W4 /WX /wd"4100" /wd"4127" /wd"4512" /wd"4996" /wd"4324">
  )
  target_compile_definitions(${TARGET} PRIVATE
    _HAS_EXCEPTIONS=0
    $<$<CONFIG:Debug>:UNICODE _UNICODE _DEBUG>
    $<$<CONFIG:Profile>:UNICODE _UNICODE NDEBUG>
    $<$<CONFIG:Release>:UNICODE _UNICODE NDEBUG>
  )
endfunction()

# Copy the Flutter library and ICU data binary dependencies to the binary output directory.
add_library(flutter_wrapper_app STATIC
  "${FLUTTER_EPHEMERAL_DIR}/cpp_client_wrapper/core_implementations.cc"
  "${FLUTTER_EPHEMERAL_DIR}/cpp_client_wrapper/standard_codec.cc"
  "${FLUTTER_EPHEMERAL_DIR}/cpp_client_wrapper/flutter_engine.cc"
  "${FLUTTER_EPHEMERAL_DIR}/cpp_client_wrapper/flutter_view_controller.cc"
)
apply_standard_settings(flutter_wrapper_app)
target_include_directories(flutter_wrapper_app PUBLIC
  "${FLUTTER_WRAPPER_HEADER}"
  "${FLUTTER_EPHEMERAL_DIR}"
)
add_dependencies(flutter_wrapper_app flutter_assemble)

add_library(flutter_wrapper_plugin STATIC
  "${FLUTTER_EPHEMERAL_DIR}/cpp_client_wrapper/core_implementations.cc"
  "${FLUTTER_EPHEMERAL_DIR}/cpp_client_wrapper/standard_codec.cc"
  "${FLUTTER_EPHEMERAL_DIR}/cpp_client_wrapper/plugin_registrar.cc"
)
apply_standard_settings(flutter_wrapper_plugin)
target_include_directories(flutter_wrapper_plugin PUBLIC
  "${FLUTTER_WRAPPER_HEADER}"
  "${FLUTTER_EPHEMERAL_DIR}"
)
add_dependencies(flutter_wrapper_plugin flutter_assemble)
