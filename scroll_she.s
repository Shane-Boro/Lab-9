.code16
.text
.globl _start

# ---------------------------------------------------------------------------
# I/O Port Definitions for 8255 PPI (Base Address = 0x640)
# ---------------------------------------------------------------------------
.equ PORT_A,    0x640           # Port A: Active-low digit select (PA7=dig7 .. PA0=dig0)
.equ PORT_B,    0x641           # Port B: Active-high 7-seg data (PB6..PB0 = g..a)
.equ PORT_C,    0x642           # Port C: Unused
.equ CTRL_PORT, 0x643           # Control Register: Mode and I/O direction setup

# ---------------------------------------------------------------------------
# 7-Segment Active-High Bit Patterns (Bit 7=0, Bits 6..0 = g f e d c b a)
# ---------------------------------------------------------------------------
.equ CHAR_S,    0b01101101      # 0x6D: segments a, c, d, f, g lit
.equ CHAR_H,    0b01110110      # 0x76: segments b, c, e, f, g lit
.equ CHAR_E,    0b01111001      # 0x79: segments a, d, e, f, g lit
.equ CHAR_BLK,  0b00000000      # 0x00: all segments off (blank)

_start:
    # 1. Initialize 8255 Control Word
    # Bit 7 = 1 (Mode Set), Bits 6-5 = 00 (Group A Mode 0), Bit 4 = 0 (Port A Out),
    # Bit 3 = 0 (Port C Upper Out), Bit 2 = 0 (Group B Mode 0),
    # Bit 1 = 0 (Port B Out), Bit 0 = 0 (Port C Lower Out)
    mov $0b10000000, %al        # Control word 0x80: All ports Mode 0 Output
    mov $CTRL_PORT, %dx         # Load Control Register address (0x643)
    out %al, %dx                # Write configuration to 8255

    # Initialize scroll state:
    # %bl = leftmost digit index for 'S' (starts at dig-7, ranges 7 down to 2)
    # %bh = scroll direction flag (0 = moving right, 1 = moving left)
    mov $7, %bl                 # Start "SHE" at leftmost position (dig-7, dig-6, dig-5)
    mov $0, %bh                 # Initial direction: scroll right

main_loop:
    # 2. Clear the 8-byte display buffer with blanks
    lea display_buf, %di        # Point %di to start of 8-byte display buffer
    mov $8, %cx                 # 8 digits to clear
    mov $CHAR_BLK, %al          # Blank segment pattern (0x00)
clear_buf:
    mov %al, (%di)              # Set digit buffer entry to blank
    inc %di                     # Advance to next digit position
    loop clear_buf              # Repeat for all 8 digits

    # 3. Place "SHE" into display_buf at current position %bl
    # display_buf[7] = dig-7 (leftmost), display_buf[0] = dig-0 (rightmost)
    mov %bx, %si                # Copy %bx to %si
    and $0x00FF, %si            # Isolate %bl (index of 'S') in %si
    movb $CHAR_S, display_buf(%si)      # Place 'S' at dig-(%bl)
    movb $CHAR_H, display_buf - 1(%si)  # Place 'H' at dig-(%bl - 1)
    movb $CHAR_E, display_buf - 2(%si)  # Place 'E' at dig-(%bl - 2)

    # 4. Multiplex display for 40 refresh frames before advancing scroll position
    mov $40, %cx                # Frame counter controls scrolling speed
frame_loop:
    push %cx                    # Save outer frame counter
    mov $8, %cx                 # Inner loop scans 8 digits (index 0 to 7)
    mov $0, %si                 # %si = current digit index (0 = dig-0 .. 7 = dig-7)
    mov $0b11111110, %ah        # Active-low digit mask starting at PA0 (dig-0)

digit_scan:
    # Blank all digits first to prevent ghosting while changing segment lines
    mov $0xFF, %al              # All 1s turns off all PNP digit transistors
    mov $PORT_A, %dx            # Select Port A (0x640)
    out %al, %dx                # Disable all digits

    # Output segment pattern for current digit to Port B
    mov display_buf(%si), %al   # Fetch 7-segment pattern for digit %si
    mov $PORT_B, %dx            # Select Port B (0x641)
    out %al, %dx                # Drive NPN segment transistors

    # Enable current digit on Port A
    mov %ah, %al                # Load active-low mask for digit %si
    mov $PORT_A, %dx            # Select Port A (0x640)
    out %al, %dx                # Turn on PNP transistor for current digit

    # Short persistence-of-vision delay
    push %cx                    # Preserve digit loop counter
    mov $0x0200, %cx            # Delay count
delay_loop:
    nop                         # Burn clock cycles
    loop delay_loop             # Repeat until %cx = 0
    pop %cx                     # Restore digit loop counter

    # Advance to next digit
    rol $1, %ah                 # Rotate active-low 0 bit left to next PA pin
    inc %si                     # Increment buffer index
    loop digit_scan             # Repeat for all 8 digits

    pop %cx                     # Restore outer frame counter
    loop frame_loop             # Repeat refresh frame

    # 5. Update scroll position (bounce between dig-7 and dig-2)
    cmp $0, %bh                 # Check direction flag (0 = right, 1 = left)
    jne scroll_left

scroll_right:
    dec %bl                     # Shift "SHE" one digit to the right
    cmp $2, %bl                 # Has 'E' reached rightmost digit (S=2, H=1, E=0)?
    jne main_loop               # If not at right edge, continue scrolling right
    mov $1, %bh                 # Reverse direction to scroll left
    jmp main_loop

scroll_left:
    inc %bl                     # Shift "SHE" one digit to the left
    cmp $7, %bl                 # Has 'S' reached leftmost digit (S=7, H=6, E=5)?
    jne main_loop               # If not at left edge, continue scrolling left
    mov $0, %bh                 # Reverse direction to scroll right
    jmp main_loop

.data
display_buf:
    .space 8, 0x00              # 8-byte buffer holding segment codes for dig-0..dig-7
    