
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <string.h>

// Screen dimensions
#define SCREEN_WIDTH 320
#define SCREEN_HEIGHT 240

// Cornell Box mesh data
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

// Framebuffer (ASCII art representation)
char framebuffer[SCREEN_HEIGHT][SCREEN_WIDTH];

// Matrix and vector math
void matmul4x4(const float in1[16], const float in2[16], float out[16]) {
    for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 4; c++) {
            float dot = 0.0f;
            for (int k = 0; k < 4; k++) {
                dot += in1[4 * r + k] * in2[4 * k + c];
            }
            out[4 * r + c] = dot;
        }
    }
}

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

// Clear framebuffer
void clear_framebuffer() {
    for (int y = 0; y < SCREEN_HEIGHT; y++) {
        for (int x = 0; x < SCREEN_WIDTH; x++) {
            framebuffer[y][x] = ' ';
        }
    }
}

// Draw a pixel (ASCII art)
void draw_pixel(int x, int y, char c) {
    if (x >= 0 && x < SCREEN_WIDTH && y >= 0 && y < SCREEN_HEIGHT) {
        framebuffer[y][x] = c;
    }
}

// Simple line drawing (Bresenham)
void draw_line(int x0, int y0, int x1, int y1, char c) {
    int dx = abs(x1 - x0);
    int dy = abs(y1 - y0);
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx - dy;
    
    while (1) {
        draw_pixel(x0, y0, c);
        if (x0 == x1 && y0 == y1) break;
        int e2 = 2 * err;
        if (e2 > -dy) { err -= dy; x0 += sx; }
        if (e2 < dx) { err += dx; y0 += sy; }
    }
}

// Draw wireframe triangle
void draw_triangle(int x1, int y1, int x2, int y2, int x3, int y3, uint8_t color) {
    // Determine character based on color
    char c = '.';
    if (color == 0xE0) c = 'R';      // Red
    else if (color == 0x1C) c = 'G'; // Green
    else c = '*';                     // White
    
    draw_line(x1, y1, x2, y2, c);
    draw_line(x2, y2, x3, y3, c);
    draw_line(x3, y3, x1, y1, c);
}

// Display framebuffer (scaled down for terminal)
void display_framebuffer() {
    printf("\033[2J\033[H");  // Clear screen and move cursor to top
    
    // Display every 4th row and 2nd column (80x60 roughly fits terminal)
    for (int y = 0; y < SCREEN_HEIGHT; y += 4) {
        for (int x = 0; x < SCREEN_WIDTH; x += 2) {
            putchar(framebuffer[y][x]);
        }
        putchar('\n');
    }
}

// Save as PPM image
void save_ppm(const char* filename) {
    FILE* f = fopen(filename, "wb");
    fprintf(f, "P6\n%d %d\n255\n", SCREEN_WIDTH, SCREEN_HEIGHT);
    
    for (int y = 0; y < SCREEN_HEIGHT; y++) {
        for (int x = 0; x < SCREEN_WIDTH; x++) {
            char c = framebuffer[y][x];
            uint8_t r = 0, g = 0, b = 0;
            
            if (c == 'R') { r = 255; }        // Red
            else if (c == 'G') { g = 255; }   // Green
            else if (c != ' ') { r = g = b = 200; }  // White/gray
            
            fputc(r, f); fputc(g, f); fputc(b, f);
        }
    }
    fclose(f);
    printf("Saved to %s\n", filename);
}

int main() {
    // Camera parameters
    float cam_x = 127.5f, cam_y = 127.5f, cam_z = -20.0f;
    float yaw = 3.1415f / 12;
    
    printf("3D Renderer Test\n");
    printf("================\n");
    printf("Camera: (%.1f, %.1f, %.1f), Yaw: %.2f rad\n\n", cam_x, cam_y, cam_z, yaw);
    
    // View matrix
    float cos_yaw = cosf(yaw);
    float sin_yaw = sinf(yaw);
    float tx = -(cos_yaw * cam_x + sin_yaw * cam_z);
    float ty = -cam_y;
    float tz = -(-sin_yaw * cam_x + cos_yaw * cam_z);
    
    const float view_mat[16] = {
        cos_yaw,  0.0f, sin_yaw, tx,
        0.0f,     1.0f, 0.0f,    ty,
        -sin_yaw, 0.0f, cos_yaw, tz,
        0.0f,     0.0f, 0.0f,    1.0f
    };
    
    // Projection matrix (60° FOV, 4:3 aspect, near=1, far=300)
    const float proj_mat[16] = {
        1.299f,  0.0f,   0.0f,    0.0f,
        0.0f,    1.732f, 0.0f,    0.0f,
        0.0f,    0.0f,   1.003f, -1.003f,
        0.0f,    0.0f,   1.0f,    0.0f
    };
    
    // Combined MVP
    float mvp[16];
    matmul4x4(proj_mat, view_mat, mvp);
    
    // Clear framebuffer
    clear_framebuffer();
    
    // Render statistics
    int triangles_rendered = 0;
    int triangles_culled = 0;
    
    // Process each triangle
    for (int i = 0; i < cornell_box_triangle_count; i++) {
        // World space vertices
        float world_v1[4] = {(float)cornell_box[i][0], (float)cornell_box[i][1], 
                             (float)cornell_box[i][2], 1.0f};
        float world_v2[4] = {(float)cornell_box[i][3], (float)cornell_box[i][4], 
                             (float)cornell_box[i][5], 1.0f};
        float world_v3[4] = {(float)cornell_box[i][6], (float)cornell_box[i][7], 
                             (float)cornell_box[i][8], 1.0f};
        // Calculate two edges
        // float edge1[3] = {world_v2[0] - world_v1[0], world_v2[1] - world_v1[1],
        //                   world_v2[2] - world_v1[2]};

        // float edge2[3] = {world_v3[0] - world_v1[0], world_v3[1] - world_v1[1],
        //                   world_v3[2] - world_v1[2]};

        // // Cross product to get normal
        // float normal[3] = {edge1[1] * edge2[2] - edge1[2] * edge2[1],
        //                    edge1[2] * edge2[0] - edge1[0] * edge2[2],
        //                    edge1[0] * edge2[1] - edge1[1] * edge2[0]};

        // // Vector from triangle to camera
        // float to_camera[3] = {cam_x - world_v1[0], cam_y - world_v1[1],
        //                       cam_z - world_v1[2]};

        // // Dot product
        // float dot = normal[0] * to_camera[0] + normal[1] * to_camera[1] +
        //             normal[2] * to_camera[2];

        // // Cull if facing away
        // if (dot > 0.0f) {
        //   continue; // Skip this triangle
        // }
        // Transform to clip space
        float clip1[4], clip2[4], clip3[4];
        matvec4x1(mvp, world_v1, clip1);
        matvec4x1(mvp, world_v2, clip2);
        matvec4x1(mvp, world_v3, clip3);
        
        // Frustum culling
        int all_left   = (clip1[0] < -clip1[3] && clip2[0] < -clip2[3] && clip3[0] < -clip3[3]);
        int all_right  = (clip1[0] >  clip1[3] && clip2[0] >  clip2[3] && clip3[0] >  clip3[3]);
        int all_bottom = (clip1[1] < -clip1[3] && clip2[1] < -clip2[3] && clip3[1] < -clip3[3]);
        int all_top    = (clip1[1] >  clip1[3] && clip2[1] >  clip2[3] && clip3[1] >  clip3[3]);
        int all_near   = (clip1[2] < 0 && clip2[2] < 0 && clip3[2] < 0);
        int all_far    = (clip1[2] > clip1[3] && clip2[2] > clip2[3] && clip3[2] > clip3[3]);
        
        if (all_left || all_right || all_bottom || all_top || all_near || all_far) {
            triangles_culled++;
            continue;
        }
        
        // Check for degenerate w
        if (clip1[3] <= 0.0001f || clip2[3] <= 0.0001f || clip3[3] <= 0.0001f) {
            triangles_culled++;
            continue;
        }
        
        // Perspective divide
        float x1_ndc = clip1[0] / clip1[3];
        float y1_ndc = clip1[1] / clip1[3];
        float x2_ndc = clip2[0] / clip2[3];
        float y2_ndc = clip2[1] / clip2[3];
        float x3_ndc = clip3[0] / clip3[3];
        float y3_ndc = clip3[1] / clip3[3];
        
        // Convert to screen coordinates
        int x1_screen = (int)((x1_ndc + 1.0f) * 160.0f);
        int y1_screen = (int)((1.0f - y1_ndc) * 120.0f);
        int x2_screen = (int)((x2_ndc + 1.0f) * 160.0f);
        int y2_screen = (int)((1.0f - y2_ndc) * 120.0f);
        int x3_screen = (int)((x3_ndc + 1.0f) * 160.0f);
        int y3_screen = (int)((1.0f - y3_ndc) * 120.0f);
        
        // Draw triangle
        uint8_t color = cornell_box[i][9];
        draw_triangle(x1_screen, y1_screen, x2_screen, y2_screen, 
                     x3_screen, y3_screen, color);
        
        triangles_rendered++;
    }
    
    // Display results
    display_framebuffer();
    
    printf("\nStatistics:\n");
    printf("  Triangles rendered: %d\n", triangles_rendered);
    printf("  Triangles culled: %d\n", triangles_culled);
    printf("  Total triangles: %d\n", cornell_box_triangle_count);
    
    // Save to image file
    save_ppm("output.ppm");
    
    return 0;
}
