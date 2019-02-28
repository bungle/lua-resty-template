.PHONY: lint
lint:
	luacheck --config=.luacheckrc --no-unused-args --no-redefined \
	                    ./lib/resty/template.lua

.PHONY: build
build:
	tarantoolctl rocks make

all: build