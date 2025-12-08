`timescale 1 ns / 1 ps
`define SIM_VIDEO // Defines whether to generate BMP

module tb_triangle_pipeline();

    // =========================================================================
    // 1. Clock & Reset Generation
    // =========================================================================
    logic aclk = 0;
    logic arstn = 0;
    always #5 aclk = ~aclk; // 100MHz

    // =========================================================================
    // 2. DUT Instantiation
    // =========================================================================
    // AXI signals (tied off as we are bypassing them)
    logic [31:0] axi_dummy_signals; // Placeholder
    
    // HDMI Outputs
    logic hdmi_clk_n, hdmi_clk_p;
    logic [2:0] hdmi_tx_n, hdmi_tx_p;

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
        // Tie off AXI inputs
        .axi_awaddr(0), .axi_awprot(0), .axi_awvalid(0), .axi_awready(),
        .axi_wdata(0), .axi_wstrb(0), .axi_wvalid(0), .axi_wready(),
        .axi_bresp(), .axi_bvalid(), .axi_bready(0),
        .axi_araddr(0), .axi_arprot(0), .axi_arvalid(0), .axi_arready(),
        .axi_rdata(), .axi_rresp(), .axi_rvalid(), .axi_rready(0)
    );

    // =========================================================================
    // 3. Hierarchical Shortcuts
    // =========================================================================
    // These allow us to "reach inside" the DUT to see/drive signals
    
    // Pointer to the Controller Instance
    localparam string PATH = "dut.hdmi_text_controller_v1_0_AXI_inst";
    
    // Monitor signals for debugging
    logic [1:0] controller_state;
    assign controller_state = dut.hdmi_text_controller_v1_0_AXI_inst.controller_state;
    
    logic triangle_ready;
    assign triangle_ready = dut.hdmi_text_controller_v1_0_AXI_inst.triangle_ready;
    
    logic rasterizer_done;
    assign rasterizer_done = dut.hdmi_text_controller_v1_0_AXI_inst.rasterizer_done;

    // =========================================================================
    // 4. BMP Generation Logic (From your provided code) - MINIMAL EDITS
    // =========================================================================
    localparam BMP_WIDTH  = 640;
    localparam BMP_HEIGHT = 480;
    // Framebuffer is 8-bit RGB332
    logic [7:0] bitmap [BMP_WIDTH][BMP_HEIGHT];
    integer i, j;
    logic pixel_clk, pixel_vde;
    logic [9:0] drawX, drawY;
    logic [3:0] red, green, blue;

    assign pixel_clk = dut.clk_25MHz;
    assign pixel_vde = dut.vde;
    assign drawX = dut.drawX;
    assign drawY = dut.drawY;
    assign red = dut.red;
    assign green = dut.green;
    assign blue = dut.blue;

    // Capture pixel: convert DUT red[3:0],green[3:0],blue[3:0] -> RGB332 (8-bit)
    // RGB332 mapping: [7:5]=R (3 bits from red[3:1]), [4:2]=G (3 bits from green[3:1]), [1:0]=B (2 bits from blue[3:2])
    always @(posedge pixel_clk) begin
        if (!arstn) begin
            for (j = 0; j < BMP_HEIGHT; j = j + 1)
                for (i = 0; i < BMP_WIDTH; i = i + 1)
                    bitmap[i][j] <= 8'h00; // Black Background (RGB332=0)
        end else if (pixel_vde) begin
            bitmap[drawX][drawY] <= { red[3:1], green[3:1], blue[3:2] };
        end
    end

    // Save BMP: expand RGB332 -> RGB888 when writing file
    task save_bmp(string bmp_file_name);
        integer unsigned fout, size, row_size;
        logic unsigned [31:0] header[0:12];
        byte r8, g8, b8;
        byte c;
        row_size = 32'(BMP_WIDTH * 3) & 32'hFFFC;
        if (((BMP_WIDTH * 3) & 32'd3) != 0) row_size = row_size + 4;
        fout = $fopen(bmp_file_name, "wb");
        if (fout == 0) begin $display("Error opening BMP"); $stop; end
        $display("Saving %s...", bmp_file_name);
        header[0:12] = '{size, 0, 54, 40, BMP_WIDTH, BMP_HEIGHT, {16'd24, 16'd1}, 0, row_size*BMP_HEIGHT, 2835, 2835, 0, 0};
        $fwrite(fout, "BM");
        for (int k=0; k<13; k++) $fwrite(fout, "%c%c%c%c", header[k][7:0], header[k][15:8], header[k][23:16], header[k][31:24]);
        for (int y=BMP_HEIGHT-1; y>=0; y--)
            for (int x=0; x<BMP_WIDTH; x++) begin
                c = bitmap[x][y];
                // Expand RGB332 -> RGB888 by simple scaling
                // r3 = c[7:5], g3 = c[4:2], b2 = c[1:0]
                r8 = ( (c[7:5] * 255) / 7 );
                g8 = ( (c[4:2] * 255) / 7 );
                b8 = ( (c[1:0] * 255) / 3 );
                $fwrite(fout, "%c%c%c", r8, g8, b8);
            end
        $fclose(fout);
    endtask

    // =========================================================================
    // 5. Tasks for Simulation Control
    // =========================================================================

    // Task to clear the Z-Buffer via backdoor (omitted per request; ignoring loop)
    task clear_z_buffer();
        $display("clear_z_buffer: omitted in this minimal testbench (simulation only)");
    endtask

    // Task to feed a triangle into the pipeline
    task draw_triangle(
        input logic [8:0] x1, input logic [7:0] y1,
        input logic [8:0] x2, input logic [7:0] y2,
        input logic [8:0] x3, input logic [7:0] y3,
        input logic [7:0] color_in,
        input logic [15:0] z1_in, input logic [15:0] z2_in, input logic [15:0] z3_in
    );
        // Variables for calculation
        int area_x2;          // Result of the 2*Area cross product
        real inv_area_real;   // Floating point inverse area
        logic [31:0] inv_area_fixed; // 32-bit fixed point for hardware (8.24)
        
        begin
            // 1. Calculate Area * 2
            // Note: inputs are unsigned; cast to signed int for area calc to allow negative cross products
            area_x2 = (int'(x1)*(int'(y2) - int'(y3)) + int'(x2)*(int'(y3) - int'(y1)) + int'(x3)*(int'(y1) - int'(y2)));
            if (area_x2 < 0) area_x2 = -area_x2;
            
            // 2. Calculate Fixed Point Inverse Area (8.24 format)
            if (area_x2 == 0) begin
                $display("Warning: Triangle has 0 area, skipping.");
                return;
            end
            
            // 2a. Calculate floating point value
            inv_area_real = (1.0 / real'(area_x2)) * 16777216.0; // 2^24
            
            // 2b. Convert real to 32-bit logic using $unsigned()
            inv_area_fixed = $unsigned(inv_area_real);
            
            $display("Feeding Triangle: (%0d,%0d), (%0d,%0d), (%0d,%0d) Color: %h", x1,y1,x2,y2,x3,y3, color_in);
            // 3. Wait for Controller to be Ready
            wait(dut.hdmi_text_controller_v1_0_AXI_inst.triangle_ready == 1'b1);
            @(posedge aclk);

            // 4. Drive Signals via Hierarchy
            dut.hdmi_text_controller_v1_0_AXI_inst.v1x <= x1;
            dut.hdmi_text_controller_v1_0_AXI_inst.v1y <= y1;
            dut.hdmi_text_controller_v1_0_AXI_inst.v2x <= x2;
            dut.hdmi_text_controller_v1_0_AXI_inst.v2y <= y2;
            dut.hdmi_text_controller_v1_0_AXI_inst.v3x <= x3;
            dut.hdmi_text_controller_v1_0_AXI_inst.v3y <= y3;
            dut.hdmi_text_controller_v1_0_AXI_inst.color <= color_in;
            dut.hdmi_text_controller_v1_0_AXI_inst.inv_area <= inv_area_fixed;
            // Z-values
            dut.hdmi_text_controller_v1_0_AXI_inst.z1 <= z1_in;
            dut.hdmi_text_controller_v1_0_AXI_inst.z2 <= z2_in;
            dut.hdmi_text_controller_v1_0_AXI_inst.z3 <= z3_in;

            // Assert Valid
            dut.hdmi_text_controller_v1_0_AXI_inst.triangle_valid <= 1'b1;

            // 5. Hold for one clock cycle
            @(posedge aclk);

            // 6. Deassert Valid
            dut.hdmi_text_controller_v1_0_AXI_inst.triangle_valid <= 1'b0;
            
            // 7. Wait for Rasterizer to finish this triangle
            wait(dut.hdmi_text_controller_v1_0_AXI_inst.rasterizer_done == 1'b1);
            @(posedge aclk);
            $display("Triangle Rasterization Done.");
        end
    endtask

    // =========================================================================
    // 6. Main Test Sequence
    // =========================================================================
    initial begin
        // Reset
        arstn = 0;
        // Ensure inputs are 0 initially
        dut.hdmi_text_controller_v1_0_AXI_inst.triangle_valid <= 0;
        #100;
        arstn = 1;
        
        $display("Waiting for clock lock...");
        wait(dut.locked);
        #1000;

        // NOTE ON Z-BUFFER: omitted the backdoor clearing per request.

        // --- Triangle 1: Red, Background (Z=50) ---
        draw_triangle(
            40, 20,    // V1
            140, 120,  // V2
            40, 120,   // V3
            8'hE0,     // RGB332 = 1110_0000
            50, 50, 50
        );

        // --- Triangle 2: Green, Foreground (Z=10) ---
        draw_triangle(
            140, 20,   // V1
            90, 70,    // V2
            190, 70,   // V3
            8'h1C,     // RGB332 = 0001_1100
            10, 10, 10
        );
        
        // --- Triangle 3: Gradient Z Test ---
        draw_triangle(
            20, 140,
            70, 200,
            20, 200,
            8'h03,    // RGB332 = 0000_0011
            10, 100, 10
        );

        $display("All triangles fed. Waiting for frame VSync...");

        // Wait for VSYNC to ensure image is latched to display
        wait(dut.vsync == 0);
        wait(dut.vsync == 1);
        wait(dut.vsync == 0);
        
        #100000; // Wait a bit more for rendering to finish if pipeline is deep
        
        save_bmp("pipeline_test.bmp");
        $display("BMP Saved. Test Finished.");
        $finish;
    end

endmodule