local template = require "resty.template"

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local function run(iterations)
    local  print, compile, iterations = print, template.compile, iterations or 10000

    local view = [[
    <ul>
    {% for _, v in ipairs(context) do %}
        <li>{{v}}</li>
    {% end %}
    </ul>]]

    print(string.format("Running %d iterations in each test", iterations))

    local x = os.clock()
    for i = 1, iterations do
        compile(view)
        template.cache = {}
    end
    print(string.format("Compilation Time: %.4f (template)", os.clock() - x))
    collectgarbage()

    compile(view)

    local x = os.clock()
    for i = 1, iterations do
        compile(view)
    end
    print(string.format("Compilation Time: %.4f (template cached)", os.clock() - x))
    collectgarbage()

    local context = { "Emma", "James", "Nicholas", "Mary" }

    template.cache = {}

    local x = os.clock()
    for i = 1, iterations do
        compile(view)(context)
        template.cache = {}
    end
    print(string.format("  Execution Time: %.4f (same template)", os.clock() - x))
    collectgarbage()

    template.cache = {}
    compile(view)

    local x = os.clock()
    for i = 1, iterations do
        compile(view)(context)
    end
    print(string.format("  Execution Time: %.4f (same template cached)", os.clock() - x))
    collectgarbage()

    template.cache = {}

    local views = new_tab(iterations, 0)
    for i = 1, iterations do
        views[i] = "<h1>Iteration " .. i .. "</h1>\n" .. view
    end

    local x = os.clock()
    for i = 1, iterations do
        compile(views[i])(context)
    end
    print(string.format("  Execution Time: %.4f (different template)", os.clock() - x))
    collectgarbage()

    local x = os.clock()
    for i = 1, iterations do
        compile(views[i])(context)
    end
    print(string.format("  Execution Time: %.4f (different template cached)", os.clock() - x))
    collectgarbage()

    template.cache = {}
    local contexts = new_tab(iterations, 0)

    for i = 1, iterations do
        contexts[i] = {"Emma " .. i, "James " .. i, "Nicholas " .. i, "Mary " .. i }
    end

    local x = os.clock()
    for i = 1, iterations do
        compile(views[i])(contexts[i])
    end
    print(string.format("  Execution Time: %.4f (different template, different context)", os.clock() - x))
    collectgarbage()

    local x = os.clock()
    for i = 1, iterations do
        compile(views[i])(contexts[i])
    end
    print(string.format("  Execution Time: %.4f (different template, different context cached)", os.clock() - x))
    collectgarbage()
end

return {
    run = run
}