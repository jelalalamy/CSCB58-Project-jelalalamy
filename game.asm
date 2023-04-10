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
# - Display height in pixels: 1024
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
.eqv MAX_TIME 120000
.eqv JUMP_HEIGHT 6

# Colours
.eqv RED_1 0xff0000
.eqv RED_2 0xE53935
.eqv ORANGE_1 0xF39C12
.eqv ORANGE_2 0xFF6F00
.eqv YELLOW_1 0xF4D03F 
.eqv GREEN_1 0x229954
.eqv GREEN_2 0xA3EB41
.eqv GREEN_3 0x1B5E20
.eqv BLUE_1 0x0000ff
.eqv BLUE_2 0x00b9ff
.eqv PURPLE_1 0x3F48CC
.eqv PINK_1 0xEF9A9A
.eqv PINK_2 0xFFCDD2
.eqv PINK_3 0xFFEBEE
.eqv BROWN_1 0x8D6E63
.eqv BROWN_2 0xA1887F
.eqv BROWN_3 0xBCAAA4
.eqv TEAL_1 0x4DB6AC
.eqv TEAL_2 0x80CBC4
.eqv TEAL_3 0xB2DFDB
.eqv SAND_1 0xFFD54F
.eqv SAND_2 0xFFE082
.eqv SAND_3 0xFFECB3
.eqv CYAN_1 0x4DD0E1
.eqv CYAN_2 0x80DEEA
.eqv CYAN_3 0xB2EBF2
.eqv BLACK 0x000000
.eqv GRAY 0x7F8C8D

.data
# Strings
start_str: .asciiz "Game started\n"
end_str: .asciiz "Game finished\n"
main_menu_str: .asciiz "In main menu\n"
init_level_str: .asciiz "Initializing level\n"
pressed_q: .asciiz "Pressed q - ending game\n"
test_str: .asciiz "Something happened\n"
loop_str: .asciiz "Sleeping then looping\n"
newline: .asciiz "\n"

# Player state
player_x: .word 5	# ranges from 0-123
player_y: .word 91	# ranges from 0-123
player_x_velocity: .word 0
player_y_velocity: .word 0
player_direction: .word	1	# 0 for left, 1 for right
player_state: .word 2		# 0 for on platform, 1 for jumping, 2 for falling
player_collided_right: .word 0	# 0 if colliding with right side of a platform, 1 otherwise
player_collided_left: .word 0
player_collided_bottom: .word 0
jump_frame: .word 0
jump_type: .word 0	# 0 for short, 1 for mid, 2 for long, 3 for high

# Collision pixels
top_collision_pixels: .space 4096
top_collision_pixels_len: .word 0
left_collision_pixels: .space 4096
left_collision_pixels_len: .word 0
right_collision_pixels: .space 4096
right_collision_pixels_len: .word 0
bottom_collision_pixels: .space 4096
bottom_collision_pixels_len: .word 0

# Portals
redraw_red_tp: .word 0
redraw_pink_tp: .word 0
redraw_brown_tp: .word 0
redraw_teal_tp: .word 0
redraw_sand_tp: .word 0
redraw_cyan_tp: .word 0
redraw_green_tp: .word 0
redraw_rocket: .word 0

# Timer
start_time_lo: .word 0
start_time_hi: .word 0

# Score
score: .word 0

##################################################################### MAIN
.text
.globl main
main:
main_menu:
	# Display main menu
	li $v0, 4
	la $a0, main_menu_str
	syscall	
	jal display_main_menu_func

main_menu_loop:
	li $t1, 0xffff0000
	lw $t2, 0($t1)
	# If no key was pressed, loop
	bne $t2, 1, main_menu_loop
	# If key was pressed, check if it was s or q (or neither)
	lw $t3, 4($t1)
	beq $t3, 0x73, game
	beq $t3, 0x71, end
	j main_menu_loop

game:	
	# Print start message
	li $v0, 4
	la $a0, start_str
	syscall	

	# Init level
	jal init_level_func
	
	# Init player
	jal init_player_func
	
	# Score 0
	lw $a1, score
	li $a0, 27580
	jal set_num_display_func
	
	# Start timer
	jal start_timer_func
	
	# Main game loop
	jal game_loop_func
	
	# Finished game
	jal display_end_screen_func
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
	# If p was pressed, reset game
	beq $t3, 0x70, reset_game
	# If q was pressed, then quit immediately, otherwise continue to check_on_platform
	beq $t3, 0x71, game_loop_return
	j check_player_state

reset_game:
	# Erase player
	lw $a1, player_x
	lw $a2, player_y
	jal compute_position_func
	# $a0 already stores the position so we can call erase_player_func immediately
	jal erase_player_func
	# Moveto beginning
	li $t0, 5
	li $t1, 91
	sw $t0, player_x
	sw $t1, player_y
	# Reset score
	sw $zero, score
	lw $a1, score
	li $a0, 27580
	jal set_num_display_func
	# Reset timer
	li $v0, 30
	syscall
	sw $a0, start_time_lo
	sw $a1, start_time_hi
	j game_loop

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
	beq $t1, 1, mid_jump
	beq $t1, 2, long_jump
	beq $t1, 3, high_jump
			
# Update locations and stuff
handle_inputs:	
	# $t3 currently stores the key pressed
	# Move using wasd
	beq $t3, 0x61, a_pressed
	beq $t3, 0x64, d_pressed
	beq $t3, 0x6A, start_short_jump
	beq $t3, 0x6B, start_mid_jump
	beq $t3, 0x6C, start_long_jump
	beq $t3, 0x20, start_high_jump
	j update_player_position

start_short_jump:
	sw $zero, jump_frame
	li $t1, 1
	sw $t1, player_state
	sw $zero, jump_type
	j short_jump
	
start_mid_jump:
	sw $zero, jump_frame
	li $t1, 1
	sw $t1, player_state
	li $t1, 1
	sw $t1, jump_type
	j mid_jump
	
start_long_jump:
	sw $zero, jump_frame
	li $t1, 1
	sw $t1, player_state
	li $t1, 2
	sw $t1, jump_type
	j long_jump
	
start_high_jump:
	sw $zero, jump_frame
	li $t1, 1
	sw $t1, player_state
	li $t1, 3
	sw $t1, jump_type
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
	
mid_jump:
	lw $t1, player_direction
	beq $t1, 0, mid_jump_left
	beq $t1, 1, mid_jump_right

mid_jump_right:
	lw $t1, jump_frame
	beq $t1, 0, mid_jump_right_0
	beq $t1, 1, mid_jump_right_0
	beq $t1, 2, mid_jump_right_0
	beq $t1, 3, mid_jump_right_1
	beq $t1, 4, mid_jump_right_1
	beq $t1, 5, mid_jump_right_1
	beq $t1, 6, mid_jump_right_1
	beq $t1, 7, mid_jump_right_2
	beq $t1, 8, mid_jump_right_2
	beq $t1, 9, mid_jump_right_2
	beq $t1, 10, end_jump
	
mid_jump_right_0:
	li $t1, 1
	li $t2, -1
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
mid_jump_right_1:
	li $t1, 1
	sw $t1, player_x_velocity
	sw $zero, player_y_velocity
	j update_jump_frame
	
mid_jump_right_2:
	li $t1, 1
	sw $t1, player_x_velocity
	sw $t1, player_y_velocity
	j update_jump_frame
	
mid_jump_left:
	lw $t1, jump_frame
	beq $t1, 0, mid_jump_left_0
	beq $t1, 1, mid_jump_left_0
	beq $t1, 2, mid_jump_left_0
	beq $t1, 3, mid_jump_left_1
	beq $t1, 4, mid_jump_left_1
	beq $t1, 5, mid_jump_left_1
	beq $t1, 6, mid_jump_left_1
	beq $t1, 7, mid_jump_left_2
	beq $t1, 8, mid_jump_left_2
	beq $t1, 9, mid_jump_left_2
	beq $t1, 10, end_jump
	
mid_jump_left_0:
	li $t1, -1
	sw $t1, player_x_velocity
	sw $t1, player_y_velocity
	j update_jump_frame
	
mid_jump_left_1:
	li $t1, -1
	sw $t1, player_x_velocity
	sw $zero, player_y_velocity
	j update_jump_frame
	
mid_jump_left_2:
	li $t1, -1
	li $t2, 1
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
long_jump:
	lw $t1, player_direction
	beq $t1, 0, long_jump_left
	beq $t1, 1, long_jump_right

long_jump_right:
	lw $t1, jump_frame
	beq $t1, 0, long_jump_right_0
	beq $t1, 1, long_jump_right_0
	beq $t1, 2, long_jump_right_0
	beq $t1, 3, long_jump_right_0
	beq $t1, 4, long_jump_right_1
	beq $t1, 5, long_jump_right_1
	beq $t1, 6, long_jump_right_1
	beq $t1, 7, long_jump_right_1
	beq $t1, 8, long_jump_right_1
	beq $t1, 9, long_jump_right_1
	beq $t1, 10, long_jump_right_2
	beq $t1, 11, long_jump_right_2
	beq $t1, 12, long_jump_right_2
	beq $t1, 13, long_jump_right_2
	beq $t1, 14, end_jump
	
long_jump_right_0:
	li $t1, 1
	li $t2, -1
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
long_jump_right_1:
	li $t1, 1
	sw $t1, player_x_velocity
	sw $zero, player_y_velocity
	j update_jump_frame
	
long_jump_right_2:
	li $t1, 1
	sw $t1, player_x_velocity
	sw $t1, player_y_velocity
	j update_jump_frame
	
long_jump_left:
	lw $t1, jump_frame
	beq $t1, 0, long_jump_left_0
	beq $t1, 1, long_jump_left_0
	beq $t1, 2, long_jump_left_0
	beq $t1, 3, long_jump_left_0
	beq $t1, 4, long_jump_left_1
	beq $t1, 5, long_jump_left_1
	beq $t1, 6, long_jump_left_1
	beq $t1, 7, long_jump_left_1
	beq $t1, 8, long_jump_left_1
	beq $t1, 9, long_jump_left_1
	beq $t1, 10, long_jump_left_2
	beq $t1, 11, long_jump_left_2
	beq $t1, 12, long_jump_left_2
	beq $t1, 13, long_jump_left_2
	beq $t1, 14, end_jump
	
long_jump_left_0:
	li $t1, -1
	sw $t1, player_x_velocity
	sw $t1, player_y_velocity
	j update_jump_frame
	
long_jump_left_1:
	li $t1, -1
	sw $t1, player_x_velocity
	sw $zero, player_y_velocity
	j update_jump_frame
	
long_jump_left_2:
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
	beq $t1, 1, high_jump_right_1
	beq $t1, 2, high_jump_right_2
	beq $t1, 3, high_jump_right_3
	beq $t1, 4, high_jump_right_4
	beq $t1, 5, end_jump
	
high_jump_right_0:
	li $t1, 0
	li $t2, -3
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
high_jump_right_1:
	li $t1, 0
	li $t2, -2
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
high_jump_right_2:
	li $t1, 1
	li $t2, -2
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
high_jump_right_3:
	li $t1, 1
	li $t2, 0
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
high_jump_right_4:
	li $t1, 1
	li $t2, 1
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
high_jump_left:
	lw $t1, jump_frame
	beq $t1, 0, high_jump_left_0
	beq $t1, 1, high_jump_left_1
	beq $t1, 2, high_jump_left_2
	beq $t1, 3, high_jump_left_3
	beq $t1, 4, high_jump_left_4
	beq $t1, 5, end_jump
	
high_jump_left_0:
	li $t1, 0
	li $t2, -3
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
high_jump_left_1:
	li $t1, 0
	li $t2, -2
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
high_jump_left_2:
	li $t1, -1
	li $t2, -2
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
high_jump_left_3:
	li $t1, -1
	li $t2, 0
	sw $t1, player_x_velocity
	sw $t2, player_y_velocity
	j update_jump_frame
	
high_jump_left_4:
	li $t1, -1
	li $t2, 1
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
	# Check if player is colliding with a platform
	lw $t5, player_collided_right
	beq $t5, 1, update_right_collision
	lw $t5, player_collided_left
	beq $t5, 1, update_left_collision
	j update_x
update_right_collision:
	ble $t3, 0, update_x
	li $t3, 0
	j update_x
update_left_collision:
	bge $t3, 0, update_x
	li $t3, 0
	j update_x
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
	# Handling collision with the bottom of a platform is different from the right/left
	lw $t5, player_collided_bottom
	beq $t5, 1, hit_platform_bottom
	bge $t2, 127, hit_bottom_edge
	ble $t2, 3, hit_top_edge
	j update_y_position
hit_bottom_edge:
	li $t2, 127
	j update_y_position
hit_top_edge:
	li $t2, 3
	j update_y_position
hit_platform_bottom:
	lw $t2, player_y
update_y_position:
	sw $t2, player_y

# Check for collisions
check_collisions:

check_ship_collision:
	lw $a1, player_x
	lw $a2, player_y
	add $a2, $a2, -1
	jal compute_position_func
	beq $a0, 2284, update_score
	j check_portal_collisions
	
update_score:
	# Update score
	lw $a1, score
	add $a1, $a1, 1
	sw $a1, score
	li $a0, 27580
	jal set_num_display_func
	# Send player to beginning
	li $t1, 5
	li $t2, 91
	sw $t1, player_x
	sw $t2, player_y
	# Redraw rocket
	li $t1, 1
	sw $t1, redraw_rocket

check_portal_collisions:
	lw $a1, player_x
	lw $a2, player_y
	add $a2, $a2, -1
	jal compute_position_func
	beq $a0, 24020, red_tp
	beq $a0, 23764, red_tp
	beq $a0, 18932, pink_tp
	beq $a0, 18676, pink_tp
	beq $a0, 16552, brown_tp
	beq $a0, 16296, brown_tp
	beq $a0, 14936, teal_tp
	beq $a0, 14680, teal_tp
	beq $a0, 7208, sand_tp
	beq $a0, 6952, sand_tp
	beq $a0, 9600, cyan_tp
	beq $a0, 9344, cyan_tp
	beq $a0, 1580, green_tp
	beq $a0, 1324, green_tp
	add $a2, $a2, -1
	jal compute_position_func
	beq $a0, 24020, red_tp
	beq $a0, 23764, red_tp
	beq $a0, 18932, pink_tp
	beq $a0, 18676, pink_tp
	beq $a0, 16552, brown_tp
	beq $a0, 16296, brown_tp
	beq $a0, 14936, teal_tp
	beq $a0, 14680, teal_tp
	beq $a0, 7208, sand_tp
	beq $a0, 6952, sand_tp
	beq $a0, 9600, cyan_tp
	beq $a0, 9344, cyan_tp
	beq $a0, 1580, green_tp
	beq $a0, 1324, green_tp
	j check_right_collisions
	
red_tp:
	li $t1, 4
	li $t2, 84
	sw $t1, player_x
	sw $t2, player_y
	li $t1, 1
	sw $t1, redraw_red_tp
	j check_right_collisions
	
pink_tp:
	li $t1, 57
	li $t2, 17
	sw $t1, player_x
	sw $t2, player_y
	li $t1, 1
	sw $t1, redraw_pink_tp
	j check_right_collisions
	
brown_tp:
	li $t1, 6
	li $t2, 65
	sw $t1, player_x
	sw $t2, player_y
	li $t1, 1
	sw $t1, redraw_brown_tp
	j check_right_collisions
	
teal_tp:
	li $t1, 3
	li $t2, 16
	sw $t1, player_x
	sw $t2, player_y
	li $t1, 1
	sw $t1, redraw_teal_tp
	j check_right_collisions
	
sand_tp:
	li $t1, 35
	li $t2, 11
	sw $t1, player_x
	sw $t2, player_y
	li $t1, 1
	sw $t1, redraw_sand_tp
	j check_right_collisions
	
cyan_tp:
	li $t1, 15
	li $t2, 5
	sw $t1, player_x
	sw $t2, player_y
	li $t1, 1
	sw $t1, redraw_cyan_tp
	j check_right_collisions
	
green_tp:
	li $t1, 4
	li $t2, 99
	sw $t1, player_x
	sw $t2, player_y
	li $t1, 1
	sw $t1, redraw_green_tp
	j check_right_collisions
	

# Checking collision on the right side of the player
check_right_collisions:
	lw $t0, left_collision_pixels_len
	li $t1, 0
	
loop_check_right_collisions:
	bge $t1, $t0, end_loop_check_right_collisions
	lw $t4, left_collision_pixels($t1)
	lw $a1, player_x
	lw $a2, player_y
check_right_body:
	add $a1, $a1, 1
	jal compute_position_func
	beq $a0, $t4, collided_with_platform_right
	add $a2, $a2, -1
	jal compute_position_func
	beq $a0, $t4, collided_with_platform_right
	add $a2, $a2, -1
	jal compute_position_func
	beq $a0, $t4, collided_with_platform_right
	add $a2, $a2, -1
	jal compute_position_func
	beq $a0, $t4, collided_with_platform_right
	add $t1, $t1, 4
	j loop_check_right_collisions
	
end_loop_check_right_collisions:
	li $t1, 1
	sw $zero, player_collided_right
	j check_left_collisions
	
collided_with_platform_right:
	li $t1, 1
	sw $t1, player_collided_right
	
# Checking collisions on the left side of the player
check_left_collisions:
	lw $t0, right_collision_pixels_len
	li $t1, 0
	
loop_check_left_collisions:
	bge $t1, $t0, end_loop_check_left_collisions
	lw $t4, right_collision_pixels($t1)
	lw $a1, player_x
	lw $a2, player_y
check_left_body:
	add $a1, $a1, -1
	jal compute_position_func
	beq $a0, $t4, collided_with_platform_left
	add $a2, $a2, -1
	jal compute_position_func
	beq $a0, $t4, collided_with_platform_left
	add $a2, $a2, -1
	jal compute_position_func
	beq $a0, $t4, collided_with_platform_left
	add $a2, $a2, -1
	jal compute_position_func
	beq $a0, $t4, collided_with_platform_left
	add $t1, $t1, 4
	j loop_check_left_collisions
	
end_loop_check_left_collisions:
	li $t1, 1
	sw $zero, player_collided_left
	j check_bottom_collisions
	
collided_with_platform_left:
	li $t1, 1
	sw $t1, player_collided_left
	
# Checking collisions with the bottom of a platform
check_bottom_collisions:
	lw $t0, bottom_collision_pixels_len
	li $t1, 0
	
loop_check_bottom_collisions:
	bge $t1, $t0, end_loop_check_bottom_collisions
	lw $t4, bottom_collision_pixels($t1)
	lw $a1, player_x
	lw $a2, player_y
check_top_body:
	add $a2, $a2, -3
	jal compute_position_func
	beq $a0, $t4, collided_with_platform_bottom
	add $a1, $a1, -1
	jal compute_position_func
	beq $a0, $t4, collided_with_platform_bottom
	add $a1, $a1, 1
	jal compute_position_func
	beq $a0, $t4, collided_with_platform_bottom
	add $t1, $t1, 4
	j loop_check_bottom_collisions
	
end_loop_check_bottom_collisions:
	sw $zero, player_collided_bottom
	j check_platform_collisions
	
collided_with_platform_bottom:
	li $t1, 1
	sw $t1, player_collided_bottom

# Checking collisions with the top of a platform
check_platform_collisions:
	# loop through collision pixels and compare player_x +- 4
	lw $t0, top_collision_pixels_len
	li $t1, 0 # t1 is the index

loop_check_collisions:
	bge $t1, $t0, end_loop_check_collisions
	lw $t4, top_collision_pixels($t1)
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
	lw $t1, redraw_red_tp
	beq $t1, 1, draw_red_tp
	lw $t1, redraw_pink_tp
	beq $t1, 1, draw_pink_tp
	lw $t1, redraw_brown_tp
	beq $t1, 1, draw_brown_tp
	lw $t1, redraw_teal_tp
	beq $t1, 1, draw_teal_tp
	lw $t1, redraw_sand_tp
	beq $t1, 1, draw_sand_tp
	lw $t1, redraw_cyan_tp
	beq $t1, 1, draw_cyan_tp
	lw $t1, redraw_green_tp
	beq $t1, 1, draw_green_tp
	lw $t1, redraw_rocket
	beq $t1, 1, draw_rocket
	j draw_new_player
	
draw_rocket:
	jal draw_rocket_func
	j draw_new_player
	
draw_red_tp:
	li $a0, 24532
	li $a1, ORANGE_2
	li $a2, ORANGE_1
	li $a3, YELLOW_1
	jal draw_portal_func
	li $t1, SAND_3
	li $t0, BASE_ADDRESS
	sw $t1, 24532($t0)
	sw $zero, redraw_red_tp
	j draw_new_player
	
draw_pink_tp:
	li $a0, 19444
	li $a1, PINK_1
	li $a2, PINK_2
	li $a3, PINK_3
	jal draw_portal_func
	li $t1, TEAL_3
	li $t0, BASE_ADDRESS
	sw $t1, 19444($t0)
	sw $zero, redraw_pink_tp
	j draw_new_player
	
draw_brown_tp:
	li $a0, 17064
	li $a1, BROWN_1
	li $a2, BROWN_2
	li $a3, BROWN_3
	jal draw_portal_func
	li $t1, PINK_3
	li $t0, BASE_ADDRESS
	sw $t1, 17064($t0)
	sw $zero, redraw_brown_tp
	j draw_new_player
	
draw_teal_tp:
	li $a0, 15448
	li $a1, TEAL_1
	li $a2, TEAL_2
	li $a3, TEAL_3
	jal draw_portal_func
	li $t1, RED_2
	li $t0, BASE_ADDRESS
	sw $t1, 15448($t0)
	sw $zero, redraw_teal_tp
	j draw_new_player
	
draw_sand_tp:
	li $a0, 7720
	li $a1, SAND_1
	li $a2, SAND_2
	li $a3, SAND_3
	jal draw_portal_func
	li $t1, PURPLE_1
	li $t0, BASE_ADDRESS
	sw $t1, 7720($t0)
	sw $zero, redraw_sand_tp
	j draw_new_player
	
draw_cyan_tp:
	li $a0, 10112
	li $a1, CYAN_1
	li $a2, CYAN_2
	li $a3, CYAN_3
	jal draw_portal_func
	li $t1, ORANGE_2
	li $t0, BASE_ADDRESS
	sw $t1, 10112($t0)
	sw $zero, redraw_cyan_tp
	j draw_new_player
	
draw_green_tp:
	li $a0, 2092
	li $a1, GREEN_3
	li $a2, GREEN_1
	li $a3, GREEN_2
	jal draw_portal_func
	li $t1, CYAN_2
	li $t0, BASE_ADDRESS
	sw $t1, 2092($t0)
	sw $zero, redraw_green_tp
	j draw_new_player
	
# Draw player in the new position
draw_new_player:
	# Compute their position and then call draw_player_func
	lw $a1, player_x
	lw $a2, player_y
	jal compute_position_func
	# $a0 already stores the position so we can call draw_player_func immediately
	jal draw_player_func
	
# Update timer
update_time:
    	# Get the current time
    	li $v0, 30          # system call for getting time
    	syscall             # issue the system call

    	# Calculate the elapsed time
    	lw $t0, start_time_lo    # load the low order bits of the start time
    	lw $t1, start_time_hi    # load the high order bits of the start time
    	subu $t0, $a0, $t0       # subtract the low order bits of the start time from the current time
    	sltu $t2, $a0, $t0       # check if the current time is less than the start time
    	subu $t1, $a1, $t2       # subtract the carry from the high order bits if necessary

	# Calculate the remaining time
	li $t3, MAX_TIME
	subu $t4, $t3, $t0
	move $t7, $t4

   	# Print the elapsed time
    	#li $v0, 1	# system call for printing integer
    	#move $a0, $t4	# move the elapsed time to $a0
  	#syscall	# issue the system call
    
   	#li $v0, 4
   	#la $a0, newline
   	#syscall
  
   	
# Update time display
update_hundreds:
   	li $t1, 100000
   	div $t4, $t1
	mflo $a1
	li $a0, 27436
	jal set_num_display_func
	bge $t4, 100000, more_than_hundred
	j update_tens
	
more_than_hundred:
	add $t4, $t4, -100000
	
update_tens:
	li $t1, 10000
	div $t4, $t1
	mflo $a1
	li $a0, 27460
	jal set_num_display_func
	bge $t4, 10000, more_than_ten
	j update_ones
	
more_than_ten:
	mul $t2, $a1, -10000
	add $t4, $t4, $t2
	
update_ones:
	li $t1, 1000
	div $t4, $t1
	mflo $a1
	li $a0, 27484
	jal set_num_display_func
  	ble $t7, 0, game_loop_return
	
# Sleep and loop
sleep_and_loop:
	
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
	# Add left collision pixel
	add $t1, $a0, -4
	lw $t3, left_collision_pixels_len
	sw $t1, left_collision_pixels($t3)
	add $t3, $t3, 4
	sw $t3, left_collision_pixels_len
	
	# Add right collision pixel
	mul $a1, $a1, 4
	add $t1, $a0, $a1
	add $t1, $t1, 4
	lw $t3, right_collision_pixels_len
	sw $t1, right_collision_pixels($t3)
	add $t3, $t3, 4
	sw $t3, right_collision_pixels_len
	
	add $t1, $a0, -256
	add $t2, $a0, 256
	lw $t3, top_collision_pixels_len
	lw $t4, bottom_collision_pixels_len
	
	li $t0, BASE_ADDRESS
	add $a0, $a0, $t0
	# Compute the end position based on the length
	add $a1, $a1, $a0

loop_draw_platform:
	bgt $a0, $a1, end_draw_platform
	# Draw the platform
	sw $a2, ($a0)
	# Store the above pixel in top_collision_pixels
	sw $t1, top_collision_pixels($t3)
	# Store the below pixel in bottom_collision_pixels
	sw $t2, bottom_collision_pixels($t4)
	add $t1, $t1, 4
	add $t2, $t2, 4
	add $t3, $t3, 4
	add $t4, $t4, 4
	sw $t3, top_collision_pixels_len
	sw $t4, bottom_collision_pixels_len
	# Loop
	add $a0, $a0, 4
	j loop_draw_platform

end_draw_platform:
	jr $ra
	
# Helper function to draw portals
# Parameters:
# $a0 - position of bottom middle pixel
# $a1 - first colour
# $a2 - second colour
# $a3 - third colour
draw_portal_func:
	li $t0, BASE_ADDRESS
	# First level
	add $a0, $a0, $t0
	sw $a1, ($a0)
	# Second level
	add $a0, $a0, -256
	sw $a2, ($a0)
	add $t1, $a0, 4
	sw $a1, ($t1)
	add $t1, $a0, -4
	sw $a1, ($t1)
	# Third level
	add $a0, $a0, -256
	sw $a3, ($a0)
	add $t1, $a0, 4
	sw $a2, ($t1)
	add $t1, $t1, 4
	sw $a1, ($t1)
	add $t1, $a0, -4
	sw $a2, ($t1)
	add $t1, $t1, -4
	sw $a1, ($t1)
	# Fourth level
	add $a0, $a0, -256
	sw $a3, ($a0)
	add $t1, $a0, 4
	sw $a2, ($t1)
	add $t1, $t1, 4
	sw $a1, ($t1)
	add $t1, $a0, -4
	sw $a2, ($t1)
	add $t1, $t1, -4
	sw $a1, ($t1)
	# Fifth level
	add $a0, $a0, -256
	sw $a2, ($a0)
	add $t1, $a0, 4
	sw $a1, ($t1)
	add $t1, $a0, -4
	sw $a1, ($t1)
	# Sixth level
	add $a0, $a0, -256
	sw $a1, ($a0)
	jr $ra
	
# Helper function to draw the player
# Parameters:
# $a0 - position (compute using compute_position_func, or just pass an immediate)
draw_player_func:
	li $t0, BASE_ADDRESS
	lw $t3, score
	beq $t3, 0, zero_colour
	beq $t3, 1, one_colour
	beq $t3, 2, two_colour
	beq $t3, 3, three_colour
	beq $t3, 4, four_colour
	beq $t3, 5, five_colour
	beq $t3, 6, six_colour
	bge $t3, 7, seven_colour
	j draw_pl
	
zero_colour:
	li $t1, RED_1
	j draw_pl
	
one_colour:
	li $t1, ORANGE_2
	j draw_pl
	
two_colour:
	li $t1, CYAN_2
	j draw_pl
	
three_colour:
	li $t1, GREEN_2
	j draw_pl
	
four_colour:
	li $t1, YELLOW_1
	j draw_pl
	
five_colour:
	li $t1, PINK_2
	j draw_pl
	
six_colour:
	li $t1, RED_2
	j draw_pl
	
seven_colour:
	li $t1, TEAL_1
	j draw_pl
	
draw_pl:
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
	jr $ra	
	
# Function to draw the rocket
draw_rocket_func:
	li $t0, BASE_ADDRESS
	li $t1, RED_2
	li $t2, GRAY
	
	# Red parts
	sw $t1, 2284($t0)
	sw $t1, 2292($t0)
	sw $t1, 2276($t0)
	
	sw $t1, 2028($t0)
	sw $t1, 2036($t0)
	sw $t1, 2020($t0)
	
	sw $t1, 1772($t0)
	
	# Gray parts
	sw $t2, 1004($t0)
	sw $t2, 1260($t0)
	sw $t2, 1516($t0)
	sw $t2, 1520($t0)
	sw $t2, 1776($t0)
	sw $t2, 2032($t0)
	sw $t2, 2288($t0)
	sw $t2, 2544($t0)
	sw $t2, 1512($t0)
	sw $t2, 1768($t0)
	sw $t2, 2024($t0)
	sw $t2, 2280($t0)
	sw $t2, 2536($t0)
	
	jr $ra

# Function to draw the inital level (platforms and stuff)
# No parameters or return 
init_level_func:
	# Store $ra on the stack since we'll be calling the compute position function
	li $v0, 4
	la $a0, init_level_str
	syscall	

	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	jal clear_display_func
	
# Draw floor
draw_floor:
	li $t0, BASE_ADDRESS 		
	# We want to draw the floor at y=126 with a length of 63 (the entire row)
	# Use the draw_platform_func function
	li $a0, 25604
	li $a1, 61
	li $a2, GREEN_1
	jal draw_platform_func
	sw $a2 25600($t0)
	sw $a2 25852($t0)
	
# Draw portals
draw_portals:
	li $a0, 24532
	li $a1, ORANGE_2
	li $a2, ORANGE_1
	li $a3, YELLOW_1
	jal draw_portal_func
	li $a0, 19444
	li $a1, PINK_1
	li $a2, PINK_2
	li $a3, PINK_3
	jal draw_portal_func
	li $a0, 17064
	li $a1, BROWN_1
	li $a2, BROWN_2
	li $a3, BROWN_3
	jal draw_portal_func
	li $a0, 15448
	li $a1, TEAL_1
	li $a2, TEAL_2
	li $a3, TEAL_3
	jal draw_portal_func
	li $a0, 7720
	li $a1, SAND_1
	li $a2, SAND_2
	li $a3, SAND_3
	jal draw_portal_func
	li $a0, 10112
	li $a1, CYAN_1
	li $a2, CYAN_2
	li $a3, CYAN_3
	jal draw_portal_func
	li $a0, 2092
	li $a1, GREEN_3
	li $a2, GREEN_1
	li $a3, GREEN_2
	jal draw_portal_func
	jal draw_rocket_func

# Draw platforms	
draw_platforms:
	li $a0, 24524
	li $a1, 4
	li $a2, SAND_3
	jal draw_platform_func
	li $a0, 22024
	li $a1, 4
	li $a2, ORANGE_1
	jal draw_platform_func
	li $a0, 20776
	li $a1, 4
	li $a2, CYAN_1
	jal draw_platform_func
	li $a0, 20836
	li $a1, 5
	li $a2, PINK_1
	jal draw_platform_func
	li $a0, 20872
	li $a1, 1
	li $a2, RED_2
	jal draw_platform_func
	li $a0, 20936
	li $a1, 7
	li $a2, PURPLE_1
	jal draw_platform_func
	li $a0, 19436
	li $a1, 3
	li $a2, TEAL_3
	jal draw_platform_func
	li $a0, 4832
	li $a1, 2
	li $a2, PINK_2
	jal draw_platform_func
	li $a0, 15600
	li $a1, 2
	li $a2, BLUE_1
	jal draw_platform_func
	li $a0, 14292
	li $a1, 3
	li $a2, YELLOW_1
	jal draw_platform_func
	li $a0, 16336
	li $a1, 3
	li $a2, ORANGE_2
	jal draw_platform_func
	li $a0, 17056
	li $a1, 4
	li $a2, PINK_3
	jal draw_platform_func
	li $a0, 14224
	li $a1, 5
	li $a2, CYAN_1
	jal draw_platform_func
	li $a0, 15440
	li $a1, 5
	li $a2, RED_2
	jal draw_platform_func
	li $a0, 16972
	li $a1, 1
	li $a2, GREEN_3
	jal draw_platform_func
	li $a0, 16992
	li $a1, 1
	li $a2, BLUE_1
	jal draw_platform_func
	li $a0, 14364
	li $a1, 4
	li $a2, SAND_3
	jal draw_platform_func
	li $a0, 15620
	li $a1, 1
	li $a2, PURPLE_1
	jal draw_platform_func
	li $a0, 16912
	li $a1, 4
	li $a2, BROWN_2
	jal draw_platform_func
	li $a0, 6624
	li $a1, 2
	li $a2, RED_2
	jal draw_platform_func
	li $a0, 10468
	li $a1, 1
	li $a2, GREEN_2
	jal draw_platform_func
	li $a0, 3384
	li $a1, 1
	li $a2, YELLOW_1
	jal draw_platform_func	
	li $a0, 4356
	li $a1, 4
	li $a2, TEAL_2
	jal draw_platform_func
	li $a0, 6724
	li $a1, 3
	li $a2, BLUE_1
	jal draw_platform_func
	li $a0, 7716
	li $a1, 3
	li $a2, PURPLE_1
	jal draw_platform_func
	li $a0, 10024
	li $a1, 3
	li $a2, PINK_1
	jal draw_platform_func
	li $a0, 6148
	li $a1, 1
	li $a2, BROWN_3
	jal draw_platform_func
	li $a0, 3468
	li $a1, 1
	li $a2, SAND_2
	jal draw_platform_func
	li $a0, 4496
	li $a1, 2
	li $a2, CYAN_3
	jal draw_platform_func
	li $a0, 10108
	li $a1, 2
	li $a2, ORANGE_2
	jal draw_platform_func
	li $a0, 12412
	li $a1, 2
	li $a2, GREEN_3
	jal draw_platform_func
	li $a0, 2084
	li $a1, 6
	li $a2, CYAN_2
	jal draw_platform_func
	li $a0, 2160
	li $a1, 1
	li $a2, RED_2
	jal draw_platform_func
	li $a0, 1676
	li $a1, 1
	li $a2, GREEN_2
	jal draw_platform_func
	li $a0, 2224
	li $a1, 1
	li $a2, CYAN_3
	jal draw_platform_func
	li $a0, 2780
	li $a1, 6
	li $a2, PURPLE_1
	jal draw_platform_func
	
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
	li $a0, 25584
	li $a1, 2
	li $a2, GREEN_2
	jal draw_platform_func
	sw $t6, 25596($t0)
	sw $t6, 25332($t0)
	sw $t6, 25336($t0)
	sw $t6, 25340($t0)
	sw $t7, 25076($t0)
	sw $t7, 25080($t0)
	sw $t6, 25084($t0)
	sw $t6, 24828($t0)
	li $a0, 24820
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

# Function to start timer
start_timer_func:
	li $v0, 30
	syscall
	sw $a0, start_time_lo
	sw $a1, start_time_hi
	jr $ra
	
# Function to draw zero in a 4x7 box
# $a0 - top left position of the square
draw_zero_func:
	li $v0, 1
	li $t0, BASE_ADDRESS
	li $t1, RED_1
	add $a0, $a0, $t0
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	jr $ra
	
draw_one_func:
	li $v0, 1
	li $t0, BASE_ADDRESS
	li $t1, RED_1
	add $a0, $a0, $t0
	add $a0, $a0, 12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	jr $ra
	
draw_two_func:
	li $v0, 1
	li $t0, BASE_ADDRESS
	li $t1, RED_1
	add $a0, $a0, $t0
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	jr $ra
	
draw_three_func:
	li $v0, 1
	li $t0, BASE_ADDRESS
	li $t1, RED_1
	add $a0, $a0, $t0
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, 768
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, -256
	sw $t1, ($a0)
	add $a0, $a0, -256
	sw $t1, ($a0)
	jr $ra
	
draw_four_func:
	li $v0, 1
	li $t0, BASE_ADDRESS
	li $t1, RED_1
	add $a0, $a0, $t0
	sw $t1, ($a0)
	add $a0, $a0, 12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, 268
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	jr $ra

draw_five_func:
	li $v0, 1
	li $t0, BASE_ADDRESS
	li $t1, RED_1
	add $a0, $a0, $t0
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 244
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	jr $ra
	
draw_six_func:
	li $v0, 1
	li $t0, BASE_ADDRESS
	li $t1, RED_1
	add $a0, $a0, $t0
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 244
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -256
	sw $t1, ($a0)
	add $a0, $a0, -256
	sw $t1, ($a0)
	jr $ra
	
draw_seven_func:
	li $v0, 1
	li $t0, BASE_ADDRESS
	li $t1, RED_1
	add $a0, $a0, $t0
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	jr $ra
	
draw_eight_func:
	li $v0, 1
	li $t0, BASE_ADDRESS
	li $t1, RED_1
	add $a0, $a0, $t0
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	jr $ra
	
draw_nine_func:
	li $v0, 1
	li $t0, BASE_ADDRESS
	li $t1, RED_1
	add $a0, $a0, $t0
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 4
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 12
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, 268
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, 256
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	add $a0, $a0, -4
	sw $t1, ($a0)
	jr $ra
	
# Function to set number display
# $a0 - position of top left pixel
# $a1 - number
set_num_display_func:
	# Store $ra on the stack since we'll be calling some functions
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	# Clear the 4x7 square first
	li $t0, BASE_ADDRESS
	add $t0, $t0, $a0
	li $t1, BLACK
	sw $t1, ($t0)
	add $t0, $t0, 4
	sw $t1 ($t0)
	add $t0, $t0, 4
	sw $t1 ($t0)
	add $t0, $t0, 4
	sw $t1 ($t0)
	add $t0, $t0, 256
	sw $t1 ($t0)
	add $t0, $t0, -4
	sw $t1 ($t0)
	add $t0, $t0, -4
	sw $t1 ($t0)
	add $t0, $t0, -4
	sw $t1 ($t0)
	add $t0, $t0, 256
	sw $t1 ($t0)
	add $t0, $t0, 4
	sw $t1 ($t0)
	add $t0, $t0, 4
	sw $t1 ($t0)
	add $t0, $t0, 4
	sw $t1 ($t0)
	add $t0, $t0, 256
	sw $t1 ($t0)
	add $t0, $t0, -4
	sw $t1 ($t0)
	add $t0, $t0, -4
	sw $t1 ($t0)
	add $t0, $t0, -4
	sw $t1 ($t0)
	add $t0, $t0, 256
	sw $t1 ($t0)
	add $t0, $t0, 4
	sw $t1 ($t0)
	add $t0, $t0, 4
	sw $t1 ($t0)
	add $t0, $t0, 4
	sw $t1 ($t0)
	add $t0, $t0, 256
	sw $t1 ($t0)
	add $t0, $t0, -4
	sw $t1 ($t0)
	add $t0, $t0, -4
	sw $t1 ($t0)
	add $t0, $t0, -4
	sw $t1 ($t0)
	add $t0, $t0, 256
	sw $t1 ($t0)
	add $t0, $t0, 4
	sw $t1 ($t0)
	add $t0, $t0, 4
	sw $t1 ($t0)
	add $t0, $t0, 4
	sw $t1 ($t0)
	
	beq $a1, 0, set_zero
	beq $a1, 1, set_one
	beq $a1, 2, set_two
	beq $a1, 3, set_three
	beq $a1, 4, set_four
	beq $a1, 5, set_five
	beq $a1, 6, set_six
	beq $a1, 7, set_seven
	beq $a1, 8, set_eight
	beq $a1, 9, set_nine
	
set_zero:
	jal draw_zero_func
	j set_num_display_end
	
set_one:
	jal draw_one_func
	j set_num_display_end
	
set_two:
	jal draw_two_func
	j set_num_display_end
	
set_three:
	jal draw_three_func
	j set_num_display_end
	
set_four:
	jal draw_four_func
	j set_num_display_end
	
set_five:
	jal draw_five_func
	j set_num_display_end
	
set_six:
	jal draw_six_func
	j set_num_display_end
	
set_seven:
	jal draw_seven_func
	j set_num_display_end
	
set_eight:
	jal draw_eight_func
	j set_num_display_end
	
set_nine:
	jal draw_nine_func
	j set_num_display_end

set_num_display_end:	
	# Return to main
	lw $t1, 0($sp)
	addi $sp, $sp, 4
	jr $t1	

display_end_screen_func:
	# Store $ra on the stack since we'll be calling some functions
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	jal clear_display_func
	
	# Show score
	lw $a1, score
	li $a0, 12412
	jal set_num_display_func
	
	lw $t0, BASE_ADDRESS
	lw $t1, score

	beq $t1, 0, display_loss
	
display_win:
	li $t0, BASE_ADDRESS
	li $t6, ORANGE_1
	li $t7, BLUE_2
	# Orange amongus in middle
	sw $t6, 15228($t0)
	sw $t6, 15232($t0)
	sw $t6, 15236($t0)
	sw $t7, 15484($t0)
	sw $t7, 15488($t0)
	sw $t6, 15492($t0)
	sw $t6, 15740($t0)
	sw $t6, 15744($t0)
	sw $t6, 15748($t0)
	sw $t6, 15996($t0)
	sw $t6, 16004($t0)
	# Purple amongus on left
	li $t6, PURPLE_1
	sw $t6, 15208($t0)
	sw $t6, 15212($t0)
	sw $t6, 15216($t0)
	sw $t6, 15464($t0)
	sw $t7, 15468($t0)
	sw $t7, 15472($t0)
	sw $t6, 15720($t0)
	sw $t6, 15724($t0)
	sw $t6, 15728($t0)
	sw $t6, 15976($t0)
	sw $t6, 15984($t0)
	# Green amongus on right
	li $t6, GREEN_2
	sw $t6, 15256($t0)
	sw $t6, 15260($t0)
	sw $t6, 15264($t0)
	sw $t7, 15512($t0)
	sw $t7, 15516($t0)
	sw $t6, 15520($t0)
	sw $t6, 15768($t0)
	sw $t6, 15772($t0)
	sw $t6, 15776($t0)
	sw $t6, 16020($t0)
	sw $t6, 16024($t0)
	sw $t6, 16028($t0)
	sw $t6, 16032($t0)
	j display_end_screen_end

display_loss:
	li $t0, BASE_ADDRESS
	li $t6, RED_1
	li $t7, BLUE_2
	# Red amongus on floor
	sw $t6, 15740($t0)
	sw $t6, 15744($t0)
	sw $t6, 15748($t0)
	sw $t6, 15752($t0)
	#sw $t6, 15996($t0)
	sw $t6, 16000($t0)
	sw $t7, 16004($t0)
	sw $t6, 16008($t0)
	sw $t6, 16252($t0)
	sw $t6, 16256($t0)
	sw $t7, 16260($t0)
	sw $t6, 16264($t0)


display_end_screen_end:
	# Return to main
	lw $t1, 0($sp)
	addi $sp, $sp, 4
	jr $t1	
	
display_main_menu_func:
	# Store $ra on the stack since we'll be calling some functions
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	
	jal clear_display_func
	
	li $t0, BASE_ADDRESS
	li $t7, BLUE_2
	# Red amongus
	li $t6, RED_1
	sw $t6, 15216($t0)
	sw $t6, 15220($t0)
	sw $t6, 15224($t0)
	sw $t7, 15472($t0)
	sw $t7, 15476($t0)
	sw $t6, 15480($t0)
	sw $t6, 15728($t0)
	sw $t6, 15732($t0)
	sw $t6, 15736($t0)
	sw $t6, 15984($t0)
	sw $t6, 15992($t0)
	
	li $v0, 32
	li $a0, 1500
	syscall
	# Purple amongus
	li $t6, PURPLE_1
	sw $t6, 15196($t0)
	sw $t6, 15200($t0)
	sw $t6, 15204($t0)
	sw $t6, 15452($t0)
	sw $t7, 15456($t0)
	sw $t7, 15460($t0)
	sw $t6, 15708($t0)
	sw $t6, 15712($t0)
	sw $t6, 15716($t0)
	sw $t6, 15964($t0)
	sw $t6, 15972($t0)
	# Orange amongus
	li $t6, ORANGE_1
	sw $t6, 15236($t0)
	sw $t6, 15240($t0)
	sw $t6, 15244($t0)
	sw $t6, 15492($t0)
	sw $t7, 15496($t0)
	sw $t7, 15500($t0)
	sw $t6, 15748($t0)
	sw $t6, 15752($t0)
	sw $t6, 15756($t0)
	sw $t6, 16004($t0)
	sw $t6, 16012($t0)
	# Green amongus
	li $t6, GREEN_2
	sw $t6, 15256($t0)
	sw $t6, 15260($t0)
	sw $t6, 15264($t0)
	sw $t7, 15512($t0)
	sw $t7, 15516($t0)
	sw $t6, 15520($t0)
	sw $t6, 15768($t0)
	sw $t6, 15772($t0)
	sw $t6, 15776($t0)
	sw $t6, 16024($t0)
	sw $t6, 16032($t0)
	
	li $v0, 32
	li $a0, 1500
	syscall
	
	# Other amongus
	li $t6, RED_2
	sw $t6, 11952($t0)
	sw $t6, 11956($t0)
	sw $t6, 11960($t0)
	sw $t6, 12208($t0)
	sw $t7, 12212($t0)
	sw $t7, 12216($t0)
	sw $t6, 12464($t0)
	sw $t6, 12468($t0)
	sw $t6, 12472($t0)
	sw $t6, 12720($t0)
	sw $t6, 12728($t0)
	
	li $v0, 32
	li $a0, 1500
	syscall
	
	# S to start
	sw $t6, 10808($t0)
	sw $t6, 10548($t0)
	sw $t6, 10288($t0)
	sw $t6, 10284($t0)
	sw $t6, 10280($t0)
	sw $t6, 10276($t0)
	sw $t6, 10528($t0)
	sw $t6, 10780($t0)
	sw $t6, 11036($t0)
	sw $t6, 11292($t0)
	sw $t6, 11552($t0)
	sw $t6, 11812($t0)
	sw $t6, 11816($t0)
	sw $t6, 11820($t0)
	sw $t6, 11824($t0)
	sw $t6, 12084($t0)
	sw $t6, 12344($t0)
	sw $t6, 12600($t0)
	sw $t6, 12856($t0)
	sw $t6, 13108($t0)
	sw $t6, 13360($t0)
	sw $t6, 13356($t0)
	sw $t6, 13352($t0)
	sw $t6, 13348($t0)
	sw $t6, 13088($t0)
	sw $t6, 12828($t0)
	
	sw $t6, 11604($t0)
	sw $t6, 11608($t0)
	sw $t6, 11612($t0)
	sw $t6, 11864($t0)
	sw $t6, 12120($t0)
	sw $t6, 12376($t0)
	sw $t6, 12632($t0)
	
	sw $t6, 11880($t0)
	sw $t6, 11884($t0)
	sw $t6, 11888($t0)
	sw $t6, 12136($t0)
	sw $t6, 12392($t0)
	sw $t6, 12648($t0)
	sw $t6, 12652($t0)
	sw $t6, 12656($t0)
	sw $t6, 12400($t0)
	sw $t6, 12144($t0)
	
	sw $t6, 11664($t0)
	sw $t6, 11660($t0)
	sw $t6, 11656($t0)
	sw $t6, 11912($t0)
	sw $t6, 12168($t0)
	sw $t6, 12172($t0)
	sw $t6, 12176($t0)
	sw $t6, 12432($t0)
	sw $t6, 12688($t0)
	sw $t6, 12684($t0)
	sw $t6, 12680($t0)
	
	sw $t6, 11932($t0)
	sw $t6, 11936($t0)
	sw $t6, 11940($t0)
	sw $t6, 12192($t0)
	sw $t6, 12448($t0)
	sw $t6, 12704($t0)
	
	sw $t6, 11972($t0)
	sw $t6, 11976($t0)
	sw $t6, 11980($t0)
	sw $t6, 12228($t0)
	sw $t6, 12236($t0)
	sw $t6, 12484($t0)
	sw $t6, 12740($t0)
	
	sw $t6, 11992($t0)
	sw $t6, 11996($t0)
	sw $t6, 12000($t0)
	sw $t6, 12252($t0)
	sw $t6, 12508($t0)
	sw $t6, 12764($t0)
	
	# Q to quit
	sw $t6, 17968($t0)
	sw $t6, 18220($t0)
	sw $t6, 18472($t0)
	sw $t6, 18728($t0)
	sw $t6, 18984($t0)
	sw $t6, 19240($t0)
	sw $t6, 19496($t0)
	sw $t6, 19752($t0)
	sw $t6, 20008($t0)
	sw $t6, 20264($t0)
	sw $t6, 20520($t0)
	sw $t6, 20780($t0)
	sw $t6, 21040($t0)
	sw $t6, 21044($t0)
	sw $t6, 21048($t0)
	sw $t6, 21052($t0)
	sw $t6, 20800($t0)
	sw $t6, 20548($t0)
	sw $t6, 20292($t0)
	sw $t6, 20036($t0)
	sw $t6, 19780($t0)
	sw $t6, 19524($t0)
	sw $t6, 19268($t0)
	sw $t6, 19012($t0)
	sw $t6, 18756($t0)
	sw $t6, 18500($t0)
	sw $t6, 18240($t0)
	sw $t6, 17980($t0)
	sw $t6, 17976($t0)
	sw $t6, 17972($t0)
	sw $t6, 21060($t0)
	sw $t6, 21320($t0)
	sw $t6, 20540($t0)
	
	sw $t6, 19296($t0)
	sw $t6, 19300($t0)
	sw $t6, 19304($t0)
	sw $t6, 19556($t0)
	sw $t6, 19812($t0)
	sw $t6, 20068($t0)
	sw $t6, 20324($t0)
	
	sw $t6, 19572($t0)
	sw $t6, 19576($t0)
	sw $t6, 19580($t0)
	sw $t6, 19828($t0)
	sw $t6, 20084($t0)
	sw $t6, 20340($t0)
	sw $t6, 20344($t0)
	sw $t6, 20348($t0)
	sw $t6, 20092($t0)
	sw $t6, 19836($t0)
	
	sw $t6, 19348($t0)
	sw $t6, 19352($t0)
	sw $t6, 19356($t0)
	sw $t6, 19604($t0)
	sw $t6, 19612($t0)
	sw $t6, 19860($t0)
	sw $t6, 19868($t0)
	sw $t6, 20116($t0)
	sw $t6, 20120($t0)
	sw $t6, 20124($t0)
	sw $t6, 20380($t0)
	sw $t6, 20384($t0)
	
	sw $t6, 19628($t0)
	sw $t6, 19636($t0)
	sw $t6, 19884($t0)
	sw $t6, 20140($t0)
	sw $t6, 20396($t0)
	sw $t6, 20400($t0)
	sw $t6, 20404($t0)
	sw $t6, 20148($t0)
	sw $t6, 19892($t0)
	
	sw $t6, 19648($t0)
	sw $t6, 19904($t0)
	sw $t6, 20160($t0)
	sw $t6, 20416($t0)
	
	sw $t6, 19660($t0)
	sw $t6, 19664($t0)
	sw $t6, 19668($t0)
	sw $t6, 19920($t0)
	sw $t6, 20176($t0)
	sw $t6, 20432($t0)

display_main_menu_end:
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

# Helper function to clear the display
clear_display_func:
	li $t0, BASE_ADDRESS
	li $t1, BLACK
	add $t2, $zero, BASE_ADDRESS
	add $t2, $t2, 29436
	
clear_display_loop:
	bge $t0, $t2, clear_display_end
	sw $t1, ($t0)
	add $t0, $t0, 4
	j clear_display_loop
	
clear_display_end:
	jr $ra
