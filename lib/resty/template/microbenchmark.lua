local template = require "resty.template"

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local function run()
    local view = [[
    <ul>
    {% for _, v in ipairs(context) do %}
        <li>{{v}}</li>
    {% end %}
    </ul>
    </table>]]

    print("10.000 Iterations in Each Test")

    local x = os.clock()
    for i = 1, 10000 do
        template.compile(view)
        template.cache = {}
    end
    print(string.format("Compilation Time: %.2f (no template cache)", os.clock() - x))

    template.compile(view)

    local x = os.clock()
    for i = 1, 10000 do
        template.compile(view)
    end
    print(string.format("Compilation Time: %.2f (with template cache)", os.clock() - x))

    local context = { "Emma", "James", "Nicholas", "Mary" }

    template.cache = {}

    local x = os.clock()
    for i = 1, 10000 do
        template.compile(view)(context)
        template.cache = {}
    end
    print(string.format("  Execution Time: %.2f (same template)", os.clock() - x))

    template.cache = {}

    template.compile(view)

    local x = os.clock()
    for i = 1, 10000 do
        template.compile(view)(context)
    end
    print(string.format("  Execution Time: %.2f (same template cached)", os.clock() - x))

    template.cache = {}

    local views = new_tab(10000, 0)
    for i = 1, 10000 do
        views[i] = "<h1>Iteration " .. i .. "</h1>\n" .. view
    end

    local x = os.clock()
    for i = 1, 10000 do
        template.compile(views[i])(context)
    end
    print(string.format("  Execution Time: %.2f (different template)", os.clock() - x))

    local x = os.clock()
    for i = 1, 10000 do
        template.compile(views[i])(context)
    end
    print(string.format("  Execution Time: %.2f (different template cached)", os.clock() - x))

    template.cache = {}
    local contexts = new_tab(10000, 0)

    for i = 1, 10000 do
        contexts[i] = {"Emma " .. i, "James " .. i, "Nicholas " .. i, "Mary " .. i }
    end

    local x = os.clock()
    for i = 1, 10000 do
        template.compile(views[i])(contexts[i])
    end
    print(string.format("  Execution Time: %.2f (different template, different context)", os.clock() - x))

    local x = os.clock()
    for i = 1, 10000 do
        template.compile(views[i])(contexts[i])
    end
    print(string.format("  Execution Time: %.2f (different template, different context cached)", os.clock() - x))
end

return {
    run = run
}