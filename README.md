# STM32 Assembly LED Blink
This is in essence an exercise in constrained resources. I also wanted to learn
some ARM, about linker scripts, etc. etc.

**Microcontroller/board:** STM32F401-DISCO

## Status
Currently, the code compiles, links, and flashes onto the MCU, but **it does not
blink an LED.** All it does is increment a register in an infinite loop. 


## Build
I have not written a Makefile yet because there is a very minimal build process.
You can source `compile.sh` to build. 

```
bash compile.sh
```

### Debugging
I've been debugging with `gdb` and `openOCD`. The latter serves as host to the
former. To do the same, you'll need two `openOCD` config files:

- `stlink.cfg`
- `stm32f4.cfg`

```
> openocd -f stlink.cfg -f stm32f4.cfg &
> gdb
(gdb) target extended-remote localhost:3333
(gdb) file blinky.elf
```

And so on.


## Background
This is a learning project, to become familiar with a modern microcontroller and
its assembly language. It's also my first experience with using `as` to write
and assemble code, and it's the first time I'm writing a linker script for `ld`. 

### Toolset
I tried to restrict myself to reference manuals and the like, and some
automatically generated code from STM Cube MX. I've used that code as reference,
and tried to simplify it to suit my minimal needs. 

My actual toolchain is composed of:

- GNU build tools `ld` and `as`
- [stlink](https://github.com/stlink-org/stlink) for writing the binary to flash
- GNU's `gdb` debug tool, with `openocd`


### My background
I started reading about computers and computer architecture in the early spring
of 2021 with only a little computer science background (C and basic compiling
procedures, etc.). I read a few books on microprocessor architecture (_Code_ by
Charles Petzold, then _Microprocessors and Microcomputers_ by Tocci and
Laskowski. The latter book set me up well to start working with a
microcontroller, so I picked up an STM32 discovery board and started reading. 

At the same time, I started writing
[cpu](https://github.com/charlie-gallagher/cpu), a virtual CPU that runs
visually on a command line. It was modeled after the simple MOS 6502
microprocessor. 

I picked up a copy of _ARM System Developer's Guide_ as well, although I haven't
read much of it. 

So, armed with some knowledge, I started tinkering with the microcontroller.
Writing C code using CubeMx was fun, but too easy. I wanted the authentic
architecture experience. So I generated a simple codebase and used it as a
template that I could simplify. So here we are. 




---

Charlie Gallagher, March 2022
