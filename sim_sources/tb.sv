`define SIM_VIDEO // Uncomment to simulate entire screen and write BMP

module hdmi_framebuffer_direct_tb();

// ----------------------------------------------------
// 1. Clock and Reset Signals (Kept from original)
// ----------------------------------------------------
logic aclk = 1'b0;
logic arstn = 1'b0; // Active-Low System Reset (0 = Reset)

// Internal Active-High reset derived from arstn, used to reset counters
logic reset_en;
assign reset_en = ~arstn; 

// ----------------------------------------------------
// 2. Video Signals and BMP (Kept from original, but driven by TB logic)
// ----------------------------------------------------
    logic [3:0] red, green, blue; // Output pixel RGB
    logic pixel_clk = 1'b0;
logic pixel_hs, pixel_vs, pixel_vde; // Timing signals from internal VGA logic
    logic [9:0] drawX, drawY; // Pixel coordinates from internal VGA logic

    // BMP writer related signals    
    localparam BMP_WIDTH  = 640; // Use 640x480 resolution for display
    localparam BMP_HEIGHT = 480;
    logic [23:0] bitmap [BMP_WIDTH][BMP_HEIGHT];
    integer i,j; 

// ----------------------------------------------------
// 3. Direct Framebuffer (VRAM) Interface
// ----------------------------------------------------
// Write Port A (Used by TB tasks to write pixels)
logic fb_wea;
logic [16:0] fb_addra;
logic [7:0] fb_dina;

// Read Port B (Used by VGA logic to read pixels)
logic [16:0] fb_addrb;
logic [7:0] fb_doutb;

// ----------------------------------------------------
// 4. DUT Instantiation (The actual framebuffer memory)
// NOTE: You must provide a 'framebuffer' module file for this to compile.
// ----------------------------------------------------
framebuffer fb_inst (
    .clk(aclk),
    .wea(fb_wea),
    .addra(fb_addra),
    .dina(fb_dina),
    .addrb(fb_addrb),
    .doutb(fb_doutb)
);

// ----------------------------------------------------
// 5. VGA Timing Generator (Simulates the missing controller logic)
// We assume 640x480 @ 60Hz timing constants
// ----------------------------------------------------
localparam H_DISPLAY = 640;
localparam V_DISPLAY = 480;
localparam H_FRONT = 16;
localparam H_SYNC = 96;
localparam H_BACK = 48;
localparam H_TOTAL = H_DISPLAY + H_FRONT + H_SYNC + H_BACK; // 800

localparam V_FRONT = 10;
localparam V_SYNC = 2;
localparam V_BACK = 33;
localparam V_TOTAL = V_DISPLAY + V_FRONT + V_SYNC + V_BACK; // 525

logic [9:0] h_counter = 10'd0;
logic [9:0] v_counter = 10'd0;

// Simulating the 25MHz Pixel Clock (Clock Wizard replacement)
always begin : PIXEL_CLOCK_GENERATION
    #20 pixel_clk = ~pixel_clk; // 40ns period (25MHz)
end

// VGA Counter and Sync Logic
always @(posedge pixel_clk) begin
    if (reset_en) begin
        h_counter <= 10'd0;
        v_counter <= 10'd0;
        pixel_hs <= 1'b0;
        pixel_vs <= 1'b0;
        pixel_vde <= 1'b0;
        drawX <= 10'd0;
        drawY <= 10'd0;
    end else begin
        // Horizontal Counter
        if (h_counter == H_TOTAL - 1) begin
            h_counter <= 10'd0;
            // Vertical Counter
            if (v_counter == V_TOTAL - 1)
                v_counter <= 10'd0;
            else
                v_counter <= v_counter + 1;
        end else begin
            h_counter <= h_counter + 1;
        end
        
        // Generate Timing Signals
        pixel_hs <= (h_counter >= (H_DISPLAY + H_FRONT)) && 
                    (h_counter < (H_DISPLAY + H_FRONT + H_SYNC));
        pixel_vs <= (v_counter >= (V_DISPLAY + V_FRONT)) && 
                    (v_counter < (V_DISPLAY + V_FRONT + V_SYNC));
        pixel_vde <= (h_counter < H_DISPLAY) && (v_counter < V_DISPLAY);
        
        // Update DrawX/DrawY 
        if (pixel_vde) begin
            drawX <= h_counter;
            drawY <= v_counter;
        end else begin
            drawX <= 10'd0;
            drawY <= 10'd0;
        end
    end
end

// ----------------------------------------------------
// 6. Framebuffer Read and Color Decode Logic
// ----------------------------------------------------
// Address scale: Read 640x480 display from 320x240 buffer (320*240 = 76800 addresses)
// The framebuffer address is (Y / 2 * 320) + (X / 2)
assign fb_addrb = (drawY >> 1) * 320 + (drawX >> 1);

// Color Decode: Assume RGB 332 format (R[7:5], G[4:2], B[1:0])
logic [7:0] pixel_data;
assign pixel_data = fb_doutb;

// Extract 3 bits for R, 3 for G, 2 for B, and pad to 4-bit output
assign red   = {pixel_data[7:5], 1'b0};
assign green = {pixel_data[4:2], 1'b0};
assign blue  = {pixel_data[1:0], 2'b0};

// ----------------------------------------------------
// 7. AXI Write/Read Tasks (REMOVED)
// ----------------------------------------------------

// ----------------------------------------------------
// 8. Direct Framebuffer Access Tasks (NEW)
// ----------------------------------------------------

// Function to convert RGB888 (input) to RGB332 (output)
function logic [7:0] rgb332(input logic [7:0] r, input logic [7:0] g, input logic [7:0] b);
    return {r[7:5], g[7:5], b[7:6]};
endfunction

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
                write_pixel(x, y, color);
            end
        end
    end
endtask

// ----------------------------------------------------
// 9. BMP Writing Task (Copied from original)
// ----------------------------------------------------
task save_bmp(string bmp_file_name);
        begin
            integer unsigned fout_bmp_pointer, BMP_file_size, BMP_row_size, r;
            logic unsigned [31:0] BMP_header[0:12];
        
            BMP_row_size  = 32'(BMP_WIDTH * 3) & 32'hFFFC;
        if (((BMP_WIDTH * 3) & 32'd3) != 0) BMP_row_size  = BMP_row_size + 4;
    
        fout_bmp_pointer= $fopen(bmp_file_name,"wb");
        if (fout_bmp_pointer==0) begin
            $display("Could not open file '%s' for writing",bmp_file_name);
            $stop;
        end
        $display("Saving bitmap '%s'.",bmp_file_name);
       
        BMP_header[0:12] = '{BMP_file_size,0,0054,40,BMP_WIDTH,BMP_HEIGHT,{16'd24,16'd1},0,(BMP_row_size*BMP_HEIGHT),2835,2835,0,0};
        
        //Write header out      
        $fwrite(fout_bmp_pointer,"BM");
        for (int i =0 ; i <13 ; i++ ) 
        $fwrite(fout_bmp_pointer,"%c%c%c%c",BMP_header[i][7:0],BMP_header[i][15:8],BMP_header[i][23:16],BMP_header[i][31:24]); 
        
        //Write image out (note that image is flipped in Y)
        for (int y=BMP_HEIGHT-1;y>=0;y--) begin
          for (int x=0;x<BMP_WIDTH;x++)
            $fwrite(fout_bmp_pointer,"%c%c%c",bitmap[x][y][23:16],bitmap[x][y][15:8],bitmap[x][y][7:0]) ;
        end
    
        $fclose(fout_bmp_pointer);
        end
    endtask

// ----------------------------------------------------
// 10. Pixel Capture and Bitmap Initialization (Modified to use reset_en)
// ----------------------------------------------------
    always@(posedge pixel_clk)
        if (reset_en) begin // Use Active-High reset_en
            for (j = 0; j < BMP_HEIGHT; j++)    
                for (i = 0; i < BMP_WIDTH; i++) 
                    bitmap[i][j] <= 24'h000040; // Default Dark Blue
        end
        else
            if (pixel_vde) //Only draw when not in the blanking interval
                // Scale 4-bit (R4G4B4) to 8-bit per channel (R8G8B8) for BMP
                bitmap[drawX][drawY] <= {{red, red[3:0]}, {green, green[3:0]}, {blue, blue[3:0]}};
  
// ----------------------------------------------------
// 11. Clock and Test Sequence (Kept and simplified)
// ----------------------------------------------------
initial begin: CLOCK_INITIALIZATION
   aclk = 1'b1;
    fb_wea = 1'b0;
    end 
       
    always begin : CLOCK_GENERATION
        #5 aclk = ~aclk;
    end

initial begin: TEST_VECTORS
    // Assert reset (arstn = 0)
    arstn = 0;
    repeat (10) @(posedge aclk);
    // Release reset (arstn = 1)
    arstn <= 1;
    
    $display("Starting direct framebuffer write test...");

    // --- Framebuffer Drawing ---
    draw_rect(0, 0, 320, 240, rgb332(8'h00, 8'h00, 8'h40)); // Dark Blue Clear
    draw_rect(10, 10, 50, 30, rgb332(8'hFF, 8'h00, 8'h00));   // Red
    draw_rect(70, 10, 50, 30, rgb332(8'h00, 8'hFF, 8'h00));   // Green
    draw_rect(130, 10, 50, 30, rgb332(8'h00, 8'h00, 8'hFF));  // Blue
    
    // Gradient Bar
    for (i = 0; i < 320; i++) begin
        logic [7:0] gray = i * 255 / 320;
        draw_rect(i, 130, 1, 20, rgb332(gray, gray, gray));
    end

    // Checkerboard
    for (j = 160; j < 230; j++) begin
        for (i = 10; i < 150; i++) begin
            if (((i / 10) + (j / 10)) % 2 == 0)
                write_pixel(i, j, rgb332(8'hFF, 8'hFF, 8'hFF)); // White
            else
                write_pixel(i, j, rgb332(8'h00, 8'h00, 8'h00)); // Black
        end
    end

    $display("Finished writing to framebuffer. Waiting for frame capture...");
    
    //Simulate until VS goes low (indicating a new frame) and write the results
    `ifdef SIM_VIDEO
    // Wait for the pixel clock to stabilize and the VGA controller to start running
    repeat (2000) @(posedge aclk);
    
    wait (~pixel_vs); // Wait for the first falling edge of VS
    wait (pixel_vs);  // Wait for the rising edge
    wait (~pixel_vs); // Wait for the second falling edge (guarantees a full frame capture)
    
    save_bmp ("sim.bmp");
    `endif
    
    $display("Test complete.");
    $finish();
end

endmodule