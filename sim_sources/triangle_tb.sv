`timescale 1ns / 1ps
`define SIM_VIDEO // Comment out to skip BMP generation

module tb_triangle_pipeline();

    // =========================================================================
    // Clock & Reset
    // =========================================================================
    logic aclk = 1'b0;
    logic arstn = 1'b0;
    always #5 aclk = ~aclk; // 100MHz

    // =========================================================================
    // AXI signals (tied off)
    // =========================================================================
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

    // =========================================================================
    // Triangle Drawing Task
    // =========================================================================
    task draw_triangle(
        input logic [8:0] x1, input logic [7:0] y1,
        input logic [8:0] x2, input logic [7:0] y2,
        input logic [8:0] x3, input logic [7:0] y3,
        input logic [7:0] color_in,
        input logic [15:0] z1_in, z2_in, z3_in
    );
        int area_x2;
        real inv_area_real;
        logic [31:0] inv_area_fixed;
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
                     x1,y1, x2,y2, x3,y3, color_in, z1_in, z2_in, z3_in);
            $display("  Area*2=%0d, inv_area=0x%h", area_x2, inv_area_fixed);

            // Wait for pipeline to be ready
            wait(dut.hdmi_text_controller_v1_0_AXI_inst.triangle_ready == 1'b1);
            @(posedge aclk);

            // Drive triangle data
            dut.hdmi_text_controller_v1_0_AXI_inst.v1x <= x1;
            dut.hdmi_text_controller_v1_0_AXI_inst.v1y <= y1;
            dut.hdmi_text_controller_v1_0_AXI_inst.v2x <= x2;
            dut.hdmi_text_controller_v1_0_AXI_inst.v2y <= y2;
            dut.hdmi_text_controller_v1_0_AXI_inst.v3x <= x3;
            dut.hdmi_text_controller_v1_0_AXI_inst.v3y <= y3;
            dut.hdmi_text_controller_v1_0_AXI_inst.color <= color_in;
            dut.hdmi_text_controller_v1_0_AXI_inst.inv_area <= inv_area_fixed;
            dut.hdmi_text_controller_v1_0_AXI_inst.z1 <= z1_in;
            dut.hdmi_text_controller_v1_0_AXI_inst.z2 <= z2_in;
            dut.hdmi_text_controller_v1_0_AXI_inst.z3 <= z3_in;

            // Assert valid
            dut.hdmi_text_controller_v1_0_AXI_inst.triangle_valid <= 1'b1;

            @(posedge aclk);

            // Deassert valid
            dut.hdmi_text_controller_v1_0_AXI_inst.triangle_valid <= 1'b0;

            // Wait for rasterization to complete
            wait(dut.hdmi_text_controller_v1_0_AXI_inst.rasterizer_done == 1'b1);
            @(posedge aclk);
            
            $display("  Triangle rasterization complete!");
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

        // Triangle 1: Red, farther back (Z=50)
        draw_triangle(
            9'd40, 8'd20,    // V1
            9'd140, 8'd120,  // V2
            9'd40, 8'd120,   // V3
            8'hE0,           // Red (RGB332: 111_000_00)
            16'd50, 16'd50, 16'd50
        );

        // Triangle 2: Green, closer (Z=10)
        draw_triangle(
            9'd140, 8'd20,   // V1
            9'd90, 8'd70,    // V2
            9'd190, 8'd70,   // V3
            8'h1C,           // Green (RGB332: 000_111_00)
            16'd10, 16'd10, 16'd10
        );

        // Triangle 3: Blue with Z gradient
        draw_triangle(
            9'd20, 8'd140,
            9'd70, 8'd200,
            9'd20, 8'd200,
            8'h03,           // Blue (RGB332: 000_000_11)
            16'd10, 16'd100, 16'd10
        );

        $display("\nAll triangles submitted. Waiting for display...");

        // Wait for vsync to swap buffers and display
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
        save_bmp("pipeline_test.bmp");
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

    // Timeout watchdog
    initial begin
        #100000000; // 100ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule