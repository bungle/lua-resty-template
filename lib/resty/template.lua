local VIEW_ACTIONS = {
    ["{%"] = function(code)
        return code
    end,
    ["{{"] = function(code)
        return ("__r[#__r + 1] = %s"):format(code)
    end,
    ["{("] = function(file)
        return ([[
if not self.__c["%s"] then
    self.__c["%s"] = compile(self, "%s")
end
__r[#__r + 1] = self.__c["%s"]()]]):format(file, file, file, file)
    end,
    ["{<"] = function(code)
        return ([[__r[#__r + 1] = escape(%s)]]):format(code)
    end,
}

local template = setmetatable({ __c = {} }, { __index = _G })
template.__index = template

function template.new(file)
    local self = setmetatable({ file = file }, template)
    self.self = self
    return self
end

function template.escape(s)
    if s == nil then
        return ""
    else
        return s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    end
end

function template.tescape(s)
    if s == nil then
        return ""
    else
        return escape(s:gsub("{", "&#123;"):gsub("}", "&#125;"))
    end
end

function template:compile(file)
    file = file or self.file
    if (template.__c[file]) then
        return template.__c[file]
    end
    local f = assert(io.open(file, "r"))
    local t = f:read("*a") .. "{}"
    f:close()
    local c = {[[local __r = {}]]}
    for t, b in string.gmatch(t, "([^{]-)(%b{})") do
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
    c = table.concat(c, "\n")
    local func = assert(load(c, file, "t", self))
    template.__c[file] = func
    return func, c

end

function template:render()
    local func = self:compile()
    if (ngx) then
        return ngx.print(func())
    else
        return print(func())
    end
end

return template
