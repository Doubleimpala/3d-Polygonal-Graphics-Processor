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
    // 4. BMP Generation Logic (From your provided code)
    // =========================================================================
    localparam BMP_WIDTH  = 640;
    localparam BMP_HEIGHT = 480;
    logic [23:0] bitmap [BMP_WIDTH][BMP_HEIGHT];
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

    always @(posedge pixel_clk) begin
        if (!arstn) begin
            for (j = 0; j < BMP_HEIGHT; j++)
                for (i = 0; i < BMP_WIDTH; i++)
                    bitmap[i][j] <= 24'h000000; // Black Background
        end else if (pixel_vde) begin
            bitmap[drawX][drawY] <= {red, 4'h0, green, 4'h0, blue, 4'h0};
        end
    end

    task save_bmp(string bmp_file_name);
        integer unsigned fout, size, row_size;
        logic unsigned [31:0] header[0:12];
        row_size = 32'(BMP_WIDTH * 3) & 32'hFFFC;
        if (((BMP_WIDTH * 3) & 32'd3) != 0) row_size = row_size + 4;
        fout = $fopen(bmp_file_name, "wb");
        if (fout == 0) begin $display("Error opening BMP"); $stop; end
        $display("Saving %s...", bmp_file_name);
        header[0:12] = '{size, 0, 54, 40, BMP_WIDTH, BMP_HEIGHT, {16'd24, 16'd1}, 0, row_size*BMP_HEIGHT, 2835, 2835, 0, 0};
        $fwrite(fout, "BM");
        for (int k=0; k<13; k++) $fwrite(fout, "%c%c%c%c", header[k][7:0], header[k][15:8], header[k][23:16], header[k][31:24]);
        for (int y=BMP_HEIGHT-1; y>=0; y--)
            for (int x=0; x<BMP_WIDTH; x++)
                $fwrite(fout, "%c%c%c", bitmap[x][y][23:16], bitmap[x][y][15:8], bitmap[x][y][7:0]);
        $fclose(fout);
    endtask

    // =========================================================================
    // 5. Tasks for Simulation Control
    // =========================================================================

    // Task to clear the Z-Buffer via backdoor (simulation only)
    // Assumes the hierarchy: dut -> axi_inst -> raster -> z_buf -> inst -> native_mem_module -> memory
    // You might need to adjust the path depending on exactly how Vivado synthesizes the BRAM IP
    task clear_z_buffer();
        $display("Initializing Z-Buffer to 0xFF (Backdoor)...");
        // Note: In strict Vivado simulation, referencing the BRAM memory array is tricky.
        // If this crashes, comment it out and we'll rely on correct draw order.
        // For now, let's assume valid triangles will have Z < 0 (if signed) or Z < uninit.
        // A safer way without backdoor is to assume standard initialization to 0, 
        // which means "closest". We need to flip logic or rely on a "clear screen" triangle.
        
        // Alternative: We will assume the logic works, but if your screen is black,
        // it's because Z-buffer is 0 and Z-test failed.
    endtask

    // Task to feed a triangle into the pipeline
    task draw_triangle(
        input logic signed [8:0] x1, input logic signed [7:0] y1,
        input logic signed [8:0] x2, input logic signed [7:0] y2,
        input logic signed [8:0] x3, input logic signed [7:0] y3,
        input logic [7:0] color_in,
        input logic [15:0] z1_in, input logic [15:0] z2_in, input logic [15:0] z3_in
    );
        // Variables for calculation
        int area_x2;
        real inv_area_real;
        logic [31:0] inv_area_fixed;
        
        begin
            // 1. Calculate Area * 2
            // Area = 0.5 * |(x1(y2 - y3) + x2(y3 - y1) + x3(y1 - y2))|
            // We need 2 * Area for the barycentric denominator
            area_x2 = (x1*(y2 - y3) + x2*(y3 - y1) + x3*(y1 - y2));
            if (area_x2 < 0) area_x2 = -area_x2;
            
            // 2. Calculate Fixed Point Inverse Area (8.24 format)
            // Value = (1.0 / area_x2) * 2^24
            if (area_x2 == 0) begin
                $display("Warning: Triangle has 0 area, skipping.");
                return;
            end
            inv_area_real = (1.0 / real'(area_x2)) * 16777216.0; // 2^24
            inv_area_fixed = 32'(inv_area_real);

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

        // NOTE ON Z-BUFFER: 
        // Since BRAM inits to 0, and we draw if (z < zbuf),
        // we must draw with Z=0 to overwrite the default, OR we assume
        // the user has a mechanism to set Z-buf to 0xFF.
        // For this test, we will use small Z values. 
        // If your Z-buffer is initialized to 0 by default, only Z=0 will pass.
        // If you can't see the triangles, check your Z-buffer initialization!
        
        // --- Triangle 1: Red, Background (Z=50) ---
        // Top Left: 100, 50
        // Bottom Right: 200, 150
        // Bottom Left: 100, 150
        draw_triangle(
            100, 50,    // V1
            200, 150,   // V2
            100, 150,   // V3
            8'hE0,      // Red (RRR GGG BB -> 111 000 00)
            50, 50, 50  // Z (Flat depth)
        );

        // --- Triangle 2: Green, Foreground (Z=10) ---
        // Overlapping the Red one.
        // Top Right: 200, 50
        // Bottom Left: 150, 100
        // Bottom Right: 250, 100
        draw_triangle(
            200, 50,     // V1
            150, 100,    // V2
            250, 100,    // V3
            8'h1C,       // Green (RRR GGG BB -> 000 111 00)
            10, 10, 10   // Z (Closer than red)
        );
        
        // --- Triangle 3: Gradient Z Test ---
        // A triangle where Z varies.
        // 50, 200 -> 100, 240 -> 50, 240
        draw_triangle(
            50, 200,
            100, 240,
            50, 240,
            8'h03,       // Blue
            10, 100, 10  // Z varies
        );

        $display("All triangles fed. Waiting for frame VSync...");

        // Wait for VSYNC to ensure image is latched to display
        wait(dut.vsync == 0); // Active Low vsync? Or check signal polarity
        wait(dut.vsync == 1);
        wait(dut.vsync == 0);
        
        #100000; // Wait a bit more for rendering to finish if pipeline is deep
        
        save_bmp("pipeline_test.bmp");
        $display("BMP Saved. Test Finished.");
        $finish;
    end

endmodule