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

//Set default ports.
assign vram_clka = clk;
assign vram_clkb = clk;
assign ena = 'b1;
assign enb = 'b1;
// Port A always writes, port B always reads
assign wea = 'b1;
assign web = 'b0;

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

//PART 1: Setup with the single multiplication for the whole triangle. 2 states. Need to use pipeline registers for DSP multiplication.

//Stage #1
//Inputs: a1, a2, a3, b1, b2, b3, bbxi, bbyi
//Outputs:
logic [17:0] prod1; // 9 bit * 9 bit
logic [16:0] prod2; // 9 bit * 8 bit
logic [17:0] prod3;
logic [16:0] prod4;
logic [17:0] prod5;
logic [16:0] prod6;
always_ff @(posedge clk) begin
    prod1 <= a1 * bbxi;
    prod2 <= b1 * bbyi;
    prod3 <= a2 * bbxi;
    prod4 <= b2 * bbyi;
    prod5 <= a3 * bbxi;
    prod6 <= b3 * bbyi;
end

//Stage #2
//Inputs: prod1, prod2,... prod6, c1, c2, c3,
//Outputs:
logic [17:0] e1;
logic [17:0] e2;
logic [17:0] e3;
always_ff @(posedge clk) begin
    e1 <= prod1 + prod2 + c1;
    e2 <= prod3 + prod4 + c2;
    e3 <= prod5 + prod6 + c3;
end

//Part 2: Loop
//Stage #3
//Inputs: e1, e2, e3
//Outputs:
logic [17:0] e1_row_stage2;
logic [17:0] e2_row_stage2;
logic [17:0] e3_row_stage2;
always_ff @(posedge clk) begin
    e1_row_stage2 <= e1;
    e2_row_stage2 <= e2;
    e3_row_stage2 <= e3;
end

//Stage #4
//Inputs: e1_row_stage2, e2_row_stage2, e3_row_stage2, a1, a2, a3
//Outputs: write_enable_gpu, data_in_gpu, addr_gpu
logic [17:0] e1_row_stage3;
logic [17:0] e2_row_stage3;
logic [17:0] e3_row_stage3;
always_ff @(posedge clk) begin
    if(e1_row >= 0 && e2_row >= 0 && e3_row >= 0) begin
        //Zbuffer work. Should I color or not?
        //if I should color:...
    end
    e1_row <= e1_row + a1;
    e2_row <= e2_row + a2;
    e3_row <= e3_row + a3;
end

//Stage #5
//Inputs: e1, e2, e3, b1, b2, b3
//Outputs: e1, e2, e3

always_ff @(posedge clk) begin
    e1 <= e1 + b1;
    e2 <= e2 + b2;
    e3 <= e3 + b3;
end

//Pipeline Controller
logic stage1, stage2, stage3, stage4_1, stage4_2, stage4_3, stage5;
always_ff @(posedge clk) begin
    if(rst) begin
        stage1 <= 0;
        stage2 <= 0;
        stage3 <= 0;
        stage4_1 <= 0;
        stage4_2 <= 0;
        stage4_3 <= 0;
        stage5 <= 0;
    end else begin
        stage1 <= rasterizer_start;
        stage2 <= stage1;
        stage3 <= stage2;
        stage4_1 <= stage3;
        stage4_2 <= stage4_1;
        stage4_3 <= stage4_2;
        stage5 <= stage4_3;
        rasterizer_done <= stage_5;
    end
end



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
