# CMake version required
cmake_minimum_required(VERSION 3.10)

# Project name
project(xwydbs_type2)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED TRUE)
set(CMAKE_CXX_EXTENSIONS ON)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -Wall -g")
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

set(PROJECT_DEFINE "")
set(CMD_FILE_PATH "${CMAKE_SOURCE_DIR}/src/.config")
if(EXISTS ${CMD_FILE_PATH})
    file(READ ${CMD_FILE_PATH} CMD_FILE_CONTENT)
    string(REPLACE "\r\n" "\n" CMD_FILE_CONTENT "${CMD_FILE_CONTENT}")
    string(REPLACE "\r" "\n" CMD_FILE_CONTENT "${CMD_FILE_CONTENT}")
    string(REGEX REPLACE "\n$" "" CMD_FILE_CONTENT "${CMD_FILE_CONTENT}")
    string(REPLACE "\n" ";" CMD_FILE_LINES "${CMD_FILE_CONTENT}")
    foreach(line IN LISTS CMD_FILE_LINES)
        if(NOT line MATCHES "^#" AND NOT line STREQUAL "")
            set(PROJECT_DEFINE "${PROJECT_DEFINE} -D${line}")
        endif()
    endforeach()
endif()

add_definitions(${PROJECT_DEFINE})

set(PROJECT_DIR "${CMAKE_SOURCE_DIR}/src")
set(COMMON_SOURCE_DIR "${PROJECT_DIR}/common")
set(OAM_SOURCE_DIR "${PROJECT_DIR}/nanoOam")
set(CU_SOURCE_DIR "${PROJECT_DIR}/cuapp")
set(CU_CPCELL_SOURCE_DIR "${CU_SOURCE_DIR}/cp/cpcellapp")
set(UP_SOURCE_DIR "${PROJECT_DIR}/cuapp/up")
set(DU_SOURCE_DIR "${PROJECT_DIR}/duapp")

include_directories(${PROJECT_DIR}/common/3rdparty/ephemeris/Eigen)
include_directories(${PROJECT_DIR}/common/3rdparty/ephemeris/export)
include_directories(${PROJECT_DIR}/common/cmn/export)
include_directories(${CMAKE_SOURCE_DIR}/include)

include(cmake/binlog.cmake)
include(cmake/interfaces.cmake)
include(cmake/l2app.cmake)
include(cmake/rlc.cmake)
include(cmake/rlcio.cmake)
include(cmake/rlctest.cmake)
include(cmake/mac.cmake)
include(cmake/macphy.cmake)
include(cmake/mactest.cmake)
include(cmake/utils.cmake)
