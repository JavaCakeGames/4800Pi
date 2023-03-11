%zeropage basicsafe
%option no_sysinit

%import textio

; Based on: https://github.com/NesHacker/NesPi/blob/main/pi-spigot.js
; With thanks to DesertFish. By James, AKA Java Cake Games.
;
; Written for Prog8 8.11-dev (e5e63cc) but also works on older versions.
;
; All multiplication and division use the mul and div routines even when 24-bit
; results aren't necessary, as doing so doesn't make the program much slower
; while still benefiting from smaller PRG size.
;
; Arrays have @requirezp to force them into zeropage.
; Normal variables are automatically put into zeropage (they all fit).

main {

  ; mul and div routines write their answer into this
  ; Also used as input for div
  ubyte[3] @shared @requirezp asmAnswer

  sub start() {

    cx16.VERA_IEN = 0 ; Disable interrupts for a smidgen more CPU time

    ; It would be nice if this was delayed to reduce the gap after displaying
    ; 3. and the first 1. But I don't think it can be done without increasing
    ; PRG size.
    txt.clear_screen() ; chrout(147)
    txt.chrout('3')
    txt.chrout('.')

    uword numberOfDigits
    %asm{{
      jsr  c64.SCREEN ; x width/columns, y height/rows
      stx  mul24.factor1
      sty  mul24.factor2
      jsr  mul24
    }}
    ; Add 1 (even values only) because 80x60 stops 1 short otherwise
    numberOfDigits = mkword(asmAnswer[1], asmAnswer[0]) | 1

    mul24(numberOfDigits, 10)
    uword length = mkword(asmAnswer[1], asmAnswer[0]) ; 16-bit in asm

    asmAnswer[0] = lsb(length)
    asmAnswer[1] = msb(length)
    ; asmAnswer[2] is already 0
    div24(3)
    length = mkword(asmAnswer[1], asmAnswer[0])

    ; Change nlines to disable CHROUT scrolling on last line
    @($0387) = $ff ; Must come after txt.height()

    ; Too big to start at $3141. Mustn't exceed $9EFF.
    const uword A = $1415

    ; Used to be to (length + 1) << 1 but this allows for smaller PRG
    for cx16.r0 in A to 37143 step 2 {
      @(cx16.r0) = 2
      @(cx16.r0 + 1) = 0
    }

    ubyte nines
    ubyte predigit

    for cx16.r1 in 1 to numberOfDigits {
      ubyte q
      ubyte[3] @shared @requirezp z24

      for cx16.r2 in length to 1 step -1 {

        uword twoI = cx16.r2 << 1
        uword twoIPlusOne = twoI | 1

        ubyte[3] @shared @requirezp left24
        ubyte[3] @shared @requirezp right24

        mul24(mkword(A[twoIPlusOne], A[twoI]), 10)
        left24[0] = asmAnswer[0]
        left24[1] = asmAnswer[1]
        left24[2] = asmAnswer[2]
        mul24(cx16.r2, q)
        right24[0] = asmAnswer[0]
        right24[1] = asmAnswer[1]
        right24[2] = asmAnswer[2]

        ; 24-bit addition.
        ; Original version written or stolen by Bing/Sydney.
        ; Adjusted by ChatGPT.
        %asm{{
          lda left24     ; load low byte of left
          clc            ; clear carry
          adc right24    ; add low byte of right
          sta z24        ; store low byte of z24
          lda left24+1   ; load middle byte of left
          adc right24+1  ; add middle byte of right with carry
          sta z24+1      ; store middle byte of z24
          lda left24+2   ; load high byte of left
          adc right24+2  ; add high byte of right with carry
          sta z24+2      ; store high byte of z24
          bcc no_carry   ; if no carry from high byte addition, skip next line
          inc z24+2      ; increment third byte of z24
          no_carry:
        }}

        asmAnswer[0] = z24[0]
        asmAnswer[1] = z24[1]
        asmAnswer[2] = z24[2]
        div24(twoI - 1)
        q = asmAnswer[0]

        A[twoI] = lsb(cx16.r0)
        A[twoIPlusOne] = msb(cx16.r0)

      }

      asmAnswer[0] = q
      ; asmAnswer[1] and [2] are already 0 from prior loop

      div24(10)
      q = asmAnswer[0]
      A[2] = lsb(cx16.r0)

      when q {
        9 -> nines++
        10 -> {
          txt.chrout(predigit + 49)
          if nines != 0 {
            for cx16.r0L in 1 to nines {
              txt.chrout('0')
            }
          }
          predigit = 0
          nines = 0
        }
        else -> {
          if (cx16.r1 > 2) txt.chrout(predigit + 48)
          predigit = q
          if nines != 0 {
            for cx16.r0L in 1 to nines {
              txt.chrout('9')
            }
            nines = 0
          }
        }
      }

    }

    %asm{{
      wai ; End
    }}

  }

  ; WARNING: This clobbers whatever byte follows factor1.
  ; Last I checked, this is div24.remainder.
  ; If program is unstable, check generated asm to see if it conflicts!
  ;
  ; Modified from:
  ; https://codebase64.org/doku.php?id=base:24bit_multiplication_24bit_product
  sub mul24(uword factor1, ubyte factor2) {
    %asm {{
      stz asmAnswer     ; set product to 0
      stz asmAnswer+1
      stz asmAnswer+2
      stz factor1+2

    loop
      lda factor2      ; while factor2 != 0
      bne nz
      rts
    nz
      lda factor2      ; if factor2 is odd
      and #$01
      beq skip

      lda factor1      ; product += factor1
      clc
      adc asmAnswer
      sta asmAnswer

      lda factor1+1
      adc asmAnswer+1
      sta asmAnswer+1

      lda factor1+2
      adc asmAnswer+2
      sta asmAnswer+2      ; end if

    skip
      asl factor1      ; << factor1
      rol factor1+1
      rol factor1+2
      ror factor2      ; >> factor2

      jmp loop      ; end while
    }}
  }

  ; cx16.r0 is the remainder. Based on:
  ; https://codebase64.org/doku.php?id=base:24bit_division_24-bit_result
  ; If using the software stack, rsavex() before and rrestorex() after
  sub div24(uword divisor) {
    %asm{{
      div24          ;preset remainder to 0
        stz cx16.r0
        stz cx16.r0+1
        ldx #24          ;repeat for each bit: ...

      divloop  asl asmAnswer  ; dividend lb & hb*2, msb -> Carry
        rol asmAnswer+1
        rol asmAnswer+2
        rol cx16.r0  ; remainder lb & hb * 2 + msb from carry
        rol cx16.r0+1
        lda cx16.r0
        sec
        sbc divisor  ; subtract divisor to see if it fits in
        tay          ; lb result -> Y, for we may need it later
        lda cx16.r0+1
        sbc divisor+1
        bcc skip  ; if carry=0 then divisor didn't fit in yet

        sta cx16.r0+1  ; else save subtraction result as new remainder,
        sty cx16.r0
        inc asmAnswer   ; and INCrement result cause divisor fit in 1 times

      skip  dex
        bne divloop
    }}
  }

}