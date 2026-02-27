# Lib name
set(DU_UTILS_LIB_NAME "duutils")

# Lib source file dir
set(DU_UTILS_LIB_DIR "${DU_SOURCE_DIR}/utils/src")

# Read all .cc files from DU_UTILS_LIB_DIR
file(GLOB DU_UTILS_LIB_SRC_FILES "${DU_UTILS_LIB_DIR}/*.cc")

# Create the utils library
add_library(${DU_UTILS_LIB_NAME} STATIC ${DU_UTILS_LIB_SRC_FILES})

target_link_libraries(
    ${DU_UTILS_LIB_NAME}
    dubinlog
)