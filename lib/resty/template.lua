local assert = assert
local setmetatable = setmetatable
local gmatch = string.gmatch
local print = print
local load = load
local concat = table.concat
local open = io.open

local VIEW_ACTIONS = {
    ["{%"] = function(code)
        return code
    end,
    ["{{"] = function(code)
        return ("__r[#__r + 1] = %s"):format(code)
    end,
    ["{("] = function(file)
        return ([[
if not __c["%s"] then
    __c["%s"] = compile("%s")
end
__r[#__r + 1] = __c["%s"](__ctx)]]):format(file, file, file, file)
    end,
    ["{<"] = function(code)
        return ([[__r[#__r + 1] = escape(%s)]]):format(code)
    end
}

local template = setmetatable({ __c = {} }, { __index = _G })
template.__index = template

function template.escape(s, code)
    if s == nil then
        return ""
    else
        if code then
            return template.escape(s:gsub("{", "&#123;"):gsub("}", "&#125;"))
        else
            return s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
        end
    end
end

function template.compile(file)
    if (template.__c[file]) then
        return template.__c[file]
    end
    local f = assert(open(file, "r"))
    local t = f:read("*a") .. "{}"
    f:close()
    local c = {[[local __r = {}]]}
    for t, b in gmatch(t, "([^{]-)(%b{})") do
        local act = VIEW_ACTIONS[b:sub(1,2)]
        if act then
            c[#c + 1] = "__r[#__r + 1] = [[" .. t .. "]]"
            c[#c + 1] = act(b:sub(3,-3))
        elseif #b > 2 then
            c[#c + 1] = "__r[#__r + 1] = [[" .. t .. b .. "]]"
        else
            c[#c + 1] = "__r[#__r + 1] = [[" .. t .. "]]"
        end
    end
    c[#c + 1] = "return table.concat(__r)"
    c = concat(c, "\n")
    local func = function(context)
        if context then
            local tb, mt = context, getmetatable(context)
            while mt do
                tb, mt = mt, getmetatable(mt)
            end
            setmetatable(tb, { __index = template })
        else
            context = template
        end
        context.__ctx = context
        return assert(load(c, file, "t", context))()
    end
    template.__c[file] = func
    return func, c
end

function template.render(file, context)
    local func = template.compile(file)
    if (ngx) then
        return ngx.print(func(context))
    else
        return print(func(context))
    end
end

return template
