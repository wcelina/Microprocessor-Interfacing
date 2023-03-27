## Design Project 2 - Part 2
#### In continuation of DP2 Part 1, we now have a 12V dual H-Bridge DC stepper motor connected to the PCA9685. The purpose of this project is to step the motor a certain number of steps to rotate the motor clockwise.
#### This will be done by sending the proper signals through the SDA/SCL lines to turn ON/OFF certain LEDs in the PCA9685. Certain LED lines are connected to a PWM pin of the TB6612FNG IC, and pulling various sets of LEDs high/low will switch on/off certain transistors in the H-Bridges in the stepper motor.

#### The important part of this project is to ensure we are utilizing the proper pattern/sequence to pull the (8) transistors high/low. We will also include a button interrupt for the motor to run through the steps every time a button is pushed. This is a simple translation from Design Project 1 from ASM to C code.

#### Pin Names connecting from PCA9685 to TB6612FNG IC:
    (LED2) PWM2 - PWMA  --- Bridge A
    (LED3) PWM3 - AIN2
    (LED4) PWM4 - AIN1
    (LED5) PWM5 - BIN1  --- Bridge B
    (LED6) PWM6 - BIN2
    (LED7) PWM7 - PWMB

#### LED sequence (Steps 1-4) to step the motor clockwise once:
    
    Table -   BIN1    BIN2    AIN1    AIN2
    Step 1:    1       0       1       0
    Step 2:    1       0       0       1
    Step 3:    0       1       0       1
    Step 4:    0       1       1       0
             Q1,Q4   Q2,Q3   Q5,Q8    Q6,Q7   (Transistors Q1-Q8)
    
    Bridge A: Q1, Q2, Q3, Q4
    Bridge B: Q5, Q6, Q7, Q8
             
    ----------Translating to code sequence----------
    -For AIN and BIN pins, clockwise (IN1, IN2) = [10];  counter-clockwise (IN1, IN2) = [01];   
     PWMA/PWMB pins will always be high (LED2 and LED7). 
    -Brackets were put in between IN1 and IN2 pins to see the pattern easier from the table above.
    
    Step 1: LED 5,6,7: [10]1   (Bridge B, clockwise)
            LED 2,3,4: 1[10]   (Bridge A, clockwise)
            
    Step 2: LED 5,6,7: [10]1   (Bridge B, clockwise)
            LED 2,3,4: 1[01]   (Bridge A, counter-clockwise)
    
    Step 3: LED 5,6,7: [01]1   (Bridge B, counter-clockwise)
            LED 2,3,4: 1[01]   (Bridge A, counter-clockwise)
    
    Step 4: LED 5,6,7: [01]1   (Bridge B, counter-clockwise)
            LED 2,3,4: 1[10]   (Bridge A, clockwise)
    
    Repeating this sequence over and over will then rotate our motor continuously.
    To rotate the motor counter-clockwise, simply reverse the sequence.
