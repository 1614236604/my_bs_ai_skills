# Lib name
set(DU_RLCIO_LIB_NAME "durlcio")

# Lib source file dir
set(DU_RLCIO_LIB_DIR "${DU_SOURCE_DIR}/rlcio/src")

# Read all .cc files from DU_RLCIO_LIB_DIR
file(GLOB DU_RLCIO_LIB_SRC_FILES "${DU_RLCIO_LIB_DIR}/*.cc")

# Create the rlcio library
add_library(${DU_RLCIO_LIB_NAME} STATIC ${DU_RLCIO_LIB_SRC_FILES})

target_link_libraries(
    ${DU_RLCIO_LIB_NAME}
    dubinlog
)