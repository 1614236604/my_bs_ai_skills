# Lib name
set(DU_MACPHY_LIB_NAME "dumacphy")

# Lib source file dir
set(DU_MACPHY_LIB_DIR "${DU_SOURCE_DIR}/macphy/src")

# Read all .cc files from DU_MACPHY_LIB_DIR
file(GLOB DU_MACPHY_LIB_SRC_FILES "${DU_MACPHY_LIB_DIR}/*.cc")

# Create the macphy library
add_library(${DU_MACPHY_LIB_NAME} STATIC ${DU_MACPHY_LIB_SRC_FILES})

target_link_libraries(
    ${DU_MACPHY_LIB_NAME}
    dubinlog
)