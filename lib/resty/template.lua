local setmetatable = setmetatable
local tostring = tostring
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

local caching = true
local template = { cache = {}, concat = concat }

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
    local file, location = path, ngx.var.template_location
    if file:sub(1)  == "/" then file = file:sub(2) end
    if location and location ~= "" then
        if location:sub(-1) == "/" then location = location:sub(1, -2) end
        local res = ngx.location.capture(location .. '/' .. file)
        if res.status == 200 then return res.body end
    end
    local root = ngx.var.template_root or ngx.var.document_root
    if root:sub(-1) == "/" then root = root:sub(1, -2) end
    return read_file(root .. "/" .. file) or path
end

if ngx then
    template.print = ngx.print or print
    template.load  = load_ngx
else
    template.print = print
    template.load  = load_lua
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
    if type(s) == "string" then
        if c then s = s:gsub("[}{]", CODE_ENTITIES) end
        return s:gsub("[\">/<'&]", HTML_ENTITIES)
    end
    return template.output(s)
end

function template.new(view, layout)
    assert(view, "view was not provided for template.new(view, layout).")
    local render = template.render
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
    local chunk = string.dump(template.compile(view), true)
    if path then
        local file = io.open(path, "wb")
        file:write(chunk)
        file:close()
    end
    return chunk
end

function template.compile(view, key)
    assert(view, "view was not provided for template.compile(view).")
    key = key or view
    local cache = template.cache
    if cache[key] then return cache[key] end
    local func = assert(load(template.parse(view), nil, "tb", context))
    if caching then cache[key] = func end
    return func
end

function template.parse(view)
    assert(view, "view was not provided for template.parse(view).")
    view = template.load(view)
    if view:sub(1, 1):byte() == 27 then return view end
    local c = {
        "context=... or {}",
        "local ___={}"
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
                c[#c+1] = '___[#___+1]=template.compile([=[' .. view:sub(e + 2, x - 1) .. ']=])(context)'
                i, j = y, y + 1
            end
        end
        i = i + 1
        s, e = view:find("{", i, true)
    end
    c[#c+1] = "___[#___+1]=[=[" .. view:sub(j) .. "]=]"
    c[#c+1] = "return template.concat(___)"
    return concat(c, "\n")
end

function template.render(view, context, key)
    assert(view, "view was not provided for template.render(view, context, key).")
    return template.print(template.compile(view, key)(context))
end

return template
