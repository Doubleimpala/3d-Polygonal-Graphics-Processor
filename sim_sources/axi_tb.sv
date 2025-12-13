`timescale 1ns / 1ps
`define SIM_VIDEO // Comment out to skip BMP generation

module tb_axi_triangle_pipeline();

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic aclk = 1'b0;
    logic arstn = 1'b0;
    always #5 aclk = ~aclk; // 100MHz

    // =========================================================================
    // AXI signals (tied off)
    // =========================================================================
    logic [4:0] write_addr = 5'd0;
    logic write_addr_valid = 1'b0;
    logic write_addr_ready;
    logic [31:0] write_data = 32'd0;
    logic write_data_valid = 1'b0;
    logic write_data_ready;
    logic [1:0] write_resp;
    logic write_resp_valid;
    logic write_resp_ready = 1'b0;

    // =========================================================================
    // HDMI outputs
    // =========================================================================
    logic hdmi_clk_n, hdmi_clk_p;
    logic [2:0] hdmi_tx_n, hdmi_tx_p;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    hdmi_text_controller_v1_0 #(
        .C_AXI_DATA_WIDTH(32),
        .C_AXI_ADDR_WIDTH(14)
    ) dut (
        .hdmi_clk_n(hdmi_clk_n),
        .hdmi_clk_p(hdmi_clk_p),
        .hdmi_tx_n(hdmi_tx_n),
        .hdmi_tx_p(hdmi_tx_p),
        .axi_aclk(aclk),
        .axi_aresetn(arstn),
        .axi_awaddr(write_addr),
        .axi_awvalid(write_addr_valid),
        .axi_awready(write_addr_ready),
        .axi_wdata(write_data),
        .axi_wvalid(write_data_valid),
        .axi_wready(write_data_ready),
        .axi_bresp(write_resp),
        .axi_bvalid(write_resp_valid),
        .axi_bready(write_resp_ready)
    );

    // =========================================================================
    // Internal signals
    // =========================================================================
    logic [3:0] red, green, blue;
    logic pixel_clk, pixel_hs, pixel_vs, pixel_vde;
    logic [9:0] drawX, drawY;

    assign pixel_clk = dut.clk_25MHz;
    assign pixel_hs = dut.hsync;
    assign pixel_vs = dut.vsync;
    assign pixel_vde = dut.vde;
    assign drawX = dut.drawX;
    assign drawY = dut.drawY;
    assign red = dut.red;
    assign green = dut.green;
    assign blue = dut.blue;

    // =========================================================================
    // BMP Generation
    // =========================================================================
    localparam BMP_WIDTH  = 640;
    localparam BMP_HEIGHT = 480;
    logic [23:0] bitmap [BMP_WIDTH][BMP_HEIGHT];
    integer i, j;

    // Capture pixels
    always @(posedge pixel_clk) begin
        if (!arstn) begin
            for (j = 0; j < BMP_HEIGHT; j++)
                for (i = 0; i < BMP_WIDTH; i++)
                    bitmap[i][j] <= 24'h000000; // Black background
        end else if (pixel_vde) begin
            // Scale 4-bit RGB to 8-bit for BMP
            bitmap[drawX][drawY] <= {red, 4'h0, green, 4'h0, blue, 4'h0};
        end
    end

    // Save BMP task
    task save_bmp(string bmp_file_name);
        integer unsigned fout, BMP_file_size, BMP_row_size;
        logic unsigned [31:0] BMP_header[0:12];
        begin
            BMP_row_size = 32'(BMP_WIDTH * 3) & 32'hFFFC;
            if (((BMP_WIDTH * 3) & 32'd3) != 0) BMP_row_size = BMP_row_size + 4;

            fout = $fopen(bmp_file_name, "wb");
            if (fout == 0) begin
                $display("Could not open file: %s", bmp_file_name);
                $stop;
            end
            $display("Saving bitmap: %s", bmp_file_name);

            BMP_header[0:12] = '{BMP_file_size, 0, 0054, 40, BMP_WIDTH, BMP_HEIGHT,
                               {16'd24, 16'd1}, 0, (BMP_row_size * BMP_HEIGHT),
                               2835, 2835, 0, 0};

            $fwrite(fout, "BM");
            for (int k = 0; k < 13; k++)
                $fwrite(fout, "%c%c%c%c",
                       BMP_header[k][7:0], BMP_header[k][15:8],
                       BMP_header[k][23:16], BMP_header[k][31:24]);

            for (int y = BMP_HEIGHT - 1; y >= 0; y--)
                for (int x = 0; x < BMP_WIDTH; x++)
                    $fwrite(fout, "%c%c%c",
                           bitmap[x][y][23:16], bitmap[x][y][15:8], bitmap[x][y][7:0]);

            $fclose(fout);
        end
    endtask
    // Provided AXI write task, follow this example for AXI read below
    task axi_write (input logic [31:0] addr, input logic [31:0] data);
        begin
            #3 write_addr <= addr;	//Put write address on bus
            write_data <= data;	//put write data on bus
            write_addr_valid <= 1'b1;	//indicate address is valid
            write_data_valid <= 1'b1;	//indicate data is valid
            write_resp_ready <= 1'b1;	//indicate ready for a response
    
            //wait for one slave ready signal or the other
            wait(write_data_ready || write_addr_ready);
                
            @(posedge aclk); //one or both signals and a positive edge
            if(write_data_ready&&write_addr_ready)//received both ready signals
            begin
                write_addr_valid<=0;
                write_data_valid<=0;
            end
            else    //wait for the other signal and a positive edge
            begin
                if(write_data_ready)    //case data handshake completed
                begin
                    write_data_valid<=0;
                    wait(write_addr_ready); //wait for address address ready
                end
                        else if(write_addr_ready)   //case address handshake completed
                        begin
                    write_addr_valid<=0;
                            wait(write_data_ready); //wait for data ready
                        end 
                @ (posedge aclk);// complete the second handshake
                write_addr_valid<=0; //make sure both valid signals are deasserted
                write_data_valid<=0;
            end
                
            //wait for valid response
            wait(write_resp_valid);
            
            //both handshake signals and rising edge
            @(posedge aclk);
    
            //deassert ready for response
            write_resp_ready<=0;
    
            //end of write transaction
        end
    endtask;

    // =========================================================================
    // Triangle Drawing Task
    // =========================================================================
    task draw_triangle(
        input logic [8:0] x1, input logic [7:0] y1,
        input logic [8:0] x2, input logic [7:0] y2,
        input logic [8:0] x3, input logic [7:0] y3,
        input logic [7:0] color_in,
        input logic [15:0] z1, z2, z3
    );
        int area_x2;
        real inv_area_real;
        logic [31:0] inv_area_fixed;
        logic [31:0] buffer[6];

        begin
            // Calculate 2*Area
            area_x2 = int'(x1)*(int'(y2) - int'(y3)) + 
                      int'(x2)*(int'(y3) - int'(y1)) + 
                      int'(x3)*(int'(y1) - int'(y2));
            
            if (area_x2 < 0) area_x2 = -area_x2;

            if (area_x2 == 0) begin
                $display("Warning: Triangle has 0 area, skipping.");
                return;
            end

            // Calculate 1/(2*Area) in 8.24 fixed-point
            inv_area_real = (1.0 / real'(area_x2)) * 16777216.0; // 2^24
            inv_area_fixed = $unsigned(inv_area_real);

            $display("Drawing Triangle: (%0d,%0d), (%0d,%0d), (%0d,%0d) Color:%h Z:(%0d,%0d,%0d)",
                     x1,y1, x2,y2, x3,y3, color_in, z1, z2, z3);
            $display("  Area*2=%0d, inv_area=0x%h", area_x2, inv_area_fixed);

            // Pack triangle data into 6 words (192 bits)
            // Format matches C code packing:
            // buffer[0] = y1 << 16 | x1
            // buffer[1] = x2 << 16 | z1
            // buffer[2] = z2 << 16 | y2
            // buffer[3] = y3 << 16 | x3
            // buffer[4] = color << 16 | z3
            // buffer[5] = inv_area
            
            buffer[0] = {8'd0, y1, 7'd0, x1};           // v1y + v1x
            buffer[1] = {7'd0, x2, z1};                 // v2x + v1z
            buffer[2] = {z2, 8'd0, y2};                 // v2z + v2y
            buffer[3] = {8'd0, y3, 7'd0, x3};           // v3y + v3x
            buffer[4] = {8'd0, color_in, z3};           // color + v3z
            buffer[5] = inv_area_fixed;                 // r_area

            // Write all 6 words via AXI (addresses 0x00, 0x04, 0x08, 0x0C, 0x10, 0x14)
            for (int i = 0; i < 6; i++) begin
                axi_write(i * 4, buffer[i]);
                $display("  AXI Write: addr=0x%02x data=0x%08x", i*4, buffer[i]);
            end
            
            // Small delay to let FIFO settle
            repeat(5) @(posedge aclk);
            
            $display("  Triangle sent via AXI!");
            
            // wait(dut.hdmi_text_controller_v1_0_AXI_inst.rasterizer_done == 1'b1);
            // @(posedge aclk);
            
            // $display("  Triangle rasterization complete!");
        end
    endtask

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin: TEST_VECTORS
        // Reset
        arstn = 1'b0;
        dut.hdmi_text_controller_v1_0_AXI_inst.triangle_valid <= 1'b0;
        repeat (10) @(posedge aclk);
        arstn = 1'b1;

        // Wait for clock wizard to lock
        $display("Waiting for clock wizard to lock...");
        wait(dut.locked);
        $display("Clock wizard locked!");

        repeat (100) @(posedge aclk);

        $display("\n=== Starting Triangle Pipeline Test ===\n");

        // Triangle 1: Red (Bottom Left) - Farther Back (Z=50)
        draw_triangle(
            9'd40, 8'd20,    // V1
            9'd140, 8'd120,  // V2
            9'd40, 8'd120,   // V3
            8'hE0,           // Red (RGB332: 111_000_00)
            16'd50, 16'd50, 16'd50
        );

        // Triangle 2: Green (Top Middle) - Closer (Z=10). **FIXED CW/CCW Winding**
        draw_triangle(
            9'd140, 8'd20,   // V1
            9'd190, 8'd70,   // V2 (Swapped from original to fix winding)
            9'd90, 8'd70,    // V3 (Swapped from original to fix winding)
            8'h1C,           // Green (RGB332: 000_111_00)
            16'd10, 16'd10, 16'd10
        );

        // Triangle 3: Blue (Top Left) - Z Gradient (Z=10 to 100)
        draw_triangle(
            9'd20, 8'd140,
            9'd70, 8'd200,
            9'd20, 8'd200,
            8'h03,           // Blue (RGB332: 000_000_11)
            16'd10, 16'd100, 16'd10
        );
        
        // --- NEW OVERLAPPING TRIANGLES ---

        // Triangle 4: Yellow (Overlapping Center) - **VERY CLOSE (Z=5)**
        // This will be drawn LAST in the FIFO and should overwrite all others.
        draw_triangle(
            9'd100, 8'd80,   // V1
            9'd200, 8'd180,  // V2
            9'd100, 8'd180,  // V3
            8'hFC,           // Yellow (RGB332: 111_111_00)
            16'd5, 16'd5, 16'd5
        );
        
        // Triangle 5: Magenta (Overlapping Yellow) - **VERY FAR (Z=100)**
        // This will be drawn AFTER Yellow, but should be hidden by the Z-buffer.
        draw_triangle(
            9'd90, 8'd70,    // V1
            9'd210, 8'd190,   // V2
            9'd90, 8'd190,   // V3
            8'hC3,           // Magenta (RGB332: 110_000_11)
            16'd100, 16'd100, 16'd100
        );

        draw_triangle(
            9'd50,  8'd300,   // V1 (Left)  Z=10
            9'd250, 8'd300,   // V2 (Right) Z=90
            9'd50,  8'd400,   // V3 (Left)  Z=10
            8'h1F,            // Cyan
            16'd10, 16'd90, 16'd10
        );

        // Triangle B: Magenta (Slopes Z: High -> Low)
        draw_triangle(
            9'd50,  8'd300,   // V1 (Left)  Z=90
            9'd250, 8'd300,   // V2 (Right) Z=10
            9'd250, 8'd400,   // V3 (Right) Z=10
            8'hE3,            // Magenta
            16'd90, 16'd10, 16'd10
        );

        $display("\nAll triangles submitted via AXI. Waiting for processing and display...");
        
        // Wait for triangles to be processed
        wait(dut.hdmi_text_controller_v1_0_AXI_inst.fifo_empty == 1'b1);
        $display("FIFO empty - all triangles consumed");
        
        // Wait for pipeline to finish
        wait(dut.hdmi_text_controller_v1_0_AXI_inst.controller_state == 
             dut.hdmi_text_controller_v1_0_AXI_inst.wait_tri);
        $display("Pipeline idle");

        // Wait for vsync to swap buffers and display
        wait(pixel_vs == 1'b0);
        $display("First vsync falling edge detected (buffer swap)");
        wait(pixel_vs == 1'b1);
        $display("Vsync high - frame displaying");
        wait(pixel_vs == 1'b0);
        $display("Second vsync falling edge - frame complete");
        wait(pixel_vs == 1'b0);
        $display("First vsync falling edge detected (buffer swap)");
        wait(pixel_vs == 1'b1);
        $display("Vsync high - frame displaying");
        wait(pixel_vs == 1'b0);
        $display("Second vsync falling edge - frame complete");

        // Let the frame fully render
        repeat(1000) @(posedge pixel_clk);

        `ifdef SIM_VIDEO
        $display("\nSaving BMP...");
        save_bmp("pipeline_axi_test.bmp");
        $display("BMP saved successfully!");
        `endif

        $display("\n=== Test Complete ===\n");
        $finish;
    end

    // =========================================================================
    // Monitoring & Debug
    // =========================================================================
    initial begin
        // Monitor key signals
        $display("Time\tState\tReady\tDone\tPixels");
        forever begin
            @(posedge aclk);
            if (dut.hdmi_text_controller_v1_0_AXI_inst.write_enable_gpu)
                $display("%0t\t%0d\t%b\t%b\tWriting addr=%0d color=%h",
                         $time,
                         dut.hdmi_text_controller_v1_0_AXI_inst.controller_state,
                         dut.hdmi_text_controller_v1_0_AXI_inst.triangle_ready,
                         dut.hdmi_text_controller_v1_0_AXI_inst.rasterizer_done,
                         dut.hdmi_text_controller_v1_0_AXI_inst.addr_gpu,
                         dut.hdmi_text_controller_v1_0_AXI_inst.data_in_gpu);
        end
    end

    // Monitor AXI writes
    initial begin
        forever begin
            @(posedge aclk);
            if (write_addr_valid && write_addr_ready && write_data_valid && write_data_ready)
                $display("%0t\tAXI WRITE: addr=0x%03x data=0x%08x", 
                         $time, write_addr, write_data);
        end
    end
    
    // Monitor FIFO
    initial begin
        forever begin
            @(posedge aclk);
            if (dut.hdmi_text_controller_v1_0_AXI_inst.fifo_wr_en)
                $display("%0t\tFIFO WRITE: full=%b", 
                         $time, dut.hdmi_text_controller_v1_0_AXI_inst.fifo_full);
            if (dut.hdmi_text_controller_v1_0_AXI_inst.fifo_rd_en)
                $display("%0t\tFIFO READ: empty=%b", 
                         $time, dut.hdmi_text_controller_v1_0_AXI_inst.fifo_empty);
        end
    end
    // Timeout watchdog
    initial begin
        #100000000; // 100ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
