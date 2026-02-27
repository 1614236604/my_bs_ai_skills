# Lib name
set(DU_INTERFACES_LIB_NAME "duinterfaces")

# Lib source file dir
set(DU_INTERFACES_LIB_DIR "${DU_SOURCE_DIR}/interfaces/src")

# Read all .cc files from DU_INTERFACES_LIB_DIR
file(GLOB DU_INTERFACES_LIB_SRC_FILES "${DU_INTERFACES_LIB_DIR}/*.cc")

# Create the interfaces library
add_library(${DU_INTERFACES_LIB_NAME} STATIC ${DU_INTERFACES_LIB_SRC_FILES})

target_link_libraries(
    ${DU_INTERFACES_LIB_NAME}
    dubinlog
)
