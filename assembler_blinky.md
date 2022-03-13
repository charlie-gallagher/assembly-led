# Blink an LED in Assembly
As an interesting project, I want to create a blinking LED purely in ARM
assembly. It's a little dumb that I'm starting this now, before I go on vacation
for two weeks, but I'm planning on spec'ing things out a little, considering
what I still need to learn, these types of things. 

# Unkowns
Basically everything is an unknown at this point. Should I work on initializing
the reset button? What do I need to get the debugger to work on my minimal
system? I think the first iteration of this will involve going in blind with no
reset button or debugger. I don't even know if that makes sense.


# System Startup
There are a couple case:

- Power on
- Reset event

I'll need to know how to distinguish between these. Maybe they're both
considered reset events? 

## HAL System Startup
There are a few steps executed in the HAL startup file: 

- Set the initial SP
- Set the initial `PC = Reset_Handler`
- Set the vector table entries with the exceptions ISR address
- Copy the data segment initializers from flash to SRAM
- Zero fill the bss segment
- Call the clock system intitialization function

Once the program gets to `main`, there are several more initialization steps: 

- `HAL_Init`, reset of all peripherals. Initializes the Flash interface and the
  Systick
- `SystemClock_Config` Configure the system clock
- Initialize all configured peripherals
  - `MX_GPIO_Init`
  - `MX_I2C1_Init`
  - `MX_USB_OTG_FS_PCD_Init`


Not all of these apply to me, but I'll definitely need `MX_GPIO_Init` (or
something similar to it). I don't need I2C or USB OTG. 


## Boot Modes
There are two boot pins, BOOT0 and BOOT1, which must be initialized to determine
how the first 256K are aliased. In my case, I believe they should be aliased to
internal flash. The details of this are still beyond me, and I don't see the
boot pins initialized in the HAL startup script. 

From the datasheet:

> On reset the 16 MHz internal RC oscillator is selected as the default CPU
> clock.

Later:

> The bootloader is located in system memory. It is used to reprogram the Flash
> memory by using either USART1(PA9/10), USART2(PD5/6), USB OTG FS in device
> mode (PA11/12) through DFU (device firmware upgrade), I2C1(PB6/7),
> I2C2(PB10/3), I2C3(PA8/PB4), SPI1(PA4/5/6/7), SPI2(PB12/13/14/15) or
> SPI3(PA15, PC10/11/12).

If I'm understanding this correctly, I don't need the boot pins because I won't
be reprogramming the Flash memory. 

## Reset vector
What happens on startup? Where do I look for this? The code section of memory
occupies addresses 0x0000 0000 through 0x1FFF FFFF, so my instructions will go
in this area of memory. I believe the first few dozen addresses are reserved for
various interrupt events, of which the reset event is an example. So, let's look
at the interrupt documentation. 

See Chapter 10 of the SM32F401xB/C/D/E technical reference manual. Actually,
this refers me to PM0214, the programming manual. I should've thought to look
there, since I will be programming after all. 

Refer to page 40 of the programming manual for a table of the interrupt vectors.
The first few are (in a descending memory arrangement):

```
Offset                  Size            Description
-------                 ------          -----------
0x0000 0000             4 bytes         Initial SP
0x0000 0004             4 bytes         Reset
0x0000 0008             4 bytes         NMI
0x0000 000C             4 bytes         Hard fault
...
```

You get the idea. I need to load `0x0000 0004` with the address of a reset
handler. This is done automatically by the linker, so you don't have to worry
about anything after you write in `Reset_Handler` in the appropriate place. 

Here's the assembly for loading the interrupt vector table.

```as
   .section  .isr_vector,"a",%progbits
  .type  g_pfnVectors, %object
  .size  g_pfnVectors, .-g_pfnVectors
    
g_pfnVectors:
  .word  _estack
  .word  Reset_Handler
  .word  NMI_Handler
  .word  HardFault_Handler
...
```

I found a good reference for these directives (also called _pseudo-ops_):
[link](https://sourceware.org/binutils/docs/as/Type.html). 

`.section` defines an object file section. The syntax for `.section` for ELF is: 

```
.section name [, "flags"[, @type[,flag_specific_arguments]]]
```

The `"a"` means section is allocatable. The `@type` may be `%type`, as in this
code snippet, and the reference gives `%progbits` as meaning "section contains
data." 

`.type` sets the type for a symbol. The syntax for `.type` is:

```
.type name , type description
```

Further, the percent sign has no significance besides marking the start of a
type. The "object" type means it is a data object. 

`.size` sets the size associated with a symbol. The syntax for `.size` for ELF
is:

```
.size name , expression
```

So this contains an expression:

```
  .size  g_pfnVectors, .-g_pfnVectors
```

which "can make use of label arithmetic." With all this in mind, the section
description makes a little bit more sense. We're defining a data section called
`.isr_vector` which is allocatable and contains program data. Then, we define a
symbol `g_pfnVectors`, which is a data object with size `.-g_pfnVectors`. The
size expression is still opaque, but we're getting there. 


Sam pointed out correctly that the directives here are important only for
compiling and linking. I think I'm still gonna compile and link, so I can keep
multiple source files if necessary. 

There will most likely be a learning curve with the assembler `as`, outside of
just learning to program in assembly in the first place. Not thrilled about
that -- seems like every day I have to learn a new compiler (`cl`, `gcc`, now
`as`). Anyway, we're all set now with the startup code. 


As an experiment, maybe I can try to compile a very minimal program, link it,
and load it into flash. All it will do is run a loop that increments register 0,
so that it is effectively a program counter. 

```as
main:
    ldr r0, #0

main_loop:
    add r0, r0, #1
    b main_loop
```

Something like this. Then I can try to connect the debugger and see what happens
to it. 


Quick note on assembler expressions. I'm trying to work out the exact meaning of
`.-g_pfnVectors`. It's an expression, as described by the documentation for
`.size`. Expressions may be absolute, or they may refer to symbols in the same
section, at least in the case of subtraction. Definitely read the documentation
again, but for this expression the point is that `g_pfnVectors` is probably
functioning as an offset, the address of the array. The `.` is special, but I
haven't found it in the manual, so I can't be sure. My guess is that it returns
the difference between the last element of the array and the first. 

"An _expression_ specifies an address or numeric value... The result of an
expression must be an absolute number, or else an offset into a particular
section." 

Aha! In the "symbols" chapter, there's a section for the special dot symbol.
"The special symbol '.' refers to the current address that `as` is assembling
into. So, I was right in thinking that it's similar to the dot symbol in linker
scripts. That doesn't totally help, though, because the two expressions are:

```
.type  g_pfnVectors, %object
.size  g_pfnVectors, .-g_pfnVectors
    
g_pfnVectors:
  .word  _estack
  .word  Reset_Handler
...
```

So wouldn't the size be 0? I haven't found anything to the contrary yet, but
we'll see. 

It's worth noting that the `.size` directive almost always comes after a
section, in which case it makes more sense. It's possible this is a mistake? 

For what it's worth, the object file dump for this symbol is:

```
00000000 g     O .isr_vector	00000000 g_pfnVectors
```

Which means it's a 'g'lobal 'O'bject symbol in the `.isr_vector` section with
the name `g_pfnVectors`. (For more on the format of `objdump`, see the man file
for the `-t` flag.) 



# A first attempt
I wrote a couple scripts that might've worked, but of course they did not. More
on this when I get back from our trip. Well, I'm back, and I feel real rusty.
Still, compiling a very simple program should be within reach. Of course, it's
not _super_ easy, but I took code from various scripts and simplified it for my
purpose. I'm getting this error: 

```
arm-none-eabi-ld: warning: cannot find entry symbol _start; defaulting to 0000000000008000
arm-none-eabi-ld: blinky.o: in function `Reset_Handler':
(.text.Reset_Handler+0x8): undefined reference to `_estack'
arm-none-eabi-ld: blinky.o:(.isr_vector+0x0): undefined reference to `_estack'
```

Doesn't seem too bad. It looks like I'm not passing in my linker script. Let me
start by doing that. 

Also, note that I looked through the Makefile for `blinky` and although
something is done for the assembly file, I don't understand exactly what, and it
all seems to get thrown through `gcc` in the end. 

```
arm-none-eabi-ld: warning: cannot find entry symbol Reset_Handler; defaulting to 0000000008000194
```

Now that's the only warning, and it's just a warning. Still, why couldn't find
the `Reset_Handler` symbol? Let me check the object file created after compiling
to see if it shows up. It shows up, and it has the address it claims to have
been given in the warning, but that seems okay for my purposes. Definitely
something to clean up later, but for now let me try to load it onto the MCU and
see what happens. 

To write with `st-flash`:

```
arm-none-eabi-objcopy -O binary blinky.elf blinky.bin
arm-none-eabi-objdump -D blinky.bin > TEST_blinky_asm.s
```

Unfortunately, I'm getting an "unrecognized format" error when I try to
disassemble `blinky.bin`. But I don't get the same error when I dump the ELF
file, so maybe everything's okay? I don't know, but let's load it up anyway and
be reckless. 

```
st-flash write blinky.bin 0x8000000
```

Okay, all loaded up with no problems. Now I just need to try connecting the
debugger and hope that it's a sensical thing to do at this stage. I know that
I'm not supposed to hope with computers, because that usually means I don't
understand something, and I admit I don't understand the gdb stuff very well. 


```
cp /usr/shared/openocd/scripts/target/stm32f4x.cfg debug/stm32f4x.cfg
cp /usr/shared/openocd/scripts/interface/stlink.cfg debug/stlink.cfg
openocd -f stlink.cfg -f stm32f4x.cfg &
```

Success! It's debugging and incrementing the `r0` register! Let's call it a
night there. 


# Initializing the GPIO pins
There are a couple steps between where I am now (running arbitrary code on the
MCU) and blinking an LED. I'm going to use a general-purpose IO pin (GPIO) that
is already connected to the LED. To set up for LED, I need to set the pin as an
output, do any other initialization steps, and then find the register I have to
write to toggle the LED. 

Let's start with the technical reference manual's chapter on GPIO (chapter 8, p.
145). 

## TRM: General-purpose I/Os
"Each general-purpose I/O port has four 32-bit configuration registers..., two
32-bit data registers..., a 32-bit set/reset register..., a 32-bit locking
register... and two 32-bit alternate function selection register." 

- Configuration registers
  - `GPIOx_MODER`
  - `GPIOx_OTYPER`
  - `GPIOx_OSPEEDR`
  - `GPIOx_PUPDR`
- Data registers
  - `GPIOx_IDR`
  - `GPIOx_ODR`
- Set/reset register
  - `GPIOx_BSRR`
- Locking register
  - `GPIOx_LCKR`
- Alternate function selection register
  - `GPIOx_AFRH`
  - `GPIOx_AFRL`

"The purpose of the `GPIOx_BSRR` register is to allow atomic read/modify
accesses to any of the GPIO registers." 

### Initialization
"During and just after reset, the... I/O ports are configured in input floating
mode." There's also some stuff about debug ports. I'm not sure what I need to
know here at this early stage. 

To initialize the GPIO, you configure the `GPIOx_MODER` register. This register
sets the direction. 

- `MODER` Sets the direction
- `OTYPER` Sets the output type
- `OSPEEDR` Sets the output speed
- `PUPDR` Selects the pull-up/pull-down behavior, regardless of direction

Then you have the data registers, each is 16-bit. 

- `IDR` Input data register. Read-only.
- `ODR` Output data register. Read/write accessible. 

### Writing with the bit set reset register
The `BSRR` register (bit set reset register) is 32-bit and allows the
application to set and reset each individual bit in the output data register. 

Each bit in `ODR` corresponds to two control bits in `BSRR`, called `BSRR(i)`
and `BSRR(i+size)`. Note that writing 0 to any `BSRR` bit has no effect.
Instead, you write `BSRR(i)` to set and `BSRR(i+SIZE)` to reset a bit. 

### Registers
First, let me go check the datasheet for some insight into where the GPIO
section in memory is mapped. The GPIO section of memory is within the AHB1
section from 0x400203FF to 0x40021C00. In particular,

```
0x4002 0000 - 0x4002 03FF               GPIOA
0x4002 0400 - 0x4002 07FF               GPIOB
0x4002 0800 - 0x4002 0BFF               GPIOC
0x4002 0C00 - 0x4002 0FFF               GPIOD
0x4002 1000 - 0x4002 13FF               GPIOE
0x4002 1C00 - 0x4002 1FFF               GPIOH
```

So, that gives us `0x3FF` or 1K per IO, which are named from A-H, skipping F and
G. The different registers are listed with an offset, which is an offset from
this absolute address. So for example, `GPIOA_MODER` is offset 0x00, so it has
an absolute address of 0x4002 0000. 

There are reset values for the different ports (A-E,H). These are how the pins
are configured upon reset. 

For `MODER` (offset 0x00), there are 15 pairs of bits each with 4 possible
configurations: 

```
00      Input (reset state)
01      General purpose output
10      Alternate function mode
11      Analog mode
```

Upon reset, the ports are set to:

```
Port A:         0000 1100 0000 0000 0000 0000 0000 0000
Port B:         0000 0000 0000 0000 0000 0010 1000 0000
Other ports:    0000 0000 0000 0000 0000 0000 0000 0000
```

`GPIOx_OTYPER` is at offset 0x04, and it is the output type register. This
controls the output type. The first 16 bits are used; the last 16 are reserved.
A reserved location must be kept at the reset value. 

```
0       Push-pull (reset state)
1       Open-drain
```

Upon reset, the values are all zero. 



For me, push-pull is the right one, so I don't have to configure this (its reset
state is enough). But as practice, I should try writing the zero to it anyway. 

Output speed is set at 0x08. 

```
00      Low speed
01      Medium speed
10      Fast speed
11      High speed
```

Upon reset, the values are:


```
Port A:         0000 1100 0000 0000 0000 0000 0000 0000
Port B:         0000 0000 0000 0000 0000 0000 1100 0000
Other ports:    0000 0000 0000 0000 0000 0000 0000 0000
```

The pull-up/pull-down register has an offset of 0x0C, and may be configured in
the following ways for each 2-bit pair. 

```
00      No pull-up, pull-down
01      Pull-up
10      Pull-down
11      Reserved
```

The reset configuration is: 

```
Port A:         0110 0100 0000 0000 0000 0000 0000 0000
Port B:         0000 0000 0000 0000 0000 0001 0000 0000
Other ports:    0000 0000 0000 0000 0000 0000 0000 0000
```

The output port data register is located at offset 0x14. 


GPIO registers can be accessed by byte, half-word, or word.

### Terminology




# Taking Action
Don't want analog output. Sam says I should use the push-pull. 




---

Charlie Gallagher, December 2021
