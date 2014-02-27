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
    local render, compile = template.render, template.compile
    if layout then
        return setmetatable({ render = function(self, context)
            local context = context or self
            self.view = compile(view)(context)
            render(layout, context)
        end }, { __tostring = function(self)
            local context = context or self
            self.view = compile(view)(context)
            return compile(layout)(context)
        end
        })
    else
        return setmetatable({ render = function(self, context)
            render(view, context or self)
        end }, { __tostring = function(self)
            return compile(view)(context or self)
        end
        })
    end
end

function template.compile(view)
    assert(view, "view was not provided for template.compile(view).")
    local cache = template.cache
    if not cache[view] then
        local parsed = template.parse(view)
        cache[view] = function(context)
            local context = context or {}
            return assert(load(parsed, view, "t", setmetatable({
               template = template,
                context = context,
                    __c = concat
            }, {
                __index = function(_, k)
                    return context[k] or template[k] or _G[k]
                end
            })))()
        end
    end
    return cache[view]
end

function template.parse(view)
    assert(view, "view was not provided for template.parse(view).")
    local file = open(view, "r")
    if file then
        view = file:read("*a")
        file:close()
    end
    local matches, cb = gmatch(view .. "{}", "([^{]-)(%b{})"), false
    local c = {[[local __r = {}]]}
    for t, b in matches do
        local act = VIEW_ACTIONS[b:sub(1, 2)]
        local len = #t
        local slf = len > 0 and "\n" == t:sub(1, 1)
        local elf = len > 0 and "\n" == t:sub(-1, 1)
        if act then
            if slf then
                if not cb then
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
            if not cb then
                if elf and not slf then
                    c[#c + 1] = [[__r[#__r + 1] = "\n"]]
                end
            end
            cb = b:sub(1, 2) == "{%"
        elseif #b > 2 then
            c[#c + 1] = "__r[#__r + 1] = [[" .. t .. b .. "]]"
            cb = false
        else
            if not cb then
                if slf or elf then
                    c[#c + 1] = [[__r[#__r + 1] = "\n"]]
                end
            end
            if len > 0 then
                c[#c + 1] = "__r[#__r + 1] = [[" .. t .. "]]"
            end
            cb = false
        end
    end
    c[#c + 1] = "return __c(__r)"
    return concat(c, "\n")
end

function template.render(view, context)
    assert(view, "view was not provided for template.render(view, context).")
    echo(template.compile(view)(context))
end

return template
