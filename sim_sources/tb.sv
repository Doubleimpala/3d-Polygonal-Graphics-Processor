`define SIM_VIDEO // Uncomment to simulate entire screen and write BMP

module framebuffer_tb_direct();

    // Clock and reset signals
    logic aclk = 1'b0;
    logic arstn = 1'b0;
    
    // VGA timing signals (Testbench generated)
    logic [9:0] drawX = 10'd0;
    logic [9:0] drawY = 10'd0;
    logic pixel_clk = 1'b0;
    logic pixel_hs = 1'b0;
    logic pixel_vs = 1'b1;
    logic pixel_vde = 1'b0;
    
    // Output RGB signals (from framebuffer read/decode)
    logic [3:0] red, green, blue;
    
    // Direct framebuffer access signals (Write side - used by TB tasks)
    logic fb_wea;
    logic [16:0] fb_addra;
    logic [7:0] fb_dina;
    
    // Direct framebuffer access signals (Read side - connected to VGA logic)
    logic [16:0] fb_addrb;
    logic [7:0] fb_doutb;
    
    // BMP writer related signals    
    // We use the 640x480 resolution (from your first post's timing constants) 
    // to match the 320x240 half-resolution framebuffer size.
    localparam H_DISPLAY = 640;
    localparam V_DISPLAY = 480;
    localparam BMP_WIDTH  = H_DISPLAY;
    localparam BMP_HEIGHT = V_DISPLAY;
    logic [23:0] bitmap [BMP_WIDTH][BMP_HEIGHT];
    integer i, j;

    // 1. Instantiate the framebuffer directly (The DUT)
    // Assuming the interface is: .clk, .wea, .addra, .dina, .addrb, .doutb
    framebuffer fb_inst (
        .clk(aclk),
        .wea(fb_wea),
        .addra(fb_addra),
        .dina(fb_dina),
        .addrb(fb_addrb),
        .doutb(fb_doutb)
    );
    
    // 2. Simulate the read-side logic (This is the logic that was inside your AXI IP)
    // Framebuffer is 320x240, read at 640x480 resolution (pixel doubling is implied by address scaling)
    // The framebuffer address is (Y * 320) + X. 
    // We use the VGA controller's pixel coordinates (drawX, drawY) but only use the most significant bits (halved) 
    // to address the 320x240 framebuffer.
    assign fb_addrb = (drawY >> 1) * 320 + (drawX >> 1);
    
    // Color Decode Logic (RGB 332 format: R[7:5], G[4:2], B[1:0])
    logic [7:0] pixel_data;
    assign pixel_data = fb_doutb;
    
    logic [3:0] r, g, b;
    // Extract 3 bits for R, 3 for G, 2 for B, and pad to 4-bit output
    assign r = {pixel_data[7:5], 1'b0};
    assign g = {pixel_data[4:2], 1'b0};
    assign b = {pixel_data[1:0], 2'b0};
    
    assign red = r;
    assign green = g;
    assign blue = b;

    // --- Clock Generation ---
    initial begin: CLOCK_INITIALIZATION
        aclk = 1'b0;
        pixel_clk = 1'b0;
    end 
       
    always begin : CLOCK_GENERATION
        #5 aclk = ~aclk;  // 100MHz system clock
    end
    
    always begin : PIXEL_CLOCK_GENERATION
        #20 pixel_clk = ~pixel_clk;  // 25MHz pixel clock (40ns period)
    end

    // --- VGA Timing Generator (640x480 @ 60Hz) ---
    localparam H_FRONT = 16;
    localparam H_SYNC = 96;
    localparam H_BACK = 48;
    localparam H_TOTAL = BMP_WIDTH + H_FRONT + H_SYNC + H_BACK; // 800
    
    localparam V_FRONT = 10;
    localparam V_SYNC = 2;
    localparam V_BACK = 33;
    localparam V_TOTAL = BMP_HEIGHT + V_FRONT + V_SYNC + V_BACK; // 525
    
    logic [9:0] h_counter = 10'd0;
    logic [9:0] v_counter = 10'd0;
    
    always @(posedge pixel_clk) begin
        if (!arstn) begin
            h_counter <= 10'd0;
            v_counter <= 10'd0;
            pixel_hs <= 1'b0;
            pixel_vs <= 1'b0;
            pixel_vde <= 1'b0;
            drawX <= 10'd0;
            drawY <= 10'd0;
        end else begin
            // Horizontal counter
            if (h_counter == H_TOTAL - 1) begin
                h_counter <= 10'd0;
                // Vertical counter
                if (v_counter == V_TOTAL - 1)
                    v_counter <= 10'd0;
                else
                    v_counter <= v_counter + 1;
            end else begin
                h_counter <= h_counter + 1;
            end
            
            // Generate timing signals
            pixel_hs <= (h_counter >= (BMP_WIDTH + H_FRONT)) && 
                        (h_counter < (BMP_WIDTH + H_FRONT + H_SYNC));
            pixel_vs <= (v_counter >= (BMP_HEIGHT + V_FRONT)) && 
                        (v_counter < (V_DISPLAY + V_FRONT + V_SYNC));
            pixel_vde <= (h_counter < BMP_WIDTH) && (v_counter < BMP_HEIGHT);
            
            // Update DrawX/DrawY only during active display area
            if (pixel_vde) begin
                drawX <= h_counter;
                drawY <= v_counter;
            end else begin
                drawX <= 10'd0;
                drawY <= 10'd0;
            end
        end
    end

    // --- BMP writing task (Copied from original, using BMP_WIDTH/HEIGHT) ---
    task save_bmp(string bmp_file_name);
        begin
            integer unsigned fout_bmp_pointer, BMP_file_size, BMP_row_size, r;
            logic unsigned [31:0] BMP_header[0:12];
        
            BMP_row_size = 32'(BMP_WIDTH * 3) & 32'hFFFC;
            if (((BMP_WIDTH * 3) & 32'd3) != 0) BMP_row_size = BMP_row_size + 4;
    
            fout_bmp_pointer = $fopen(bmp_file_name, "wb");
            if (fout_bmp_pointer == 0) begin
                $display("Could not open file '%s' for writing", bmp_file_name);
                $stop;     
            end
            $display("Saving bitmap '%s'.", bmp_file_name);
       
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
    
    // --- Capture pixels to bitmap ---
    always @(posedge pixel_clk) begin
        if (!arstn) begin
            for (j = 0; j < BMP_HEIGHT; j++)
                for (i = 0; i < BMP_WIDTH; i++)
                    bitmap[i][j] <= 24'h000040; // Dark Blue background
        end else if (pixel_vde) begin
            // Scale 4-bit RGB (R4G4B4) to 8-bit per channel (R8G8B8) for BMP
            // The R, G, B signals are 4 bits: {R[3:0], G[3:0], B[3:0]}.
            // R = {red[3:0], red[3:0]} is a common way to scale 4-bit to 8-bit.
            bitmap[drawX][drawY] <= {red, red[3:0], green, green[3:0], blue, blue[3:0]};
        end
    end

    // --- Direct Write Tasks (Write-Side of Framebuffer) ---
    // Framebuffer is 320x240, addressed 0 to (320*240 - 1)
    
    // Task to write a pixel to framebuffer (RGB332 format)
    task write_pixel(input int x, input int y, input logic [7:0] color);
        begin
            // Ensure coordinates are within the 320x240 buffer size
            if (x < 320 && y < 240) begin
                @(posedge aclk);
                fb_wea = 1'b1;
                fb_addra = y * 320 + x;
                fb_dina = color;
                @(posedge aclk);
                fb_wea = 1'b0;
            end
        end
    endtask
    
    // Task to draw a filled rectangle
    task draw_rect(input int x0, input int y0, input int w, input int h, input logic [7:0] color);
        begin
            for (int y = y0; y < y0 + h; y++) begin
                for (int x = x0; x < x0 + w; x++) begin
                    write_pixel(x, y, color); // Range check is inside write_pixel
                end
            end
        end
    endtask
    
    // Function to convert RGB888 (input) to RGB332 (output)
    function logic [7:0] rgb332(input logic [7:0] r, input logic [7:0] g, input logic [7:0] b);
        return {r[7:5], g[7:5], b[7:6]};
    endfunction

    // --- Main test sequence ---
    initial begin: TEST_VECTORS
        fb_wea = 1'b0;
        fb_addra = 17'd0;
        fb_dina = 8'd0;
        
        // Assert and release reset
        arstn = 1'b0;
        repeat (10) @(posedge aclk);
        arstn <= 1'b1;
        
        $display("Starting framebuffer test...");
        
        // Clear screen to dark blue (via write_pixel task, which is clocked by aclk)
        $display("Clearing screen...");
        draw_rect(0, 0, 320, 240, rgb332(8'h00, 8'h00, 8'h40));
        
        // Draw some test patterns (uses full-brightness 8-bit colors)
        $display("Drawing test patterns...");
        
        draw_rect(10, 10, 50, 30, rgb332(8'hFF, 8'h00, 8'h00));   // Red
        draw_rect(70, 10, 50, 30, rgb332(8'h00, 8'hFF, 8'h00));   // Green
        draw_rect(130, 10, 50, 30, rgb332(8'h00, 8'h00, 8'hFF));  // Blue
        draw_rect(10, 50, 50, 30, rgb332(8'hFF, 8'hFF, 8'h00));   // Yellow
        draw_rect(70, 50, 50, 30, rgb332(8'h00, 8'hFF, 8'hFF));   // Cyan
        draw_rect(130, 50, 50, 30, rgb332(8'hFF, 8'h00, 8'hFF));  // Magenta
        draw_rect(10, 90, 50, 30, rgb332(8'hFF, 8'hFF, 8'hFF));   // White
        
        // Gradient bar
        for (int x = 0; x < 320; x++) begin
            logic [7:0] gray = x * 255 / 320;
            draw_rect(x, 130, 1, 20, rgb332(gray, gray, gray));
        end
        
        // Checkerboard pattern
        for (int y = 160; y < 230; y++) begin
            for (int x = 10; x < 150; x++) begin
                if (((x / 10) + (y / 10)) % 2 == 0)
                    write_pixel(x, y, rgb332(8'hFF, 8'hFF, 8'hFF)); // White
                else
                    write_pixel(x, y, rgb332(8'h00, 8'h00, 8'h00)); // Black
            end
        end
        
        $display("Finished drawing. Waiting for frame to complete...");
        
        // Wait for a complete frame to be displayed
        `ifdef SIM_VIDEO
        wait(~pixel_vs);  // Wait for vsync to go low (start of frame)
        wait(pixel_vs);   // Wait for vsync to go high
        wait(~pixel_vs);  // Wait for vsync to go low again (guarantees a full frame was captured)
        
        $display("Saving BMP...");
        save_bmp("framebuffer_test.bmp");
        `endif
        
        $display("Test complete!");
        $finish();
    end

endmodule