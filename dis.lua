local wd40 = require("wd40")

local HEADER_VERSION = {
    "Other",
    "DIS PDU version 1.0 (May 92)",
    "IEEE 1278-1993",
    "DIS PDU version 2.0 - third draft (May 93)",
    "DIS PDU version 2.0 - fourth draft (revised) March 16, 1994",
    "IEEE 1278.1-1995"
}

local pf_header_version = ProtoField.uint16("dis.header.version", "version", nil, HEADER_VERSION)

local HEADER_FAMILY = {
    [0] = "other",
    [1] = "Entity Information/Interaction",
    [129] = "Experimental - CGF",
    [130] = "Experimental - Entity Interaction/Information - Field Instrumentation",
    [131] = "Experimental - Warfare Field Instrumentation",
    [132] = "Experimental - Environment Object Information/Interaction",
    [133] = "Experimental - Entity Management",
    [2] = "Warfare",
    [3] = "Logistics",
    [4] = "Radio Communication",
    [5] = "Simulation Management",
    [6] = "Distributed Emission Regeneration"
}

local FORCE_ID = {
    [0] = "Other",
    [1] = "Friendly",
    [2] = "Opposing",
    [3] = "Neutral"
}

local ENUM_PDU_TYPE = { 
    [0] = 'Other',
    [1] = 'Entity State',
    [10] = 'Repair Response',
    [11] = 'Create Entity',
    [12] = 'Remove Entity',
    [129] = 'Announce Object',
    [13] = 'Start/Resume',
    [130] = 'Delete Object',
    [131] = 'Describe Application',
    [132] = 'Describe Event',
    [133] = 'Describe Object',
    [134] = 'Request Event',
    [135] = 'Request Object',
    [14] = 'Stop/Freeze',
    [140] = 'Time Space Position Indicator - FI',
    [141] = 'Appearance-FI',
    [142] = 'Articulated Parts - FI',
    [143] = 'Fire - FI',
    [144] = 'Detonation - FI',
    [15] = 'Acknowledge',
    [150] = 'Point Object State',
    [151] = 'Linear Object State',
    [152] = 'Areal Object State',
    [153] = 'Environment',
    [155] = 'Transfer Control Request',
    [156] = 'Transfer Control',
    [157] = 'Transfer Control Acknowledge',
    [16] = 'Action Request',
    [160] = 'Intercom Control',
    [161] = 'Intercom Signal',
    [17] = 'Action Response',
    [170] = 'Aggregate',
    [18] = 'Data Query',
    [19] = 'Set Data',
    [2] = 'Fire',
    [20] = 'Data',
    [21] = 'Event Report',
    [22] = 'Comment',
    [23] = 'Electromagnetic Emission',
    [24] = 'Designator',
    [25] = 'Transmitter',
    [26] = 'Signal',
    [27] = 'Receiver',
    [3] = 'Detonation',
    [4] = 'Collision',
    [41] = 'Environmental Process',
    [5] = 'Service Request',
    [6] = 'Resupply Offer',
    [7] = 'Resupply Received',
    [8] = 'Resupply Cancel',
    [9] = 'Repair Complete',
}

local pduType = wd40.ref()
local Header = wd40.struct()
        :add('version', u8():name("Protocol Version"):field(pf_header_version))
        :add('exerciseId', u8():name("Exercise Identifier"))
        :add('PDU Type', u8():values(ENUM_PDU_TYPE):ref(pduType):info(function(v,d) return d end))
        :add('family', u8():name("Protocol Family"):values(HEADER_FAMILY):info(function(v,d) return d end))
        :add('timestamp', u32():name("Time Stamp")) -- todo timestamp
        :add('length', u16():name("PDU Length"))
        :add('padding', u16():name("Padding"))

local SimulationAddressRecord = wd40.struct()
    :name("Simulation Address")
    :add('siteID', u16():name("Site Identifier"))
    :add('appID', u16():name("Application Identifier"))

local EntityID = wd40.struct()
    :add('simulationAddress', SimulationAddressRecord)
    :add('entityID', u16():name("Entity Identity"))

local ENUM_KIND = {
    [0] = 'Other',
    [1] = 'Platform',
    [2] = 'Munition',
    [3] = 'Life form',
    [4] = 'Environmental',
    [5] = 'Cultural feature',
    [6] = 'Supply',
    [7] = 'Radio',
    [8] = 'Expendable',
    [9] = 'Sensor/Emitter',
}
local EntityType = wd40.struct()
    :add('Kind', u8():values(ENUM_KIND))				
    :add('Domain', u8())				
    :add('Country', u16())				
    :add('Category', u8())				
    :add('Subcategory', u8())				
    :add('Specific', u8())				
    :add('Extra', u8())

local LinearVelocity = wd40.struct()
    :add('First Vector Component', u32())				
    :add('Second Vector Component', u32())				
    :add('Third Vector Component', u32())

local Location = wd40.struct()
    :add('X', float64())				
    :add('Y', float64())				
    :add('Z', float64())

local Orientation = wd40.struct()
    :add('psi', float32())
    :add('theta', float32())
    :add('phi', float32())

local AngularVelocity = wd40.struct()
    :add('Rate About X-Axis', float32())
    :add('Rate About Y-Axis', float32())
    :add('Rate About Z-Axis', float32())

local SpecificAppearanceVarient = wd40.struct()
    :add('Land Platforms', u16())				
    :add('Air Platforms', u16())				
    :add('Surface Platforms', u16())				
    :add('Subsurface Platforms', u16())				
    :add('Space Platforms', u16())				
    :add('Guided Munitions', u16())				
    :add('Life Forms', u16())				
    :add('Environmentals', u16())

local Appearance = wd40.struct()
    :add('General Appearance', u16()) -- todo bitfield
    :add('Specific Appearance Varient', u16()) -- todo union of SpecificAppearanceVarient	

local ENUM_DEAD_RECKONING_ALGO = {
    [0] = 'Other',
    [1] = 'Static (Entity does not move.)',
    [2] = 'DRM(F, P, W)',
    [3] = 'DRM(R, P, W)',
    [4] = 'DRM(R, V, W)',
    [5] = 'DRM(F, V, W)',
    [6] = 'DRM(F, P, B)',
    [7] = 'DRM(R, P, B)',
    [8] = 'DRM(R, V, B)',
    [9] = 'DRM(F, V, B)',
}

local DeadReconingParameter = wd40.struct()
    :add('Dead Reckoning Algorithm', u8():values(ENUM_DEAD_RECKONING_ALGO))				
    :add('Dead Reckoning Other Parameters', data(15))
    :add('Entity Linear Acceleration', LinearVelocity)
    :add('Entity Angular Velocity', AngularVelocity)

local ENUM_MARKING_CHARACTER_SET = {
    [0] = 'Unused',
    [1] = 'ASCII',
    [2] = 'Army Marking (CCTT)',
    [3] = 'Digit Chevron',
}

local Marking = wd40.struct()
    :add('Entity Marking Character Set', u8():values(ENUM_MARKING_CHARACTER_SET))				
    :add('Entity Marking String', stringz(11))

local ArticulationParameter = wd40.struct()
    :add('Parameter Type Designator', u8())
    :add('Parameter Change Indicator', u8())
    :add('Articulation Attachment ID', u16())
    :add('Parameter Type Varient', u64())
    :add('Articulation Parameter Value', u64())

local cn = wd40.ref()

local EntityState = wd40.struct()
    :add('forceID', u8():name("Force ID"):values(FORCE_ID))
    :add('nofArticulationParameters', u8():ref(cn))
    :add('entityType', EntityType)
    :add('alternativeEntityType', EntityType)
    :add('Entity Linear Velocity', LinearVelocity)
    :add('Entity Location', Location)
    :add('Entity Orientation', Orientation)				
    :add('Entity Appearance', Appearance)				
    :add('Dead Reckoning Parameters', DeadReconingParameter)			
    :add('Entity Marking', Marking)
    :add('Entity Capabilities', u32()) -- todo bitfield
    :add('Articulation Parameter', ArticulationParameter:count(function() return cn.value end ))

local signalDataBits = wd40.ref()
local Signal = wd40.struct()
    :add('Radio ID', u16())				
    :add('Encoding Scheme Record', u16()) -- todo bitfield
    :add('TDL Type', u16())
    :add('Sample Rate', u32())				
    :add('Data Length', u16():ref(signalDataBits))				
    :add('Samples field', u16())
    :add('Data', data():size(function() return signalDataBits.value / 8 end)) -- todo should be raw data

local PDUs = {
    [1] = EntityState,
    [26] = Signal,
}

local dis = wd40.struct()
    :add('header', Header)
    :add('entityID', EntityID:name("EntityID"))
    :add('pdu', choice(function()
        return PDUs[pduType.value] or data(0)
    end))


-- Distributed Interactive Simulation

local proto = Proto("dise", "Enhanced Distributed Interactive Simulation")
proto.fields = { pf_header_version }

function proto.dissector(buffer, pinfo, tree)
    pinfo.cols.protocol:set("DIS")
    pinfo.cols.info:set('DIS')
    Walk(buffer, pinfo, tree, 'Distributed Interactive Simulation', dis)
end

udp_table = DissectorTable.get("udp.port")
udp_table:add(6000, proto)
