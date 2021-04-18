-- mock
Mock = {}
Mock.__index = Mock

function Mock.new()
    o = {returns = {}}
    setmetatable(o, Mock)
    return o
end

function Mock:add(returns, count)
    local i = #self.returns
    if i > 0 and self.returns[i].count <= 0 then
        i = i - 1 -- if the last item is the default return, insert just before
    end
    table.insert(self.returns, i + 1, {returns = returns, count = count or 1})
    return self
end

function Mock:call()
    local o = self.returns[1]
    if not o then
        error("nothing is set to return")
    end
    local args = o.returns
    o.count = o.count - 1
    if o.count == 0 then
        table.remove(self.returns, 1)
    end
    return unpack(args)
end

--
function Proto(name, desc)
    return {
        name = name,
        description = function()
            return desc
        end,
        dissector = function()
        end
    }
end

-- Protofield
ProtoField = {}
function ProtoField.uint16()
    return {}
end
function ProtoField.uint8()
    return {}
end

-- Tree
TreeItem = {}
TreeItem.__index = TreeItem

function TreeItem.new(label)
    print("TreeItem.new", label)
    o = {
        label = label,
        children = {},
        m_add_packet_field = Mock.new():add({3}, 0)
    }
    setmetatable(o, TreeItem)
    return o
end
function TreeItem:add(buffer, name)
    local t = TreeItem.new(name)
    table.insert(self.children, t)
    t.m_add_packet_field = self.m_add_packet_field
    return t
end
function TreeItem:add_packet_field()
    local t = TreeItem.new("protofield")
    table.insert(self.children, t)
    t.m_add_packet_field = self.m_add_packet_field
    return t, self.m_add_packet_field:call()
end
function TreeItem:set_len()
    return self
end
function TreeItem:set_text(str)
    self.label = str
    return self
end

-- Dissector
DissectorTable = {}
Dissector = {}

function DissectorTable.get()
    return Dissector
end

function Dissector:add()
end

-- Buffer
Buffer = {}
Buffer.__index = Buffer

function Buffer.new(a0, b0)
    o = {offset = a0, length = b0}
    setmetatable(
        o,
        {
            __call = function(self, a, b)
                print("creating smaller buffer from ", self)
                if a < a0 or a + b > a0 + b0 then
                    error(string.format("out of bounds: [%d,%d] -> [%d,%d] ", a0, b0, a, b))
                end
                return Buffer.new(a, b)
            end,
            __index = Buffer
        }
    )
    print("created buffer", a0, b0, o)
    return o
end

function Buffer:uint()
    return 2
end

function Buffer:len()
    return self.length - self.offset
end
