# Lib name
set(DU_RLC_LIB_NAME "durlc")

# Lib source file dir
set(DU_RLC_LIB_DIR "${DU_SOURCE_DIR}/rlc/src")

# Read all .cc files from DU_RLC_LIB_DIR
file(GLOB DU_RLC_LIB_SRC_FILES "${DU_RLC_LIB_DIR}/*.cc")

# Create the rlc library
add_library(${DU_RLC_LIB_NAME} STATIC ${DU_RLC_LIB_SRC_FILES})

target_link_libraries(
    ${DU_RLC_LIB_NAME}
    dubinlog
)