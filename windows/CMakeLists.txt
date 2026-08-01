cmake_minimum_required(VERSION 3.14)
project(hk_drop LANGUAGES CXX)

set(BINARY_NAME "hk_drop")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Configure build options.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "" FORCE)
  endif()
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Profile" "Release")
endif()

# Define the application target.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")

add_subdirectory(${FLUTTER_MANAGED_DIR})
add_subdirectory("runner")

# Standard Flutter build settings.
apply_standard_settings(${BINARY_NAME})
set_target_properties(${BINARY_NAME} PROPERTIES
  WIN32_EXECUTABLE TRUE)
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE
  "dwmapi.lib"
)
target_include_directories(${BINARY_NAME} PRIVATE
  "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Only the install-generated bundle's copy of the executable will launch
# correctly, since the resources must in the right relative locations. To avoid
# people trying to run the IDE-generated binary without realizing this, rename
# the internal binary.
set_target_properties(${BINARY_NAME}
  PROPERTIES
  OUTPUT_NAME "$<CONFIG>/runner"
)

# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)

# === Installation ===
# Install bundle.
install(CODE "
  file(REMOVE_RECURSE \"${CMAKE_INSTALL_PREFIX}\")
")
install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/\${CMAKE_INSTALL_CONFIG_NAME}/"
  DESTINATION . USE_SOURCE_PERMISSIONS)
