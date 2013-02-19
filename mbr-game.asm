org 0x7c00

bits 16

; Set video mode and stuff
; Modifies: ax
; Result: Text mode set
text_mode:
    mov ax, 01h
    int 10h

draw_grid:
    mov si, grid                ; grid is a bit vector, 0 means food, 1 means wall
next_byte:
    lodsb                       ; load next byte in grid
    cmp al, 0                   ; End of grid, jump to input
    je wait_for_key
    mov ch, al
    mov cl, 7                   ; 8 bits in a byte

    loop:
        call next_bit           ; Get cl'th bit and print it (pass through to print_char)
        add dh, 1
        cmp dh, 11              ; Breadth of grid is 10
        je print_newline
    back:
        sub cl, 1
        cmp cl, -1              ; No more bits, load next_byte
        je next_byte
        jmp loop                ; Else, just move onto next bit

wait_for_key:

    ; Wait delay timer
    mov ah, 86h
    mov cx, 0
    mov dx, 65535
    int 15h

    ; Update screen
    call draw_man
    call update_score

    ; Check for input
    mov ah, 01h
    int 16h
    jnz handle_input
    jmp wait_for_key

    ; Handle input
    handle_input:
        mov ah, 00h
        int 16h
        call update_next_direction
        jmp wait_for_key



; Prints a string, expects si to be pointed to memory location
print_string:
    lodsb
    cmp al, 0
    je return
    call print_char
    jmp print_string
    
; ch contains the number whose cl'th bit has to be found, al will (in the end) contain the
; character to be printed on the screen corresponding to that
;   Input: ch - 8-bit number
;          cl - bit to be found
;   Result: al contains the character type to be printed on the screen - wall or food          
; Pass through to the next label, print_char
next_bit:
    mov dl, 1
    shl dl, cl
    and dl, ch
    shr dl, cl
    cmp dl, 0
    mov al, 219
    jne print_char
    make_food:
        mov al, 248

; Prints the char in al
; Pass through to the next label, return
print_char:
    mov ah, 0eh
    int 10h

return:
    ret

; Prints CR, LF
print_newline:
    mov al, 10
    call print_char
    
    mov al, 13
    call print_char

    mov dh, 0
    jmp back

; Moves cursor pointed to dl, dh
set_cursor_position:
    mov ah, 02h
    int 10h
    ret

; Get character at position dh, dl
; Called after setting the cursor position
; Result goes in al
get_char_at_dh_dl:
    mov ah, 08h
    int 10h
    ret 

; Increments score in [score]
increment_score:
    cmp al, 248     ; 248 is food
    jne return
    add byte [score], 1
    ret

; Converts 2 digit number to string
; Input:  ax number
; Output: ax - two character string
decimal_string:
    push dx
    push cx
    mov dx, 0
    mov bx, 10
    div bx
    mov ah, dl
    add ax, 0x3030      ; Add 48 to each of modulus and remainder
    pop cx
    pop dx
    ret

; Gets the shape of the cursor based on the direction in cl, so for 0 we get |>, etc
; Codes: 31 - down, 30 up
;        17 - left, 16 right      
; The code can be calculated based on the direction value in cl
; > 0
; < 1
; /\ 2
; \/ 3
get_cursor_shape:
    mov al, 16
    cmp cl, 1
    jle horizontal
    vertical:
            cmp cl, 4
            je default_position
            mov al, 28
    horizontal:
            add al, cl
    default_position:
        ret

; Checks next position based on value of cl
next_position:
    cmp cl, 4       ; Start-off case, nothing to do!
    je return

    cmp cl, 1
    jle horizontal_next
    vertical_next:
        cmp cl, 2
        je vertical_up
        vertical_down:
            add bh, 2       ; Uses jump through here, actually adds 1 to bh
        vertical_up:
            sub bh, 1
            ret
    horizontal_next:
        cmp cl, 0
        je horizontal_right
        horizontal_left:
            sub bl, 1
            cmp bl, -1
            je warp_left
            ret
            warp_left:
                mov bl, 9       ; Another jump through, actual value of bl will be 10
        horizontal_right:
            add bl, 1
            cmp bl, 11
            je warp_right
            ret
            warp_right:
                mov bl, 0
            ret
            
; Verify next position in bl, bh
; Move the cursor there and get the character value, 
;    If can move
;       a) Call increment score (which will compare the character value with food or space
;       b) Update cursor position
;    If can't move
;       a) Get stuck and redraw cursor at old position
verify_next_position:
    push dx
    mov dx, bx

    cmp cl, 4       ; Default position
    je get_stuck    

    mov bx, 0
    call set_cursor_position        ; Move to the new position
    call get_char_at_dh_dl          ; Get character value
    cmp al, 219                     ; Is it a wall?
    je get_stuck                    ; boohoo
    call increment_score            ; Food!
    call get_cursor_shape           ; What character to draw
    call print_char                 ; What are we waiting for? Draw it!
    call unset_current_position     ; Since we moved to the new position, replace the previous position with a ' '
    mov [x], dl                     ; Update the x, y coordinates to new ones
    mov [y], dh
    pop dx
    ret
    get_stuck:                      ; We don't have anywhere to move
        pop dx
        mov bx, 0
        call set_cursor_position    ; So we'll just redraw at the current position
        call get_cursor_shape
        call print_char
        ret

; Unsets current position in x and y coordinates
; i.e. replaces the man with a space
unset_current_position:
    push dx
    mov dh, [y]
    mov dl, [x]
    call set_cursor_position
    mov al, ' '
    call print_char
    pop dx
    ret

; Update direction and set it to next_direction
; Set next_direction to 4
unset_next_direction:
    mov al, [next_direction]
    mov byte [direction], al
    mov byte [next_direction], 4
    ret

; Draw the food eater man
; Tries [next_direction] first and sees if it can move there
; If not, then [direction] is tried
; Otherwise, it's just redrawn to the current position
draw_man:
    mov dh, [y]
    mov dl, [x]
    mov cl, [direction]

    ; Tests next position based on next_direction
    ; [next_direction] takes precedence over current direction
    mov bx, dx
    mov cl, [next_direction]
    call next_position  ; gets new position in bh, bl
    call verify_next_position 

    ; Test if we moved or not by comparing current and old position
    mov ch, [y]
    mov cl, [x]
    cmp cx, dx
    jne unset_next_direction    ; If we moved, unset the next_direction variable

    ; If we did not move, test [direction] instead
    mov bx, cx
    mov cl, [direction]
    call next_position
    call verify_next_position
    ret

; Updates the score on the screen
update_score:
    mov dx, 0x0a00      ; Cursor position where score is drawn
    call set_cursor_position
    movzx ax, [score]   ; Put score in ax
    call decimal_string ; Convert score to a string 
    mov [score_string+7], ax  ; Update the string to be printed
    mov si, score_string
    call print_string
    cmp byte [score], 51          ; 51 is the max score that can be
    je end              
    ret


; Updates the next_direction byte to point to where we should move next whenever possible
; based on the direction table
;   Input: Keycode in ah
;   Result: [next_direction] is modified
update_next_direction:
    mov byte [next_direction], 0
    cmp ah, 0x50
    je next_down
    cmp ah, 0x48
    je next_up
    cmp ah, 0x4d
    je next_right
    cmp ah, 0x4b
    je next_left

    ; The order of labels is specific here, since it relies on pass through
    next_down:    
        add byte [next_direction], 1
    next_up:
        add byte [next_direction], 1
    next_left:
        add byte [next_direction], 1
    next_right:
        ret


; Some data
grid  db 255, 240, 6, 186, 194, 19, 89, 73, 99, 141, 37, 145, 63, 255, 0    ; Grid
score_string db "Eaten: 00", 0     ; Score variable
stripe db "Stripe", 0   ; Exit message on success
y db 4          ; Current y position
x db 0          ; Current x position
score db 0

; Current direction
direction db 4  ; Direction table:
                ; > 0
                ; < 1
                ; /\ 2
                ; \/ 3
; Next direction to take, should it is available
next_direction db 4

; This is the end, beautiful friend ...
end:
    mov dx, 0x0b00
    call set_cursor_position
    mov si, stripe
    call print_string

times 510 - ($-$$) db 0
dw 0xAA55
