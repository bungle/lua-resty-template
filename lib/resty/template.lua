local assert = assert
local setmetatable = setmetatable
local getmetatable = getmetatable
local gmatch = string.gmatch
local load = load
local concat = table.concat
local open = io.open
local echo = print

if ngx then echo = ngx.print end

local function setcontext(context, index)
    if not context then return index end
    local nm, tb, mt = true, context, getmetatable(context)
    while mt do
        if mt.__index == index then
            nm = false
            break
        end
        tb, mt = mt, getmetatable(mt)
    end
    if nm then
        setmetatable(tb, { __index = index })
        context.self = context
    end
    return context
end

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
__r[#__r + 1] = __c["%s"](self)]]):format(file, file, file, file)
    end,
    ["{<"] = function(code)
        return ([[__r[#__r + 1] = escape(%s)]]):format(code)
    end
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

local template = setmetatable({ __c = {} }, { __index = _G })

function template.escape(s, code)
    if s == nil then
        return ""
    else
        if code then
            return template.escape(s:gsub([=[[}{]]=], CODE_ENTITIES))
        else
            return s:gsub([=[[">/<'&]]=], HTML_ENTITIES)
        end
    end
end

function template.new(file)
    assert(file, "file was not provided for template.new(file).")
    return setmetatable({ render = function(self, context)
        template.render(file, setcontext(context, self))
    end }, { __index = template })
end

function template.compile(file)
    assert(file, "file was not provided for template.compile(file).")
    if (template.__c[file]) then return template.__c[file] end
    local i = assert(open(file, "r"))
    local t = i:read("*a") .. "{}"
    i:close()
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
    local f = function(context)
        return assert(load(c, file, "t", setcontext(context, template)))()
    end
    template.__c[file] = f
    return f, c
end

function template.render(file, context)
    assert(file, "file was not provided for template.render(file, context).")
    echo(template.compile(file)(context))
end

return template
