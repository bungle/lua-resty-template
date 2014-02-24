local assert = assert
local setmetatable = setmetatable
local match = string.match
local gmatch = string.gmatch
local load = load
local concat = table.concat
local open = io.open
local echo = print

if ngx then echo = ngx.print end

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
        return { render = function(self, context)
            self.view = template.compile(view)(context or self)
            template.render(layout, context or self)
        end }
    else
        return { render = function(self, context)
            template.render(view, context or self)
        end }
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
        return assert(load(c, file, "t", setmetatable({ self = context }, { __index = function(_, k)
                return context[k] or template[k]
            end
        })))()
    end
    template.__c[file] = f
    return f
end

function template.render(file, context)
    assert(file, "file was not provided for template.render(file, context).")
    echo(template.compile(file)(context))
end

return template
