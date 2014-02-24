#lua-resty-template

**lua-resty-template** is a templating engine for OpenResty.

## Hello World with lua-resty-template

##### Lua
```lua
local template = require "resty.template"
-- Using template.new
local view = template.new("view.html")
view.message  = "Hello, World!"
view.render()
-- Using template.render
template.render("view.html", { message = "Hello, World!" })
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
* `{( templat e)}`, includes `template` file

From templates you may access everything in `context` table, and everything in `template` table. In templates you can also access `context` and `template` by prefixing keys.

```html
<h1>{{message}}</h1> == <h1>{{context.message}}</h1>
```

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

* `context`, holds the current context, if set you need to use `{{context.context}}`
* `template`, holds the current context, if set you need to use `{{context.template}}`

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

## Lua API
#### template.new

Creates a new template instance that is used as a context when `render`ed.

`local view = template.new("template.html")` or `local view = template.new("view.html", "layout.html")`

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
```

#### template.compile

Compiles and caches a template and returns the compiled template as a function that takes context as a parameter and returns rendered template as a string.

`local func = template.compile("template.html")`

##### Example
```lua
local template = require "resty.template"
local func     = template.compile("view.html")
local world    = func({ message = "Hello, World!" })
local universe = func({ message = "Hello, Universe!" })
print(world, universe)
```

#### template.render

Compiles, caches and outputs template either with `ngx.print` if available, or `print`.

`template.render("template.html", { message = "Hello, World!" })`

##### Example
```lua
local template = require "resty.template"
template.render("view.html", { message = "Hello, World!" })
template.render("view.html", { message = "Hello, Universe!" })
```

## Usage Examples

### Views with Layouts

##### Lua
```lua
local template = require "resty.template"
local layout   = template.new("layout.html")
layout.title   = "Testing lua-resty-template"
layout.view    = template.compile("view.html")({ message = "Hello, World!" })
layout:render()
-- Or like this
template.render("layout.html", {
  title = "Testing lua-resty-template",
  view  = template.compile("view.html")({ message = "Hello, World!" })
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

## Alternatives

You may also look at these:

* etlua (https://github.com/leafo/etlua)
* lustache (https://github.com/Olivine-Labs/lustache)
* mixlua (https://github.com/LuaDist/mixlua)
* tirtemplate (https://github.com/torhve/LuaWeb/blob/master/tirtemplate.lua)

`lua-resty-template` *was originally forked from Tor Hveem's* `tirtemplate.lua` *that he had extracted from Zed Shaw's Tir web framework (http://tir.mongrel2.org/). Thank you Tor, and Zed for your earlier contributions.*

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
