// Auto-generated HEX header from sample-005535-s32be-2x16x4.raw
// Generated: 2025-09-24 08:31:51Z UTC
// Input: signed 32-bit big-endian; values emitted as (int32_t)0xXXXXXXXX

#ifndef SAMPLE_005535_S32BE_HEX_H
#define SAMPLE_005535_S32BE_HEX_H

#include <stdint.h>

// Image metadata
#define SAMPLE_005535_WIDTH 2
#define SAMPLE_005535_HEIGHT 16
#define SAMPLE_005535_CHANNELS 4
typedef int32_t raw_s32_t;

// Pixel order: row-major [y][x][c], flattened as y -> x -> c
static const raw_s32_t SAMPLE_005535_DATA[128] = {
    (int32_t)0xFFFFFFFF,     (int32_t)0x000000B1,     (int32_t)0x00000045,     (int32_t)0xFFFFFFF5,     (int32_t)0x000003FF,     (int32_t)0x00000073,     (int32_t)0x00000077,     (int32_t)0x00000027,
    (int32_t)0x00000431,     (int32_t)0x000000A5,     (int32_t)0x000000A9,     (int32_t)0x00000059,     (int32_t)0x00000471,     (int32_t)0x00000109,     (int32_t)0x000000CD,     (int32_t)0x0000007D,
    (int32_t)0x000003B1,     (int32_t)0xFFFFFD07,     (int32_t)0x000000A5,     (int32_t)0x00000055,     (int32_t)0x00000389,     (int32_t)0xFFFFFCDF,     (int32_t)0x0000007D,     (int32_t)0x0000002D,
    (int32_t)0x000001A9,     (int32_t)0xFFFFFC1C,     (int32_t)0x0000005D,     (int32_t)0x0000004F,     (int32_t)0x000001B0,     (int32_t)0xFFFFFBF4,     (int32_t)0x00000035,     (int32_t)0x00000027,
    (int32_t)0x00000188,     (int32_t)0xFFFFFBCC,     (int32_t)0x0000000D,     (int32_t)0xFFFFFFFF,     (int32_t)0x00000162,     (int32_t)0xFFFFFBAC,     (int32_t)0xFFFFFF83,     (int32_t)0x00000050,
    (int32_t)0x000003CF,     (int32_t)0xFFFFFCD1,     (int32_t)0xFFFFFF1B,     (int32_t)0x00000028,     (int32_t)0x000003F8,     (int32_t)0xFFFFFC4E,     (int32_t)0xFFFFFF18,     (int32_t)0x00000025,
    (int32_t)0x000003F5,     (int32_t)0xFFFFFC4B,     (int32_t)0xFFFFFF15,     (int32_t)0x00000022,     (int32_t)0x00000125,     (int32_t)0xFFFFF843,     (int32_t)0xFFFFFF37,     (int32_t)0x00000273,
    (int32_t)0x000001AC,     (int32_t)0xFFFFF894,     (int32_t)0xFFFFFE39,     (int32_t)0x000002F4,     (int32_t)0xFFFFFCEC,     (int32_t)0xFFFFF78E,     (int32_t)0xFFFFFE3B,     (int32_t)0x000001D4,
    (int32_t)0x00001800,     (int32_t)0x00001897,     (int32_t)0x00001885,     (int32_t)0x000017E5,     (int32_t)0x0000181F,     (int32_t)0x00001A69,     (int32_t)0x000018B7,     (int32_t)0x00001817,
    (int32_t)0x00001851,     (int32_t)0x00001A9B,     (int32_t)0x000018E9,     (int32_t)0x00001849,     (int32_t)0x00001851,     (int32_t)0x00001ABF,     (int32_t)0x0000190D,     (int32_t)0x0000186D,
    (int32_t)0x00001581,     (int32_t)0x000016B7,     (int32_t)0x000018E5,     (int32_t)0x00001845,     (int32_t)0x00001559,     (int32_t)0x0000168F,     (int32_t)0x000018BD,     (int32_t)0x00001825,
    (int32_t)0x000013F9,     (int32_t)0x0000154F,     (int32_t)0x0000189D,     (int32_t)0x0000181B,     (int32_t)0x000012D5,     (int32_t)0x00001527,     (int32_t)0x00001875,     (int32_t)0x000017F3,
    (int32_t)0x000012AD,     (int32_t)0x000014FF,     (int32_t)0x0000189A,     (int32_t)0x000017CB,     (int32_t)0x0000118D,     (int32_t)0x00001520,     (int32_t)0x000017EE,     (int32_t)0x000017CA,
    (int32_t)0x0000114A,     (int32_t)0x000014FC,     (int32_t)0x000017C6,     (int32_t)0x000017A2,     (int32_t)0x000010FE,     (int32_t)0x000014F9,     (int32_t)0x000017C3,     (int32_t)0x0000179F,
    (int32_t)0x000010FB,     (int32_t)0x000014F6,     (int32_t)0x000017C0,     (int32_t)0x0000151F,     (int32_t)0x00000CF9,     (int32_t)0x00001547,     (int32_t)0x00001847,     (int32_t)0x00001541,
    (int32_t)0x00000BD1,     (int32_t)0x00001569,     (int32_t)0x00000CD5,     (int32_t)0x00001121,     (int32_t)0x00000991,     (int32_t)0x0000176A,     (int32_t)0x00001019,     (int32_t)0x00001121
};

#define SAMPLE_005535_AT(y,x,c) SAMPLE_005535_DATA[((y)*SAMPLE_005535_WIDTH*SAMPLE_005535_CHANNELS) + ((x)*SAMPLE_005535_CHANNELS) + (c)]

#endif // SAMPLE_005535_S32BE_HEX_H
