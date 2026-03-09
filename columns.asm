################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Erzheng Zhang, 1010939148
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    256
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
    
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

color_table:
    .word 0x000000  # 0 = black
    .word 0xff0000  # 1 = red
    .word 0xff6600  # 2 = orange
    .word 0xffff00  # 3 = yellow
    .word 0x00ff00  # 4 = green
    .word 0x0000ff  # 5 = blue
    .word 0x9900ff  # 6 = purple

##############################################################################
# Mutable Data
##############################################################################

grid:           .word 0:160 # 8 x 20 grid

# Current falling column
col_x:          .word 3     # horizontal position (0-7), start middle
col_y:          .word 0     # vertical position of top gem
col_gem1:       .word 1     # top gem (color index)
col_gem2:       .word 1     # middle gem (color index)
col_gem3:       .word 1     # bottom gem (color index)
col_x_prev:     .word 3     # previous x position for collision detection

match_grid:     .word 0:160     # 1 = matched, 0 = not matched
match_found:    .word 0         # flag: did we find any match this pass

# Game state
game_over:      .word 0     # 0 = running, 1 = game over
score:          .word 0     # current score
combo:          .word 0     # combo counter for current move

# Gravity settings (loops per drop):
# Speed 1 (slow):   30 loops
# Speed 2 (medium): 15 loops  
# Speed 3 (fast):   5 loops
GRAVITY_SPEED:  .word 15    # change this to 30 or 5 for other speeds
gravity_timer:  .word 0     # counts up to GRAVITY_SPEED then drops

# 3x5 pixel font for digits 0-9
# Each digit = 5 rows, each row = 3 bits (packed into a byte, left=MSB)
# Bit layout per row: bit2=left col, bit1=mid col, bit0=right col
digit_font:
    # 0
    .byte 1,1,1  # ###
    .byte 1,0,1  # # #
    .byte 1,0,1  # # #
    .byte 1,0,1  # # #
    .byte 1,1,1  # ###
    # 1
    .byte 0,1,0  #  #
    .byte 1,1,0  # ##
    .byte 0,1,0  #  #
    .byte 0,1,0  #  #
    .byte 1,1,1  # ###
    # 2
    .byte 1,1,1  # ###
    .byte 0,0,1  #   #
    .byte 1,1,1  # ###
    .byte 1,0,0  # #
    .byte 1,1,1  # ###
    # 3
    .byte 1,1,1  # ###
    .byte 0,0,1  #   #
    .byte 1,1,1  # ###
    .byte 0,0,1  #   #
    .byte 1,1,1  # ###
    # 4
    .byte 1,0,1  # # #
    .byte 1,0,1  # # #
    .byte 1,1,1  # ###
    .byte 0,0,1  #   #
    .byte 0,0,1  #   #
    # 5
    .byte 1,1,1  # ###
    .byte 1,0,0  # #
    .byte 1,1,1  # ###
    .byte 0,0,1  #   #
    .byte 1,1,1  # ###
    # 6
    .byte 1,1,1  # ###
    .byte 1,0,0  # #
    .byte 1,1,1  # ###
    .byte 1,0,1  # # #
    .byte 1,1,1  # ###
    # 7
    .byte 1,1,1  # ###
    .byte 0,0,1  #   #
    .byte 0,1,0  #  #
    .byte 0,1,0  #  #
    .byte 0,1,0  #  #
    # 8
    .byte 1,1,1  # ###
    .byte 1,0,1  # # #
    .byte 1,1,1  # ###
    .byte 1,0,1  # # #
    .byte 1,1,1  # ###
    # 9
    .byte 1,1,1  # ###
    .byte 1,0,1  # # #
    .byte 1,1,1  # ###
    .byte 0,0,1  #   #
    .byte 1,1,1  # ###

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize the game
    jal init_game
    j game_loop

game_loop: # order switched from handout during debugging
    jal check_keyboard
    jal update_column
    jal check_collision
	jal draw_screen
	jal sleep
    j game_loop

##############################################################################
# init_game: Initialize game state
# - randomize starting gem colors
# - reset column position to top middle
##############################################################################
init_game:
    # randomize gem 1
    li $v0, 42
    li $a0, 0
    li $a1, 6
    syscall             # $a0 = random 0-5
    addi $a0, $a0, 1    # shift to 1-6
    sw $a0, col_gem1

    # randomize gem 2
    li $v0, 42
    li $a0, 0
    li $a1, 6
    syscall
    addi $a0, $a0, 1
    sw $a0, col_gem2

    # randomize gem 3
    li $v0, 42
    li $a0, 0
    li $a1, 6
    syscall
    addi $a0, $a0, 1
    sw $a0, col_gem3

    # reset position to top middle
    li $t0, 3
    sw $t0, col_x
    li $t0, 0
    sw $t0, col_y

    jr $ra

##############################################################################
# check_keyboard: Poll keyboard and handle input
# - a: move left
# - d: move right
# - w: shuffle gems
# - s: drop down
# - q: quit
##############################################################################
check_keyboard:
    lw $t0, ADDR_KBRD       # load keyboard base address
    lw $t1, 0($t0)          # check if key pressed
    bne $t1, 1, keyboard_done

    lw $t2, 4($t0)          # load ASCII of key pressed

    beq $t2, 0x61, key_a    # a
    beq $t2, 0x64, key_d    # d
    beq $t2, 0x77, key_w    # w
    beq $t2, 0x73, key_s    # s
    beq $t2, 0x71, key_q    # q
    j keyboard_done

key_a:
    lw $t0, col_x
    beq $t0, 0, keyboard_done   # already at left wall
    addi $t0, $t0, -1
    sw $t0, col_x
    j keyboard_done

key_d:
    lw $t0, col_x
    beq $t0, 7, keyboard_done   # already at right wall
    addi $t0, $t0, 1
    sw $t0, col_x
    j keyboard_done

key_w:
    lw $t0, col_gem1        # $t0 = gem1
    lw $t1, col_gem2        # $t1 = gem2
    lw $t2, col_gem3        # $t2 = gem3

    sw $t2, col_gem1        # gem1 = old gem3
    sw $t0, col_gem2        # gem2 = old gem1
    sw $t1, col_gem3        # gem3 = old gem2
    j keyboard_done

key_s:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal drop_to_bottom
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    j keyboard_done

key_q:
    li $v0, 10
    syscall

keyboard_done:
    jr $ra

##############################################################################
# check_collision: Check all collision cases
# - left/right: block move if existing gem in the way
# - bottom: lock column if hitting floor or existing gem below
##############################################################################
check_collision:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    jal check_horizontal_collision
    jal check_vertical_collision

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# check_horizontal_collision: Block left/right movement into existing gems
# - checks all 3 gem positions at current col_x against grid
# - if any of the 3 cells are occupied, revert col_x to col_x_prev
##############################################################################
check_horizontal_collision:
    lw $t0, col_x
    lw $t1, col_x_prev
    lw $t2, col_y

    beq $t0, $t1, horiz_done    # no horizontal movement, skip

    blt $t0, $t1, check_left_collision
    j check_right_collision

check_left_collision:
    # gem 1: index = col_y * 8 + col_x
    sll $t3, $t2, 3
    add $t3, $t3, $t0
    la $t4, grid
    sll $t5, $t3, 2
    add $t4, $t4, $t5
    lw $t5, 0($t4)
    bne $t5, 0, revert_col_x

    # gem 2: index = (col_y+1) * 8 + col_x
    addi $t3, $t2, 1
    sll $t3, $t3, 3
    add $t3, $t3, $t0
    la $t4, grid
    sll $t5, $t3, 2
    add $t4, $t4, $t5
    lw $t5, 0($t4)
    bne $t5, 0, revert_col_x

    # gem 3: index = (col_y+2) * 8 + col_x
    addi $t3, $t2, 2
    sll $t3, $t3, 3
    add $t3, $t3, $t0
    la $t4, grid
    sll $t5, $t3, 2
    add $t4, $t4, $t5
    lw $t5, 0($t4)
    bne $t5, 0, revert_col_x

    j horiz_update_prev

check_right_collision:
    # gem 1
    sll $t3, $t2, 3
    add $t3, $t3, $t0
    la $t4, grid
    sll $t5, $t3, 2
    add $t4, $t4, $t5
    lw $t5, 0($t4)
    bne $t5, 0, revert_col_x

    # gem 2
    addi $t3, $t2, 1
    sll $t3, $t3, 3
    add $t3, $t3, $t0
    la $t4, grid
    sll $t5, $t3, 2
    add $t4, $t4, $t5
    lw $t5, 0($t4)
    bne $t5, 0, revert_col_x

    # gem 3
    addi $t3, $t2, 2
    sll $t3, $t3, 3
    add $t3, $t3, $t0
    la $t4, grid
    sll $t5, $t3, 2
    add $t4, $t4, $t5
    lw $t5, 0($t4)
    bne $t5, 0, revert_col_x

    j horiz_update_prev

revert_col_x:
    sw $t1, col_x
    jr $ra

horiz_update_prev:
    sw $t0, col_x_prev
    jr $ra

horiz_done:
    jr $ra

##############################################################################
# check_vertical_collision: Check if column has landed
# - landed if bottom gem (col_y + 2) is at row 19
# - landed if cell below bottom gem is occupied
##############################################################################
check_vertical_collision:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    lw $t0, col_y
    lw $t1, col_x

    # check if bottom gem hit floor (row 19 or beyond)
    addi $t2, $t0, 2
    bge $t2, 19, do_land_column

    # check cell below bottom gem
    addi $t3, $t0, 3
    sll $t3, $t3, 3
    add $t3, $t3, $t1
    la $t4, grid
    sll $t5, $t3, 2
    add $t4, $t4, $t5
    lw $t5, 0($t4)
    bne $t5, 0, do_land_column

    j vert_done

do_land_column:
    jal land_column

vert_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# land_column: Lock piece, check matches, spawn next
##############################################################################
land_column:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    jal lock_column
    sw $zero, combo
    jal check_matches
    jal spawn_column
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# lock_column: Write current column gems into grid array
##############################################################################
lock_column:
    lw $t0, col_y
    lw $t1, col_x
    la $t2, grid

    # lock gem 1
    lw $t3, col_gem1
    sll $t4, $t0, 3
    add $t4, $t4, $t1
    sll $t4, $t4, 2
    add $t4, $t2, $t4
    sw $t3, 0($t4)

    # lock gem 2
    lw $t3, col_gem2
    addi $t5, $t0, 1
    sll $t4, $t5, 3
    add $t4, $t4, $t1
    sll $t4, $t4, 2
    add $t4, $t2, $t4
    sw $t3, 0($t4)

    # lock gem 3
    lw $t3, col_gem3
    addi $t5, $t0, 2
    sll $t4, $t5, 3
    add $t4, $t4, $t1
    sll $t4, $t4, 2
    add $t4, $t2, $t4
    sw $t3, 0($t4)

    jr $ra

##############################################################################
# spawn_column: Generate new column at top middle with random colors
# - checks game over first
##############################################################################
spawn_column:
    lw $t0, col_y
    beq $t0, 0, trigger_game_over

    # reset position
    li $t0, 3
    sw $t0, col_x
    sw $t0, col_x_prev
    li $t0, 0
    sw $t0, col_y

    # randomize gem 1
    li $v0, 42
    li $a0, 0
    li $a1, 6
    syscall
    addi $a0, $a0, 1
    sw $a0, col_gem1

    # randomize gem 2
    li $v0, 42
    li $a0, 0
    li $a1, 6
    syscall
    addi $a0, $a0, 1
    sw $a0, col_gem2

    # randomize gem 3
    li $v0, 42
    li $a0, 0
    li $a1, 6
    syscall
    addi $a0, $a0, 1
    sw $a0, col_gem3

    jr $ra

trigger_game_over:
    li $t0, 1
    sw $t0, game_over
    li $v0, 10
    syscall

##############################################################################
# update_column: Update column position after input + collision
##############################################################################
##############################################################################
# update_column: Apply gravity — drop piece every GRAVITY_SPEED loops
##############################################################################
update_column:
    lw $t0, gravity_timer
    addi $t0, $t0, 1
    sw $t0, gravity_timer

    lw $t1, GRAVITY_SPEED
    blt $t0, $t1, update_column_done

    # reset timer
    sw $zero, gravity_timer

    # drop piece by 1 (same as key_s)
    lw $t0, col_y
    addi $t0, $t0, 1
    sw $t0, col_y

update_column_done:
    jr $ra

##############################################################################
# draw_screen: Draw everything to bitmap display
##############################################################################
draw_screen:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    jal draw_background
    jal draw_border
    jal draw_grid
    jal draw_column
    jal draw_score

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# draw_background: Fill entire display with black
##############################################################################
draw_background:
    lw $t0, ADDR_DSPL
    li $t1, 0x000000
    li $t2, 0
    li $t3, 1024

draw_background_loop:
    beq $t2, $t3, draw_background_done
    sll $t4, $t2, 2
    add $t4, $t0, $t4
    sw $t1, 0($t4)
    addi $t2, $t2, 1
    j draw_background_loop

draw_background_done:
    jr $ra

##############################################################################
# draw_border: Draw white border around the grid
# - grid is at col 1-8, row 1-20 on display
# - border is col 0, col 9, row 0, row 21
##############################################################################
draw_border:
    lw $t0, ADDR_DSPL
    li $t1, 0xffffff

    # top border (row 0, col 0-9)
    li $t2, 0
draw_top_border:
    beq $t2, 10, draw_bottom_border_start
    sll $t3, $t2, 2
    add $t3, $t0, $t3
    sw $t1, 0($t3)
    addi $t2, $t2, 1
    j draw_top_border

    # bottom border (row 21, col 0-9)
draw_bottom_border_start:
    li $t2, 0
draw_bottom_border:
    beq $t2, 10, draw_left_border_start
    li $t3, 21
    li $t4, 32
    mul $t3, $t3, $t4
    add $t3, $t3, $t2
    sll $t3, $t3, 2
    add $t3, $t0, $t3
    sw $t1, 0($t3)
    addi $t2, $t2, 1
    j draw_bottom_border

    # left border (col 0, row 0-21)
draw_left_border_start:
    li $t2, 0
draw_left_border:
    beq $t2, 22, draw_right_border_start
    li $t3, 32
    mul $t3, $t2, $t3
    sll $t3, $t3, 2
    add $t3, $t0, $t3
    sw $t1, 0($t3)
    addi $t2, $t2, 1
    j draw_left_border

    # right border (col 9, row 0-21)
draw_right_border_start:
    li $t2, 0
draw_right_border:
    beq $t2, 22, draw_border_done
    li $t3, 32
    mul $t3, $t2, $t3
    addi $t3, $t3, 9
    sll $t3, $t3, 2
    add $t3, $t0, $t3
    sw $t1, 0($t3)
    addi $t2, $t2, 1
    j draw_right_border

draw_border_done:
    jr $ra

##############################################################################
# draw_grid: Draw all landed gems from grid array
##############################################################################
draw_grid:
    lw $t0, ADDR_DSPL
    la $t1, grid
    li $t2, 0

draw_grid_loop:
    beq $t2, 160, draw_grid_done

    sll $t3, $t2, 2
    add $t3, $t1, $t3
    lw $t4, 0($t3)

    beq $t4, 0, draw_grid_next

    la $t5, color_table
    sll $t6, $t4, 2
    add $t5, $t5, $t6
    lw $t5, 0($t5)

    andi $t6, $t2, 7        # col = index % 8
    addi $t6, $t6, 1        # shift for border
    srl $t7, $t2, 3         # row = index / 8
    addi $t7, $t7, 1        # shift for border

    li $t8, 32
    mul $t7, $t7, $t8
    add $t7, $t7, $t6
    sll $t7, $t7, 2
    add $t7, $t0, $t7
    sw $t5, 0($t7)

draw_grid_next:
    addi $t2, $t2, 1
    j draw_grid_loop

draw_grid_done:
    jr $ra

##############################################################################
# draw_column: Draw the current falling column (3 gems)
##############################################################################
draw_column:
    lw $t0, ADDR_DSPL
    lw $t1, col_x
    lw $t2, col_y

    addi $t1, $t1, 1        # shift for border
    addi $t2, $t2, 1        # shift for border

    # draw gem 1 (top)
    lw $t3, col_gem1
    la $t4, color_table
    sll $t3, $t3, 2
    add $t4, $t4, $t3
    lw $t4, 0($t4)

    li $t5, 32
    mul $t6, $t2, $t5
    add $t6, $t6, $t1
    sll $t6, $t6, 2
    add $t6, $t0, $t6
    sw $t4, 0($t6)

    # draw gem 2 (middle)
    lw $t3, col_gem2
    la $t4, color_table
    sll $t3, $t3, 2
    add $t4, $t4, $t3
    lw $t4, 0($t4)

    addi $t2, $t2, 1
    mul $t6, $t2, $t5
    add $t6, $t6, $t1
    sll $t6, $t6, 2
    add $t6, $t0, $t6
    sw $t4, 0($t6)

    # draw gem 3 (bottom)
    lw $t3, col_gem3
    la $t4, color_table
    sll $t3, $t3, 2
    add $t4, $t4, $t3
    lw $t4, 0($t4)

    addi $t2, $t2, 1
    mul $t6, $t2, $t5
    add $t6, $t6, $t1
    sll $t6, $t6, 2
    add $t6, $t0, $t6
    sw $t4, 0($t6)

    jr $ra

##############################################################################
# check_matches: Repeatedly scan and clear matches until no more are found
# Calls scan_matches, then clear_matches, then apply_gravity in a loop
##############################################################################
check_matches:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

check_matches_loop:
    # Clear match_grid
    la $t0, match_grid
    li $t1, 0
    li $t2, 0

clear_match_grid:
    beq $t2, 160, clear_match_grid_done
    sll $t3, $t2, 2
    add $t3, $t0, $t3
    sw $t1, 0($t3)
    addi $t2, $t2, 1
    j clear_match_grid
clear_match_grid_done:

    # Reset match_found flag
    sw $zero, match_found

    jal scan_matches

    lw $t0, match_found
    beq $t0, 0, check_matches_done     # no matches found, exit loop

    jal count_and_score_matches
    jal clear_matches
    jal apply_gravity
    j check_matches_loop               # repeat in case clearing created new matches

check_matches_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# scan_matches: Mark all cells that are part of a 3-in-a-row match
# Checks horizontal, vertical, diagonal (both directions)
##############################################################################
scan_matches:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    jal scan_vertical
    jal scan_horizontal
    jal scan_diag_down_right
    jal scan_diag_down_left

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# scan_vertical: Mark vertical matches (same color, 3+ in a column)
# For each column (0-7), scan rows 0-17 and check cell, cell+1, cell+2
##############################################################################
scan_vertical:
    li $s0, 0                   # col = 0
scan_vert_col_loop:
    beq $s0, 8, scan_vert_done
    li $s1, 0                   # row = 0
scan_vert_row_loop:
    addi $t0, $s1, 2
    bgt $t0, 19, scan_vert_next_col    # need 3 rows, stop at row 17

    # index of cell (row, col)
    sll $t1, $s1, 3
    add $t1, $t1, $s0           # t1 = row*8 + col

    # load color at (row, col)
    la $t2, grid
    sll $t3, $t1, 2
    add $t3, $t2, $t3
    lw $t4, 0($t3)              # color at top cell
    beq $t4, 0, scan_vert_row_next   # skip empty

    # load color at (row+1, col)
    addi $t5, $t1, 8
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    lw $t6, 0($t3)
    bne $t4, $t6, scan_vert_row_next

    # load color at (row+2, col)
    addi $t5, $t1, 16
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    lw $t7, 0($t3)
    bne $t4, $t7, scan_vert_row_next

    # all 3 match — mark them in match_grid
    la $t2, match_grid
    li $t8, 1

    sll $t3, $t1, 2
    add $t3, $t2, $t3
    sw $t8, 0($t3)

    addi $t5, $t1, 8
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    sw $t8, 0($t3)

    addi $t5, $t1, 16
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    sw $t8, 0($t3)

    sw $t8, match_found

scan_vert_row_next:
    addi $s1, $s1, 1
    j scan_vert_row_loop
scan_vert_next_col:
    addi $s0, $s0, 1
    j scan_vert_col_loop
scan_vert_done:
    jr $ra

##############################################################################
# scan_horizontal: Mark horizontal matches (same color, 3+ in a row)
# For each row (0-19), scan cols 0-5 and check cell, cell+1, cell+2
##############################################################################
scan_horizontal:
    li $s0, 0                   # row = 0
scan_horiz_row_loop:
    beq $s0, 20, scan_horiz_done
    li $s1, 0                   # col = 0
scan_horiz_col_loop:
    addi $t0, $s1, 2
    bgt $t0, 7, scan_horiz_next_row   # need 3 cols, stop at col 5

    sll $t1, $s0, 3
    add $t1, $t1, $s1           # t1 = row*8 + col

    la $t2, grid
    sll $t3, $t1, 2
    add $t3, $t2, $t3
    lw $t4, 0($t3)
    beq $t4, 0, scan_horiz_col_next

    addi $t5, $t1, 1
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    lw $t6, 0($t3)
    bne $t4, $t6, scan_horiz_col_next

    addi $t5, $t1, 2
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    lw $t7, 0($t3)
    bne $t4, $t7, scan_horiz_col_next

    la $t2, match_grid
    li $t8, 1

    sll $t3, $t1, 2
    add $t3, $t2, $t3
    sw $t8, 0($t3)

    addi $t5, $t1, 1
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    sw $t8, 0($t3)

    addi $t5, $t1, 2
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    sw $t8, 0($t3)

    sw $t8, match_found

scan_horiz_col_next:
    addi $s1, $s1, 1
    j scan_horiz_col_loop
scan_horiz_next_row:
    addi $s0, $s0, 1
    j scan_horiz_row_loop
scan_horiz_done:
    jr $ra

##############################################################################
# scan_diag_down_right: Mark diagonal matches going down-right (\)
# rows 0-17, cols 0-5
##############################################################################
scan_diag_down_right:
    li $s0, 0
scan_ddr_row_loop:
    addi $t0, $s0, 2
    bgt $t0, 19, scan_ddr_done
    li $s1, 0
scan_ddr_col_loop:
    addi $t0, $s1, 2
    bgt $t0, 7, scan_ddr_next_row

    sll $t1, $s0, 3
    add $t1, $t1, $s1

    la $t2, grid
    sll $t3, $t1, 2
    add $t3, $t2, $t3
    lw $t4, 0($t3)
    beq $t4, 0, scan_ddr_col_next

    addi $t5, $t1, 9             # down 1, right 1 = +8+1
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    lw $t6, 0($t3)
    bne $t4, $t6, scan_ddr_col_next

    addi $t5, $t1, 18            # down 2, right 2 = +16+2
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    lw $t7, 0($t3)
    bne $t4, $t7, scan_ddr_col_next

    la $t2, match_grid
    li $t8, 1

    sll $t3, $t1, 2
    add $t3, $t2, $t3
    sw $t8, 0($t3)

    addi $t5, $t1, 9
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    sw $t8, 0($t3)

    addi $t5, $t1, 18
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    sw $t8, 0($t3)

    sw $t8, match_found

scan_ddr_col_next:
    addi $s1, $s1, 1
    j scan_ddr_col_loop
scan_ddr_next_row:
    addi $s0, $s0, 1
    j scan_ddr_row_loop
scan_ddr_done:
    jr $ra

##############################################################################
# scan_diag_down_left: Mark diagonal matches going down-left (/)
# rows 0-17, cols 2-7
##############################################################################
scan_diag_down_left:
    li $s0, 0
scan_ddl_row_loop:
    addi $t0, $s0, 2
    bgt $t0, 19, scan_ddl_done
    li $s1, 2                    # start at col 2 (need col-2 to be valid)
scan_ddl_col_loop:
    bgt $s1, 7, scan_ddl_next_row

    sll $t1, $s0, 3
    add $t1, $t1, $s1

    la $t2, grid
    sll $t3, $t1, 2
    add $t3, $t2, $t3
    lw $t4, 0($t3)
    beq $t4, 0, scan_ddl_col_next

    addi $t5, $t1, 7             # down 1, left 1 = +8-1
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    lw $t6, 0($t3)
    bne $t4, $t6, scan_ddl_col_next

    addi $t5, $t1, 14            # down 2, left 2 = +16-2
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    lw $t7, 0($t3)
    bne $t4, $t7, scan_ddl_col_next

    la $t2, match_grid
    li $t8, 1

    sll $t3, $t1, 2
    add $t3, $t2, $t3
    sw $t8, 0($t3)

    addi $t5, $t1, 7
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    sw $t8, 0($t3)

    addi $t5, $t1, 14
    sll $t3, $t5, 2
    add $t3, $t2, $t3
    sw $t8, 0($t3)

    sw $t8, match_found

scan_ddl_col_next:
    addi $s1, $s1, 1
    j scan_ddl_col_loop
scan_ddl_next_row:
    addi $s0, $s0, 1
    j scan_ddl_row_loop
scan_ddl_done:
    jr $ra

##############################################################################
# count_and_score_matches: Score based on run lengths in match_grid
# Scans vertical, horizontal, both diagonals for contiguous marked runs
# Scoring: 3=100, 4=300, 5=600, scaled by 2^(combo-1)
# combo is incremented each time this is called (once per gravity loop pass)
##############################################################################
count_and_score_matches:
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # increment combo counter
    lw $t0, combo
    addi $t0, $t0, 1
    sw $t0, combo

    # score accumulator for this pass
    li $s3, 0                   # total points this pass

    jal score_vertical_runs
    jal score_horizontal_runs
    jal score_diag_dr_runs
    jal score_diag_dl_runs

    # apply combo multiplier: score * 2^(combo-1)
    # shift left by (combo-1)
    lw $t0, combo
    addi $t0, $t0, -1           # combo - 1
    sllv $s3, $s3, $t0          # s3 = s3 << (combo-1)

    lw $t1, score
    add $t1, $t1, $s3
    sw $t1, score

    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# score_run: $a0 = run length, adds 100*(n-2)*(n-1)/2 to $s3
# 3=100, 4=300, 5=600, 6=1000, 7=1500, ...
##############################################################################
score_run:
    blt $a0, 3, score_run_done  # run < 3, no points
    addi $t0, $a0, -1           # n-1
    addi $t1, $a0, -2           # n-2
    mul $t0, $t0, $t1           # (n-1)*(n-2)
    li $t1, 50
    mul $t0, $t0, $t1           # * 50 = 100*(n-1)*(n-2)/2
    add $s3, $s3, $t0
score_run_done:
    jr $ra

##############################################################################
# score_vertical_runs: scan grid columns for same-color runs
##############################################################################
score_vertical_runs:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $s0, 0                   # col
score_vr_col:
    beq $s0, 8, score_vr_done
    li $s1, 0                   # row
    li $s2, 0                   # run length
    li $s6, 0                   # current run color
score_vr_row:
    bge $s1, 20, score_vr_flush

    sll $t1, $s1, 3
    add $t1, $t1, $s0
    la $t2, grid
    sll $t3, $t1, 2
    add $t3, $t2, $t3
    lw $t4, 0($t3)              # color at this cell

    beq $t4, 0, score_vr_break         # empty cell breaks run
    beq $s2, 0, score_vr_start_run     # start new run
    bne $t4, $s6, score_vr_break       # different color breaks run
    addi $s2, $s2, 1
    addi $s1, $s1, 1
    j score_vr_row
score_vr_start_run:
    move $s6, $t4
    li $s2, 1
    addi $s1, $s1, 1
    j score_vr_row
score_vr_break:
    move $a0, $s2
    jal score_run
    li $s2, 0
    li $s6, 0
    addi $s1, $s1, 1
    j score_vr_row
score_vr_flush:
    move $a0, $s2
    jal score_run
    addi $s0, $s0, 1
    j score_vr_col
score_vr_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# score_horizontal_runs: scan grid rows for same-color runs
##############################################################################
score_horizontal_runs:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $s0, 0                   # row
score_hr_row:
    beq $s0, 20, score_hr_done
    li $s1, 0                   # col
    li $s2, 0
    li $s6, 0
score_hr_col:
    bge $s1, 8, score_hr_flush

    sll $t1, $s0, 3
    add $t1, $t1, $s1
    la $t2, grid
    sll $t3, $t1, 2
    add $t3, $t2, $t3
    lw $t4, 0($t3)

    beq $t4, 0, score_hr_break
    beq $s2, 0, score_hr_start_run
    bne $t4, $s6, score_hr_break
    addi $s2, $s2, 1
    addi $s1, $s1, 1
    j score_hr_col
score_hr_start_run:
    move $s6, $t4
    li $s2, 1
    addi $s1, $s1, 1
    j score_hr_col
score_hr_break:
    move $a0, $s2
    jal score_run
    li $s2, 0
    li $s6, 0
    addi $s1, $s1, 1
    j score_hr_col
score_hr_flush:
    move $a0, $s2
    jal score_run
    addi $s0, $s0, 1
    j score_hr_row
score_hr_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# score_diag_dr_runs: score \ diagonal runs
##############################################################################
score_diag_dr_runs:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $s0, 0
score_ddr_top:
    beq $s0, 8, score_ddr_left
    li $t5, 0
    move $t6, $s0
    jal walk_diag_dr
    addi $s0, $s0, 1
    j score_ddr_top
score_ddr_left:
    li $s0, 1
score_ddr_leftloop:
    beq $s0, 20, score_ddr_done
    move $t5, $s0
    li $t6, 0
    jal walk_diag_dr
    addi $s0, $s0, 1
    j score_ddr_leftloop
score_ddr_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

walk_diag_dr:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    move $s4, $t5
    move $s5, $t6
    li $s2, 0
    li $s6, 0
walk_ddr_step:
    bge $s4, 20, walk_ddr_flush
    bge $s5, 8, walk_ddr_flush

    sll $t1, $s4, 3
    add $t1, $t1, $s5
    la $t2, grid
    sll $t3, $t1, 2
    add $t3, $t2, $t3
    lw $t4, 0($t3)

    beq $t4, 0, walk_ddr_break
    beq $s2, 0, walk_ddr_start
    bne $t4, $s6, walk_ddr_break
    addi $s2, $s2, 1
    addi $s4, $s4, 1
    addi $s5, $s5, 1
    j walk_ddr_step
walk_ddr_start:
    move $s6, $t4
    li $s2, 1
    addi $s4, $s4, 1
    addi $s5, $s5, 1
    j walk_ddr_step
walk_ddr_break:
    move $a0, $s2
    jal score_run
    li $s2, 0
    li $s6, 0
    addi $s4, $s4, 1
    addi $s5, $s5, 1
    j walk_ddr_step
walk_ddr_flush:
    move $a0, $s2
    jal score_run
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# score_diag_dl_runs: score / diagonal runs
##############################################################################
score_diag_dl_runs:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    li $s0, 0
score_ddl_top:
    beq $s0, 8, score_ddl_right
    li $t5, 0
    move $t6, $s0
    jal walk_diag_dl
    addi $s0, $s0, 1
    j score_ddl_top
score_ddl_right:
    li $s0, 1
score_ddl_rightloop:
    beq $s0, 20, score_ddl_done
    move $t5, $s0
    li $t6, 7
    jal walk_diag_dl
    addi $s0, $s0, 1
    j score_ddl_rightloop
score_ddl_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

walk_diag_dl:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    move $s4, $t5
    move $s5, $t6
    li $s2, 0
    li $s6, 0
walk_ddl_step:
    bge $s4, 20, walk_ddl_flush
    blt $s5, 0, walk_ddl_flush

    sll $t1, $s4, 3
    add $t1, $t1, $s5
    la $t2, grid
    sll $t3, $t1, 2
    add $t3, $t2, $t3
    lw $t4, 0($t3)

    beq $t4, 0, walk_ddl_break
    beq $s2, 0, walk_ddl_start
    bne $t4, $s6, walk_ddl_break
    addi $s2, $s2, 1
    addi $s4, $s4, 1
    addi $s5, $s5, -1
    j walk_ddl_step
walk_ddl_start:
    move $s6, $t4
    li $s2, 1
    addi $s4, $s4, 1
    addi $s5, $s5, -1
    j walk_ddl_step
walk_ddl_break:
    move $a0, $s2
    jal score_run
    li $s2, 0
    li $s6, 0
    addi $s4, $s4, 1
    addi $s5, $s5, -1
    j walk_ddl_step
walk_ddl_flush:
    move $a0, $s2
    jal score_run
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# clear_matches: Zero out any grid cell marked in match_grid
##############################################################################
clear_matches:
    la $t0, grid
    la $t1, match_grid
    li $t2, 0

clear_matches_loop:
    beq $t2, 160, clear_matches_done

    sll $t3, $t2, 2
    add $t4, $t1, $t3
    lw $t5, 0($t4)              # load match flag
    beq $t5, 0, clear_matches_next

    add $t4, $t0, $t3
    sw $zero, 0($t4)            # clear grid cell

clear_matches_next:
    addi $t2, $t2, 1
    j clear_matches_loop

clear_matches_done:
    jr $ra

##############################################################################
# apply_gravity: After clearing, drop gems down to fill empty spaces
# Scans each column bottom-to-top, compacts non-zero gems downward
##############################################################################
apply_gravity:
    li $s0, 0                   # col = 0

apply_grav_col_loop:
    beq $s0, 8, apply_grav_done

    li $s1, 19                  # write_row starts at bottom
    li $s2, 19                  # read_row starts at bottom

apply_grav_row_loop:
    blt $s2, 0, apply_grav_fill_empty

    # load grid[read_row][col]
    sll $t1, $s2, 3
    add $t1, $t1, $s0
    la $t2, grid
    sll $t3, $t1, 2
    add $t3, $t2, $t3
    lw $t4, 0($t3)

    beq $t4, 0, apply_grav_skip_empty

    # write gem to write_row
    sll $t1, $s1, 3
    add $t1, $t1, $s0
    sll $t3, $t1, 2
    add $t3, $t2, $t3
    sw $t4, 0($t3)

    addi $s1, $s1, -1           # move write pointer up

apply_grav_skip_empty:
    addi $s2, $s2, -1           # move read pointer up
    j apply_grav_row_loop

apply_grav_fill_empty:
    # fill remaining rows above write_row with 0
    blt $s1, 0, apply_grav_next_col
    sll $t1, $s1, 3
    add $t1, $t1, $s0
    la $t2, grid
    sll $t3, $t1, 2
    add $t3, $t2, $t3
    sw $zero, 0($t3)
    addi $s1, $s1, -1
    j apply_grav_fill_empty

apply_grav_next_col:
    addi $s0, $s0, 1
    j apply_grav_col_loop

apply_grav_done:
    jr $ra

##############################################################################
# draw_score: Render score label and digits on right side of display
# Score panel starts at display column 11, row 1
##############################################################################
draw_score:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Extract up to 6 digits of score into digit_buf on stack
    # We'll render up to 6 digits starting at col 11, row 3
    lw $s0, score

    # We'll draw digits right-to-left into a 6-digit buffer on the stack
    addi $sp, $sp, -20         # 5 words for digits
    li $s1, 4                  # index into buffer (rightmost = index 4)
    li $s2, 0                  # digit count

extract_digits:
    li $t0, 10
    div $s0, $t0
    mflo $s0                    # quotient
    mfhi $t1                    # remainder = digit
    sll $t2, $s1, 2
    add $t2, $sp, $t2
    sw $t1, 0($t2)
    addi $s1, $s1, -1
    addi $s2, $s2, 1
    beq $s2, 5, draw_digits_start
    bne $s0, 0, extract_digits

    # pad remaining slots with -1 (blank)
pad_digits:
    blt $s1, 0, draw_digits_start
    sll $t2, $s1, 2
    add $t2, $sp, $t2
    li $t3, -1
    sw $t3, 0($t2)
    addi $s1, $s1, -1
    j pad_digits

draw_digits_start:
    li $s1, 0                   # digit slot index (0-5)
draw_digits_loop:
    beq $s1, 5, draw_digits_done
    sll $t0, $s1, 2
    add $t0, $sp, $t0
    lw $t1, 0($t0)              # digit value (-1 = blank)
    beq $t1, -1, draw_digits_next

    # x_offset = 11 + s1 * 4  (each digit is 3 wide + 1 gap)
    li $t2, 4
    mul $t2, $s1, $t2
    addi $t2, $t2, 11           # display col

    li $t3, 3                   # display row (below label)

    # call draw_digit(digit=$t1, col=$t2, row=$t3)
    move $a0, $t1
    move $a1, $t2
    move $a2, $t3
    jal draw_digit

draw_digits_next:
    addi $s1, $s1, 1
    j draw_digits_loop

draw_digits_done:
    addi $sp, $sp, 20
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# draw_digit: Draw a single 3x5 digit onto the bitmap display
# $a0 = digit (0-9), $a1 = display col, $a2 = display row
##############################################################################
draw_digit:
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    # digit font offset = a0 * 15 bytes (5 rows * 3 cols)
    li $t0, 15
    mul $t0, $a0, $t0
    la $t1, digit_font
    add $t1, $t1, $t0           # t1 = pointer to digit's font data

    lw $t9, ADDR_DSPL
    li $t2, 0                   # font row (0-4)

draw_digit_row:
    beq $t2, 5, draw_digit_done
    li $t3, 0                   # font col (0-2)

draw_digit_col:
    beq $t3, 3, draw_digit_next_row

    lb $t4, 0($t1)              # load pixel value (0 or 1)
    addi $t1, $t1, 1

    beq $t4, 0, draw_digit_skip_pixel

    # display position
    add $t5, $a2, $t2           # display row = base_row + font_row
    add $t6, $a1, $t3           # display col = base_col + font_col
    li $t7, 32
    mul $t5, $t5, $t7
    add $t5, $t5, $t6
    sll $t5, $t5, 2
    add $t5, $t9, $t5
    li $t8, 0xffd700            # gold color for digits
    sw $t8, 0($t5)

draw_digit_skip_pixel:
    addi $t3, $t3, 1
    j draw_digit_col

draw_digit_next_row:
    addi $t2, $t2, 1
    j draw_digit_row

draw_digit_done:
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

##############################################################################
# drop_to_bottom: Instantly drop piece to lowest valid position in column
# Scans downward from col_y until floor or occupied cell below
##############################################################################
drop_to_bottom:
    lw $t0, col_y
    lw $t1, col_x

drop_scan:
    # check if bottom gem is at or past floor (row 19)
    addi $t2, $t0, 2
    bge $t2, 19, drop_done      # >= catches any out-of-bounds case too

    # check cell below bottom gem (row col_y+3)
    addi $t3, $t0, 3
    sll $t3, $t3, 3
    add $t3, $t3, $t1
    la $t4, grid
    sll $t5, $t3, 2
    add $t4, $t4, $t5
    lw $t5, 0($t4)
    bne $t5, 0, drop_done

    # safe to move down one more
    addi $t0, $t0, 1
    j drop_scan

drop_done:
    sw $t0, col_y
    sw $zero, gravity_timer     # reset gravity timer so it doesn't double-trigger
    jr $ra

##############################################################################
# sleep: Sleep for ~16ms to target 60fps
##############################################################################
sleep:
    li $v0, 32
    li $a0, 16
    syscall
    jr $ra