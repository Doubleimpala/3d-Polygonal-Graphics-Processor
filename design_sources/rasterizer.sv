// Z-buffer is per pixel, only part of triangle may be drawn
// z here is z in screen space (microblaze gives this)
// https://www.scratchapixel.com/lessons/3d-basic-rendering/rasterization-practical-implementation/visibility-problem-depth-buffer-depth-interpolation.html
module rasterizer(
    input logic clk,
    //Inverse area of the triangle from the microblaze.
    input logic [31:0] inv_area,

    //Edge equation coefficients
    input logic [8:0] a1, b1, a2, b2, a3, b3;
    input logic [15:0] c1, c2, c3;
    //Bounding box
    input logic [8:0] bbxi,
    input logic [8:0] bbxf,
    input logic [7:0] bbyi,
    input logic [7:0] bbyf,


    //Rasterizer handshaking signals
    input logic rasterizer_start,
    output logic rasterizer_done,
    
    //Frame buffer memory signals
    output logic write_enable_gpu,
    output logic [7:0] data_in_gpu,
    output logic [16:0] addr_gpu
);

logic vram_clka;
logic vram_clkb;
logic ena;
logic enb;
logic [3:0] wea;
logic [3:0] web;
logic [19:0] addra;
logic [19:0] addrb;
logic [7:0] dina; // 9 bits???
logic [7:0] dinb;
logic [7:0] douta;
logic [7:0] doutb; 

assign vram_clka = clk;
assign vram_clkb = clk;
assign ena = 'b1;
assign enb = 'b1;
// Port A always writes, port B always reads
assign wea = 'b1;
assign web = 'b0;

// 320 * 240 * 1 B = 76.8 kB
// width: 8 bits
// Make sure to initialize each cell to the maximum integer
// This can either be done once on initialization through vivado
// with a .mif or .coe file
// OR
// make our own reset logic
blk_mem_gen_0 z_buf(
    .clka(vram_clka),
    .clkb(vram_clkb),
    .*
);

// Assumes that memory writes in second half of cycle (after read)
assign addrb = draw_y * 320 + draw_x;
assign addra = addrb;

assign draw = z < douta;
assign dina = draw ? z : douta;

endmodule
