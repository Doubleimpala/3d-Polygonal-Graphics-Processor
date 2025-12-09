/***************************** Include Files *******************************/
#include "hdmi_text_controller.h"
#include "sleep.h"
#include "stdio.h"
#include "stdlib.h"
#include "string.h"
#include <cstdlib>
#include <math.h>

// TODO: Maybe unroll and use restrict keyword
__inline__ void matmul4x4(const float in1[16], const float in2[16],
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
__inline__ void matvec4x1(const float mat[16], const float vec[4],
                          float *out_vec) {
  for (int mat_r = 0; mat_r < 4; mat_r++) {
    float dot = 0.0f;

    for (int mat_c = 0; mat_c < 4; mat_c++) {
      dot += mat[4 * mat_r + mat_c] * vec[mat_c];
    }

    out_vec[mat_r] = dot;
  }
}

// TODO: Have to store orientation of camera as well
int main() {
  // Yaw is rotation about vertical axis
  // TODO: Proper initialization values
  float cam_x = 127.5f, cam_y = 127.5f, cam_z = -50.0f;
  float yaw = 0; // in radians

  while (1) {
    // TODO: Keyboard or fpga button control for camera movement
    // TODO: Consider 16-bit fixed point format

    // Calculate Project @ View
    // One matmul and then one matvec mutiply per vertice

    // ===== VIEW MATRIX =====
    // View = Translate(-camera_pos) × RotateY(yaw)
    float cos_yaw = cosf(yaw);
    float sin_yaw = sinf(yaw);

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

    // TODO: Look into culling (frustram, backface, occlusion, etc.)
    for (int8_t i = 0; i < cornell_box_triangle_count; i++) {
      float world_vec1[4] = {(float)cornell_box[i][0], (float)cornell_box[i][1],
                             (float)cornell_box[i][2], 1.0f};

      float world_vec2[4] = {(float)cornell_box[i][3], (float)cornell_box[i][4],
                             (float)cornell_box[i][5], 1.0f};

      float world_vec3[4] = {(float)cornell_box[i][6], (float)cornell_box[i][7],
                             (float)cornell_box[i][8], 1.0f};

      // Backface Culling
      // Calculate two edges
      float edge1[3] = {world_vec2[0] - world_vec1[0],
                        world_vec2[1] - world_vec1[1],
                        world_vec2[2] - world_vec1[2]};

      float edge2[3] = {world_vec3[0] - world_vec1[0],
                        world_vec3[1] - world_vec1[1],
                        world_vec3[2] - world_vec1[2]};

      // Cross product to get normal
      float normal[3] = {edge1[1] * edge2[2] - edge1[2] * edge2[1],
                         edge1[2] * edge2[0] - edge1[0] * edge2[2],
                         edge1[0] * edge2[1] - edge1[1] * edge2[0]};

      // Vector from triangle to camera
      float to_camera[3] = {cam_x - world_vec1[0], cam_y - world_vec1[1],
                            cam_z - world_vec1[2]};

      // Dot product
      float dot = normal[0] * to_camera[0] + normal[1] * to_camera[1] +
                  normal[2] * to_camera[2];

      // Cull if facing away
      if (dot < 0.0f) {
        continue; // Skip this triangle
      }

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

      data->color = cornell_box[i][9];
      float *vecs[3] = {vec1, vec2, vec3};
      for (int i = 0; i < 3; i++) {
        // Perspective divide
        vecs[i][0] /= vecs[i][3];
        vecs[i][1] /= vecs[i][3];
        vecs[i][2] /= vecs[i][3];

        data->vertices[3 * i] = (uint16_t)((vecs[i][0] + 1.0f) * 160.0f);
        data->vertices[3 * i + 1] = (uint16_t)((1.0f - vecs[i][1]) * 120.0f);
        data->vertices[3 * i + 2] = (uint16_t)(vecs[i][2] * 255.0f);
      }

      int x1 = data->vertices[0];
      int y1 = data->vertices[1];
      int x2 = data->vertices[3];
      int y2 = data->vertices[4];
      int x3 = data->vertices[6];
      int y3 = data->vertices[7];

      float r_area = 2.0f / (x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2));
      data->r_area = (r_area < 0) ? -r_area : r_area;
    }
  }
}
