module framebuffer#(
    parameter ADDR_WIDTH = 17
)(
    input logic clk,
    input logic vsync,
    input logic rst,

    //GPU side
    input logic wea,
    input logic [ADDR_WIDTH-1:0] addra,
    input logic [7:0] dina,

    //VGA side
    input logic [ADDR_WIDTH-1:0] addrb,
    output logic [7:0] doutb
);

logic front;
logic prev_vsync_sync;
logic vsync_sync1;
logic vsync_sync2;
always_ff @(posedge clk) begin
    vsync_sync1 <= vsync;
    vsync_sync2 <= vsync_sync1;
end

//Used to prevent clock domain crossing since the memory runs at 100 MHz and vsync is at 25 MHz, causes front to trigger multiple times.
always_ff @(posedge clk) begin
    if (rst) begin
        front           <= 1'b0;
        prev_vsync_sync <= 1'b0;
    end 
    else begin
        prev_vsync_sync <= vsync_sync2;
        if (prev_vsync_sync & ~vsync_sync2) begin
            front <= ~front;
        end
    end
end

logic frontbuf_ena;
logic frontbuf_enb;
logic frontbuf_wea;
logic frontbuf_web;
logic [ADDR_WIDTH-1:0] frontbuf_addra; // MIGHT HAVE TO CHANGE WIDTH
logic [ADDR_WIDTH-1:0] frontbuf_addrb;
logic [7:0] frontbuf_dina;
logic [7:0] frontbuf_dinb;
logic [7:0] frontbuf_douta;
logic [7:0] frontbuf_doutb; 

logic backbuf_ena;
logic backbuf_enb;
logic backbuf_wea;
logic backbuf_web;
logic [ADDR_WIDTH-1:0] backbuf_addra; // MIGHT HAVE TO CHANGE WIDTH
logic [ADDR_WIDTH-1:0] backbuf_addrb;
logic [7:0] backbuf_dina;
logic [7:0] backbuf_dinb;
logic [7:0] backbuf_douta;
logic [7:0] backbuf_doutb; 

assign frontbuf_web = 'b0;
assign backbuf_web = 'b0;
assign frontbuf_dinb = 'b0;
assign backbuf_dinb = 'b0;
assign frontbuf_ena = 'b1;
assign backbuf_ena = 'b1;
assign frontbuf_enb = 'b1;
assign backbuf_enb = 'b1;

//Make frame buffer here.
//True Dual Port
//Byte Write Enable (8 bit bytes)
//Write width: 8
//Write depth: >= 768000
//320 * 240 * 1 B = 76.8 kB
//width: 8 bits (8-bit colorspace)
blk_mem_gen_0 front_buffer(
    .clka(clk),
    .clkb(clk),
    .ena(frontbuf_ena),
    .enb(frontbuf_enb),
    .wea(frontbuf_wea),
    .web(frontbuf_web),
    .addra(frontbuf_addra),
    .addrb(frontbuf_addrb),
    .dina(frontbuf_dina),
    .dinb(frontbuf_dinb),
    .douta(frontbuf_douta),
    .doutb(frontbuf_doutb)
);

// Double buffering
blk_mem_gen_0 back_buffer(
    .clka(clk),
    .clkb(clk),
    .ena(backbuf_ena),
    .enb(backbuf_enb),
    .wea(backbuf_wea),
    .web(backbuf_web),
    .addra(backbuf_addra),
    .addrb(backbuf_addrb),
    .dina(backbuf_dina),
    .dinb(backbuf_dinb),
    .douta(backbuf_douta),
    .doutb(backbuf_doutb)
);


always_comb begin
    if(front) begin
        //front is write buffer
        frontbuf_wea   = wea;
        frontbuf_addra = addra;
        frontbuf_dina  = dina;
        frontbuf_addrb = 'b0;

        // BACK is read buffer
        backbuf_wea   = 'b0;
        backbuf_addra = 'b0;
        backbuf_dina  = 'b0;
        backbuf_addrb = addrb;
        doutb = backbuf_doutb;
    end else begin
        //back is write buffer
        backbuf_wea   = wea;
        backbuf_addra = addra;
        backbuf_dina  = dina;
        backbuf_addrb = 'b0;

        // FRONT is read buffer
        frontbuf_wea   = 'b0;
        frontbuf_addra = 'b0;
        frontbuf_dina  = 'b0;
        frontbuf_addrb = addrb;
        doutb = frontbuf_doutb;
    end
end
endmodule