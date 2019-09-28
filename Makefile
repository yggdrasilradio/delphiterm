
all:	delphiterm

delphiterm: dterm.asm
	lwasm -9 -b -o dterm.bin dterm.asm

clean:
	rm -f *.bin

backup:
	tar -cvf backups/`date +%Y-%m-%d_%H-%M-%S`.tar Makefile *.asm

