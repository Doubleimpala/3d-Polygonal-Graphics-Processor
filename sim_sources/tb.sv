`define SIM_VIDEO // Comment out to skip BMP generation (faster simulation)

module framebuffer_tb();

    // Clock and reset signals
    logic aclk = 1'b0;
    logic arstn = 1'b0;
    
    // AXI signals (tied off, not used for this test)
    logic [13:0] axi_awaddr = 14'd0;
    logic [2:0] axi_awprot = 3'd0;
    logic axi_awvalid = 1'b0;
    logic axi_awready;
    logic [31:0] axi_wdata = 32'd0;
    logic [3:0] axi_wstrb = 4'd0;
    logic axi_wvalid = 1'b0;
    logic axi_wready;
    logic [1:0] axi_bresp;
    logic axi_bvalid;
    logic axi_bready = 1'b0;
    logic [13:0] axi_araddr = 14'd0;
    logic [2:0] axi_arprot = 3'd0;
    logic axi_arvalid = 1'b0;
    logic axi_arready;
    logic [31:0] axi_rdata;
    logic [1:0] axi_rresp;
    logic axi_rvalid;
    logic axi_rready = 1'b0;
    
    // HDMI outputs
    logic hdmi_clk_n, hdmi_clk_p;
    logic [2:0] hdmi_tx_n, hdmi_tx_p;
    
    // Internal signals we'll monitor
    logic [3:0] red, green, blue;
    logic pixel_clk, pixel_hs, pixel_vs, pixel_vde;
    logic [9:0] drawX, drawY;
    
    // BMP writer related signals    
    localparam BMP_WIDTH  = 640;
    localparam BMP_HEIGHT = 480;
    logic [23:0] bitmap [BMP_WIDTH][BMP_HEIGHT];
    integer i, j;

    // Instantiate the top-level module
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
        .axi_awaddr(axi_awaddr),
        .axi_awprot(axi_awprot),
        .axi_awvalid(axi_awvalid),
        .axi_awready(axi_awready),
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb),
        .axi_wvalid(axi_wvalid),
        .axi_wready(axi_wready),
        .axi_bresp(axi_bresp),
        .axi_bvalid(axi_bvalid),
        .axi_bready(axi_bready),
        .axi_araddr(axi_araddr),
        .axi_arprot(axi_arprot),
        .axi_arvalid(axi_arvalid),
        .axi_arready(axi_arready),
        .axi_rdata(axi_rdata),
        .axi_rresp(axi_rresp),
        .axi_rvalid(axi_rvalid),
        .axi_rready(axi_rready)
    );

    // Clock generation - 100MHz
    always #5 aclk = ~aclk;

    // Probe internal signals using hierarchical references
    assign pixel_clk = dut.clk_25MHz;
    assign pixel_hs = dut.hsync;
    assign pixel_vs = dut.vsync;
    assign pixel_vde = dut.vde;
    assign drawX = dut.drawX;
    assign drawY = dut.drawY;
    assign red = dut.red;
    assign green = dut.green;
    assign blue = dut.blue;

    // BMP writing task
    task save_bmp(string bmp_file_name);
        begin
            integer unsigned fout_bmp_pointer, BMP_file_size, BMP_row_size, r;
            logic unsigned [31:0] BMP_header[0:12];
        
            BMP_row_size = 32'(BMP_WIDTH * 3) & 32'hFFFC;
            if (((BMP_WIDTH * 3) & 32'd3) != 0) BMP_row_size = BMP_row_size + 4;
    
            fout_bmp_pointer = $fopen(bmp_file_name, "wb");
            if (fout_bmp_pointer == 0) begin
                $display("Could not open file for writing: %s", bmp_file_name);
                $stop;     
            end
            $display("Saving bitmap: %s", bmp_file_name);
       
            BMP_header[0:12] = '{BMP_file_size, 0, 0054, 40, BMP_WIDTH, BMP_HEIGHT, 
                               {16'd24, 16'd1}, 0, (BMP_row_size * BMP_HEIGHT), 
                               2835, 2835, 0, 0};
        
            // Write header out      
            $fwrite(fout_bmp_pointer, "BM");
            for (int i = 0; i < 13; i++) 
                $fwrite(fout_bmp_pointer, "%c%c%c%c", 
                       BMP_header[i][7:0], BMP_header[i][15:8], 
                       BMP_header[i][23:16], BMP_header[i][31:24]);
        
            // Write image out (note that image is flipped in Y)
            for (int y = BMP_HEIGHT - 1; y >= 0; y--) begin
                for (int x = 0; x < BMP_WIDTH; x++)
                    $fwrite(fout_bmp_pointer, "%c%c%c", 
                           bitmap[x][y][23:16], bitmap[x][y][15:8], bitmap[x][y][7:0]);
            end
    
            $fclose(fout_bmp_pointer);
        end
    endtask
    
    // Capture pixels to bitmap
    always @(posedge pixel_clk) begin
        if (!arstn) begin
            for (j = 0; j < BMP_HEIGHT; j++)
                for (i = 0; i < BMP_WIDTH; i++)
                    bitmap[i][j] <= 24'h7f7f7f; // Gray background
        end else if (pixel_vde) begin
            // Scale 4-bit RGB to 8-bit for BMP
            bitmap[drawX][drawY] <= {red, 4'h0, green, 4'h0, blue, 4'h0};
        end
    end

    // Task to write directly to the BACK buffer memory
    // Your framebuffer switches which is front/back based on vsync
    // We need to figure out which buffer is currently the write buffer
    task write_to_buffer(input int addr, input logic [7:0] color);
        begin
            @(posedge aclk);
            // Write directly through the framebuffer GPU interface
            dut.hdmi_text_controller_v1_0_AXI_inst.wea = 1'b1;
            dut.hdmi_text_controller_v1_0_AXI_inst.addra = addr;
            dut.hdmi_text_controller_v1_0_AXI_inst.dina = color;
            @(posedge aclk);
            dut.hdmi_text_controller_v1_0_AXI_inst.wea = 1'b0;
        end
    endtask
    
    // Task to write a pixel at X,Y coordinates
    task write_pixel(input int x, input int y, input logic [7:0] color);
        begin
            int addr;
            if (x < 320 && y < 240) begin
                addr = y * 320 + x;
                write_to_buffer(addr, color);
            end
        end
    endtask
    
    // Task to draw a filled rectangle
    task draw_rect(input int x0, input int y0, input int w, input int h, input logic [7:0] color);
        begin
            for (int y = y0; y < y0 + h; y++) begin
                for (int x = x0; x < x0 + w; x++) begin
                    write_pixel(x, y, color);
                end
            end
        end
    endtask
    
    // Function to convert RGB888 to RGB332
    function logic [7:0] rgb332(input logic [7:0] r, input logic [7:0] g, input logic [7:0] b);
        return {r[7:5], g[7:5], b[7:6]};
    endfunction

    // Main test sequence
    initial begin: TEST_VECTORS
        arstn = 1'b0;
        repeat (10) @(posedge aclk);
        arstn = 1'b1;
        
        // Wait for clock wizard to lock
        $display("Waiting for clock wizard to lock...");
        wait(dut.locked);
        $display("Clock wizard locked!");
        
        // Wait a few more cycles for things to stabilize
        repeat (100) @(posedge aclk);
        
        $display("Starting framebuffer test...");
        
        // Clear screen to dark blue
        $display("Clearing screen to dark blue...");
        draw_rect(0, 0, 320, 240, rgb332(8'hFF, 8'h00, 8'h00));
        
        // Draw test patterns
        $display("Drawing color bars...");
        
        // Red rectangle
        draw_rect(10, 10, 50, 30, rgb332(8'hFF, 8'h00, 8'h00));
        
        // Green rectangle
        draw_rect(70, 10, 50, 30, rgb332(8'h00, 8'hFF, 8'h00));
        
        // Blue rectangle  
        draw_rect(130, 10, 50, 30, rgb332(8'h00, 8'h00, 8'hFF));
        
        // Yellow rectangle
        draw_rect(10, 50, 50, 30, rgb332(8'hFF, 8'hFF, 8'h00));
        
        // Cyan rectangle
        draw_rect(70, 50, 50, 30, rgb332(8'h00, 8'hFF, 8'hFF));
        
        // Magenta rectangle
        draw_rect(130, 50, 50, 30, rgb332(8'hFF, 8'h00, 8'hFF));
        
        // White rectangle
        draw_rect(10, 90, 50, 30, rgb332(8'hFF, 8'hFF, 8'hFF));
        
        // Gradient bar
        $display("Drawing gradient...");
        for (int x = 0; x < 320; x++) begin
            logic [7:0] gray;
            gray = x * 255 / 320;
            draw_rect(x, 130, 1, 20, rgb332(gray, gray, gray));
        end
        
        // Checkerboard pattern
        $display("Drawing checkerboard...");
        for (int y = 160; y < 230; y++) begin
            for (int x = 10; x < 150; x++) begin
                if (((x / 10) + (y / 10)) % 2 == 0)
                    write_pixel(x, y, rgb332(8'hFF, 8'hFF, 8'hFF));
                else
                    write_pixel(x, y, rgb332(8'h00, 8'h00, 8'h00));
            end
        end
        
        $display("Finished drawing. Waiting for buffer swap and frame display...");
        
        // Wait for vsync to trigger buffer swap (falling edge swaps buffers)
        wait(~pixel_vs);  // Wait for vsync falling edge (buffer swap happens here)
        $display("Buffer swapped! Waiting for frame to be displayed...");
        
        // Wait for the swapped buffer to be fully displayed
        `ifdef SIM_VIDEO
        wait(pixel_vs);   // Wait for vsync to go high
        wait(~pixel_vs);  // Wait for next vsync falling edge (full frame displayed)
        wait(pixel_vs);   // Wait for vsync high again
        repeat(1000) @(posedge pixel_clk); // Let a bit more render
        
        $display("Saving BMP...");
        save_bmp("framebuffer_test.bmp");
        `endif
        
        $display("Test complete!");
        $finish();
    end

endmodule