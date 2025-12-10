#ifndef HDMI_TEXT_CONTROLLER_H
#define HDMI_TEXT_CONTROLLER_H


/****************** Include Files ********************/
#include "xil_types.h"
#include "xstatus.h"
#include "xparameters.h"

struct DATA {
  uint16_t vertices[9];
  uint8_t color;
  int32_t r_area;
};

// TODO: SET THIS LATER
volatile bool vsync;

//TODO: CHANGE THIS
static volatile struct DATA* data = XPAR_HDMI_TEXT_CONTROLLER_0_AXI_BASEADDR;


// Cornell Box Mesh
// Vertex1, Vertex2, Vertex3, RRRGGGBB
static const uint8_t cornell_box[][10] = {
    // Floor (white)
    {0,0,0,   255,0,0,   255,0,255,   0xFF},
    {0,0,0,   255,0,255,   0,0,255,   0xFF},
    // Ceiling (white)
    {0,255,0,   255,255,255,   255,255,0,   0xFF},
    {0,255,0,   0,255,255,   255,255,255,   0xFF},
    // Left wall (red)
    {0,0,0,   0,0,255,   0,255,255,   0xE0},
    {0,0,0,   0,255,255,   0,255,0,   0xE0},
    // Right wall (green)
    {255,0,0,   255,255,0,   255,255,255,   0x1C},
    {255,0,0,   255,255,255,   255,0,255,   0x1C},
    // Back wall (white)
    {0,0,255,   255,0,255,   255,255,255,   0xFF},
    {0,0,255,   255,255,255,   0,255,255,   0xFF},
    // Small cube (white)
    {51,0,102,   102,0,102,   102,0,153,   0xFF},
    {51,0,102,   102,0,153,   51,0,153,   0xFF},
    {51,51,102,  102,51,153,  102,51,102,  0xFF},
    {51,51,102,  51,51,153,  102,51,153,  0xFF},
    {51,0,102,   51,51,102,   102,51,102,   0xFF},
    {51,0,102,   102,51,102,  102,0,102,   0xFF},
    {51,0,153,   102,0,153,   102,51,153,   0xFF},
    {51,0,153,   102,51,153,  51,51,153,   0xFF},
    {51,0,102,   51,0,153,   51,51,153,   0xFF},
    {51,0,102,   51,51,153,   51,51,102,   0xFF},
    {102,0,102,   102,51,102,   102,51,153,   0xFF},
    {102,0,102,   102,51,153,   102,0,153,   0xFF},
    // Tall cube (white)
    {153,0,179,   204,0,179,   204,0,230,   0xFF},
    {153,0,179,   204,0,230,   153,0,230,   0xFF},
    {153,128,179,  204,128,230,  204,128,179,  0xFF},
    {153,128,179,  153,128,230,  204,128,230,  0xFF},
    {153,0,179,   153,128,179,   204,128,179,   0xFF},
    {153,0,179,   204,128,179,   204,0,179,   0xFF},
    {153,0,230,   204,0,230,   204,128,230,   0xFF},
    {153,0,230,   204,128,230,  153,128,230,   0xFF},
    {153,0,179,   153,0,230,   153,128,230,   0xFF},
    {153,0,179,   153,128,230,  153,128,179,   0xFF},
    {204,0,179,   204,128,179,   204,128,230,   0xFF},
    {204,0,179,   204,128,230,   204,0,230,   0xFF},
};
#define cornell_box_triangle_count (sizeof(cornell_box) / sizeof(cornell_box[0]))

static const int cornell_box_triangle_count =
    sizeof(cornell_box)/sizeof(cornell_box[0]);


/**************************** Type Definitions *****************************/
/**
 *
 * Write a value to a HDMI_TEXT_CONTROLLER register. A 32 bit write is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is written.
 *
 * @param   BaseAddress is the base address of the HDMI_TEXT_CONTROLLERdevice.
 * @param   RegOffset is the register offset from the base to write to.
 * @param   Data is the data written to the register.
 *
 * @return  None.
 *
 * @note
 * C-style signature:
 * 	void HDMI_TEXT_CONTROLLER_mWriteReg(u32 BaseAddress, unsigned RegOffset, u32 Data)
 *
 */
#define HDMI_TEXT_CONTROLLER_mWriteReg(BaseAddress, RegOffset, Data) \
  	Xil_Out32((BaseAddress) + (RegOffset), (u32)(Data))

/**
 *
 * Read a value from a HDMI_TEXT_CONTROLLER register. A 32 bit read is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is read from the register. The most significant data
 * will be read as 0.
 *
 * @param   BaseAddress is the base address of the HDMI_TEXT_CONTROLLER device.
 * @param   RegOffset is the register offset from the base to write to.
 *
 * @return  Data is the data from the register.
 *
 * @note
 * C-style signature:
 * 	u32 HDMI_TEXT_CONTROLLER_mReadReg(u32 BaseAddress, unsigned RegOffset)
 *
 */
#define HDMI_TEXT_CONTROLLER_mReadReg(BaseAddress, RegOffset) \
    Xil_In32((BaseAddress) + (RegOffset))

/************************** Function Prototypes ****************************/
/**
 *
 * Run a self-test on the driver/device. Note this may be a destructive test if
 * resets of the device are performed.
 *
 * If the hardware system is not built correctly, this function may never
 * return to the caller.
 *
 * @param   baseaddr_p is the base address of the HDMI_TEXT_CONTROLLER instance to be worked on.
 *
 * @return
 *
 *    - XST_SUCCESS   if all self-test code passed
 *    - XST_FAILURE   if any self-test code failed
 *
 * @note    Caching must be turned off for this function to work.
 * @note    Self test may fail if data memory and device are not on the same bus.
 *
 */
 
#endif // HDMI_TEXT_CONTROLLER_H
