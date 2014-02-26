-- This is just a stupid example
-- And this is horrible. Still looking for other ways to extend templates.
local template = require "resty.template"
local setmetatable = setmetatable
local pairs = pairs
local concat = table.concat
local escape = template.escape

local html = {}

function html.tag(content)
    return setmetatable({}, {
        __index = function(_, tag)
            return function(_, attr)
                return function()
                    local r, a = {}, {}
                    r[#r + 1] = "<"
                    r[#r + 1] = tag
                    if attr then
                        for k, v in pairs(attr) do
                            a[#a + 1] = k .. '="' .. escape(v) .. '"'
                        end
                        if #a > 0 then
                            r[#r + 1] = " "
                            r[#r + 1] = concat(a, " ")
                        end
                    end
                    if content then
                        r[#r + 1] = ">"
                        r[#r + 1] = escape(content)
                        r[#r + 1] = "</"
                        r[#r + 1] = tag
                        r[#r + 1] = ">"
                    else
                        r[#r + 1] = " />"
                    end
                    return concat(r)
                end
            end
        end,
        __tostring = function()
            return content
        end
    })
end

return html