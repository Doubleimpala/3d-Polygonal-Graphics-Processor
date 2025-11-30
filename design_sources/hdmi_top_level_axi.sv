//`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: ECE-Illinois
// Engineer: Zuofu Cheng
// 
// Create Date: 06/08/2023 12:21:05 PM
// Design Name: 
// Module Name: hdmi_text_controller_v1_0_AXI
// Project Name: ECE 385 - hdmi_text_controller
// Target Devices: 
// Tool Versions: 
// Description: 
// This is a modified version of the Vivado template for an AXI4-Lite peripheral,
// rewritten into SystemVerilog for use with ECE 385.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.02 - File modified to be more consistent with generated template
// Revision 11/18 - Made comments less confusing
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1 ns / 1 ps

module hdmi_text_controller_v1_0_AXI #
(

    // Parameters of Axi Slave Bus Interface S_AXI
    // Modify parameters as necessary for access of full VRAM range

    // Width of S_AXI data bus
    parameter integer C_S_AXI_DATA_WIDTH	= 32,
    // Width of S_AXI address bus
    parameter integer C_S_AXI_ADDR_WIDTH	= 14
)
(
    // Users to add ports here
    input logic vsync,
    input logic [9:0] drawX,
    input logic [9:0] drawY,
    
    output logic [11:0] font_rom_addr,
    input logic [7:0] font_rom_data,
    
    output logic [3:0] red, green, blue,
    

    // User ports ends

    // Global Clock Signal
    input logic  S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input logic  S_AXI_ARESETN,
    // Write address (issued by master, acceped by Slave)
    input logic [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    // Write channel Protection type. This signal indicates the
        // privilege and security level of the transaction, and whether
        // the transaction is a data access or an instruction access.
    input logic [2 : 0] S_AXI_AWPROT,
    // Write address valid. This signal indicates that the master signaling
        // valid write address and control information.
    input logic  S_AXI_AWVALID,
    // Write address ready. This signal indicates that the slave is ready
        // to accept an address and associated control signals.
    output logic  S_AXI_AWREADY,
    // Write data (issued by master, acceped by Slave) 
    input logic [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    // Write strobes. This signal indicates which byte lanes hold
        // valid data. There is one write strobe bit for each eight
        // bits of the write data bus.    
    input logic [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    // Write valid. This signal indicates that valid write
        // data and strobes are available.
    input logic  S_AXI_WVALID,
    // Write ready. This signal indicates that the slave
        // can accept the write data.
    output logic  S_AXI_WREADY,
    // Write response. This signal indicates the status
        // of the write transaction.
    output logic [1 : 0] S_AXI_BRESP,
    // Write response valid. This signal indicates that the channel
        // is signaling a valid write response.
    output logic  S_AXI_BVALID,
    // Response ready. This signal indicates that the master
        // can accept a write response.
    input logic  S_AXI_BREADY,
    // Read address (issued by master, acceped by Slave)
    input logic [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    // Protection type. This signal indicates the privilege
        // and security level of the transaction, and whether the
        // transaction is a data access or an instruction access.
    input logic [2 : 0] S_AXI_ARPROT,
    // Read address valid. This signal indicates that the channel
        // is signaling valid read address and control information.
    input logic  S_AXI_ARVALID,
    // Read address ready. This signal indicates that the slave is
        // ready to accept an address and associated control signals.
    output logic  S_AXI_ARREADY,
    // Read data (issued by slave)
    output logic [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    // Read response. This signal indicates the status of the
        // read transfer.
    output logic [1 : 0] S_AXI_RRESP,
    // Read valid. This signal indicates that the channel is
        // signaling the required read data.
    output logic  S_AXI_RVALID,
    // Read ready. This signal indicates that the master can
        // accept the read data and response information.
    input logic  S_AXI_RREADY
);

// AXI4LITE signals
logic  [C_S_AXI_ADDR_WIDTH - 1 : 0] 	axi_awaddr;
logic  axi_awready;
logic  axi_wready;
logic  [1 : 0] 	axi_bresp;
logic  axi_bvalid;
logic  [C_S_AXI_ADDR_WIDTH - 1 : 0] 	axi_araddr;
logic  axi_arready;
logic  [C_S_AXI_DATA_WIDTH - 1 : 0] 	axi_rdata;
logic  [1 : 0] 	axi_rresp;
logic  	axi_rvalid;




//TODO: DELETE THIS ONCE YOU FINISH FRAME BUFFER TESTBENCH
logic douta;

// Example-specific design signals
// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
// ADDR_LSB is used for addressing 32/64 bit registers/memories
// ADDR_LSB = 2 for 32 bits (n downto 2)
// ADDR_LSB = 3 for 64 bits (n downto 3)
localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
localparam integer OPT_MEM_ADDR_BITS = 11;
//----------------------------------------------
//-- Signals for user logic register space example
//------------------------------------------------
//-- Number of Slave Registers 4
//logic [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0;
//logic [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1;
//logic [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
//logic [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;
//
//Note: the provided Verilog template had the registered declared as above, but in order to give 
//students a hint we have replaced the 4 individual registers with an unpacked array of packed logic. 
//Note that you as the student will still need to extend this to the full register set needed for the lab.
// logic [C_S_AXI_DATA_WIDTH-1:0] slv_regs[604];
//logic [C_S_AXI_DATA_WIDTH-1:0] slv_regs[604];
logic	 slv_reg_rden;
logic	 slv_reg_wren;
logic [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;

logic [31:0] palette_regs[16];
logic [31:0] control_regs[3];


logic [C_S_AXI_ADDR_WIDTH - 3:0] addr_write;
logic [C_S_AXI_ADDR_WIDTH - 3:0] addr_read;

integer	 byte_index;
logic	 aw_en;


logic [1:0] rcounter;
logic wcounterreset;
logic rcounterreset;
logic [1:0] wcounter;



// I/O Connections assignments

assign S_AXI_AWREADY	= axi_awready;
assign S_AXI_WREADY	= axi_wready;
assign S_AXI_BRESP	= axi_bresp;
assign S_AXI_BVALID	= axi_bvalid;
assign S_AXI_ARREADY = axi_arready;
assign S_AXI_RDATA	= axi_rdata;
assign S_AXI_RRESP	= axi_rresp;
assign S_AXI_RVALID	= axi_rvalid;
// Implement axi_awready generation
// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
// de-asserted when reset is low.

always_ff @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_awready <= 1'b0;
      aw_en <= 1'b1;
    end 
  else
    begin    
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
        begin
          // slave is ready to accept write address when 
          // there is a valid write address and write data
          // on the write address and data bus. This design 
          // expects no outstanding transactions. 
          axi_awready <= 1'b1;
          aw_en <= 1'b0;
        end
        else if (S_AXI_BREADY && axi_bvalid)
            begin
              aw_en <= 1'b1;
              axi_awready <= 1'b0;
            end
      else           
        begin
          axi_awready <= 1'b0;
        end
    end 
end       

// Implement axi_awaddr latching
// This process is used to latch the address when both 
// S_AXI_AWVALID and S_AXI_WVALID are valid. 

always_ff @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_awaddr <= 0;
    end 
  else
    begin    
      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
        begin
          // Write Address latching 
          axi_awaddr <= S_AXI_AWADDR;
        end
    end 
end       

// Implement axi_wready generation
// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
// de-asserted when reset is low. 

always_ff @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_wready <= 1'b0;
    end 
  else
    begin    
      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
        begin
          // slave is ready to accept write data when 
          // there is a valid write address and write data
          // on the write address and data bus. This design 
          // expects no outstanding transactions. 
          axi_wready <= 1'b1;
        end
      else
        begin
          axi_wready <= 1'b0;
        end
    end 
end       


// Implement memory mapped register select and write logic generation
// The write data is accepted and written to memory mapped registers when
// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
// select byte enables of slave registers while writing.
// These registers are cleared when reset (active low) is applied.
// Slave register write enable is asserted when valid address and data are available
// and the slave is ready to accept the write address and write data.
assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;
logic prev_vsync;
//integer write_counter = 0;
always_ff @( posedge S_AXI_ACLK )
begin
//  write_counter = write_counter + 1;

    if(axi_awready && S_AXI_AWVALID) begin
        addr_write <= axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];
    end
    
    if(axi_wready && S_AXI_WVALID) begin
        if(axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] <= 'h4AF) begin
            dina <= S_AXI_WDATA;
            wea <= S_AXI_WSTRB;
          end
         else begin
            if (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] >= 'h800 && axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] <= 'h807) begin
                palette_regs[2 * (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] - 'h800) + 1] <= S_AXI_WDATA[31:16];
                palette_regs[2 * (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] - 'h800)] <= S_AXI_WDATA[15:0];
            end
         end
    end else wea <= 0;
    
//    if (slv_reg_wren)
//      begin
////        if (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] < 'h259)
////             for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
////              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
//                // Respective byte enables are asserted as per write strobes, note the use of the index part select operator
//                // '+:', you will need to understand how this operator works.
//                //CHANGE
//        if(axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] != 'h258 && ) begin
//            addr_write <= axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];//[(byte_index*8) +: 8];
//            dina <= S_AXI_WDATA;
//            wea <= S_AXI_WSTRB;
//          end
//          else control_regs[0] <= S_AXI_WDATA;
//    end 
//  else begin
//        wea <= 'b0;
//   end
  
  //CHANGED
  control_regs[1] <= drawX;
  control_regs[2] <= drawY;
  prev_vsync <= vsync;
  if (S_AXI_ARESETN == 1'b0)
    control_regs[0] <= 'b0;
  else if (prev_vsync & ~vsync)
    control_regs[0] <= control_regs[0] + 1;
end    
// i love ece 385! 
//  
// Implement write response logic generation
// The write response and response valid signals are asserted by the slave 
// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
// This marks the acceptance of address and indicates the status of 
// write transaction.

always_ff @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_bvalid  <= 0;
      axi_bresp   <= 2'b0;
      wcounterreset <= 1'b1;
    end 
  else
    begin    
      if (axi_awready && S_AXI_AWVALID && axi_wready && S_AXI_WVALID)
          wcounter <= 2'b00;
      else if (wcounter < 2'b10)
          wcounter <= wcounter + 1;
          
      if (~axi_bvalid && (wcounter >= 2'b10)) begin
          axi_bvalid <= 1'b1;
          axi_bresp  <= 2'b00; // 'OKAY' response 
      end 
      else if (S_AXI_BREADY && axi_bvalid) begin
          axi_bvalid <= 1'b0;
      end
    end
end   

//logic [1:0] handshake_counter;
//logic handshake_counter_reset;
//always_ff @(posedge S_AXI_ACLK) begin
//    if(handshake_counter == 2'b11 || handshake_counter_reset) handshake_counter <= 2'b0;
//    else handshake_counter <= handshake_counter + 1;
//end

// Implement axi_arready generation
// axi_arready is asserted for one S_AXI_ACLK clock cycle when
// S_AXI_ARVALID is asserted. axi_awready is 
// de-asserted when reset (active low) is asserted. 
// The read address is also latched when S_AXI_ARVALID is 
// asserted. axi_araddr is reset to zero on reset assertion.

always_ff @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_arready <= 1'b0;
      axi_araddr  <= 32'b0;
    end 
  else
    begin    
      if (~axi_arready && S_AXI_ARVALID)
        begin
          // indicates that the slave has acceped the valid read address
          axi_arready <= 1'b1;
          // Read address latching
          axi_araddr  <= S_AXI_ARADDR;
        end
      else
        begin
          axi_arready <= 1'b0;
        end
    end 
end       

// Implement axi_arvalid generation
// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
// data are available on the axi_rdata bus at this instance. The 
// assertion of axi_rvalid marks the validity of read data on the 
// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
// is deasserted on reset (active low). axi_rresp and axi_rdata are 
// cleared to zero on reset (active low).  
//always_ff @( posedge S_AXI_ACLK )
//begin
//  if ( S_AXI_ARESETN == 1'b0 )
//    begin
//      axi_rvalid <= 0;
//      axi_rresp  <= 0;
//    end 
//  else
//    begin    
//      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
//        begin
//          // Valid read data is available at the read data bus
//          axi_rvalid <= 1'b1;
//          axi_rresp  <= 2'b0; // 'OKAY' response
//        end   
//      else if (axi_rvalid && S_AXI_RREADY)
//        begin
//          // Read data is accepted by the master
//          axi_rvalid <= 1'b0;
//        end                
//    end
//end    



// Implement memory mapped register select and read logic generation
// Slave register read enable is asserted when valid address is available
// and the slave is ready to accept the read address.
assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;////////////////////////////////////////////////3


always_ff @(posedge S_AXI_ACLK) begin
  if (!S_AXI_ARESETN)
    addr_read <= '0;
  else if (axi_arready && S_AXI_ARVALID)
    addr_read <= axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];
end



// Output register or memory read data
always_ff @( posedge S_AXI_ACLK )
begin
  if ( S_AXI_ARESETN == 1'b0 )
    begin
      axi_rdata  <= 0;
      axi_rvalid <= 1'b0;
      axi_rresp  <= 2'b00;
      rcounter   <= 2'b00;
    end 
  else
    begin    
      // When there is a valid read address (S_AXI_ARVALID) with 
      // acceptance of read address by the slave (axi_arready), 
      // output the read dada 
      if (axi_arready && S_AXI_ARVALID)
          rcounter <= 2'b00; // reset counter when read accepted
      else if (rcounter < 2'b10)
          rcounter <= rcounter + 1;

      // Assert RVALID after 2 cycles (BRAM read latency)
      if (~axi_rvalid && (rcounter == 2'b01)) begin
            axi_rvalid <= 1'b1;
            axi_rresp  <= 2'b00; // 'OKAY' response
            if (addr_read >= 'h800 && addr_read <= 'h807) begin
                axi_rdata <= {palette_regs[2*(addr_read-'h800)+1][15:0],
                              palette_regs[2*(addr_read-'h800)][15:0]};
            end else if (addr_read == 'h808) axi_rdata <= control_regs[0];
            else if (addr_read == 'h809) axi_rdata <= control_regs[1];
            else if (addr_read == 'h80A) axi_rdata <= control_regs[2];
            else axi_rdata <= douta;
        end
      else if (axi_rvalid && (rcounter == 2'b10)) begin
            axi_rvalid <= 1'b0;
            if (addr_read >= 'h800 && addr_read <= 'h807) begin
                axi_rdata <= {palette_regs[2*(addr_read-'h800)+1][15:0],
                              palette_regs[2*(addr_read-'h800)][15:0]};
            end else if (addr_read == 'h808) axi_rdata <= control_regs[0];
            else if (addr_read == 'h809) axi_rdata <= control_regs[1];
            else if (addr_read == 'h80A) axi_rdata <= control_regs[2];
            else axi_rdata <= douta;
      end else if (axi_rvalid && S_AXI_RREADY) begin
          axi_rvalid <= 1'b0;
          axi_rdata <= 'b0;
      end   
    end
end    

// Add user logic here



//always_ff @(posedge S_AXI_ACLK) begin
//    if(wcounter == 2'b11 || wcounterreset) wcounter <= 2'b0;
//    else wcounter <= wcounter + 1;
//end
//always_ff @(posedge S_AXI_ACLK) begin
//    rcounter <= rcounter + 1;
//end



//Triangle logic


//Declaring the zbuffer. Need to connect to rest of logic using z input & output.
zbuffer zb(
  .clk(S_AXI_ACLK),
  .draw_x(drawX),
  .draw_y(drawY),
  .z(),
  .draw()
);

//Buffer signals for the GPU side.
logic wea;
logic [16:0] addra;
logic [7:0] dina;

//Buffer signals for the VGA side
logic [7:0] doutb;
logic [16:0] addrb;

framebuffer fb(
  .clk(S_AXI_ACLK),
  .*
);

// Accessing array of 2d bitmap pointers
// Lab 7.1
// row # * numCols + col#
// numCols = number of bitmap pointers in single row
// (drawY / 16) * 80 + drawX / 8, cannot do drawY
// Lab 7.2: Multiply address by 2 since one character every 2 bytes instead of every byte
//CHANGE

// assign vram_addr = ((drawY >> 4) * 80 + (drawX >> 3)) << 1;
// assign addrb = vram_addr[C_S_AXI_ADDR_WIDTH - 1 : 2];
// assign invert_glyph_code = doutb[(vram_addr[1] * 16) + 8 +: 8];
// assign fg_bg = doutb[(vram_addr[0] * 16) +: 8];

// logic [6:0] glyph;
// logic invert;
// assign glyph = invert_glyph_code[6:0];
// assign invert = invert_glyph_code[7];

// logic [3:0] fg_idx;
// logic [3:0] bg_idx;
// assign fg_idx = fg_bg[7:4];
// assign bg_idx = fg_bg[3:0];

// always_ff @(posedge S_AXI_ACLK) begin
//         addrb <= vram_addr[16:2];
//         glyph_code <= doutb[vram_addr[1:0]*8 +: 8];
// end


// font_rom_index = {glyph_code[6:0], DrawY[3:0]}, use glyph_code[7] for invert)
// Font Rom also little endian, so access with row len - drawx
//DONT CHANGE
// assign font_rom_addr = {glyph[6:0], drawY[3:0]};


assign addrb = drawY*320 + drawX;

logic [7:0] pixel_data;

//DONT CHANGE
assign pixel_data = doutb;

logic [3:0] r,g,b;

assign r = {pixel_data[7:5],1'b0};
assign g = {pixel_data[4:2],1'b0};
assign b = {pixel_data[1:0],2'b0};


//DONT CHANGE
always_comb begin
  red = r;
  blue = b;
  green = g;
end
// User logic ends
endmodule
