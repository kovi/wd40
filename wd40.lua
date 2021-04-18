-- for debug
if not DissectorTable then
    require("wsapi")
end

-- Ref
local Ref = {}
Ref.__index = Ref
function Ref.new()
    o = {}
    setmetatable(o, Ref)
    return o
end

function Ref:value()
    return self.value
end

-- Struct
local Struct = {}
Struct.__index = Struct

function Struct.new()
    o = {}
    setmetatable(
        o,
        {
            __call = function(self)
                return self:clone()
            end,
            __index = Struct
        }
    )
    o._fields = {}
    o._size = 0
    return o
end

function Struct:clone()
    local s = Struct.new()
    s._name = self._name
    s._info = self._info
    s._count = self._count
    s._fields = self._fields
    s._size = self._size
    return s
end

function Struct:add(name, def)
    local f = {name = name, def = def}
    table.insert(self._fields, f)
    return self
end

function Struct:name(name)
    self._name = name
    return self
end

function Struct:count(n)
    self._count = n
    return self
end

function Struct:info(info)
    self._info = info
    return self
end

function choice(fn)
    return {
        _choice = fn
    }
end

-- Type
local Type = {}
Type.__index = Type
function Type.new(size, valFn)
    o = {_size = size, _valFn = valFn}
    setmetatable(o, Type)
    o.__tostring = function()
        return string.format("type(size=%d)", self._size)
    end
    return o
end

function Type:name(name)
    self._name = name
    return self
end

function Type:map(mapFn)
    self._mapFn = mapFn
    return self
end

function Type:values(values)
    self._values = values
    return self
end

function Type:field(proto_field)
    self._field = proto_field
    return self
end

function Type:value(tvb)
    return self._valFn(tvb)
end

function Type:count(n)
    self._count = n
    return self
end

function Type:size(n)
    self._size = n
    return self
end

function Type:ref(r)
    self._ref = r
    return self
end

function Type:info(info)
    self._info = info
    return self
end

type_factory = function(size, valFn)
    return function()
        return Type.new(size, valFn)
    end
end

local uint = function(b)
    return b:uint()
end

local floatFn = function(b)
    return b:float()
end

u8 = type_factory(1, uint)
u16 = type_factory(2, uint)
u32 = type_factory(4, uint)
u64 = type_factory(8, uint)
float32 = type_factory(4, floatFn)
float64 = type_factory(8, floatFn)
stringz = function(length)
    return Type.new(
        length,
        function(b)
            return b:stringz()
        end
    )
end
data = function(length)
    return Type.new(
        length,
        function(b)
            return "[" .. b:len() .. " bytes of data]"
        end
    )
end

function dump(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. dump(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
end

local function updateInfo(def, value, displayValue, pinfo)
    if type(def._info) ~= "function" then
        return
    end

    local info = def._info(value, displayValue, pinfo.cols.info)
    if info == nul then
        return
    end

    if string.len(tostring(pinfo.cols.info)) > 0 then
        pinfo.cols.info = tostring(pinfo.cols.info) .. ", "
    end
    pinfo.cols.info = tostring(pinfo.cols.info) .. info
end

local function defaultValuesMapper(value, def)
    if def._values[value] then
        return def._values[value], true
    end

    return "unknown", true
end

-- Walk
local LABEL_MISSING_VALUE = "* missing data *"
local function walk(buffer, pinfo, tree, struct,  addMissing, from, label, ignoreCount)
    local def = struct.def
    if def._choice then
        def = def._choice()
    end

    local name = label or def._name or struct.name

    -- if repeateable
    if not ignoreCount and (def._count or struct._count) then
        local count = struct._count or def._count
        if type(count) == "function" then
            count = count()
        end
        count = math.floor(tonumber(count))

        local subtree = tree:add(buffer(from, 0), name .. "[" .. count .. "]")
        local size = 0
        local ok = true
        for i = 1, count do
            local s, status
            s, status = walk(buffer, pinfo, subtree, struct, addMissing, from + size, "[" .. (i - 1) .. "]", true)
            size = size + s
            ok = ok and status
            if not ok and not addMissing then
                break
            end
        end
        subtree:set_len(size)
        return size, ok
    end

    -- if it is a struct
    if def._fields then
        local subtree = tree:add(buffer(from, 0), name)
        local size = 0
        local ok = true
        for i = 1, #def._fields do
            local s, status

            s, status = walk(buffer, pinfo, subtree, def._fields[i], addMissing, from + size)
            size = size + s
            ok = ok and status
            if not ok and not addMissing then
                break
            end
        end
        subtree:set_len(size)

        -- value is nil for structs - we cant pass data but ref()s work
        updateInfo(def, nil, nil, pinfo)

        return size, ok
    end

    -- calculatable size (when data length depends on other field)
    local size = def._size
    if size and type(size) == "function" then
        size = size()
    end

    if buffer:len() < from + size then
        if addMissing then
            tree:add(buffer(from, 0), name .. ": " .. LABEL_MISSING_VALUE)
        end
        return 0, false
    end

    local value
    local item
    local b = buffer(from, size)
    if def._field then
        -- uses the ProtoField but we still need to use the _size
        -- so it is correctly highlighted in the UI and we also need
        -- to returned the consumed bytes
        item, value = tree:add_packet_field(def._field, b, 0)
        -- if add_packet_field failed to return the value
        -- try to determine with the old way
        if not value then
            value = def:value(b)
        end
    else
        value = def:value(b)
        item = tree:add(b, name .. ": " .. value)
    end

    -- update reference fields
    if def._ref then
        def._ref.value = value
    end

    -- see if there is mapping on field
    -- this can change label of a protofield as well
    local appendValue, displayValue
    if def._mapFn then
        displayValue, appendValue = def._mapFn(value, def)
    elseif def._values then
        displayValue, appendValue = defaultValuesMapper(value, def)
    end
    if appendValue then
        displayValue = displayValue .. " (" .. value .. ")"
    end
    if displayValue then
        item:set_text(name .. ": " .. displayValue)
    end

    -- update info columns
    updateInfo(def, value, displayValue or value, pinfo)

    return size, true
end

function Walk(tvb, pinfo, tree, name, struct, addMissing)
    return walk(tvb, pinfo, tree, {name = name, def = struct}, addMissing, 0)
end

return {
    struct = function(v)
        return Struct.new(v)
    end,
    ref = function()
        return Ref.new()
    end
}
