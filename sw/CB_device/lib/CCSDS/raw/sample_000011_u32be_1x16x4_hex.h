// Auto-generated HEX header from sample-000011-u32be-1x16x4.raw
// Generated: 2025-09-23 14:53:27Z UTC
// Format: unsigned 32-bit, values written as 0xXXXXXXXX hex literals

#ifndef SAMPLE_000011_U32BE_HEX_H
#define SAMPLE_000011_U32BE_HEX_H

#include <stdint.h>

// Image metadata
#define SAMPLE_000011_WIDTH 1
#define SAMPLE_000011_HEIGHT 16
#define SAMPLE_000011_CHANNELS 4
typedef uint32_t raw_u32_t;

// Pixel order: row-major [y][x][c], flattened as y -> x -> c
__attribute__((used)) static const raw_u32_t SAMPLE_000011_DATA[64] = {
    0x7FFFFF55,     0x7FFFD100,     0x80001993,     0x80000596,     0x7FFFE37E,     0x7FFFED57,     0x7FFFF944,     0x800010EE,
    0x7FED35B8,     0x7FE99786,     0x7FEE85E8,     0x7FFF9932,     0x8016AEBC,     0x7FD9048C,     0x80028F23,     0x7FEA179E,
    0x7FF5EC5E,     0x7FF372B8,     0x7FF41EC0,     0x7FF34465,     0x7FF4D71A,     0x7FF3FB5E,     0x7FF3D403,     0x7FF39656,
    0x7FF4764B,     0x7FF40FB2,     0x7FF3C580,     0x7FF3AED0,     0x7FF45433,     0x7FF415D5,     0x7FF3D2D4,     0x7FF3B8E8,
    0x7FF438DA,     0x7FF410F3,     0x7FF3D771,     0x7FF3C291,     0x7FF42757,     0x7FF40A73,     0x7FF3DBE4,     0x7FF3CA6D,
    0xFFFFF0E0,     0xF7EF64C7,     0x0001F00E,     0x966C4F0F,     0x0F0F0F0F,     0xF290F0F0,     0xF0F0F0FF,     0x00000000,
    0xE0000080,     0x3FFFFFFF,     0x3C383BFD,     0xEA000000,     0xEE966C42,     0x187656D6,     0x03C7DAFF,     0xE000074B,
    0xFDCE26A4,     0x005800B0,     0x00100080,     0xFEFFFF4F,     0xFFEFFF7F,     0x0007D000,     0x0007D058,     0xFFFF77FB
};

#define SAMPLE_000011_AT(y,x,c) SAMPLE_000011_DATA[((y)*SAMPLE_000011_WIDTH*SAMPLE_000011_CHANNELS) + ((x)*SAMPLE_000011_CHANNELS) + (c)]

#endif // SAMPLE_000011_U32BE_HEX_H
