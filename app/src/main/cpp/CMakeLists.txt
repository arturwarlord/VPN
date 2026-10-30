cmake_minimum_required(VERSION 3.22.1)
project(FreeRouteOpenVPN3 LANGUAGES C CXX)
if(NOT ANDROID)
  message(FATAL_ERROR "Configure with the Android NDK toolchain.")
endif()
if(NOT DEFINED OPENVPN3_SOURCE_DIR OR NOT EXISTS "${OPENVPN3_SOURCE_DIR}/client/ovpncli.cpp")
  message(FATAL_ERROR "OPENVPN3_SOURCE_DIR must point to the pinned OpenVPN 3 checkout.")
endif()
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
include("${OPENVPN3_SOURCE_DIR}/cmake/findcoredeps.cmake")
set(OPENVPN_PLAT android)
if(NOT DEFINED OPENVPN3_SWIG_WRAPPER OR NOT EXISTS "${OPENVPN3_SWIG_WRAPPER}")
  message(FATAL_ERROR "OPENVPN3_SWIG_WRAPPER must point to the generated SWIG Java binding.")
endif()
add_library(freeroute_openvpn3 SHARED
  native_bridge.cpp
  openvpn_client_bridge.cpp
  "${OPENVPN3_SOURCE_DIR}/client/ovpncli.cpp"
  "${OPENVPN3_SWIG_WRAPPER}"
)
set_source_files_properties("${OPENVPN3_SWIG_WRAPPER}" PROPERTIES COMPILE_DEFINITIONS "SWIGJAVA")
target_include_directories(freeroute_openvpn3 PRIVATE "${OPENVPN3_SOURCE_DIR}/client" "${OPENVPN3_SOURCE_DIR}")
add_core_dependencies(freeroute_openvpn3)
# Android Bionic exposes pthread symbols through libc, not a separate libpthread.so.
get_target_property(_freeroute_openvpn3_links freeroute_openvpn3 LINK_LIBRARIES)
if(_freeroute_openvpn3_links)
  list(REMOVE_ITEM _freeroute_openvpn3_links pthread)
  set_property(TARGET freeroute_openvpn3 PROPERTY LINK_LIBRARIES "${_freeroute_openvpn3_links}")
endif()
target_compile_options(freeroute_openvpn3 PRIVATE -fexceptions -frtti)
# OpenVPN's dependency helper uses the plain target_link_libraries signature.
# Keep this call plain as well; CMake rejects mixing plain and keyword signatures.
target_link_libraries(freeroute_openvpn3 log)
set_target_properties(freeroute_openvpn3 PROPERTIES OUTPUT_NAME "freeroute_openvpn3" CXX_VISIBILITY_PRESET hidden VISIBILITY_INLINES_HIDDEN YES)
