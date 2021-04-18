# wd40

A wireshark lua dissector helper.

It allows you to define your structs with some primitive types in a semi-declarative way (some logics may need implementation, yet). Then use the `Walk()` function inside your Wireshark dissector to parse the buffer as the struct definition.

```lua
local tp = Proto("test", "description")
tp.fields = { pf_header_version }

function tp.dissector(buffer, pinfo, tree)
    pinfo.cols.protocol:set("test")
    Walk(buffer, pinfo, tree, 'WD40 Test', test)
end

udp_table = DissectorTable.get("udp.port")
udp_table:add(6000, tp)

```

See the [`test.lua`](test.lua) for an example.

## Features

- [x] data tree with primitive types and structs
- [x] map primitive types to a readable string
- [x] can use Wireshark `ProtoField`
- [ ] incomplete packet detection
- [ ] bitfields

## Struct

A struct of data.

Add fields with the `add(name, type)` method. The `type` can be another struct or a  primitive type. The `name` argument is the displayed field name unless a `name` is assigned to the field.

The method `clone` returns a clone (the `__call` is overridden too). Use it so modifiers are applied to different types. Otherwise when using a type, a second `:count()` modifier would overwrite a previous one.

```lua
local Subject = wd40.struct()
    :add('id', u32())

local test = wd40.struct()
    :add('receiver', Subject())
    :add('sender', Subject())
    :add('data', u8())
```

## Primitive types

| Type      | bytes |
| --------- | ----- |
| `u8`      | 1     |
| `u16`     | 2     |
| `u32`     | 4     |
| `u64`     | 8     |
| `float32` | 4     |
| `float64` | 8     |

The type named functions return the primitive type with given size.

## `wd40.ref()`

Returns object to be used for field reference. Registered to a field with `ref`, the field value is set into the ref object upon field processing. The value stored in `ref` can be used in later definitions.

```lua
local refCount = wd40.ref()
local test = wd40.struct()
    :add('length', u8():ref(refCount))
    :add('ids', u8():count((function() return refCount.value end)))
```

## `choice(function() -> type|struct)`

Creates a pseudo type which can be added as a field. When the field is processed the type returned by the handler function is used.

```lua
    :add('data', choice(function()
        if refCount.value == 3 then
            return Header
        end

        return u8():name('byte') 
    end
```

## `Walk(tvb, pinfo, tree, rootLabel, structDefinition, addMissing) -> (int, bool)`

Parses the given data based on the struct definitions and adds the struct tree to `tree`. Returns the number of parsed bytes and a status whether all fields have been parsed or not.

When the `addMissing` flag is true, the tree building is not stopped when buffer has run out. Instead fields with `* missing data *` is added for all fields. When a field is missing no modifier is called (no `map`, `ref`, ... etc).

## Modifiers

### `name(string)`

Assigns a display name to a type/struct. The name will be displayed in Wireshark as field name instead of what was added with `add()`.

```lua
    :add('name', u8():name("Field Name")
```

### `values(table)`

Assigns a map of values and sets a default mapper function so the displayed value is `table[value]`.

```lua
TYPES = {
    [1] = "Plain",
    [2] = "Forest",
}

test = wd40.struct()
    :add('values', u8():values(TYPES))
```

### `ref(wd40.ref)`

Assigns the reference variable to the field.

See `wd40.ref()` section above.

### `info(function(value, displayValue, info) -> string | nil)`  

Sets a callback to add update the info column. The string returned by the callback function will be appeneded to the info column, a ", " is added if info column had value previously. Returned `nil` value is ignored. The third parameter is the column itself so it is possible to alter the info column directly (eg.: clear, prepend, ...)

```lua
  :info(function(value, displayValue, infoColumn) 
          return "info: " .. v .. displayValue
        end)
```

### `map(function(value, def) -> (string, boolean))`

Sets a handler function to transform/map the field. The function receives the actual value and the field definition object. The function shall return the display value. Optionally a second boolean value can be returned which is if true the original value is appended to the display string (eg.: "mapped (2)")

```lua
  :map(function(value, definition)
         return transformedValue, true
       end) 
```

### `count(int | function() -> int)`

Sets caridnality for field.

```lua
    :add('keys', Key():count(3))
    :add('data', u8():count(5))
```

### `field(ProtoField)`

Sets the field to be parsed as a Wireshark `ProtoField`. It allows Wireshark filters to work.

```lua
local pf_header_version = ProtoField.uint16("test.header.version", "version", nil, HEADER_VERSION)

local Header = wd40.struct()
    :add('version', u8():name("Protocol Version"):field(pf_header_version))
```
