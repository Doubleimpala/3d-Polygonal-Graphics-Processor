/***************************** Include Files *******************************/
#include "hdmi_text_controller.h"
#include "stdio.h"
#include "stdlib.h"
#include "string.h"
#include "sleep.h"

/************************** Function Definitions ***************************/

void paletteTest()
{
	textHDMIColorClr();

	for (int i = 0; i < 8; i ++)
	{
		char color_string[80];
		sprintf(color_string, "Foreground: %d background %d", 2*i, 2*i+1);
		textHDMIDrawColorText (color_string, 0, 2*i, 2*i, 2*i+1);
		sprintf(color_string, "Foreground: %d background %d", 2*i+1, 2*i);
		textHDMIDrawColorText (color_string, 40, 2*i, 2*i+1, 2*i);
	}
	textHDMIDrawColorText ("The above text should cycle through random colors", 0, 25, 0, 1);


	for (int i = 0; i < 10; i++)
	{
		sleep_MB (1);
		for (int j = 0; j < 16; j++)
			setColorPalette(j, 	rand() % 16, rand() % 16,rand() % 16); //set color 0 to random color;

	}
}

void textHDMIColorClr()
{
	for (int i = 0; i<(ROWS*COLUMNS) * 2; i++)
	{
		hdmi_ctrl->VRAM[i] = 0x00;
	}
}

void textHDMIDrawColorText(char* str, int x, int y, uint8_t background, uint8_t foreground)
{
	int i = 0;
	while (str[i]!=0)
	{
		hdmi_ctrl->VRAM[(y*COLUMNS + x + i) * 2] = foreground << 4 | background;
		hdmi_ctrl->VRAM[(y*COLUMNS + x + i) * 2 + 1] = str[i];
		i++;
	}
}

void setColorPalette (uint8_t color, uint8_t red, uint8_t green, uint8_t blue)
{
	//fill in this function to set the color palette entry <color> to <red>, <green>, <blue> 12-bit color
}

void sleepframe(uint32_t frames)
{
	uint32_t last_frame_count = hdmi_ctrl->FRAME_COUNT;
	while (hdmi_ctrl->FRAME_COUNT < last_frame_count + frames)
	{}
}


void textHDMIColorScreenSaver()
{

	char color_string[80];
    int fg, bg, x, y;
	char dvd_string[80];
	uint8_t old_string[160];
	int dvd_x = 0;
	int dvd_y = 0;
	int dvd_dx = 1;
	int dvd_dy = 1;

	int8_t dvd_colors[3] = {0x07, 0x07, 0x07};
	int8_t dvd_d_colors[3] = {-1, +1, -1};

	paletteTest();
	textHDMIColorClr();

	memset(old_string, 0, sizeof(old_string));
	sprintf(dvd_string, "%s and %s completed ECE 385!", STUDENT1NETID, STUDENT2NETID);

	//initialize palette
	for (int i = 0; i < 16; i++)
	{
		setColorPalette (i, colors[i].red, colors[i].green, colors[i].blue);
	}
	while (1)
	{
		if (hdmi_ctrl->FRAME_COUNT % 10 == 0) //every 10 frames update forground
		{
			//restore VRAM bytes into background to undo 'DVD' text
			memcpy(&(hdmi_ctrl->VRAM[(dvd_y*COLUMNS + dvd_x) * 2]), old_string, strlen(dvd_string)*2);

			if ( (dvd_x + dvd_dx >= 80-strlen(dvd_string)) || (dvd_x + dvd_dx < 0)) //check X bound
				dvd_dx = -1*dvd_dx;
			if ( (dvd_y + dvd_dy >= 30) || (dvd_y + dvd_dy < 0)) //check Y bound
				dvd_dy = -1*dvd_dy;
			dvd_x += dvd_dx;
			dvd_y += dvd_dy;

			//store VRAM bytes into buffer before overwriting with 'DVD' text.
			memcpy(old_string, &(hdmi_ctrl->VRAM[(dvd_y*COLUMNS + dvd_x) * 2]), strlen(dvd_string)*2);
			textHDMIDrawColorText (dvd_string, dvd_x, dvd_y, 0, (rand() % 7) + 9);
		}

		if (hdmi_ctrl->FRAME_COUNT % 30 == 0) //every 30 frames update background
			{
				fg = rand() % 16;
				bg = rand() % 16;
				while (fg == bg)
				{
					fg = rand() % 16;
					bg = rand() % 16;
				}
				sprintf(color_string, "Drawing %s text with %s background", colors[fg].name, colors[bg].name);
				x = rand() % (80-strlen(color_string));
				y = rand() % 30;

				textHDMIDrawColorText (color_string, x, y, bg, fg);
		}

		sleepframe(1);//sleep the rest of the frame
	}
}

//Call this function for your Week 2 test
hdmiTestWeek2()
{
	paletteTest();
	printf ("Palette test passed, beginning screensaver loop\n\r");


    textHDMIColorScreenSaver();
}



int triangulate(Vertex * polygon) {
	
}