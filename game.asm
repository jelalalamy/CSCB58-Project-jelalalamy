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
# Constants
.eqv BASE_ADDRESS 0x10008000
.eqv WAIT_TIME 40
.eqv JUMP_HEIGHT 6
.eqv RED_1 0xff0000
.eqv GREEN_1 0x00ff00
.eqv BLUE_1 0x0000ff
.eqv BLACK 0x000000

.data
# Strings
start_str: .asciiz "Game started\n"
end_str: .asciiz "Game finished\n"
pressed_q: .asciiz "Pressed q - ending game\n"
test_str: .asciiz "Something happened\n"

# Player (coords refer to the player's feet
player_x: .word 0
player_y: .word 61
player_position: .word 0
player_on_platform: .word 0

# Platforms
platforms_3: .word 14888, 14952
platforms_3_length: .word 2 

# Counters
jump_counter: .word 0
array_counter: .word 0

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
	j check_player_state
	
	keypress_happened:
		lw $t2, 4($t9)
		beq $t2, 0x64, move_player_coords_right
		beq $t2, 0x61, move_player_coords_left
		beq $t2, 0x20, start_jump
		beq $t2, 0x77, move_player_coords_up
		beq $t2, 0x73, move_player_coords_down
		beq $t2, 0x71, respond_to_q
		j check_player_state
	
	respond_to_q:
		li $v0, 4
		la $a0, pressed_q
		syscall
		jr $ra
		
	check_player_state:
		# Floor is y=62, so check if player has y=61
		lw $t1, player_y
		seq $t2, $t1, 61
		sw $t2, player_on_platform
		bgtz $t2, sleep_and_loop
		# Check if a player is currently jumping, on a platform, or falling
		lw $t1, jump_counter
		bgtz $t1, jumping
		j falling
		
		# to check collision, keep an array of platform pixels?
		
	start_jump:
		# Set jump counter
		lw $t1, player_on_platform
		beqz $t1, sleep_and_loop
		li $t1, JUMP_HEIGHT
		sw $t1, jump_counter
		j jumping
		
	jumping:
		# Decrement jump_counter and move player up
		lw $t1, jump_counter
		addi $t1, $t1, -1
		sw $t1, jump_counter
		j move_player_coords_up
		
	falling:
		j move_player_coords_down
		
	move_player_coords_right:
		# Get player coordinates
		lw $s0, player_x
		lw $s1, player_y
		# If the player is already at the right edge, do not move
		beq $s0, 63, sleep_and_loop
		# Increment by 1 to move right
		addi $s0, $s0, 1
		sw $s0, player_x
		j update_player_position
		
	move_player_coords_left:
		# Get player coordinates
		lw $s0, player_x
		lw $s1, player_y
		# If the player is already at the left edge, do not move
		beq $s0, 0, sleep_and_loop
		# Decrement by 1 to move left
		addi $s0, $s0, -1
		sw $s0, player_x
		j update_player_position

	move_player_coords_up:
		# Get player coordinates
		lw $s0, player_x
		lw $s1, player_y
		# If the player is already at the top edge, do not move
		beq $s1, 0, sleep_and_loop
		# Decrement by 1 to move up
		addi $s1, $s1, -1
		sw $s1, player_y
		j update_player_position
		
	move_player_coords_down:
		# Get player coordinates
		lw $s0, player_x
		lw $s1, player_y
		# If the player is already at the bottom edge, do not move
		beq $s1, 63, sleep_and_loop
		# Increment by 1 to move up
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
		li $t2, BLACK
		lw $s2, player_position
		add $s2, $s2, $t0
		sw $t2, ($s2)
		
		# Draw new position
		sw $t1, player_position
		li $t2, GREEN_1
		add $t1, $t1, $t0
		sw $t2, ($t1)
		
	sleep_and_loop:
		# Prints once per loop
		#li $v0, 4
		#la $a0, test_str
		#syscall
		
		li $v0, 32
		li $a0, WAIT_TIME
		syscall
		j game_loop

init_level:
	# Draw floor
	draw_floor:
		li $t0, BASE_ADDRESS 	# $t0 stores the base address for display
		li $t1, RED_1		# $t1 stores the red colour code
		li $t2, 0	# loop counter
		li $t3, 15872
		add $t3, $t3, $t0

	loop_draw_floor:
		bgt $t2, 63, end_draw_floor
		sw $t1, ($t3)
		add $t3, $t3, 4
		add $t2, $t2, 1
		j loop_draw_floor
	
	end_draw_floor:
	
	draw_platforms_3:
		li $t0, BASE_ADDRESS	# base address for display
		li $t1, BLUE_1		# blue colour code
		li $t2, 0		# loop counter
		la $t3, platforms_3	# array address
		lw $t4, platforms_3_length	# array length
		
	loop_draw_platforms_3:
		bge $t2, 2, end_draw_platforms_3	# if loop counter >= array length (since we start at 0), stop
		sll $t5, $t2, 2		# multiply loop counter by 4 to get byte offset
		add $t5, $t5, $t3	# add byte offset to array address
		lw $a0, ($t5)		# store array element in $a0
		add $t5, $a0, $t0	# add base address
		sw $t1, ($t5)		# colour blue
		add $t5, $t5, 4
		sw $t1 ($t5)
		add $t5, $t5, 4
		sw $t1 ($t5)
		add $t2, $t2, 1		# increment loop counter
    		j loop_draw_platforms_3
    		
    	end_draw_platforms_3:
	
	# Draw player initial position
	# Compute position according to formula (x, y) = (y*64 + x)*4 and store in $t1
	lw $s0, player_x
	lw $s1, player_y
	mul $t1, $s1, 64
	add $t1, $t1, $s0
	mul $t1, $t1, 4
	sw $t1, player_position
	add $t1, $t1, $t0
	li $t2, GREEN_1
	sw $t2, ($t1)
	
	jr $ra
	
end:
	# Print end message
	li $v0, 4
	la $a0, end_str
	syscall
	
	li $v0, 10 	# terminate the program gracefully
	syscall
