# Lib name
set(DU_L2APP_LIB_NAME "dul2app")

# Lib source file dir
set(DU_L2APP_LIB_DIR "${DU_SOURCE_DIR}/l2app/src")

# Read all .cc files from DU_L2APP_LIB_DIR
file(GLOB DU_L2APP_LIB_SRC_FILES "${DU_L2APP_LIB_DIR}/*.cc")

# Create the l2app library
add_library(${DU_L2APP_LIB_NAME} STATIC ${DU_L2APP_LIB_SRC_FILES})

# Link with other libraries
target_link_libraries(
    ${DU_L2APP_LIB_NAME}
    dubinlog
)