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
        return ("__r[#__r + 1] = template.escape(%s)"):format(code)
    end,
    ["{("] = function(file)
        return ([[
if not template.__c["%s"] then
    template.__c["%s"] = template.compile("%s")
end
__r[#__r + 1] = template.__c["%s"](context)]]):format(file, file, file, file)
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

function template.compile(file)
    assert(file, "file was not provided for template.compile(file).")
    file = match(file, "^()%s*$") and "" or match(file, "^%s*(.*%S)")
    if (template.__c[file]) then return template.__c[file] end
    local i = assert(open(file, "r"))
    local t = i:read("*a") .. "{}"
    i:close()
    local c = {[[local __r = {}]] }
    local codeblock = false
    for t, b in gmatch(t, "([^{]-)(%b{})") do
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
    c[#c + 1] = "return table.concat(__r)"
    c = concat(c, "\n")
    print(c)
    local f = function(context)
        local context = context or {}
        return assert(load(c, file, "t", setmetatable({ context = context, template = template }, { __index = function(t, k)
                return t.context[k] or t.template[k]
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
