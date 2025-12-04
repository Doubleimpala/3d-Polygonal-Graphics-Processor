module edge_eq_bb(
    input logic clk,
    input logic rst,

    //Triangle vertices.
    input logic [15:0] v1,
    input logic [15:0] v2,
    input logic [15:0] v3,

    //Handshaking signals.
    input logic edge_start,
    output logic edge_done,

    //Edge equation coefficients.
    //Need to be signed because the coefficients could be negative.
    output logic signed [8:0] a1,b1,
    output logic signed [8:0] a2,b2,
    output logic signed [8:0] a3,b3,
    
    //These require more bits bc they are products of 8 bit vertices.
    output logic signed [16:0] c1, c2, c3,

    //Bounding box dimensions.
    //X initial, 9 bit coordinate
    output logic [8:0] bbxi,
    //X final, 9 bit coordinate
    output logic [8:0] bbxf,
    //Y initial, 8 bit coordinate
    output logic [7:0] bbyi,
    //Y final, 8 bit coordinate
    output logic [7:0] bbyf
);

//Latch the inputs. Since v1, v2, v3 inputs technically COULD change between the start and when our final output is computed and some things in the design are combinational, we should use latched versions.
logic [15:0] v1_latched, v2_latched, v3_latched;
always_ff @(posedge clk) begin
    if(start) begin
        v1_latched <= v1;
        v2_latched <= v2;
        v3_latched <= v3;
    end
end

//Triangle vertices in x and y.
logic signed [7:0] v1x, v1y, v2x, v2y, v3x, v3y;
assign v1x = v1_latched[15:8];
assign v1y = v1_latched[7:0];
assign v2x = v2_latched[15:8];
assign v2y = v2_latched[7:0];
assign v3x = v3_latched[15:8];
assign v3y = v3_latched[7:0];

//Bounding box calculations.
//All combinational.
logic signed [7:0] temp1;
logic signed [7:0] temp2;
logic signed [7:0] temp3;
logic signed [7:0] temp4;
assign temp1 = (v1x < v2x) ? v1x : v2x;
assign bbxi = (temp1 < v3x) ? temp1 : v3x;

assign temp2 = (v1x > v2x) ? v1x : v2x;
assign bbxf = (temp2 > v3x) ? temp2 : v3x;

assign temp3 = (v1y < v2y) ? v1y : v2y;
assign bbyi = (temp3 < v3y) ? temp3 : v3y;

assign temp4 = (v1y > v2y) ? v1y : v2y;
assign bbyf = (temp4 > v3y) ? temp4 : v3y;


//Edge equation calculations.
//Edge(x,y) = A*x + B*y + C
//A = y1-y2 = delta y.
//B = x2-x1 = delta x. It's in this direction because that's how the math works out apparently. Ask the article I guess ¯\_(ツ)_/¯
//C = x1*y2 - x2*y1
//So if Edge(x,y) >= 0 then the pixel is inside. If all 3 edges are >= 0, then we should draw the pixel.

//Multiplications take multiple cycles. Apparently the best way to force the synthesis to use DSP slices for our multiplication is to add registers in the multiplication operation.
//We will therefore split this into 2 stages & therefore make it a 2 clock cycle process.

//Edge v1 to v2.
// a1 = v1y - v2y, Takes 1 clock cycle. We do it combinationally after latching the inputs.
// b1 = v2x - v1x, Takes 1 clock cycle. We do it combinationally after latching the inputs.
// c1 = v1x*v2y - v2x*v1y, Takes 2 clock cycles. We do it in 2 stages & handshake.

// Edge v2 to v3.
// a2 = v2y - v3y, Takes 1 clock cycle. We do it combinationally after latching the inputs.
// b2 = v3x - v2x, Takes 1 clock cycle. We do it combinationally after latching the inputs.
// c2 = v2x*v3y - v3x*v2y, Takes 2 clock cycles. We do it in 2 stages & handshake.

// Edge v3 to v1.
// a3 = v3y - v1y, Takes 1 clock cycle. We do it combinationally after latching the inputs.
// b3 = v1x - v3x, Takes 1 clock cycle. We do it combinationally after latching the inputs.
// c3 = v3x*v1y - v1x*v3y, Takes 2 clock cycles. We do it in 2 stages & handshake.


assign a1 = v1y - v2y;
assign b1 = v2x - v1x;

assign a2 = v2y - v3y;
assign b2 = v3x - v2x;

assign a3 = v3y - v1y;
assign b3 = v1x - v3x;

logic signed [15:0] prod1, prod2, prod3, prod4, prod5, prod6;
//Stage 1: We calculate A & B which are only additions. We also begin our multiplications, which if we use the DSP slices will be done in 1 cycle before the second stage.
always_ff @(posedge clk) begin
    prod1 <= v1x*v2y;
    prod2 <= v2x*v1y;
    prod3 <= v2x*v3y;
    prod4 <= v3x*v2y;
    prod5 <= v3x*v1y;
    prod6 <= v1x*v3y;
end

//Stage 2: Complete our calculations by performing the subtractions.
always_ff @(posedge clk) begin
    c1 <= prod1 - prod2;
    c2 <= prod3 - prod4;
    c3 <= prod5 - prod6;
end

logic ready_s1, ready_s2;
always_ff @(posedge clk) begin
    if(rst) begin
        ready_s1 <= 0;
        ready_s2 <= 0;
    end else begin
        ready_s1 <= edge_start;
        ready_s2 <= ready_s1;
    end
end
assign edge_done = ready_s2;
endmodule