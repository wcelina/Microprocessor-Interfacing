/*	ECE 372 Design Project #1
	Programmed debouncing and button service on GPIO1_3 and
	Timer3 Delay with incrementing/decrementing LEDs in 2 second intervals.

	User LED hex values: (check in GPIO1_GPIO_DATAOUT to see which one we're currently on)
		LED3		 LED2		 LED1		 LED0
	0x01000000, 0x00800000, 0x00400000, 0x00200000
	Register R8 will regularly hold our LED values in the interrupt procedure.
	To move through the LEDs, we will simply start by grabbing the hex value of LED3 and
	LSL/LSR by 1 to shift the bit over to its neighboring bit.

	Celina Wong Winter 2023
*/

.text
.global _start
.global INT_DIRECTOR
_start:
@initialize stack in user and IRQ mode
		LDR R13, =STACK1		@point to base of STACK for SVC mode
		ADD R13, R13, #0x1000	@point to top of stack
		CPS #0x12				@switch to IRQ mode
		LDR R13, =STACK2		@point to IRQ stack
		ADD R13, R13, #0x1000	@point to top of stack
		CPS #0x13				@switch back to SVC mode
@feed clock to GPIO1 to turn it on
		MOV R0, #0x02			@value to enable clocks for GPIO modules
		LDR R1, =0x44E000AC		@address of CM_PER_GPIO1_CLKCTRL register
		STR R0, [R1]			@write 2 to register
		LDR R0, =0x4804C000		@base address for GPIO1 registers
@load value to turn off all four LEDs
		MOV R7, #0x01E00000		@GPIO_21-24 with GPIO_CLEARDATAOUT register
		ADD R4, R0, #0x190		@Make GPIO1_CLEARDATAOUT register address
		STR R7, [R4]			@Write to GPIO1_CLEARDATAOUT register
@program GPIO_21-24 as outputs
		ADD R1, R0, #0x134		@make GPIO1_OE register address
		LDR R6, [R1]			@read current GPIO1_OE register
		MOV R7, #0xFE1FFFFF		@load word to enable GPIO_21-24 as outputs
		AND R6, R7, R6			@Clear bits 21-24 (modify)
		STR R6, [R1]			@write to GPIO1_OE register
@add debounce wait time (pg.42)
		LDR R3, =0x44E000AC		@address of CM_PER_GPIO1_CLKCTRL
		LDR R4, =0x00040002		@turn on Aux Funct CLK, bit 18 and CLK
		STR R4, [R3]			@write value to register
		ADD R1, R0, #0x0150		@make GPIO1_DEBOUNCENABLE register
		MOV R2, #0x00000008		@load value for GPIO1 bit 3
		STR R2, [R1]			@enable GPIO1 bit 3
		ADD R1, R0, #0x154		@GPIO1_DEBOUNCING TIME register address
		MOV R2, #0xA0			@no.31 microsec debounce intervals-1
		STR R2, [R1]			@enable GPIO1 Debounce for 5ms on all GPIO1
@detect falling edge on GPIO1_3 and enable to assert POINTRPEND1 (set up button as interrupt)
		@GPIO1 base address already saved in R0
		ADD R1, R0, #0x14C		@address of GPIO1_FALLINGDETECT register
		MOV R2, #0x00000008		@load value for bit 3 (GPIO1_3)
		LDR R3, [R1]			@read GPIO1_FALLINGDETECT register
		ORR R3, R3, R2			@modify (set bit 3)
		STR R3, [R1]			@write back
		ADD R1, R0, #0x34		@address of GPIO1_IRQSTATUS_SET_0 register
		STR R2, [R1]			@enable GPIO1_3 request on POINTRPEND1
@initialize INTC
		LDR R1, =0x48200000		@address of INTCPS register
		MOV R2, #0x2			@value to reset INTC
		STR R2, [R1, #0x10]		@write to INTC Config register (TIOCP_CFG)
		MOV R2, #0x20			@unmask INTC INT 69, Timer3 interrupt (DMTIMER_3/TINT3)
		STR R2, [R1, #0xC8]		@write to INTC_MIR_CLEAR2 register
		MOV R2, #0x04			@value to unmask INTC INT 98, GPIO1A
		STR R2, [R1, #0xE8]		@write to INTC_MIR_CLEAR3
@turn on Timer3 CLK
		MOV R2, #0x2			@value to enable Timer CLK
		LDR R1, =0x44E00084		@address of CM_PER_TIMER3_CLKCTRL
		STR R2, [R1]			@read into address to turn on
		LDR R1, =0x44E0050C		@address of PRCMCLKSEL_TIMER3 register (CM_DPLL_CLKSEL_TIMER3_CLK)
		STR R2, [R1]			@select 32 KHz CLK for Timer3
@initialize Timer 3 registers, with count, overflow interrupt generation
		LDR R1, =0x48042000		@base address for Timer3 registers
		MOV R2, #0x1			@value to reset Timer3
		STR R2, [R1, #0x10]		@write to Timer3 CFG register (TIOCP_CFG)
		MOV R2, #0x2			@value to enable overflow interrupt
		STR R2, [R1, #0x2C]		@write to Timer3 IRQENABLE_SET
		LDR R2, =0xFFFF0000		@count value for 2 seconds
		STR R2, [R1, #0x40]		@Timer3 load register (reload value, TLDR)
		STR R2, [R1, #0x3C]		@write to Timer3 counter register (TCRR)
@make sure processor IRQ enabled in CPSR
		MRS R3, CPSR			@copy CPSR to R3
		BIC R3, #0x80			@clear bit 7
		MSR CPSR_c, R3			@write back to CPSR

WAIT:	NOP 	@wait for interrupt
		B WAIT

INT_DIRECTOR:	@this function tests if interrupt was from timer or button
		STMFD SP!, {R0-R3, LR}	@push registers on stack
		LDR R0, =0x482000F8		@address of INTC_PENDING_IRQ3
		LDR R1, [R0]			@read INTC_PENDING_IRQ3 register
		TST R1, #0x00000004		@test bit 2
		BEQ TCHK				@not GPIOINT1A, check if Timer3, Else:
		LDR R0, =0x4804C02C		@load GPIO1_IRQSTATUS_0 register address
		LDR R1, [R0]			@read status register
		TST R1, #0x00000008		@check if button bit GPIO1_3 = 1 (True)
		BNE BUTTON_SVC			@if bit = 1, then button pressed, go to BUTTON_SVC
		@if bit = 0, then button not pressed, go back to program (PASS_ON)

PASS_ON:	@these instructions go back to main, where we were initially before the interrupt
		LDR R0, =0x48200048		@address of INTC_CONTROL register
		MOV R1, #01				@value to clear bit 0
		STR R1, [R0]			@write to INTC_CONTROL register
		LDMFD SP!, {R0-R3, LR}	@restore registers
		SUBS PC, LR, #4			@return from IRQ interrupt procedure

TCHK:	@check if interrupt is from Timer3
		LDR R1, =0x482000D8		@address of INTC_PENDING_IRQ2
		LDR R0, [R1]			@read value
		TST R0, #0x20			@check if bit interrupt from Timer3
		BEQ PASS_ON				@if not, return back to main program, Else:
		LDR R1, =0x48042028		@address of Timer3 IRQSTATUS register
		LDR R0, [R1]			@read value
		TST R0, #0x2			@check bit 1
		BNE TIMER				@if overflow, then continue to TIMER func
		B PASS_ON				@else go back to main program

TIMER:	@this determines what happens when timer interrupts
		LDR R10, =PLAYPAUSE		@read array
		LDR R12, [R10]			@load array value into register
		CMP R12, #0x00000000	@compare with 0
		BEQ INIT_LED			@if equal to 0, then go to lights func
		BNE STOPPED				@if equal to 1, go to STOPPED

BUTTON_SVC:	@this determines what happens when button interrupts
		MOV R1, #0x00000008		@value turns off GPIO1_3 and INTC interrupt request
		STR R1, [R0]			@write to GPIO1_IRQSTATUS_0 register

		@reload timer everytime the button is pressed
		MOV R2, #0x03			@load value to auto-reload timer and start
		LDR R1, =0x48042038		@address of Timer 3 TCLR register
		STR R2, [R1]			@write to TCLR register

		@turn off NEW IRQA bit in INTC_CONTROL, so processor can respond to new IRQ
		LDR R0, =0x48200048		@address of INTC_CONTROL register
		MOV R1, #01				@value to clear bit 0
		STR R1, [R0]			@write to INTC_CONTROL register
		@continue to TOGGLE func

TOGGLE:	@this determines whether the button press will set flag equal to 1 or 0
@TOGGLE FUNC: PLAY/PAUSE flag - if flag = 1, lights are paused. if flag = 0, lights are running
		LDR R10, =PLAYPAUSE		@read array
		LDR R12, [R10]			@load array value into register
		CMP R12, #0x00000001	@compare with 1
		BEQ PLAY				@if currently equal to 1, set flag as 0 so we run LEDs
		BNE PAUSE				@else currently equal to 0, set flag as 1 so we stop

PAUSE:	@set flag equal to 1
		MOV R11, #0x00000001	@set flag as 1
		STR R11, [R10]			@store into memory (PLAY/PAUSE array)
		B STOPPED				@then go here to turn off LED

PLAY: 	@set flag equal to 0
		MOV R11, #0x00000000	@set flag as 0
		STR R11, [R10]			@store into memory (PLAY/PAUSE array)
		@then continue on with lighting functions below

@program: check which LED and decide to increment or decrement, light the LED, then wait for interrupt
INIT_LED:	@initalize addresses/set registers needed to control LEDs
		LDR R0, =0x4804C000		@base address for GPIO1 registers
		@ADD R6, R0, #0x13C		@load address of GPIO1_GPIO_DATAOUT register - where LED is currently lit up
		ADD R5, R0, #0x194		@load address of GPIO1_SETDATAOUT register	- this lights up LED
		ADD R4, R0, #0x190		@load address of GPIO1_CLEARDATAOUT register - this turns off LED
		MOV R7, #0x01E00000		@bits 21-24 for all LEDs

@INIT_CHECK:	@check GPIO1_GPIO_DATAOUT value
@		LDR R8, [R6]			@read value from GPIO1_GPIO_DATAOUT
@		CMP R8, #0x00000000		@start of program, no LEDs on
@		BEQ FIRSTLIGHT			@go to FIRSTLIGHT func
@		BNE ARRAY				@go to ARRAY func

LCHECK:	@check our value in array/memory
@when we press the button to stop and turn off LEDs,
@we need to save what LED we were in previously to resume back to the same spot
		@below code is required when resuming lights from button press
		LDR R10, =CURRENTLED	@check if our array has a value
		LDR R8, [R10]			@read the value
		CMP R8, #0x00000000		@check if empty
		BEQ FIRSTLIGHT			@if empty, start of program, go to FIRSTLIGHT
		@STR R6, [R8]			@else load array value into GPIO_DATAOUT and continue

		@else, check if we are on LED3
		CMP R8, #0x01000000		@check if we are on LED3
		BEQ FORWARD				@set DIRECTION flag = 0 (forward)

		@else, check if we are on LED0
		CMP R8, #0x00200000		@check if we are on LED0
		BEQ BACKWARD			@set DIRECTION flag = 1 (backwards)

		@else not first light or LED0 or LED3, check direction flag to continue from LED1 or LED2
		LDR R10, =DIRECTION		@check direction flag
		LDR R12, [R10]			@read value in memory and compare with 0
		CMP R12, #0x00000000	@this is so we can increment/decrement LEDS array
		BEQ INCREMENT			@if equal to 0, go to function to run lights forward (incrementing)
		BNE DECREMENT			@else go to function to run lights backwards (decrementing)

FIRSTLIGHT:	@light up LED3 and return to wait loop if first time running through interrupt procedure
		LDR R11, =LED3			@array to store starting point in LEDs
		LDR R8, [R11]			@load LED3 hex value
		STR R8, [R5]			@write to SETDATAOUT register to light up
		B BACK					@go back to wait loop

@increment/decrement current GPIO_DATAOUT address, read value, and set it out to light up
INCREMENT:	@from LED3 --> LED0
		STR R7, [R4]			@clear all LEDs by writing to CLEARDATAOUT
		MOV R8, R8, LSR #1		@shift right by 1 to go increment to next LED hex val
		STR R8, [R5]			@write to SETDATAOUT register to light up
		B BACK					@go back to wait loop

DECREMENT:	@from LED0 --> LED3
		STR R7, [R4]			@clear all LEDs by writing to CLEARDATAOUT
		MOV R8, R8, LSL #1		@shift left by 1 to decrement from one LED to another
		STR R8, [R5]			@write to SETDATAOUT register to light up
		B BACK					@go back to wait loop

FORWARD:
		LDR R10, =DIRECTION		@set direction flag
		MOV R11, #0x00000000	@flag value of 0 = forwards
		STR R11, [R10]			@store into memory
		B INCREMENT

BACKWARD:
		LDR R10, =DIRECTION		@set direction flag
		MOV R11, #0x00000001	@flag value of 1 = backwards
		STR R11, [R10]			@store into memory
		B DECREMENT

STOPPED: @clears LEDs
		STR R7, [R4]			@Write to GPIO1_CLEARDATAOUT register to clear LEDs

BACK:	@reset and go back to wait loop
		@turn off Timer3 interrupt request and enable INTC for next IRQ
		LDR R1, =0x48042028		@load address of Timer3 IRQSTATUS register
		MOV R2, #0x2			@value to reset Timer3 Overflow IRQ request
		STR R2, [R1]			@write to IRQSTATUS

		LDR R1, =0x48200048		@address of INTC_CONTROL address
		MOV R2, #0x01			@value to enable new IRQ response in INTC
		STR R2, [R1]			@write to INTC_CONTROL register

		@store current LED value into memory
		LDR R10, =CURRENTLED	@store current LED hex value to use next time/so we know where we stopped
		STR R8, [R10]			@write to memory

		LDMFD SP!, {R0-R3, LR}	@restore registers
		SUBS PC, LR, #4			@return from IRQ interrupt procedure


.align 2
SYS_IRQ:	.WORD 0				@location to store systems IRQ address
.data
LED3:		.WORD 0x01000000	@array to carry LED3 hex value - starting point
CURRENTLED:	.WORD 0x00000000	@array to store current LED hex value
PLAYPAUSE:	.WORD 0x00000001	@array to store flag to determine if lights play/pause
DIRECTION:	.WORD 0x00000000	@flag to determine which direction the lights go
.align 2
STACK1:		.rept 1024
			.word 0x0000
			.endr
STACK2:		.rept 1024
			.word 0x0000
			.endr

.END
