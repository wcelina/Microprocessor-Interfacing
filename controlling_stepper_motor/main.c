/**
 * Celina Wong
 * ECE 372 Winter 2023 Design Project 2 with button interrupt
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
#define CM_PER_I2C2_CLKCTRL 0x44    //write 0x2 to BASE + I2C2_CLKCTRL
#define CM_PER_GPIO1_CLKCTRL 0xAC   //write 0x2 to BASE + GPIO1_CLKCTRL

//values for button
#define GPIO1_BASE 0x4804C000
#define FALLINGDETECT 0x14C         //write 0x8
#define IRQSTATUS_SET_0 0x34        //write 0x8 for button bit 3
#define IRQSTATUS_0 0x2C            //turn off interrupt request

//values for INTC
#define INTCPS_BASE 0x48200000
#define INTC_CONFIG 0x10        //write 0x2
#define INTC_MIR_CLEAR3 0xE8    //write 0x4
#define INTC_PENDING_IRQ3 0xF8  //check interrupt
#define INTC_CONTROL 0x48       //write #0x1

//define I2C offsets
#define I2C2_BASE 0x4819C000
//clock-related registers
#define SCLL 0xB4 //SCLLow - write 0x8
#define SCLH 0xB8 //SCLHigh - write 0xA
#define PSC 0xB0  //prescaler - write 0x3
//bus-transmission registers
#define CON 0xA4  //configure register - write 0x8600
#define OA 0xA8   //own address (primary)
#define SA 0xAC   //secondary address
#define CNT 0x98  //count register
#define DATA 0x9C //data register
#define IRQSTATUS_RAW 0x24 //status register

//LED registers - only need LED_ON_H
#define ALL_LED_OFF_H 0xFD
#define PWMA 0x0F    //LED2_ON_H address
#define A01 0x13     //LED3_ON_H address
#define A02 0x17     //LED4_ON_H address

#define B01 0x1B     //LED5_ON_H address
#define B02 0x1F     //LED6_ON_H address
#define PWMB 0x23    //LED7_ON_H address

//functions
void loop();
void init_BBB();
void init_PCA();
void init_Delay();
void delay();
void transmit(int address, int data);
void checkBus();
void INT_DIRECTOR();
void buttonPress();
void LED_OFF();
void stepMotor();
//void go_CW(int PWM, int N01, int N02);
//void go_CCW(int PWM, int N01, int N02);
void go_CWA();
void go_CCWA();
void go_CWB();
void go_CCWB();

//global variables
volatile unsigned int STACK1[1000];     //main program
volatile unsigned int STACK2[1000];     //interrupt procedure

int main(void) {
    //set up stack, similar to project 1
    asm("LDR R12, =STACK1");        //point to base of STACK for SVC mode
    asm("ADD R13, R13, #0x1000");   //point to top of stack
    asm("CPS #0x12");               //switch to IRQ mode
    asm("LDR R13, =STACK2");        //point to IRQ stack
    asm("ADD R13, R13, #0x1000");   //point to top of stack
    asm("CPS #0x13");               //switch back to SVC mode

    init_BBB();     //initialize BBB stuff
    init_PCA();     //initialize PCA9685 stuff

    loop();
    transmit(ALL_LED_OFF_H, 0x10);  //disconnect master LEDs switch after we're done
    delay();
    return 0;
}

void loop(void) {
    while(1) {
        //wait loop, do nothing and wait for interrupt
    }
}

void init_BBB(void) {   //BBB initializations
    //initialize button stuff
    HWREG(CM_PER_BASE + CM_PER_GPIO1_CLKCTRL) = 0x2;    //wake up GPIO1 module
    HWREG(GPIO1_BASE + FALLINGDETECT) = 0x8;            //set bit 3 to detect button press
    HWREG(GPIO1_BASE + IRQSTATUS_SET_0) = 0x8;          //enable GPIO1_3 request on POINTRPEND1
    HWREG(GPIO1_BASE + IRQSTATUS_0) = 0x8;              //enable interrupt on GPIO1_3 bit 3

    //initialize INTC stuff
    HWREG(INTCPS_BASE + INTC_CONFIG) = 0x2;             //reset INTCPS - this sets INTC_MIR3 back to 0xFFFFFFFF
    HWREG(INTCPS_BASE + INTC_MIR_CLEAR3) = 0x04;        //unmask INT 98, GPIO1A - this sets INTC_MIR3 to 0xFFFFFFFB

    //initialize I2C stuff
    HWREG(CM_PER_BASE + CM_PER_I2C2_CLKCTRL) = 0x2; //wake up I2C clock
    HWREG(CTRL_MOD_BASE + SCL) = MODE2;  //set pin 21 to mode 2
    HWREG(CTRL_MOD_BASE + SDA) = MODE2;  //set pin 22 to mode 2

    HWREG(I2C2_BASE + SCLL) = 0x8;      //values of SCL in fast mode
    HWREG(I2C2_BASE + SCLH) = 0xA;      //with 400KHz frequency
    HWREG(I2C2_BASE + PSC) = 0x3;       //internal clock of 12MHz

    HWREG(I2C2_BASE + OA) = 0x10;       //configure own address, value doesn't matter for first part
    HWREG(I2C2_BASE + CON) = 0x8600;    //take I2C module out of reset
    HWREG(I2C2_BASE + SA) = 0x70;       //SA - 70 or E0; send 0 to E0 to receive ACK from PCA9685

    //enable processor IRQ in CPSR
    asm("MRS R3, CPSR");        //copy CPSR to R3
    asm("BIC R3, #0x80");       //clear bit 7
    asm("MSR CPSR_c, R3");      //write back to CPSR
    return;
}

void init_PCA(void) {   ///PCA9685 initializations
    //set up PCA9685 for all-call
    transmit(0x00, 0x01);           //PCA9685 MODE1 register, ALLCALL bit value = 1
    init_Delay();
    //set prescale mode for 1kHz
    transmit(0xFE, 0x05);           //send 0x05 to PRESCALE register
    //set up PCA9685 totem pole structure
    transmit(0x01, 0x04);           //send 0x04 to PCA9685 MODE2 register
    init_Delay();
    //turn on all_off PCA9685 LEDS
    transmit(ALL_LED_OFF_H, 0x00);  //send 0x00 to 0xFD to turn on master LED_OFF switch
    delay();
    return;
}

void init_Delay(void) {     //delay count of 5,000 between each command sent
    int count = 0;
    while (count != 5000) {
        count = count + 1;
    }
    return;
}

void delay(void) {   //delay count of 400,000 between each set of step commands
    int count = 0;
    while(count != 25000) {
        asm("NOP");
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

void INT_DIRECTOR(void) {
    if (HWREG(GPIO1_BASE + IRQSTATUS_0) == 0x8) {        //check if interrupt is from button GPIO1_3
        HWREG(INTCPS_BASE + INTC_PENDING_IRQ3) = 0x8;    //turn off GPIO1_3 and INTC interrupt request
        buttonPress();     //go do something
    }

    HWREG(INTCPS_BASE + INTC_CONTROL) = 0x1;    //clear NEW IRQA bit 0 so processor can respond to new IRQ
    HWREG(GPIO1_BASE + IRQSTATUS_0) = 0x8;      //enable interrupt on GPIO1_3 bit 3

    transmit(ALL_LED_OFF_H, 0x10);  //disconnect master LEDs switch after we're done
    delay();
    LED_OFF(); //make sure we turn all the LEDs off individually

    //restore registers and return from IRQ interrupt procedure
    asm("LDMFD SP!, {LR}");
    asm("LDMFD SP!, {LR}");
    asm("SUBS PC, LR, #0x4");
    return;
}

void buttonPress(void) {    //enable LEDs and do something with motor
    transmit(ALL_LED_OFF_H, 0x00);  //send 0x00 to 0xFD to turn on master LED switch
    delay();
    for (int i=0; i<50; i++) {  //go step n times
        stepMotor();
    }
    return;
}

void LED_OFF(void) {
    transmit(PWMA, 0x00);
    transmit(A01, 0x00);
    transmit(A02, 0x00);
    transmit(B01, 0x00);
    transmit(B02, 0x00);
    transmit(PWMB, 0x00);
    return;
}

/*
 * Motor patterns from table - kind of like a state machine
 * Variables: PWMA, A01,  A02;  B01,  B02,  PWMB
 *            LED2, LED3, LED4, LED5, LED6, LED7
 *
 * We want to continuously turn the motor clock-wise (CW).
 * - Write 0x10 for ON, 0x00 for OFF
 */

void stepMotor(void) {          //motor pattern to go forward
    go_CWB();                   //step 1
    go_CWA();                   //CW CW = 10 10
    delay();

    go_CWB();                   //step 2
    go_CCWA();                  //CW CCW = 10 01
    delay();

    go_CCWB();                  //step 3
    go_CCWA();                  //CCW CCW = 01 01
    delay();

    go_CCWB();                  //step 4
    go_CWA();                   //CCW CW = 01 10
    delay();

    return;
}
void go_CWA() {                  //bridge A go clock-wise
    transmit(PWMA, 0x10);
    transmit(A01, 0x10);         //LED 2,3,4 = 1,1,0
    transmit(A02, 0x00);
    init_Delay();
    return;
}
void go_CCWA() {                 //bridge A go counter clock-wise
    transmit(PWMA, 0x10);
    transmit(A01, 0x00);         //LED 2,3,4 = 1,0,1
    transmit(A02, 0x10);
    init_Delay();
    return;
}
void go_CWB() {                 //bridge B go clock-wise
    transmit(B01, 0x10);        //LED 5,6,7 = 1,0,1
    transmit(B02, 0x00);
    transmit(PWMB, 0x10);
    init_Delay();
    return;
}
void go_CCWB() {                //bridge B go counter clock-wise
    transmit(B01, 0x00);        //LED 5,6,7 = 0,1,1
    transmit(B02, 0x10);
    transmit(PWMB, 0x10);
    init_Delay();
    return;
}
