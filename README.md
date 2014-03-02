# lua-resty-template

**lua-resty-template** is a compiling templating engine for OpenResty and Lua.

## Hello World with lua-resty-template

```lua
local template = require "resty.template"
-- Using template.new
local view = template.new("view.html")
view.message  = "Hello, World!"
view.render()
-- Using template.render
template.render("view.html", { message = "Hello, World!" })
-- Using template string
template.render([[
<!DOCTYPE html>
<html>
<body>
  <h1>{{message}}</h1>
</body>
</html>]],  { message = "Hello, World!" })
```

##### view.html
```html
<!DOCTYPE html>
<html>
<body>
  <h1>{{message}}</h1>
</body>
</html>
```

##### Output
```html
<!DOCTYPE html>
<html>
<body>
  <h1>Hello, World!</h1>
</body>
</html>
```

## Template Syntax

You may use the following tags in templates:

* `{{expression}}`, writes result of expression - html escaped
* `{*expression*}`, writes result of expression 
* `{% lua code %}`, executes Lua code
* `{(template)}`, includes `template` file

From templates you may access everything in `context` table, and everything in `template` table. In templates you can also access `context` and `template` by prefixing keys.

**If you precompile your templates, the inclusion `{(file)}` expects that all the included templates are precompiled too. So you cannot mix and match text and binary templates with this.**


```html
<h1>{{message}}</h1> == <h1>{{context.message}}</h1>
```

##### A Word About HTML Escaping

Only strings are escaped, functions are called (recursively) and results are returned as is, tables are `tostring`ified and other types are simply just returned. `nil`s are converted to `""`.

#### Example
##### Lua
```lua
local template = require "resty.template"
template.render("view.html", {
  title   = "Testing lua-resty-template",
  message = "Hello, World!"
  names   = { "James", "Jack", "Anne" },
  jquery  = '<script src="//ajax.googleapis.com/ajax/libs/jquery/2.1.0/jquery.min.js"></script>' 
})
```

##### view.html
```html
{(header.html)}
<h1>{{message}}</h1>
<ul>
{% for _, name in ipairs(names) do %}
    <li>{{name}}</li>
{% end %}
</ul>
{(footer.html)}
```

##### header.html
```html
<!DOCTYPE html>
<html>
<head>
  <title>{{title}}</title>
  {*jquery*}
</head>
<body>
```

##### footer.html
```html
</body>
</html>
```

#### Reserved Context Keys and Remarks

It is adviced that you do not use these keys in your context tables:

* `__r`, holds the compiled template, if set you need to use `{{context.__r}}`
* `context`, holds the current context, if set you need to use `{{context.context}}`
* `template`, holds the template table, if set you need to use `{{context.template}}` (used in escaping, and compiling child templates)

In addition to that with `template.new` you should not overwrite:

* `render`, the function that renders a view, obviously ;-)

You should also not `{(view.html)}` recursively

##### Lua
```lua
template.render("view.html")
```

##### view.html
```html
{(view.html)}
```

**Also note that you can provide template either as a file path or as a string. If the file exists, it will be used, otherwise the string is used.**

## Lua API

#### boolean template.caching(boolean or nil)

This function enables or disables template caching, or if no parameters are passed, returns current state of template caching. By default template caching is enabled, but you may want to disable it on development or low-memory situations.

```lua
local template = require "resty.template"   
-- Get current state of template caching
local enabled = template.caching()
-- Disable template caching
template.caching(false)
-- Enable template caching
template.caching(true)
```

Please note that if the template was already cached when compiling a template or loading a precompiled template, the cached version will be returned. You may want to flush cache with `template.cache = {}` to ensure that your template really gets recompiled or loaded.

#### table template.new(view, layout, precompiled)

Creates a new template instance that is used as a context when `render`ed. If you have precompiled your `view` (and `layout`), please set `precompiled` to `true`.

```lua
local view = template.new("template.html")            -- or
local view = template.new("view.html", "layout.html") -- or
local view = template.new([[<h1>{{message}}</h1>]])   -- or
local view = template.new([[<h1>{{message}}</h1>]], [[
<html>
<body>
  {*view*}
</body>
</html>
]])
```

##### Example
```lua
local template = require "resty.template"
local view = template.new("view.html")
view.message  = "Hello, World!"
view.render()
-- You may also replace context on render
view.render({ title = "Testing lua-resty-template" })
-- If you want to include view context in  replacement context
view.render(setmetatable({ title = "Testing lua-resty-template" }, { __index = view }))
-- To get rendered template as a string, you can use tostring
local result = tostring(view)
```

#### function template.compile(view)

Parses, compiles and caches (if caching is enabled) a template and returns the compiled template as a function that takes context as a parameter and returns rendered template as a string.

```lua
local func = template.compile("template.html")          -- or
local func = template.compile([[<h1>{{message}}</h1>]])
```

##### Example
```lua
local template = require "resty.template"
local func     = template.compile("view.html")
local world    = func{ message = "Hello, World!" }
local universe = func{ message = "Hello, Universe!" }
print(world, universe)
```

#### template.render(view, context, precompiled)

Parses, compiles, caches (if caching is enabled) and outputs template either with `ngx.print` if available, or `print`. If you have precompiled your view, please set `precompiled` to `true`.

```lua
template.render("template.html", { message = "Hello, World!" })          -- or
template.render([[<h1>{{message}}</h1>]], { message = "Hello, World!" })
```

##### Example
```lua
local template = require "resty.template"
template.render("view.html", { message = "Hello, World!" })
template.render("view.html", { message = "Hello, Universe!" })
```

#### string template.parse(view, precompile)

Parses template file or string, and generates a parsed template string. This may come useful when debugging templates. `precompile` parameter is optional, and it affects only on `{(file)}` tag rendering (`template.compile("%s")(context)` or `template.load("%s")(context)`).

```lua
local t1 = template.parse("template.html")
local t2 = template.parse([[<h1>{{message}}</h1>]])
```

#### string template.precompile(view, path)

Precompiles template as a binary chunk. This binary chunk can be written out as a file, or used directly with `template.load`. For convenience you may optionally specify `path` argument to output binary chunk to file.

```lua
local view = [[
<h1>{{title}}</h1>
<ul>
{% for _, v in ipairs(context) do %}
    <li>{{v}}</li>
{% end %}
</ul>]]

local compiled = template.precompile(view)

local file = io.open("precompiled-bin.html", "wb")
file:write(t)
file:close()

-- Alternatively you could just write (which does the same thing as above)
template.precompile(view, "precompiled-bin.html")

template.render("precompiled-bin.html", {
    title = "Names",
    "Emma", "James", "Nicholas", "Mary"
  }, true)
```

#### function template.load(view)

Loads precompiled chunk either from file or string (`view`). Binary chunks can be obtained with `template.precompile`.

```lua
local compiled = template.precompile([[
<h1>{{title}}</h1>
<ul>
{% for _, v in ipairs(context) do %}
    <li>{{v}}</li>
{% end %}
</ul>]])

local f = template.load(compiled)
local r = f({ title = "Names", "Emma", "James", "Nicholas", "Mary" })
```

#### function template.print

This field contains a function that is used on `template.render()` or `template.new("example.html").render()` to output the results. By default this holds either `ngx.print` (if available) or `print`. You may want to (and are allowed to) overwrite this field, if you want to use your own output function instead. This is also useful if you are using some other framework, e.g. Turbo.lua (http://turbolua.org/).

```lua
local template = require "resty.template"

template.print = function(s)
  print(s)
  print("<!-- Output by My Functions -->")
end
```

## Template Precompilation

`lua-resty-template` supports template precompilation. This can be useful when you want to skip template parsing (and Lua interpretation) in production or if you do not want your templates distributed as plain text files on production servers. Also by precompiling, you can ensure that your templates do not contain something, that cannot be compiled (they are syntactically valid Lua). Although templates are cached (even without precompilation), there are some perfomance (and memory) gains. You could integrate template precompilation in your build (or deployment) scripts (maybe as Gulp, Grunt or Ant tasks).

##### Precompiling template, and output it as a binary file

```lua
local template = require "resty.template"
local compiled = template.precompile("example.html")
local file = io.open("example-bin.html", "w")
file:write(t)
file:close()
```

##### Load precompiled template file, and run it with context parameters

```lua
local template = require "resty.template"
template.render("example-bin.html", { "Jack", "Mary" }, true)
```

The last parameter in `template.render` denotes that the template (`example-bin.html` in this case) is a precompiled binary chunk.

## Template Helpers

While `lua-resty-template` does not have much infrastucture or ways to extend it, you still have a few possibilities that you may try.

* Adding methods to global `string`, and `table` types (not encouraged, though)
* Wrap your values with something before adding them in context
* Create global functions
* Add local functions either to `template` table or `context` table
* Use metamethods in your tables

While modifying global types seems convenient, it can have nasty side effects. That's why I suggest you to look at these libraries, and articles first:

* Method Chaining Wrapper (http://lua-users.org/wiki/MethodChainingWrapper)
* Moses (https://github.com/Yonaba/Moses)
* underscore-lua (https://github.com/jtarchie/underscore-lua)

You could for example add Moses' or Underscore's `_` to template table or context table.

##### Example

```lua
local _ = require "moses"
local template = require "resty.template"
template._ = _
```

Then you can use `_` inside your templates. I created one example template helper that can be found from here:
https://github.com/bungle/lua-resty-template/blob/master/lib/resty/template/html.lua

##### Lua

```lua
local template = require "resty.template"
local html = require "resty.template.html"

template.render([[
<ul>
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
</table>]], {
    { id = 1, name = "Emma"},
    { id = 2, name = "James" },
    { id = 3, name = "Nicholas" },
    { id = 4 }
})
```

##### Output

```html
<ul>
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
```

## Usage Examples

### Views with Layouts

Layouts (or Master Pages) can be used to wrap a view inside another view (aka layout).

##### Lua
```lua
local template = require "resty.template"
local layout   = template.new("layout.html")
layout.title   = "Testing lua-resty-template"
layout.view    = template.compile("view.html"){ message = "Hello, World!" }
layout:render()
-- Or like this
template.render("layout.html", {
  title = "Testing lua-resty-template",
  view  = template.compile("view.html"){ message = "Hello, World!" }
})
-- Or maybe you like this style more (but please remember that view.view is overwritten on render)
local view     = template.new("view.html", "layout.html")
view.title     = "Testing lua-resty-template"
view.message   = "Hello, World!"
view:render()
```

##### layout.html
```html
<!DOCTYPE html>
<html>
<head>
    <title>{{title}}</title>
</head>
<body>
    {*view*}
</body>
</html>
```

##### view.html
```html
<h1>{{message}}</h1>
```

### Calling Methods in Templates

You can call string methods (or other table functions) in templates too.

##### Lua
```lua
local template = require "resty.template"
template.render([[
<h1>{{header:upper()}}</h1>
]], { header = "hello, world!" })
```

##### Output
```html
<h1>HELLO, WORLD!</h1>
```

## FAQ

### How Do I Clear the Template Cache

`lua-resty-template` automatically caches (if caching is enabled) the resulting template functions in `template.cache` table. You can clear the cache by issuing `template.cache = {}`.

## Alternatives

You may also look at these:

* etlua (https://github.com/leafo/etlua)
* lustache (https://github.com/Olivine-Labs/lustache)
* lust (https://github.com/weshoke/Lust)
* templet (http://colberg.org/lua-templet/)
* luahtml (https://github.com/TheLinx/LuaHTML)
* mixlua (https://github.com/LuaDist/mixlua)
* tirtemplate (https://github.com/torhve/LuaWeb/blob/master/tirtemplate.lua)
* cosmo (http://cosmo.luaforge.net/)
* lua-codegen (http://fperrad.github.io/lua-CodeGen/)

`lua-resty-template` *was originally forked from Tor Hveem's* `tirtemplate.lua` *that he had extracted from Zed Shaw's Tir web framework (http://tir.mongrel2.org/). Thank you Tor, and Zed for your earlier contributions.*

## Benchmarks

There is a small microbenchmark located here:
https://github.com/bungle/lua-resty-template/blob/master/lib/resty/template/microbenchmark.lua

##### Lua

```lua
local benchmark = require "resty.template.microbenchmark"
benchmark.run()
-- You may also pass iteration count (by default it is 10000)
benchmark.run(100)
```

Here are some results from my laptop.

##### Lua 5.2.2  Copyright (C) 1994-2013 Lua.org, PUC-Rio

```
Running 10000 iterations in each test
Compilation Time: 0.5006 (template)
Compilation Time: 0.0022 (template cached)
  Execution Time: 0.6178 (same template)
  Execution Time: 0.0883 (same template cached)
  Execution Time: 0.8924 (different template)
  Execution Time: 0.2171 (different template cached)
  Execution Time: 0.9910 (different template, different context)
  Execution Time: 0.2542 (different template, different context cached)
```

##### LuaJIT 2.0.2 -- Copyright (C) 2005-2013 Mike Pall. http://luajit.org/

```
Running 10000 iterations in each test
Compilation Time: 0.2530 (template)
Compilation Time: 0.0001 (template cached)
  Execution Time: 0.3250 (same template)
  Execution Time: 0.0370 (same template cached)
  Execution Time: 2.5133 (different template)
  Execution Time: 1.1772 (different template cached)
  Execution Time: 3.0978 (different template, different context)
  Execution Time: 0.1788 (different template, different context cached)
```

##### LuaJIT 2.1.0-alpha -- Copyright (C) 2005-2014 Mike Pall. http://luajit.org/

```
Running 10000 iterations in each test
Compilation Time: 0.2530 (template)
Compilation Time: 0.0001 (template cached)
  Execution Time: 0.3250 (same template)
  Execution Time: 0.0370 (same template cached)
  Execution Time: 2.5133 (different template)
  Execution Time: 1.1772 (different template cached)
  Execution Time: 3.0978 (different template, different context)
  Execution Time: 0.1788 (different template, different context cached)
```

I have not yet compared the results against the alternatives. There seems to be opportunity to improve LuaJIT performance. The main performance bottleneck with LuaJIT seems to be in `template.parse` as it uses `string.gmatch` that cannot be JIT compiled. 

## License

`lua-resty-template` uses three clause BSD license (because it was originally forked from one that uses it).

```
Copyright (c) 2014, Aapo Talvensaari
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this
  list of conditions and the following disclaimer in the documentation and/or
  other materials provided with the distribution.

* Neither the name of the {organization} nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
