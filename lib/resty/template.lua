local ffi = require "ffi"
local bit = require "bit"
local ffi_new = ffi.new
local ffi_cast = ffi.cast
local bxor = bit.bxor
local band = bit.band
local bnot = bit.bnot
local rshift = bit.rshift
local setmetatable = setmetatable
local tostring = tostring
local assert = assert
local concat = table.concat
local gmatch = string.gmatch
local load = load
local open = io.open
local echo = print
local type = type

if ngx then echo = ngx.print end

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

local VIEW_ACTIONS = {
    ["{%"] = function(code) return code end,
    ["{*"] = function(code) return ("__r[#__r + 1] = template.output(%s)"):format(code) end,
    ["{{"] = function(code) return ("__r[#__r + 1] = template.escape(%s)"):format(code) end,
    ["{("] = function(view) return ([[__r[#__r + 1] = template.compile("%s")(context)]]):format(view) end
}

local HTML_ENTITIES = {
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&#39;",
    ["/"] = "&#47;"
}

local CODE_ENTITIES = {
    ["{"] = "&#123;",
    ["}"] = "&#125;"
}

local template = { cache = {} }

function template.output(s)
    if s == nil then
        return ""
    else
        local t = type(s)
        if t == "function" then
            return template.output(s())
        elseif t == "table" then
            return tostring(s)
        else
            return s
        end
    end
end

function template.escape(s, c)
    if s == nil then
        return ""
    else
        local t = type(s)
        if t == "string" and #t > 0 then
            if c then
                return template.escape(s:gsub([=[[}{]]=], CODE_ENTITIES))
            else
                return s:gsub([=[[">/<'&]]=], HTML_ENTITIES)
            end
        elseif t == "function" then
            return template.output(s())
        elseif t == "table" then
            return tostring(s)
        else
            return s
        end
    end
end

function template.new(view, layout)
    assert(view, "view was not provided for template.new(view, layout).")
    if layout then
        return setmetatable({ render = function(self, context)
                local context = context or self
                self.view = template.compile(view)(context)
                template.render(layout, context)
            end }, { __tostring = function(self)
                local context = context or self
                self.view = template.compile(view)(context)
                return template.compile(layout)(context)
            end
        })
    else
        return setmetatable({ render = function(self, context)
            template.render(view, context or self)
            end }, { __tostring = function(self)
                return template.compile(view)(context or self)
            end
        })
    end
end

function template.compile(view)
    assert(view, "view was not provided for template.compile(view).")
    local crc = crc32(view)
    if template.cache[crc] then return template.cache[crc] end
    local file, content = open(view, "r"), view
    if file then
        content = file:read("*a")
        file:close()
    end
    local matches, codeblock = gmatch(content .. "{}", "([^{]-)(%b{})"), false
    local c = {[[local __r = {}]]}
    for t, b in matches do
        local act = VIEW_ACTIONS[b:sub(1, 2)]
        local len = #t
        local slf = len > 0 and "\n" == t:sub(1, 1)
        local elf = len > 0 and "\n" == t:sub(-1, 1)
        if act then
            if slf then
                if not codeblock then
                    c[#c + 1] = [[__r[#__r + 1] = "\n"]]
                end
                if len > 1 then
                    c[#c + 1] = "__r[#__r + 1] = [[" .. t:sub(2) .. "]]"
                end
            elseif elf and len > 1 then
                c[#c + 1] = "__r[#__r + 1] = [[" .. t:sub(-2) .. "]]"
            elseif len > 0 then
                c[#c + 1] = "__r[#__r + 1] = [[" .. t .. "]]"
            end
            c[#c + 1] = act(b:sub(3, -3))
            if not codeblock then
                if elf and not slf then
                    c[#c + 1] = [[__r[#__r + 1] = "\n"]]
                end
            end
            codeblock = b:sub(1, 2) == "{%"
        elseif #b > 2 then
            c[#c + 1] = "__r[#__r + 1] = [[" .. t .. b .. "]]"
            codeblock = false
        else
            if not codeblock then
                if slf or elf then
                    c[#c + 1] = [[__r[#__r + 1] = "\n"]]
                end
            end
            if len > 0 then
                c[#c + 1] = "__r[#__r + 1] = [[" .. t .. "]]"
            end
            codeblock = false
        end
    end
    c[#c + 1] = "return __c(__r)"
    c = concat(c, "\n")
    local f = function(context)
        local context = context or {}
        return assert(load(c, view, "t", setmetatable({
            template = template,
             context = context,
                 __c = concat
        }, {
             __index = function(_, k)
                 return context[k] or template[k] or _G[k]
             end
        })))()
    end
    template.cache[crc] = f
    return f
end

function template.render(view, context)
    assert(view, "view was not provided for template.render(view, context).")
    echo(template.compile(view)(context))
end

return template
