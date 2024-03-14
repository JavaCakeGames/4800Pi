%zeropage basicsafe
%option no_sysinit

; Would like LZSA-compressed program but couldn't make it work
;%output raw
;%launcher none
;%address 2697

%import textio

; Based on: https://github.com/NesHacker/NesPi/blob/main/pi-spigot.js
; With thanks to DesertFish (Irmen). By James (Java Cake Games).
;
; Written for Prog8 10.1.
;
; Arrays have @requirezp to force them into zeropage.
; Normal variables are automatically put into zeropage (they all fit).

main {

  ; div routine writes its answer into this
  ; Also used as input for div
  ubyte[3] @shared @requirezp asmAnswer

  &ubyte nines = &cx16.r3L
  &ubyte predigit = &cx16.r3H

  sub start() {

    ; Testing:
    ;cx16.screen_mode(6, false)

    cx16.VERA_IEN = 0 ; Disable interrupts for a smidgen more CPU time

    ;txt.clear_screen() ; chrout(147)
    txt.chrout(147)

    uword numberOfDigits = 4801 ; 80x60 - extra digit to make it print because next is 9
    when cx16.screen_mode(0, true) {
      8 -> numberOfDigits = 3200 ; 64x50
      1, 2 -> numberOfDigits = 2400 ; 80x30, 40x60
      9, 10 -> numberOfDigits = 1600 ; 64x25, 32x50
      3, $80 -> numberOfDigits = 1200 ; 40x30
      11 -> numberOfDigits = 800 ; 32x25
      4, 5 -> numberOfDigits = 600 ; 40x15, 20x30
      7 -> numberOfDigits = 506 ; 22x23
      6 -> numberOfDigits = 300 ; 20x15
    }

    uword length = numberOfDigits * 10

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

    ; It would be nice if this was delayed to reduce the gap after displaying
    ; 3. and the first 1.
    ; But I don't think it can be done without increasing PRG size.
    ; As of R43, the sequence "3." is now in ROM and RAM, but there's no way to
    ; take advantage of that to decrease the PRG size. memory_copy is larger.
    txt.chrout('3')
    txt.chrout('.')

    for cx16.r1 in 1 to numberOfDigits {
      ubyte q

      for cx16.r2 in length to 1 step -1 {

        uword twoI = cx16.r2 << 1
        uword twoIPlusOne = twoI | 1

        cx16.VERA_CTRL = %00000100 ; DCSEL=2, ADDRSEL=0
        @($9f29) = %01000000 ; blit write enabled ("cache writes")

        cx16.VERA_CTRL = %00001100 ; DCSEL=6

        @($9f29) = A[twoI]
        @($9f2a) = A[twoIPlusOne]
        @($9f2b) = 10

        cx16.VERA_CTRL = %00000100 ; DCSEL=2, ADDRSEL=0
        @($9f2c) = %01010000 ; accumulate and multiply
        cx16.VERA_CTRL = %00001100 ; DCSEL=6

        @($9f29) = lsb(cx16.r2)
        @($9f2a) = msb(cx16.r2)
        @($9f2b) = q
        cx16.VERA_DATA1 = 0

        cx16.VERA_CTRL = %00000100 ; DCSEL=2, ADDRSEL=0
        @($9f29) = 0 ; reset
        @($9f2c) = %10010000 ; reset accumulator, multiplier enabled

        cx16.VERA_ADDR_L = 0
        cx16.VERA_ADDR_M = 0
        cx16.VERA_ADDR_H = %00010000 ; increment 1
        asmAnswer[0] = cx16.VERA_DATA0
        asmAnswer[1] = cx16.VERA_DATA0
        asmAnswer[2] = cx16.VERA_DATA0
        ; ignore 4th byte

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
          txt.chrout('1' + predigit)
          repeat nines txt.chrout('0')
          predigit = 0
          nines = 0
        }
        else -> {
          if (cx16.r1 > 2) txt.chrout('0' | predigit)
          predigit = q
          repeat nines txt.chrout('9')
          nines = 0
        }
      }

    }

    %asm{{
      wai ; End - stp not used because emulator
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

      divloop  asl p8v_asmAnswer  ; dividend lb & hb*2, msb -> Carry
        rol p8v_asmAnswer+1
        rol p8v_asmAnswer+2
        rol cx16.r0  ; remainder lb & hb * 2 + msb from carry
        rol cx16.r0+1
        lda cx16.r0
        sec
        sbc p8v_divisor  ; subtract divisor to see if it fits in
        tay          ; lb result -> Y, for we may need it later
        lda cx16.r0+1
        sbc p8v_divisor+1
        bcc skip  ; if carry=0 then divisor didn't fit in yet

        sta cx16.r0+1  ; else save subtraction result as new remainder,
        sty cx16.r0
        inc p8v_asmAnswer   ; and INCrement result cause divisor fit in 1 times

      skip  dex
        bne divloop
    }}
  }

}
