local wd40 = require("wd40")

local HEADER_VERSION = {
    "Unknown",
    "Version 1",
    "Version 2"
}

local pf_header_version = ProtoField.uint16("test.header.version", "version", nil, HEADER_VERSION)
local group = ProtoField.uint8("test.group", "group")
local subgroup = ProtoField.uint8("test.subgroup", "subgroup")

local HEADER_FAMILY = {
    [0] = "other",
    [200] = "experiment",
    [300] = "regular"
}

local TYPES = {
    [1] = "Plain",
    [2] = "Forest",
    [3] = "Sea",
}

local function timestamp(v)
    return "timestamp"
end

local Header = wd40.struct()
    :add('version', u8():name("Protocol Version"):field(pf_header_version))
    :add('family', u8():name("Family"):values(HEADER_FAMILY))
    :add('timestamp', u32():name("Time Stamp"):map(timestamp))
    :add('length', u16():name("Length"))

local Subject = wd40.struct()
    :add('id', u32())

local Key = wd40.struct()
    :add('value', u8())
    :add('code', u8())

local refCount = wd40.ref()
local rGroup = wd40.ref()
local test = wd40.struct()
    :add('header', Header)
    :add('receiver', Subject)
    :add('pad', u8())
    :add('group', u8():field(group):ref(rGroup))
    :add('subgroup', u8():field(subgroup):map(function(v,d) return "" .. v .. " [" .. rGroup.value end))
    :add('sender', Subject)
    :add('keys', Key:clone():count(3)) 
    :add('valuesInfo', u8():name("Type"):values(TYPES):info(function(_, dv) return dv end):count(4))
    :add('fnRef', u8():ref(refCount):info(function(v, dv) return "Info: " .. v end))
    :add('fnCount', u8():count((function() return refCount.value / 10 end)))
    :add('mapped', u8():map(function (v) return 'mapped ' .. v end))
    :add('mapped append', u8():map(function (v) return 'mapped with raw value', true end))
    :add('data', choice(function()
        if refCount.value == 3 then
            return Header
        end

        return u8():name('byte') 
    end))

-- Wireshark plugin def
local tp = Proto("test", "test description")
tp.fields = { pf_header_version, group, subgroup }

function tp.dissector(buffer, pinfo, tree)
    pinfo.cols.protocol:set("test")
    Walk(buffer, pinfo, tree, 'WD40 Test', test, true)
end

-- debug: if no Buffer then not run from Wireshark
if not Buffer then
    udp_table = DissectorTable.get("udp.port")
    udp_table:add(6000, tp)
else
    local pinfo = {
        cols = {
            info = ""
        }
    }

    local function eq(expected) 
        return function (a)
            if a ~= expected then
                error(string.format("got value <%s> does not equal expected <%s>", tostring(a), tostring(expected)))
            end
        end
    end
    
    local function expect(what, exp)
        exp(what)
    end

    local function it(description, test)
        print("---", description)
        test()
    end

    it("should be ok and return processed length", function()
        local len, status = Walk(Buffer.new(0,200), pinfo, TreeItem.new('root'), "test", test)
        expect(len, eq(33))
        expect(status, eq(true))
    end)

    it("should return processed length", function()
        local len, status = Walk(Buffer.new(0,20), pinfo, TreeItem.new('root'), "test", test)
        expect(len, eq(20))
        expect(status, eq(false))
    end)
    
    it("should add tree items for fields which has no data", function()
        local test = wd40.struct()
            :add('2b', u16())
            :add('m1', u16())
            :add('m2', wd40.struct()
                :add('a', u8())
                :add('b', u16()))
            :add('m3', u8():count(2))
        local tree = TreeItem.new('root')
        local len, status = Walk(Buffer.new(0,2), pinfo, tree, "test", test, true)
        expect(len, eq(2))
        expect(status, eq(false))
        local tree = tree.children[1]
        expect(tree.children[1].label, eq('2b: 2'))
        expect(tree.children[2].label, eq('m1: * missing data *'))
        expect(tree.children[3].label, eq('m2'))
        expect(tree.children[3].children[1].label, eq('a: * missing data *'))
        expect(tree.children[3].children[2].label, eq('b: * missing data *'))
        expect(tree.children[4].label, eq('m3[2]'))
        expect(tree.children[4].children[1].label, eq('[0]: * missing data *'))
        expect(tree.children[4].children[2].label, eq('[1]: * missing data *'))
    end)

    it("should add missing fields when buffer runs out with an array", function()
        local test = wd40.struct()
            :add('m1', u8():count(20))
        local tree = TreeItem.new('root')
        local len, status = Walk(Buffer.new(0,2), pinfo, tree, "test", test, true)
        expect(len, eq(2))
        expect(status, eq(false))
        expect(test._fields[1].def._count, eq(20), "def._count field should not be changed")
        local tree = tree.children[1]
        expect(tree.children[1].label, eq('m1[20]'))
        expect(tree.children[1].children[1].label, eq('[0]: 2'))
        expect(tree.children[1].children[2].label, eq('[1]: 2'))
        expect(tree.children[1].children[3].label, eq('[2]: * missing data *'))
    end)

    it("should update ref", function()
        local ref = wd40.ref()
        local refProto = wd40.ref()
        local t = wd40.struct()
            :add("field", u8():ref(ref))
            :add('proto', u8():field({}):ref(refProto))
        Walk(Buffer.new(0, 10), pinfo, TreeItem.new('root'), "test", t)
        expect(ref.value, eq(2))
        expect(refProto.value, eq(3))
    end)

    it("should clone fields", function()
        local t0 = wd40.struct():add("field", u8())
        local t = wd40.struct()
            :add("field", t0:clone():name("f1"):count(2))
            :add("field", t0():name("f2"))
        expect(t0._fields[1].def._count, eq(nil))
        expect(t0._fields[1].def._name, eq(nil))
        expect(t._fields[1].def._name, eq("f1"))
        expect(t._fields[1].def._count, eq(2))
        expect(t._fields[2].def._name, eq("f2"))
        expect(t._fields[2].def._count, eq(nil))
    end)

    it("should call info", function()
        pinfo.cols.info = ""
        local t = wd40.struct()
            :add("field", u8():info(function(v,d) return "-" .. v .. "-" .. d .. "-" end))
        Walk(Buffer.new(0, 10), pinfo, TreeItem.new('root'), "test", t)
        expect(pinfo.cols.info, eq("-2-2-"))
    end)

    it("should call info with protofield", function()
        pinfo.cols.info = ""
        local t = wd40.struct()
            :add("field", u8():field(ProtoField.uint16()):info(function(v,d) return "-" .. v .. "-" .. d .. "-" end))
            
        local tree = TreeItem.new('root')
        tree.m_add_packet_field:add({4})

        Walk(Buffer.new(0, 10), pinfo, tree, "test", t)
        expect(pinfo.cols.info, eq("-4-4-"))
    end)

    it("should use data()", function()
        local t = wd40.struct()
            :add("field", data(10))
        local tree = TreeItem.new('root')

        Walk(Buffer.new(0, 20), pinfo, tree, "test", t)
    end)

end