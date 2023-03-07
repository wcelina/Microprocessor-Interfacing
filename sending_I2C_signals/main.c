

/**
 * main.c
 */

#define HWREG(x) (*((volatile unsigned int *)(x)))

//control module signals to use SCL/SDA on pins 21 and 22
#define CTRL_MOD_BASE = 0x44E10000
#define SCL = 0x954     //pin 21
#define SDA = 0x950     //pin 22
#define MODE2 = 0x32    //this will be written to pins 21 and 22 to set to SCL/SDA

//values to wake up clock
#define CM_PER_BASE = 0x44E00000
#define CM_PER_I2C2_CLKCTRL = 0x44  //write 0x2 to BASE + CLKCTRL

//define I2C offsets
#define I2C2_BASE = 0x4819C000
#define SCLL = 0xB4 //SCLLow - write 0x8
#define SCLH = 0xB8 //SCLHigh - write 0xA
#define PSC = 0xB0  //prescaler - write 0x3

#define CON = 0xA4  //configure register - write 0x8600
#define OA = 0xA8   //own address (primary)
#define SA = 0xAC   //secondary address
#define CNT = 0x98  //count register
#define DATA = 0x9C //data register
#define IRQSTATUS_RAW = 0x24

//LED values

int main(void) {
    HWREG(CM_PER_BASE + CM_PER_I2C2_CLKCTRL) = 0x2; //wake up I2C clock
    HWREG(CTRL_MOD_BASE + SCL) = MODE2;  //set pin 21 to mode 2
    HWREG(CTRL_MOD_BASE + SDA) = MODE2;  //set pin 22 to mode 2

    HWREG(I2C2_BASE + SCLL) = 0x8;  //values of SCL in fast mode
    HWREG(I2C2_BASE + SCLH) = 0xA;  //with 400KHz frequency
    HWREG(I2C2_BASE + PSC) = 0x3;   //internal clock of 12MHz

    HWREG(I2C2_BASE + CON) = 0x8600;    //primary
    HWREG(I2C2_BASE + SA) = 0x40;       //secondary
	return 0;
}
