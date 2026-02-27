# Lib name
set(DU_BINLOG_LIB_NAME "dubinlog")

# Lib source file dir
set(DU_BINLOG_LIB_DIR "${DU_SOURCE_DIR}/binlog")

# Read all .cc files from DU_BINLOG_LIB_DIR
file(GLOB DU_BINLOG_LIB_SRC_FILES "${DU_BINLOG_LIB_DIR}/*.cc")

# Create the RAN library
add_library(${DU_BINLOG_LIB_NAME} STATIC ${DU_BINLOG_LIB_SRC_FILES})

# Libs required
#target_link_libraries(
#    ${DU_BINLOG_LIB_NAME}
#    #dulogger
#)

# Headers required
target_include_directories(
    ${DU_BINLOG_LIB_NAME}
    PUBLIC
    ${DU_BINLOG_LIB_DIR}
    ${DU_SOURCE_DIR}/interfaces/src
    ${DU_SOURCE_DIR}/l2app/src
    ${DU_SOURCE_DIR}/mac/export
    ${DU_SOURCE_DIR}/mac/src
    ${DU_SOURCE_DIR}/macphy/export
    ${DU_SOURCE_DIR}/macphy/src
    ${DU_SOURCE_DIR}/rlc/export
    ${DU_SOURCE_DIR}/rlc/src
    ${DU_SOURCE_DIR}/rlcio/export
    ${DU_SOURCE_DIR}/rlcio/src
    ${DU_SOURCE_DIR}/utils/export
    ${DU_SOURCE_DIR}/utils/src
    ${DU_SOURCE_DIR}/nrmactest/export
    ${DU_SOURCE_DIR}/nrmactest/src
    ${DU_SOURCE_DIR}/rlctest/export
    ${DU_SOURCE_DIR}/rlctest/src
    ${COMMON_SOURCE_DIR}/cmn/export
    ${COMMON_SOURCE_DIR}/cmn/src
    ${COMMON_SOURCE_DIR}/base/export
    ${COMMON_SOURCE_DIR}/base/src
    ${COMMON_SOURCE_DIR}/tests/unittest/UnitTest++/h
    ${PROJECT_DIR}/components/callp/export
    ${PROJECT_DIR}/components/3rdparty/export/license
)
