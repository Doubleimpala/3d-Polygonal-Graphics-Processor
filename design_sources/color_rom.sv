module color_rom ( input [10:0]	addr,
				  output [7:0]	data
					 );

	parameter ADDR_WIDTH = 11;
	parameter DATA_WIDTH =  8;
				
	// ROM definition				
	// TODO: Fill in values, possibly 3-3-2 RGB
	parameter [0:2**ADDR_WIDTH-1][DATA_WIDTH-1:0] ROM = {};

	assign data = ROM[addr];

endmodule  
