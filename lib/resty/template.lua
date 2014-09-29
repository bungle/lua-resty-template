local setmetatable = setmetatable
local tostring = tostring
local setfenv = setfenv
local concat = table.concat
local assert = assert
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

local caching, ngx_var, ngx_capture, ngx_null = true
local template = { _VERSION = "1.2", cache = {}, concat = concat }

local function read_file(path)
    local file = open(path, "rb")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

local function load_lua(path)
    return read_file(path) or path
end

local function load_ngx(path)
    local file, location = path, ngx_var.template_location
    if file:sub(1)  == "/" then file = file:sub(2) end
    if location and location ~= "" then
        if location:sub(-1) == "/" then location = location:sub(1, -2) end
        local res = ngx_capture(location .. '/' .. file)
        if res.status == 200 then return res.body end
    end
    local root = ngx_var.template_root or ngx_var.document_root
    if root:sub(-1) == "/" then root = root:sub(1, -2) end
    return read_file(root .. "/" .. file) or path
end

if ngx then
    template.print = ngx.print or print
    template.load  = load_ngx
    ngx_var, ngx_capture, ngx_null = ngx.var, ngx.location.capture, ngx.null
else
    template.print = print
    template.load  = load_lua
end

local load_chunk

if _VERSION == "Lua 5.1" then
    local context = { __index = function(t, k)
        return t.context[k] or t.template[k] or _G[k]
    end }
    if jit then
        load_chunk = function(view)
            return assert(load(view, nil, "tb", setmetatable({ template = template }, context)))
        end
    else
        load_chunk = function(view)
            local func = assert(loadstring(view))
            setfenv(func, setmetatable({ template = template }, context))
            return func
        end
    end
else
    local context = { __index = function(t, k)
        return t.context[k] or t.template[k] or _ENV[k]
    end }
    load_chunk = function(view)
        return assert(load(view, nil, "tb", setmetatable({ template = template }, context)))
    end
end

function template.caching(enable)
    if enable ~= nil then caching = enable == true end
    return caching
end

function template.output(s)
    if s == nil or s == ngx_null then return "" end
    if type(s) == "function" then return template.output(s()) end
    return tostring(s)
end

function template.escape(s, c)
    if type(s) == "string" then
        if c then s = s:gsub("[}{]", CODE_ENTITIES) end
        return s:gsub("[\">/<'&]", HTML_ENTITIES)
    end
    return template.output(s)
end

function template.new(view, layout)
    assert(view, "view was not provided for template.new(view, layout).")
    local render, compile = template.render, template.compile
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

function template.precompile(view, path, strip)
    local chunk = string.dump(template.compile(view), strip ~= false)
    if path then
        local file = io.open(path, "wb")
        file:write(chunk)
        file:close()
    end
    return chunk
end

function template.compile(view, key, plain)
    assert(view, "view was not provided for template.compile(view, key, plain).")
    if key == "no-cache" then
        return load_chunk(template.parse(view, plain)), false
    end
    key = key or view
    local cache = template.cache
    if cache[key] then return cache[key], true end
    local func = load_chunk(template.parse(view, plain))
    if caching then cache[key] = func end
    return func, false
end

function template.parse(view, plain)
    assert(view, "view was not provided for template.parse(view, plain).")
    if not plain then
        view = template.load(view)
        if view:sub(1, 1):byte() == 27 then return view end
    end
    local c = {
        "context=... or {}",
        "local ___,blocks,layout={},blocks or {}"
    }
    local i, j, s, e = 0, 0, view:find("{", 1, true)
    while s do
        local t = view:sub(s, e + 1)
        if t == "{{" then
            local x, y = view:find("}}", e + 2, true)
            if x then
                if j ~= s then c[#c+1] = "___[#___+1]=[=[" .. view:sub(j, s - 1) .. "]=]" end
                c[#c+1] = "___[#___+1]=template.escape(" .. view:sub(e + 2, x - 1) .. ")"
                i, j = y, y + 1
            end
        elseif t == "{*" then
            local x, y = view:find("*}", e + 2, true)
            if x then
                if j ~= s then c[#c+1] = "___[#___+1]=[=[" .. view:sub(j, s - 1) .. "]=]" end
                c[#c+1] = "___[#___+1]=template.output(" .. view:sub(e + 2, x - 1) .. ")"
                i, j = y, y + 1
            end
        elseif t == "{%" then
            local x, y = view:find("%}", e + 2, true)
            if x then
                if j ~= s then c[#c+1] = "___[#___+1]=[=[" .. view:sub(j, s - 1) .. "]=]" end
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
                if j ~= s then c[#c+1] = "___[#___+1]=[=[" .. view:sub(j, s - 1) .. "]=]" end
                local file = view:sub(e + 2, x - 1)
                local a, b = file:find(',', 2, true)
                if a then
                    c[#c+1] = '___[#___+1]=template.compile([=[' .. file:sub(1, a - 1) .. ']=])(' .. file:sub(b + 1) .. ')'
                else
                    c[#c+1] = '___[#___+1]=template.compile([=[' .. file .. ']=])(context)'
                end
                i, j = y, y + 1
            end
        elseif t == "{-" then
            local x, y = view:find("-}", e + 2, true)
            if x then
                local a, b = view:find(view:sub(e, y), y, true)
                if a then
                    if j ~= s then c[#c+1] = "___[#___+1]=[=[" .. view:sub(j, s - 1) .. "]=]" end
                    c[#c+1] = 'blocks["' .. view:sub(e + 2, x - 1) .. '"]=template.compile([=[' .. view:sub(y + 1, a - 1) .. ']=], "no-cache", true)(context)'
                    i, j = b, b + 1
                end
            end
        elseif t == "{#" then
            local x, y = view:find("#}", e + 2, true)
            if x then
                if j ~= s then c[#c+1] = "___[#___+1]=[=[" .. view:sub(j, s - 1) .. "]=]" end
                i, j = y, y + 1
            end
        end
        i = i + 1
        s, e = view:find("{", i, true)
    end
    c[#c+1] = "___[#___+1]=[=[" .. view:sub(j) .. "]=]"
    c[#c+1] = "if not layout then return template.concat(___) end"
    c[#c+1] = "if next(blocks) then return template.compile(layout)(setmetatable({view=template.concat(___),blocks=blocks},{__index=context})) end"
    c[#c+1] = "return template.compile(layout)(context)"
    return concat(c, "\n")
end

function template.render(view, context, key, plain)
    assert(view, "view was not provided for template.render(view, context, key, plain).")
    return template.print(template.compile(view, key, plain)(context))
end

return template
