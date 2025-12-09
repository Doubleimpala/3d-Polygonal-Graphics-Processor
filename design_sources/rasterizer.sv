// Z-buffer is per pixel, only part of triangle may be drawn
// z here is z in screen space (microblaze gives this)
// https://www.scratchapixel.com/lessons/3d-basic-rendering/rasterization-practical-implementation/visibility-problem-depth-buffer-depth-interpolation.html
module rasterizer(
    input logic clk,
    input logic rst,
    //Inverse area of the triangle from the microblaze.
    input logic [31:0] inv_area,

    //Color of triangle
    input logic [7:0] color,

    //Edge equation coefficients
    input logic signed [8:0] a1, b1, a2, b2, a3, b3,
    input logic signed [17:0] c1, c2, c3,
    //Bounding box
    input logic [8:0] bbxi,
    input logic [8:0] bbxf,
    input logic [7:0] bbyi,
    input logic [7:0] bbyf,

    // Vertex Z coordinates
    input logic [15:0] z1, z2, z3,

    //Rasterizer handshaking signals
    input logic rasterizer_start,
    output logic rasterizer_done,
    
    //Frame buffer memory signals
    output logic write_enable_gpu,
    output logic [7:0] data_in_gpu,
    output logic [16:0] addr_gpu
);

//Zbuffer signals
logic [7:0] zbuf_dout;
logic [16:0] zbuf_addr;
logic [7:0] zbuf_din;
logic zbuf_we;
logic zbuf_en;
assign zbuf_en = 1;

//https://stackoverflow.com/questions/2049582/how-to-determine-if-a-point-is-in-a-2d-triangle
//Very cool stack overflow post saved me from a lot of work!
//But also we can increment to save computation in hardware instead of recomputing for every pixel.

//Pseudocode that we implement.
//Calculate E1, E2, E3 a single time.
//Edge(x,y) = A*x + B*y + C
/*
PART 1:
E1 = a1*bbxi + b1*bbyi + c1
E2 = a2*bbxi + b2*bbyi + c2
E3 = a3*bbxi + b3*bbyi + c3

PART 2:
for(integer y = bbyi; y <= bbyf; y++) begin
    E1_row = E1;
    E2_row = E2;
    E3_row = E3;
    for(integer x = bbxi; x <= bbxf; x++) begin
        if(E1_row >= 0 && E2_row >= 0 && E3_row >= 0): CHECK ZBUFFER & Write color.
        E1_row += a1;
        E2_row += a2;
        E3_row += a3;
    end
    E1 += b1;
    E2 += b2;
    E3 += b3;
end
*/

//Pixel positions
logic [8:0] x;
logic [7:0] y;

//Edge Equation Products
logic signed [18:0] prod1; // 9 bit * 9 bit
logic signed [17:0] prod2; // 9 bit * 8 bit
logic signed [18:0] prod3;
logic signed [17:0] prod4;
logic signed [18:0] prod5;
logic signed [17:0] prod6;


//Edge equations
logic signed [20:0] e1;
logic signed [20:0] e2;
logic signed [20:0] e3;

//Edge equations stored per row.
logic signed [20:0] e1_row;
logic signed [20:0] e2_row;
logic signed [20:0] e3_row;

//Barycentric weights for zbuffer.
logic signed [52:0] w1_raw, w2_raw, w3_raw;
logic signed [28:0] w1,w2, w3;

//Barycentric/z interpolation products.
logic signed [44:0] prod7;
logic signed [44:0] prod8;
logic signed [44:0] prod9;

//Interpolated Z calculations. We only store "z" in the buffer which is the shifted version of "z_calc"
logic signed [45:0] z_calc;
logic [7:0] z;


enum logic [4:0] {
    halt,
    edge_prods,
    edge_prods_wait
    edge_eqs,
    row_setup,
    inside_check,
    barycentric,
    barycentric_wait,
    barycentric_normalize,
    comp_z_prods,
    comp_z_wait,
    comp_z,
    buf_addressing,
    read_zbuf,
    write,
    col_inc,
    row_inc
} state;


always_ff @(posedge clk) begin
    if(rst) begin
        state <= halt;
        rasterizer_done <= 0;
    end else begin
        case(state)
            halt: begin
                rasterizer_done <= 0;
                if(rasterizer_start) begin
                    state <= edge_prods;
                    x <= bbxi;
                    y <= bbyi;
                end
            end
            edge_prods: begin
                prod1 <= $signed(a1) * $signed({1'b0, bbxi});
                prod2 <= $signed(b1) * $signed({1'b0, bbyi});
                prod3 <= $signed(a2) * $signed({1'b0, bbxi});
                prod4 <= $signed(b2) * $signed({1'b0, bbyi});
                prod5 <= $signed(a3) * $signed({1'b0, bbxi});
                prod6 <= $signed(b3) * $signed({1'b0, bbyi});
                state <= edge_prods_wait;
            end
            edge_prods_wait: begin
                state <= edge_eqs;   // allow multipliers to update prod1..prod6
            end
            edge_eqs: begin
                e1 <= $signed(prod1) + $signed(prod2) + $signed(c1);
                e2 <= $signed(prod3) + $signed(prod4) + $signed(c2);
                e3 <= $signed(prod5) + $signed(prod6) + $signed(c3);
                state <= row_setup;
            end
            row_setup: begin
                x <= bbxi;
                e1_row <= e1;
                e2_row <= e2;
                e3_row <= e3;
                state <= inside_check;
            end
            inside_check: begin
                //Should it be like this or 1 clock cycle delayed by calculating inside first and then checking for inside?
                if(e1_row >= 0 && e2_row >= 0 && e3_row >= 0) begin
                    state <= barycentric;
                end else begin
                    state <= col_inc;
                end
            end
            barycentric: begin
                w1_raw <= $signed(e1_row) * $signed(inv_area);
                w2_raw <= $signed(e2_row) * $signed(inv_area);
                w3_raw <= $signed(e3_row) * $signed(inv_area);
                state <= barycentric_wait;
            end
            barycentric_wait: begin
                state <= barycentric_normalize;
            end
            barycentric_normalize: begin
                w1 <= w1_raw >>> 24;
                w2 <= w2_raw >>> 24;
                w3 <= w3_raw >>> 24;
                state <= comp_z_prods;
            end
            comp_z_prods: begin
                prod7 <= w1 * $signed({1'b0, z1});
                prod8 <= w2 * $signed({1'b0, z2});
                prod9 <= w3 * $signed({1'b0, z3});
                state <= comp_z_wait;
            end
            comp_z_wait: begin
                state <= comp_z;
            end
            comp_z: begin
                z_calc <= prod7 + prod8 + prod9;
                state <= buf_addressing;
            end
            buf_addressing: begin
                z <= z_calc[44:37];
                zbuf_addr <= y*320 + x;
                addr_gpu <= y*320 + x;
                state <= read_zbuf;
            end
            read_zbuf: begin
                // Wait 1 cycle for BRAM to respond
                state <= write;  // Now zbuf_dout is valid
            end
            write: begin
                if(z < zbuf_dout) begin
                    zbuf_we <= 1;
                    zbuf_din <= z;

                    write_enable_gpu <= 1;
                    data_in_gpu <= color;
                end else begin
                    zbuf_we <= 0;
                    write_enable_gpu <= 0;
                end
                state <= col_inc;
            end
            col_inc: begin
                zbuf_we <= 0;
                write_enable_gpu <= 0;
                if(x == bbxf) begin
                    state <= row_inc;
                end else begin
                    x <= x+1;
                    e1_row <= e1_row + a1;
                    e2_row <= e2_row + a2;
                    e3_row <= e3_row + a3;
                    state <= inside_check;
                end
            end
            row_inc: begin
                if(y == bbyf) begin
                    rasterizer_done <= 1;
                    state <= halt;
                end else begin
                    y <= y+1;
                    e1 <= e1 + b1;
                    e2 <= e2 + b2;
                    e3 <= e3 + b3;
                    state <= row_setup;
                end
            end
        endcase
    end
end

// 320 * 240 * 1 B = 76.8 kB
// width: 8 bits
// Make sure to initialize each cell to the maximum integer
// This can either be done once on initialization through vivado
// with a .mif or .coe file
// OR
// make our own reset logic
// & also make it single port.
blk_mem_gen_1 z_buf(
    .clka(clk),
    .addra(zbuf_addr),
    .dina(zbuf_din),
    .douta(zbuf_dout),
    .wea(zbuf_we),
    .ena(zbuf_en)
);
endmodule