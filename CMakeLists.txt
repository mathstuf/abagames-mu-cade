cmake_minimum_required(VERSION 2.8.12)
list(APPEND CMAKE_MODULE_PATH
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

set(rc_lang)
if (WIN32)
    set(rc_lang RC)
endif ()

project(mu-cade D ${rc_lang})

set(CMAKE_D_FLAGS
    "${CMAKE_D_FLAGS} -Wall")

option(MUCADE_INSTALL "Whether to build an installable Mu-cade or not" OFF)
if (MUCADE_INSTALL)
    set(CMAKE_D_FLAGS
        "${CMAKE_D_FLAGS} ${CMAKE_D_VERSION_FLAG}MucadeInstall")
endif ()

get_filename_component(CMAKE_SYSTEM_ROOT "${CMAKE_D_COMPILER}" DIRECTORY)
get_filename_component(CMAKE_SYSTEM_ROOT "${CMAKE_SYSTEM_ROOT}" DIRECTORY)

include_directories(SYSTEM "${CMAKE_SYSTEM_ROOT}/include/d")

add_subdirectory(src)

if (WIN32)
    set(asset_suffix "")
else ()
    set(asset_suffix "/mu-cade")
endif ()

install(
    DIRECTORY   "barrage" "images" "sounds"
    DESTINATION "share${asset_suffix}"
    COMPONENT   runtime)

if (WIN32)
    # Nothing needed for the icon.
elseif (UNIX)
    install(
        FILES       "resource/mu-cade.desktop"
        DESTINATION "share/applications"
        COMPONENT   runtime)
    install(
        FILES       "resource/mu-cade.png"
        DESTINATION "share/icons/locolor/32x32"
        COMPONENT   runtime)
endif ()
