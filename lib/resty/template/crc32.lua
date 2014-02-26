local ok, ffi = pcall(require, "ffi")

if not ok then
    return function(buf) return buf end
end

local bit = require "bit"
local ffi_new = ffi.new
local ffi_cast = ffi.cast
local bxor = bit.bxor
local band = bit.band
local bnot = bit.bnot
local rshift = bit.rshift

-- CRC-32 Implemenatation
-- https://github.com/luapower/crc32/blob/master/crc32.lua
local s_crc32 = ffi_new("const uint32_t[16]",
    0x00000000, 0x1db71064, 0x3b6e20c8, 0x26d930ac,
    0x76dc4190, 0x6b6b51f4, 0x4db26158, 0x5005713c,
    0xedb88320, 0xf00f9344, 0xd6d6a3e8, 0xcb61b38c,
    0x9b64c2b0, 0x86d3d2d4, 0xa00ae278, 0xbdbdf21c)

local function crc32(buf)
    local crc, sz, buf  = -1, #buf, ffi_cast("const uint8_t*", buf)
    for i = 0, sz - 1 do
        crc = bxor(rshift(crc, 4), s_crc32[bxor(band(crc, 0xF), band(buf[i], 0xF))])
        crc = bxor(rshift(crc, 4), s_crc32[bxor(band(crc, 0xF), rshift(buf[i], 4))])
    end
    return bnot(crc)
end

return crc32