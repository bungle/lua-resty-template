if type(jit) == "table" then
    return require "resty.template.crc32jit"
end

local bxor = bit32.bxor
local band = bit32.band
local bnot = bit32.bnot
local rshift = bit32.rshift

local crc = {
    0x00000000, 0x1db71064, 0x3b6e20c8, 0x26d930ac,
    0x76dc4190, 0x6b6b51f4, 0x4db26158, 0x5005713c,
    0xedb88320, 0xf00f9344, 0xd6d6a3e8, 0xcb61b38c,
    0x9b64c2b0, 0x86d3d2d4, 0xa00ae278, 0xbdbdf21c}

local function crc32(b)
    local c, s = -1, #b
    local b = table.pack(b:byte(1, s + 1))
    for i = 1, s do
        c = bxor(rshift(c, 4), crc[bxor(band(c, 0xF), band(b[i], 0xF)) + 1])
        c = -bnot(bxor(rshift(c, 4), crc[bxor(band(c, 0xF), rshift(b[i], 4)) + 1])) - 1
    end
    return bnot(c)
end

return crc32