module //# (
    //Number of points we're going to be projecting.
    //Points instead of triangles since we need have already finished zbuffering before using this module in the pipeline.
//     parameter integer POINT_NUM = 1,
// )
(
    input logic clk,
    input logic rst,
    //Input point is 3d, so represented with 3 bytes.
    input logic [23:0] p_in,//[POINT_NUM],
    input logic [7:0] canvas_dist, // Distance from 0,0 in the z dimension
    //Output point is 2d, so represented with 2 bytes.
    output logic [15:0] p_out,//[POINT_NUM],
);

// integer i;
// for(i = 0; i < POINT_NUM; i++) begin
//     points_in[i];
// end


//Division module operation
always_ff @(posedge clk) begin

end

endmodule