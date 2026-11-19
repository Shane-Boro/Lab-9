8255 PPI 8-Digit 7-Segment Display Scroller ("SHE")
===================================================

Overview
--------
This project contains 8086 GNU Assembly (GAS) code that configures an Intel 8255
Programmable Peripheral Interface (PPI) to scroll the word "SHE" continuously
back and forth across an 8-digit common-anode 7-segment LED display[cite: 1].

Hardware & I/O Port Mapping
---------------------------
Base I/O Address: 0x640[cite: 1]

- Port A (0x640): Active-low digit selection (PA7 = leftmost dig-7 .. PA0 = rightmost dig-0)[cite: 1].
  Drives PNP common-anode transistors tied to Vcc (0 = ON, 1 = OFF)[cite: 1].
- Port B (0x641): Active-high segment data (PB6..PB0 = segments g..a, PB7 = NC)[cite: 1].
  Drives NPN cathode sinking transistors tied to Ground (1 = ON, 0 = OFF)[cite: 1].
- Port C (0x642): Unused.
- Control Register (0x643): Configured with 0x80 (0b10000000) for Mode 0, all ports Output[cite: 1].

7-Segment Encodings (Port B)
----------------------------
Bit format: X g f e d c b a (Bit 7 unused = 0)[cite: 1]

- 'S' : Segments a, c, d, f, g -> 0b01101101 (0x6D)[cite: 1]
- 'H' : Segments b, c, e, f, g -> 0b01110110 (0x76)[cite: 1]
- 'E' : Segments a, d, e, f, g -> 0b01111001 (0x79)[cite: 1]
- Blank: None                  -> 0b00000000 (0x00)

How It Works
------------
1. Initialization: Writes 0x80 to 0x643 to set Ports A, B, and C as Mode 0 outputs[cite: 1].
2. Buffering: Populates an 8-byte buffer (display_buf) with the segment bytes for
   'S', 'H', and 'E' at the current scroll offset while keeping remaining digits blank.
3. Multiplexing: Scans digits 0 through 7 rapidly. Before updating Port B, all
   digits are disabled (0xFF sent to Port A) to prevent ghosting, then the active
   digit's low bit is rotated via ROL across PA0-PA7.
4. Scrolling: After 40 refresh frames, the starting index shifts right (dig-7 down
   to dig-2) and bounces back left (dig-2 up to dig-7) in an infinite loop.

Assembling (GNU Assembler)
--------------------------
as --32 -o scroll_she.o scroll_she.s
ld -m elf_i386 --oformat binary -o scroll_she.bin scroll_she.o