arm-none-eabi-as -g -o blinky.o as_blinky.s
arm-none-eabi-ld -o blinky.elf -T as_blinky_link.ld blinky.o
arm-none-eabi-objcopy -O binary blinky.elf blinky.bin
