local setmetatable = setmetatable
local tostring = tostring
local concat = table.concat
local assert = assert
local rename = os.rename
local open = io.open
local load = load
local type = type

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

local caching = true
local template = { cache = {}, concat = concat }

if ngx then
    template.print = ngx.print or print
else
    template.print = print
end

local context = setmetatable({ context = {}, template = template }, {
    __index = function(t, k)
        return t.context[k] or t.template[k] or _G[k]
    end
})

function template.caching(enable)
    if enable ~= nil then caching = enable == true end
    return caching
end

function template.output(s)
    if s == nil then return "" end
    local t = type(s)
    if t == "function" then return template.output(s()) end
    if t == "table"    then return tostring(s)          end
    return s
end

function template.escape(s, c)
    if s == nil then return "" end
    local t = type(s)
    if t == "string" and #t > 0 then
        if c then return template.escape(s:gsub("[}{]", CODE_ENTITIES)) end
        return s:gsub("[\">/<'&]", HTML_ENTITIES)
    end
    if t == "function" then return template.output(s()) end
    if t == "table"    then return tostring(s)          end
    return s
end

function template.new(view, layout, precompiled)
    assert(view, "view was not provided for template.new(view, layout, precompiled).")
    local render = template.render
    if precompiled then
        local load = template.load
        if layout then
            return setmetatable({ render = function(self, context)
                local context = context or self
                context.view = load(view)(context)
                render(layout, context, true)
            end }, { __tostring = function(self)
                local context = context or self
                context.view = load(view)(context)
                return load(layout)(context)
            end })
        end
        return setmetatable({ render = function(self, context)
            render(view, context or self, true)
        end }, { __tostring = function(self)
            return load(view)(context or self)
        end })
    end
    local compile = template.compile
    if layout then
        return setmetatable({ render = function(self, context)
            local context = context or self
            context.view = compile(view)(context)
            render(layout, context)
        end }, { __tostring = function(self)
            local context = context or self
            context.view = compile(view)(context)
            return compile(layout)(context)
        end })
    end
    return setmetatable({ render = function(self, context)
        render(view, context or self)
    end }, { __tostring = function(self)
        return compile(view)(context or self)
    end })
end

function template.precompile(view, path)
    local chunk = string.dump(assert(load(template.parse(view, true), view, "t", context)))
    if path then
        local file = io.open(path, "wb")
        file:write(chunk)
        file:close()
    end
    return chunk
end

function template.load(view)
    local cache = template.cache
    if cache[view] then return cache[view] end
    local func
    if rename(view, view) then
        func = assert(loadfile(view, "b", context))
    else
        func = assert(load(view, nil, "b", context))
    end
    if caching then cache[view] = func end
    return func
end

function template.compile(view)
    assert(view, "view was not provided for template.compile(view).")
    local cache = template.cache
    if cache[view] then return cache[view] end
    local func = assert(load(template.parse(view), view, "t", context))
    if caching then cache[view] = func end
    return func
end

function template.parse(view, precompile)
    assert(view, "view was not provided for template.parse(view, precompiled).")
    local file = open(view, "r")
    if file then
        view = file:read("*a")
        file:close()
    end
    local c = {
        "context = ... or {}",
        "local __r = {}"
    }
    local i, j, s, e = 0, 0, view:find("{", 1, true)
    while s do
        local t = view:sub(s, e + 1)
        if t == "{{" then
            local x, y = view:find("}}", e + 2, true)
            if x then
                if j ~= s then c[#c+1] = concat({"__r[#__r+1] = [=[", view:sub(j, s - 1), "]=]"}) end
                c[#c+1] = concat({"__r[#__r+1] = template.escape(", view:sub(e + 2, x - 1) ,")"})
                i, j = y, y + 1
            end
        elseif t == "{*" then
            local x, y = view:find("*}", e + 2, true)
            if x then
                if j ~= s then c[#c+1] = concat({"__r[#__r+1] = [=[", view:sub(j, s - 1), "]=]"}) end
                c[#c+1] = concat({"__r[#__r+1] = template.output(", view:sub(e + 2, x - 1), ")"})
                i, j = y, y + 1
            end
        elseif t == "{%" then
            local x, y = view:find("%}", e + 2, true)
            if x then
                if j ~= s then c[#c+1] = concat({"__r[#__r+1] = [=[", view:sub(j, s - 1), "]=]"}) end
                c[#c+1] = view:sub(e + 2, x - 1)
                if view:sub(y + 1, y + 1) == "\n" then
                    i, j = y + 1, y + 2
                else
                    i, j = y, y + 1
                end
            end
        elseif t == "{(" then
            local x, y = view:find(")}", e + 2, true)
            if x then
                if j ~= s then c[#c+1] = concat({"__r[#__r+1] = [=[", view:sub(j, s - 1), "]=]"}) end
                if precompile then
                    c[#c+1] = concat({'__r[#__r+1] = template.load("', view:sub(e + 2, x - 1), '")(context)'})
                else
                    c[#c+1] = concat({'__r[#__r+1] = template.compile("', view:sub(e + 2, x - 1), '")(context)'})
                end
                i, j = y, y + 1
            end
        end
        i = i + 1
        s, e = view:find("{", i, true)
    end
    c[#c+1] = concat({"__r[#__r+1] = [=[", view:sub(j), "]=]"})
    c[#c+1] = "return template.concat(__r)"
    return concat(c, "\n")
end

function template.render(view, context, precompiled)
    assert(view, "view was not provided for template.render(view, context, precompiled).")
    if precompiled then return template.print(template.load(view)(context)) end
    return template.print(template.compile(view)(context))
end

return template
