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
# - yes, and please share this project github link as well!
#
# Any additional information that the TA needs to know:
# - Controls:
# - a: move left
# - d: move right
# - j: short jump
# - k: middle jump
# - l: long jump
# - space: high jump
#
##################################################################### DATA
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
loop_str: .asciiz "Sleeping then looping\n"

# Player state
player_x: .word 0	# ranges from 0-63
player_y: .word 61	# ranges from 0-63
player_direction: .word	1	# 0 for left, 1 for right
player_state: .word 0	# 0 for on platform, 1 for jumping, 2 for falling
jump_frame: .word 0

##################################################################### MAIN
.text
.globl main
main:
	# Print start message
	li $v0, 4
	la $a0, start_str
	syscall	
	
	# Init level
	jal init_level_func
	
	# Init player
	jal init_player_func
	
	# Main game loop
	jal game_loop_func
	
	# Finished game
	j end

end:
	# Print end message
	li $v0, 4
	la $a0, end_str
	syscall	
	
	# Terminate program
	li $v0, 10 
	syscall

##################################################################### GAME LOOP
# Function for the game loop, doesn't require any arguments
game_loop_func:
	# Store $ra on the stack so we can return to main later
	addi $sp, $sp, -4
	sw $ra, 0($sp)

# Main loop
game_loop:
# Check for user input
check_user_input:
	li $t1, 0xffff0000
	lw $t2, 0($t1)
	# If no key was pressed, move on to next step
	li $t3, 0
	bne $t2, 1, check_player_state
	# If key was pressed, store it in $t3
	lw $t3, 4($t1)
	# If q was pressed, then quit immediately, otherwise continue to check_on_platform
	beq $t3, 0x71, game_loop_return

# Check if the player is on a platform
check_player_state:
	
# Update locations and stuff
update_player_position:
	# Store player current position so we can erase it later (use $k0 and $k1 for now)
	lw $k0, player_x
	lw $k1, player_y
	
	# $t3 currently stores the key pressed
	# Move using wasd
	beq $t3, 0x61, move_player_left
	beq $t3, 0x64, move_player_right
	beq $t3, 0x77, move_player_up
	beq $t3, 0x73, move_player_down
	beq $t3, 0x6A, short_jump
	j check_collisions

short_jump:
	# For now a short jump will have 8 frames: up, right, up, right, right, down, right, down
	# Move the player depending on the jump frame
	j check_collisions

move_player_left:
	lw $t1, player_x
	# Do not move the player if they are at the right edge already
	beq $t1, 0, check_collisions
	add $t1, $t1, -1
	sw $t1, player_x
	j check_collisions
	
move_player_right:
	lw $t1, player_x
	# Do not move the player if they are at the right edge already
	beq $t1, 63, check_collisions
	add $t1, $t1, 1
	sw $t1, player_x
	j check_collisions
	
move_player_up:
	lw $t1, player_y
	# Do not move the player if they are at the right edge already
	beq $t1, 0, check_collisions
	add $t1, $t1, -1
	sw $t1, player_y
	j check_collisions

move_player_down:
	lw $t1, player_y
	# Do not move the player if they are at the right edge already
	beq $t1, 63, check_collisions
	add $t1, $t1, 1
	sw $t1, player_y
	j check_collisions

# Check for collisions
check_collisions:

# Update other game states (if needed)

# Erase old objects
erase_old_objects:
	# Compute their position and then call erase_player_func
	add $a1, $k0, 0
	add $a2, $k1, 0
	jal compute_position_func
	# $a0 already stores the position so we can call erase_player_func immediately
	jal erase_player_func
	
# Draw new objects
draw_new_objects:
# Draw player in the new position
draw_new_player:
	# Compute their position and then call draw_player_func
	lw $a1, player_x
	lw $a2, player_y
	jal compute_position_func
	# $a0 already stores the position so we can call draw_player_func immediately
	jal draw_player_func
	
# Sleep and loop
sleep_and_loop:
	li $v0, 4
	la $a0, loop_str
	syscall
	
	li $v0, 32
	li $a0, WAIT_TIME
	syscall
	j game_loop
	
# Return to main
game_loop_return:
	lw $t1, 0($sp)
	addi $sp, $sp, 4
	jr $t1

##################################################################### GAME HELPER FUNCTIONS
# Helper function to draw platforms
# Parameters:
# $a0 - starting position (compute using compute_position_func, or just pass an immediate)
# $a1 - length
# $a2 - colour
draw_platform_func:
	li $t0, BASE_ADDRESS
	add $a0, $a0, $t0
	# Compute the end position based on the length
	mul $a1, $a1, 4
	add $a1, $a1, $a0

loop_draw_platform:
	bgt $a0, $a1, end_draw_platform
	sw $a2, ($a0)
	add $a0, $a0, 4
	j loop_draw_platform

end_draw_platform:
	jr $ra
	
# Helper function to draw the player
# Parameters:
# $a0 - position (compute using compute_position_func, or just pass an immediate)
draw_player_func:
	li $t0, BASE_ADDRESS
	li $t1, GREEN_1
	add $a0, $a0, $t0
	sw $t1, ($a0)
	jr $ra
	
# Helper function to erase the player (usually their previous location)
# Parameters:
# $a0 - position (compute using compute_position_func, or just pass an immediate)
erase_player_func:
	li $t0, BASE_ADDRESS
	li $t1, BLACK
	add $a0, $a0, $t0
	sw $t1, ($a0)
	jr $ra

# Function to draw the inital level (platforms and stuff)
# No parameters or return 
init_level_func:
	# Store $ra on the stack since we'll be calling the compute position function
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
# Draw floor
draw_floor:
	li $t0, BASE_ADDRESS 		
	# We want to draw the floor at y=62 with a length of 63 (the entire row)
	# Use the draw_platform_func function
	li $a0, 15872
	li $a1, 63
	li $a2, RED_1
	jal draw_platform_func
	
init_level_return:
	# Return to main
	lw $t1, 0($sp)
	addi $sp, $sp, 4
	jr $t1
	
# Function to draw the player in their initial position
# No parameters or return
init_player_func:
	# Store $ra on the stack since we'll be calling some functions
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	# Use helper to compute position
	lw $a1, player_x
	lw $a2, player_y
	jal compute_position_func
	# $a0 already stores the position so we can call draw_player_func immediately
	jal draw_player_func
	
	# Return to main
	lw $t1, 0($sp)
	addi $sp, $sp, 4
	jr $t1	

##################################################################### UTILITY HELPER FUNCTIONS
# Helper function to compute position based on x and y coordinates
# Using the formula pos(x,y) = (y*64 + x)*4
# NOTE: still need to add base address after computing position
# Pass in x and y as $a1 and $a2, return position in $a0
compute_position_func:	
	mul $a0, $a2, 64
	add $a0, $a0, $a1
	mul $a0, $a0, 4
	jr $ra
