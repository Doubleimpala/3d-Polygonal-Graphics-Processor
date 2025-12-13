module edge_eq_bb(
    input logic clk,
    input logic rst,

    //Triangle vertices.
    input logic [8:0] v1x_in, v2x_in, v3x_in,
    input logic [7:0] v1y_in, v2y_in, v3y_in,

    //Handshaking signals.
    input logic edge_start,
    output logic edge_done,

    //Edge equation coefficients.
    //Need to be signed because the coefficients could be negative.
    output logic signed [9:0] a1,b1,a2,b2,a3,b3,
    
    //These require more bits bc they are products of 8 bit vertices.
    output logic signed [17:0] c1, c2, c3,

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

//Triangle vertices in x and y.
logic [8:0] v1x, v2x, v3x;
logic [7:0] v1y, v2y, v3y;

//Latch the inputs. Since v1, v2, v3 inputs technically COULD change between the start and when our final output is computed and some things in the design are combinational, we should use latched versions.
always_ff @(posedge clk) begin
    if(edge_start) begin
        v1x <= v1x_in;
        v2x <= v2x_in;
        v3x <= v3x_in;
        v1y <= v1y_in;
        v2y <= v2y_in;
        v3y <= v3y_in;
    end
end


//Bounding box calculations.
//All combinational.
logic [8:0] temp1;
logic [8:0] temp2;
logic [7:0] temp3;
logic [7:0] temp4;
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
//B = x2-x1 = delta x. It's in this direction because that's how the math works out apparently. Ask the stack overflow I guess.
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

logic signed [16:0] prod1, prod2, prod3, prod4, prod5, prod6;
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