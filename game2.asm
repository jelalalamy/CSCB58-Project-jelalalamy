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
.eqv ORANGE_1 0xF39C12
.eqv GREEN_1 0x229954
.eqv GREEN_2 0xA3EB41
.eqv BLUE_1 0x0000ff
.eqv BLUE_2 0x00b9ff
.eqv PURPLE_1 0x3F48CC
.eqv BLACK 0x000000

.data
# Strings
start_str: .asciiz "Game started\n"
end_str: .asciiz "Game finished\n"
pressed_q: .asciiz "Pressed q - ending game\n"
test_str: .asciiz "Something happened\n"
loop_str: .asciiz "Sleeping then looping\n"

# Player state
player_x: .word 5	# ranges from 0-63
player_y: .word 90	# ranges from 0-63
player_x_velocity: .word 0
player_y_velocity: .word 0
player_direction: .word	1	# 0 for left, 1 for right
player_state: .word 2	# 0 for on platform, 1 for jumping, 2 for falling
jump_frame: .word 0
jump_type: .word 0	# 0 for short, 1 for mid, 2 for long, 3 for high

# Platforms
collision_pixels: .space 4096
collision_pixels_len: .word 0

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

# Check the player state (0 = on platform 1 = jumping, 2 = falling)
check_player_state:
	lw $t1, player_state
	# Only allow inputs while on a platform
	beq $t1, 0, on_platform
	# If jumping
	beq $t1, 1, jumping
	# If falling,
	beq $t1, 2, falling

on_platform:
	sw $zero, player_x_velocity
	sw $zero, player_y_velocity
	j handle_inputs

falling:
	li $t1, 1
	sw $t1, player_y_velocity
	# For now set the player x velocity to 0, eventually we want to preserve velocity when falling after jumping
	sw $zero, player_x_velocity
	j update_player_position

jumping:
	lw $t1, jump_type
	beq $t1, 0, short_jump
			
# Update locations and stuff
handle_inputs:	
	# $t3 currently stores the key pressed
	# Move using wasd
	beq $t3, 0x61, a_pressed
	beq $t3, 0x64, d_pressed
	beq $t3, 0x6A, start_short_jump
	beq $t3, 0x20, start_high_jump
	j update_player_position

start_short_jump:
	sw $zero, jump_frame
	li $t1, 1
	sw $t1, player_state
	j short_jump
	
start_high_jump:
	sw $zero, jump_frame
	li $t1, 1
	sw $t1, player_state
	j high_jump

short_jump:
	lw $t1, player_direction
	beq $t1, 0, short_jump_left
	beq $t1, 1, short_jump_right

short_jump_right:
	lw $t1, jump_frame
	beq $t1, 0, short_jump_right_0
	beq $t1, 1, short_jump_right_0
	beq $t1, 2, short_jump_right_1
	beq $t1, 3, short_jump_right_1
	beq $t1, 4, short_jump_right_2
	beq $t1, 5, short_jump_right_2
	beq $t1, 6, end_jump
	
short_jump_right_0:
	li $t1, 1
	li $t2, -1
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
short_jump_right_1:
	li $t1, 1
	sw $t1, player_x_velocity
	sw $zero, player_y_velocity
	j update_jump_frame
	
short_jump_right_2:
	li $t1, 1
	sw $t1, player_x_velocity
	sw $t1, player_y_velocity
	j update_jump_frame
	
short_jump_left:
	lw $t1, jump_frame
	beq $t1, 0, short_jump_left_0
	beq $t1, 1, short_jump_left_0
	beq $t1, 2, short_jump_left_1
	beq $t1, 3, short_jump_left_1
	beq $t1, 4, short_jump_left_2
	beq $t1, 5, short_jump_left_2
	beq $t1, 6, end_jump
	
short_jump_left_0:
	li $t1, -1
	sw $t1, player_x_velocity
	sw $t1, player_y_velocity
	j update_jump_frame
	
short_jump_left_1:
	li $t1, -1
	sw $t1, player_x_velocity
	sw $zero, player_y_velocity
	j update_jump_frame
	
short_jump_left_2:
	li $t1, -1
	li $t2, 1
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame

high_jump:
	lw $t1, player_direction
	beq $t1, 0, high_jump_left
	beq $t1, 1, high_jump_right

high_jump_right:
	lw $t1, jump_frame
	beq $t1, 0, high_jump_right_0
	beq $t1, 1, high_jump_right_0
	beq $t1, 2, high_jump_right_1
	beq $t1, 3, high_jump_right_1
	beq $t1, 4, end_jump
	
high_jump_right_0:
	li $t1, 1
	li $t2, -4
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
high_jump_right_1:
	li $t1, 1
	li $t2, 4
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
high_jump_left:
	lw $t1, jump_frame
	beq $t1, 0, high_jump_left_0
	beq $t1, 1, high_jump_left_0
	beq $t1, 2, high_jump_left_1
	beq $t1, 3, high_jump_left_1
	beq $t1, 4, end_jump
	
high_jump_left_0:
	li $t1, -1
	li $t2, -4
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
high_jump_left_1:
	li $t1, -1
	li $t2, 4
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame

update_jump_frame:
	lw $t1, jump_frame
	add $t1, $t1, 1
	sw $t1, jump_frame
	j update_player_position

end_jump:
	sw $zero, player_x_velocity
	sw $zero, player_y_velocity
	sw $zero, jump_frame
	li $t1, 2
	sw $t1, player_state
	j check_collisions

a_pressed:
	lw $t1, player_direction
	beq $t1, 1, turn_left
	li $t2, -1
	sw $t2, player_x_velocity
	j update_player_position
turn_left:
	sw $zero, player_direction
	sw $zero, player_x_velocity
	j update_player_position
	
d_pressed:
	lw $t1, player_direction
	beq $t1, 0, turn_right
	li $t2, 1
	sw $t2, player_x_velocity
	j update_player_position
turn_right:
	li $t2, 1
	sw $t2, player_direction
	li $t2, 0
	sw $t2, player_x_velocity
	j update_player_position
	
# Update player position based on velocity
update_player_position:
	# Store player current position so we can erase it later (use $k0 and $k1 for now)
	lw $k0, player_x
	lw $k1, player_y
	
	lw $t1, player_x
	lw $t2, player_y
	lw $t3, player_x_velocity
	lw $t4, player_y_velocity
update_x:
	add $t1, $t1, $t3
	bge $t1, 62, hit_right_edge
	ble $t1, 1, hit_left_edge
	j update_x_position
hit_right_edge:
	li $t1, 62
	j update_x_position
hit_left_edge:
	li $t1, 1
update_x_position:
	sw $t1, player_x
update_y:
	add $t2, $t2, $t4
	bge $t2, 127, hit_bottom_edge
	ble $t2, 3, hit_top_edge
	j update_y_position
hit_bottom_edge:
	li $t2, 127
	j update_y_position
hit_top_edge:
	li $t2, 3
update_y_position:
	sw $t2, player_y

# Check for collisions
check_collisions:

#check_portal_collisions:
#	lw $a1, player_x
#	lw $a2, player_y
#	jal compute_position_func
#	beq $a0, 29384, red_tp
#	j check_platform_collisions
	
#red_tp:
#	li $t1, 10
#	li $t2, 105
#	sw $t1, player_x
#	sw $t2, player_y

check_platform_collisions:
	# loop through collision pixels and compare player_x +- 4
	lw $t0, collision_pixels_len
	li $t1, 0 # t1 is the index

loop_check_collisions:
	bge $t1, $t0, end_loop_check_collisions
	lw $t4, collision_pixels($t1)
	lw $t2, player_x
	lw $a2, player_y
check_left_foot:
	add $a1, $t2, -1
	jal compute_position_func
	beq $a0, $t4, collided_with_platform_top
check_right_foot:
	add $a1, $t2, 1
	jal compute_position_func
	beq $a0, $t4, collided_with_platform_top
	add $t1, $t1, 4
	j loop_check_collisions
end_loop_check_collisions:
	lw $t1, player_state
	beq $t1, 1, erase_old_objects
	beq $t1, 2, erase_old_objects
	li $t2, 2
	sw $t2, player_state
	j erase_old_objects
		
collided_with_platform_top:
	li $t1, 0
	sw $t1, player_state

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
	#li $v0, 4
	#la $a0, loop_str
	#syscall
	
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
	# $t1 will be used to store collision pixels
	add $t1, $a0, -256
	lw $t3, collision_pixels_len
	
	li $t0, BASE_ADDRESS
	add $a0, $a0, $t0
	# Compute the end position based on the length
	mul $a1, $a1, 4
	add $a1, $a1, $a0

loop_draw_platform:
	bgt $a0, $a1, end_draw_platform
	# Draw the platform
	sw $a2, ($a0)
	# Store the above pixel in collision_pixels
	sw $t1, collision_pixels($t3)
	#li $t4, BLUE_1
	#add $t2, $t1, $t0
	#sw $t4, ($t2)
	add $t1, $t1, 4
	add $t3, $t3, 4
	sw $t3, collision_pixels_len
	# Loop
	add $a0, $a0, 4
	j loop_draw_platform

end_draw_platform:
	jr $ra
	
# Helper function to draw
	
# Helper function to draw the player
# Parameters:
# $a0 - position (compute using compute_position_func, or just pass an immediate)
draw_player_func:
	li $t0, BASE_ADDRESS
	li $t1, RED_1
	li $t2, BLUE_2
	add $a0, $a0, $t0
	# Draw feet
	add $t3, $a0, 4
	sw $t1, ($t3)
	add $t3, $a0, -4
	sw $t1, ($t3)
	# Draw lower body
	add $a0, $a0, -256
	sw $t1, ($a0)
	add $t3, $a0, 4
	sw $t1, ($t3)
	add $t3, $a0, -4
	sw $t1, ($t3)
	# Draw middle body
	lw $t4, player_direction
	beq $t4, 0, draw_upper_left
	add $a0, $a0, -256
	sw $t2, ($a0)
	add $t3, $a0, 4
	sw $t2, ($t3)
	add $t3, $a0, -4
	sw $t1, ($t3)
	j draw_upper_body
draw_upper_left:
	add $a0, $a0, -256
	sw $t2, ($a0)
	add $t3, $a0, 4
	sw $t1, ($t3)
	add $t3, $a0, -4
	sw $t2, ($t3)	
draw_upper_body:
	# Draw upper body
	add $a0, $a0, -256
	sw $t1, ($a0)
	add $t3, $a0, 4
	sw $t1, ($t3)
	add $t3, $a0, -4
	sw $t1, ($t3)	
	jr $ra
	
# Helper function to erase the player (usually their previous location)
# Parameters:
# $a0 - position (compute using compute_position_func, or just pass an immediate)
erase_player_func:
	li $t0, BASE_ADDRESS
	li $t1, BLACK
	add $a0, $a0, $t0
	# Erase feet
	add $t3, $a0, 4
	sw $t1, ($t3)
	add $t3, $a0, -4
	sw $t1, ($t3)
	# Erase lower body
	add $a0, $a0, -256
	sw $t1, ($a0)
	add $t3, $a0, 4
	sw $t1, ($t3)
	add $t3, $a0, -4
	sw $t1, ($t3)
	# Erase middle body
	add $a0, $a0, -256
	sw $t1, ($a0)
	add $t3, $a0, 4
	sw $t1, ($t3)
	add $t3, $a0, -4
	sw $t1, ($t3)
	# Erase upper body
	add $a0, $a0, -256
	sw $t1, ($a0)
	add $t3, $a0, 4
	sw $t1, ($t3)
	add $t3, $a0, -4
	sw $t1, ($t3)	

# Function to draw the inital level (platforms and stuff)
# No parameters or return 
init_level_func:
	# Store $ra on the stack since we'll be calling the compute position function
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
# Draw floor
draw_floor:
	li $t0, BASE_ADDRESS 		
	# We want to draw the floor at y=126 with a length of 63 (the entire row)
	# Use the draw_platform_func function
	li $a0, 25600
	li $a1, 63
	li $a2, GREEN_1
	jal draw_platform_func
	
draw_platforms:
	
	sw $a2, 29384($t0)
	
draw_amongus:
	li $t0, BASE_ADDRESS
	li $t6, PURPLE_1
	li $t7, BLUE_2
	# Purple amongus on floor
	sw $t6, 25396($t0)
	sw $t6, 25140($t0)
	li $a0, 24884
	li $a1, 0
	li $a2, PURPLE_1
	jal draw_platform_func
	sw $t6, 25400($t0)
	sw $t7, 25144($t0)
	li $a0, 24888
	li $a1, 0
	li $a2, BLUE_2
	jal draw_platform_func
	sw $t6, 25404($t0)
	sw $t6, 25148($t0)
	li $a0, 24892
	li $a1, 1
	li $a2, PURPLE_1
	jal draw_platform_func
	sw $t6, 25408($t0)
	
	# Orange amongus on floor
	li $t6, ORANGE_1
	sw $t6, 25464($t0)
	sw $t6, 25468($t0)
	sw $t7, 25472($t0)
	sw $t6, 25476($t0)
	sw $t6, 25212($t0)
	sw $t7, 25216($t0)
	sw $t6, 25220($t0)
	li $a0, 24952
	li $a1, 3
	li $a2, ORANGE_1
	jal draw_platform_func
	
	# Green amongus on floor
	li $t6, GREEN_2
	sw $t6, 25588($t0)
	sw $t6, 25592($t0)
	sw $t6, 25596($t0)
	sw $t6, 25336($t0)
	sw $t6, 25340($t0)
	sw $t7, 25080($t0)
	sw $t6, 25084($t0)
	li $a0, 24824
	li $a1, 1
	li $a2, GREEN_2
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
