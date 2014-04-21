        title   PHYMEM       -- Sample Device Driver, does physical mem i/o
        page    55,132
        .286p

; Sample device driver to do physical memory i/o
;
; - Illustrates reading / writing physical memory.
; 
; Chuck Grandgent, AEG Modicon, Industrial Automation Systems Group,
; North Andover, Massachusetts
; CIS 72330,450        Co-Pro BBS 508-975-9779
; Usenet: Chuck_M_Grandgent@cup.portal.com
;
; This program may be freely copied without restriction.
; No warrantees are made, expressed, or implied.
; The user assumes full burden of responsibility for suitability
; of this program for any purpose.   8/14/89
;
; Note: the skeleton for this driver is from:
; Ray Duncan's "Advanced OS/2 programming", which I heartily recommend.
;
;-------------------- CONFIGURATION VALIDATION SECTION -------------------
show1   macro   a1
        %OUT ** PHYSEG (physical memory segment) defined as a1
        endm
show2   macro   a2
        %OUT ** SEGSIZE (phymem segment size)    defined as a2
        endm
if1
        ifndef PHYSEG
                %OUT ** >>>>> CONFIGURATION ERROR <<<<<<
                %OUT ** Must define PHYSEG as segment for physical memory
                %OUT **         For example, assemble with
                %OUT **         /DPHYSEG=0b000h     for Hercules adapter
        else
                %OUT ** CONFIGURATION SETTINGS: 
                show1 %PHYSEG
        endif

        ifndef SEGSIZE
                %OUT ** >>>>> CONFIGURATION ERROR <<<<<<
                %OUT ** Must define SEGSIZE as segment size for physical memory
                %OUT **         For example, assemble with
                %OUT **         /DSEGSIZE=0fa0h    for Hercules adapter (80*25*2)
        else
                show2 %SEGSIZE
        endif
endif

;---------------------------------------------------------------------
; DevHlp routines:
AllocateGDTSelector equ 2dh     ; Allocates one or more GDT selectors
                                ; for use by the driver
PhysToVirt      equ     15h     ; converts a 32-bit physical (linear)
                                ; address to a virtual address
UnPhysToVirt    equ     32h     ; signals that the virtual address
                                ; previously obtained with PhysToVirt
                                ; can be reused
PhysToUVirt     equ     17h     ; Converts a 32-bit physical address to
                                ; a virtual address accessed through the
                                ; current Local Descriptor Table (LDT)
PhysToGDTSelector equ  2eh     ; maps a physical address and length
                                ; onto a GDT selector
VirtToPhys      equ     16h     ; Converts a virtual address
                                ; (segment:offset or selector:offset)
                                ; to a 32-bit physical address
ROMCritSection  equ     26h     ; flags critical section of execution
                                ; in the ROM BIOS to prevent the real
                                ; mode session from being suspended in
                                ; the background.
VerifyAccess    equ     27h     ; confirms whether the user process has the
                                ; correct access rights for the memory that
                                ; it passed to the device driver
LockSeg         equ     13h     ; marks a memory segment as fixed
                                ; (not movable or swapable) and freezes
                                ; it at a particular location.
UnLockSeg       equ     14h     ; release the lock on a memory segment
;---------------------------------------------------------------------

maxcmd  equ     26              ; maximum allowed command code

stdin   equ     0               ; standard device handles
stdout  equ     1
stderr  equ     2

cr      equ     0dh             ; ASCII carriage return
lf      equ     0ah             ; ASCII linefeed

        extrn   DosWrite:far

DGROUP  group   _DATA

_DATA   segment word public 'DATA'

                                ; device driver header...
header  dd      -1              ; link to next device driver
        dw      8080h           ; device attribute word
        dw      Strat           ; Strategy entry point
        dw      0               ; IDC entry point
        db      'PHYMEM$ '      ; logical device name 
        db      8 dup (0)       ; reserved            

devhlp  dd      ?               ; bimodal pointer to
                                ; DevHlp common entry point
                                ; (from Init routine)

wlen    dw      ?               ; receives DosWrite length

                                ; Strategy routine dispatch table
                                ; for request packet command code...
dispch  dw      Init            ; 0  = initialize driver
        dw      Error           ; 1  = media check 
        dw      Error           ; 2  = build BIOS parameter block 
        dw      Error           ; 3  = not used 
        dw      Read            ; 4  = read from device
        dw      Error           ; 5  = nondestructive read 
        dw      Error           ; 6  = return input status 
        dw      Error           ; 7  = flush device input buffers 
        dw      Error           ; 8  = write to device
        dw      Error           ; 9  = write with verify
        dw      Error           ; 10 = return output status 
        dw      Error           ; 11 = flush output buffers 
        dw      Error           ; 12 = not used 
        dw      DevOpen         ; 13 = device open
        dw      DevClose        ; 14 = device close
        dw      Error           ; 15 = removable media 
        dw      Error           ; 16 = generic IOCTL 
        dw      Error           ; 17 = reset media 
        dw      Error           ; 18 = get logical drive 
        dw      Error           ; 19 = set logical drive 
        dw      Error           ; 20 = deinstall 
        dw      Error           ; 21 = not used 
        dw      Error           ; 22 = partitionable fixed disks 
        dw      Error           ; 23 = get fixed disk unit map 
        dw      Error           ; 24 = not used 
        dw      Error           ; 25 = not used 
        dw      Error           ; 26 = not used 


xfrcnt  dw      0                       ; bytes successfully transferred
xfrreq  dw      0                       ; number of bytes requested
xfraddr dd      0                       ; working address for transfer
xfroff  dw      0                       ; offset from first word in buffer
uptres  dw      0                       ; selector for user pointer

ident   db      cr,lf,lf
        db      'PHYMEM sample device driver for OS/2'
        db      cr,lf
        db      'Does physical memory I/O'
        db      cr,lf,lf
ident_len equ   $-ident

_DATA   ends


_TEXT   segment word public 'CODE'

        assume  cs:_TEXT,ds:DGROUP,es:NOTHING

Strat   proc    far             ; Strategy entry point
                                ; ES:BX = request packet address
        mov     di,es:[bx+2]    ; get command code from packet
        and     di,0ffh
        cmp     di,maxcmd       ; supported by this driver?
        jle     Strat1          ; jump if command code OK

        call    Error           ; bad command code
        jmp     short Strat2

Strat1: add     di,di           ; branch to command code routine
        call    word ptr [di+dispch]

Strat2: mov     es:[bx+3],ax    ; status into request packet
        ret                     ; back to OS/2 kernel

Strat   endp

Intr    proc    far             ; driver Interrupt handler

        clc                     ; signal we owned interrupt
        ret                     ; return from interrupt

Intr    endp


; Command code routines are called by the Strategy routine
; via the Dispatch table with ES:BX pointing to the request
; header.  Each routine should return ES:BX unchanged
; and AX = status to be placed in request packet:
; 0100h if 'done' and no error
; 0000h if thread should block pending interrupt
; 81xxh if 'done' and error detected (xx=error code)

MediaChk proc   near            ; function 1 = media check

        mov     ax,0100h        ; return 'done' status
        ret

MediaChk endp

BuildBPB proc   near            ; function 2 = build BPB

        mov     ax,0100h        ; return 'done' status
        ret

BuildBPB endp

Read    proc    near            ; function 4 = read

        push    ds
        push    es              ; save request packet address
        push    bx

        mov     ax,es:[bx+12h]  ; bytes requested
        mov     xfrreq,ax

        mov     ax,es:[bx+0eh]  ; requestor's buffer address
        mov     word ptr xfraddr,ax
        mov     ax,es:[bx+10h]
        mov     word ptr xfraddr+2,ax

Read1:  

;=======================================================================
        mov     ax,PHYSEG        ; segment address
;        mov     ax,0b000h       ; hercules adapter address @ b000:0000
        mov     bx,0             ; initial offset of zero

; this normalization fragment Fm: Dean Gibson (UltiMeth) 73427,2072
        rol     ax, 4
        mov     dx, 0fff0h
        and     dx, ax
        xor     ax, dx
        add     bx, dx
        adc     al, ah

        mov     cx,SEGSIZE      ; length of area with 0=65535 bytes
        mov     dh,1            ; get virtual & make seg ReadWrite
        mov     dl,PhysToUVirt  
        call    devhlp
        mov     uptres,es       ; save es portion, the user selector
;=======================================================================
                                ; convert destination physical
                                ; address to virtual address...
        mov     bx,word ptr xfraddr
        mov     ax,word ptr xfraddr+2
        mov     cx,xfrreq       ; size of "segment" (1 byte segments illegal)
        mov     dh,1            ; leave result in ES:DI
        mov     dl,PhysToVirt   ; function number
        call    devhlp          ; transfer to kernel
; ----- We've got buffer address in ES:DI

        mov     ax,word ptr uptres
        mov     word ptr es:[di],ax ; copy to DosRead's buffer

Read2:

        mov     dl,UnPhysToVirt ; function number
        call    devhlp          ; transfer to kernel


        pop     bx              ; restore request packet address
        pop     es

        mov     ax,xfrreq       ; put actual transfer count
        mov     es:[bx+12h],ax  ; into request packet

        mov     ax,0100h        ; return 'done' status

        pop     ds
        ret

Read    endp

NdRead  proc    near            ; function 5 = nondestructive read

        mov     ax,0100h        ; return 'done' status
        ret

NdRead  endp

InpStat proc    near            ; function 6 = input status

        mov     ax,0100h        ; return 'done' status
        ret

InpStat endp

InpFlush proc   near            ; function 7 = flush input buffers

        mov     ax,0100h        ; return 'done' status
        ret

InpFlush endp

Write   proc    near            ; function 8,9 = write

        mov     ax,0100h        ; return 'done' status
        ret

Write   endp

WriteVfy proc   near            ; function 9 = write with verify

        mov     ax,0100h        ; return 'done' status
        ret

WriteVfy endp

Outstat proc    near            ; function 10 = output status

        mov     ax,0100h        ; return 'done' status
        ret

Outstat endp

OutFlush proc   near            ; function 11 = flush output buffers

        mov     ax,0100h        ; return 'done' status
        ret

OutFlush endp

DevOpen proc    near            ; function 13 = device open

        mov     ax,0100h        ; return 'done' status
        ret

DevOpen endp

DevClose proc   near            ; function 14 = device close

        mov     ax,0100h        ; return 'done' status
        ret

DevClose endp

RemMedia proc   near            ; function 15 = removable media

        mov     ax,0100h        ; return 'done' status
        ret

RemMedia endp

GenIOCTL proc   near            ; function 16 = generic IOCTL

        mov     ax,0100h        ; return 'done' status
        ret

GenIOCTL endp

ResetMed proc   near            ; function 17 = reset media

        mov     ax,0100h        ; return 'done' status
        ret

ResetMed endp

GetLogDrv proc  near            ; function 18 = get logical drive

        mov     ax,0100h        ; return 'done' status
        ret

GetLogDrv endp

SetLogDrv proc  near            ; function 19 = set logical drive

        mov     ax,0100h        ; return 'done' status
        ret

SetLogDrv endp

DeInstall proc  near            ; function 20 = deinstall driver

        mov     ax,0100h        ; return 'done' status
        ret

DeInstall endp

PartFD  proc    near            ; function 22 = partitionable
                                ;               fixed disk

        mov     ax,0100h        ; return 'done' status
        ret

PartFD  endp

FDMap   proc    near            ; function 23 = get fixed disk
                                ;               logical unit map

        mov     ax,0100h        ; return 'done' status
        ret

FDMap   endp

Error   proc    near            ; bad command code

        mov     ax,8103h        ; error bit and 'done' status
                                ; + "Unknown Command" code
        ret

Error   endp


Init    proc    near            ; function 0 = initialize

        push    es              ; save request packet address
        push    bx

        mov     ax,es:[bx+14]   ; get DevHlp entry point
        mov     word ptr devhlp,ax
        mov     ax,es:[bx+16]
        mov     word ptr devhlp+2,ax

                                ; set offsets to end of code
                                ; and data segments
        mov     word ptr es:[bx+14],offset _TEXT:Init
        mov     word ptr es:[bx+16],offset DGROUP:ident

                                ; display sign-on message...
        push    stdout          ; standard output handle
        push    ds              ; address of message
        push    offset DGROUP:ident
        push    ident_len       ; length of message
        push    ds              ; receives bytes written
        push    offset DGROUP:wlen
        call    DosWrite        ; transfer to OS/2

        pop     bx              ; restore request packet address
        pop     es

        mov     ax,0100h        ; return 'done' status
        ret

Init    endp

_TEXT   ends

        end
