local ffi = require "ffi"
local bit = require "bit"
local ffi_new = ffi.new
local ffi_cast = ffi.cast
local bxor = bit.bxor
local band = bit.band
local bnot = bit.bnot
local rshift = bit.rshift

-- CRC-32 Implemenatation
-- https://github.com/luapower/crc32/blob/master/crc32.lua
local crc = ffi_new("const uint32_t[16]",
    0x00000000, 0x1db71064, 0x3b6e20c8, 0x26d930ac,
    0x76dc4190, 0x6b6b51f4, 0x4db26158, 0x5005713c,
    0xedb88320, 0xf00f9344, 0xd6d6a3e8, 0xcb61b38c,
    0x9b64c2b0, 0x86d3d2d4, 0xa00ae278, 0xbdbdf21c)

local function crc32(b)
    local c, s, b = -1, #b, ffi_cast("const uint8_t*", b)
    for i = 0, s - 1 do
        c = bxor(rshift(c, 4), crc[bxor(band(c, 0xF), band(b[i], 0xF))])
        c = bxor(rshift(c, 4), crc[bxor(band(c, 0xF), rshift(b[i], 4))])
    end
    return bnot(c)
end

return crc32