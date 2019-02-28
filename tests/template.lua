#!/usr/bin/env tarantool

local tap = require('tap')
local template = require('resty.template')

local test = tap.test('Template engine tests')

local function test_render(test)
    test:plan(2)
    local result
    local template_print = template.print
    template.print = function(text) result = text end
    local expected = [[<!DOCTYPE html>
<html>
<body>
  <h1>Hello, World!</h1>
</body>
</html>
]]

    local view = template.new("./tests/view.html")
    view.message = "Hello, World!"
    view:render()
    test:is(result, expected, "template.new() -> view:render()")

    result = nil
    template.render("./tests/view.html", { message = "Hello, World!" })
    test:is(result, expected, "template.render")
    template.print = template_print
end

local function test_compile(test)
    test:plan(1)
    local test_template = [[<ul>
{% for _, person in ipairs(context) do %}
    {*html.li(person.name)*}
{% end %}
</ul>
<table>
{% for _, person in ipairs(context) do %}
    <tr data-sort="{{(person.name or ""):lower()}}">
        {*html.td{ id = person.id }(person.name)*}
    </tr>
{% end %}
</table>
]]
    local test_data = {
        { id = 1, name = "Emma"},
        { id = 2, name = "James" },
        { id = 3, name = "Nicholas" },
        { id = 4 }
    }

    local expected = [[<ul>
    <li>Emma</li>
    <li>James</li>
    <li>Nicholas</li>
    <li />
</ul>
<table>
    <tr data-sort="emma">
        <td id="1">Emma</td>
    </tr>
    <tr data-sort="james">
        <td id="2">James</td>
    </tr>
    <tr data-sort="nicholas">
        <td id="3">Nicholas</td>
    </tr>
    <tr data-sort="">
        <td id="4" />
    </tr>
</table>
]]
    local result = template.compile(test_template)(test_data)
    test:is(result, expected, 'template.compile')
end

local function test_precompile(test)
    test:plan(2)
    local result
    local template_print = template.print
    template.print = function(text) result = text end
    local view = [[
<h1>{{title}}</h1>
<ul>
{% for _, v in ipairs(context) do %}
    <li>{{v}}</li>
{% end %}
</ul>
]]
    local expected = [[
<h1>Names</h1>
<ul>
    <li>Emma</li>
    <li>James</li>
    <li>Nicholas</li>
    <li>Mary</li>
</ul>
]]
    local compiled = template.precompile(view)
    test:isnt(compiled, nil, 'Successful pre-compilation')
    template.render(compiled, {
        title = "Names",
        "Emma", "James", "Nicholas", "Mary"
    })

    test:is(result, expected, 'Precompiled string')
    template.print = template_print
end


test:plan(3)
test:test('template.render', test_render)
test:test('template.compile', test_compile)
test:test('template.precompile', test_precompile)

os.exit(test:check() and 0 or 1)
