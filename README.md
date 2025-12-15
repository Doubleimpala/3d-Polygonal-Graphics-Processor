# Instructions
1. Set up Lab 7.2 exactly as per 15.1 Introduction to AXI4-lite and HDMI (rev 2)-1.pdf document (can't link because document is on Canvas).
2. Import design_sources/* into the hdmi_text_controller custom IP as design sources (replace the top level and AXI files)
3. Import sim_sources/* into the hdmi_text_controller custom IP as simulation sources
4. Import software_sources/* into Vitis. The mesh used in the demo is provided in the header file.
5. Generate bitstream in Vivado, then build and run in Vitis!

# IP Setup.
1. Our double frame buffers use 1 memory address per pixel. Since we are upscaling a 320x240 VGA signal to 640x480, we have 2 frame buffer BRAM modules with 17 bit addresses and a depth of 76800. They must be true dual port, and preloaded with values of 0. Name this IP blk_mem_gen_0.
2. We have a single port zbuffer which has 16 bit wide values. Therefore it has an 18 bit address and a depth of 153600. Name this IP blk_mem_gen_1.
3. We also have a hardware FIFO to coordinate AXI transfers. This way we can queue triangles from the microblaze in the FIFO until the hardware is ready to rasterize them. Initialize this with a write width of 192 bits, and a depth of 32.
4. Clocking wizard inside the hdmi_text_controller IP is set up with 100 MHz input, and one output at 25 MHz (approx. VGA clocking speed) and the other one at 125 MHz (5x clock).

# Microblaze and I/O setup.
1. Set up the microblaze with a 16 Kb memory size. When Vitis has opened, use a following linker flag to increase the runtime stack size to x4000 (without this some functions may not run due to insufficient stack space).
2. To display UART outputs or use the keyboard (not implemented but set up) you must add the AXI UART IP, as well as a few AXI GPIO IPs to set up the keyboard keycode capturing, inturrupt signals and other required IPs. Since we did not implement the keyboard, we will not go into detail on how to set it up.