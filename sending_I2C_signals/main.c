/**
 * Celina Wong
 * ECE 372 Winter 2023 Design Project 2
 */

//Defines section
#define HWREG(x) (*((volatile unsigned int *)(x)))

//control module signals to use SCL/SDA on pins 21 and 22
#define CTRL_MOD_BASE 0x44E10000
#define SCL 0x954     //pin 21
#define SDA 0x950     //pin 22
#define MODE2 0x32    //this will be written to pins 21 and 22 to set to SCL/SDA

//values to wake up clock
#define CM_PER_BASE 0x44E00000
#define CM_PER_I2C2_CLKCTRL 0x44  //write 0x2 to BASE + CLKCTRL

//define I2C offsets
#define I2C2_BASE 0x4819C000
//clock-related registers
#define SCLL 0xB4 //SCLLow - write 0x8
#define SCLH 0xB8 //SCLHigh - write 0xA
#define PSC 0xB0  //prescalar - write 0x3
//bus-transmission registers
#define CON 0xA4  //configure register - write 0x8600
#define OA 0xA8   //own address (primary)
#define SA 0xAC   //secondary address
#define CNT 0x98  //count register
#define DATA 0x9C //data register
#define IRQSTATUS_RAW 0x24 //status register

void delay();
void transmit(int address, int data);
void checkBus();

int main(void) {
    HWREG(CM_PER_BASE + CM_PER_I2C2_CLKCTRL) = 0x2; //wake up I2C clock
    HWREG(CTRL_MOD_BASE + SCL) = MODE2;  //set pin 21 to mode 2
    HWREG(CTRL_MOD_BASE + SDA) = MODE2;  //set pin 22 to mode 2

    HWREG(I2C2_BASE + SCLL) = 0x8;      //values of SCL in fast mode
    HWREG(I2C2_BASE + SCLH) = 0xA;      //with 400KHz frequency
    HWREG(I2C2_BASE + PSC) = 0x3;       //internal clock of 12MHz

    HWREG(I2C2_BASE + OA) = 0x10;        //configure own address, value doesn't matter for first part
    HWREG(I2C2_BASE + CON) = 0x8600;    //take I2C module out of reset
    HWREG(I2C2_BASE + SA) = 0xE0;       //SA - send 0 to E0 to receive ACK from PCA9685

    //start sending data
    transmit(0x00, 0x11);       //PCA9685 MODE1 register, SLEEP & ALLCALL bit value = 1
    delay();
    //transmit(0x00, 0x91);      //send 0 to E0 to receive ACK from PCA9685?
    //delay();

    return 0;
}

void delay(void) {   //delay count of 5,000 between each command sent
    int count = 0;
    while(count != 100000) {
        count = count + 1;
    }
    return;
}

void transmit(int address, int data) {  //takes in two arguments
    checkBus(); //check if bus is busy

    HWREG(I2C2_BASE + DATA) = address;  //send address
    HWREG(I2C2_BASE + DATA) = data;     //send data
    return;
}

void checkBus(void) {
    //check if BB bit 12 = 1 in I2C_IRQSTATUS_RAW, stay in while loop until BB goes high
    while ((HWREG(I2C2_BASE + IRQSTATUS_RAW) & 0x1000) == 0x1000) {}  //mask by ANDing then compare

    HWREG(I2C2_BASE + CNT) = 0x2; //set count to 2 bytes, the amount of data to send

    //initiate transfer; write 1 to STT and STP in configured I2C_CON --> 0x3
    HWREG(I2C2_BASE + CON) = 0x8603;

    //check if bus is ready to transmit data, stay in while loop until XRDY goes low
    while ((HWREG(I2C2_BASE + IRQSTATUS_RAW) & 0x10) != 0x10) {}    //mask by ANDing then compare
    return;
}
