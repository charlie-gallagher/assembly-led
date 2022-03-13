arm-none-eabi-as -o blinky.o as_blinky.s
arm-none-eabi-ld -o blinky.elf -T as_blinky_link.ld blinky.o
