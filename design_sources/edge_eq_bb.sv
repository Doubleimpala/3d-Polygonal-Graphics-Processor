module edge_eq_bb(
    input logic clk,
    // input logic rst,

    //Triangle vertices.
    input logic [15:0] v1,
    input logic [15:0] v2,
    input logic [15:0] v3,

    //Handshaking signals.
    input logic edge_input_ready,
    output logic edge_output_ready,

    //Edge equation coefficients.
    //Edge(x,y) = A(cross)x + B(cross)y + C
    //A = y1-y2 = delta y.
    //B = x2-x1
    output logic a1,
    output logic b1,
    output logic c1,
    output logic a2,
    output logic b2,
    output logic c2,
    output logic a3,
    output logic b3,
    output logic c3,

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
logic v1x = v1[15:8];
logic v1y = v1[7:0];
logic v2x = v2[15:8];
logic v2y = v2[7:0];
logic v3x = v3[15:8];
logic v3y = v3[7:0];

//Bounding box calculations.
assign bbxi = min3(v1x,v2x,v3x);
assign bbxf= max3(v1x,v2x,v3x);
assign bbyi = min3(v1y,v2y,v3y);
assign bbyf= max3(v1y,v2y,v3y);



//Edge equation calculations.


endmodule