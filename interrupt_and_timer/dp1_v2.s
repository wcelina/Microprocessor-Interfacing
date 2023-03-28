/*	ECE 372 Design Project #1 - Version 2
	Programmed debouncing and button service on GPIO1_3 and
	Timer3 Delay with incrementing/decrementing LEDs in 2 second intervals.

	User LED hex values:
		LED3		LED2		LED1		LED0
	0x01000000, 0x00800000, 0x00400000, 0x00200000

	- 'LEDS' array holds the four hex values for the four USER LEDs (0-3) in our desired sequence.

	- Register R3 (CURRLED) will regularly hold the current LED address - basically acting as pointer.

	- This allows for customization of the light-up pattern by simply changing the values in this array.

	- However, if the sequence is changed, slight changes will have to be made for the comparison in the
	  LIGHTS function to determine which values are the first and last elements of the array.
	  This could be improved by creating a function to check how many elements are in the LEDS array,
	  then saving the first element by putting that value in an array to be read from, and then
	  incrementing the LEDS array n times until we reach the last element, then saving that value
	  in an array to be read from. Then we can read from these arrays to be used for comparing and
	  determining the TOGGLE flag.

	This program increments through a custom set of LEDs by taking the address of the first
	element in 'LEDS' array.

	When we hit LED0, the TOGGLE flag will be set for decrement (left). When we hit LED3, the
	TOGGLE flag will be set for increment (right).

	To move through the LEDs, we will read the value in CURRLED and increment/decrement its
	current address depending on the TOGGLE flag.

	*This program focuses on storing the ADDRESS and only incrementing/decrementing the ADDRESS.
	 The LED hex values will need to be read from these addresses to be written into SETDATAOUT
	 to be lit up on the board.

	Celina Wong Winter 2023
*/

@read the value from R3(CURRLED) and increment/decrement that, remember to store the
@incremented/decremented value back into memory, then read value from R3 to get the hex value
@then set out to light up. To get the LED hex value, load R3 into R8, then load R8 into itself.

.EQU TIMER3_BA, 0x48042000

.text
.global _start
.global INT_DIRECTOR
_start:
			LDR	R13, =STACK1			@ Point to base of STACK for SVC mode
			ADD	R13, R13, #0x1000		@ Point to top of STACK
			CPS	#0x12					@ Switch to IRQ stack
			LDR	R13, =STACK2			@ Point to top of IQR STACK
			ADD	R13, R13, #0x1000		@ Point to top of STACK
			CPS	#0x13					@ Back to SVC

			@ Enable GPIO1 module
			MOV	R0, #0x02				@ Value to enable clock for a GPIO module
			LDR	R1, =0x44E000AC			@ Address of CM_PER_GPIO1_CLKCTRL Register
			STR	R0, [R1]				@ Write #02 to register
			LDR	R0, =0x4804C000			@ Base address of GPIO1 registers
			MOV	R7, #0x01E00000			@ Load all LED bit values to GPIO_21-24 with GPIO_CLEARDATAOUT register
			ADD	R4, R0, #0x190			@ Load address of GPIO1_CLEARDATAOUT register
			STR	R7, [R4]				@ Write to GPIO1_CLEARDATAOUT register

			@ Program GPIO_21-24 as outputs
			ADD R1, R0, #0x134			@ Make GPIO1_OE register address
			LDR R6, [R1]				@ Read current GPIO1_OE register
			MOV R7, #0xFE1FFFFF			@ Enable GPIO_21-24 as outputs
			AND R6, R7, R6				@ Clear bits 21-24 (modify)
			STR R6, [R1]				@ Write to GPIO1_OE register

			@ Enable debouncing (page 42 in ECE372 textbook)
			LDR R3, =0x44E000AC			@ Address of CM_PER_GPIO1_CLKCTRL
			LDR R4, =0x00040002			@ Turn on Aux Funct CLK, bit 18 and CLK
			STR R4, [R3]				@ Write value to register
			ADD R1, R0, #0x0150			@ Make GPIO1_DEBOUNCENABLE register
			MOV R2, #0x00000008			@ Load value for GPIO1 bit 3
			STR R2, [R1]				@ Enable GPIO1 bit 3
			ADD R1, R0, #0x154			@ GPIO1_DEBOUNCING TIME register address
			MOV R2, #0xA0				@ Number 31 microsec debounce intervals-1
			STR R2, [R1]				@ Enable GPIO1 Debounce for 5ms on all GPIO1 same

			@ Detect falling edge on GPIO1_3 and enable to assert POINTRPEND1
			ADD R1, R0, #0x14C			@ R1 = address of GPIO1_FALLINGDETECT register
			MOV	R2, #0x00000008			@ Load value for bit 3
			LDR	R3, [R1]				@ Read GPIO_FALLINGDETECT register
			ORR	R3, R3, R2				@ Modify bit 29
			STR	R3, [R1]				@ Write to register
			ADD	R1, R0, #0x34			@ R1 = address to GPIO1_IRQSTAUS_SET_0 register
			STR	R2, [R1]				@ Enable GPIO1_29 request on POINTRPEND1

			@ Initialize INTC
			LDR	R1, =0x48200000			@ Base address for INTC
			MOV	R2, #0x2				@ Value to reset INTC
			STR	R2, [R1,#0x10]			@ Write to INTC config register
			MOV	R2, #0x20				@ Value to unmask INTC INT 69, Timer3 Interrupt
			STR	R2, [R1,#0xC8]			@ Write to INTC_MIR_CLEAR2 register
			MOV	R2, #0x04				@ Value to unmask INTC INT 98, GPIOINTA
			STR	R2, [R1,#0xE8]			@ Write to INTC_MIR_CLEAR3 register

			@ Turn on Timer3 CLK
			MOV	R2, #0x2				@ Value to enable Timer3 CLK
			LDR	R1, =0x44E00084			@ Address of CM_PER_TIMER3_CLKCTRL
			STR	R2, [R1]				@ Turn on
			LDR	R1, =0x44E0050C			@ Address of PRCMCLKSEL_TIMER3 register
			STR	R2, [R1]				@ Select 32 KHz CLK for Timer3

			@ Initialize Timer 3 registers, with count, overflow interrupt generation
			LDR	R1, =0x48042000			@ Base address for Timer3 registers
			MOV	R2, #0x1				@ Value to reset Timer3
			STR	R2, [R1,#0x10]			@ Write to Timer3 CFG register
			MOV	R2, #0x2				@ Value to Enable Overflow interrupt
			STR	R2, [R1,#0x2C]			@ Write to Timer3 IRQENABLE_SET
			LDR	R2, =0xFFFF0000			@ Count value for 2 seconds
			STR	R2, [R1,#0x40]			@ Timer3 TLDR load register for (reload value)
			STR	R2, [R1,#0x3C]			@ Write to Timer3 TCRR count register

			@ Make sure processor IRQ enabled in CPSR
			MRS	R3, CPSR				@ Copy CPSR to R3
			BIC	R3, #0x80				@ Clear bit 7
			MSR	CPSR_c, R3				@ Write back to CPSR

			@ Wait for interrupt
LOOP: 		NOP
			B	LOOP

INT_DIRECTOR:
			STMFD SP!, {R0-R3, LR}		@ Push registers on stack
			LDR R0, =0x482000F8			@ Address of INTC_PENDING_IRQ3 register
			LDR R1, [R0]				@ Read INTC_PENDING_IRQ3 register
			TST R1, #0x00000004			@ Test bit 2
			BEQ	TCHK					@ Not GPIOINT1A, check if Timer3, else
			LDR R0, =0x4804C02C			@ GPIO_IRQSTATUS_0 register address
			LDR	R1, [R0]				@ Read status register
			TST	R1, #0x00000008			@ Check if button bit GPIO1_3 = 1
			BNE	BUTTON_SVC				@ If bit 3 = 1, button pushed, service
			LDR	R0, =0x48200048			@ Address of INTC_CONTROL register
			MOV	R1, #01					@ Value to clear bit 0
			STR	R1, [R0]				@ Write to INTC_CONTROL register
			LDMFD SP!, {R0-R3, LR}		@ Restore registers
			SUBS PC, LR, #4				@ Pass execution on to wait LOOP for now

TCHK:
			LDR R1, =0x482000D8			@ Address of INTC_PENDING_IRQ2 register
			LDR	R0, [R1]				@ Read value
			TST	R0, #0x20				@ Check if interrupt from Timer3
			BEQ	PASS_ON					@ No, return, Yes, check for overflow
			LDR	R1, =0x48042028			@ Address of Timer3 IRQSTATUS register
			LDR	R0, [R1]				@ Read value
			TST	R0, #0x2				@ Check bit 1
			BNE	TCHK2					@ If overflow, then continue to TIMER function

PASS_ON:
			LDR R0, =0x48200048			@ Address of INTC_CONTROL register
			MOV	R1, #01					@ Value to clear bit 0
			STR	R1, [R0]				@ Write to INTC_CONTROL register
			LDMFD SP!, {R0-R3, LR}		@ Restore registers
			SUBS PC, LR, #4				@ Return from IRQ interrupt procedure

TCHK2:
			LDR R10, =TOGGLE			@ Read array
			LDR R12, [R10]				@ Load array value into register
			CMP R12, #0x00000000		@ Compare with 0
			BEQ LIGHTS					@ If equal to 0, then go to lights function
			BNE STOP					@ If equal to 1, go to STOP

BUTTON_SVC:
			MOV R1, #0x00000008			@ Value to turn off GPIO1_3 Interrupt request, turns off INTC request also
			STR	R1, [R0]				@ Write to GPIO1_IRQSTATUS_0 register
			MOV R2, #0x03				@ Load value to auto-reload timer and start
			LDR R1, =0x48042038			@ Address of Timer 3 TCLR register
			STR R2, [R1]				@ Write to TCLR register
			@ Turn off NEW IRQA bit in INTC_CONTROL, so processor can respond to new IRQ
			LDR R0, =0x48200048			@ Address of INTC_CONTROL register
			MOV R1, #01					@ Value to clear bit 0
			STR R1, [R0]				@ Write to INTC_CONTROL register

			LDR R10, =TOGGLE			@ Read array
			LDR R12, [R10]				@ Load array into register
			CMP R12, #0x00000001		@ Compare with 1
			BEQ PLAY					@ If equal to 1, set flag as 0 to run LEDs
			BNE PAUSE					@ Else equal to 0, set flag as 1 to stop LEDs

PAUSE:
			MOV R11, #0x00000001		@ Set flag as 1
			STR R11, [R10]				@ Store into memory (PLAY/PAUSE array)
			B STOP						@ Jump here to turn off LED

PLAY:
			MOV R11, #0x00000000		@ Set flag as 0
			STR R11, [R10]				@ Store into memory (PLAY/PAUSE array)

LIGHTS:
			LDR R0, =0x4804C000			@ Base address for GPIO1 registers
			ADD R5, R0, #0x194			@ Load address of GPIO1_SETDATAOUT register
			ADD R4, R0, #0x190			@ Load address of GPIO1_CLEARDATAOUT register
			MOV R7, #0x01E00000			@ Bits 21-24 for all LEDs

			LDR R3, =CURRLED			@ Check if array has a value
			LDR R8, [R3]				@ Read the value
			CMP R8, #0x00000000			@ Check if empty
			BEQ FIRST					@ If start of program, go to FIRST

			LDR R8, [R8]				@else, go to address and load value into register
			CMP R8, #0x00200000			@check if on LED0
			BEQ BACKWARDFLAG			@if on LED0, set flag = 1 and decrement

			CMP R8, #0x01000000			@check if we're on LED3
			BEQ FORWARDFLAG				@set forward flag = 0 and increment

			LDR R9, =BACKFLAG			@ else check if we're going backwards
			LDR R6, [R9]				@ read
			CMP R6, #0x00000000			@
			BEQ LEDFORWARD				@if equal to 0 then keep going forward
			BNE LEDBACKWARD				@else go backwards in LED array

FIRST:
			LDR R11, =LEDS				@ Array to store LEDs starting point
			LDR R8, [R11]				@ Load LED3 hex value
			STR R8, [R5]				@ Write to SETDATAOUT register

			STR R11, [R3]				@ writing to memory in CURRLED array
			@from hereon out, read the value from R3(CURRLED) and increment/decrement that, remember to store the
			@incremented/decremented value back into memory, then read value from R3 to get the hex value
			@then set out to light up. To get the LED hex value, load R3 into R8, then load R8 into itself.
			B BACK						@ Back to wait loop

FORWARDFLAG:
			LDR R9, =BACKFLAG			@load array
			MOV R11, #0x00000000		@value of 0
			STR R11, [R9]				@store into array
			B LEDFORWARD				@continue incrementing

BACKWARDFLAG:	@set backwards flag
			LDR R9, =BACKFLAG			@load array
			MOV R11, #0x00000001		@value of 1
			STR R11, [R9]				@store into array
			B LEDBACKWARD

LEDFORWARD:	@increment through array
			STR R7, [R4]				@ Clear LEDs by writing to CLEARDATAOUT
			LDR R8, [R3]				@grab value in R3
			ADD R8, R8, #4				@ add 4 to increment to next value in array
			STR R8, [R3]				@remember to store incremented address back into R3
			LDR R8, [R8]				@ read value in incremented address
			STR R8, [R5]				@ Write to SETDATAOUT register
			B BACK						@ Go back to wait loop

LEDBACKWARD:	@decrement through array
			STR R7, [R4]				@clear LEDs
			LDR R8, [R3]				@grab value in R3
			SUB R8, R8, #4				@subtract 4 to decrement
			STR R8, [R3]				@store decremented address back into R3
			LDR R8, [R8]				@read value in decremented address
			STR R8, [R5]				@light up LED by writing to SETDATAOUT register
			B BACK						@go back to wait loop

STOP:
			STR R7, [R4]				@ Write to GPIO1_CLEARDATAOUT register to clear LEDs

BACK:
			LDR R1, =0x48042028			@ Address of Timer3 IRQSTATUS register
			MOV R2, #0x2				@ Value to reset Timer3 Overflow IRQ request
			STR R2, [R1]				@ Write to IRQSTATUS
			LDR R1, =0x48200048			@ Address of INTC_CONTROL address
			MOV R2, #0x01				@ Value to enable new IRQ response in INTC
			STR R2, [R1]				@ Write to INTC_CONTROL register

			LDMFD SP!, {R0-R3, LR}		@ Restore registers
			SUBS PC, LR, #4				@ Return from IRQ interrupt procedure



.align 2
SYS_IRQ:	.WORD 0						@ Location to store systems IRQ address
.data
LEDS:		.WORD 0x01000000, 0x00800000, 0x00400000, 0x00200000	@store LED hex values
CURRLED:	.WORD 0x00000000			@ Array to store current LED hex value
TOGGLE:		.WORD 0x00000001			@ Array to store flag to determine if lights play/pause
BACKFLAG:	.WORD 0x00000000			@ Flag to decrement array
.align 2
STACK1:		.rept 1024
			.word 0x0000
			.endr
STACK2:		.rept 1024
			.word 0x0000
			.endr

.END

