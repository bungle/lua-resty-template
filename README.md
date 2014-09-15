# lua-resty-template

**lua-resty-template** is a compiling (HTML) templating engine for Lua and OpenResty.

## Hello World with lua-resty-template

```lua
local template = require "resty.template"
-- Using template.new
local view = template.new("view.html")
view.message  = "Hello, World!"
view:render()
-- Using template.render
template.render("view.html", { message = "Hello, World!" })
-- Using template string
template.render([[
<!DOCTYPE html>
<html>
<body>
  <h1>{{message}}</h1>
</body>
</html>]], { message = "Hello, World!" })
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

## Contents

* [Template Syntax](#template-syntax)
  * [Reserved Context Keys and Remarks](#reserved-context-keys-and-remarks)
* [Installation](#installation)
  * [Using LuaRocks or Moonrocks](#using-luarocks-or-moonrocks)
* [Nginx / OpenResty Configuration](#nginx--openresty-configuration)
* [Lua API](#lua-api)
  * [template.caching](#boolean-templatecachingboolean-or-nil)
  * [template.new](#table-templatenewview-layout)
  * [template.compile](#function-boolean-templatecompileview-key)
  * [template.render](#templaterenderview-context-key)
  * [template.parse](#string-templateparseview)
  * [template.precompile](#string-templateprecompileview-path-strip)
  * [template.load](#templateload)
  * [template.print](#templateprint)
* [Template Precompilation](#template-precompilation)
* [Template Helpers](#template-helpers)
* [Usage Examples](#usage-examples)
  * [Template Including](#template-including)
  * [Views with Layouts](#views-with-layouts)
  * [Using Blocks](#using-blocks)
  * [Calling Methods in Templates](#calling-methods-in-templates)
* [FAQ](#faq)
* [Alternatives](#alternatives)
* [Benchmarks](#benchmarks)
* [Changes](#changes)
* [License](#license)

## Template Syntax

You may use the following tags in templates:

* `{{expression}}`, writes result of expression - html escaped
* `{*expression*}`, writes result of expression 
* `{% lua code %}`, executes Lua code
* `{(template)}`, includes `template` file, you may also supply context for include file `{(file.html, { message = "Hello, World" } )}`
* `{-block-}...{-block-}`, wraps inside of a `{-block-}` to a value stored in a `blocks` table with a key `block` (in this case), see [using blocks](https://github.com/bungle/lua-resty-template#using-blocks).
* `{# comments #}` everything between `{#` and `#}` is considered to be commented out (i.e. not outputted or executed)

From templates you may access everything in `context` table, and everything in `template` table. In templates you can also access `context` and `template` by prefixing keys.

```html
<h1>{{message}}</h1> == <h1>{{context.message}}</h1>
```

##### A Word About HTML Escaping

Only strings are escaped, functions are called without arguments (recursively) and results are returned as is, other types are `tostring`ified. `nil`s and `ngx.null`s are converted to empty strings `""`.

Escaped HTML characters:

* `&` becomes `&amp;`
* `<` becomes `&lt;`
* `>` becomes `&gt;`
* `"` becomes `&quot;`
* `'` becomes `&#39;`
* `/` becomes `&#47;`

#### Example
##### Lua
```lua
local template = require "resty.template"
template.render("view.html", {
  title   = "Testing lua-resty-template",
  message = "Hello, World!",
  names   = { "James", "Jack", "Anne" },
  jquery  = '<script src="js/jquery.min.js"></script>' 
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

* `___`, holds the compiled template, if set you need to use `{{context.___}}`
* `context`, holds the current context, if set you need to use `{{context.context}}`
* `layout`, holds the layout by which the view will be decorated, if set you need to use `{{context.layout}}`
* `blocks`, holds the blocks, if set you need to use `{{context.blocks}}` (see: [using blocks](#using-blocks))
* `template`, holds the template table, if set you need to use `{{context.template}}`

In addition to that with `template.new` you should not overwrite:

* `render`, the function that renders a view, obviously ;-)

You should also not `{(view.html)}` recursively:

##### Lua
```lua
template.render "view.html"
```

##### view.html
```html
{(view.html)}
```

You can  load templates from "sub-directories" as well with `{(syntax)}`:

##### view.html
```html
{(users/list.html)}
```

**Also note that you can provide template either as a file path or as a string. If the file exists, it will be used, otherwise the string is used. See also [`template.load`](#templateload).**

## Installation

Just place [`template.lua`](https://github.com/bungle/lua-resty-template/blob/master/lib/resty/template.lua) somewhere in your `package.path`, preferably under `resty` directory. If you are using OpenResty, the default location would be `/usr/local/openresty/lualib/resty`.

### Using LuaRocks or MoonRocks

If you are using LuaRocks >= 2.2:

```Shell
$ luarocks install lua-resty-template
```

If you are using LuaRocks < 2.2:

```Shell
$ luarocks install --server=http://rocks.moonscript.org moonrocks
$ moonrocks install lua-resty-template
```

MoonRocks repository for `lua-resty-template`  is located here: https://rocks.moonscript.org/modules/bungle/lua-resty-template.

## Nginx / OpenResty Configuration

When `lua-resty-template` is used in context of Nginx / OpenResty there are a few configuration directives that you need to be aware:

* `template_root` (`set $template_root /var/www/site/templates`)
* `template_location` (`set $template_location /templates`)

If none of these are set in Nginx configuration, `ngx.var.document_root` (aka root-directive) value is used. If `template_location` is set, it will be used first, and if the location returns anything but `200` as a status code, we do fallback to either `template_root` (if defined) or `document_root`.

##### Using `document_root`

This one tries to load file content with Lua code from `html` directory (relative to Nginx prefix).

```nginx
http {
  server {
    location / {
      root html;
      content_by_lua '
        local template = require "resty.template"
        template.render("view.html", { message = "Hello, World!" })
      ';      
    }
  }
}
```

##### Using `template_root`

This one tries to load file content with Lua code from `/usr/local/openresty/nginx/html/templates` directory.

```nginx
http {
  server {
    set $template_root /usr/local/openresty/nginx/html/templates;
    location / {
      root html;
      content_by_lua '
        local template = require "resty.template"
        template.render("view.html", { message = "Hello, World!" })
      ';      
    }
  }
}
```

##### Using `template_location`

This one tries to load content with `ngx.location.capture` from `/templates` location (in this case this is served with `ngx_static` module).

```nginx
http {
  server {
    set $template_location /templates;
    location / {
      root html;
      content_by_lua '
        local template = require "resty.template"
        template.render("view.html", { message = "Hello, World!" })
      ';      
    }
    location /templates {
      internal;
      alias html/templates/;
    }    
  }
}
```

**See also [`template.load`](#templateload).**

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

Please note that if the template was already cached when compiling a template, the cached version will be returned. You may want to flush cache with `template.cache = {}` to ensure that your template really gets recompiled.

#### table template.new(view, layout)

Creates a new template instance that is used as a (default) context when `render`ed.

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
view:render()
-- You may also replace context on render
view:render{ title = "Testing lua-resty-template" }
-- If you want to include view context in  replacement context
view:render(setmetatable({ title = "Testing lua-resty-template" }, { __index = view }))
-- To get rendered template as a string, you can use tostring
local result = tostring(view)
```

#### function, boolean template.compile(view, key, plain)

Parses, compiles and caches (if caching is enabled) a template and returns the compiled template as a function that takes context as a parameter and returns rendered template as a string. Optionally you may pass `key` that is used as a cache key. If cache key is not provided `view` wil be used as a cache key. If cache key is `no-cache` the template cache will not be checked and the resulting function will not be cached. You may also optionally pass `plain` with a value of `true` if the `view` is plain text string (this will skip `template.load` and binary chunk detection in `template.parse` phase).

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

Also note the second return value which is a boolean. You may discard it, or use it to determine if the returned function was cached.

#### template.render(view, context, key, plain)

Parses, compiles, caches (if caching is enabled) and outputs template either with `ngx.print` if available, or `print`. You may optionally also pass `key` that is used as a cache key. If `plain` evaluates to `true`, the `view` is considered to be plain string template (`template.load` and binary chunk detection is skipped on `template.parse`).

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

#### string template.parse(view, plain)

Parses template file or string, and generates a parsed template string. This may come useful when debugging templates. You should note that if you are trying to parse a binary chunk (e.g. one returned with `template.compile`), `template.parse` will return that binary chunk as is. If optional parameter `plain` evaluates to `true`, the `view` is considered to be plain string, and the `template.load` and binary chunk detection is skipped.

```lua
local t1 = template.parse("template.html")
local t2 = template.parse([[<h1>{{message}}</h1>]])
```

#### string template.precompile(view, path, strip)

Precompiles template as a binary chunk. This binary chunk can be written out as a file (and you may use it directly with Lua's `load` and `loadfile`). For convenience you may optionally specify `path` argument to output binary chunk to file. You may also supply `strip` parameter with value of `false` to make precompiled templates to have debug information as well (defaults to `true`).

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
})
```

#### template.load

This field is used to load templates. `template.parse` calls this function before it starts parsing the template (assuming that optional `plain` argument in `template.parse` evaluates false (the default). By default there are two loaders in `lua-resty-template`: one for Lua and the other for Nginx / OpenResty. Users can overwrite this field with their own function. For example you may want to write a template loader function that loads templates from a database.

Default `template.load` for Lua (attached as template.load when used directly with Lua):

```lua
local function load_lua(path)
    -- read_file tries to open file from path, and return its content.
    return read_file(path) or path
end
```

Default `template.load` for Nginx / OpenResty (attached as template.load when used in context of Nginx / OpenResty):

```lua
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
    -- read_file tries to open file from path, and return its content.
    return read_file(root .. "/" .. file) or path
end
```

As you can see, `lua-resty-template` always tries (by default) to load a template from a file (or with `ngx.location.capture`) even if you provided template as a string. `lua-resty-template`. But if you know that your templates are always strings, and not file paths, you may use `plain` argument in `template.compile`, `template.render`, and `template.parse` OR replace `template.load` with the simplest possible template loader there is (but be aware that if your templates use `{(file.html)}` includes, those are considered as strings too, in this case `file.html` will be the template string that is parsed) - you could also setup a loader that finds templates in some database system, e.g. Redis:

```lua
local template = require "resty.template"
template.load = function(s) return s end
```

#### template.print

This field contains a function that is used on `template.render()` or `template.new("example.html"):render()` to output the results. By default this holds either `ngx.print` (if available) or `print`. You may want to (and are allowed to) overwrite this field, if you want to use your own output function instead. This is also useful if you are using some other framework, e.g. Turbo.lua (http://turbolua.org/).

```lua
local template = require "resty.template"

template.print = function(s)
  print(s)
  print("<!-- Output by My Function -->")
end
```

## Template Precompilation

`lua-resty-template` supports template precompilation. This can be useful when you want to skip template parsing (and Lua interpretation) in production or if you do not want your templates distributed as plain text files on production servers. Also by precompiling, you can ensure that your templates do not contain something, that cannot be compiled (they are syntactically valid Lua). Although templates are cached (even without precompilation), there are some perfomance (and memory) gains. You could integrate template precompilation in your build (or deployment) scripts (maybe as Gulp, Grunt or Ant tasks).

##### Precompiling template, and output it as a binary file

```lua
local template = require "resty.template"
local compiled = template.precompile("example.html", "example-bin.html")
```

##### Load precompiled template file, and run it with context parameters

```lua
local template = require "resty.template"
template.render("example-bin.html", { "Jack", "Mary" })
```

## Template Helpers

While `lua-resty-template` does not have much infrastucture or ways to extend it, you still have a few possibilities that you may try.

* Adding methods to global `string`, and `table` types (not encouraged, though)
* Wrap your values with something before adding them in context (e.g. proxy-table)
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

### Template Including

You may include templates inside templates with `{(template)}` and `{(template, context)}` syntax. The first one uses the current context as a context for included template, and the second one replaces it with a new context. Here is example of using includes and passing a different context to include file:

##### Lua

```lua
local template = require "resty.template"
template.render("include.html", { users = {
    { name = "Jane", age = 29 },
    { name = "John", age = 25 }
}})
```

##### include.html

```html
<html>
<body>
<ul>
{% for _, user in ipairs(users) do %}
    {(user.html, user)}
{% end %}
</ul>
</body>
</html>
```

##### user.html

```html
<li>User {{name}} is of age {{age}}</li>
```

##### Outut

```html
<html>
<body>
<ul>
    <li>User Jane is of age 29</li>
    <li>User John is of age 25</li>
</ul>
</body>
</html>
```

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
-- Or maybe you like this style more
-- (but please remember that context.view is overwritten on rendering the layout.html)
local view     = template.new("view.html", "layout.html")
view.title     = "Testing lua-resty-template"
view.message   = "Hello, World!"
view:render()
```

##### view.html
```html
<h1>{{message}}</h1>
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

##### Alternatively you can define the layout in a view as well:

##### Lua
```lua
local view     = template.new("view.html", "layout.html")
view.title     = "Testing lua-resty-template"
view.message   = "Hello, World!"
view:render()
```

##### view.html
```html
{% layout="section.html" %}
<h1>{{message}}</h1>
```

##### section.html
```html
<div id="section">
    {*view*}
</div>
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

##### Output
```html
<!DOCTYPE html>
<html>
<head>
    <title>Testing lua-resty-template</title>
</head>
<body>
<div id="section">
    <h1>Hello, World!</h1>
</div>
</body>
</html>
```

### Using Blocks

Blocks can be used to move different parts of the views to specific places in layouts. Layouts have placeholders for blocks.

##### Lua
```lua
local view     = template.new("view.html", "layout.html")
view.title     = "Testing lua-resty-template blocks"
view.message   = "Hello, World!"
view.keywords  = { "test", "lua", "template", "blocks" }
view:render()
```

##### view.html
```html
<h1>{{message}}</h1>
{-aside-}
<ul>
    {% for _, keyword in ipairs(keywords) do %}
    <li>{{keyword}}</li>
    {% end %}
</ul>
{-aside-}
```

##### layout.html
```html
<!DOCTYPE html>
<html>
<head>
<title>{*title*}</title>
</head>
<body>
<article>
    {*view*}
</article>
{% if blocks.aside then %}
<aside>
    {*blocks.aside*}
</aside>
{% end %}
</body>
</html>
```

##### Output

```html
<!DOCTYPE html>
<html>
<head>
<title>Testing lua-resty-template blocks</title>
</head>
<body>
<article>
    <h1>Hello, World!</h1>
</article>
<aside>
    <ul>
        <li>test</li>
        <li>lua</li>
        <li>template</li>
        <li>blocks</li>
    </ul>
</aside>
</body>
</html>
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
* cgilua (http://keplerproject.github.io/cgilua/manual.html#templates)
* orbit (http://keplerproject.github.io/orbit/pages.html)
* turbolua mustache (http://turbolua.org/doc/web.html#mustache-templating)
* pl.template (http://stevedonovan.github.io/Penlight/api/modules/pl.template.html)
* lustache (https://github.com/Olivine-Labs/lustache)
* luvstache (https://github.com/james2doyle/luvstache)
* lub.Template (http://doc.lubyk.org/lub.Template.html)
* lust (https://github.com/weshoke/Lust)
* templet (http://colberg.org/lua-templet/)
* luahtml (https://github.com/TheLinx/LuaHTML)
* mixlua (https://github.com/LuaDist/mixlua)
* lutem (https://github.com/daly88/lutem)
* tirtemplate (https://github.com/torhve/LuaWeb/blob/master/tirtemplate.lua)
* cosmo (http://cosmo.luaforge.net/)
* lua-codegen (http://fperrad.github.io/lua-CodeGen/)
* groucho (https://github.com/hanjos/groucho)
* simple lua preprocessor (http://lua-users.org/wiki/SimpleLuaPreprocessor)
* slightly less simple lua preprocessor (http://lua-users.org/wiki/SlightlyLessSimpleLuaPreprocessor)
* ltp (http://www.savarese.com/software/ltp/)
* slt (https://code.google.com/p/slt/)
* slt2 (https://github.com/henix/slt2)
* luasp (http://luasp.org/)
* view0 (https://bitbucket.org/jimstudt/view0)
* leslie (https://code.google.com/p/leslie/)
* fraudster (https://bitbucket.org/sphen_lee/fraudster)
* lua-haml (https://github.com/norman/lua-haml)
* lua-template (https://github.com/tgn14/Lua-template)
* hige (https://github.com/nrk/hige)
* lapis html generation (http://leafo.net/lapis/reference.html#html-generation)

`lua-resty-template` *was originally forked from Tor Hveem's* `tirtemplate.lua` *that he had extracted from Zed Shaw's Tir web framework (http://tir.mongrel2.org/). Thank you Tor, and Zed for your earlier contributions.*

## Benchmarks

There is a small microbenchmark located here:
https://github.com/bungle/lua-resty-template/blob/master/lib/resty/template/microbenchmark.lua

##### Lua

```lua
local benchmark = require "resty.template.microbenchmark"
benchmark.run()
-- You may also pass iteration count (by default it is 1,000)
benchmark.run(100)
```

Here are some results from my laptop.

##### Lua 5.2.2  Copyright (C) 1994-2013 Lua.org, PUC-Rio

```
Running 1000 iterations in each test
Compilation Time: 0.056178 (template)
Compilation Time: 0.000266 (template cached)
  Execution Time: 0.067796 (same template)
  Execution Time: 0.009158 (same template cached)
  Execution Time: 0.062518 (different template)
  Execution Time: 0.008550 (different template cached)
  Execution Time: 0.071966 (different template, different context)
  Execution Time: 0.009919 (different template, different context cached)
```

##### LuaJIT 2.0.2 -- Copyright (C) 2005-2013 Mike Pall. http://luajit.org/

```
Running 1000 iterations in each test
Compilation Time: 0.026106 (template)
Compilation Time: 0.000079 (template cached)
  Execution Time: 0.034294 (same template)
  Execution Time: 0.004126 (same template cached)
  Execution Time: 0.057301 (different template)
  Execution Time: 0.009084 (different template cached)
  Execution Time: 0.063139 (different template, different context)
  Execution Time: 0.005883 (different template, different context cached)
```

##### LuaJIT 2.1.0-alpha -- Copyright (C) 2005-2014 Mike Pall. http://luajit.org/

```
Running 1000 iterations in each test
Compilation Time: 0.021228 (template)
Compilation Time: 0.000077 (template cached)
  Execution Time: 0.029370 (same template)
  Execution Time: 0.004002 (same template cached)
  Execution Time: 0.049048 (different template)
  Execution Time: 0.018746 (different template cached)
  Execution Time: 0.061752 (different template, different context)
  Execution Time: 0.006793 (different template, different context cached)
```

I have not yet compared the results against the alternatives.

## Changes

The changes of every release of this module is recorded in [CHANGES](https://github.com/bungle/lua-resty-template/blob/master/CHANGES) file.

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
