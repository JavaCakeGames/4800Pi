#!/bin/bash

java -jar prog8compiler-8.11-dev-all.jar -slowwarn -target cx16 pi.p8
sed -i "/jsr  cx16.init_system_phase2/d" pi.asm
sed -i "/jmp  cx16.cleanup_at_exit/d" pi.asm
sed -ie "s/.word  (+), 2023/.word  (+), 0/" pi.asm
sed -ie "s/, \$3a, \$8f, '\ prog8'//" pi.asm

sed -i "/src line:/d" pi.asm
# I haven't been able to automatically get rid of rts the program's rts without
# breaking everything, so it needs manually removing to save a byte for now.
#sed -i "/; End/,/; variables/d" pi.asm
sed -i "/; program startup initialization/,/; statements/d" pi.asm

64tass --ascii --case-sensitive --long-branch -Wall -Wno-strict-bool -Wno-shadow --no-monitor pi.asm --output 4800PI.PRG
rm *.vice-mon-list *.prg
./box16 -randram -scale 1 -nosound -warp 1 -prg PI.PRG # turbo!
rm *.asm *.asme
