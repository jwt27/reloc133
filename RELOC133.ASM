; RELOC133 - Relocates Promise Ultra133 TX2 data segment to high memory.
; Copyright 2017 J.W. Jagersma - see COPYING.TXT for details.

org 0x100
use16
    mov dx, msg_hello
    mov ah, 9
    int 0x21
    call find_bios
    jc fail
    push ds
    mov ds, [0x379] ; pointer to ultra133 data area
    mov ax, ds
    cmp ax, [0x379] ; should be identical
    pop ds
    jne fail
    call find_chipset
    mov al, 0x33
    call set_rw
    jc fail
    mov ax, [0]
    not ax
    mov [0], ax
    cmp [0], ax
    mov dx, err_readonly
    jne fail
    not ax
    mov [0], ax
    push bx
    push cx
    push 0x40
    pop es
    mov ax, [es:0x13]   ; total conventional memory in kb
    shl ax, 6
    mov bx, [0x379]
    cmp ax, bx
    mov dx, err_notmax
    jne fail
    mov ax, [es:0x0e]
    cmp ax, [0x379] ; ebda should be above ultra133 segment ...
    mov dx, err_ebdanotfound
    jbe fail
    cmp ax, 0xa000  ; ... and below vga memory
    jae fail
    push ds
    mov ds, [es:0x0e]
    mov cx, [0x00]
    shl cx, 6
    mov si, name_ebda
    call alloc      ; allocate space for ebda
    jc fail
    cli
    xor di, di
    xor si, si
    rep movsb       ; copy ebda
    push 0x40
    pop ds
    mov cx, [0x0e]
    mov [0x0e], es  ; set ebda pointer to new segment
    sti
    pop ds
    mov ax, [0x379]
    sub cx, ax
    mov si, name_ultra133
    call alloc      ; allocate new data area
    jc fail
    cli
    push ds
    mov ds, [0x379]
    xor di, di
    xor si, si
    rep movsb       ; copy the whole thing over
    pop ds
    push ds
    call fix_pointers   ; fix pointers in ROM ...
    mov ds, [0x379]
    call fix_pointers   ; ... and in the data area itself
    pop ds
    pop ax
    pop bx
    call set_rw
    call fix_mcb
    sti
    mov dx, msg_done
    mov ah, 9
    int 0x21
    mov ax, 0x4c00
    int 0x21


fix_mcb:
    mov ah, 0x52
    int 0x21
    push es
    push bx
    push 0x40
    pop ds
    mov cx, 640
    sub cx, [0x13]
    mov word [0x13], 640    ; set total memory to 640k
    mov bx, [es:bx-2]
@@: mov ds, bx
    add bx, [3]
    inc bx
    cmp byte [0], 'Z'   ; find last low mcb entry
    jne @b
@@: shl cx, 6
    add [3], cx         ; add the new space
    mov di, ds
    add di, [3]
    inc di
    mov es, di
    mov ds, bx
    xor di, di
    xor si, si
    push cx
    mov cx, 0x10
    rep movsb           ; copy the UMB root block
    pop cx
    sub [es:3], cx      ; update its size
    pop bx
    pop ds
    mov [bx+0x66], es   ; update UMB root pointer
    ret

find_chipset:
    mov ecx, 0x60000    ; northbridge class
    mov ax, 0xb103
    xor si, si
    int 0x1a
    mov dx, err_chipset
    jc .z
    push bx
    mov ax, 0xb10a
    xor di, di
    int 0x1a
    cmp ecx, 0x71908086 ; 440bx id
    je @f
    mov dx, warn_chipset
    push ds
    push cs
    pop ds
    mov ah, 9
    int 0x21
    pop ds
@@: pop bx
    clc
.z: ret

; set shadow-rom r/w bits for DS to AL, returns previous value in CL
set_rw:
    push ax
    mov di, ds
    sub di, 0xc000
    shr di, 11
    add di, 0x5a
    mov ax, 0xb108
    push bx
    push di
    int 0x1a
    pop di
    pop bx
    pop ax
    mov dx, err_chipsetaccess
    jc .z
    push cx
    mov cx, ax
    mov ax, 0xb10b
    int 0x1a
    pop cx
.z: ret


fix_pointers:
    mov [0x379], es ; segment of data area
    mov bx, 0x2e8
    mov ax, es
    mov dh, ah
    shr dh, 4
    shl ax, 4
    add bx, ax
    mov al, dh
    adc al, 0
    xor ah, ah
    mov [0x2c4], bx ; DMA pointer
    mov [0x2c6], ax
    ret
    

; find the Promise BIOS ROM. the BIOS itself uses roughly the same technique.
find_bios:
    mov cx, 0x70
    mov ax, 0xC800
.n: mov ds, ax
    cmp word [0], 0xAA55
    jne @f
    cmp byte [2], 0
    je @f
    mov si, [0x18]
    cmp word [si+0x04], 0x105A
    jne @f
    cmp word [si+0x06], 0x4D69
    jne @f
    cmp word [si+0x0E], 0x0180
    je .f
@@: add ax, 80h
    loop .n
    mov dx, err_notfound
    stc
    ret
.f: clc
    ret

    
; allocate CX paragraphs in high memory.
alloc:
    mov ax, 0x5802
    int 0x21
    mov dx, 1
    jc .z
    cbw
    push ax
    mov ax, 0x5803
    mov bx, 0x0001      ; enable UMBs
    int 0x21
    jc .y
    mov ax, 0x5800
    int 0x21
    jc .y
    cbw
    push ax
    mov ax, 0x5801
    mov bx, 0x0041      ; allocate in high memory, best fit
    int 0x21
    jc .x
    mov ah, 0x48
    mov bx, cx
    int 0x21
    mov di, ax
    jc .x
    xor dx, dx
    push di
    dec di
    mov es, di
    mov word [es:1], 8  ; set DOS as owner of this block (so it won't be freed)
    mov di, 8
    push cx
    mov cx, 8
    push ds
    push cs
    pop ds
    rep movsb
    pop ds
    pop cx
    pop es
.x: mov ax, 0x5801
    pop bx
    int 0x21
.y: mov ax, 0x5803
    pop bx
    int 0x21
.z: mov ax, dx
    sahf
    mov dx, err_alloc
    ret

fail:
    push cs
    pop ds
    mov ah, 0x09
    int 0x21
    mov ax, 0x4cff
    int 0x21

msg_hello db "RELOC133 - (C) 2017 J.W. Jagersma - $'
msg_done db "Done.$"
err_notfound db "ERROR: Promise Ultra133 TX2 BIOS not found.$"
err_ebdanotfound db "ERROR: Extended BDA found in unexpected location.$"
err_notmax db "ERROR: Expected Ultra133 data area on top of memory.$"
err_alloc db "ERROR: Memory allocation failed.$"
err_readonly db "ERROR: BIOS is write-protected.$"
err_chipset db "ERROR: Chipset not found?$"
err_chipsetaccess db "ERROR: Unable to access chipset.$"
warn_chipset db "WARNING: Unsupported chipset!$"
name_ultra133 db "ULTRA133"
name_ebda db "EBDA",0,0,0,0


