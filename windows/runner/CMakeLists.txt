cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

set(BINARY_NAME "hk_drop")

add_executable(${BINARY_NAME} WIN32
  "main.cpp"
  "my_application.cpp"
  "my_application.h"
  "win32_window.cpp"
  "win32_window.h"
  "flutter_window.cpp"
  "flutter_window.h"
  "resource.h"
  "Runner.rc"
  "runner.exe.manifest"
  "utils.cpp"
  "utils.h"
)

apply_standard_settings(${BINARY_NAME})

target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

add_dependencies(${BINARY_NAME} flutter_assemble)

# Only the install-generated bundle's copy of the executable will launch
# correctly, since the resources must in the right relative locations. To avoid
# people trying to run the IDE-generated binary without realizing this, rename
# the internal binary.
set_target_properties(${BINARY_NAME}
  PROPERTIES
  OUTPUT_NAME "$<CONFIG>/runner"
)
