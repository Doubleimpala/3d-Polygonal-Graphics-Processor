#include <stdio.h>
#include "lw_usb/GenericMacros.h"
#include "lw_usb/GenericTypeDefs.h"
#include "lw_usb/MAX3421E.h"
#include "lw_usb/USB.h"
#include "lw_usb/usb_ch9.h"
#include "lw_usb/transfer.h"
#include "lw_usb/HID.h"

#include "xparameters.h"
#include <xgpio.h>

/***************************** Include Files *******************************/
#include "sleep.h"
#include "stdio.h"
#include "stdlib.h"
#include "string.h"
// #include <cstdlib>
// #include "math.h"
#include "platform.h"

#include "hdmi_text_controller.h"

extern HID_DEVICE hid_device;
static BYTE addr = 1; 				//hard-wired USB address
const char* const devclasses[] = { " Uninitialized", " HID Keyboard", " HID Mouse", " Mass storage" };

BYTE GetDriverandReport() {
	BYTE i;
	BYTE rcode;
	BYTE device = 0xFF;
	BYTE tmpbyte;

	DEV_RECORD* tpl_ptr;
	xil_printf("Reached USB_STATE_RUNNING (0x40)\n");
	for (i = 1; i < USB_NUMDEVICES; i++) {
		tpl_ptr = GetDevtable(i);
		if (tpl_ptr->epinfo != NULL) {
			xil_printf("Device: %d", i);
			xil_printf("%s \n", devclasses[tpl_ptr->devclass]);
			device = tpl_ptr->devclass;
		}
	}
	//Query rate and protocol
	rcode = XferGetIdle(addr, 0, hid_device.interface, 0, &tmpbyte);
	if (rcode) {   //error handling
		xil_printf("GetIdle Error. Error code: ");
		xil_printf("%x \n", rcode);
	} else {
		xil_printf("Update rate: ");
		xil_printf("%x \n", tmpbyte);
	}
	xil_printf("Protocol: ");
	rcode = XferGetProto(addr, 0, hid_device.interface, &tmpbyte);
	if (rcode) {   //error handling
		xil_printf("GetProto Error. Error code ");
		xil_printf("%x \n", rcode);
	} else {
		xil_printf("%d \n", tmpbyte);
	}
	return device;
}

void printHex (u32 data, unsigned channel)
{
//	XGpio_DiscreteWrite (&Gpio_hex, channel, data);
}

// TODO: Maybe unroll and use restrict keyword
void matmul4x4(const float in1[16], const float in2[16],
                          float out_mat[16]) {
  for (int r = 0; r < 4; r++) {
    for (int c = 0; c < 4; c++) {
      float dot = 0.0f;

      for (int k = 0; k < 4; k++) {
        dot += in1[4 * r + k] * in2[4 * k + c];
      }

      out_mat[4 * r + c] = dot;
    }
  }
}

// TODO: Unroll this?
void matvec4x1(const float mat[16], const float vec[4],
                          float *out_vec) {
  for (int mat_r = 0; mat_r < 4; mat_r++) {
    float dot = 0.0f;

    for (int mat_c = 0; mat_c < 4; mat_c++) {
      dot += mat[4 * mat_r + mat_c] * vec[mat_c];
    }

    out_vec[mat_r] = dot;
  }
}

float dir = 0.5;
float theta = 0.0f;
float r = 100.0f;

int main() {
	init_platform();
//	BYTE rcode;
//	BOOT_MOUSE_REPORT buf;		//USB mouse report
//	BOOT_KBD_REPORT kbdbuf;
//
//	BYTE runningdebugflag = 0;//flag to dump out a bunch of information when we first get to USB_STATE_RUNNING
//	BYTE errorflag = 0; //flag once we get an error device so we don't keep dumping out state info
//	BYTE device;

//	xil_printf("initializing MAX3421E...\n");
//	MAX3421E_init();
////	xil_printf("initializing USB...\n");
//	USB_init();

	//xil_printf("Entering main");
	float cam_x = 127.5f, cam_y = 127.5f, cam_z = -50.0f;
	float yaw = 0.0f; // in radians
	while(1)  {
//		if (cam_z >= 255.0f || cam_z <= -20.0f) dir *= -1;
//		cam_z += dir;
		cam_x = (r * cos_lookup(theta));
		cam_z = (r * sin_lookup(theta));
		yaw = (theta + (3.1415f / 2));
		theta += 0.001f;
		if (yaw >= (3.1415f) / 12 || yaw <= -3.1415f / 12) dir *= -1;
		yaw += dir;

		//Calculate Project @ View
		// One matmul and then one matvec mutiply per vertice
//		xil_printf("Top of loop \n");
		// ===== VIEW MATRIX =====
		// View = Translate(-camera_pos) × RotateY(yaw)
		float sin_yaw = sin_lookup(yaw);
		float cos_yaw = cos_lookup(yaw);


		// Pre-compute translation components

		float tx = -(cos_yaw * cam_x + sin_yaw * cam_z);
		float ty = -cam_y;
		float tz = -(-sin_yaw * cam_x + cos_yaw * cam_z);

		const float view_mat[16] = {cos_yaw, 0.0f, sin_yaw,  tx,   0.0f,    1.0f,
									0.0f,    ty,   -sin_yaw, 0.0f, cos_yaw, tz,
									0.0f,    0.0f, 0.0f,     1.0f};


		// ===== PROJECTION MATRIX (for [0, 1] depth) =====
		// Pre-computed for:
		// - FOV: 60 degrees
		// - Aspect ratio: 320/240 = 4/3
		// - Near plane: 1.0
		// - Far plane: 300.0 (to see entire Cornell box at z=0..255)
		//
		// Formula:
		// f = 1/tan(60°/2) = 1/tan(30°) ≈ 1.732
		// m[0][0] = f/aspect = 1.732 / (4/3) = 1.299
		// m[1][1] = f = 1.732
		// m[2][2] = far/(far-near) = 300/(300-1) ≈ 1.003
		// m[2][3] = -(far*near)/(far-near) = -300*1/299 ≈ -1.003
		// m[3][2] = 1.0 (for [0,1] depth, not -1.0)
		const float proj_mat[16] = {1.299f, 0.0f, 0.0f, 0.0f, 0.0f,   1.732f,
									0.0f,   0.0f, 0.0f, 0.0f, 1.003f, -1.003f,
									0.0f,   0.0f, 1.0f, 0.0f};

		float proj_view_mat[16];
		matmul4x4(proj_mat, view_mat, proj_view_mat);
		for (int i = 0; i < cornell_box_triangle_count; i++) {
			DATA data;

			float world_vec1[4] = {(float)cornell_box[i][0], (float)cornell_box[i][1],
								 (float)cornell_box[i][2], 1.0f};

			float world_vec2[4] = {(float)cornell_box[i][3], (float)cornell_box[i][4],
								 (float)cornell_box[i][5], 1.0f};

			float world_vec3[4] = {(float)cornell_box[i][6], (float)cornell_box[i][7],
								 (float)cornell_box[i][8], 1.0f};
			// Backface Culling
			// Calculate two edges
//			float edge1[3] = {world_vec2[0] - world_vec1[0],
//							world_vec2[1] - world_vec1[1],
//							world_vec2[2] - world_vec1[2]};
//
//			float edge2[3] = {world_vec3[0] - world_vec1[0],
//							world_vec3[1] - world_vec1[1],
//							world_vec3[2] - world_vec1[2]};
//
//			// Cross product to get normal
//			float normal[3] = {edge1[1] * edge2[2] - edge1[2] * edge2[1],
//							 edge1[2] * edge2[0] - edge1[0] * edge2[2],
//							 edge1[0] * edge2[1] - edge1[1] * edge2[0]};
//
//			// Vector from triangle to camera
//			float to_camera[3] = {cam_x - world_vec1[0], cam_y - world_vec1[1],
//								cam_z - world_vec1[2]};
//
//			// Dot product
//			float dot = normal[0] * to_camera[0] + normal[1] * to_camera[1] +
//					  normal[2] * to_camera[2];
//			// Cull if facing away
//			if (dot < 0.0f) {
//				continue; // Skip this triangle
//			}

			float vec1[4], vec2[4], vec3[4];

			// Transforms to clip space (before perspective divide)
			matvec4x1(proj_view_mat, world_vec1, vec1);
			matvec4x1(proj_view_mat, world_vec2, vec2);
			matvec4x1(proj_view_mat, world_vec3, vec3);

			// Test if ALL vertices are outside the SAME frustum plane
			int8_t all_left =
			  (vec1[0] < -vec1[3] && vec2[0] < -vec2[3] && vec3[0] < -vec3[3]);
			int8_t all_right =
			  (vec1[0] > vec1[3] && vec2[0] > vec2[3] && vec3[0] > vec3[3]);
			int8_t all_bottom =
			  (vec1[1] < -vec1[3] && vec2[1] < -vec2[3] && vec3[1] < -vec3[3]);
			int8_t all_top =
			  (vec1[1] > vec1[3] && vec2[1] > vec2[3] && vec3[1] > vec3[3]);
			int8_t all_near =
			  (vec1[2] < 0 && vec2[2] < 0 && vec3[2] < 0); // (behind camera)
			int8_t all_far =
			  (vec1[2] > vec1[3] && vec2[2] > vec2[3] && vec3[2] > vec3[3]);

			// Cull this triangle - completely outside frustum
			if (all_left || all_right || all_bottom || all_top || all_near || all_far)
				continue;

			// Check for degenerate w
			if (vec1[3] <= 0.0001f || vec2[3] <= 0.0001f || vec3[3] <= 0.0001f)
				continue;
			data.color = cornell_box[i][9];
			float *vecs[3] = {vec1, vec2, vec3};
			uint32_t x[3], y[3];
			for (int j = 0; j < 3; j++) {
				// Perspective divide
				vecs[j][0] /= vecs[j][3];
				vecs[j][1] /= vecs[j][3];
				vecs[j][2] /= vecs[j][3];

				x[j] = (uint32_t) ((vecs[j][0] + 1.0f) * 160.0f);
				y[j] = (uint32_t) ((1.0f - vecs[j][1]) * 120.0f);

				data.vertices[3 * j] = x[j];
				data.vertices[3 * j + 1] = y[j];
				data.vertices[3 * j + 2] = (uint16_t) (vecs[j][2] * 255.0f);
			}

			float r_area = 2.0f / (x[0] * (y[1] - y[2]) + x[1] * (y[2] - y[0]) + x[2] * (y[0] - y[1]));
			if (r_area < 0) r_area *= -1;

			// Turn into 8.24 fixed point
			data.r_area = (int32_t) (r_area * (1 << 24));

//			xil_printf("Start\n");
//			xil_printf("%d\n",(data.vertices[1] << 16) | data.vertices[0]);
//			xil_printf("%d\n",(data.vertices[3] << 16) | data.vertices[2]);
//			xil_printf("%d\n",(data.vertices[5] << 16) | data.vertices[4]);
//			xil_printf("%d\n",(data.vertices[7] << 16) | data.vertices[6]);
//			xil_printf("%d\n",(data.color << 16) | data.vertices[8]);
//			xil_printf("%d\n",data.r_area);
//			xil_printf("end\n");
//			addr[0] = (data.vertices[1] << 16) | data.vertices[0];
//			addr[1] = (data.vertices[3] << 16) | data.vertices[2];
//			addr[2] = (data.vertices[5] << 16) | data.vertices[4];
//			addr[3] = (data.vertices[7] << 16) | data.vertices[6];
//			//xil_printf("%d",addr);
//			addr[4] = (data.color << 16) | data.vertices[8];
//			addr[5] = data.r_area;


		  typedef struct {
			  uint32_t v0v1;      // Maps to lower 16 bits of addr[0]
			  uint32_t v2v3;      // Maps to lower 16 bits of addr[1]
			  uint32_t v4v5;      // Maps to upper 16 bits of addr[1]
			  uint32_t v6v7;      // Maps to lower 16 bits of addr[2]
			  uint32_t v8color;      // Maps to upper 16 bits of addr[3]
			  int32_t  r_area;  // Maps to addr[5]
//			  uint32_t done;
		  } TrianglePacket;

			  static volatile TrianglePacket *pkt = (TrianglePacket*)XPAR_HDMI_TEXT_CONTROLLER_0_AXI_BASEADDR;

			  pkt->v0v1 = (data.vertices[1] << 16) | data.vertices[0];
			  pkt->v2v3 = (data.vertices[3] << 16) | data.vertices[2];
			  pkt->v4v5 = (data.vertices[5] << 16) | data.vertices[4];
			  pkt->v6v7 = (data.vertices[7] << 16) | data.vertices[6];
			  pkt->v8color = (data.color << 16) | data.vertices[8];
			  pkt->r_area = data.r_area;
//			  pkt->done = 0xFFFFFFFF;
		}
	}
	cleanup_platform();
	return 0;
}

//int main()
//{
//    init_platform();   // initializes stdout (UART) and BSP drivers
//
//    xil_printf("Entering main\n");
//	float cam_x = 127.5f, cam_y = 127.5f, cam_z = -50.0f;
//	float yaw = 0; // in radians
//	//Xil_DCacheDisable();
//
//    xil_printf("Tests\n");
//    while(1) {
//		// Calculate Project @ View
//		// One matmul and then one matvec mutiply per vertice
//
//		// ===== VIEW MATRIX =====
//		// View = Translate(-camera_pos) × RotateY(yaw)
//		float cos_yaw = cos_lookup(yaw);
//		float sin_yaw = sin_lookup(yaw);
//
//		// Pre-compute translation components
//		float tx = -(cos_yaw * cam_x + sin_yaw * cam_z);
//		float ty = -cam_y;
//		float tz = -(-sin_yaw * cam_x + cos_yaw * cam_z);
//		const float view_mat[16] = {cos_yaw, 0.0f, sin_yaw,  tx,   0.0f,    1.0f,
//									0.0f,    ty,   -sin_yaw, 0.0f, cos_yaw, tz,
//									0.0f,    0.0f, 0.0f,     1.0f};
//		// ===== PROJECTION MATRIX (for [0, 1] depth) =====
//		// Pre-computed for:
//		// - FOV: 60 degrees
//		// - Aspect ratio: 320/240 = 4/3
//		// - Near plane: 1.0
//		// - Far plane: 300.0 (to see entire Cornell box at z=0..255)
//		//
//		// Formula:
//		// f = 1/tan(60°/2) = 1/tan(30°) ≈ 1.732
//		// m[0][0] = f/aspect = 1.732 / (4/3) = 1.299
//		// m[1][1] = f = 1.732
//		// m[2][2] = far/(far-near) = 300/(300-1) ≈ 1.003
//		// m[2][3] = -(far*near)/(far-near) = -300*1/299 ≈ -1.003
//		// m[3][2] = 1.0 (for [0,1] depth, not -1.0)
//		const float proj_mat[16] = {1.299f, 0.0f, 0.0f, 0.0f, 0.0f,   1.732f,
//									0.0f,   0.0f, 0.0f, 0.0f, 1.003f, -1.003f,
//									0.0f,   0.0f, 1.0f, 0.0f};
//
//		float proj_view_mat[16];
//		matmul4x4(proj_mat, view_mat, proj_view_mat);
//
//		//		// TODO: Look into culling (frustram, backface, occlusion, etc.)
//		for (int i = 0; i < cornell_box_triangle_count; i++) {
//			DATA data;
//
//			float world_vec1[4] = {(float)cornell_box[i][0], (float)cornell_box[i][1],
//								 (float)cornell_box[i][2], 1.0f};
//
//			float world_vec2[4] = {(float)cornell_box[i][3], (float)cornell_box[i][4],
//								 (float)cornell_box[i][5], 1.0f};
//
//			float world_vec3[4] = {(float)cornell_box[i][6], (float)cornell_box[i][7],
//								 (float)cornell_box[i][8], 1.0f};
//
//			// Backface Culling
//			// Calculate two edges
//			float edge1[3] = {world_vec2[0] - world_vec1[0],
//							world_vec2[1] - world_vec1[1],
//							world_vec2[2] - world_vec1[2]};
//
//			float edge2[3] = {world_vec3[0] - world_vec1[0],
//							world_vec3[1] - world_vec1[1],
//							world_vec3[2] - world_vec1[2]};
//
//			// Cross product to get normal
//			float normal[3] = {edge1[1] * edge2[2] - edge1[2] * edge2[1],
//							 edge1[2] * edge2[0] - edge1[0] * edge2[2],
//							 edge1[0] * edge2[1] - edge1[1] * edge2[0]};
//
//			// Vector from triangle to camera
//			float to_camera[3] = {cam_x - world_vec1[0], cam_y - world_vec1[1],
//								cam_z - world_vec1[2]};
//
//			// Dot product
//			float dot = normal[0] * to_camera[0] + normal[1] * to_camera[1] +
//					  normal[2] * to_camera[2];
//			// Cull if facing away
//			if (dot < 0.0f) {
//				continue; // Skip this triangle
//			}
//
//			float vec1[4], vec2[4], vec3[4];
//
//			// Transforms to clip space (before perspective divide)
//			matvec4x1(proj_view_mat, world_vec1, vec1);
//			matvec4x1(proj_view_mat, world_vec2, vec2);
//			matvec4x1(proj_view_mat, world_vec3, vec3);
//
//			// Test if ALL vertices are outside the SAME frustum plane
//			int8_t all_left =
//			  (vec1[0] < -vec1[3] && vec2[0] < -vec2[3] && vec3[0] < -vec3[3]);
//			int8_t all_right =
//			  (vec1[0] > vec1[3] && vec2[0] > vec2[3] && vec3[0] > vec3[3]);
//			int8_t all_bottom =
//			  (vec1[1] < -vec1[3] && vec2[1] < -vec2[3] && vec3[1] < -vec3[3]);
//			int8_t all_top =
//			  (vec1[1] > vec1[3] && vec2[1] > vec2[3] && vec3[1] > vec3[3]);
//			int8_t all_near =
//			  (vec1[2] < 0 && vec2[2] < 0 && vec3[2] < 0); // (behind camera)
//			int8_t all_far =
//			  (vec1[2] > vec1[3] && vec2[2] > vec2[3] && vec3[2] > vec3[3]);
//
//			// Cull this triangle - completely outside frustum
//			if (all_left || all_right || all_bottom || all_top || all_near || all_far)
//				continue;
//
//			// Check for degenerate w
//			if (vec1[3] <= 0.0001f || vec2[3] <= 0.0001f || vec3[3] <= 0.0001f)
//				continue;
//
//			data.color = cornell_box[i][9];
//			float *vecs[3] = {vec1, vec2, vec3};
//			uint32_t x[3], y[3];
//			for (int j = 0; j < 3; j++) {
//				// Perspective divide
//				vecs[j][0] /= vecs[j][3];
//				vecs[j][1] /= vecs[j][3];
//				vecs[j][2] /= vecs[j][3];
//
//				x[j] = (uint32_t) ((vecs[j][0] + 1.0f) * 160.0f);
//				y[j] = (uint32_t) ((1.0f - vecs[j][1]) * 120.0f);
//
//				data.vertices[3 * j] = x[j];
//				data.vertices[3 * j + 1] = y[j];
//				data.vertices[3 * j + 2] = (uint16_t) (vecs[j][2] * 255.0f);
//			}
//
//			float r_area = 2.0f / (x[0] * (y[1] - y[2]) + x[1] * (y[2] - y[0]) + x[2] * (y[0] - y[1]));
//			if (r_area < 0) r_area *= -1;
//
//			// Turn into 8.24 fixed point
//			data.r_area = (int32_t) (r_area * (1 << 24));
////
//			addr[0] = (data.vertices[1] << 16) | data.vertices[0];
//			addr[1] = (data.vertices[3] << 16) | data.vertices[2];
//			addr[2] = (data.vertices[5] << 16) | data.vertices[4];
//			addr[3] = (data.vertices[7] << 16) | data.vertices[6];
//			addr[4] = (data.color << 16) | data.vertices[8];
//			addr[5] = data.r_area;
//		}
//    }
//
//	cleanup_platform();
//	return 0;
//}













//
//    float cam_x = 127.5f, cam_y = 127.5f, cam_z = -50.0f;
//    float yaw = 0; // in radians
//
//    while(1) {
//		// TODO: Keyboard or fpga button control for camera movement
//		// TODO: Consider 16-bit fixed point format
//
//		// Calculate Project @ View
//		// One matmul and then one matvec mutiply per vertice
//
//		// ===== VIEW MATRIX =====
//		// View = Translate(-camera_pos) × RotateY(yaw)
//		float cos_yaw = cos_lookup(yaw);
//		float sin_yaw = sin_lookup(yaw);
//
//		// Pre-compute translation components
//		float tx = -(cos_yaw * cam_x + sin_yaw * cam_z);
//		float ty = -cam_y;
//		float tz = -(-sin_yaw * cam_x + cos_yaw * cam_z);
//		const float view_mat[16] = {cos_yaw, 0.0f, sin_yaw,  tx,   0.0f,    1.0f,
//									0.0f,    ty,   -sin_yaw, 0.0f, cos_yaw, tz,
//									0.0f,    0.0f, 0.0f,     1.0f};
//
//		// ===== PROJECTION MATRIX (for [0, 1] depth) =====
//		// Pre-computed for:
//		// - FOV: 60 degrees
//		// - Aspect ratio: 320/240 = 4/3
//		// - Near plane: 1.0
//		// - Far plane: 300.0 (to see entire Cornell box at z=0..255)
//		//
//		// Formula:
//		// f = 1/tan(60°/2) = 1/tan(30°) ≈ 1.732
//		// m[0][0] = f/aspect = 1.732 / (4/3) = 1.299
//		// m[1][1] = f = 1.732
//		// m[2][2] = far/(far-near) = 300/(300-1) ≈ 1.003
//		// m[2][3] = -(far*near)/(far-near) = -300*1/299 ≈ -1.003
//		// m[3][2] = 1.0 (for [0,1] depth, not -1.0)
//		const float proj_mat[16] = {1.299f, 0.0f, 0.0f, 0.0f, 0.0f,   1.732f,
//									0.0f,   0.0f, 0.0f, 0.0f, 1.003f, -1.003f,
//									0.0f,   0.0f, 1.0f, 0.0f};
//
//		float proj_view_mat[16];
//		matmul4x4(proj_mat, view_mat, proj_view_mat);
////		xil_printf("test\r\n");
////		sleep(1);
//		// TODO: Look into culling (frustram, backface, occlusion, etc.)
//		for (int8_t i = 0; i < cornell_box_triangle_count; i++) {
////		  DATA data;
//
//		  //if (!*vsync)
//		  //  break;
//
//		  float world_vec1[4] = {(float)cornell_box[i][0], (float)cornell_box[i][1],
//								 (float)cornell_box[i][2], 1.0f};
//
//		  float world_vec2[4] = {(float)cornell_box[i][3], (float)cornell_box[i][4],
//								 (float)cornell_box[i][5], 1.0f};
//
//		  float world_vec3[4] = {(float)cornell_box[i][6], (float)cornell_box[i][7],
//								 (float)cornell_box[i][8], 1.0f};
//
//		  // Backface Culling
//		  // Calculate two edges
//		  float edge1[3] = {world_vec2[0] - world_vec1[0],
//							world_vec2[1] - world_vec1[1],
//							world_vec2[2] - world_vec1[2]};
//
//		  float edge2[3] = {world_vec3[0] - world_vec1[0],
//							world_vec3[1] - world_vec1[1],
//							world_vec3[2] - world_vec1[2]};
//
//		  // Cross product to get normal
//		  float normal[3] = {edge1[1] * edge2[2] - edge1[2] * edge2[1],
//							 edge1[2] * edge2[0] - edge1[0] * edge2[2],
//							 edge1[0] * edge2[1] - edge1[1] * edge2[0]};
//
//		  // Vector from triangle to camera
//		  float to_camera[3] = {cam_x - world_vec1[0], cam_y - world_vec1[1],
//								cam_z - world_vec1[2]};
//
//		  // Dot product
//		  float dot = normal[0] * to_camera[0] + normal[1] * to_camera[1] +
//					  normal[2] * to_camera[2];
//
//		  // Cull if facing away
//		  if (dot < 0.0f) {
//			continue; // Skip this triangle
//		  }
//
//		  float vec1[4], vec2[4], vec3[4];
//
//		  // Transforms to clip space (before perspective divide)
//		  matvec4x1(proj_view_mat, world_vec1, vec1);
//		  matvec4x1(proj_view_mat, world_vec2, vec2);
//		  matvec4x1(proj_view_mat, world_vec3, vec3);
////
////		  // Test if ALL vertices are outside the SAME frustum plane
//		  int8_t all_left =
//			  (vec1[0] < -vec1[3] && vec2[0] < -vec2[3] && vec3[0] < -vec3[3]);
//		  int8_t all_right =
//			  (vec1[0] > vec1[3] && vec2[0] > vec2[3] && vec3[0] > vec3[3]);
//		  int8_t all_bottom =
//			  (vec1[1] < -vec1[3] && vec2[1] < -vec2[3] && vec3[1] < -vec3[3]);
//		  int8_t all_top =
//			  (vec1[1] > vec1[3] && vec2[1] > vec2[3] && vec3[1] > vec3[3]);
//		  int8_t all_near =
//			  (vec1[2] < 0 && vec2[2] < 0 && vec3[2] < 0); // (behind camera)
//		  int8_t all_far =
//			  (vec1[2] > vec1[3] && vec2[2] > vec2[3] && vec3[2] > vec3[3]);
//
//		  // Cull this triangle - completely outside frustum
//		  if (all_left || all_right || all_bottom || all_top || all_near || all_far)
//			continue;
//
//		  // Check for degenerate w
//		  if (vec1[3] <= 0.0001f || vec2[3] <= 0.0001f || vec3[3] <= 0.0001f)
//			continue;
//
//		  data.color = cornell_box[i][9];
//		  float *vecs[3] = {vec1, vec2, vec3};
//		  uint32_t x[3], y[3];
//		  for (int i = 0; i < 3; i++) {
//			// Perspective divide
//			vecs[i][0] /= vecs[i][3];
//			vecs[i][1] /= vecs[i][3];
//			vecs[i][2] /= vecs[i][3];
//
//			x[i] = (uint32_t) ((vecs[i][0] + 1.0f) * 160.0f);
//			y[i] = (uint32_t) ((1.0f - vecs[i][1]) * 120.0f);
//
//			data.vertices[3 * i] = x[i];
//			data.vertices[3 * i + 1] = y[i];
//			data.vertices[3 * i + 2] = (uint16_t) (vecs[i][2] * 255.0f);
//
////			xil_printf("V%d x: %u\r\n", i, data.vertices[3 * i]);
////			xil_printf("V%d y: %u\r\n", i, data.vertices[3 * i + 1]);
////			xil_printf("V%d z: %u\r\n", i, data.vertices[3 * i + 2]);
//		  }
//
////		  uint32_t x1 = data.vertices[0];
////		  uint32_t y1 = data.vertices[1];
////		  uint32_t x2 = data.vertices[3];
////		  uint32_t y2 = data.vertices[4];
////		  uint32_t x3 = data.vertices[6];
////		  uint32_t y3 = data.vertices[7];
////
//		  float r_area = 2.0f / (x[0] * (y[1] - y[2]) + x[1] * (y[2] - y[0]) + x[2] * (y[0] - y[1]));
//		  if (r_area < 0) r_area *= -1;
////
////		  // Turn into 8.24 fixed point
////		  data.r_area = (int32_t) r_area * (1 << 24);
//
//		  // Copy into AXI/FIFO, pack into 32 bit words to avoid write strobe
////		  memcpy(addr,(data.vertices[1] << 16) | data.vertices[0],32);
////		  *(addr-1) = 1;
////		  uint32_t * test = 0x05;
////		  *test = 1;
////		  addr[0] = (data.vertices[1] << 16) | data.vertices[0];
////		  addr[1] = (data.vertices[3] << 16) | data.vertices[2];
////		  addr[2] = (data.vertices[5] << 16) | data.vertices[4];
////		  addr[3] = (data.vertices[7] << 16) | data.vertices[6];
////		  addr[4] = (data.color << 16) | data.vertices[8];
////		  addr[5] = data.r_area;
//
////		  typedef struct __attribute__((packed)) {
////		      uint16_t v0;      // Maps to lower 16 bits of addr[0]
////		      uint16_t v1;      // Maps to upper 16 bits of addr[0]
////		      uint16_t v2;      // Maps to lower 16 bits of addr[1]
////		      uint16_t v3;      // Maps to upper 16 bits of addr[1]
////		      uint16_t v4;      // Maps to lower 16 bits of addr[2]
////		      uint16_t v5;      // Maps to upper 16 bits of addr[2]
////		      uint16_t v6;      // Maps to lower 16 bits of addr[3]
////		      uint16_t v7;      // Maps to upper 16 bits of addr[3]
////		      uint16_t v8;      // Maps to lower 16 bits of addr[4]
////		      uint8_t  color;   // Maps to bits 16-23 of addr[4]
////		      uint8_t  reserved; // Padding to keep next 32-bit aligned
////		      int32_t  r_area;  // Maps to addr[5]
////		  } TrianglePacket;
////
////		  TrianglePacket pkt;
////
////		  // Fill the packet (replaces your addr[0]...addr[5] logic)
////		  pkt.v0 = data.vertices[0];
////		  pkt.v1 = data.vertices[1];
////		  pkt.v2 = data.vertices[2];
////		  pkt.v3 = data.vertices[3];
////		  pkt.v4 = data.vertices[4];
////		  pkt.v5 = data.vertices[5];
////		  pkt.v6 = data.vertices[6];
////		  pkt.v7 = data.vertices[7];
////		  pkt.v8 = data.vertices[8];
////		  pkt.color = data.color;
////		  pkt.reserved = 0; // Ensure bits 24-31 of addr[4] are clean
////		  pkt.r_area = data.r_area;
////
////		  // Copy the entire packet to the AXI base address
////		  // addr is your (uint32_t ) XPAR_HDMI_TEXT_CONTROLLER_0_AXI_BASEADDR
////		  memcpy((void*)addr, &pkt, sizeof(TrianglePacket));
////		  xil_printf("Color: %d\r\n", data.color);
////		  xil_printf("Inverse area (hex): %X", data.r_area);
//
//		}
//
//		//while (*vsync);
//    }
//
//    cleanup_platform();
//    return 0;
//}
