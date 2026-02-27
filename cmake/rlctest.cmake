# Lib name
set(DU_RLCTEST_LIB_NAME "durlctest")

# Lib source file dir
set(DU_RLCTEST_LIB_DIR "${DU_SOURCE_DIR}/rlctest/src")

# Read all .cc files from DU_RLCTEST_LIB_DIR
file(GLOB DU_RLCTEST_LIB_SRC_FILES "${DU_RLCTEST_LIB_DIR}/*.cc")

# Create the rlctest library
add_library(${DU_RLCTEST_LIB_NAME} STATIC ${DU_RLCTEST_LIB_SRC_FILES})

target_link_libraries(
    ${DU_RLCTEST_LIB_NAME}
    dubinlog
)