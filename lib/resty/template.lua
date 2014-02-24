local assert = assert
local setmetatable = setmetatable
local getmetatable = getmetatable
local match = string.match
local gmatch = string.gmatch
local load = load
local concat = table.concat
local open = io.open
local echo = print

if ngx then echo = ngx.print end

local function setcontext(context, index)
    if not context then return index end
    local i, nm, tb, mt = 1, true, context, getmetatable(context)
    while mt do
        assert(i < 11, "context table metatables are too deeply nested.")
        if mt.__index then
            if mt.__index == index then
                nm = false
                break
            end
        else
            mt.__index = mt
        end
        i, tb, mt = i + 1, mt, getmetatable(mt)
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
    ["{*"] = function(code)
        return ("__r[#__r + 1] = %s"):format(code)
    end,
    ["{{"] = function(code)
        return ([[__r[#__r + 1] = escape(%s)]]):format(code)
    end,
    ["{("] = function(file)
        return ([[
if not __c["%s"] then
    __c["%s"] = compile("%s")
end
__r[#__r + 1] = __c["%s"](self)]]):format(file, file, file, file)
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

function template.new(view, layout)
    assert(view, "file was not provided for template.new(file).")
    if layout then
        return setcontext({ render = function(self, context)
            local ctx = setcontext(context, self)
            ctx.view = template.compile(view)(ctx)
            template.render(layout, ctx)
        end }, template)
    else
        return setcontext({ render = function(self, context)
            template.render(view, setcontext(context, self))
        end }, template)
    end
end

function template.compile(file)
    assert(file, "file was not provided for template.compile(file).")
    file = match(file, "^()%s*$") and "" or match(file, "^%s*(.*%S)")
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
    return f
end

function template.render(file, context)
    assert(file, "file was not provided for template.render(file, context).")
    echo(template.compile(file)(context))
end

return template
