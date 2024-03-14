#!/bin/bash

java -jar prog8compiler-10.1-all.jar -target cx16 pi.p8
sed -i "/jsr  cx16.init_system_phase2/d" pi.asm
sed -i "/jmp  cx16.cleanup_at_exit/d" pi.asm
sed -ie "s/.word  (+), 2024/.word  (+), 0/" pi.asm
sed -ie "s/, \$3a, \$8f, '\ prog8'//" pi.asm

sed -i "/jsr  sys.init_system_phase2/d" pi.asm
sed -i "/jmp  sys.cleanup_at_exit/d" pi.asm
sed -ie "s/.word  (+), 2024/.word  (+), 0/" pi.asm
sed -ie "s/, \$3a, \$8f, '\ prog8'//" pi.asm
sed -i "/src line:/d" pi.asm
sed -i "/; program startup initialization/,/; statements/d" pi.asm

64tass --ascii --case-sensitive --long-branch -Wall -Wno-strict-bool -Wno-shadow --no-monitor pi.asm --output 4800PI.PRG
rm *.vice-mon-list *.prg
./x16emu -prg 4800PI.PRG -mhz 32 -sound none -run
rm *.asm *.asme
