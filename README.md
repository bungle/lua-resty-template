#lua-resty-template

**lua-resty-template** is a templating engine for OpenResty.

## Hello, World with lua-resty-template

*Lua:*
```lua
local template = require "resty.template"
-- Using template.new
local view = template.new("view.html")
view.message  = "Hello, World!"
view.render()
-- Using template.render
template.render("view.html", { message = "Hello, World!" })
```

*view.html:*
```html
<!DOCTYPE html>
<html>
<body>
  <h1>{{message}}</h1>
</body>
</html>
```

*Output:*
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
* `{( template )}`, includes `template` file

### Example

*Lua:*
```lua
local template = require "resty.template"
-- Using template.new
local view = template.new("view.html")
view.message  = "Hello, World!"
view.render()
-- Using template.render
template.render("view.html", { message = "Hello, World!" })
```

*view.html:*
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

*header.html:*
```html
<!DOCTYPE html>
<html>
<head>
  <title>{{title}}</title>
</head>
<body>
```

*footer.html:*
```html
</body>
</html>
```

## Lua API

### template.new

`local view = template.new("template.html")`

Creates a new template instance that is used as a context when `render`ed.

#### Example

```lua
local template = require "resty.template"
local view = template.new("view.html")
view.message  = "Hello, World!"
view.render()
--You may also pass additional context to render:
view.render({ title = "Testing lua-resty-template" })
```

### template.compile

`local func = template.compile("template.html")`

Compiles, and caches a template and returns the compiled template as a function that takes context as a parameter and returns rendered template as a string.

#### Example:

```lua
local template = require "resty.template"
local func     = template.compile("view.html")
local world    = func({ message = "Hello, World!" })
local universe = func({ message = "Hello, Universe!" })
print(world, universe)
```

### template.render

`template.render("template.html", { message = "Hello, World!" })`

Compiles, and outputs template either with `ngx.print` if available, or `print`.

#### Example

```lua
local template = require "resty.template"
template.render("view.html", { message = "Hello, World!" })
template.render("view.html", { message = "Hello, Universe!" })
```
