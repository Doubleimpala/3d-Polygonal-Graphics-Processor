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

//Pixel positions
logic [8:0] x;
logic [7:0] y;

//Edge Equation Products
logic signed [17:0] prod1; // 9 bit * 9 bit
logic signed [16:0] prod2; // 9 bit * 8 bit
logic signed [17:0] prod3;
logic signed [16:0] prod4;
logic signed [17:0] prod5;
logic signed [16:0] prod6;

//Edge equations
logic signed [17:0] e1;
logic signed [17:0] e2;
logic signed [17:0] e3;

//Edge equations stored per row.
logic signed [17:0] e1_row;
logic signed [17:0] e2_row;
logic signed [17:0] e3_row;

//Barycentric weights for zbuffer.
logic signed [31:0] w1,w2, w3;




enum logic [3:0] {
    halt,
    edge_prods,
    edge_eqs,
    row_setup,
    barycentric,
    comp_z,
    buf_addressing,
    write,
    col_inc,
    row_inc,
    done
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
                end
            end
            edge_prods: begin
                prod1 <= a1 * bbxi;
                prod2 <= b1 * bbyi;
                prod3 <= a2 * bbxi;
                prod4 <= b2 * bbyi;
                prod5 <= a3 * bbxi;
                prod6 <= b3 * bbyi;
            end
            edge_eqs: begin
                e1 <= prod1 + prod2 + c1;
                e2 <= prod3 + prod4 + c2;
                e3 <= prod5 + prod6 + c3;
            end
            row_setup: begin
                e1_row <= e1;
                e2_row <= e2;
                e3_row <= e3;
            end
            barycentric: begin
                
            end
            comp_z: begin
                
            end
            buf_addressing: begin
                
            end
            write: begin
                
            end
            col_inc: begin
                if(x == bbxf) begin
                    x <= 
                end else begin
                    x <= x+1;
                    e1_row <= e1_row + a1;
                    e2_row <= e2_row + a2;
                    e3_row <= e3_row + a3;
                    state <= barycentric;
                end
            end
            row_inc: begin
                if(y == bbyf) begin
                    rasterizer_done <= 1;
                    state <= halt;
                end else begin
                    e1 <= e1 + b1;
                    e2 <= e2 + b2;
                    e3 <= e3 + b3;
                    state <= row_setup;
                end
            end
            done: begin
                
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
