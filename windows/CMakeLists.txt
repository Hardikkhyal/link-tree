# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(hk_drop LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "hk_drop")

# Explicitly opt into modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(SET CMP0063 NEW)

# Define build configuration options.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
  set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}" CACHE STRING "" FORCE)
  set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}" CACHE STRING "" FORCE)
  set(CMAKE_STATIC_LINKER_FLAGS_PROFILE "${CMAKE_STATIC_LINKER_FLAGS_RELEASE}" CACHE STRING "" FORCE)
  set(CMAKE_MODULE_LINKER_FLAGS_PROFILE "${CMAKE_MODULE_LINKER_FLAGS_RELEASE}" CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "" FORCE)
  endif()
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Profile" "Release")
endif()

# Define the standard compiler/linker settings function used by flutter subdir.
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

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build.
add_subdirectory("runner")

# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake OPTIONAL)

# === Installation ===
# Support staging allocations for install.
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/runner")
endif()
set(CMAKE_INSTALL_PREFIX ${CMAKE_INSTALL_PREFIX} CACHE PATH "..." FORCE)

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}")

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${CMAKE_INSTALL_PREFIX}"
  CONFIGURATIONS Debug;Profile;Release OPTIONAL)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}" DESTINATION "${CMAKE_INSTALL_PREFIX}"
    CONFIGURATIONS Debug;Profile;Release OPTIONAL)
endif()

# Copy Flutter assets and ICU data into the data/ subdirectory
set(PROJECT_BUILD_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../build")
install(DIRECTORY "${PROJECT_BUILD_DIR}/flutter_assets" DESTINATION "${CMAKE_INSTALL_PREFIX}/data"
  CONFIGURATIONS Debug;Profile;Release OPTIONAL)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${CMAKE_INSTALL_PREFIX}/data"
  CONFIGURATIONS Debug;Profile;Release OPTIONAL)
