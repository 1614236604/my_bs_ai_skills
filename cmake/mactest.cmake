# Lib name
set(DU_MACTEST_LIB_NAME "dumactest")

# Lib source file dir
set(DU_MACTEST_LIB_DIR "${DU_SOURCE_DIR}/nrmactest/src")

# Read all .cc files from DU_MACTEST_LIB_DIR
file(GLOB DU_MACTEST_LIB_SRC_FILES "${DU_MACTEST_LIB_DIR}/*.cc")

# Create the mactest library
add_library(${DU_MACTEST_LIB_NAME} STATIC ${DU_MACTEST_LIB_SRC_FILES})

target_link_libraries(
    ${DU_MACTEST_LIB_NAME}
    dubinlog
)