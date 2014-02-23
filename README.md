#lua-resty-template

**lua-resty-template** is a templating engine for OpenResty.

## Hello World with lua-resty-template

*Lua:*

```lua
local template = require "resty.template"

-- Using template.new
local view = template.new("view.html")
view.message  = "Hello, World!"

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
