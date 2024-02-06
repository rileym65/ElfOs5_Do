; *******************************************************************
; *** This software is copyright 2004 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

#include   ../macros.inc
#include   ../bios.inc
#include   ../kernel.inc

              org       2000h
begin:        br        start
              eever
              db        'Written by Michael H. Riley',0

start:        mov       rf,0400h       ; get Elf/OS version
              ldn       rf
              smi       5              ; must be 5+
              lbdf      start2         ; jump if valid version
              call      o_inmsg        ; display error
              db        'Requires Elf/OS 5+',10,13,0
              ldi       014h           ; set return code to invalid version
              rtn                      ; return to caller

start2:       lda       ra             ; move past any spaces
              smi       ' '
              lbz       start2
              dec       ra             ; move back to non-space character
              ghi       ra             ; copy argument address to rf
              phi       rf
              glo       ra
              plo       rf
loop1:        lda       rf             ; look for first less <= space
              smi       33
              lbdf      loop1
              dec       rf             ; backup to char
              ldi       0              ; need proper termination
              str       rf
              ghi       ra             ; back to beginning of name
              phi       rf
              glo       ra
              plo       rf
              ldn       rf             ; get byte from argument
              lbnz      good           ; jump if filename given
              sep       scall          ; otherwise display usage message
              dw        o_inmsg
              db        'Usage: do filename',10,13,0
              ldi       0ah
              sep       sret           ; and return to os

good:         ldi       high fildes    ; get file descriptor
              phi       rd
              ldi       low fildes
              plo       rd
              ldi       0              ; flags for open
              plo       r7
              sep       scall          ; attempt to open file
              dw        o_open
              lbnf      opened         ; jump if file was opened
              call      o_inmsg     
              db        'File not found',10,13,0
              ldi       0ch
              sep       sret           ; and return to os
opened:       mov       rc,1024        ; allocate 1k on the heap
              mov       r7,0ff04h      ; allocate on page boundary
              call      o_alloc        ; allocate the memory
              lbnf      allocated      ; jump if memory allocated
              call      o_inmsg        ; display error message
              db        'Could not allocate heap memory. aborting.',10,13,0
              ldi       5              ; set return value
              rtn                      ; and return to OS
allocated:    mov       rc,f_dta       ; need dta
              lda       rc
              smi       mainlp.1       ; subtract base address
              phi       rb
              ldn       rc
              plo       rb
              glo       rb             ; add heap address
              str       r2
              glo       rf
              add
              str       rc             ; point pointer back
              dec       rc
              ghi       rb
              str       r2
              ghi       rf
              adc
              str       rc             ; FILDES now has correct dta on heap
              ghi       rd             ; now adjust FILDES
              smi       mainlp.1
              phi       rd
              glo       rd
              str       r2
              glo       rf
              add
              plo       rd
              ghi       rd
              str       r2
              ghi       rf
              adc
              phi       rd             ; RD FILDES address is now in heap

              mov       ra,mainlp      ; now copy relocatable code to heap
              mov       rb,rf
              mov       rc,1022
cpyloop:      lda       ra
              str       rb
              inc       rb
              dec       rc
              glo       rc
              lbnz      cpyloop
              ghi       rc
              lbnz      cpyloop        ; loop until relocation section fully copied
              mov       r7,xfer2       ; need to temporarily switch PC
              ghi       rf             ; set initial RA
              adi       1
              phi       ra
              ldi       command.0
              plo       ra
              mov       rc,0           ; indicate no bytes from script read
              sep       r7
xfer2:        mov       r3,rf          ; set R3 to code on the heap
              sep       r3             ; and transfer to it

; ****************************************************
; ***** Relocatable portion that runs the script *****
; ****************************************************

.align page

mainlp:       ldi       ret_1
              stxd
              ldi       getbyte.0      ; get a byte from last input data
              plo       r3
ret_1:        bdf       readexc        ; jump if exception during read
              glo       re             ; save character
              smi       32             ; check for non printable
              bnf       eol            ; end of line
              glo       re             ; recover character
              str       ra             ; write character to command line
              inc       ra
              br        mainlp         ; loop until end found
readexc:      bz        goodeof        ; jump if eof was found
exit:         ghi       r3             ; need to remove permanent flag from heap
              phi       rf
              ldi       0
              plo       rf
              dec       rf
              dec       rf
              dec       rf
              ldi       2
              str       rf
              rtn                      ; return to OS

goodeof:      ldi       0              ; terminate command
              str       ra
              ghi       r3             ; point to command
              adi       1
              phi       rf
              ldi       command.0
              plo       rf
              call      o_exec         ; and execute it
              bdf       execbin2       ; jump if error
              br        exit           ; was last command in file, exit
execbin2:     ghi       r3             ; point to command
              adi       1
              phi       rf
              ldi       command.0
              plo       rf
              call      o_execbin
              bdf       execerr2
              br        exit
execerr2:     call      o_inmsg        ; show error
              db        'Err',10,13,0
              br        exit

eol:          ldi       ret_2.0
              stxd
              ldi       getbyte.0      ; get nextbyte
              plo       r3
ret_2:        glo       re
              bz        goodeof        ; jump if eof
              glo       re             ; save it
              smi       32             ; look for next printable
              bnf       eol            ; loop until printable
              glo       re             ; save it
              stxd
              ldi       0              ; terminate command line
              str       ra
              ghi       r3             ; point to command
              adi       1
              phi       rf
              ldi       command.0
              plo       rf
              push      rb
              push      rc
              push      rd
              call      o_exec         ; and execute it
              pop       rd
              pop       rc
              pop       rb
              bdf       execbin        ; jump if erorr occured
execgood:     ghi       r3             ; point to command line
              adi       1
              phi       ra
              ldi       command.0
              plo       ra
              irx                      ; recover last character
              ldx
              str       ra             ; store into command
              inc       ra
              br        mainlp         ; read next line
execbin:      ghi       r3             ; point to command buffer
              adi       1
              phi       rf
              ldi       command.0
              plo       rf
              push      rb
              push      rc
              push      rd
              call      o_execbin
              bdf       execerr
              pop       rd
              pop       rc
              pop       rb
              br        execgood
execerr:      irx
              br        execerr2

getbyte:      glo       rc             ; see if still have characters
              bnz       havechars      ; jump if so
              ghi       r3
              adi       1
              phi       rf
              ldi       cbuffer.0
              plo       rf
              mov       rc,80          ; read 80 bytes
              call      o_read         ; read from script file
              bdf       badread        ; jump if bad read
              glo       rc             ; see if end of file
              bz        eof            ; jump if so
              ghi       r3
              adi       1
              phi       rb
              ldi       cbuffer.0
              plo       rb
havechars:    dec       rc             ; decrement bytes available
              lda       rb             ; get next available byte
              adi       0              ; signal good read
              br        return
badread:      call      o_inmsg        ; display error
              db        'Err,10,13,0
              ldi       1              ; signal bad read
              lskp
eof:          ldi       0              ; signal eof
              smi       0
return:       plo       re
              irx
              ldx
              plo       r3

.align page

fildes:    db      0,0,0,0
f_dta:     dw      dta
           db      0,0
           db      0
           db      0,0,0,0
           dw      0,0
           db      0,0,0,0

.suppress

command:   ds      80
cbuffer:   ds      80
dta:       ds      512

           end     begin
