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
    parameter integer C_S_AXI_ADDR_WIDTH	= 5
)
(
    // Users to add ports here
    input logic vsync,
    input logic [9:0] drawX,
    input logic [9:0] drawY,
    
    output logic [3:0] red, green, blue,
    

    // User ports ends

    // Global Clock Signal
    input logic  S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input logic  S_AXI_ARESETN,
    // Write address (issued by master, acceped by Slave)
    input logic [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    // // Write channel Protection type. This signal indicates the
    //     // privilege and security level of the transaction, and whether
    //     // the transaction is a data access or an instruction access.
    // input logic [2 : 0] S_AXI_AWPROT,
    // // Write address valid. This signal indicates that the master signaling
    //     // valid write address and control information.
    input logic  S_AXI_AWVALID,
    // // Write address ready. This signal indicates that the slave is ready
    //     // to accept an address and associated control signals.
    output logic  S_AXI_AWREADY,
    // // Write data (issued by master, acceped by Slave) 
    input logic [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    // // Write strobes. This signal indicates which byte lanes hold
    //     // valid data. There is one write strobe bit for each eight
    //     // bits of the write data bus.    
    // input logic [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    // // Write valid. This signal indicates that valid write
    //     // data and strobes are available.
    input logic  S_AXI_WVALID,
    // // Write ready. This signal indicates that the slave
    //     // can accept the write data.
    output logic  S_AXI_WREADY,
    // // Write response. This signal indicates the status
    //     // of the write transaction.
    output logic [1 : 0] S_AXI_BRESP,
    // // Write response valid. This signal indicates that the channel
    //     // is signaling a valid write response.
    output logic  S_AXI_BVALID,
    // // Response ready. This signal indicates that the master
    //     // can accept a write response.
    input logic  S_AXI_BREADY,
    // // Read address (issued by master, acceped by Slave)
    // input logic [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    // // Protection type. This signal indicates the privilege
    //     // and security level of the transaction, and whether the
    //     // transaction is a data access or an instruction access.
    // input logic [2 : 0] S_AXI_ARPROT,
    // // Read address valid. This signal indicates that the channel
    //     // is signaling valid read address and control information.
    // input logic  S_AXI_ARVALID,
    // // Read address ready. This signal indicates that the slave is
    //     // ready to accept an address and associated control signals.
    // output logic  S_AXI_ARREADY,
    // // Read data (issued by slave)
    // output logic [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    // // Read response. This signal indicates the status of the
    //     // read transfer.
    // output logic [1 : 0] S_AXI_RRESP,
    // // Read valid. This signal indicates that the channel is
    //     // signaling the required read data.
    // output logic  S_AXI_RVALID,
    // // Read ready. This signal indicates that the master can
    //     // accept the read data and response information.
    // input logic  S_AXI_RREADY
);

// AXI4LITE signals
logic  [C_S_AXI_ADDR_WIDTH - 1 : 0] 	axi_awaddr;
logic  axi_awready;
logic  axi_wready;
logic  [1 : 0] 	axi_bresp;
logic  axi_bvalid;
// logic  [C_S_AXI_ADDR_WIDTH - 1 : 0] 	axi_araddr;
// logic  axi_arready;
// logic  [C_S_AXI_DATA_WIDTH - 1 : 0] 	axi_rdata;
// logic  [1 : 0] 	axi_rresp;
// logic  	axi_rvalid;




//TODO: DELETE THIS logic douta ONCE YOU FINISH FRAME BUFFER TESTBENCH
logic douta;

// Example-specific design signals
// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
// ADDR_LSB is used for addressing 32/64 bit registers/memories
// ADDR_LSB = 2 for 32 bits (n downto 2)
// ADDR_LSB = 3 for 64 bits (n downto 3)


// localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
// localparam integer OPT_MEM_ADDR_BITS = 11;

//Note: the provided Verilog template had the registered declared as above, but in order to give 
//students a hint we have replaced the 4 individual registers with an unpacked array of packed logic. 
//Note that you as the student will still need to extend this to the full register set needed for the lab.
// logic	 slv_reg_rden;
// logic	 slv_reg_wren;
// logic [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;

// logic [31:0] palette_regs[16];
// logic [31:0] control_regs[3];


logic [C_S_AXI_ADDR_WIDTH - 1:0] addr_write;
// logic [C_S_AXI_ADDR_WIDTH - 3:0] addr_write;
// logic [C_S_AXI_ADDR_WIDTH - 3:0] addr_read;

// integer	 byte_index;
logic	 aw_en;


// logic [1:0] rcounter;
// logic wcounterreset;
// logic rcounterreset;
// logic [1:0] wcounter;



// I/O Connections assignments

assign S_AXI_AWREADY	= axi_awready;
assign S_AXI_WREADY	= axi_wready;
assign S_AXI_BRESP	= axi_bresp;
assign S_AXI_BVALID	= axi_bvalid;
// assign S_AXI_ARREADY = axi_arready;
// assign S_AXI_RDATA	= axi_rdata;
// assign S_AXI_RRESP	= axi_rresp;
// assign S_AXI_RVALID	= axi_rvalid;
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
logic [31:0] buffer [5:0];
assign buffer_wr_en = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;
always_ff @( posedge S_AXI_ACLK ) begin
  if ( S_AXI_ARESETN == 1'b1 && buffer_wr_en ) begin
    buffer[axi_awaddr[4:2]] <= S_AXI_WDATA;

    fifo_wr_en <= 1'b0;
    if (axi_awaddr[4:2] == 3'd5 && !fifo_full) begin
        fifo_din <= {
            buffer[5],  // r_area
            buffer[4],  // color + v3z
            buffer[3],  // v3y + v3x
            buffer[2],  // v2z + v2y
            buffer[1],  // v2x + v1z
            buffer[0]   // v1y + v1x
        };
        fifo_wr_en <= 1'b1;
    end
  end
end    

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
    end 
  else
    begin    
      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
        begin
          // indicates a valid write response is available
          axi_bvalid <= 1'b1;
          axi_bresp  <= 2'b0; // 'OKAY' response 
        end                   // work error responses in future
      else
        begin
          if (S_AXI_BREADY && axi_bvalid) 
            //check if bready is asserted while bvalid is high) 
            //(there is a possibility that bready is always asserted high)   
            begin
              axi_bvalid <= 1'b0; 
            end  
        end
    end
end   


// Implement axi_arready generation
// axi_arready is asserted for one S_AXI_ACLK clock cycle when
// S_AXI_ARVALID is asserted. axi_awready is 
// de-asserted when reset (active low) is asserted. 
// The read address is also latched when S_AXI_ARVALID is 
// asserted. axi_araddr is reset to zero on reset assertion.

// always_ff @( posedge S_AXI_ACLK )
// begin
//   if ( S_AXI_ARESETN == 1'b0 )
//     begin
//       axi_arready <= 1'b0;
//       axi_araddr  <= 32'b0;
//     end 
//   else
//     begin    
//       if (~axi_arready && S_AXI_ARVALID)
//         begin
//           // indicates that the slave has acceped the valid read address
//           axi_arready <= 1'b1;
//           // Read address latching
//           axi_araddr  <= S_AXI_ARADDR;
//         end
//       else
//         begin
//           axi_arready <= 1'b0;
//         end
//     end 
// end       

// Implement axi_arvalid generation
// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
// data are available on the axi_rdata bus at this instance. The 
// assertion of axi_rvalid marks the validity of read data on the 
// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
// is deasserted on reset (active low). axi_rresp and axi_rdata are 
// cleared to zero on reset (active low).  



// Implement memory mapped register select and read logic generation
// Slave register read enable is asserted when valid address is available
// and the slave is ready to accept the read address.
// assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;////////////////////////////////////////////////3


// always_ff @(posedge S_AXI_ACLK) begin
//   if (!S_AXI_ARESETN)
//     addr_read <= '0;
//   else if (axi_arready && S_AXI_ARVALID)
//     addr_read <= axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];
// end



// Output register or memory read data
// always_ff @( posedge S_AXI_ACLK )
// begin
//   if ( S_AXI_ARESETN == 1'b0 )
//     begin
//       axi_rdata  <= 0;
//       axi_rvalid <= 1'b0;
//       axi_rresp  <= 2'b00;
//       rcounter   <= 2'b00;
//     end 
//   else
//     begin    
//       // When there is a valid read address (S_AXI_ARVALID) with 
//       // acceptance of read address by the slave (axi_arready), 
//       // output the read dada 
//       if (axi_arready && S_AXI_ARVALID)
//           rcounter <= 2'b00; // reset counter when read accepted
//       else if (rcounter < 2'b10)
//           rcounter <= rcounter + 1;

//       // Assert RVALID after 2 cycles (BRAM read latency)
//       if (~axi_rvalid && (rcounter == 2'b01)) begin
//             axi_rvalid <= 1'b1;
//             axi_rresp  <= 2'b00; // 'OKAY' response
//             if (addr_read >= 'h800 && addr_read <= 'h807) begin
//                 axi_rdata <= {palette_regs[2*(addr_read-'h800)+1][15:0],
//                               palette_regs[2*(addr_read-'h800)][15:0]};
//             end else if (addr_read == 'h808) axi_rdata <= control_regs[0];
//             else if (addr_read == 'h809) axi_rdata <= control_regs[1];
//             else if (addr_read == 'h80A) axi_rdata <= control_regs[2];
//             else axi_rdata <= douta;
//         end
//       else if (axi_rvalid && (rcounter == 2'b10)) begin
//             axi_rvalid <= 1'b0;
//             if (addr_read >= 'h800 && addr_read <= 'h807) begin
//                 axi_rdata <= {palette_regs[2*(addr_read-'h800)+1][15:0],
//                               palette_regs[2*(addr_read-'h800)][15:0]};
//             end else if (addr_read == 'h808) axi_rdata <= control_regs[0];
//             else if (addr_read == 'h809) axi_rdata <= control_regs[1];
//             else if (addr_read == 'h80A) axi_rdata <= control_regs[2];
//             else axi_rdata <= douta;
//       end else if (axi_rvalid && S_AXI_RREADY) begin
//           axi_rvalid <= 1'b0;
//           axi_rdata <= 'b0;
//       end   
//     end
// end    



//Triangle controller states:
enum logic [1:0] {
  clear_buf,
  wait_tri,
  calc_edge,
  rasterize
} controller_state;


////////////////////BEGIN FRAME BUFFER
//Buffer signals for the GPU side.
logic wea;
logic [16:0] addra;
logic [7:0] dina;

//Rasterizer memory signals.
logic write_enable_gpu;
logic [7:0] data_in_gpu;
logic [16:0] addr_gpu;

//Buffer signals from clear buffer.
logic wea_clear_buf;
logic [16:0] addra_clear_buf;
logic [7:0] dina_clear_buf;

//MUX to switch between.
always_comb begin
  if(controller_state == clear_buf) begin
    wea = wea_clear_buf;
    addra = addra_clear_buf;
    dina = dina_clear_buf;
  end else begin 
    wea = write_enable_gpu;
    addra = addr_gpu;
    dina = data_in_gpu;
  end
end

//Buffer signals for the VGA side
logic [7:0] doutb;
logic [16:0] addrb;

framebuffer fb(
  .clk(S_AXI_ACLK),
  .rst(~S_AXI_ARESETN),
  .*
);

////////////////////END FRAME BUFFER


////////////////////ZBUFFER
//Zbuffer signals
logic [7:0] zbuf_dout;
logic [16:0] zbuf_addr;
logic [7:0] zbuf_din;
logic zbuf_we;
logic zbuf_en;
assign zbuf_en = 1;

//Zbuffer signals from rasterizer
logic [7:0] zbuf_dout_raster;
logic [16:0] zbuf_addr_raster;
logic [7:0] zbuf_din_raster;
logic zbuf_we_raster;
logic zbuf_en_raster;
assign zbuf_dout_raster = zbuf_dout;

//Zbuffer signals from buffer clear.
logic [16:0] zbuf_addr_buf_clear;
logic [7:0] zbuf_din_buf_clear;
logic zbuf_we_buf_clear;
logic zbuf_en_buf_clear;

//MUX to switch between clear buffer control and 
always_comb begin
  if(controller_state == clear_buf) begin
    zbuf_addr = zbuf_addr_buf_clear;
    zbuf_din = zbuf_din_buf_clear;
    zbuf_we = zbuf_we_buf_clear;
  end else begin
    zbuf_addr = zbuf_addr_raster;
    zbuf_din = zbuf_din_raster;
    zbuf_we = zbuf_we_raster;
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
  .clka(S_AXI_ACLK),
  .addra(zbuf_addr),
  .dina(zbuf_din),
  .douta(zbuf_dout),
  .wea(zbuf_we),
  .ena(zbuf_en)
);

////////////////////END ZBUFFER


//Triangle logic

//Recieve Triangles into FIFO.
logic fifo_full;
logic [191:0] fifo_din;
logic fifo_wr_en;
logic fifo_empty;
logic [191:0] fifo_dout;
logic fifo_rd_en;
logic fifo_srst;


///// Configuration
// Interface type: Native
// Write/Read Width: 192 (32 * 6)
fifo_generator_0 fifo(
  .clk(S_AXI_ACLK),
  .srst(~S_AXI_ARESETN),
  .full(fifo_full),
  .din(fifo_din),
  .wr_en(fifo_wr_en),
  .empty(fifo_empty),
  .dout(fifo_dout),
  .rd_en(fifo_rd_en)
);


//Signals for 1 triangle:
logic [8:0] v1x, v2x, v3x;
logic [7:0] v1y, v2y, v3y;
logic [7:0] color;
logic [31:0] inv_area;
// use triangle_ready and triangle_valid signals
assign triangle_valid = ~fifo_empty;
assign fifo_rd_en = triangle_valid & triangle_ready;

assign [31:0] inv_area = fifo_dout[183:152];
assign [7:0] color = fifo_dout[151:144];
assign [15:0] vertex0 = fifo_dout[143:128];
assign [15:0] vertex1 = fifo_dout[127:112];
assign [15:0] vertex2 = fifo_dout[111:96];
assign [15:0] vertex3 = fifo_dout[95:80];
assign [15:0] vertex4 = fifo_dout[79:64];
assign [15:0] vertex5 = fifo_dout[63:48];
assign [15:0] vertex6 = fifo_dout[47:32];
assign [15:0] vertex7 = fifo_dout[31:16];
assign [15:0] vertex8 = fifo_dout[15:0];

////////////////////BEGIN EDGES & BOUNDING BOX STAGE (3 clock cycles)
//Calculate Edge equations using vertices, and bounding box.

//Vertices. I renamed these so that we can differentiate from the ones coming out of the FIFO/AXI. We need these to be 1 triangle at a time in the controller.
logic [8:0] v1x_in, v2x_in, v3x_in;
logic [7:0] v1y_in, v2y_in, v3y_in;
assign v1x_in = v1x;
assign v2x_in = v2x;
assign v3x_in = v3x;
assign v1y_in = v1y;
assign v2y_in = v2y;
assign v3y_in = v3y;
//Edge handshaking protocol. We assert edge_start for 1 clock cycle when the data in is valid. We then wait for edge_done before retrieving data and continuing to next stage. Expect a 2 clock cycle latency.
logic edge_start;
logic edge_done;

//Edge equation coefficients.
logic signed [9:0] a1, b1, a2, b2, a3, b3;
logic signed [17:0] c1, c2, c3;
logic [8:0] bbxi;
logic [8:0] bbxf;
logic [7:0] bbyi;
logic [7:0] bbyf; 

edge_eq_bb edge_calc(
 .clk(S_AXI_ACLK),
 .rst(~S_AXI_ARESETN),
 .*
);
////////////////////END EDGES & BOUNDING BOX STAGE


////////////////////BEGIN RASTERIZER STAGE ( clock cycles)
//Rasterizer handshaking protocol. We assert rasterizer_start for 1 clock cycle when the data in is valid. We then wait for rasterizer_done before retrieving data and continuing to next stage. Expect a  clock cycle latency.
logic rasterizer_start;
logic rasterizer_done;


//Z coordinates
logic [15:0] z1, z2, z3;

rasterizer raster(
  .clk(S_AXI_ACLK),
  .rst(~S_AXI_ARESETN),
  .zbuf_dout(zbuf_dout_raster),
  .zbuf_addr(zbuf_addr_raster),
  .zbuf_din(zbuf_din_raster),
  .zbuf_we(zbuf_we_raster),
  .zbuf_en(zbuf_en_raster),
  .*
);
////////////////////END RASTERIZER STAGE


////////////////////BEGIN PIPELINE CONTROLLER
logic triangle_ready;
logic triangle_valid;
logic buffers_cleared;
logic [16:0] clear_addr;

logic prev_vsync_sync;
logic vsync_sync1;
logic vsync_sync2;

always_ff @(posedge S_AXI_ACLK) begin
    vsync_sync1 <= vsync;
    vsync_sync2 <= vsync_sync1;
end

//Used to prevent clock domain crossing since the memory runs at 100 MHz and vsync is at 25 MHz, causes front to trigger multiple times.
always_ff @(posedge S_AXI_ACLK) begin
    if (~S_AXI_ARESETN) begin
        prev_vsync_sync <= 1'b0;
    end 
    else begin
      prev_vsync_sync <= vsync_sync2;
    end
end


always_ff @(posedge S_AXI_ACLK) begin
  if(~S_AXI_ARESETN) begin
    controller_state <= clear_buf;
    triangle_ready <= 0;
    edge_start <= 0;
    rasterizer_start <= 0;
    buffers_cleared <= 0;
    clear_addr <= 0;
  end else begin
    if(~prev_vsync_sync && vsync_sync2 && controller_state == wait_tri) begin
      controller_state <= clear_buf;
      buffers_cleared <= 0;
      clear_addr <= 0;
    end else begin
      case(controller_state) 
        clear_buf: begin
          if(~buffers_cleared) begin
            // Clear both buffers
            zbuf_we_buf_clear <= 1;
            zbuf_addr_buf_clear <= clear_addr;
            zbuf_din_buf_clear <= 8'hFF;
            
            wea_clear_buf <= 1;
            addra_clear_buf <= clear_addr;
            dina_clear_buf <= 8'h00;

            clear_addr <= clear_addr + 1;

            if(clear_addr == 76799) begin
              buffers_cleared <= 1;
              zbuf_we_buf_clear <= 0;
              wea_clear_buf <= 0;
              triangle_ready <= 1;
              controller_state <= wait_tri;
            end
          end
        end
        wait_tri: begin
          if(triangle_ready && triangle_valid) begin
            edge_start <= 1;
            triangle_ready <= 0;
            controller_state <= calc_edge;
          end
        end
        calc_edge: begin
          edge_start <= 0;
          if(edge_done) begin
            rasterizer_start <= 1;
            controller_state <= rasterize;
          end
        end
        rasterize: begin
          rasterizer_start <= 0;
          if(rasterizer_done) begin
            controller_state <= wait_tri;
            triangle_ready <= 1;
          end
        end
      endcase
    end
  end
end

////////////////////END PIPELINE CONTROLLER




//Pixel drawing logic:
//Calculate address in the frame buffer for the current x and y we are drawing for.
assign addrb = drawY[8:1]*320 + drawX[9:1];

//Retrieve the data combinationally since our VGA clock is 4x slower (25 MHz vs 100MHz AXI clock)
logic [7:0] pixel_data;
assign pixel_data = doutb;

//Retrieve 8 bit color & resize it to 4 bits, as that's how VGA requires it.
logic [3:0] r,g,b;
assign r = {pixel_data[7:5],1'b0};
assign g = {pixel_data[4:2],1'b0};
assign b = {pixel_data[1:0],2'b0};

//Set the output colors.
always_comb begin
  red = r;
  blue = b;
  green = g;
end

endmodule
