# Lib name
set(DU_MAC_LIB_NAME "dumac")

# Lib source file dir
set(DU_MAC_LIB_DIR "${DU_SOURCE_DIR}/mac/src")

# Read all .cc files from DU_MAC_LIB_DIR
file(GLOB DU_MAC_LIB_SRC_FILES "${DU_MAC_LIB_DIR}/*.cc")

# Create the mac library
add_library(${DU_MAC_LIB_NAME} STATIC ${DU_MAC_LIB_SRC_FILES})

target_link_libraries(
    ${DU_MAC_LIB_NAME}
    dubinlog
)