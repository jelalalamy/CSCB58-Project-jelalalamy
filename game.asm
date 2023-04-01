#####################################################################
#
# CSCB58 Winter 2023 Assembly Final Project
# University of Toronto, Scarborough
#
# Student: Jeremy La, 1007191995, lajeremy, jeremy.la@mail.utoronto.ca
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 512
# - Display height in pixels: 512
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1/2/3 (choose the one the applies)
#
# Which approved features have been implemented for milestone 3?
# (See the assignment handout for the list of additional features)
# 1. (fill in the feature, if any)
# 2. (fill in the feature, if any)
# 3. (fill in the feature, if any)
# ... (add more if necessary)
#
# Link to video demonstration for final submission:
# - (insert YouTube / MyMedia / other URL here). Make sure we can view it!
#
# Are you OK with us sharing the video with people outside course staff?
# - yes / no / yes, and please share this project github link as well!
#
# Any additional information that the TA needs to know:
# - (write here, if any)
#
#####################################################################
.eqv BASE_ADDRESS 0x10008000
.eqv WAIT_TIME 40
.data
# Strings
start_str: .asciiz "Game started\n"
end_str: .asciiz "Game finished\n"
pressed_q: .asciiz "Pressed q - ending game\n"
test_str: .asciiz "Something happened\n"

# Player (coords refer to the player's feet
player_x: .word 0
player_y: .word 63
player_position: .word 16128

# Colours
red_1: .word 0xff0000 
green_1: .word 0x00ff00
blue_1: .word 0x0000ff
black: .word 0x000000

######
# Conventions
# Use $t0 for base address
# Use $t1, $t2, $t3 for immediate use
# Use $t4 for function return
# Use $s0, $s1 for function arguments
#####
.text
.globl main
main:
	# Print start message
	li $v0, 4
	la $a0, start_str
	syscall	

	jal init_level
	jal game_loop
	j end
	
game_loop:
	# Check user input
	li $t9, 0xffff0000
	lw $t8, 0($t9)
	beq $t8, 1, keypress_happened
	j sleep_and_loop
	
	keypress_happened:
		lw $t2, 4($t9)
		beq $t2, 0x64, move_player_coords_right
		beq $t2, 0x61, move_player_coords_left
		beq $t2, 0x20, move_player_coords_up
		beq $t2, 0x73, move_player_coords_down
		beq $t2, 0x71, respond_to_q
		j sleep_and_loop
	
	respond_to_q:
		li $v0, 4
		la $a0, pressed_q
		syscall
		jr $ra
		
	move_player_coords_right:
		# Get player x-coordinate and increment by 1 to move right
		lw $s0, player_x
		lw $s1, player_y
		addi $s0, $s0, 1
		sw $s0, player_x
		j update_player_position
		
	move_player_coords_left:
		# Get player x-coordinate and decrement by 1 to move left
		lw $s0, player_x
		lw $s1, player_y
		addi $s0, $s0, -1
		sw $s0, player_x
		j update_player_position

	move_player_coords_up:
		# Get player y-coordinate and decrement by 1 to move up
		lw $s0, player_x
		lw $s1, player_y
		addi $s1, $s1, -1
		sw $s1, player_y
		j update_player_position
		
	move_player_coords_down:
		# Get player y-coordinate and increment by 1 to move right
		lw $s0, player_x
		lw $s1, player_y
		addi $s1, $s1, 1
		sw $s1, player_y
		j update_player_position
		
	update_player_position:
		# Compute position according to formula (x, y) = (y*64 + x)*4 and store in $t1
		mul $t1, $s1, 64
		add $t1, $t1, $s0
		mul $t1, $t1, 4
		
		# Erase old position
		li $t0, BASE_ADDRESS
		lw $t2, black
		lw $s2, player_position
		add $s2, $s2, $t0
		sw $t2, ($s2)
		
		# Draw new position
		sw $t1, player_position
		lw $t2, green_1
		add $t1, $t1, $t0
		sw $t2, ($t1)
		
	sleep_and_loop:
		# Prints once per loop
		li $v0, 4
		la $a0, test_str
		syscall
		
		li $v0, 32
		li $a0, WAIT_TIME
		syscall
		j game_loop

init_level:
	li $t0, BASE_ADDRESS 	# $t0 stores the base address for display
	lw $t1, red_1		# $t1 stores the red colour code
	lw $t2, green_1		# $t2 stores the green colour code
	lw $t3, blue_1		# $t3 stores the blue colour code
	
	sw $t1, 0($t0)		# paint the first (top-left) unit red. (0,0) = 0*4 + 0*256
	sw $t2, 4($t0) 		# paint the second unit on the first row green. Why $t0+4? (1, 0) = (0*64 + 1)*4
	sw $t3, 256($t0)	# paint the first unit on the second row blue. Why +256? (0,1) = (1*64 + 0)*4
	
	sw $t2, 16128($t0) 	# draw player initial position (bottom left)
	
	jr $ra

end:
	# Print end message
	li $v0, 4
	la $a0, end_str
	syscall
	
	li $v0, 10 	# terminate the program gracefully
	syscall