BINDING_HEADER_RAIDASSIGNMENTS = "Raid Assignments"
BINDING_NAME_RAIDASSIGNMENTS_TARGET_MARK = "Target Your Mark"

-- Helper: apply class colour to a modern-style player frame.
-- Must be defined before any frame builder functions that reference it.
local function RA_ApplyFrameColor(frame, r, g, b)
    if frame.borderLines then
        for _, ln in ipairs(frame.borderLines) do
            ln:SetVertexColor(r, g, b, 1)
        end
    end
    if frame.fill then
        frame.fill:SetVertexColor(r * 0.18, g * 0.18, b * 0.18, 0.85)
    end
    if frame.glow then
        frame.glow:SetVertexColor(r, g, b, 0.15)
    end
    -- Keep texture alias in sync for legacy callers
    if frame.texture and frame.texture ~= frame.fill then
        frame.texture:SetVertexColor(r, g, b, 1)
    end
end

-- ---------------------------------------------------------------------------
-- Chat message queue
-- WoW 1.12 silently throttles SendChatMessage after ~4 rapid calls in a row.
-- PostAssignments can generate 20+ lines at once (headers + tank + curse +
-- heal rows), so everything past the first few gets dropped.
-- We queue all outgoing chat and drain one message every 0.35s via OnUpdate.
-- ---------------------------------------------------------------------------
local RA_MsgQueue     = {}
local RA_MsgTimer     = 0
local RA_MSG_INTERVAL = 0.35  -- seconds between messages (safe under throttle)

local function RA_QueueMessage(text, channel, lang, target)
    table.insert(RA_MsgQueue, { text = text, channel = channel, lang = lang, target = target })
end

-- Ticker frame: always shown so OnUpdate fires even when the main frame is hidden.
local RA_MsgTicker = CreateFrame("Frame", "RaidAssignmentsMsgTicker", UIParent)
RA_MsgTicker:SetWidth(1)
RA_MsgTicker:SetHeight(1)
RA_MsgTicker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
RA_MsgTicker:SetScript("OnUpdate", function()
    RA_MsgTimer = RA_MsgTimer + arg1
    if RA_MsgTimer < RA_MSG_INTERVAL then return end
    RA_MsgTimer = 0
    if table.getn(RA_MsgQueue) == 0 then return end
    local msg = table.remove(RA_MsgQueue, 1)
    SendChatMessage(msg.text, msg.channel, msg.lang, msg.target)
end)

RaidAssignments = CreateFrame("Button", "RaidAssignments", UIParent)
RaidAssignments.ToolTip = CreateFrame("Button", "ToolTip", UIParent)
RaidAssignments.HealToolTip = CreateFrame("Button", "HealToolTip", UIParent)
RaidAssignments.GeneralToolTip = CreateFrame("Button", "GeneralToolTip", UIParent)
RaidAssignments.GeneralAssignments = CreateFrame("Button", "GeneralAssignments", UIParent)

RaidAssignments_Settings = RaidAssignments_Settings or {}

RaidAssignments.RoleFilter = {
    TankPrimary = { Warrior = true, Druid = true, Paladin = true, Shaman = true },
    Healer = { Priest = true, Druid = true, Shaman = true, Paladin = true }
}

RaidAssignments.CustomMarks = RaidAssignments.CustomMarks or {}
RaidAssignments_Settings["useWhisper"] = RaidAssignments_Settings["useWhisper"] or false

RaidAssignments.Settings = {
	["MainFrame"] = false,
	["Animation"] = false,
	["MainFrameX"] = 975,
	["MainFrameY"] = 680,
	["SizeX"] = 0,
	["SizeY"] = 0,
	["active"] = "",
	["active_heal"] = "",
	["active_general"] = "",
	["GeneralFrame"] = false,
	["GeneralAnimation"] = false,
	["GeneralFrameX"] = 700,
	["GeneralFrameY"] = 560,
	["GeneralSizeX"] = 0,
	["GeneralSizeY"] = 0,
}

RaidAssignments.Marks = {
    [1] = {},
    [2] = {},
    [3] = {},
    [4] = {},
    [5] = {},
    [6] = {},
    [7] = {},
    [8] = {},
    [9] = {},
    [10] = {},
    [11] = {},
    [12] = {},
}


RaidAssignments.RealMarks = {
	[1] = "Star",
	[2] = "Circle",
	[3] = "Diamond",
	[4] = "Triangle",
	[5] = "Moon",
	[6] = "Square",
	[7] = "Cross",
	[8] = "Skull",
}

RaidAssignments.WarlockMarks = {
    [9] = { icon = "Interface\\AddOns\\RaidAssignments\\assets\\Spell_Shadow_CurseOfTounges.tga", name = "Curse of Tongues" },
    [10] = { icon = "Interface\\AddOns\\RaidAssignments\\assets\\Spell_Shadow_UnholyStrength.tga", name = "Curse of Recklessness" },
    [11] = { icon = "Interface\\AddOns\\RaidAssignments\\assets\\Spell_Shadow_CurseOfAchimonde.tga", name = "Curse of Shadow" },
    [12] = { icon = "Interface\\AddOns\\RaidAssignments\\assets\\Spell_Shadow_ChillTouch.tga", name = "Curse of the Elements" },
}

RaidAssignments.HealMarks = {
	[1] = {nil, nil, nil, nil, nil, nil},
	[2] = {nil, nil, nil, nil, nil, nil},
	[3] = {nil, nil, nil, nil, nil, nil},
	[4] = {nil, nil, nil, nil, nil, nil},
	[5] = {nil, nil, nil, nil, nil, nil},
	[6] = {nil, nil, nil, nil, nil, nil},
	[7] = {nil, nil, nil, nil, nil, nil},
	[8] = {nil, nil, nil, nil, nil, nil},
	[9] = {nil, nil, nil, nil, nil, nil},
	[10] = {nil, nil, nil, nil, nil, nil},
	[11] = {nil, nil, nil, nil, nil, nil},
	[12] = {nil, nil, nil, nil, nil, nil},
}

RaidAssignments.HealRealMarks = {
	[1] = "D",
	[2] = "C",
	[3] = "B",
	[4] = "A",
	[5] = "4",
	[6] = "3",
	[7] = "2",
	[8] = "1",
	[9] = "South",
	[10] = "North",
	[11] = "Right",
	[12] = "Left",
}

RaidAssignments.GeneralMarks = {
[1] = {}, [2] = {}, [3] = {}, [4] = {},
[5] = {}, [6] = {}, [7] = {}, [8] = {},
[9] = {nil, nil, nil, nil, nil, nil, nil},
[10] = {nil, nil, nil, nil, nil, nil, nil},
}


RaidAssignments.GeneralRealMarks = {
[1] = "1: North",
[2] = "2: North East",
[3] = "3: East",
[4] = "4: South East",
[5] = "5: South",
[6] = "6: South West",
[7] = "7: West",
[8] = "8: North West",
[9] = "",
[10] = "",
}

RaidAssignments.Frames = {
    ["ToolTip"] = {},
    ["HealToolTip"] = {},
    ["GeneralToolTip"] = {},
    [1] = {},
    [2] = {},
    [3] = {},
    [4] = {},
    [5] = {},
    [6] = {},
    [7] = {},
    [8] = {},
    [9] = {},
    [10] = {},
    [11] = {},
    [12] = {},
}


RaidAssignments.HealFrames = {
	[1] = {},
	[2] = {},
	[3] = {},
	[4] = {},
	[5] = {},
	[6] = {},
	[7] = {},
	[8] = {},
	[9] = {},
	[10] = {},
	[11] = {},
	[12] = {},
}

RaidAssignments.GeneralFrames = {
	[1] = {},
	[2] = {},
	[3] = {},
	[4] = {},
	[5] = {},
	[6] = {},
	[7] = {},
	[8] = {},
	[9] = {},
   [10] = {},
}

RaidAssignments.Classes = {
	[1] = "Warrior",
	[2] = "Warlock",
	[3] = "Rogue",
	[4] = "Priest",
	[5] = "Mage",
	[6] = "Hunter",
	[7] = "Druid",
	[8] = "Paladin",
	[9] = "Shaman",
}

RaidAssignments.ChanTable = {
	["s"] = "SAY",
	["y"] = "YELL",
	["e"] = "EMOTE",
	["g"] = "GUILD",
	["p"] = "PARTY",
	["r"] = "RAID",
	["1"] = {"CHANNEL", "1"},
	["2"] = {"CHANNEL", "2"},
	["3"] = {"CHANNEL", "3"},
	["4"] = {"CHANNEL", "4"},
	["5"] = {"CHANNEL", "5"},
	["6"] = {"CHANNEL", "6"},
	["7"] = {"CHANNEL", "7"},
	["8"] = {"CHANNEL", "8"},
	["9"] = {"CHANNEL", "9"},
}

-- Test mode variables
RaidAssignments.TestMode = false
RaidAssignments.TestRoster = {}

-- Sync-safety flags.
-- _marksPopulated: true only after marks have been received from another officer
--   OR after the local officer has manually assigned at least one player.
--   Officers must never broadcast while this is false, or they will overwrite
--   everyone else's data with their own empty tables.
-- _respondTimer: used to stagger RARequestMarks responses so only one officer
--   (the leader, or the first officer to answer) actually sends data.
RaidAssignments._marksPopulated = false
RaidAssignments._respondTimer   = nil

-- Sequence counters: ChunkSend keys by prefix string.
-- Legacy numeric sub-keys (tanks/heals/general/custom[i]) are unused now
-- but left in place so any stray references don't error.
RaidAssignments._sendSeq = {
    tanks = 0, heals = 0, general = 0,
    custom = { 0, 0, 0, 0, 0, 0, 0, 0 },
    -- string-keyed entries for ChunkSend (auto-created on first send)
}
RaidAssignments._recvSeq = {
    tanks   = 0,
    heals   = 0,
    general = 0,
    custom  = { 0, 0, 0, 0, 0, 0, 0, 0 },
}

-- --- Chunked addon message system --------------------------------------------
-- Vanilla WoW 1.12 caps SendAddonMessage payloads at 255 bytes.
-- With 40-player raids the mark data easily exceeds that, so we split the
-- payload into up to 200-byte pieces (leaving room for the chunk header) and
-- reassemble them on the receiving end before parsing.
--
-- Chunk header format (prepended to each SendAddonMessage call):
--   "C<seq>/<part>/<total>:<data>"
--   seq   = monotonically increasing send counter (prevents stale reassembly)
--   part  = 1-based chunk index
--   total = total number of chunks in this message
--   data  = raw payload slice
--
-- NOTE: ":" is used as separator (not "|") because WoW's chat hook rejects
-- messages containing "|" that don't form valid escape sequences.
-- NOTE: string.match does not exist in WoW 1.12 Lua 5.0 - use string.find.
--
-- Single-chunk messages use the same format with part=1, total=1.
-- The reassembly buffer is keyed by (prefix, sender) and discarded when a
-- newer seq arrives before all parts of the old one are collected.
--
-- IMPORTANT: These locals MUST be declared before OnEvent (and before any
-- other function that references them), because Lua resolves local upvalues
-- at parse time based on declaration order within the file scope.

local CHUNK_DATA_MAX = 200   -- bytes of payload data per chunk (safe margin under 255)

-- _chunkBuf[prefix][sender] = { seq=N, total=T, parts={}, count=N }
RaidAssignments._chunkBuf = {}

local function ChunkSend(prefix, payload, channel)
    RaidAssignments._sendSeq[prefix] = (RaidAssignments._sendSeq[prefix] or 0) + 1
    local seq = RaidAssignments._sendSeq[prefix]
    local len = string.len(payload)
    local total = math.max(1, math.ceil(len / CHUNK_DATA_MAX))
    for part = 1, total do
        local s = (part - 1) * CHUNK_DATA_MAX + 1
        local e = math.min(part * CHUNK_DATA_MAX, len)
        local slice = (len == 0) and "" or string.sub(payload, s, e)
        local header = "C" .. seq .. "/" .. part .. "/" .. total .. ":"
        SendAddonMessage(prefix, header .. slice, channel)
    end
end

-- Called from CHAT_MSG_ADDON. Returns the complete reassembled payload once
-- all chunks have arrived, or nil if still waiting for more parts.
local function ChunkReceive(prefix, raw, sender)
    -- Parse header: "C<seq>/<part>/<total>:<data>"
    local _, _, seq, part, total, data =
        string.find(raw, "^C(%d+)/(%d+)/(%d+):(.*)$")
    if not seq then
        -- Legacy / non-chunked message - pass through as-is
        return raw
    end
    seq   = tonumber(seq)
    part  = tonumber(part)
    total = tonumber(total)

    -- Fast path: single chunk
    if total == 1 then return data end

    -- Multi-chunk reassembly
    if not RaidAssignments._chunkBuf[prefix] then
        RaidAssignments._chunkBuf[prefix] = {}
    end
    local buf = RaidAssignments._chunkBuf[prefix]
    if not buf[sender] or buf[sender].seq ~= seq then
        -- New (or replacement) sequence - start fresh
        buf[sender] = { seq = seq, total = total, parts = {}, count = 0 }
    end
    local entry = buf[sender]
    if not entry.parts[part] then
        entry.parts[part] = data
        entry.count = entry.count + 1
    end
    if entry.count == entry.total then
        -- All parts received - reassemble in order
        local assembled = ""
        for i = 1, entry.total do
            assembled = assembled .. (entry.parts[i] or "")
        end
        buf[sender] = nil
        return assembled
    end
    return nil  -- still waiting
end

-- Thin wrappers kept for call-site compatibility
local function SeqEncode(seq, data)
    -- No longer used for sending; kept so any stray calls don't error.
    return (data or "")
end
local function SeqDecode(raw)
    if not raw then return 0, "" end
    -- Legacy SEQ: prefix (old format) - strip and return payload with seq=1
    local _, _, seq, payload = string.find(raw, "^SEQ:(%d+)[;|](.*)$")
    if seq then return tonumber(seq), payload end
    return 1, raw
end

-- --- Roster cache ------------------------------------------------------------
-- Rebuilt on RAID_ROSTER_UPDATE so GetClassColors / IsInRaid are O(1) lookups
-- instead of iterating up to 40 UnitName/UnitClass calls per query.
-- _rosterCache[name] = class  (string, e.g. "Warrior")
-- _rosterSet[name]   = true   (for fast IsInRaid checks)
RaidAssignments._rosterCache = {}
RaidAssignments._rosterSet   = {}

function RaidAssignments:RebuildRosterCache()
    local cache = {}
    local rset  = {}

    -- Always include the player themselves
    local pName  = UnitName("player")
    local pClass = UnitClass("player")
    if pName then
        cache[pName] = pClass
        rset[pName]  = true
    end

    if RaidAssignments.TestMode then
        for _, unit in ipairs(RaidAssignments.TestRoster) do
            if unit.name then
                cache[unit.name] = unit.class
                rset[unit.name]  = true
            end
        end
    elseif GetRaidRosterInfo(1) then
        for i = 1, GetNumRaidMembers() do
            local name  = UnitName("raid"..i)
            local class = UnitClass("raid"..i)
            if name then
                cache[name] = class
                rset[name]  = true
            end
        end
    elseif GetNumPartyMembers() > 0 then
        for i = 1, GetNumPartyMembers() do
            local name  = UnitName("party"..i)
            local class = UnitClass("party"..i)
            if name then
                cache[name] = class
                rset[name]  = true
            end
        end
    end

    RaidAssignments._rosterCache = cache
    RaidAssignments._rosterSet   = rset
end

-- Lookup helper: returns class string for a player name, or nil.
local function GetCachedClass(name)
    return RaidAssignments._rosterCache[name]
end

-- -----------------------------------------------------------------------------

-- events
RaidAssignments:RegisterEvent("ADDON_LOADED")
RaidAssignments:RegisterEvent("RAID_ROSTER_UPDATE")
RaidAssignments:RegisterEvent("CHAT_MSG_WHISPER")
RaidAssignments:RegisterEvent("UNIT_PORTRAIT_UPDATE")
RaidAssignments:RegisterEvent("CHAT_MSG_ADDON")
RaidAssignments:RegisterEvent("UPDATE_MOUSEOVER_UNIT")

function RaidAssignments:OnEvent()
    if event == "ADDON_LOADED" and arg1 == "RaidAssignments" then

        -- Initialize settings
        RaidAssignments_Settings = RaidAssignments_Settings or {}
        if RaidAssignments_Settings["usecolors"] == nil then
            RaidAssignments_Settings["usecolors"] = true
        end
        if RaidAssignments_Settings["showYourMarkFrame"] == nil then
            RaidAssignments_Settings["showYourMarkFrame"] = true
        end
        if RaidAssignments_Settings["markSound"] == nil then
            RaidAssignments_Settings["markSound"] = true
        end

        -- Initialize CustomRealMarks for all custom windows (1-8)
        RaidAssignments.CustomRealMarks = RaidAssignments.CustomRealMarks or {}
        for i = 1, 8 do
            RaidAssignments.CustomRealMarks[i] = RaidAssignments.CustomRealMarks[i] or {}
            RaidAssignments.CustomRealMarks[i][9] = RaidAssignments.CustomRealMarks[i][9] or "Custom 1"
            RaidAssignments.CustomRealMarks[i][10] = RaidAssignments.CustomRealMarks[i][10] or "Custom 2"
        end

        -- Initialize Custom Assignments system COMPLETELY
        RaidAssignments.CustomMarks = RaidAssignments.CustomMarks or {}
        RaidAssignments.CustomRealMarks = RaidAssignments.CustomRealMarks or {}
        RaidAssignments.CustomFrames = RaidAssignments.CustomFrames or {}
        RaidAssignments_Settings.CustomWindowTitles = RaidAssignments_Settings.CustomWindowTitles or {}

        for i = 1, 8 do
            -- Initialize CustomMarks with all marks and slots
            RaidAssignments.CustomMarks[i] = RaidAssignments.CustomMarks[i] or {}
            for m = 1, 10 do
                RaidAssignments.CustomMarks[i][m] = RaidAssignments.CustomMarks[i][m] or {}
                -- Initialize all slots for each mark
                local maxSlots = (m >= 9 and m <= 10) and 6 or 5
                for s = 1, maxSlots do
                    if RaidAssignments.CustomMarks[i][m][s] == nil then
                        RaidAssignments.CustomMarks[i][m][s] = nil -- Explicitly set to nil
                    end
                end
            end

            -- Initialize CustomRealMarks with proper raid icons for 1-8 and custom names for 9-10
            RaidAssignments.CustomRealMarks[i] = RaidAssignments.CustomRealMarks[i] or {}
            for m = 1, 8 do
                RaidAssignments.CustomRealMarks[i][m] = RaidAssignments.RealMarks[m] or ("Mark "..m)
            end
            RaidAssignments.CustomRealMarks[i][9] = RaidAssignments.CustomRealMarks[i][9] or "Custom 1"
            RaidAssignments.CustomRealMarks[i][10] = RaidAssignments.CustomRealMarks[i][10] or "Custom 2"

            -- Initialize CustomWindowTitles
            if not RaidAssignments_Settings.CustomWindowTitles[i] then
                RaidAssignments_Settings.CustomWindowTitles[i] = "Custom Assignments " .. tostring(i)
            end

            -- Initialize CustomFrames
            RaidAssignments.CustomFrames[i] = RaidAssignments.CustomFrames[i] or {}
        end

        -- Set the reference for custom window titles
        RaidAssignments.CustomWindowTitles = RaidAssignments_Settings.CustomWindowTitles

        -- Initialize other data structures
        RaidAssignments:ConfigMainFrame()
        RaidAssignments:SetScale(RaidAssignments_Settings["UIScale"] or 1.0)
        RaidAssignments:ConfigGeneralFrame()
        RaidAssignments:ConfigAllCustomFrames()
        RaidAssignments:CreateCustomAssignmentButtons()
		RaidAssignments:CreateMinimapButton()
        RaidAssignments:CreateYourMarkFrame()
        RaidAssignments:CreateYourCurseFrame()

        -- Initialize and sync class filters
        RaidAssignments:InitializeClassFilters()
        RaidAssignments:SyncClassFilters()

        -- Hook SetItemRef to handle our custom |HRAmark:N| chat links.
        local origSetItemRef = SetItemRef
        SetItemRef = function(link, text, button)
            if string.sub(link, 1, 7) == "RAmark:" then
                local markIndex = tonumber(string.sub(link, 8))
                if markIndex then
                    TargetUnit("mark"..markIndex)
                end
                return
            end
            if origSetItemRef then origSetItemRef(link, text, button) end
        end

        -- -- Unit tooltip hook: show assigned players for raid-marked units ------
        -- Appends "<MarkName>: <PlayerName>" lines in the mark's colour.
        -- Guard against double-decoration (target frame calls SetUnit repeatedly).
        RaidAssignments._RA_lastDecorated = {unit = nil, markIndex = nil}

        RaidAssignments.DecorateTooltip = function(unit)
            if not UnitExists(unit) then return end
            local markIndex = GetRaidTargetIndex(unit)
            if not markIndex or markIndex < 1 or markIndex > 8 then return end

            if RaidAssignments._RA_lastDecorated.unit == unit and
               RaidAssignments._RA_lastDecorated.markIndex == markIndex then
                return
            end
            RaidAssignments._RA_lastDecorated.unit      = unit
            RaidAssignments._RA_lastDecorated.markIndex = markIndex

            local slots = RaidAssignments.Marks[markIndex]
            if not slots then return end
            local assignedNames = {}
            for _, pname in pairs(slots) do
                if pname and pname ~= "" then
                    assignedNames[table.getn(assignedNames) + 1] = pname
                end
            end
            if table.getn(assignedNames) == 0 then return end

            local col       = RaidAssignments.MarkColors[markIndex] or {1, 1, 1}
            local hex       = string.format("%02x%02x%02x",
                                  math.floor(col[1]*255),
                                  math.floor(col[2]*255),
                                  math.floor(col[3]*255))
            local markName  = RaidAssignments.RealMarks[markIndex] or ("Mark "..markIndex)
            local label     = "|cff"..hex..markName..":|r"

            for _, pname in ipairs(assignedNames) do
                GameTooltip:AddLine(label.."  "..pname, 1, 1, 1)
            end
            GameTooltip:Show()
        end

        local origSetUnit = GameTooltip.SetUnit
        GameTooltip.SetUnit = function(tooltip, unit)
            RaidAssignments._RA_lastDecorated.unit      = nil
            RaidAssignments._RA_lastDecorated.markIndex = nil
            origSetUnit(tooltip, unit)
            RaidAssignments.DecorateTooltip(unit)
        end
        -- ---------------------------------------------------------------------

        RaidAssignments:UnregisterEvent("ADDON_LOADED")

    elseif event == "RAID_ROSTER_UPDATE" or event == "UNIT_PORTRAIT_UPDATE" then
        RaidAssignments:RebuildRosterCache()
        -- Update all relevant frames safely
        pcall(function()
            RaidAssignments:UpdateTanks()
            RaidAssignments:UpdateHeals()
            RaidAssignments:UpdateGeneral()
            RaidAssignments:UpdateYourMarkFrame()
            RaidAssignments:UpdateYourCurseFrame()

            -- NOTE: We deliberately do NOT auto-broadcast marks on roster changes.
            -- Doing so caused officers who just loaded in (with empty tables) to
            -- overwrite everyone else's data. Marks are only sent by explicit user
            -- action (assign/remove/reset) or in response to a RARequestMarks message.
        end)

        -- Detect when this player just joined a raid group.
        -- ALL players (officer or not) request current marks from whoever has them.
        -- Officers will respond only if their own _marksPopulated flag is set,
        -- preventing a freshly-loaded officer from broadcasting empty data.
        local currentCount = GetNumRaidMembers() or 0
        local previousCount = RaidAssignments._prevRaidMemberCount or 0
        if currentCount > 0 and previousCount == 0 then
            -- Use a short timer so the RAID channel is fully available before sending
            RaidAssignments._requestMarksTimer = 2.5
        end
        RaidAssignments._prevRaidMemberCount = currentCount

elseif event == "CHAT_MSG_ADDON" then
    if not arg1 or type(arg1) ~= "string" then
        return
    end

    local isRACMarks = string.find(arg1, "^RACMarks%d$") and true or false
    local isRACLabels = string.find(arg1, "^RACLabel%d$") and true or false
    local isRACTitle = string.find(arg1, "^RACTitle%d$") and true or false

    if not (
        arg1 == "TankAssignmentsMarks" or
        arg1 == "HealAssignmentsMarks" or
        arg1 == "RaidAssignmentsGeneralMarks" or
        arg1 == "RARequestMarks" or
        isRACMarks or
        isRACLabels or
        isRACTitle
    ) then
        return
    end

    if UnitName("player") == arg4 then
        return
    end

    -- Only accept mark data from officers or the raid leader.
    -- This prevents any non-officer raid member (or a bad actor with a modified
    -- addon) from broadcasting and overwriting everyone's assignments.
    -- RARequestMarks is exempt -- anyone is allowed to ask for marks.
    local senderName = arg4
    local senderIsOfficer = false
    if senderName then
        for i = 1, GetNumRaidMembers() do
            if UnitName("raid"..i) == senderName then
                -- GetRaidRosterInfo returns: name, rank, subgroup, level, class, fileName, zone, online, isDead
                -- rank: 0=member, 1=assistant/officer, 2=leader
                -- Note: select() does not exist in WoW 1.12 Lua 5.0; destructure directly.
                local _, rosterRank = GetRaidRosterInfo(i)
                if rosterRank and rosterRank >= 1 then
                    senderIsOfficer = true
                end
                break
            end
        end
    end

    local requiresOfficer = (
        arg1 == "TankAssignmentsMarks" or
        arg1 == "HealAssignmentsMarks" or
        arg1 == "RaidAssignmentsGeneralMarks" or
        isRACMarks or
        isRACLabels or
        isRACTitle
    )
    -- RARequestMarks does NOT require officer -- anyone joining can ask
    if requiresOfficer and not senderIsOfficer then
        return
    end

    pcall(function()
        if arg1 == "TankAssignmentsMarks" then
            local payload = ChunkReceive(arg1, arg2, arg4)
            if not payload then return end  -- waiting for more chunks
            local seq, data = SeqDecode(payload)
            if seq < RaidAssignments._recvSeq.tanks then return end
            RaidAssignments._recvSeq.tanks = seq

            RaidAssignments.Marks = {
                [1]={},[2]={},[3]={},[4]={},[5]={},[6]={},[7]={},[8]={},
                [9]={},[10]={},[11]={},[12]={}
            }

            local pos = 1
            while pos <= string.len(data) do
                local markEnd = string.find(data, "_", pos)
                if not markEnd then break end
                local slotEnd = string.find(data, "_", markEnd + 1)
                if not slotEnd then break end
                local nameEnd = string.find(data, ",", slotEnd + 1)
                if not nameEnd then nameEnd = string.len(data) + 1 end

                local mark = tonumber(string.sub(data, pos, markEnd - 1))
                local slot = tonumber(string.sub(data, markEnd + 1, slotEnd - 1))
                local name = string.sub(data, slotEnd + 1, nameEnd - 1)

                if mark and slot and name and name ~= "" and mark >= 1 and mark <= 12 then
                    if not RaidAssignments.Marks[mark] then
                        RaidAssignments.Marks[mark] = {}
                    end
                    RaidAssignments.Marks[mark][slot] = name
                end
                pos = nameEnd + 1
            end
            -- Receiving a sync from another officer means our tables are now populated.
            -- Also cancel our own pending respond timer -- someone else already answered.
            RaidAssignments._marksPopulated = true
            RaidAssignments._respondTimer   = nil
            RaidAssignments:UpdateTanks()
            RaidAssignments:UpdateYourMarkFrame()
            RaidAssignments:UpdateYourCurseFrame()

        elseif arg1 == "HealAssignmentsMarks" then
            local payload = ChunkReceive(arg1, arg2, arg4)
            if not payload then return end
            local seq, data = SeqDecode(payload)
            if seq < RaidAssignments._recvSeq.heals then return end
            RaidAssignments._recvSeq.heals = seq

            RaidAssignments.HealMarks = {}
            for i = 1, 12 do
                RaidAssignments.HealMarks[i] = {nil, nil, nil, nil, nil, nil}
            end

            local pos = 1
            while pos <= string.len(data) do
                local markEnd = string.find(data, "_", pos)
                if not markEnd then break end
                local slotEnd = string.find(data, "_", markEnd + 1)
                if not slotEnd then break end
                local nameEnd = string.find(data, ",", slotEnd + 1)
                if not nameEnd then nameEnd = string.len(data) + 1 end

                local mark = tonumber(string.sub(data, pos, markEnd - 1))
                local slot = tonumber(string.sub(data, markEnd + 1, slotEnd - 1))
                local name = string.sub(data, slotEnd + 1, nameEnd - 1)

                if mark and slot and slot <= 6 and name and name ~= "" then
                    RaidAssignments.HealMarks[mark][slot] = name
                end
                pos = nameEnd + 1
            end
            RaidAssignments._marksPopulated = true
            RaidAssignments._respondTimer   = nil
            RaidAssignments:UpdateHeals()
            RaidAssignments:UpdateYourMarkFrame()
            RaidAssignments:UpdateYourCurseFrame()

        elseif arg1 == "RaidAssignmentsGeneralMarks" then
            local payload = ChunkReceive(arg1, arg2, arg4)
            if not payload then return end
            local seq, data = SeqDecode(payload)
            if seq < RaidAssignments._recvSeq.general then return end
            RaidAssignments._recvSeq.general = seq

            for i = 1, 10 do
                RaidAssignments.GeneralMarks[i] = {}
            end
            local pos = 1
            while pos <= string.len(data) do
                local markEnd = string.find(data, "_", pos)
                if not markEnd then break end
                local slotEnd = string.find(data, "_", markEnd + 1)
                if not slotEnd then break end
                local nameEnd = string.find(data, ",", slotEnd + 1)
                if not nameEnd then nameEnd = string.len(data) + 1 end
                local mark = tonumber(string.sub(data, pos, markEnd - 1))
                local slot = tonumber(string.sub(data, markEnd + 1, slotEnd - 1))
                local name = string.sub(data, slotEnd + 1, nameEnd - 1)
                if mark and slot and name and name ~= "" and mark >= 1 and mark <= 10 then
                    RaidAssignments.GeneralMarks[mark][slot] = name
                end
                pos = nameEnd + 1
            end
            RaidAssignments._marksPopulated = true
            RaidAssignments._respondTimer   = nil
            RaidAssignments:UpdateGeneral()

        elseif isRACLabels then
            local customIndex = tonumber(string.sub(arg1, 9))
            if customIndex and customIndex >= 1 and customIndex <= 8 then
                local data = arg2 or ""
                local pos = 1
                while pos <= string.len(data) do
                    local markEnd = string.find(data, "_", pos)
                    if not markEnd then break end
                    local labelEnd = string.find(data, ",", markEnd + 1)
                    if not labelEnd then labelEnd = string.len(data) + 1 end

                    local mark = tonumber(string.sub(data, pos, markEnd - 1))
                    local label = string.sub(data, markEnd + 1, labelEnd - 1)

                    if mark and (mark == 9 or mark == 10) then
                        RaidAssignments.CustomRealMarks[customIndex][mark] = label or "Custom " .. (mark - 8)
                        local editBox = _G["C" .. customIndex .. "_" .. mark .. "_Edit"]
                        if editBox then
                            editBox:SetText(label or "Custom " .. (mark - 8))
                        end
                    end
                    pos = labelEnd + 1
                end
                RaidAssignments:UpdateCustom(customIndex)
            end

        elseif isRACTitle then
            local customIndex = tonumber(string.sub(arg1, 9))
            if customIndex and customIndex >= 1 and customIndex <= 8 then
                RaidAssignments_Settings.CustomWindowTitles = RaidAssignments_Settings.CustomWindowTitles or {}
                RaidAssignments.CustomWindowTitles = RaidAssignments_Settings.CustomWindowTitles
                RaidAssignments.CustomWindowTitles[customIndex] = arg2 or ("Custom Assignments " .. tostring(customIndex))
                RaidAssignments_Settings.CustomWindowTitles[customIndex] = RaidAssignments.CustomWindowTitles[customIndex]

                if RaidAssignments.CustomFrames[customIndex] and RaidAssignments.CustomFrames[customIndex].frame then
                    local frame = RaidAssignments.CustomFrames[customIndex].frame
                    if frame.title then
                        frame.title:SetText(RaidAssignments.CustomWindowTitles[customIndex])
                    end
                    if frame.titleEditBox then
                        frame.titleEditBox:SetText(RaidAssignments.CustomWindowTitles[customIndex])
                    end
                end
            end

        elseif isRACMarks then
            local customIndex = tonumber(string.sub(arg1, 9))
            if customIndex and customIndex >= 1 and customIndex <= 8 then
                local payload = ChunkReceive(arg1, arg2, arg4)
                if not payload then return end
                local seq, data = SeqDecode(payload)
                if seq < RaidAssignments._recvSeq.custom[customIndex] then return end
                RaidAssignments._recvSeq.custom[customIndex] = seq

                for mark = 1, 10 do
                    local maxSlots = (mark >= 9 and mark <= 10) and 6 or 5
                    RaidAssignments.CustomMarks[customIndex][mark] = {}
                    for slot = 1, maxSlots do
                        RaidAssignments.CustomMarks[customIndex][mark][slot] = nil
                    end
                end

                local pos = 1
                while pos <= string.len(data) do
                    local markEnd = string.find(data, "_", pos)
                    if not markEnd then break end
                    local slotEnd = string.find(data, "_", markEnd + 1)
                    if not slotEnd then break end
                    local nameEnd = string.find(data, ",", slotEnd + 1)
                    if not nameEnd then nameEnd = string.len(data) + 1 end

                    local mark = tonumber(string.sub(data, pos, markEnd - 1))
                    local slot = tonumber(string.sub(data, markEnd + 1, slotEnd - 1))
                    local name = string.sub(data, slotEnd + 1, nameEnd - 1)

                    if mark and slot and name and name ~= "" and mark >= 1 and mark <= 10 then
                        local maxSlots = (mark >= 9 and mark <= 10) and 6 or 5
                        if slot <= maxSlots then
                            if not RaidAssignments.CustomMarks[customIndex][mark] then
                                RaidAssignments.CustomMarks[customIndex][mark] = {}
                            end
                            RaidAssignments.CustomMarks[customIndex][mark][slot] = name
                        end
                    end
                    pos = nameEnd + 1
                end
                RaidAssignments._marksPopulated = true
                RaidAssignments._respondTimer   = nil
                RaidAssignments:UpdateCustom(customIndex)
            end
        elseif arg1 == "RARequestMarks" then
            -- Someone joined/reloaded - reset recv counters so re-broadcasts are accepted
            RaidAssignments._recvSeq.tanks   = 0
            RaidAssignments._recvSeq.heals   = 0
            RaidAssignments._recvSeq.general = 0
            for ci = 1, 8 do
                RaidAssignments._recvSeq.custom[ci] = 0
            end
            if IsRaidOfficer() and RaidAssignments._marksPopulated then
                if IsRaidLeader() then
                    RaidAssignments._respondTimer = 0.5
                else
                    RaidAssignments._respondTimer = 2.0 + math.random() * 2.0
                end
            end
        end
    end)

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        -- 3D world tooltip: engine populates GameTooltip itself, then fires this event.
        if UnitExists("mouseover") and RaidAssignments.DecorateTooltip then
            RaidAssignments._RA_lastDecorated.unit      = nil
            RaidAssignments._RA_lastDecorated.markIndex = nil
            RaidAssignments.DecorateTooltip("mouseover")
        end
    end  -- closes if event == "ADDON_LOADED" / elseif chain

end

-- -- Shared custom button skin helper -----------------------------------------
-- Creates a fully custom WoW-dark-fantasy styled button.
-- Dark bg, gold border, amber text, hover glow. No Blizzard art required.
function RaidAssignments:MakeBtn(parent, w, h, label, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(w)
    btn:SetHeight(h)
    btn:EnableMouse(true)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.08, 0.06, 0.04, 0.95)
    bg:SetAllPoints(btn)
    btn.bg = bg

    local function MakeLine()
        local t = btn:CreateTexture(nil, "BORDER")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        return t
    end
    local gold = {0.72, 0.55, 0.15}
    local bTop = MakeLine(); local bBot = MakeLine(); local bLeft = MakeLine(); local bRight = MakeLine()
    for _, ln in ipairs({bTop, bBot, bLeft, bRight}) do ln:SetVertexColor(gold[1], gold[2], gold[3], 1) end
    bTop:SetHeight(1);  bTop:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0);       bTop:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    bBot:SetHeight(1);  bBot:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0); bBot:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    bLeft:SetWidth(1);  bLeft:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0);      bLeft:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    bRight:SetWidth(1); bRight:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0);   bRight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    btn.borderLines = {bTop, bBot, bLeft, bRight}

    local glow = btn:CreateTexture(nil, "ARTWORK")
    glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetVertexColor(0.80, 0.60, 0.10, 0.18)
    glow:SetAllPoints(btn)
    glow:Hide()
    btn.glow = glow

    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 12)
    fs:SetTextColor(0.92, 0.78, 0.28, 1)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetText(label)
    fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.label = fs

    btn:SetScript("OnEnter", function()
        btn.glow:Show()
        for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(0.95, 0.80, 0.30, 1) end
        btn.label:SetTextColor(1, 0.95, 0.50, 1)
    end)
    btn:SetScript("OnLeave", function()
        btn.glow:Hide()
        for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(gold[1], gold[2], gold[3], 1) end
        btn.label:SetTextColor(0.92, 0.78, 0.28, 1)
    end)
    btn:SetScript("OnMouseDown", function()
        bg:SetVertexColor(0.18, 0.13, 0.04, 0.98)
        fs:SetPoint("CENTER", btn, "CENTER", 0, -1)
    end)
    btn:SetScript("OnMouseUp", function()
        bg:SetVertexColor(0.08, 0.06, 0.04, 0.95)
        fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
    end)
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

-- Custom-skinned EditBox: no Blizzard InputBoxTemplate art.
-- Creates a plain EditBox with the same dark/gold aesthetic as the rest of the UI.
function RaidAssignments:MakeEditBox(name, parent, w, h)
    local eb = CreateFrame("EditBox", name, parent)
    eb:SetWidth(w)
    eb:SetHeight(h)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(64)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetTextColor(0.92, 0.86, 0.62, 1)
    eb:SetTextInsets(6, 6, 2, 2)

    -- Dark background
    local bg = eb:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.07, 0.07, 0.09, 0.97)
    bg:SetAllPoints(eb)
    eb.raBg = bg

    -- Gold border lines (1 px each side)
    local function MkLine(layer)
        local t = eb:CreateTexture(nil, layer or "BORDER")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        return t
    end
    local gc = {0.15, 0.15, 0.18}
    local bT = MkLine(); local bB = MkLine(); local bL = MkLine(); local bR = MkLine()
    bT:SetHeight(1); bT:SetPoint("TOPLEFT", eb, "TOPLEFT", 0, 0);       bT:SetPoint("TOPRIGHT", eb, "TOPRIGHT", 0, 0)
    bB:SetHeight(1); bB:SetPoint("BOTTOMLEFT", eb, "BOTTOMLEFT", 0, 0); bB:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 0, 0)
    bL:SetWidth(1);  bL:SetPoint("TOPLEFT", eb, "TOPLEFT", 0, 0);       bL:SetPoint("BOTTOMLEFT", eb, "BOTTOMLEFT", 0, 0)
    bR:SetWidth(1);  bR:SetPoint("TOPRIGHT", eb, "TOPRIGHT", 0, 0);     bR:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 0, 0)
    for _, ln in ipairs({bT, bB, bL, bR}) do ln:SetVertexColor(gc[1], gc[2], gc[3], 1) end
    eb.raBorderLines = {bT, bB, bL, bR}

    -- Subtle inner glow / highlight stripe along the top edge
    local shine = eb:CreateTexture(nil, "ARTWORK")
    shine:SetTexture("Interface\\Buttons\\WHITE8X8")
    shine:SetVertexColor(1, 0.9, 0.5, 0.06)
    shine:SetHeight(3)
    shine:SetPoint("TOPLEFT", eb, "TOPLEFT", 1, -1)
    shine:SetPoint("TOPRIGHT", eb, "TOPRIGHT", -1, -1)

    -- Focus highlight: brighten border on focus
    eb:SetScript("OnEditFocusGained", function()
        for _, ln in ipairs(this.raBorderLines) do ln:SetVertexColor(0.90, 0.72, 0.22, 1) end
        this.raBg:SetVertexColor(0.10, 0.08, 0.04, 0.98)
    end)
    eb:SetScript("OnEditFocusLost", function()
        for _, ln in ipairs(this.raBorderLines) do ln:SetVertexColor(gc[1], gc[2], gc[3], 1) end
        this.raBg:SetVertexColor(0.07, 0.07, 0.09, 0.97)
    end)

    return eb
end

function RaidAssignments:ConfigMainFrame()
    RaidAssignments.Drag = {}
    function RaidAssignments.Drag:StartMoving()
        RaidAssignments:StartMoving()
        this.drag = true
    end

    function RaidAssignments.Drag:StopMovingOrSizing()
        RaidAssignments:StopMovingOrSizing()
        this.drag = false
    end

    -- Flat dark panel -- modern/sharp look
    local backdrop = {
        bgFile  = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile    = false,
        edgeSize = 1,
        insets  = { left = 0, right = 0, top = 0, bottom = 0 }
    }

    self:SetFrameStrata("FULLSCREEN")
    self:SetWidth(RaidAssignments.Settings["MainFrameX"])
    self:SetHeight(RaidAssignments.Settings["MainFrameY"])
    self:SetPoint("CENTER", 0, 60)
    self:SetMovable(true)
    self:EnableMouse(true)
    self:RegisterForDrag("LeftButton")
    self:SetBackdrop(backdrop)
    self:SetBackdropColor(0.07, 0.07, 0.09, 0.97)
    self:SetBackdropBorderColor(0.15, 0.15, 0.18, 1)

    -- REMOVED ANIMATION: Simplified OnUpdate script
    -- Timer logic is throttled to avoid running every single frame.
    self:SetScript("OnUpdate", function()
        local elapsed = arg1

        -- Deferred request: ask officers for marks shortly after joining a raid.
        if RaidAssignments._requestMarksTimer then
            RaidAssignments._requestMarksTimer = RaidAssignments._requestMarksTimer - elapsed
            if RaidAssignments._requestMarksTimer <= 0 then
                RaidAssignments._requestMarksTimer = nil
                if GetNumRaidMembers() > 0 then
                    SendAddonMessage("RARequestMarks", "", "RAID")
                end
            end
        end

        -- Deferred respond: answer a RARequestMarks after a staggered delay.
        if RaidAssignments._respondTimer then
            RaidAssignments._respondTimer = RaidAssignments._respondTimer - elapsed
            if RaidAssignments._respondTimer <= 0 then
                RaidAssignments._respondTimer = nil
                if RaidAssignments._marksPopulated and IsRaidOfficer() and GetNumRaidMembers() > 0 then
                    RaidAssignments:SendTanks()
                    RaidAssignments:SendHeals()
                    RaidAssignments:SendGeneral()
                    for i = 1, 8 do
                        RaidAssignments:SendCustom(i)
                    end
                end
            end
        end

        if RaidAssignments:IsVisible() then
            if not RaidAssignments.Settings["MainFrame"] then
                RaidAssignments.Settings["MainFrame"] = true
                RaidAssignments:SetWidth(RaidAssignments.Settings["MainFrameX"])
                RaidAssignments:SetHeight(RaidAssignments.Settings["MainFrameY"])
                RaidAssignments.bg:Show()
                RaidAssignments:UpdateTanks()
                RaidAssignments:UpdateHeals()
            elseif RaidAssignments.Settings["Animation"] then
                RaidAssignments.Settings["MainFrame"] = false
                RaidAssignments.Settings["Animation"] = false
                RaidAssignments.bg:Hide()
                RaidAssignments:Hide()
            end
        end
    end)

    self.bg = CreateFrame("Button", "bg", RaidAssignments)
    self.bg:SetWidth(self:GetWidth())
    self.bg:SetHeight(self:GetHeight())
    self.bg:SetPoint("TOPLEFT",0,0)
    self.bg:SetBackdropColor(0,0,0,1)
    self.bg:EnableMouse(true)
    self.bg:SetMovable(true)
    self.bg:RegisterForDrag("LeftButton")
    self.bg:SetScript("OnDragStart", RaidAssignments.Drag.StartMoving)
    self.bg:SetScript("OnDragStop", RaidAssignments.Drag.StopMovingOrSizing)
    self.bg:SetScript("OnEnter", function()
        RaidAssignments.ToolTip:Hide()
        RaidAssignments.HealToolTip:Hide()
    end)

    -- -- Title bar (dark strip across top) ----------------------------------
    local titleBar = self.bg:CreateTexture(nil, "BACKGROUND")
    titleBar:SetTexture("Interface\\Buttons\\WHITE8X8")
    titleBar:SetVertexColor(0.05, 0.05, 0.07, 1)
    titleBar:SetPoint("TOPLEFT",  self.bg, "TOPLEFT",  1, -1)
    titleBar:SetPoint("TOPRIGHT", self.bg, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(36)

    self.text = self.bg:CreateFontString(nil, "OVERLAY")
    self.text:SetPoint("TOP", self.bg, "TOP", 0, -10)
    self.text:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 18)
    self.text:SetTextColor(0.9, 0.9, 0.95, 1)
    self.text:SetShadowOffset(1, -1)
    self.text:SetShadowColor(0, 0, 0, 1)
    self.text:SetText("RAID ASSIGNMENTS")

    -- Cyan accent line under title bar
    local accentLine = self.bg:CreateTexture(nil, "ARTWORK")
    accentLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    accentLine:SetVertexColor(0.2, 0.8, 0.9, 0.9)
    accentLine:SetHeight(2)
    accentLine:SetPoint("TOPLEFT",  self.bg, "TOPLEFT",  1, -37)
    accentLine:SetPoint("TOPRIGHT", self.bg, "TOPRIGHT", -1, -37)

    -- -- Class filter icons --------------------------------------------------
    -- Compact row in the title bar, left side -- custom skinned with dark bg + gold border
    local CLASS_ICON_SIZE = 24
    local CLASS_ICON_GAP  = 4
    local classIconStartX = 8
    local classIconY      = -6   -- vertically centered in the 36px title bar
    local i = 1
    for n, class in pairs(RaidAssignments.Classes) do
        local r, l, t, b = RaidAssignments:ClassPos(class)
        local classframe = CreateFrame("Button", class, self.bg)
        classframe:SetWidth(CLASS_ICON_SIZE)
        classframe:SetHeight(CLASS_ICON_SIZE)
        classframe:SetPoint("TOPLEFT", classIconStartX + (i - 1) * (CLASS_ICON_SIZE + CLASS_ICON_GAP), classIconY)
        classframe:SetFrameStrata("FULLSCREEN")

        -- Dark background
        local cfBg = classframe:CreateTexture(nil, "BACKGROUND")
        cfBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        cfBg:SetVertexColor(0.06, 0.05, 0.03, 0.90)
        cfBg:SetAllPoints(classframe)
        classframe.cfBg = cfBg

        -- Gold border lines
        local function CFLine() local t2 = classframe:CreateTexture(nil, "BORDER"); t2:SetTexture("Interface\\Buttons\\WHITE8X8"); return t2 end
        local cfBT = CFLine(); local cfBB = CFLine(); local cfBL = CFLine(); local cfBR = CFLine()
        cfBT:SetVertexColor(0.55, 0.42, 0.10, 1); cfBB:SetVertexColor(0.55, 0.42, 0.10, 1)
        cfBL:SetVertexColor(0.55, 0.42, 0.10, 1); cfBR:SetVertexColor(0.55, 0.42, 0.10, 1)
        cfBT:SetHeight(1); cfBT:SetPoint("TOPLEFT",classframe,"TOPLEFT",0,0);     cfBT:SetPoint("TOPRIGHT",classframe,"TOPRIGHT",0,0)
        cfBB:SetHeight(1); cfBB:SetPoint("BOTTOMLEFT",classframe,"BOTTOMLEFT",0,0); cfBB:SetPoint("BOTTOMRIGHT",classframe,"BOTTOMRIGHT",0,0)
        cfBL:SetWidth(1);  cfBL:SetPoint("TOPLEFT",classframe,"TOPLEFT",0,0);     cfBL:SetPoint("BOTTOMLEFT",classframe,"BOTTOMLEFT",0,0)
        cfBR:SetWidth(1);  cfBR:SetPoint("TOPRIGHT",classframe,"TOPRIGHT",0,0);   cfBR:SetPoint("BOTTOMRIGHT",classframe,"BOTTOMRIGHT",0,0)
        classframe.cfBorderLines = {cfBT, cfBB, cfBL, cfBR}

        -- Hover glow
        local cfGlow = classframe:CreateTexture(nil, "ARTWORK")
        cfGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
        cfGlow:SetVertexColor(0.80, 0.60, 0.10, 0.20)
        cfGlow:SetAllPoints(classframe)
        cfGlow:Hide()
        classframe.cfGlow = cfGlow

        -- Class icon (inset 2px from border)
        classframe.Icon = classframe:CreateTexture(nil, "OVERLAY")
        classframe.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        classframe.Icon:SetTexCoord(r, l, t, b)
        classframe.Icon:SetPoint("TOPLEFT", classframe, "TOPLEFT", 2, -2)
        classframe.Icon:SetPoint("BOTTOMRIGHT", classframe, "BOTTOMRIGHT", -2, 2)

        classframe:SetScript("OnEnter", function()
            classframe.cfGlow:Show()
            for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.95, 0.80, 0.30, 1) end
            local cr, cg, cb = RaidAssignments:GetClassColors(this:GetName(), "class")
            GameTooltip:SetOwner(classframe, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText("|cffFFFFFFShow|r " .. this:GetName(), cr, cg, cb)
            GameTooltip:Show()
        end)
        classframe:SetScript("OnLeave", function()
            classframe.cfGlow:Hide()
            for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.55, 0.42, 0.10, 1) end
            GameTooltip:Hide()
        end)
        classframe:SetScript("OnMouseDown", function()
            if arg1 == "LeftButton" then
                if RaidAssignments_Settings[this:GetName()] == 1 then
                    RaidAssignments_Settings[this:GetName()] = 0
                    classframe.Icon:SetVertexColor(0.25, 0.25, 0.25)
                    for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.30, 0.22, 0.06, 1) end
                else
                    RaidAssignments_Settings[this:GetName()] = 1
                    classframe.Icon:SetVertexColor(1.0, 1.0, 1.0)
                    for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.55, 0.42, 0.10, 1) end
                end
                RaidAssignments:SyncClassFilters()
            end
        end)
        i = i + 1
        if RaidAssignments_Settings[class] == nil then
            RaidAssignments_Settings[class] = 1
        end
        if RaidAssignments_Settings[class] == 1 then
            classframe.Icon:SetVertexColor(1.0, 1.0, 1.0)
        else
            classframe.Icon:SetVertexColor(0.25, 0.25, 0.25)
            for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.30, 0.22, 0.06, 1) end
        end
    end

    -- -- Layout constants ----------------------------------------------------
    -- Tank column: icons at x=14, slots extend right at 85px each (4 slots = 340px) -> ends ~x=389
    -- Divider at x=400
    -- Heal column: icons at x=410, slots extend right at 85px each (6 slots = 510px) -> ends ~x=955
    local ICON_X_TANK  = 14
    local ICON_X_HEAL  = 410
    local ICON_SIZE    = 32
    local ROW_PADDING  = 6
    local ROW_H        = ICON_SIZE + ROW_PADDING
    local COL_TOP      = -90   -- y offset: accent line at -74, +16px gap = -90

    -- Column header bars
    local function MakeColumnHeader(label, x, w)
        local bar = self.bg:CreateTexture(nil, "BACKGROUND")
        bar:SetTexture("Interface\\Buttons\\WHITE8X8")
        bar:SetVertexColor(0.10, 0.10, 0.13, 1)
        bar:SetWidth(w)
        bar:SetHeight(20)
        bar:SetPoint("TOPLEFT", self.bg, "TOPLEFT", x, -48)

        local accent = self.bg:CreateTexture(nil, "ARTWORK")
        accent:SetTexture("Interface\\Buttons\\WHITE8X8")
        accent:SetVertexColor(0.2, 0.8, 0.9, 0.7)
        accent:SetWidth(w)
        accent:SetHeight(1)
        accent:SetPoint("TOPLEFT", self.bg, "TOPLEFT", x, -74)

        local fs = self.bg:CreateFontString(nil, "OVERLAY")
        fs:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 11)
        fs:SetTextColor(0.65, 0.65, 0.70, 1)
        fs:SetText(label)
        fs:SetPoint("LEFT", bar, "LEFT", 8, 0)
    end

    MakeColumnHeader("TANKS", ICON_X_TANK, 385)
    MakeColumnHeader("HEALERS", ICON_X_HEAL, 535)

    -- Vertical divider between columns
    local divider = self.bg:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    divider:SetVertexColor(0.20, 0.20, 0.24, 1)
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT",    self.bg, "TOPLEFT", 403, -48)
    divider:SetPoint("BOTTOMLEFT", self.bg, "BOTTOMLEFT", 403, 46)

    local padding = ROW_PADDING

    -- -- Tank / Curse mark icons (left column) ------------------------------
    -- Rows 1-8: standard raid icons (Skull at top = i=8 displayed first)
    -- Empty slot ghost borders. Uses the same anchor as player frames:
    -- player frames do SetPoint("RIGHT", parentIcon, "RIGHT", 5 + (85*slot), 0)
    -- which positions the frame's RIGHT edge at parentIcon.RIGHT + 5 + 85*slot.
    -- So LEFT edge = that offset - 80 (frame width). We replicate this exactly.
    local function MakeEmptySlots(parent, numSlots)
        for slot = 1, numSlots do
            local ghost = CreateFrame("Frame", nil, parent)
            ghost:SetWidth(80)
            ghost:SetHeight(25)
            -- Match player frame anchor exactly
            ghost:SetPoint("RIGHT", parent, "RIGHT", 5 + (85 * slot), 0)
            ghost:SetFrameStrata("MEDIUM")
            -- Top edge
            local eT = ghost:CreateTexture(nil, "ARTWORK")
            eT:SetTexture("Interface\\Buttons\\WHITE8X8") eT:SetVertexColor(1,1,1,0.06) eT:SetHeight(1)
            eT:SetPoint("TOPLEFT",ghost,"TOPLEFT",0,0) eT:SetPoint("TOPRIGHT",ghost,"TOPRIGHT",0,0)
            -- Bottom edge
            local eB = ghost:CreateTexture(nil, "ARTWORK")
            eB:SetTexture("Interface\\Buttons\\WHITE8X8") eB:SetVertexColor(1,1,1,0.06) eB:SetHeight(1)
            eB:SetPoint("BOTTOMLEFT",ghost,"BOTTOMLEFT",0,0) eB:SetPoint("BOTTOMRIGHT",ghost,"BOTTOMRIGHT",0,0)
            -- Left edge
            local eL = ghost:CreateTexture(nil, "ARTWORK")
            eL:SetTexture("Interface\\Buttons\\WHITE8X8") eL:SetVertexColor(1,1,1,0.06) eL:SetWidth(1)
            eL:SetPoint("TOPLEFT",ghost,"TOPLEFT",0,0) eL:SetPoint("BOTTOMLEFT",ghost,"BOTTOMLEFT",0,0)
            -- Right edge
            local eR = ghost:CreateTexture(nil, "ARTWORK")
            eR:SetTexture("Interface\\Buttons\\WHITE8X8") eR:SetVertexColor(1,1,1,0.06) eR:SetWidth(1)
            eR:SetPoint("TOPRIGHT",ghost,"TOPRIGHT",0,0) eR:SetPoint("BOTTOMRIGHT",ghost,"BOTTOMRIGHT",0,0)
        end
    end

    for i = 8, 1, -1 do
        local r, l, t, b = RaidAssignments:GetMarkPos(i)
        local icon = CreateFrame("Frame", "T"..i, self.bg)
        icon:SetWidth(ICON_SIZE)
        icon:SetHeight(ICON_SIZE)
        -- Row position: mark 8 -> row 0 (top), mark 1 -> row 7
        local row = 8 - i
        icon:SetPoint("TOPLEFT", self.bg, "TOPLEFT", ICON_X_TANK, COL_TOP - (row * ROW_H))
        icon:SetFrameStrata("FULLSCREEN")
        icon:EnableMouse(true)
        icon:SetScript("OnEnter", function() RaidAssignments:OpenToolTip(this:GetName()) end)
        icon:SetScript("OnLeave", function() end)
        icon.Icon = icon:CreateTexture(nil, "ARTWORK")
        icon.Icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        icon.Icon:SetTexCoord(r, l, t, b)
        icon.Icon:SetAllPoints(icon)
        MakeEmptySlots(icon, 4)  -- 4 tank slots per mark
    end

    -- -- "CURSES" sub-header -- mirrors MakeColumnHeader exactly --------------
    -- Bar top sits 8px below the last tank icon row
    local CURSE_BAR_Y = COL_TOP - (8 * ROW_H) - 8

    local curseHeaderBar = self.bg:CreateTexture(nil, "BACKGROUND")
    curseHeaderBar:SetTexture("Interface\\Buttons\\WHITE8X8")
    curseHeaderBar:SetVertexColor(0.10, 0.10, 0.13, 1)
    curseHeaderBar:SetWidth(385)
    curseHeaderBar:SetHeight(20)
    curseHeaderBar:SetPoint("TOPLEFT", self.bg, "TOPLEFT", ICON_X_TANK, CURSE_BAR_Y)

    -- Accent line 26px below bar top (same relative gap as TANKS/HEALERS: bar at -48, accent at -74)
    local curseAccent = self.bg:CreateTexture(nil, "ARTWORK")
    curseAccent:SetTexture("Interface\\Buttons\\WHITE8X8")
    curseAccent:SetVertexColor(0.58, 0.30, 0.80, 0.8)
    curseAccent:SetWidth(385)
    curseAccent:SetHeight(1)
    curseAccent:SetPoint("TOPLEFT", self.bg, "TOPLEFT", ICON_X_TANK, CURSE_BAR_Y - 26)

    local curseLabel = self.bg:CreateFontString(nil, "OVERLAY")
    curseLabel:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 11)
    curseLabel:SetTextColor(0.65, 0.45, 0.80, 1)
    curseLabel:SetText("CURSES")
    curseLabel:SetPoint("LEFT", curseHeaderBar, "LEFT", 8, 0)

    -- First curse icon 16px below the accent line (same gap as COL_TOP uses)
    local CURSE_OFFSET = CURSE_BAR_Y - 26 - 16

    -- Rows 9-12: Warlock curse icons (4 rows below the CURSES header)
    -- Display reversed: index 12 at top, 9 at bottom
    for i = 12, 9, -1 do
        local data = RaidAssignments.WarlockMarks[i]
        local icon = CreateFrame("Frame", "T"..i, self.bg)
        icon:SetWidth(ICON_SIZE)
        icon:SetHeight(ICON_SIZE)
        local curseRow = (12 - i)  -- 12->0, 11->1, 10->2, 9->3
        icon:SetPoint("TOPLEFT", self.bg, "TOPLEFT", ICON_X_TANK, CURSE_OFFSET - (curseRow * ROW_H))
        icon:SetFrameStrata("FULLSCREEN")
        icon:EnableMouse(true)
        icon:SetScript("OnEnter", function() RaidAssignments:OpenToolTip(this:GetName()) end)
        icon:SetScript("OnLeave", function() end)
        icon.Icon = icon:CreateTexture(nil, "ARTWORK")
        icon.Icon:SetTexture(data.icon)
        icon.Icon:SetAllPoints(icon)
        MakeEmptySlots(icon, 1)  -- 1 warlock slot per curse mark
    end

    -- -- Healer mark icons (right column) -----------------------------------
    -- Rows 1-8: flat colored label pills
    -- Rows 9-12: directional icons from assets
    local directionIcons = {
        [9]  = "Interface\\AddOns\\RaidAssignments\\assets\\South.tga",
        [10] = "Interface\\AddOns\\RaidAssignments\\assets\\North.tga",
        [11] = "Interface\\AddOns\\RaidAssignments\\assets\\Right.tga",
        [12] = "Interface\\AddOns\\RaidAssignments\\assets\\Left.tga",
    }
    -- Display order top->bottom: 1,2,3,4,A,B,C,D then North,South,Left,Right
    -- HealRealMarks: [8]="1",[7]="2",[6]="3",[5]="4",[4]="A",[3]="B",[2]="C",[1]="D"
    -- Direction:     [10]=North, [9]=South, [12]=Left, [11]=Right
    local healDisplayOrder = {8, 7, 6, 5, 4, 3, 2, 1, 10, 9, 12, 11}

    for row = 0, 11 do
        local i = healDisplayOrder[row + 1]
        local icon = CreateFrame("Frame", "H"..i, self.bg)
        icon:SetWidth(ICON_SIZE)
        icon:SetHeight(ICON_SIZE)
        -- Add 12px gap between groups: 0-3=1234, 4-7=ABCD, 8-11=arrows
        local groupGap = 0
        if row >= 4 then groupGap = groupGap + 14 end
        if row >= 8 then groupGap = groupGap + 14 end
        icon:SetPoint("TOPLEFT", self.bg, "TOPLEFT", ICON_X_HEAL, COL_TOP - (row * ROW_H) - groupGap)
        icon:SetFrameStrata("FULLSCREEN")
        icon:EnableMouse(true)
        icon:SetScript("OnEnter", function() RaidAssignments:OpenHealToolTip(this:GetName()) end)
        icon:SetScript("OnLeave", function() end)

        if directionIcons[i] then
            -- Use .tga direction icon for South/North/Right/Left
            icon.Icon = icon:CreateTexture(nil, "ARTWORK")
            icon.Icon:SetTexture(directionIcons[i])
            icon.Icon:SetAllPoints(icon)
        else
            -- Use .tga asset icon for 1/2/3/4/A/B/C/D
            local assetName = RaidAssignments.HealRealMarks[i] or tostring(i)
            local assetPath = "Interface\\AddOns\\RaidAssignments\\assets\\" .. assetName .. ".tga"
            icon.Icon = icon:CreateTexture(nil, "ARTWORK")
            icon.Icon:SetTexture(assetPath)
            icon.Icon:SetAllPoints(icon)
        end
        MakeEmptySlots(icon, 6)  -- 6 healer slots per mark
    end

    -- -- Mousewheel scaling on the main frame ---------------------------------
    self.bg:EnableMouseWheel(true)
    self.bg:SetScript("OnMouseWheel", function()
        local delta = arg1
        local currentScale = RaidAssignments:GetScale()
        local newScale
        if delta > 0 then
            newScale = math.min(currentScale + 0.05, 2.0)
        else
            newScale = math.max(currentScale - 0.05, 0.5)
        end
        RaidAssignments:SetScale(newScale)
        RaidAssignments_Settings["UIScale"] = newScale
    end)

    -- -- Confirm dialog helper -------------------------------------------------
    local function ShowConfirmDialog(msg, onConfirm)
        local d = CreateFrame("Frame", nil, UIParent)
        d:SetFrameStrata("FULLSCREEN_DIALOG")
        d:SetWidth(280)
        d:SetHeight(100)
        d:SetPoint("CENTER", 0, 0)
        d:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = {left=0,right=0,top=0,bottom=0}
        })
        d:SetBackdropColor(0.07, 0.06, 0.04, 0.98)
        d:SetBackdropBorderColor(0.72, 0.55, 0.15, 1)

        local label = d:CreateFontString(nil, "OVERLAY")
        label:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 13)
        label:SetTextColor(0.92, 0.85, 0.60, 1)
        label:SetText(msg)
        label:SetPoint("TOP", d, "TOP", 0, -18)

        local yes = RaidAssignments:MakeBtn(d, 90, 26, "Confirm", function()
            d:Hide()
            onConfirm()
        end)
        yes:SetPoint("BOTTOMRIGHT", d, "BOTTOM", -6, 12)

        local no = RaidAssignments:MakeBtn(d, 90, 26, "Cancel", function()
            d:Hide()
        end)
        no:SetPoint("BOTTOMLEFT", d, "BOTTOM", 6, 12)
        -- tint Cancel slightly red
        for _, ln in ipairs(no.borderLines) do ln:SetVertexColor(0.6, 0.2, 0.2, 1) end
        no.label:SetTextColor(0.85, 0.40, 0.40, 1)
        no:SetScript("OnEnter", function()
            no.glow:Show()
            for _, ln in ipairs(no.borderLines) do ln:SetVertexColor(0.9, 0.3, 0.3, 1) end
            no.label:SetTextColor(1, 0.55, 0.55, 1)
        end)
        no:SetScript("OnLeave", function()
            no.glow:Hide()
            for _, ln in ipairs(no.borderLines) do ln:SetVertexColor(0.6, 0.2, 0.2, 1) end
            no.label:SetTextColor(0.85, 0.40, 0.40, 1)
        end)
        d:Show()
    end

    -- -- Close / Your Mark / Reset / Reset All (title bar area) ------
    self.CloseButton = RaidAssignments:MakeBtn(self.bg, 22, 22, "X", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        RaidAssignments.ToolTip:Hide()
        RaidAssignments.HealToolTip:Hide()
        RaidAssignments.Settings["Animation"] = true
        RaidAssignments.Settings["MainFrame"] = false
    end)
    self.CloseButton.label:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 13)
    self.CloseButton.label:SetTextColor(0.90, 0.35, 0.35, 1)
    -- Red border tint on close button
    for _, ln in ipairs(self.CloseButton.borderLines) do ln:SetVertexColor(0.6, 0.2, 0.2, 1) end
    self.CloseButton:SetScript("OnEnter", function()
        self.CloseButton.glow:Show()
        for _, ln in ipairs(self.CloseButton.borderLines) do ln:SetVertexColor(0.9, 0.3, 0.3, 1) end
        self.CloseButton.label:SetTextColor(1, 0.55, 0.55, 1)
    end)
    self.CloseButton:SetScript("OnLeave", function()
        self.CloseButton.glow:Hide()
        for _, ln in ipairs(self.CloseButton.borderLines) do ln:SetVertexColor(0.6, 0.2, 0.2, 1) end
        self.CloseButton.label:SetTextColor(0.90, 0.35, 0.35, 1)
    end)
    self.CloseButton:SetPoint("TOPRIGHT", self.bg, "TOPRIGHT", -4, -4)
    self.CloseButton:SetFrameStrata("FULLSCREEN")

    self.yourMarkToggle = RaidAssignments:MakeBtn(self.bg, 80, 22, "Your Mark", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        local mf = RaidAssignments.YourMarkFrame
        local cf = RaidAssignments.YourCurseFrame
        RaidAssignments_Settings["showYourMarkFrame"] = not RaidAssignments_Settings["showYourMarkFrame"]
        if RaidAssignments_Settings["showYourMarkFrame"] then
            RaidAssignments:UpdateYourMarkFrame()
            RaidAssignments:UpdateYourCurseFrame()
        else
            if mf then mf:Hide() end
            if cf then cf:Hide() end
        end
        RaidAssignments:UpdateYourMarkToggleState()
    end)
    self.yourMarkToggle:SetPoint("RIGHT", self.CloseButton, "LEFT", -8, 0)
    RaidAssignments._yourMarkToggle = self.yourMarkToggle
    -- Apply initial visual state (ON by default)
    RaidAssignments:UpdateYourMarkToggleState()

    -- Sound toggle button: sits immediately left of the Your Mark button
    self.markSoundToggle = RaidAssignments:MakeBtn(self.bg, 22, 22, "S", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        RaidAssignments_Settings["markSound"] = not RaidAssignments_Settings["markSound"]
        RaidAssignments:UpdateMarkSoundToggleState()
        -- Also update the mark frame's own sound button label if it exists
        if RaidAssignments.YourMarkFrame and RaidAssignments.YourMarkFrame.soundBtn then
            local sBtn = RaidAssignments.YourMarkFrame.soundBtn
            if RaidAssignments_Settings["markSound"] then
                sBtn.label:SetText("|cff88ff88S|r")
            else
                sBtn.label:SetText("|cffff5555M|r")
            end
        end
    end)
    self.markSoundToggle:SetPoint("RIGHT", self.yourMarkToggle, "LEFT", -4, 0)
    RaidAssignments._markSoundToggle = self.markSoundToggle
    RaidAssignments:UpdateMarkSoundToggleState()
    self.markSoundToggle:SetScript("OnEnter", function()
        self.markSoundToggle.glow:Show()
        if RaidAssignments_Settings["markSound"] then
            for _, ln in ipairs(self.markSoundToggle.borderLines) do ln:SetVertexColor(0.40, 1.00, 0.55, 1) end
        else
            for _, ln in ipairs(self.markSoundToggle.borderLines) do ln:SetVertexColor(0.95, 0.80, 0.30, 1) end
        end
        self.markSoundToggle.label:SetTextColor(1, 0.95, 0.50, 1)
        GameTooltip:SetOwner(self.markSoundToggle, "ANCHOR_BOTTOM")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Mark Assignment Sound", 1, 1, 0.5)
        if RaidAssignments_Settings["markSound"] then
            GameTooltip:AddLine("Currently: ON  (click to mute)", 0.4, 1, 0.55)
        else
            GameTooltip:AddLine("Currently: OFF  (click to unmute)", 1, 0.45, 0.35)
        end
        GameTooltip:Show()
    end)
    self.markSoundToggle:SetScript("OnLeave", function()
        self.markSoundToggle.glow:Hide()
        RaidAssignments:UpdateMarkSoundToggleState()
        GameTooltip:Hide()
    end)

    self.yourMarkToggle:SetScript("OnEnter", function()
        self.yourMarkToggle.glow:Show()
        if RaidAssignments_Settings["showYourMarkFrame"] then
            for _, ln in ipairs(self.yourMarkToggle.borderLines) do ln:SetVertexColor(0.40, 1.00, 0.55, 1) end
        else
            for _, ln in ipairs(self.yourMarkToggle.borderLines) do ln:SetVertexColor(0.95, 0.80, 0.30, 1) end
        end
        self.yourMarkToggle.label:SetTextColor(1, 0.95, 0.50, 1)
        GameTooltip:SetOwner(self.yourMarkToggle, "ANCHOR_BOTTOM")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Your Mark / Curse Frame", 1, 1, 0.5)
        if RaidAssignments_Settings["showYourMarkFrame"] then
            GameTooltip:AddLine("Currently: ON  (click to hide)", 0.4, 1, 0.55)
        else
            GameTooltip:AddLine("Currently: OFF  (click to show)", 1, 0.45, 0.35)
        end
        GameTooltip:Show()
    end)
    self.yourMarkToggle:SetScript("OnLeave", function()
        self.yourMarkToggle.glow:Hide()
        RaidAssignments:UpdateYourMarkToggleState()
        GameTooltip:Hide()
    end)

    self.resetAllButton = RaidAssignments:MakeBtn(self.bg, 76, 22, "Reset", function()
        ShowConfirmDialog("Reset tanks & heals?", function()
            PlaySound("igMainMenuOptionCheckBoxOn")
            for i = 1, 12 do
                RaidAssignments.Marks[i] = {}
                for k, v in pairs(RaidAssignments.Frames[i]) do
                    if v:IsVisible() then v:Hide() end
                end
            end
            for i = 1, 12 do
                for k = 1, 6 do RaidAssignments.HealMarks[i][k] = nil end
                for k, v in pairs(RaidAssignments.HealFrames[i]) do
                    if v:IsVisible() then v:Hide() end
                end
            end
            RaidAssignments:UpdateTanks()
            RaidAssignments:UpdateHeals()
            RaidAssignments:SendTanks()
            RaidAssignments:SendHeals()
            DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments|r: Tank and heal assignments cleared")
        end)
    end)
    self.resetAllButton:SetPoint("RIGHT", self.markSoundToggle, "LEFT", -8, 0)

    self.masterResetButton = RaidAssignments:MakeBtn(self.bg, 88, 22, "Reset All", function()
        ShowConfirmDialog("Reset ALL assignments?", function()
            PlaySound("igMainMenuOptionCheckBoxOn")
            for i = 1, 12 do
                RaidAssignments.Marks[i] = {}
                for k, v in pairs(RaidAssignments.Frames[i]) do
                    if v:IsVisible() then v:Hide() end
                end
            end
            for i = 1, 12 do
                for k = 1, 6 do RaidAssignments.HealMarks[i][k] = nil end
                for k, v in pairs(RaidAssignments.HealFrames[i]) do
                    if v:IsVisible() then v:Hide() end
                end
            end
            for i = 1, 10 do
                local maxSlots = (i >= 9 and i <= 10) and 7 or 5
                for k = 1, maxSlots do RaidAssignments.GeneralMarks[i][k] = nil end
                for k, v in pairs(RaidAssignments.GeneralFrames[i]) do
                    if v:IsVisible() then v:Hide() end
                end
            end
            RaidAssignments:UpdateTanks()
            RaidAssignments:UpdateHeals()
            RaidAssignments:UpdateGeneral()
            RaidAssignments:SendTanks()
            RaidAssignments:SendHeals()
            RaidAssignments:SendGeneral()
            DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments|r: All assignments cleared")
        end)
    end)
    self.masterResetButton:SetPoint("RIGHT", self.resetAllButton, "LEFT", -6, 0)

    -- -- Bottom button layout ------------------------------------------------
    -- Row 1 (y=46, centered): Post Tanks | Post Healers | Post Curses | Post All | General
    -- Row 2 (y=14, centered): C1-C8 | KT | 4H | C'Thun
    -- Frame width = 960. Row1: 5x160px + 4x8px = 832px -> x_start = (960-832)/2 = 64
    -- Row2: 11x76px + 10x8px = 836+80 = 916px -> x_start = (960-916)/2 = 22

    local ROW1_W    = 160
    local ROW1_GAP  = 8
    local ROW1_TOTAL = 5 * ROW1_W + 4 * ROW1_GAP   -- 832
    local ROW1_X    = math.floor((960 - ROW1_TOTAL) / 2)  -- 64
    local ROW1_Y    = 46

    local ROW2_W    = 76
    local ROW2_GAP  = 8
    local ROW2_TOTAL = 11 * ROW2_W + 10 * ROW2_GAP  -- 916
    local ROW2_X    = math.floor((960 - ROW2_TOTAL) / 2)  -- 22
    local ROW2_Y    = 14

    -- Row 1 buttons -- Post buttons get a cyan tint to visually distinguish them
    local function TintCyan(btn)
        for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(0.15, 0.65, 0.80, 1) end
        btn.label:SetTextColor(0.40, 0.85, 0.95, 1)
        btn:SetScript("OnEnter", function()
            btn.glow:Show()
            btn.glow:SetVertexColor(0.10, 0.50, 0.70, 0.25)
            for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(0.25, 0.85, 1.0, 1) end
            btn.label:SetTextColor(0.70, 1.0, 1.0, 1)
        end)
        btn:SetScript("OnLeave", function()
            btn.glow:Hide()
            for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(0.15, 0.65, 0.80, 1) end
            btn.label:SetTextColor(0.40, 0.85, 0.95, 1)
        end)
    end

    self.tankButton = RaidAssignments:MakeBtn(self.bg, ROW1_W, 24, "Post Tanks", function()
        if IsRaidOfficer() then
            PlaySound("igMainMenuOptionCheckBoxOn")
            RaidAssignments:PostRaidAssignments()
        end
    end)
    self.tankButton:SetPoint("BOTTOMLEFT", self.bg, "BOTTOMLEFT", ROW1_X, ROW1_Y)
    self.tankButton:SetFrameStrata("FULLSCREEN")
    TintCyan(self.tankButton)

    self.healButton = RaidAssignments:MakeBtn(self.bg, ROW1_W, 24, "Post Healers", function()
        if IsRaidOfficer() then
            PlaySound("igMainMenuOptionCheckBoxOn")
            RaidAssignments:PostHealAssignments()
        end
    end)
    self.healButton:SetPoint("LEFT", self.tankButton, "RIGHT", ROW1_GAP, 0)
    self.healButton:SetFrameStrata("FULLSCREEN")
    TintCyan(self.healButton)

    self.cursesButton = RaidAssignments:MakeBtn(self.bg, ROW1_W, 24, "Post Curses", function()
        if IsRaidOfficer() then
            PlaySound("igMainMenuOptionCheckBoxOn")
            RaidAssignments:PostCurses()
        end
    end)
    self.cursesButton:SetPoint("LEFT", self.healButton, "RIGHT", ROW1_GAP, 0)
    TintCyan(self.cursesButton)

    self.dbutton = RaidAssignments:MakeBtn(self.bg, ROW1_W, 24, "Post All", function()
        if IsRaidOfficer() then
            PlaySound("igMainMenuOptionCheckBoxOn")
            RaidAssignments:PostAssignments()
        end
    end)
    self.dbutton:SetPoint("LEFT", self.cursesButton, "RIGHT", ROW1_GAP, 0)
    self.dbutton:SetFrameStrata("FULLSCREEN")
    TintCyan(self.dbutton)

    self.generalButton = RaidAssignments:MakeBtn(self.bg, ROW1_W, 24, "General Assignments", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        RaidAssignments.ToolTip:Hide()
        RaidAssignments.HealToolTip:Hide()
        RaidAssignments.Settings["Animation"] = true
        RaidAssignments.Settings["MainFrame"] = false
        RaidAssignments.Settings["GeneralAnimation"] = false
        RaidAssignments.Settings["GeneralFrame"] = false
        RaidAssignments.Settings["GeneralSizeX"] = 0
        RaidAssignments.Settings["GeneralSizeY"] = 0
        RaidAssignments.GeneralAssignments:Show()
    end)
    self.generalButton.label:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 10)
    self.generalButton:SetPoint("LEFT", self.dbutton, "RIGHT", ROW1_GAP, 0)

    -- Row 2: KT / 4H / C'Thun at the right end, C1-C8 fill the left (via CreateCustomAssignmentButtons)
    self.cthunButton = RaidAssignments:MakeBtn(self.bg, ROW2_W, 24, "C'Thun", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        if not RaidAssignments.CthunFrame then
            RaidAssignments.CthunFrame = CreateFrame("Frame", "RaidAssignmentsCthunFrame", UIParent)
            RaidAssignments.CthunFrame:SetFrameStrata("FULLSCREEN")
            RaidAssignments.CthunFrame:SetWidth(512)
            RaidAssignments.CthunFrame:SetHeight(512)
            RaidAssignments.CthunFrame:SetPoint("CENTER", 0, 0)
            RaidAssignments.CthunFrame:EnableMouse(true)
            RaidAssignments.CthunFrame:SetMovable(true)
            RaidAssignments.CthunFrame:RegisterForDrag("LeftButton")
            RaidAssignments.CthunFrame:SetScript("OnDragStart", function() this:StartMoving() end)
            RaidAssignments.CthunFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
            RaidAssignments.CthunFrame.texture = RaidAssignments.CthunFrame:CreateTexture(nil, "ARTWORK")
            RaidAssignments.CthunFrame.texture:SetAllPoints(RaidAssignments.CthunFrame)
            RaidAssignments.CthunFrame.texture:SetTexture("Interface\\AddOns\\RaidAssignments\\assets\\CThun.tga")
            RaidAssignments.CthunFrame.close = CreateFrame("Button", nil, RaidAssignments.CthunFrame, "UIPanelCloseButton")
            RaidAssignments.CthunFrame.close:SetPoint("TOPRIGHT", RaidAssignments.CthunFrame, "TOPRIGHT")
            RaidAssignments.CthunFrame.close:SetScript("OnClick", function() RaidAssignments.CthunFrame:Hide() end)
            RaidAssignments.CthunFrame:Hide()
        end
        if RaidAssignments.CthunFrame:IsShown() then RaidAssignments.CthunFrame:Hide()
        else RaidAssignments.CthunFrame:Show() end
    end)
    self.cthunButton:SetPoint("BOTTOMLEFT", self.bg, "BOTTOMLEFT", ROW2_X + 10 * (ROW2_W + ROW2_GAP), ROW2_Y)

    self.fourhButton = RaidAssignments:MakeBtn(self.bg, ROW2_W, 24, "4H", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        if not RaidAssignments.FourHFrame then
            RaidAssignments.FourHFrame = CreateFrame("Frame", "RaidAssignmentsFourHFrame", UIParent)
            RaidAssignments.FourHFrame:SetFrameStrata("FULLSCREEN")
            RaidAssignments.FourHFrame:SetWidth(512)
            RaidAssignments.FourHFrame:SetHeight(512)
            RaidAssignments.FourHFrame:SetPoint("CENTER", 0, 0)
            RaidAssignments.FourHFrame:EnableMouse(true)
            RaidAssignments.FourHFrame:SetMovable(true)
            RaidAssignments.FourHFrame:RegisterForDrag("LeftButton")
            RaidAssignments.FourHFrame:SetScript("OnDragStart", function() this:StartMoving() end)
            RaidAssignments.FourHFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
            RaidAssignments.FourHFrame.texture = RaidAssignments.FourHFrame:CreateTexture(nil, "ARTWORK")
            RaidAssignments.FourHFrame.texture:SetAllPoints(RaidAssignments.FourHFrame)
            RaidAssignments.FourHFrame.texture:SetTexture("Interface\\AddOns\\RaidAssignments\\assets\\4H.tga")
            RaidAssignments.FourHFrame.close = CreateFrame("Button", nil, RaidAssignments.FourHFrame, "UIPanelCloseButton")
            RaidAssignments.FourHFrame.close:SetPoint("TOPRIGHT", RaidAssignments.FourHFrame, "TOPRIGHT")
            RaidAssignments.FourHFrame.close:SetScript("OnClick", function() RaidAssignments.FourHFrame:Hide() end)
            RaidAssignments.FourHFrame:Hide()
        end
        if RaidAssignments.FourHFrame:IsShown() then RaidAssignments.FourHFrame:Hide()
        else RaidAssignments.FourHFrame:Show() end
    end)
    self.fourhButton:SetPoint("BOTTOMLEFT", self.bg, "BOTTOMLEFT", ROW2_X + 9 * (ROW2_W + ROW2_GAP), ROW2_Y)

    self.ktButton = RaidAssignments:MakeBtn(self.bg, ROW2_W, 24, "KT", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        if not RaidAssignments.KTFrame then
            RaidAssignments.KTFrame = CreateFrame("Frame", "RaidAssignmentsKTFrame", UIParent)
            RaidAssignments.KTFrame:SetFrameStrata("FULLSCREEN")
            RaidAssignments.KTFrame:SetWidth(512)
            RaidAssignments.KTFrame:SetHeight(512)
            RaidAssignments.KTFrame:SetPoint("CENTER", 0, 0)
            RaidAssignments.KTFrame:EnableMouse(true)
            RaidAssignments.KTFrame:SetMovable(true)
            RaidAssignments.KTFrame:RegisterForDrag("LeftButton")
            RaidAssignments.KTFrame:SetScript("OnDragStart", function() this:StartMoving() end)
            RaidAssignments.KTFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
            RaidAssignments.KTFrame.texture = RaidAssignments.KTFrame:CreateTexture(nil, "ARTWORK")
            RaidAssignments.KTFrame.texture:SetAllPoints(RaidAssignments.KTFrame)
            RaidAssignments.KTFrame.texture:SetTexture("Interface\\AddOns\\RaidAssignments\\assets\\KT.tga")
            RaidAssignments.KTFrame.close = CreateFrame("Button", nil, RaidAssignments.KTFrame, "UIPanelCloseButton")
            RaidAssignments.KTFrame.close:SetPoint("TOPRIGHT", RaidAssignments.KTFrame, "TOPRIGHT")
            RaidAssignments.KTFrame.close:SetScript("OnClick", function() RaidAssignments.KTFrame:Hide() end)
            RaidAssignments.KTFrame:Hide()
        end
        if RaidAssignments.KTFrame:IsShown() then RaidAssignments.KTFrame:Hide()
        else RaidAssignments.KTFrame:Show() end
    end)
    self.ktButton:SetPoint("BOTTOMLEFT", self.bg, "BOTTOMLEFT", ROW2_X + 8 * (ROW2_W + ROW2_GAP), ROW2_Y)

	-- Initialize GeneralToolTip Frame
    RaidAssignments.GeneralToolTip:SetFrameStrata("FULLSCREEN")
    RaidAssignments.GeneralToolTip:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    RaidAssignments.GeneralToolTip:SetBackdropColor(0.07, 0.07, 0.10, 0.97)
    RaidAssignments.GeneralToolTip:SetBackdropBorderColor(0.2, 0.8, 0.9, 0.8)
    RaidAssignments.GeneralToolTip:EnableMouse(true)
    RaidAssignments.GeneralToolTip:EnableMouseWheel(true)
    RaidAssignments.GeneralToolTip:Hide()

    -- Set up hide behavior for GeneralToolTip
    RaidAssignments.GeneralToolTip:SetScript("OnHide", function()
        this.isVisible = false
        this.hideTimer = nil
        this:SetScript("OnUpdate", nil)
    end)

    -- Tooltips should be on HIGHER strata than main frames
    RaidAssignments.ToolTip:SetFrameStrata("FULLSCREEN")
    RaidAssignments.HealToolTip:SetFrameStrata("FULLSCREEN")
    RaidAssignments.GeneralToolTip:SetFrameStrata("FULLSCREEN")

    -- Main frames should be on LOWER strata than tooltips
    RaidAssignments:SetFrameStrata("DIALOG")
    RaidAssignments.GeneralAssignments:SetFrameStrata("DIALOG")

    -- Initialize custom frames strata if they exist
    for i = 1, 8 do
        if RaidAssignments.CustomFrames[i] and RaidAssignments.CustomFrames[i].frame then
            RaidAssignments.CustomFrames[i].frame:SetFrameStrata("DIALOG")
        end
    end

    -- (Scale buttons are now defined above, anchored to CloseButton)


    self.bg:Hide()
    self:Hide()
    RaidAssignments.Settings["MainFrame"] = false
    RaidAssignments.Settings["SizeX"] = 0
    RaidAssignments.Settings["SizeY"] = 0
    self:CreateCustomAssignmentButtons()

    -- Compositions panel toggle button (defined in RaidCompositions.lua)
    RaidAssignments:CreateCompositionsButton()
end

function RaidAssignments:ConfigGeneralFrame()
    RaidAssignments.GeneralDrag = {}
    function RaidAssignments.GeneralDrag:StartMoving()
        RaidAssignments.GeneralAssignments:StartMoving()
        this.drag = true
    end

    function RaidAssignments.GeneralDrag:StopMovingOrSizing()
        RaidAssignments.GeneralAssignments:StopMovingOrSizing()
        this.drag = false
    end

    local backdrop = {
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 }
    }

    RaidAssignments.GeneralAssignments:SetFrameStrata("DIALOG")
    RaidAssignments.GeneralAssignments:SetWidth(RaidAssignments.Settings["GeneralFrameX"])
    RaidAssignments.GeneralAssignments:SetHeight(RaidAssignments.Settings["GeneralFrameY"])
    RaidAssignments.GeneralAssignments:SetPoint("CENTER", 0, 60)
    RaidAssignments.GeneralAssignments:SetMovable(true)
    RaidAssignments.GeneralAssignments:EnableMouse(true)
    RaidAssignments.GeneralAssignments:RegisterForDrag("LeftButton")
    RaidAssignments.GeneralAssignments:SetBackdrop(backdrop)
    RaidAssignments.GeneralAssignments:SetBackdropColor(0.07, 0.07, 0.09, 0.97)
    RaidAssignments.GeneralAssignments:SetBackdropBorderColor(0.15, 0.15, 0.18, 1)

    RaidAssignments.GeneralAssignments:SetScript("OnUpdate", function()
        if RaidAssignments.GeneralAssignments:IsVisible() then
            if not RaidAssignments.Settings["GeneralFrame"] then
                RaidAssignments.Settings["GeneralFrame"] = true
                RaidAssignments.GeneralAssignments:SetWidth(RaidAssignments.Settings["GeneralFrameX"])
                RaidAssignments.GeneralAssignments:SetHeight(RaidAssignments.Settings["GeneralFrameY"])
                self.generalBg:SetWidth(RaidAssignments.GeneralAssignments:GetWidth())
                self.generalBg:SetHeight(RaidAssignments.GeneralAssignments:GetHeight())
                RaidAssignments.generalBg:Show()
                RaidAssignments:UpdateGeneral()
            elseif RaidAssignments.Settings["GeneralAnimation"] then
                RaidAssignments.Settings["GeneralFrame"] = false
                RaidAssignments.Settings["GeneralAnimation"] = false
                RaidAssignments.generalBg:Hide()
                RaidAssignments.GeneralAssignments:Hide()
            end
        end
    end)

    self.generalBg = CreateFrame("Button", "generalBg", RaidAssignments.GeneralAssignments)
    self.generalBg:SetWidth(RaidAssignments.GeneralAssignments:GetWidth())
    self.generalBg:SetHeight(RaidAssignments.GeneralAssignments:GetHeight()) 
    self.generalBg:SetPoint("TOPLEFT",0,0)
    self.generalBg:SetBackdropColor(0,0,0,1)
    self.generalBg:EnableMouse(true)
    self.generalBg:SetMovable(true)
    self.generalBg:RegisterForDrag("LeftButton")
    self.generalBg:SetScript("OnDragStart", RaidAssignments.GeneralDrag.StartMoving)
    self.generalBg:SetScript("OnDragStop", RaidAssignments.GeneralDrag.StopMovingOrSizing)
    self.generalBg:SetScript("OnEnter", function() RaidAssignments.GeneralToolTip:Hide() end)

    -- Title bar strip
    local gTitleBar = self.generalBg:CreateTexture(nil, "BACKGROUND")
    gTitleBar:SetTexture("Interface\\Buttons\\WHITE8X8")
    gTitleBar:SetVertexColor(0.05, 0.05, 0.07, 1)
    gTitleBar:SetPoint("TOPLEFT",  self.generalBg, "TOPLEFT",  1, -1)
    gTitleBar:SetPoint("TOPRIGHT", self.generalBg, "TOPRIGHT", -1, -1)
    gTitleBar:SetHeight(36)

    self.generalText = self.generalBg:CreateFontString(nil, "OVERLAY")
    self.generalText:SetPoint("TOP", self.generalBg, "TOP", 0, -10)
    self.generalText:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 18)
    self.generalText:SetTextColor(0.9, 0.9, 0.95, 1)
    self.generalText:SetShadowOffset(1, -1)
    self.generalText:SetShadowColor(0, 0, 0, 1)
    self.generalText:SetText("GENERAL ASSIGNMENTS")

    -- Cyan accent line
    local gAccentLine = self.generalBg:CreateTexture(nil, "ARTWORK")
    gAccentLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    gAccentLine:SetVertexColor(0.2, 0.8, 0.9, 0.9)
    gAccentLine:SetHeight(2)
    gAccentLine:SetPoint("TOPLEFT",  self.generalBg, "TOPLEFT",  1, -37)
    gAccentLine:SetPoint("TOPRIGHT", self.generalBg, "TOPRIGHT", -1, -37)

    local CLASS_ICON_SIZE_G = 19
    local CLASS_ICON_GAP_G  = 4
    local classIconStartX, classIconY, i = 8, -6, 1
    for n, class in pairs(RaidAssignments.Classes) do
        local r, l, t, b = RaidAssignments:ClassPos(class)
        local classframe = CreateFrame("Button", class.."_General", self.generalBg)
        classframe:SetWidth(CLASS_ICON_SIZE_G)
        classframe:SetHeight(CLASS_ICON_SIZE_G)
        classframe:SetPoint("TOPLEFT", classIconStartX + (i - 1) * (CLASS_ICON_SIZE_G + CLASS_ICON_GAP_G), classIconY)
        classframe:SetFrameStrata("DIALOG")

        local cfBg2 = classframe:CreateTexture(nil, "BACKGROUND")
        cfBg2:SetTexture("Interface\\Buttons\\WHITE8X8")
        cfBg2:SetVertexColor(0.06, 0.05, 0.03, 0.90)
        cfBg2:SetAllPoints(classframe)

        local function GCFLine() local t2 = classframe:CreateTexture(nil, "BORDER"); t2:SetTexture("Interface\\Buttons\\WHITE8X8"); return t2 end
        local cfBT = GCFLine(); local cfBB = GCFLine(); local cfBL = GCFLine(); local cfBR = GCFLine()
        cfBT:SetVertexColor(0.55, 0.42, 0.10, 1); cfBB:SetVertexColor(0.55, 0.42, 0.10, 1)
        cfBL:SetVertexColor(0.55, 0.42, 0.10, 1); cfBR:SetVertexColor(0.55, 0.42, 0.10, 1)
        cfBT:SetHeight(1); cfBT:SetPoint("TOPLEFT",classframe,"TOPLEFT",0,0);     cfBT:SetPoint("TOPRIGHT",classframe,"TOPRIGHT",0,0)
        cfBB:SetHeight(1); cfBB:SetPoint("BOTTOMLEFT",classframe,"BOTTOMLEFT",0,0); cfBB:SetPoint("BOTTOMRIGHT",classframe,"BOTTOMRIGHT",0,0)
        cfBL:SetWidth(1);  cfBL:SetPoint("TOPLEFT",classframe,"TOPLEFT",0,0);     cfBL:SetPoint("BOTTOMLEFT",classframe,"BOTTOMLEFT",0,0)
        cfBR:SetWidth(1);  cfBR:SetPoint("TOPRIGHT",classframe,"TOPRIGHT",0,0);   cfBR:SetPoint("BOTTOMRIGHT",classframe,"BOTTOMRIGHT",0,0)
        classframe.cfBorderLines = {cfBT, cfBB, cfBL, cfBR}

        local cfGlow2 = classframe:CreateTexture(nil, "ARTWORK")
        cfGlow2:SetTexture("Interface\\Buttons\\WHITE8X8")
        cfGlow2:SetVertexColor(0.80, 0.60, 0.10, 0.20)
        cfGlow2:SetAllPoints(classframe)
        cfGlow2:Hide()
        classframe.cfGlow = cfGlow2

        classframe.Icon = classframe:CreateTexture(nil, "OVERLAY")
        classframe.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        classframe.Icon:SetTexCoord(r, l, t, b)
        classframe.Icon:SetPoint("TOPLEFT", classframe, "TOPLEFT", 2, -2)
        classframe.Icon:SetPoint("BOTTOMRIGHT", classframe, "BOTTOMRIGHT", -2, 2)

        classframe:SetScript("OnEnter", function()
            classframe.cfGlow:Show()
            for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.95, 0.80, 0.30, 1) end
            local cr,cg,cb = RaidAssignments:GetClassColors(string.gsub(this:GetName(), "_General", ""),"class")
            GameTooltip:SetOwner(classframe, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText("|cffFFFFFFShow|r "..string.gsub(this:GetName(), "_General", ""), cr, cg, cb)
            GameTooltip:Show()
        end)
        classframe:SetScript("OnLeave", function()
            classframe.cfGlow:Hide()
            for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.55, 0.42, 0.10, 1) end
            GameTooltip:Hide()
        end)
        classframe:SetScript("OnMouseDown", function()
            if arg1 == "LeftButton" then
                local className = string.gsub(this:GetName(), "_General", "")
                if RaidAssignments_Settings[className] == 1 then
                    RaidAssignments_Settings[className] = 0
                    classframe.Icon:SetVertexColor(0.25, 0.25, 0.25)
                    for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.30, 0.22, 0.06, 1) end
                else
                    RaidAssignments_Settings[className] = 1
                    classframe.Icon:SetVertexColor(1.0, 1.0, 1.0)
                    for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.55, 0.42, 0.10, 1) end
                end
                RaidAssignments:SyncClassFilters()
            end
        end)
        i = i + 1
        local className = string.gsub(classframe:GetName(), "_General", "")
        if RaidAssignments_Settings[className] == nil then
            RaidAssignments_Settings[className] = 1
        end
        if RaidAssignments_Settings[className] == 1 then
            classframe.Icon:SetVertexColor(1.0, 1.0, 1.0)
        else
            classframe.Icon:SetVertexColor(0.25, 0.25, 0.25)
            for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.30, 0.22, 0.06, 1) end
        end
    end

    -- General marks 1-8 using custom .tga icons
    local padding = 5
    local function MakeGeneralEmptySlots(parent, numSlots)
        for slot = 1, numSlots do
            local ghost = CreateFrame("Frame", nil, parent)
            ghost:SetWidth(80)
            ghost:SetHeight(25)
            ghost:SetPoint("RIGHT", parent, "RIGHT", 5 + (85 * slot), 0)
            ghost:SetFrameStrata("DIALOG")
            local eT = ghost:CreateTexture(nil, "ARTWORK")
            eT:SetTexture("Interface\\Buttons\\WHITE8X8") eT:SetVertexColor(1,1,1,0.06) eT:SetHeight(1)
            eT:SetPoint("TOPLEFT",ghost,"TOPLEFT",0,0) eT:SetPoint("TOPRIGHT",ghost,"TOPRIGHT",0,0)
            local eB = ghost:CreateTexture(nil, "ARTWORK")
            eB:SetTexture("Interface\\Buttons\\WHITE8X8") eB:SetVertexColor(1,1,1,0.06) eB:SetHeight(1)
            eB:SetPoint("BOTTOMLEFT",ghost,"BOTTOMLEFT",0,0) eB:SetPoint("BOTTOMRIGHT",ghost,"BOTTOMRIGHT",0,0)
            local eL = ghost:CreateTexture(nil, "ARTWORK")
            eL:SetTexture("Interface\\Buttons\\WHITE8X8") eL:SetVertexColor(1,1,1,0.06) eL:SetWidth(1)
            eL:SetPoint("TOPLEFT",ghost,"TOPLEFT",0,0) eL:SetPoint("BOTTOMLEFT",ghost,"BOTTOMLEFT",0,0)
            local eR = ghost:CreateTexture(nil, "ARTWORK")
            eR:SetTexture("Interface\\Buttons\\WHITE8X8") eR:SetVertexColor(1,1,1,0.06) eR:SetWidth(1)
            eR:SetPoint("TOPRIGHT",ghost,"TOPRIGHT",0,0) eR:SetPoint("BOTTOMRIGHT",ghost,"BOTTOMRIGHT",0,0)
        end
    end

    for i = 1, 8 do
        local icon = CreateFrame("Frame", "G"..i, self.generalBg)
        icon:SetWidth(35)
        icon:SetHeight(35)
        icon:SetPoint("TOPLEFT", 50, -75 - ((35 + padding) * (i - 1)))
        icon:SetFrameStrata("DIALOG")
        icon:EnableMouse(true)
        icon:SetScript("OnEnter", function() RaidAssignments:OpenGeneralToolTip(this:GetName()) end)
        icon:SetScript("OnLeave", function() end)
        icon.Icon = icon:CreateTexture(nil, "ARTWORK")
        icon.Icon:SetTexture("Interface\\AddOns\\RaidAssignments\\assets\\" .. i .. ".tga")
        icon.Icon:SetPoint("CENTER", 0, 0)
        icon.Icon:SetWidth(35)
        icon.Icon:SetHeight(35)
        MakeGeneralEmptySlots(icon, 5)  -- 5 slots for regular general marks
    end

    -- Custom marks 9 and 10 with EditBox
    for i = 9, 10 do
        local icon = CreateFrame("Frame", "G"..i, self.generalBg)
        icon:SetWidth(35)
        icon:SetHeight(35)
        icon:SetPoint("TOPLEFT", 50, -75 - ((35 + padding) * (i - 1) + (i - 9) * 30))
        icon:SetFrameStrata("DIALOG")
        icon:EnableMouse(true)
        icon:SetScript("OnEnter", function()
            RaidAssignments:OpenGeneralToolTip(this:GetName())
        end)
        icon:SetScript("OnLeave", function() end)

        icon.Icon = icon:CreateTexture(nil, "ARTWORK")
        icon.Icon:SetTexture("Interface\\AddOns\\RaidAssignments\\assets\\Custom.tga")
        icon.Icon:SetPoint("CENTER", 0, 0)
        icon.Icon:SetWidth(35)
        icon.Icon:SetHeight(35)
        MakeGeneralEmptySlots(icon, 7)  -- 7 slots for custom general marks

        local editBox = RaidAssignments:MakeEditBox("G"..i.."_Edit", self.generalBg, 90, 24)
        editBox:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", -20, -5)

        local defaultText = RaidAssignments.GeneralRealMarks[i] or ("Custom " .. (i - 8))
        editBox:SetText(defaultText)

        editBox:SetScript("OnEnterPressed", function()
            local txt = this:GetText()
            if txt and txt ~= "" then
                RaidAssignments.GeneralRealMarks[i] = txt
                RaidAssignments:UpdateGeneral()
            else
                local defaultText = "Custom " .. (i - 8)
                this:SetText(defaultText)
                RaidAssignments.GeneralRealMarks[i] = defaultText
            end
            this:ClearFocus()
        end)

        editBox:SetScript("OnEscapePressed", function()
            local currentText = RaidAssignments.GeneralRealMarks[i] or ("Custom " .. (i - 8))
            this:SetText(currentText)
            this:ClearFocus()
        end)
    end

    -- === TOP-RIGHT: Close Button + Reset All Button ===
    local closeBtn = RaidAssignments:MakeBtn(self.generalBg, 22, 22, "X", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        RaidAssignments.GeneralAssignments:Hide()
        RaidAssignments.Settings["GeneralAnimation"] = true
        RaidAssignments.Settings["GeneralFrame"] = false
    end)
    closeBtn.label:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 13)
    closeBtn.label:SetTextColor(0.90, 0.35, 0.35, 1)
    for _, ln in ipairs(closeBtn.borderLines) do ln:SetVertexColor(0.6, 0.2, 0.2, 1) end
    closeBtn:SetScript("OnEnter", function()
        closeBtn.glow:Show()
        for _, ln in ipairs(closeBtn.borderLines) do ln:SetVertexColor(0.9, 0.3, 0.3, 1) end
        closeBtn.label:SetTextColor(1, 0.55, 0.55, 1)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeBtn.glow:Hide()
        for _, ln in ipairs(closeBtn.borderLines) do ln:SetVertexColor(0.6, 0.2, 0.2, 1) end
        closeBtn.label:SetTextColor(0.90, 0.35, 0.35, 1)
    end)
    closeBtn:SetPoint("TOPRIGHT", self.generalBg, "TOPRIGHT", -4, -4)
    closeBtn:SetFrameStrata("DIALOG")

    -- Reset All Button - TOP RIGHT, next to Close
    local resetBtn = RaidAssignments:MakeBtn(self.generalBg, 90, 22, "Reset All", nil)
    resetBtn:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
    resetBtn:SetFrameStrata("DIALOG")
    resetBtn:SetScript("OnClick", function()
        if IsRaidOfficer() then
            PlaySound("igMainMenuOptionCheckBoxOn")
            for i = 1, 10 do
                local maxSlots = (i >= 9 and i <= 10) and 7 or 5
                for k = 1, maxSlots do
                    RaidAssignments.GeneralMarks[i][k] = nil
                end
                for k, v in pairs(RaidAssignments.GeneralFrames[i]) do
                    if v:IsVisible() then v:Hide() end
                end
            end
            RaidAssignments:UpdateGeneral()
            RaidAssignments:SendGeneral()
            DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments|r: All general assignments cleared")
        end
    end)

    -- === BOTTOM BUTTONS ===
    local btnY = 10
    local btnSpacing = 10
    local btnStartX = -50

    -- Post General Assignments Button
    local postBtn = RaidAssignments:MakeBtn(self.generalBg, 145, 24, "Post Assignments", function()
        if IsRaidOfficer() then
            PlaySound("igMainMenuOptionCheckBoxOn")
            RaidAssignments:PostGeneralAssignments()
        end
    end)
    postBtn:SetPoint("BOTTOM", self.generalBg, "BOTTOM", btnStartX, btnY)
    postBtn:SetFrameStrata("DIALOG")

    -- Back to Main Button
    local backBtn = RaidAssignments:MakeBtn(self.generalBg, 145, 24, "Back to Main", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        RaidAssignments.GeneralAssignments:Hide()
        RaidAssignments.Settings["GeneralAnimation"] = true
        RaidAssignments.Settings["GeneralFrame"] = false
        RaidAssignments:Show()
    end)
    backBtn:SetPoint("LEFT", postBtn, "RIGHT", btnSpacing, 0)
    backBtn:SetFrameStrata("DIALOG")

    self.generalBg:Hide()
    RaidAssignments.GeneralAssignments:Hide()
end

function RaidAssignments:UpdateGeneral()
    if GetRaidRosterInfo(1) or RaidAssignments.TestMode then
        -- Initialize GeneralFrames for all marks if not already done
        for i = 1, 10 do
            if not RaidAssignments.GeneralFrames[i] then
                RaidAssignments.GeneralFrames[i] = {}
            end
        end

        -- Process each mark (1-10)
        for i = 1, 10 do
            -- Get the mark icon frame (G1 to G10)
            local iconFrame = _G["G" .. i]
            if iconFrame then
                iconFrame:Show()
            end

            -- Hide all player frames for this mark first
            for k, v in pairs(RaidAssignments.GeneralFrames[i]) do
                if v:IsVisible() then
                    v:Hide()
                end
            end

            -- Remove players no longer in raid
            local maxSlots = (i >= 9 and i <= 10) and 7 or 5  -- 7 slots for custom marks 9-10, 5 for others
            for k = 1, maxSlots do
                local v = RaidAssignments.GeneralMarks[i] and RaidAssignments.GeneralMarks[i][k]
                if v and not RaidAssignments:IsInRaid(v) then
                    RaidAssignments.GeneralMarks[i][k] = nil
                end
            end

            -- Show frames for assigned players in correct slots
            for slot = 1, maxSlots do
                local v = RaidAssignments.GeneralMarks[i] and RaidAssignments.GeneralMarks[i][slot]
                if v then
                    -- Create frame if it doesn't exist
                    if not RaidAssignments.GeneralFrames[i][v] then
                        RaidAssignments.GeneralFrames[i][v] = RaidAssignments:AddGeneralFrame(v, i)
                    end
                    local frame = RaidAssignments.GeneralFrames[i][v]
                    frame:SetPoint("RIGHT", 5 + (85 * slot), 0)
                    local r, g, b = RaidAssignments:GetClassColors(v, "rgb")
                    RA_ApplyFrameColor(frame, r, g, b)
                    frame:Show()
                end
            end
        end
    else
        -- Hide all frames and clear marks if not in raid
        for i = 1, 10 do
            local iconFrame = _G["G" .. i]
            if iconFrame then
                iconFrame:Show()
            end
            for k, v in pairs(RaidAssignments.GeneralFrames[i]) do
                if v:IsVisible() then
                    v:Hide()
                end
            end
            -- Clear all slots properly
            local maxSlots = (i >= 9 and i <= 10) and 7 or 5
            for k = 1, maxSlots do
                if RaidAssignments.GeneralMarks[i] then
                    RaidAssignments.GeneralMarks[i][k] = nil
                end
            end
        end
    end
end

function RaidAssignments:InitializeClassFilters()
    for _, class in pairs(RaidAssignments.Classes) do
        if RaidAssignments_Settings[class] == nil then
            RaidAssignments_Settings[class] = 1  -- Default to enabled
        end
    end
end

function RaidAssignments:WhisperAssignments()
    if not IsRaidOfficer() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments 2.0|r: You must be a raid officer to whisper assignments")
        return
    end
    for i = 1, 8 do
        for k, v in pairs(RaidAssignments.Marks[i]) do
            if RaidAssignments:IsInRaid(v) then
                local text = "You are assigned to tank " .. RaidAssignments.RealMarks[i] .. " (slot " .. k .. ")"
                SendChatMessage(text, "WHISPER", nil, v)
            end
        end
    end
    for i = 1, 12 do
        for k = 1, 6 do
            local v = RaidAssignments.HealMarks[i][k]
            if v and RaidAssignments:IsInRaid(v) then
                local text = "You are assigned to heal " .. RaidAssignments.HealRealMarks[i] .. " (slot " .. k .. ")"
                SendChatMessage(text, "WHISPER", nil, v)
            end
        end
    end
    for i = 1, 8 do
        for k, v in pairs(RaidAssignments.GeneralMarks[i]) do
            if RaidAssignments:IsInRaid(v) then
                local text = "You are assigned to " .. RaidAssignments.GeneralRealMarks[i] .. " (slot " .. k .. ")"
                SendChatMessage(text, "WHISPER", nil, v)
            end
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments 2.0|r: Whispered assignments to players")
end

function RaidAssignments:SetTankChannelString()
	local channelChar = self.TankChannelEditBox:GetText()
	if channelChar == "s" or channelChar == "S" then
		self.TankChannelSelectedFontString:SetText("Say")
	elseif channelChar == "r" or channelChar == "R" then
		self.TankChannelSelectedFontString:SetText("Raid")
	elseif channelChar == "p" or channelChar == "P" then
		self.TankChannelSelectedFontString:SetText("Group")
	elseif channelChar == "g" or channelChar == "G" then
		self.TankChannelSelectedFontString:SetText("Guild")
	elseif channelChar == "e" or channelChar == "E" then
		self.TankChannelSelectedFontString:SetText("Emote")
	elseif channelChar == "rw" or channelChar == "RW" then
		self.TankChannelSelectedFontString:SetText("Raid Warning")
	else
		local id, name = GetChannelName(channelChar)
		self.TankChannelSelectedFontString:SetText(name or "Unknown")
	end
end

function RaidAssignments:GetSendChannel(chanName)
	if not chanName or chanName == "" or chanName == " " then
		return nil,nil
	end
	chanName = string.lower(chanName)
	if RaidAssignments.ChanTable[chanName] then
		if type(RaidAssignments.ChanTable[chanName]) == "table" then
			local chan = RaidAssignments.ChanTable[chanName][1]
			local bla = RaidAssignments.ChanTable[chanName][2]
			return chan,bla
		else
			local chan = RaidAssignments.ChanTable[chanName]
			return chan,chanName
		end
	end
	return "WHISPER",chanName
end

function RaidAssignments:GetMarkPos(mark)
	if mark == 1 then return 0, 0.25, 0, 0.25 end
	if mark == 2 then return 0.25, 0.5, 0, 0.25 end
	if mark == 3 then return 0.5, 0.75, 0, 0.25 end
	if mark == 4 then return 0.75, 1, 0, 0.25 end
	if mark == 5 then return 0, 0.25, 0.25, 0.5 end
	if mark == 6 then return 0.25, 0.5, 0.25, 0.5 end
	if mark == 7 then return 0.5, 0.75, 0.25, 0.5 end
	if mark == 8 then return 0.75, 1, 0.25, 0.5 end
	return 0, 0.25, 0.5, 0.75 -- Returns empty next one, so blank
end

function RaidAssignments:ClassPos(class)
	if class == "Warrior" then return 0, 0.25, 0, 0.25 end
	if class == "Mage" then return 0.25, 0.5, 0, 0.25 end
	if class == "Rogue" then return 0.5, 0.75, 0, 0.25 end
	if class == "Druid" then return 0.75, 1, 0, 0.25 end
	if class == "Hunter" then return 0, 0.25, 0.25, 0.5 end
	if class == "Shaman" then return 0.25, 0.5, 0.25, 0.5 end
	if class == "Priest" then return 0.5, 0.75, 0.25, 0.5 end
	if class == "Warlock" then return 0.75, 1, 0.25, 0.5 end
	if class == "Paladin" then return 0, 0.25, 0.5, 0.75 end
end

function RaidAssignments:GetClassColors(name, color)
    if color == "rgb" then
        local class = GetCachedClass(name)
        if not class then
            -- Cache miss: fall back to direct API for the local player
            if name == UnitName("player") then class = UnitClass("player") end
        end
        if class == "Warrior" then return 0.78, 0.61, 0.43, 1
        elseif class == "Hunter"  then return 0.67, 0.83, 0.45, 1
        elseif class == "Mage"    then return 0.41, 0.80, 0.94, 1
        elseif class == "Rogue"   then return 1.00, 0.96, 0.41, 1
        elseif class == "Warlock" then return 0.58, 0.51, 0.79, 1
        elseif class == "Druid"   then return 1.00, 0.49, 0.04, 1
        elseif class == "Shaman"  then return 0.00, 0.44, 0.87, 1
        elseif class == "Priest"  then return 1.00, 1.00, 1.00, 1
        elseif class == "Paladin" then return 0.96, 0.55, 0.73, 1
        end
        return 0.8, 0.8, 0.8, 1  -- unknown class fallback

    elseif color == "cff" then
        local class = GetCachedClass(name)
        if not class then
            if name == UnitName("player") then class = UnitClass("player") end
        end
        if class == "Warrior" then return "|cffC79C6E"..name.."|r"
        elseif class == "Hunter"  then return "|cffABD473"..name.."|r"
        elseif class == "Mage"    then return "|cff69CCF0"..name.."|r"
        elseif class == "Rogue"   then return "|cffFFF569"..name.."|r"
        elseif class == "Warlock" then return "|cff9482C9"..name.."|r"
        elseif class == "Druid"   then return "|cffFF7D0A"..name.."|r"
        elseif class == "Shaman"  then return "|cff0070DE"..name.."|r"
        elseif class == "Priest"  then return "|cffFFFFFF"..name.."|r"
        elseif class == "Paladin" then return "|cffF58CBA"..name.."|r"
        end
        return name or ""  -- unknown class fallback
	elseif color == "class" then
		if (name == "Warrior") then
			return 0.78, 0.61, 0.43
		end
		if(name=="Mage") then
			return 0.41, 0.80, 0.94
		end
		if(name=="Rogue") then
			return 1.00, 0.96, 0.41
		end
		if(name=="Druid") then
			return 1, 0.49, 0.04
		end
		if(name=="Hunter") then
			return 0.67, 0.83, 0.45
		end
		if(name=="Shaman") then
			return 0.0, 0.44, 0.87
		end
		if(name=="Priest") then
			return 1.00, 1.00, 1.00
		end
		if(name=="Warlock") then
			return 0.58, 0.51, 0.79
		end
		if(name=="Paladin") then
			return 0.96, 0.55, 0.73
		end
	elseif color == "mark" then
		if name == "Skull"    then return "|cffFFFFFF"..name.."|r" end
		if name == "Cross"    then return "|cffFF0000"..name.."|r" end
		if name == "Square"   then return "|cff00B4FF"..name.."|r" end
		if name == "Moon"     then return "|cffCEECF5"..name.."|r" end
		if name == "Triangle" then return "|cff66FF00"..name.."|r" end
		if name == "Diamond"  then return "|cffCC00FF"..name.."|r" end
		if name == "Circle"   then return "|cffFF9900"..name.."|r" end
		if name == "Star"     then return "|cffFFFF00"..name.."|r" end
		-- Fallback: plain name
		return name or ""
	end
	-- Final fallback so the function never returns nil regardless of color mode
	if color == "cff" then
		return name or ""
	end
end

function RaidAssignments:IsInRaid(name)
    return RaidAssignments._rosterSet[name] == true
end

-- Restrict Curse Marks (9-12) to Warlocks only
function RaidAssignments:CanAssignToMark(mark, playerName)
    if mark >= 9 and mark <= 12 then
        -- Use roster cache for O(1) class lookup
        local playerClass = GetCachedClass(playerName)
        if not playerClass and playerName == UnitName("player") then
            playerClass = UnitClass("player")
        end
        if playerClass ~= "Warlock" then
            return false
        end
    end
    return true
end

function RaidAssignments:GetRaidID(name)
	if GetRaidRosterInfo(1) or RaidAssignments.TestMode then
		local roster = RaidAssignments.TestMode and RaidAssignments.TestRoster or {}
		local numMembers = RaidAssignments.TestMode and table.getn(RaidAssignments.TestRoster) or GetNumRaidMembers()
		for i=1,numMembers do
			local unitName
			if RaidAssignments.TestMode then
				unitName = roster[i].name
			else
				unitName = UnitName("raid"..i)
			end
			if unitName == name then
				return "raid"..i
			end
		end
	elseif GetNumPartyMembers() > 0 then
		for i=1,GetNumPartyMembers() do
			if UnitName("party"..i) == name then
				return "party"..i
			end
		end
		if UnitName("player") == name then
			return "player"
		end
	else
		if UnitName("player") == name then
			return "player"
		end
	end
	return nil
end

function RaidAssignments:UpdateTanks()
    if GetRaidRosterInfo(1) or RaidAssignments.TestMode then
        for i=1,12 do
            -- Ensure Marks[i] exists
            if not RaidAssignments.Marks[i] then
                RaidAssignments.Marks[i] = {}
            end

            -- Hide old frames
            for k,v in pairs(RaidAssignments.Frames[i]) do
                if v and v.Hide then
                    v:Hide()
                end
            end

            -- Remove players not in raid anymore, but only after a grace period.
            -- During roster events (promotions, zoning, etc.) IsInRaid() can briefly
            -- return false for players who are still in the raid. Removing them
            -- immediately and then re-broadcasting would silently delete assignments.
            -- We only remove someone if they've been "not in raid" for at least 5s.
            local maxSlots = (i <= 8) and 4 or 1
            for k=1,maxSlots do
                local v = RaidAssignments.Marks[i][k]
                if v and not RaidAssignments:IsInRaid(v) then
                    -- Track first time we noticed this player missing
                    RaidAssignments._missingPlayers = RaidAssignments._missingPlayers or {}
                    local key = i .. "_" .. k
                    if not RaidAssignments._missingPlayers[key] then
                        RaidAssignments._missingPlayers[key] = GetTime()
                    elseif (GetTime() - RaidAssignments._missingPlayers[key]) >= 5 then
                        -- They've been gone for 5+ seconds -- safe to remove
                        RaidAssignments._missingPlayers[key] = nil
                        RaidAssignments.Marks[i][k] = nil
                        if RaidAssignments.Frames[i][v] then
                            RaidAssignments.Frames[i][v]:Hide()
                            RaidAssignments.Frames[i][v] = nil
                        end
                    end
                else
                    -- Player is in raid -- clear any pending removal timer for this slot
                    if RaidAssignments._missingPlayers then
                        RaidAssignments._missingPlayers[i .. "_" .. k] = nil
                    end
                end
            end

            -- Show frames for tanks/curses in correct slots
            for slot=1,maxSlots do
                local v = RaidAssignments.Marks[i][slot]
                if v then
                    RaidAssignments.Frames[i][v] = RaidAssignments.Frames[i][v] or RaidAssignments:AddTankFrame(v,i)
                    local frame = RaidAssignments.Frames[i][v]
                    frame:SetPoint("RIGHT", 5 + (85 * slot), 0)
                    local r, g, b = RaidAssignments:GetClassColors(v, "rgb")
                    RA_ApplyFrameColor(frame, r, g, b)
                    frame:Show()
                end
            end
        end
    else
        for i=1,12 do  -- Changed from 8 to 12 to include curse marks
            -- Ensure Marks[i] exists
            if not RaidAssignments.Marks[i] then
                RaidAssignments.Marks[i] = {}
            end

            for k,v in pairs(RaidAssignments.Frames[i]) do
                if v and v:IsVisible() then
                    v:Hide()
                end
            end
            -- Clear the table properly
            local maxSlots = (i <= 8) and 4 or 1
            for k=1,maxSlots do
                RaidAssignments.Marks[i][k] = nil
            end
        end
    end
    RaidAssignments:UpdateYourMarkFrame()
    RaidAssignments:UpdateYourCurseFrame()
end

function RaidAssignments:UpdateHeals()
    if GetRaidRosterInfo(1) or RaidAssignments.TestMode then
        -- Hide old frames first
        for i=1,12 do
            for k,v in pairs(RaidAssignments.HealFrames[i]) do
                v:Hide()
            end
        end

        -- Remove players not in raid anymore from heal marks, with grace period
        for i=1,12 do
            for k=1,6 do
                local name = RaidAssignments.HealMarks[i][k]
                if name and not RaidAssignments:IsInRaid(name) then
                    RaidAssignments._missingPlayers = RaidAssignments._missingPlayers or {}
                    local key = "h" .. i .. "_" .. k
                    if not RaidAssignments._missingPlayers[key] then
                        RaidAssignments._missingPlayers[key] = GetTime()
                    elseif (GetTime() - RaidAssignments._missingPlayers[key]) >= 5 then
                        RaidAssignments._missingPlayers[key] = nil
                        RaidAssignments.HealMarks[i][k] = nil
                    end
                else
                    if RaidAssignments._missingPlayers then
                        RaidAssignments._missingPlayers["h" .. i .. "_" .. k] = nil
                    end
                end
            end
        end

        -- Show healers (all 6 slots)
        for i=1,12 do
            for k=1,6 do
                local name = RaidAssignments.HealMarks[i][k]
                if name then
                    RaidAssignments.HealFrames[i][name] = RaidAssignments.HealFrames[i][name] or RaidAssignments:AddHealFrame(name, i)
                    local frame = RaidAssignments.HealFrames[i][name]
                    frame:SetPoint("RIGHT", 5 + (85 * k), 0)
                    local r, g, b = RaidAssignments:GetClassColors(name, "rgb")
                    RA_ApplyFrameColor(frame, r, g, b)
                    frame:Show()
                end
            end
        end
    else
        -- Hide all frames and clear marks if not in raid (clear all 6 slots)
        for i=1,12 do
            for k,v in pairs(RaidAssignments.HealFrames[i]) do
                if v:IsVisible() then
                    v:Hide()
                end
            end
            -- Clear all 6 slots
            for k=1,6 do  -- Changed from 4 to 6
                RaidAssignments.HealMarks[i][k] = nil
            end
        end
    end
end

-- Returns true if the given marks table has at least one non-nil assignment.
-- Used to prevent officers with empty tables from overwriting everyone else's data.
local function HasAnyMarks(marksTable, maxIndex)
    for i = 1, (maxIndex or 12) do
        local slots = marksTable[i]
        if slots then
            for _, v in pairs(slots) do
                if v and v ~= "" then return true end
            end
        end
    end
    return false
end

function RaidAssignments:SendTanks()
    if not IsRaidOfficer() then return end
    if not RaidAssignments._marksPopulated then return end
    local payload = ""
    for mark = 1, 12 do
        for k, v in pairs(RaidAssignments.Marks[mark]) do
            payload = payload .. mark .. "_" .. k .. "_" .. v .. ","
        end
    end
    ChunkSend("TankAssignmentsMarks", payload, "RAID")
end

function RaidAssignments:SendHeals()
    if not IsRaidOfficer() then return end
    if not RaidAssignments._marksPopulated then return end
    local payload = ""
    for mark = 1, 12 do
        for slot = 1, 6 do
            local v = RaidAssignments.HealMarks[mark][slot]
            if v then
                payload = payload .. mark .. "_" .. slot .. "_" .. v .. ","
            end
        end
    end
    ChunkSend("HealAssignmentsMarks", payload, "RAID")
end

function RaidAssignments:SanitizeName(name)
    if not name then return "" end
    local sanitized = string.gsub(name, "[^%w%s%-]", "")
    return sanitized
end

function RaidAssignments:SendGeneral()
    if not IsRaidOfficer() then return end
    if not RaidAssignments._marksPopulated then return end
    local payload = ""
    for mark = 1, 10 do
        if RaidAssignments.GeneralMarks[mark] then
            local maxSlots = (mark >= 9 and mark <= 10) and 7 or 5
            for slot = 1, maxSlots do
                local v = RaidAssignments.GeneralMarks[mark][slot]
                if v then
                    payload = payload .. mark .. "_" .. slot .. "_" .. v .. ","
                end
            end
        end
    end
    ChunkSend("RaidAssignmentsGeneralMarks", payload, "RAID")
end

function RaidAssignments:OpenToolTip(frameName)
    if GetRaidRosterInfo(1) or RaidAssignments.TestMode then
        for k, v in pairs(RaidAssignments.Frames["ToolTip"]) do
            v:Hide()
        end
        local index = 0
        local n = tonumber(string.sub(frameName, 2))
        -- Safely get assigned count for curse marks (9-12)
        local assignedCount = 0
		if n and n >= 9 and n <= 12 then
            if RaidAssignments.Marks[n] then
                -- Count actual assigned players
                for k, v in pairs(RaidAssignments.Marks[n]) do
                    if v and type(k) == "number" then
                        assignedCount = assignedCount + 1
                    end
                end
            end

            -- Don't show tooltip if curse mark already has 1 player assigned
            if assignedCount >= 1 then
                return
            end
        end

        local roster = RaidAssignments.TestMode and RaidAssignments.TestRoster or {}
        local numMembers = RaidAssignments.TestMode and table.getn(RaidAssignments.TestRoster) or GetNumRaidMembers()

        -- Collect eligible players
        local eligiblePlayers = {}
        for i = 1, numMembers do
            local name, class
            if RaidAssignments.TestMode then
                name = roster[i] and roster[i].name
                class = roster[i] and roster[i].class
            else
                name = UnitName("raid"..i)
                class = UnitClass("raid"..i)
            end
            if name and class then
                local f = false
                -- Check if player is already assigned within the same category:
                -- raid marks (1-8) and curse marks (9-12) are independent pools.
                local isCurseMark = (n and n >= 9 and n <= 12)
                local checkStart = isCurseMark and 9 or 1
                local checkEnd   = isCurseMark and 12 or 8
                for j = checkStart, checkEnd do
                    if RaidAssignments.Marks[j] then
                        for k, v in pairs(RaidAssignments.Marks[j]) do
                            if name == v then
                                f = true
                                break
                            end
                        end
                    end
                    if f then break end
                end
                if not f then
                    -- SPECIAL HANDLING FOR CURSE MARKS (9-12): Only show Warlocks
					if n and n >= 9 and n <= 12 then
                        if class == "Warlock" and RaidAssignments_Settings[class] == 1 then
                            table.insert(eligiblePlayers, name)
                        end
                    else
                        -- Regular marks (1-8): Show all enabled classes
                        if RaidAssignments_Settings[class] == 1 then
                            table.insert(eligiblePlayers, name)
                        end
                    end
                end
            end
        end

        -- Calculate columns
        local totalPlayers = table.getn(eligiblePlayers)
        if totalPlayers == 0 then return end

        local maxPlayersPerColumn = 10
        local numColumns = math.ceil(totalPlayers / maxPlayersPerColumn)
        local playersPerColumn = math.ceil(totalPlayers / numColumns)
        local actualRows = math.min(playersPerColumn, totalPlayers)

        -- Create columns
        local columnWidth = 80
        local totalWidth = columnWidth * numColumns
        local totalHeight = 25 * actualRows

        -- Set up the tooltip backdrop first
        RaidAssignments.ToolTip:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = false,
            tileSize = 16,
            edgeSize = 2,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        RaidAssignments.ToolTip:SetBackdropColor(0, 0, 0, 1)
        RaidAssignments.ToolTip:SetBackdropBorderColor(1, 1, 1, 0.5)
        RaidAssignments.ToolTip:SetWidth(totalWidth)
        RaidAssignments.ToolTip:SetHeight(totalHeight)
        local markFrame = _G[frameName]
			if markFrame then
				RaidAssignments.ToolTip:SetPoint("TOPRIGHT", markFrame, "TOPLEFT", 0, 0)
			else
				RaidAssignments.ToolTip:Hide()
				return
			end
        RaidAssignments.ToolTip:EnableMouse(true)
        RaidAssignments.ToolTip:EnableMouseWheel(true)

        -- Store the original mark frame for reference
        RaidAssignments.ToolTip.originalMark = _G[frameName]
        RaidAssignments.ToolTip.isVisible = true

        -- Walk the full parent chain to check if 'child' is under 'ancestor'.
        -- Needed because player frames have an hpbar child whose children (textures,
        -- fontstrings) would fail a single-level GetParent() check.
        local function IsUnder(child, ancestor)
            local f = child
            while f do
                if f == ancestor then return true end
                f = f:GetParent()
            end
            return false
        end

        RaidAssignments.ToolTip:SetScript("OnLeave", function()
            local mouseFocus = GetMouseFocus()
            local overTooltip = mouseFocus and IsUnder(mouseFocus, this)
            local overMark    = mouseFocus and IsUnder(mouseFocus, this.originalMark)
            if not overTooltip and not overMark then
                this.isVisible = false
                this:Hide()
            end
        end)

        if RaidAssignments.ToolTip.originalMark then
            RaidAssignments.ToolTip.originalMark:SetScript("OnLeave", function()
                local mouseFocus = GetMouseFocus()
                local overMark    = mouseFocus and IsUnder(mouseFocus, this)
                local overTooltip = mouseFocus and IsUnder(mouseFocus, RaidAssignments.ToolTip)
                if not overMark and not overTooltip then
                    RaidAssignments.ToolTip.isVisible = false
                    RaidAssignments.ToolTip:Hide()
                end
            end)
        end

        RaidAssignments.ToolTip:SetFrameStrata("FULLSCREEN")

        -- Now create the player frames
        for col = 1, numColumns do
            local startIndex = (col - 1) * playersPerColumn + 1
            local endIndex = math.min(startIndex + playersPerColumn - 1, totalPlayers)

            for i = startIndex, endIndex do
                local name = eligiblePlayers[i]
                local rowIndex = i - startIndex

                RaidAssignments.Frames["ToolTip"][name] = RaidAssignments.Frames["ToolTip"][name] or RaidAssignments:AddToolTipFrame(name, RaidAssignments.ToolTip)
                local frame = RaidAssignments.Frames["ToolTip"][name]
                frame:SetPoint("TOPLEFT", RaidAssignments.ToolTip, "TOPLEFT", (col - 1) * columnWidth + 2, -2 - (25 * rowIndex))
                local r, g, b = RaidAssignments:GetClassColors(name, "rgb")
                RA_ApplyFrameColor(frame, r, g, b)
                frame:Show()
            end
        end

        RaidAssignments.Settings["active"] = n
        RaidAssignments.ToolTip:Show()
    end
end

function RaidAssignments:OpenHealToolTip(frameName)
    if GetRaidRosterInfo(1) or RaidAssignments.TestMode then
        for k, v in pairs(RaidAssignments.Frames["HealToolTip"]) do
            v:Hide()
        end
        local n = tonumber(string.sub(frameName, 2))
        local roster = RaidAssignments.TestMode and RaidAssignments.TestRoster or {}
        local numMembers = RaidAssignments.TestMode and table.getn(RaidAssignments.TestRoster) or GetNumRaidMembers()

        -- Collect eligible players
        local eligiblePlayers = {}
        for i = 1, numMembers do
            local name, class
            if RaidAssignments.TestMode then
                name = roster[i] and roster[i].name
                class = roster[i] and roster[i].class
            else
                name = UnitName("raid"..i)
                class = UnitClass("raid"..i)
            end
            if name and class then
                local f = false
                -- Check if player is already assigned to ANY heal mark (1-12)
                for j = 1, 12 do
                    for k, v in ipairs(RaidAssignments.HealMarks[j]) do
                        if name == v then
                            f = true
                            break
                        end
                    end
                    if f then break end
                end
                if not f and RaidAssignments.RoleFilter.Healer[class] and RaidAssignments_Settings[class] == 1 then
                    table.insert(eligiblePlayers, name)
                end
            end
        end

        -- Calculate columns
        local totalPlayers = table.getn(eligiblePlayers)
        if totalPlayers == 0 then return end

        local maxPlayersPerColumn = 10
        local numColumns = math.ceil(totalPlayers / maxPlayersPerColumn)
        local playersPerColumn = math.ceil(totalPlayers / numColumns)
        local actualRows = math.min(playersPerColumn, totalPlayers)

        -- Create columns
        local columnWidth = 80
        local totalWidth = columnWidth * numColumns
        local totalHeight = 25 * actualRows

        -- Set up the tooltip backdrop first
        RaidAssignments.HealToolTip:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = false,
            tileSize = 16,
            edgeSize = 2,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        RaidAssignments.HealToolTip:SetBackdropColor(0, 0, 0, 1)
        RaidAssignments.HealToolTip:SetBackdropBorderColor(1, 1, 1, 0.5)
        RaidAssignments.HealToolTip:SetWidth(totalWidth)
        RaidAssignments.HealToolTip:SetHeight(totalHeight)
        
        -- FIX: Use HealToolTip instead of ToolTip for positioning
        local markFrame = _G[frameName]
        if markFrame then
            RaidAssignments.HealToolTip:SetPoint("TOPRIGHT", markFrame, "TOPLEFT", 0, 0)
        else
            RaidAssignments.HealToolTip:Hide()
            return
        end
        
        RaidAssignments.HealToolTip:EnableMouse(true)
        RaidAssignments.HealToolTip:EnableMouseWheel(true)

        -- Store the original mark frame for reference
        RaidAssignments.HealToolTip.originalMark = _G[frameName]
        RaidAssignments.HealToolTip.isVisible = true

        -- Walk the full parent chain to check if 'child' is under 'ancestor'.
        local function IsUnder(child, ancestor)
            local f = child
            while f do
                if f == ancestor then return true end
                f = f:GetParent()
            end
            return false
        end

        RaidAssignments.HealToolTip:SetScript("OnLeave", function()
            local mouseFocus = GetMouseFocus()
            local overTooltip = mouseFocus and IsUnder(mouseFocus, this)
            local overMark    = mouseFocus and IsUnder(mouseFocus, this.originalMark)
            if not overTooltip and not overMark then
                this.isVisible = false
                this:Hide()
            end
        end)

        if RaidAssignments.HealToolTip.originalMark then
            RaidAssignments.HealToolTip.originalMark:SetScript("OnLeave", function()
                local mouseFocus = GetMouseFocus()
                local overMark    = mouseFocus and IsUnder(mouseFocus, this)
                local overTooltip = mouseFocus and IsUnder(mouseFocus, RaidAssignments.HealToolTip)
                if not overMark and not overTooltip then
                    RaidAssignments.HealToolTip.isVisible = false
                    RaidAssignments.HealToolTip:Hide()
                end
            end)
        end

        RaidAssignments.HealToolTip:SetFrameStrata("FULLSCREEN")

        -- Now create the player frames
        for col = 1, numColumns do
            local startIndex = (col - 1) * playersPerColumn + 1
            local endIndex = math.min(startIndex + playersPerColumn - 1, totalPlayers)

            for i = startIndex, endIndex do
                local name = eligiblePlayers[i]
                local rowIndex = i - startIndex

                RaidAssignments.Frames["HealToolTip"][name] = RaidAssignments.Frames["HealToolTip"][name] or RaidAssignments:AddToolTipFrame(name, RaidAssignments.HealToolTip)
                local frame = RaidAssignments.Frames["HealToolTip"][name]
                frame:SetPoint("TOPLEFT", RaidAssignments.HealToolTip, "TOPLEFT", (col - 1) * columnWidth + 2, -2 - (25 * rowIndex))
                local r, g, b = RaidAssignments:GetClassColors(name, "rgb")
                RA_ApplyFrameColor(frame, r, g, b)
                frame:Show()
            end
        end

        RaidAssignments.Settings["active_heal"] = n
        RaidAssignments.HealToolTip:Show()
    end
end

function RaidAssignments:AddTank(name, mark)
    mark = tonumber(mark)

    -- Determine which "category" we're assigning to:
    -- Raid marks (1-8) and curse marks (9-12) are independent pools.
    -- A warlock may appear once in marks 1-8 AND once in marks 9-12.
    local isCurse = (mark >= 9 and mark <= 12)
    local searchStart = isCurse and 9 or 1
    local searchEnd   = isCurse and 12 or 8

    -- Prevent assigning the same player twice within the same category
    for i = searchStart, searchEnd do
        if RaidAssignments.Marks[i] then
            for k, v in pairs(RaidAssignments.Marks[i]) do
                if v == name then
                    -- If clicking the same mark they're already on -> remove (toggle)
                    if i == mark then
                        for slot, assignedName in pairs(RaidAssignments.Marks[mark]) do
                            if assignedName == name then
                                RaidAssignments.Marks[mark][slot] = nil
                                if RaidAssignments.Frames[mark][name] then
                                    RaidAssignments.Frames[mark][name]:Hide()
                                    RaidAssignments.Frames[mark][name] = nil
                                end
                                RaidAssignments:UpdateTanks()
                                RaidAssignments:SendTanks()
                                return
                            end
                        end
                    end
                    -- Already assigned somewhere else in this category -> block
                    return
                end
            end
        end
    end

    if not RaidAssignments.Marks[mark] then
        RaidAssignments.Marks[mark] = {}
    end

    -- Curse marks (9-12): limit to 1 warlock per curse type
    if isCurse then
        local count = 0
        for k, v in pairs(RaidAssignments.Marks[mark]) do
            if v then count = count + 1 end
        end
        if count >= 1 then
            return
        end
    end

    -- Find the next available slot
    local maxSlots = isCurse and 1 or 4
    local index = nil
    for slot = 1, maxSlots do
        if not RaidAssignments.Marks[mark][slot] then
            index = slot
            break
        end
    end

    if not index then return end

    local unit = RaidAssignments:GetRaidID(name)
    local class = RaidAssignments.TestMode and RaidAssignments:GetTestClass(name) or UnitClass(unit)

    RaidAssignments.Frames[mark][name] = RaidAssignments.Frames[mark][name] or RaidAssignments:AddTankFrame(name, mark)
    local frame = RaidAssignments.Frames[mark][name]
    frame:SetPoint("RIGHT", 5 + (85 * index), 0)
    local r, g, b = RaidAssignments:GetClassColors(name, "rgb")
    RA_ApplyFrameColor(frame, r, g, b)
    frame:Show()

    if RaidAssignments:CanAssignToMark(mark, name) then
        RaidAssignments.Marks[mark][index] = name
        -- A manual assignment means our table is now authoritative -- safe to broadcast.
        RaidAssignments._marksPopulated = true
        RaidAssignments:SendTanks()
    end
end

function RaidAssignments:AddHeal(name, mark)
    mark = tonumber(mark)

    -- Prevent assigning the same healer twice in the same mark (check all 6 slots)
    for i = 1, 6 do  -- Changed from 4 to 6
        if RaidAssignments.HealMarks[mark][i] == name then
            return
        end
    end

    local slot = nil
    -- Find first empty slot (check all 6 slots)
    for i = 1, 6 do  -- Changed from 4 to 6
        if not RaidAssignments.HealMarks[mark][i] then
            slot = i
            break
        end
    end

    if slot then
        RaidAssignments.HealFrames[mark][name] = RaidAssignments.HealFrames[mark][name] or RaidAssignments:AddHealFrame(name, mark)
        local frame = RaidAssignments.HealFrames[mark][name]
        frame:SetPoint("RIGHT", 5 + (85 * slot), 0)
        local r, g, b = RaidAssignments:GetClassColors(name, "rgb")
        RA_ApplyFrameColor(frame, r, g, b)
        frame:Show()
        RaidAssignments.HealMarks[mark][slot] = name
        RaidAssignments._marksPopulated = true
        RaidAssignments:SendHeals()
    end
end

function RaidAssignments:AddGeneral(name, mark)
    mark = tonumber(mark)

    -- Ensure the mark exists in the table
    if not RaidAssignments.GeneralMarks[mark] then
        RaidAssignments.GeneralMarks[mark] = {}
    end

    -- Prevent assigning the same player to ANY general mark (1-10)
    for i = 1, 10 do
        if RaidAssignments.GeneralMarks[i] then
            for _, v in pairs(RaidAssignments.GeneralMarks[i]) do
                if v == name then
                    return
                end
            end
        end
    end

    -- Find the first available slot
    local slot = nil
    local maxSlots = (mark >= 9 and mark <= 10) and 7 or 5  -- 7 slots for custom marks 9-10, 5 for others
    for i = 1, maxSlots do
        if not RaidAssignments.GeneralMarks[mark][i] then
            slot = i
            break
        end
    end

    if slot then
        RaidAssignments.GeneralFrames[mark][name] = RaidAssignments.GeneralFrames[mark][name] or RaidAssignments:AddGeneralFrame(name, mark)
        local frame = RaidAssignments.GeneralFrames[mark][name]
        frame:SetPoint("RIGHT", 5 + (85 * slot), 0)
        local r, g, b = RaidAssignments:GetClassColors(name, "rgb")
        RA_ApplyFrameColor(frame, r, g, b)
        frame:Show()
        RaidAssignments.GeneralMarks[mark][slot] = name
        RaidAssignments._marksPopulated = true
        RaidAssignments:SendGeneral()
    end
end

function RaidAssignments:AddToolTipFrame(name, tooltip)
    local frame = CreateFrame("Button", name, tooltip)
    frame:SetWidth(80)
    frame:SetHeight(25)
    frame:EnableMouse(true)

    -- Black background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.04, 0.04, 0.04, 0.96)
    bg:SetAllPoints(frame)
    frame.bg = bg

    -- Class-coloured border lines (set at assignment time via SetVertexColor)
    local function MkLine()
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        return t
    end
    local bT = MkLine(); local bB = MkLine(); local bL = MkLine(); local bR = MkLine()
    bT:SetHeight(1); bT:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);         bT:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
    bB:SetHeight(1); bB:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0);   bB:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    bL:SetWidth(1);  bL:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);         bL:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0)
    bR:SetWidth(1);  bR:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0);       bR:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    frame.borderLines = {bT, bB, bL, bR}

    -- Subtle inner colour fill (tinted, semi-transparent)
    local fill = frame:CreateTexture(nil, "ARTWORK")
    fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    fill:SetPoint("TOPLEFT",     frame, "TOPLEFT",     1, -1)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.fill = fill

    -- Hover glow
    local glow = frame:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetAllPoints(frame)
    glow:Hide()
    frame.glow = glow

    -- Player name (centred, white, shadow)
    frame.name = frame:CreateFontString(nil, "OVERLAY")
    frame.name:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.name:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 11)
    frame.name:SetTextColor(1, 1, 1, 1)
    frame.name:SetShadowOffset(1, -1)
    frame.name:SetShadowColor(0, 0, 0, 1)
    frame.name:SetText(name)

    -- texture alias kept for callers that do frame.texture:SetVertexColor(...)
    -- We drive colour through SetVertexColor on the border and fill instead.
    frame.texture = fill

    frame:SetScript("OnEnter", function()
        frame.glow:Show()
        frame.glow:SetVertexColor(1, 1, 1, 0.08)
    end)
    frame:SetScript("OnLeave", function()
        frame.glow:Hide()
    end)

    -- OnClick is set by the caller (AddToolTipFrame is reused for tank/heal/general tooltips)
    frame:SetScript("OnClick", function()
        if IsRaidOfficer() then
            this:Hide()
            if tooltip == RaidAssignments.ToolTip then
                RaidAssignments:AddTank(this:GetName(), RaidAssignments.Settings["active"])
                RaidAssignments:OpenToolTip("T"..RaidAssignments.Settings["active"])
                RaidAssignments:SendTanks()
            elseif tooltip == RaidAssignments.HealToolTip then
                RaidAssignments:AddHeal(this:GetName(), RaidAssignments.Settings["active_heal"])
                RaidAssignments:OpenHealToolTip("H"..RaidAssignments.Settings["active_heal"])
                RaidAssignments:SendHeals()
            elseif tooltip == RaidAssignments.GeneralToolTip then
                RaidAssignments:AddGeneral(this:GetName(), RaidAssignments.Settings["active_general"])
                RaidAssignments:OpenGeneralToolTip("G"..RaidAssignments.Settings["active_general"])
                RaidAssignments:SendGeneral()
            end
        end
    end)
    return frame
end



function RaidAssignments:AddTankFrame(name, mark)
    local frame = CreateFrame("Button", mark..name, RaidAssignments.bg)
    frame:SetParent("T"..mark)
    frame:SetWidth(80)
    frame:SetHeight(25)
    frame:EnableMouse(true)

    -- Black background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.04, 0.04, 0.04, 0.96)
    bg:SetAllPoints(frame)
    frame.bg = bg

    -- Class-coloured border lines
    local function MkLine()
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        return t
    end
    local bT = MkLine(); local bB = MkLine(); local bL = MkLine(); local bR = MkLine()
    bT:SetHeight(1); bT:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);         bT:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
    bB:SetHeight(1); bB:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0);   bB:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    bL:SetWidth(1);  bL:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);         bL:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0)
    bR:SetWidth(1);  bR:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0);       bR:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    frame.borderLines = {bT, bB, bL, bR}

    -- Subtle inner colour fill
    local fill = frame:CreateTexture(nil, "ARTWORK")
    fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    fill:SetPoint("TOPLEFT",     frame, "TOPLEFT",     1, -1)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.fill = fill
    frame.texture = fill  -- alias for legacy callers

    -- Hover glow
    local glow = frame:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetAllPoints(frame)
    glow:Hide()
    frame.glow = glow

    -- Player name
    frame.name = frame:CreateFontString(nil, "OVERLAY")
    frame.name:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.name:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 11)
    frame.name:SetTextColor(1, 1, 1, 1)
    frame.name:SetShadowOffset(1, -1)
    frame.name:SetShadowColor(0, 0, 0, 1)
    frame.name:SetText(name)

    frame:SetScript("OnEnter", function() frame.glow:Show() end)
    frame:SetScript("OnLeave", function() frame.glow:Hide() end)
    frame:SetScript("OnClick", function()
        if IsRaidOfficer() then
            for k, v in pairs(RaidAssignments.Marks[mark]) do
                if v == name then
                    RaidAssignments.Marks[mark][k] = nil
                    this:Hide()
                    RaidAssignments.Frames[mark][name] = nil
                    RaidAssignments:UpdateTanks()
                    RaidAssignments:SendTanks()
                    break
                end
            end
        end
    end)
    return frame
end

function RaidAssignments:AddHealFrame(name, mark)
    local frame = CreateFrame("Button", "H"..mark..name, RaidAssignments.bg)
    frame:SetParent("H"..mark)
    frame:SetWidth(80)
    frame:SetHeight(25)
    frame:EnableMouse(true)

    -- Black background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.04, 0.04, 0.04, 0.96)
    bg:SetAllPoints(frame)
    frame.bg = bg

    -- Class-coloured border lines
    local function MkLine()
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        return t
    end
    local bT = MkLine(); local bB = MkLine(); local bL = MkLine(); local bR = MkLine()
    bT:SetHeight(1); bT:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);         bT:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
    bB:SetHeight(1); bB:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0);   bB:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    bL:SetWidth(1);  bL:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);         bL:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0)
    bR:SetWidth(1);  bR:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0);       bR:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    frame.borderLines = {bT, bB, bL, bR}

    -- Subtle inner colour fill
    local fill = frame:CreateTexture(nil, "ARTWORK")
    fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    fill:SetPoint("TOPLEFT",     frame, "TOPLEFT",     1, -1)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.fill = fill
    frame.texture = fill  -- alias for legacy callers

    -- Hover glow
    local glow = frame:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetAllPoints(frame)
    glow:Hide()
    frame.glow = glow

    -- Player name
    frame.name = frame:CreateFontString(nil, "OVERLAY")
    frame.name:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.name:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 11)
    frame.name:SetTextColor(1, 1, 1, 1)
    frame.name:SetShadowOffset(1, -1)
    frame.name:SetShadowColor(0, 0, 0, 1)
    frame.name:SetText(name)

    frame:SetScript("OnEnter", function() frame.glow:Show() end)
    frame:SetScript("OnLeave", function() frame.glow:Hide() end)
    frame:SetScript("OnClick", function()
        if IsRaidOfficer() then
            for k = 1, 6 do
                if RaidAssignments.HealMarks[mark][k] == name then
                    RaidAssignments.HealMarks[mark][k] = nil
                    this:Hide()
                    RaidAssignments.HealFrames[mark][name] = nil
                    RaidAssignments:UpdateHeals()
                    RaidAssignments:SendHeals()
                    break
                end
            end
        end
    end)
    return frame
end

function RaidAssignments:AddGeneralFrame(name, mark)
    local frame = CreateFrame("Button", mark..name, RaidAssignments.generalBg)
    frame:SetParent("G"..mark)
    frame:SetWidth(80)
    frame:SetHeight(25)
    frame:EnableMouse(true)

    -- Black background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.04, 0.04, 0.04, 0.96)
    bg:SetAllPoints(frame)
    frame.bg = bg

    -- Class-coloured border lines
    local function MkLine()
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        return t
    end
    local bT = MkLine(); local bB = MkLine(); local bL = MkLine(); local bR = MkLine()
    bT:SetHeight(1); bT:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);         bT:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
    bB:SetHeight(1); bB:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0);   bB:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    bL:SetWidth(1);  bL:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);         bL:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0)
    bR:SetWidth(1);  bR:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0);       bR:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    frame.borderLines = {bT, bB, bL, bR}

    -- Subtle inner colour fill
    local fill = frame:CreateTexture(nil, "ARTWORK")
    fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    fill:SetPoint("TOPLEFT",     frame, "TOPLEFT",     1, -1)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.fill = fill
    frame.texture = fill  -- alias for legacy callers

    -- Hover glow
    local glow = frame:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetAllPoints(frame)
    glow:Hide()
    frame.glow = glow

    -- Player name
    frame.name = frame:CreateFontString(nil, "OVERLAY")
    frame.name:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.name:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 11)
    frame.name:SetTextColor(1, 1, 1, 1)
    frame.name:SetShadowOffset(1, -1)
    frame.name:SetShadowColor(0, 0, 0, 1)
    frame.name:SetText(name)

    frame:SetScript("OnEnter", function() frame.glow:Show() end)
    frame:SetScript("OnLeave", function() frame.glow:Hide() end)
    frame:SetScript("OnClick", function()
        if IsRaidOfficer() then
            local maxSlots = (mark >= 9 and mark <= 10) and 7 or 5
            for k = 1, maxSlots do
                if RaidAssignments.GeneralMarks[mark] and RaidAssignments.GeneralMarks[mark][k] == name then
                    RaidAssignments.GeneralMarks[mark][k] = nil
                    this:Hide()
                    RaidAssignments.GeneralFrames[mark][name] = nil
                    RaidAssignments:UpdateGeneral()
                    RaidAssignments:SendGeneral()
                    break
                end
            end
        end
    end)
    return frame
end

function RaidAssignments:PostAssignments()
    local chan = "RAID" -- Default to RAID channel
    local chanNum = nil
    local n = false

    if RaidAssignments_Settings["usecolors"] then
        -- Tanks
        for i = 1, 8 do
            for _ in pairs(RaidAssignments.Marks[i]) do n = true; break end
        end
        if n then
            RA_QueueMessage("-- Tank Assignments --", chan, nil, chanNum)
            local i = 8
            while i > 0 do
                local text = RaidAssignments:GetClassColors(RaidAssignments.RealMarks[i], "mark")
                local hasAny = false
                for _ in pairs(RaidAssignments.Marks[i]) do hasAny = true; break end
                if hasAny then
                    local first = true
                    for k, v in pairs(RaidAssignments.Marks[i]) do
                        if first then
                            text = text .. ": " .. RaidAssignments:GetClassColors(v, "cff")
                            first = false
                        else
                            text = text .. ", " .. RaidAssignments:GetClassColors(v, "cff")
                        end
                    end
                    text = text .. "."
                    RA_QueueMessage(text, chan, nil, chanNum)
                end
                i = i - 1
            end
        end

        -- Curses
        n = false
        for i = 9, 12 do
            for _ in pairs(RaidAssignments.Marks[i] or {}) do n = true; break end
            if n then break end
        end
        if n then
            RA_QueueMessage("-- Curse Assignments --", chan, nil, chanNum)
            for i = 9, 12 do
                local hasAny = false
                for _ in pairs(RaidAssignments.Marks[i] or {}) do hasAny = true; break end
                if hasAny then
                    local curseName = RaidAssignments.WarlockMarks[i] and RaidAssignments.WarlockMarks[i].name or "Unknown Curse"
                    local text = curseName .. ": "
                    local first = true
                    for k, v in pairs(RaidAssignments.Marks[i]) do
                        if first then text = text .. RaidAssignments:GetClassColors(v, "cff"); first = false
                        else text = text .. ", " .. RaidAssignments:GetClassColors(v, "cff") end
                    end
                    text = text .. "."
                    RA_QueueMessage(text, chan, nil, chanNum)
                end
            end
        end

        -- Heals
        n = false
        for i = 1, 12 do
            for k = 1, 6 do
                if RaidAssignments.HealMarks[i][k] then
                    n = true
                    break
                end
            end
        end
        if n then
            RA_QueueMessage("-- Heal Assignments --", chan, nil, chanNum)
            local i = 12
            while i > 0 do
                local text = RaidAssignments.HealRealMarks[i]
                local hasHealers = false
                for k = 1, 6 do
                    if RaidAssignments.HealMarks[i][k] then
                        hasHealers = true
                        break
                    end
                end
                if hasHealers then
                    text = text .. ": "
                    for k = 1, 6 do
                        local v = RaidAssignments.HealMarks[i][k]
                        if v then
                            text = text .. "(" .. k .. ") " .. RaidAssignments:GetClassColors(v, "cff")
                            local hasMore = false
                            for m = k + 1, 6 do
                                if RaidAssignments.HealMarks[i][m] then
                                    hasMore = true
                                    break
                                end
                            end
                            if hasMore then
                                text = text .. ", "
                            else
                                text = text .. "."
                            end
                        end
                    end
                    RA_QueueMessage(text, chan, nil, chanNum)
                end
                i = i - 1
            end
        end

    else
        -- Tanks
        for i = 1, 8 do
            for _ in pairs(RaidAssignments.Marks[i]) do n = true; break end
        end
        if n then
            RA_QueueMessage("-- Tank Assignments --", chan, nil, chanNum)
            local i = 8
            while i > 0 do
                local text = RaidAssignments.RealMarks[i]
                local hasAny = false
                for _ in pairs(RaidAssignments.Marks[i]) do hasAny = true; break end
                if hasAny then
                    local first = true
                    for k, v in pairs(RaidAssignments.Marks[i]) do
                        if first then
                            text = text .. ": " .. v
                            first = false
                        else
                            text = text .. ", " .. v
                        end
                    end
                    text = text .. "."
                    RA_QueueMessage(text, chan, nil, chanNum)
                end
                i = i - 1
            end
        end

        -- Curses
        n = false
        for i = 9, 12 do
            for _ in pairs(RaidAssignments.Marks[i] or {}) do n = true; break end
            if n then break end
        end
        if n then
            RA_QueueMessage("-- Curse Assignments --", chan, nil, chanNum)
            for i = 9, 12 do
                local hasAny = false
                for _ in pairs(RaidAssignments.Marks[i] or {}) do hasAny = true; break end
                if hasAny then
                    local curseName = RaidAssignments.WarlockMarks[i] and RaidAssignments.WarlockMarks[i].name or "Unknown Curse"
                    local text = curseName .. ": "
                    local first = true
                    for k, v in pairs(RaidAssignments.Marks[i]) do
                        if first then text = text .. v; first = false
                        else text = text .. ", " .. v end
                    end
                    text = text .. "."
                    RA_QueueMessage(text, chan, nil, chanNum)
                end
            end
        end

        -- Heals
        n = false
        for i = 1, 12 do
            for k = 1, 6 do
                if RaidAssignments.HealMarks[i][k] then
                    n = true
                    break
                end
            end
        end
        if n then
            RA_QueueMessage("-- Heal Assignments --", chan, nil, chanNum)
            local i = 12
            while i > 0 do
                local text = RaidAssignments.HealRealMarks[i]
                local hasHealers = false
                for k = 1, 6 do
                    if RaidAssignments.HealMarks[i][k] then
                        hasHealers = true
                        break
                    end
                end
                if hasHealers then
                    text = text .. ": "
                    for k = 1, 6 do
                        local v = RaidAssignments.HealMarks[i][k]
                        if v then
                            text = text .. "(" .. k .. ") " .. v
                            local hasMore = false
                            for m = k + 1, 6 do
                                if RaidAssignments.HealMarks[i][m] then
                                    hasMore = true
                                    break
                                end
                            end
                            if hasMore then
                                text = text .. ", "
                            else
                                text = text .. "."
                            end
                        end
                    end
                    RA_QueueMessage(text, chan, nil, chanNum)
                end
                i = i - 1
            end
        end
    end
    if RaidAssignments_Settings["useWhisper"] then
        self:WhisperAssignments()
    end
end

function RaidAssignments:GenerateTestRoster()
    RaidAssignments.TestRoster = {}
    local classes = {"Warrior", "Warlock", "Rogue", "Priest", "Mage", "Hunter", "Druid", "Paladin", "Shaman"}
    local names = {
        "Abelius", "Arboldemango", "Azzer", "Bestigor", "Bigbron", "Bombardero", "Calogero", "Catu",
        "Culin", "Dardork", "Darez", "Dragovar", "Durotavich", "Edeax", "Elcucho", "Eisla",
        "Gulolio", "Hecryp", "Hezpar", "Hoplite", "Kukarda", "Lokyu", "Ndree", "Neneta",
        "Neralone", "Ocuspocuss", "Onrul", "Palawhite", "Pandamonium", "Pimienta", "Pokker", "Fionna",
        "Selner", "Sinnergia", "Tankita", "Teletubbiei", "Uburrka", "Xanty", "Xposed", "Zeroxkg"
    }
    for i = 1, 40 do
        local class = classes[math.mod(i - 1, 9) + 1] -- Distribute classes evenly
        local name = names[i] -- Use name from the pool
        table.insert(RaidAssignments.TestRoster, {
            name = name,
            class = class
        })
    end
end

function RaidAssignments:GetTestClass(name)
    for _, unit in pairs(RaidAssignments.TestRoster) do
        if unit.name == name then
            return unit.class
        end
    end
    return nil
end

function RaidAssignments:ToggleTestMode()
    if not RaidAssignments.TestMode then
        RaidAssignments.TestMode = true
        RaidAssignments:GenerateTestRoster()
        -- Populate the roster cache from the test roster so GetCachedClass(),
        -- IsInRaid(), and GetClassColors() all work correctly in test mode.
        RaidAssignments:RebuildRosterCache()
        DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments 2.0|r: Test mode enabled with 40 dummy players")
    else
        RaidAssignments.TestMode = false
        RaidAssignments.TestRoster = {}
        -- Clear the cache so stale test names don't linger after disabling.
        RaidAssignments:RebuildRosterCache()
        DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments 2.0|r: Test mode disabled")
    end
    RaidAssignments:UpdateTanks()
    RaidAssignments:UpdateHeals()
    RaidAssignments:UpdateGeneral()
end

function RaidAssignments:Slash(arg1)
	if arg1 == nil or arg1 == "" then
		if RaidAssignments:IsVisible() then
			RaidAssignments.ToolTip:Hide()
			RaidAssignments.HealToolTip:Hide()
			RaidAssignments.Settings["Animation"] = true
			RaidAssignments.Settings["MainFrame"] = false
		else
			RaidAssignments.Settings["Animation"] = false
			RaidAssignments.Settings["MainFrame"] = false
			RaidAssignments.Settings["SizeX"] = 0
			RaidAssignments.Settings["SizeY"] = 0
			RaidAssignments:Show()
		end
	elseif arg1 == "test" then
		RaidAssignments:ToggleTestMode()
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments 2.0|r: Unknown command. Use /ta, or /ta test")
	end
end

SLASH_TA1, SLASH_TA2 = "/ta", "/tanksassignments"
function SlashCmdList.TA(msg, editbox)
	RaidAssignments:Slash(msg)
end

RaidAssignments:SetScript("OnEvent", RaidAssignments.OnEvent)

function RaidAssignments:Debug()
	for k, v in pairs(RaidAssignments.Marks) do
		for i, name in pairs(RaidAssignments.Marks[k]) do
			DEFAULT_CHAT_FRAME:AddMessage(k..": "..i.." - "..name)
		end
	end
end

function RaidAssignments:PostRaidAssignments()
    local chan = "RAID"
    local chanNum = nil
    local n = false

    if RaidAssignments_Settings["usecolors"] then
        -- Tanks
        for i = 1, 8 do
            for _ in pairs(RaidAssignments.Marks[i]) do n = true; break end
        end
        if n then
            RA_QueueMessage("-- Tank Assignments --", chan, nil, chanNum)
            local i = 8
            while i > 0 do
                local text = RaidAssignments:GetClassColors(RaidAssignments.RealMarks[i], "mark")
                local hasAny = false
                for _ in pairs(RaidAssignments.Marks[i]) do hasAny = true; break end
                if hasAny then
                    local first = true
                    for k, v in pairs(RaidAssignments.Marks[i]) do
                        if first then
                            text = text .. ": " .. RaidAssignments:GetClassColors(v, "cff")
                            first = false
                        else
                            text = text .. ", " .. RaidAssignments:GetClassColors(v, "cff")
                        end
                    end
                    text = text .. "."
                    RA_QueueMessage(text, chan, nil, chanNum)
                end
                i = i - 1
            end
        end
    else
        -- Tanks (no colors)
        for i = 1, 8 do
            for _ in pairs(RaidAssignments.Marks[i]) do n = true; break end
        end
        if n then
            RA_QueueMessage("-- Tank Assignments --", chan, nil, chanNum)
            local i = 8
            while i > 0 do
                local text = RaidAssignments.RealMarks[i]
                local hasAny = false
                for _ in pairs(RaidAssignments.Marks[i]) do hasAny = true; break end
                if hasAny then
                    local first = true
                    for k, v in pairs(RaidAssignments.Marks[i]) do
                        if first then
                            text = text .. ": " .. v
                            first = false
                        else
                            text = text .. ", " .. v
                        end
                    end
                    text = text .. "."
                    RA_QueueMessage(text, chan, nil, chanNum)
                end
                i = i - 1
            end
        end
    end
    if RaidAssignments_Settings["useWhisper"] then
        for i = 1, 8 do
            for k, v in pairs(RaidAssignments.Marks[i]) do
                if RaidAssignments:IsInRaid(v) then
                    local text = "You are assigned to tank " .. RaidAssignments.RealMarks[i] .. " (slot " .. k .. ")"
                    SendChatMessage(text, "WHISPER", nil, v)
                end
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments 2.0|r: Whispered tank assignments to players")
    end
end

function RaidAssignments:PostHealAssignments()
    local chan = "RAID"
    local chanNum = nil
    local n = false

    if RaidAssignments_Settings["usecolors"] then
        -- Heals
        for i = 1, 12 do
            for k = 1, 6 do
                if RaidAssignments.HealMarks[i][k] then
                    n = true
                    break
                end
            end
        end
        if n then
            RA_QueueMessage("-- Heal Assignments --", chan, nil, chanNum)
            local i = 12
            while i > 0 do
                local text = RaidAssignments.HealRealMarks[i]
                local hasHealers = false
                for k = 1, 6 do
                    if RaidAssignments.HealMarks[i][k] then
                        hasHealers = true
                        break
                    end
                end
                if hasHealers then
                    text = text .. ": "
                    for k = 1, 6 do
                        local v = RaidAssignments.HealMarks[i][k]
                        if v then
                            text = text .. "(" .. k .. ") " .. RaidAssignments:GetClassColors(v, "cff")
                            local hasMore = false
                            for m = k + 1, 6 do
                                if RaidAssignments.HealMarks[i][m] then
                                    hasMore = true
                                    break
                                end
                            end
                            if hasMore then
                                text = text .. ", "
                            else
                                text = text .. "."
                            end
                        end
                    end
                    RA_QueueMessage(text, chan, nil, chanNum)
                end
                i = i - 1
            end
        end
    else
        -- Heals (no colors)
        for i = 1, 12 do
            for k = 1, 6 do
                if RaidAssignments.HealMarks[i][k] then
                    n = true
                    break
                end
            end
        end
        if n then
            RA_QueueMessage("-- Heal Assignments --", chan, nil, chanNum)
            local i = 12
            while i > 0 do
                local text = RaidAssignments.HealRealMarks[i]
                local hasHealers = false
                for k = 1, 6 do
                    if RaidAssignments.HealMarks[i][k] then
                        hasHealers = true
                        break
                    end
                end
                if hasHealers then
                    text = text .. ": "
                    for k = 1, 6 do
                        local v = RaidAssignments.HealMarks[i][k]
                        if v then
                            text = text .. "(" .. k .. ") " .. v
                            local hasMore = false
                            for m = k + 1, 6 do
                                if RaidAssignments.HealMarks[i][m] then
                                    hasMore = true
                                    break
                                end
                            end
                            if hasMore then
                                text = text .. ", "
                            else
                                text = text .. "."
                            end
                        end
                    end
                    RA_QueueMessage(text, chan, nil, chanNum)
                end
                i = i - 1
            end
        end
    end
    if RaidAssignments_Settings["useWhisper"] then
        for i = 1, 12 do
            for k = 1, 6 do
                local v = RaidAssignments.HealMarks[i][k]
                if v and RaidAssignments:IsInRaid(v) then
                    local text = "You are assigned to heal " .. RaidAssignments.HealRealMarks[i] .. " (slot " .. k .. ")"
                    SendChatMessage(text, "WHISPER", nil, v)
                end
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments 2.0|r: Whispered heal assignments to players")
    end
end

function RaidAssignments:PostGeneralAssignments()
    local chan = "RAID"
    local chanNum = nil
    local n = false

    if RaidAssignments_Settings["usecolors"] then
        for i = 1, 10 do
            if RaidAssignments.GeneralMarks[i] ~= nil then
                local hasAssignments = false
                local maxSlots = (i >= 9 and i <= 10) and 7 or 5  -- 7 slots for custom marks 9-10, 5 for others
                for k = 1, maxSlots do
                    if RaidAssignments.GeneralMarks[i] and RaidAssignments.GeneralMarks[i][k] then
                        hasAssignments = true
                        n = true
                        break
                    end
                end
            end
        end
        if n then
            RA_QueueMessage("-- General Assignments --", chan, nil, chanNum)
            local i = 1
            while i <= 10 do
                local maxSlots = (i >= 9 and i <= 10) and 7 or 5  -- 7 slots for custom marks 9-10, 5 for others
                local hasAssignments = false
                for k = 1, maxSlots do
                    if RaidAssignments.GeneralMarks[i] and RaidAssignments.GeneralMarks[i][k] then
                        hasAssignments = true
                        break
                    end
                end

                if hasAssignments then
                    -- Get the mark text from the input box for custom marks, or use predefined names
                    local markText = RaidAssignments.GeneralRealMarks[i]
                    if i >= 9 then
                        -- For custom marks 9 and 10, get the text from the EditBox
                        local editBox = _G["G"..i.."_Edit"]
                        if editBox then
                            local editText = editBox:GetText()
                            if editText and editText ~= "" then
                                markText = editText
                            else
                                markText = "Custom Mark " .. (i - 8)
                            end
                        else
                            markText = "Custom Mark " .. (i - 8)
                        end
                    end

                    local text = markText .. ": "
                    local first = true
                    for k = 1, maxSlots do
                        local v = RaidAssignments.GeneralMarks[i] and RaidAssignments.GeneralMarks[i][k]
                        if v then
                            if not first then
                                text = text .. ", "
                            end
                            text = text .. RaidAssignments:GetClassColors(v, "cff")
                            first = false
                        end
                    end
                    text = text .. "."
                    RA_QueueMessage(text, chan, nil, chanNum)
                end
                i = i + 1
            end
        end
    else
        for i = 1, 10 do
            if RaidAssignments.GeneralMarks[i] ~= nil then
                local hasAssignments = false
                local maxSlots = (i >= 9 and i <= 10) and 7 or 5  -- 7 slots for custom marks 9-10, 5 for others
                for k = 1, maxSlots do
                    if RaidAssignments.GeneralMarks[i] and RaidAssignments.GeneralMarks[i][k] then
                        hasAssignments = true
                        n = true
                        break
                    end
                end
            end
        end
        if n then
            RA_QueueMessage("-- General Assignments --", chan, nil, chanNum)
            local i = 1
            while i <= 10 do
                local maxSlots = (i >= 9 and i <= 10) and 7 or 5  -- 7 slots for custom marks 9-10, 5 for others
                local hasAssignments = false
                for k = 1, maxSlots do
                    if RaidAssignments.GeneralMarks[i] and RaidAssignments.GeneralMarks[i][k] then
                        hasAssignments = true
                        break
                    end
                end

                if hasAssignments then
                    -- Get the mark text from the input box for custom marks, or use predefined names
                    local markText = RaidAssignments.GeneralRealMarks[i]
                    if i >= 9 then
                        -- For custom marks 9 and 10, get the text from the EditBox
                        local editBox = _G["G"..i.."_Edit"]
                        if editBox then
                            local editText = editBox:GetText()
                            if editText and editText ~= "" then
                                markText = editText
                            else
                                markText = "Custom Mark " .. (i - 8)
                            end
                        else
                            markText = "Custom Mark " .. (i - 8)
                        end
                    end

                    local text = markText .. ": "
                    local first = true
                    for k = 1, maxSlots do
                        local v = RaidAssignments.GeneralMarks[i] and RaidAssignments.GeneralMarks[i][k]
                        if v then
                            if not first then
                                text = text .. ", "
                            end
                            text = text .. v
                            first = false
                        end
                    end
                    text = text .. "."
                    RA_QueueMessage(text, chan, nil, chanNum)
                end
                i = i + 1
            end
        end
    end
    if RaidAssignments_Settings["useWhisper"] then
        for i = 1, 10 do
            local maxSlots = (i >= 9 and i <= 10) and 7 or 5  -- 7 slots for custom marks 9-10, 5 for others
            for k = 1, maxSlots do
                local v = RaidAssignments.GeneralMarks[i] and RaidAssignments.GeneralMarks[i][k]
                if v and RaidAssignments:IsInRaid(v) then
                    -- Get the mark text from the input box for custom marks, or use predefined names
                    local markText = RaidAssignments.GeneralRealMarks[i]
                    if i >= 9 then
                        -- For custom marks 9 and 10, get the text from the EditBox
                        local editBox = _G["G"..i.."_Edit"]
                        if editBox then
                            local editText = editBox:GetText()
                            if editText and editText ~= "" then
                                markText = editText
                            else
                                markText = "Custom Mark " .. (i - 8)
                            end
                        else
                            markText = "Custom Mark " .. (i - 8)
                        end
                    end
                    local text = "You are assigned to " .. markText .. " (slot " .. k .. ")"
                    SendChatMessage(text, "WHISPER", nil, v)
                end
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments 2.0|r: Whispered general assignments to players")
    end
end

function RaidAssignments:PostCurses()
    if not IsRaidOfficer() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments 3.0|r: You must be a raid officer to post curse assignments")
        return
    end

    local chan = "RAID"
    local chanNum = nil
    local hasCurses = false

    -- Check if there are any curse assignments
    for i = 9, 12 do
        for _ in pairs(RaidAssignments.Marks[i] or {}) do hasCurses = true; break end
        if hasCurses then break end
    end

    if not hasCurses then
        DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments 3.0|r: No curse assignments to post")
        return
    end

    if RaidAssignments_Settings["usecolors"] then
        RA_QueueMessage("-- Curse Assignments --", chan, nil, chanNum)
        for i = 9, 12 do
            local hasAny = false
            for _ in pairs(RaidAssignments.Marks[i] or {}) do hasAny = true; break end
            if hasAny then
                local curseName = RaidAssignments.WarlockMarks[i] and RaidAssignments.WarlockMarks[i].name or "Unknown Curse"
                local text = curseName .. ": "
                local first = true
                for k, v in pairs(RaidAssignments.Marks[i]) do
                    if first then text = text .. RaidAssignments:GetClassColors(v, "cff"); first = false
                    else text = text .. ", " .. RaidAssignments:GetClassColors(v, "cff") end
                end
                text = text .. "."
                RA_QueueMessage(text, chan, nil, chanNum)
            end
        end
    else
        RA_QueueMessage("-- Curse Assignments --", chan, nil, chanNum)
        for i = 9, 12 do
            local hasAny = false
            for _ in pairs(RaidAssignments.Marks[i] or {}) do hasAny = true; break end
            if hasAny then
                local curseName = RaidAssignments.WarlockMarks[i] and RaidAssignments.WarlockMarks[i].name or "Unknown Curse"
                local text = curseName .. ": "
                local first = true
                for k, v in pairs(RaidAssignments.Marks[i]) do
                    if first then text = text .. v; first = false
                    else text = text .. ", " .. v end
                end
                text = text .. "."
                RA_QueueMessage(text, chan, nil, chanNum)
            end
        end
    end

    -- Also whisper individual assignments if enabled
    if RaidAssignments_Settings["useWhisper"] then
        for i = 9, 12 do
            for k, v in pairs(RaidAssignments.Marks[i]) do
                if RaidAssignments:IsInRaid(v) then
                    local curseName = RaidAssignments.WarlockMarks[i] and RaidAssignments.WarlockMarks[i].name or "Unknown Curse"
                    local text = "You are assigned to " .. curseName .. " (slot " .. k .. ")"
                    SendChatMessage(text, "WHISPER", nil, v)
                end
            end
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments 3.0|r: Whispered curse assignments to players")
    end

end

--  Custom Assignments Extension (8 Independent Windows)

RaidAssignments.CustomMarks = RaidAssignments.CustomMarks or {}
RaidAssignments.CustomRealMarks = RaidAssignments.CustomRealMarks or {}
RaidAssignments.CustomFrames = RaidAssignments.CustomFrames or {}

for i = 1, 8 do
    RaidAssignments.CustomMarks[i] = RaidAssignments.CustomMarks[i] or {}
    for m = 1, 10 do
        RaidAssignments.CustomMarks[i][m] = RaidAssignments.CustomMarks[i][m] or {}
    end
    RaidAssignments.CustomRealMarks[i] = RaidAssignments.CustomRealMarks[i] or {}
    for m = 1, 8 do
        RaidAssignments.CustomRealMarks[i][m] = RaidAssignments.RealMarks[m] or ("Mark "..m)
    end
    RaidAssignments.CustomRealMarks[i][9] = RaidAssignments.CustomRealMarks[i][9] or ""
    RaidAssignments.CustomRealMarks[i][10] = RaidAssignments.CustomRealMarks[i][10] or ""
    RaidAssignments.CustomFrames[i] = RaidAssignments.CustomFrames[i] or {}
end

-- Sync
-- SendCustom is defined after SendCustomWindowTitle below.



function RaidAssignments:SendCustomLabels(i)
    if not IsRaidOfficer() then return end

    RaidAssignments.CustomRealMarks[i] = RaidAssignments.CustomRealMarks[i] or {}
    local label9 = RaidAssignments.CustomRealMarks[i][9] or "Custom 1"
    local label10 = RaidAssignments.CustomRealMarks[i][10] or "Custom 2"

    local out = "9_" .. label9 .. ",10_" .. label10 .. ","
    SendAddonMessage("RACLabel"..tostring(i), out, "RAID")
end

function RaidAssignments:PostCustomAssignments(i)
    if not IsRaidOfficer() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments 3.0|r: You must be a raid officer to post custom assignments")
        return
    end

    local chan = "RAID"
    local chanNum = nil
    local hasAssignments = false

    local markColors = {
        [1] = "|cffffff00", -- Star: Yellow
        [2] = "|cffffa500", -- Circle: Orange
        [3] = "|cffa100a5", -- Diamond: Purple
        [4] = "|cff00ff00", -- Triangle: Green
        [5] = "|cffd3d3d3", -- Moon: Light Gray
        [6] = "|cff0000ff", -- Square: Blue
        [7] = "|cffff0000", -- Cross: Red
        [8] = "|cffffffff", -- Skull: White
        [9] = "|cffd3d3d3", -- Custom 1: Light Gray
        [10] = "|cffd3d3d3" -- Custom 2: Light Gray
    }

    for mark = 1, 10 do
        local maxSlots = (mark >= 9 and mark <= 10) and 6 or 5
        for slot = 1, maxSlots do
            if RaidAssignments.CustomMarks[i][mark] and RaidAssignments.CustomMarks[i][mark][slot] then
                hasAssignments = true
                break
            end
        end
        if hasAssignments then break end
    end

    if not hasAssignments then
        DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments 3.0|r: No custom assignments to post for frame " .. i)
        return
    end

    local windowTitle = RaidAssignments_Settings.CustomWindowTitles and RaidAssignments_Settings.CustomWindowTitles[i] or "Custom Assignments " .. tostring(i)
    RA_QueueMessage("-- " .. windowTitle .. " --", chan, nil, chanNum)

    -- COLORED POSTING (REVERSED ORDER)
    if RaidAssignments_Settings["usecolors"] then
        for mark = 10, 1, -1 do
            local maxSlots = (mark >= 9 and mark <= 10) and 6 or 5
            local names = {}
            for slot = 1, maxSlots do
                local name = RaidAssignments.CustomMarks[i][mark] and RaidAssignments.CustomMarks[i][mark][slot]
                if name and name ~= "" then
                    table.insert(names, RaidAssignments:GetClassColors(name, "cff"))
                end
            end
            if table.getn(names) > 0 then
                local label
                if mark >= 9 and mark <= 10 then
                    local editBox = _G["C" .. i .. "_" .. mark .. "_Edit"]
                    label = (editBox and editBox:GetText() ~= "") and editBox:GetText() or
                            RaidAssignments.CustomRealMarks[i][mark] or
                            ("Custom " .. (mark - 8))
                else
                    label = RaidAssignments.CustomRealMarks[i][mark] or ("Mark " .. mark)
                end
                local coloredLabel = markColors[mark] .. label .. "|r"
                local text = coloredLabel .. ": " .. table.concat(names, ", ") .. "."
                RA_QueueMessage(text, chan, nil, chanNum)
            end
        end
    else
        -- NON-COLORED POSTING (REVERSED ORDER)
        for mark = 10, 1, -1 do
            local maxSlots = (mark >= 9 and mark <= 10) and 6 or 5
            local names = {}
            for slot = 1, maxSlots do
                local name = RaidAssignments.CustomMarks[i][mark] and RaidAssignments.CustomMarks[i][mark][slot]
                if name and name ~= "" then
                    table.insert(names, name)
                end
            end
            if table.getn(names) > 0 then
                local label
                if mark >= 9 and mark <= 10 then
                    local editBox = _G["C" .. i .. "_" .. mark .. "_Edit"]
                    label = (editBox and editBox:GetText() ~= "") and editBox:GetText() or
                            RaidAssignments.CustomRealMarks[i][mark] or
                            ("Custom " .. (mark - 8))
                else
                    label = RaidAssignments.CustomRealMarks[i][mark] or ("Mark " .. mark)
                end
                local text = label .. ": " .. table.concat(names, ", ") .. "."
                RA_QueueMessage(text, chan, nil, chanNum)
            end
        end
    end

    -- WHISPER SECTION (unchanged)
    if RaidAssignments_Settings["useWhisper"] then
        for mark = 10, 1, -1 do
            local maxSlots = (mark >= 9 and mark <= 10) and 6 or 5
            for slot = 1, maxSlots do
                local name = RaidAssignments.CustomMarks[i][mark] and RaidAssignments.CustomMarks[i][mark][slot]
                if name and name ~= "" and RaidAssignments:IsInRaid(name) then
                    local label
                    if mark >= 9 and mark <= 10 then
                        local editBox = _G["C" .. i .. "_" .. mark .. "_Edit"]
                        label = (editBox and editBox:GetText() ~= "") and editBox:GetText() or
                                RaidAssignments.CustomRealMarks[i][mark] or
                                ("Custom " .. (mark - 8))
                    else
                        label = RaidAssignments.CustomRealMarks[i][mark] or ("Mark " .. mark)
                    end
                    local text = "You are assigned to " .. label .. " (slot " .. slot .. ")"
                    SendChatMessage(text, "WHISPER", nil, name)
                end
            end
        end
    end

    RaidAssignments:SendCustom(i)
end


-- UI
function RaidAssignments:ConfigCustomFrame(i)
    local name = "RaidAssignmentsCustom"..tostring(i)
    if _G[name] then return end

    -- Ensure data structures exist
    RaidAssignments.CustomMarks[i] = RaidAssignments.CustomMarks[i] or {}
    RaidAssignments.CustomRealMarks[i] = RaidAssignments.CustomRealMarks[i] or {}
    RaidAssignments_Settings.CustomWindowTitles = RaidAssignments_Settings.CustomWindowTitles or {}

    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetWidth(620)
    frame:SetHeight(560)
    frame:SetPoint("CENTER", 0, 100)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({
        bgFile  = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile    = false,
        edgeSize = 1,
        insets  = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame:SetBackdropColor(0.07, 0.07, 0.09, 0.97)
    frame:SetBackdropBorderColor(0.15, 0.15, 0.18, 1)

    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    -- Mouse wheel scaling
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function()
        local f = _G[name]
        local scale = f:GetScale()
        if arg1 > 0 then
            scale = math.min(scale + 0.05, 2.0)
        else
            scale = math.max(scale - 0.05, 0.5)
        end
        f:SetScale(scale)
    end)

    -- Title bar strip
    local titleBar = frame:CreateTexture(nil, "BACKGROUND")
    titleBar:SetTexture("Interface\\Buttons\\WHITE8X8")
    titleBar:SetVertexColor(0.05, 0.05, 0.07, 1)
    titleBar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -1)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(36)

    -- Cyan accent line under title bar
    local accentLine = frame:CreateTexture(nil, "ARTWORK")
    accentLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    accentLine:SetVertexColor(0.2, 0.8, 0.9, 0.9)
    accentLine:SetHeight(2)
    accentLine:SetPoint("TOPLEFT",  frame, "TOPLEFT",  1, -37)
    accentLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -37)

    -- Create title EditBox WITH AUTO-SYNC
    frame.titleEditBox = RaidAssignments:AddCustomWindowTitleEditBox(frame, i)

    -- Title display
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 20)
    frame.title:SetPoint("TOP", frame.titleEditBox, "BOTTOM", 0, -5)

    -- Initialize with current title
    local currentTitle = RaidAssignments_Settings.CustomWindowTitles[i] or "Custom Assignments " .. tostring(i)
    frame.title:SetText(currentTitle)
    frame.titleEditBox:SetText(currentTitle)

    -- Add class filters
    local CLASS_ICON_SIZE_C = 18
    local CLASS_ICON_GAP_C  = 3
    local classIconStartX, classIconY, iconIndex = 8, -6, 1
    for n, class in pairs(RaidAssignments.Classes) do
        local r, l, t, b = RaidAssignments:ClassPos(class)
        local classframe = CreateFrame("Button", class.."_Custom"..i, frame)
        classframe:SetWidth(CLASS_ICON_SIZE_C)
        classframe:SetHeight(CLASS_ICON_SIZE_C)
        classframe:SetPoint("TOPLEFT", classIconStartX + (iconIndex - 1) * (CLASS_ICON_SIZE_C + CLASS_ICON_GAP_C), classIconY)
        classframe:SetFrameStrata("DIALOG")

        -- Dark background
        local cfBg = classframe:CreateTexture(nil, "BACKGROUND")
        cfBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        cfBg:SetVertexColor(0.06, 0.05, 0.03, 0.90)
        cfBg:SetAllPoints(classframe)
        classframe.cfBg = cfBg

        -- Gold border lines
        local function CCFLine() local t2 = classframe:CreateTexture(nil, "BORDER"); t2:SetTexture("Interface\\Buttons\\WHITE8X8"); return t2 end
        local cfBT = CCFLine(); local cfBB = CCFLine(); local cfBL = CCFLine(); local cfBR = CCFLine()
        cfBT:SetVertexColor(0.55, 0.42, 0.10, 1); cfBB:SetVertexColor(0.55, 0.42, 0.10, 1)
        cfBL:SetVertexColor(0.55, 0.42, 0.10, 1); cfBR:SetVertexColor(0.55, 0.42, 0.10, 1)
        cfBT:SetHeight(1); cfBT:SetPoint("TOPLEFT",classframe,"TOPLEFT",0,0);     cfBT:SetPoint("TOPRIGHT",classframe,"TOPRIGHT",0,0)
        cfBB:SetHeight(1); cfBB:SetPoint("BOTTOMLEFT",classframe,"BOTTOMLEFT",0,0); cfBB:SetPoint("BOTTOMRIGHT",classframe,"BOTTOMRIGHT",0,0)
        cfBL:SetWidth(1);  cfBL:SetPoint("TOPLEFT",classframe,"TOPLEFT",0,0);     cfBL:SetPoint("BOTTOMLEFT",classframe,"BOTTOMLEFT",0,0)
        cfBR:SetWidth(1);  cfBR:SetPoint("TOPRIGHT",classframe,"TOPRIGHT",0,0);   cfBR:SetPoint("BOTTOMRIGHT",classframe,"BOTTOMRIGHT",0,0)
        classframe.cfBorderLines = {cfBT, cfBB, cfBL, cfBR}

        -- Hover glow
        local cfGlow = classframe:CreateTexture(nil, "ARTWORK")
        cfGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
        cfGlow:SetVertexColor(0.80, 0.60, 0.10, 0.20)
        cfGlow:SetAllPoints(classframe)
        cfGlow:Hide()
        classframe.cfGlow = cfGlow

        -- Class icon (inset 2px)
        classframe.Icon = classframe:CreateTexture(nil, "OVERLAY")
        classframe.Icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        classframe.Icon:SetTexCoord(r, l, t, b)
        classframe.Icon:SetPoint("TOPLEFT", classframe, "TOPLEFT", 2, -2)
        classframe.Icon:SetPoint("BOTTOMRIGHT", classframe, "BOTTOMRIGHT", -2, 2)

        classframe:SetScript("OnEnter", function()
            classframe.cfGlow:Show()
            for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.95, 0.80, 0.30, 1) end
            local cr,cg,cb = RaidAssignments:GetClassColors(string.gsub(this:GetName(), "_Custom"..i, ""),"class")
            GameTooltip:SetOwner(classframe, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText("|cffFFFFFFShow|r "..string.gsub(this:GetName(), "_Custom"..i, ""), cr, cg, cb)
            GameTooltip:Show()
        end)
        classframe:SetScript("OnLeave", function()
            classframe.cfGlow:Hide()
            for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.55, 0.42, 0.10, 1) end
            GameTooltip:Hide()
        end)
        classframe:SetScript("OnMouseDown", function()
            if arg1 == "LeftButton" then
                local className = string.gsub(this:GetName(), "_Custom"..i, "")
                if RaidAssignments_Settings[className] == 1 then
                    RaidAssignments_Settings[className] = 0
                    classframe.Icon:SetVertexColor(0.25, 0.25, 0.25)
                    for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.30, 0.22, 0.06, 1) end
                else
                    RaidAssignments_Settings[className] = 1
                    classframe.Icon:SetVertexColor(1.0, 1.0, 1.0)
                    for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.55, 0.42, 0.10, 1) end
                end
                RaidAssignments:SyncClassFilters()
            end
        end)
        iconIndex = iconIndex + 1

        -- Initialize filter state
        local className = string.gsub(classframe:GetName(), "_Custom"..i, "")
        if RaidAssignments_Settings[className] == nil then
            RaidAssignments_Settings[className] = 1
        end
        if RaidAssignments_Settings[className] == 1 then
            classframe.Icon:SetVertexColor(1.0, 1.0, 1.0)
        else
            classframe.Icon:SetVertexColor(0.25, 0.25, 0.25)
            for _, ln in ipairs(classframe.cfBorderLines) do ln:SetVertexColor(0.30, 0.22, 0.06, 1) end
        end
    end

    -- Custom close button (top-right)
    frame.closeButton = RaidAssignments:MakeBtn(frame, 22, 22, "X", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        frame:Hide()
    end)
    frame.closeButton.label:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 13)
    frame.closeButton.label:SetTextColor(0.90, 0.35, 0.35, 1)
    for _, ln in ipairs(frame.closeButton.borderLines) do ln:SetVertexColor(0.6, 0.2, 0.2, 1) end
    frame.closeButton:SetScript("OnEnter", function()
        frame.closeButton.glow:Show()
        for _, ln in ipairs(frame.closeButton.borderLines) do ln:SetVertexColor(0.9, 0.3, 0.3, 1) end
        frame.closeButton.label:SetTextColor(1, 0.55, 0.55, 1)
    end)
    frame.closeButton:SetScript("OnLeave", function()
        frame.closeButton.glow:Hide()
        for _, ln in ipairs(frame.closeButton.borderLines) do ln:SetVertexColor(0.6, 0.2, 0.2, 1) end
        frame.closeButton.label:SetTextColor(0.90, 0.35, 0.35, 1)
    end)
    frame.closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    frame.closeButton:SetFrameStrata("DIALOG")

    -- Remove All Button
    local removeAllBtn = RaidAssignments:MakeBtn(frame, 100, 22, "Remove All", nil)
    removeAllBtn:SetPoint("TOPRIGHT", frame.closeButton, "TOPLEFT", -8, 0)
    removeAllBtn:SetFrameStrata("DIALOG")
    removeAllBtn:SetScript("OnClick", function()
        if IsRaidOfficer() then
            PlaySound("igMainMenuOptionCheckBoxOn")

            -- Clear all assignments for this custom window
            for mark = 1, 10 do
                local maxSlots = (mark >= 9 and mark <= 10) and 6 or 5
                for slot = 1, maxSlots do
                    RaidAssignments.CustomMarks[i][mark][slot] = nil
                end
            end

            -- Hide all frames
            for mark = 1, 10 do
                if RaidAssignments.CustomFrames[i].frames and RaidAssignments.CustomFrames[i].frames[mark] then
                    for name, frame in pairs(RaidAssignments.CustomFrames[i].frames[mark]) do
                        if frame and frame.Hide then
                            frame:Hide()
                        end
                    end
                    RaidAssignments.CustomFrames[i].frames[mark] = {}
                end
            end

            -- Update display and sync
            RaidAssignments:UpdateCustom(i)
            RaidAssignments:SendCustom(i)
            DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments|r: All assignments removed from Custom " .. i)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6E RaidAssignments|r: You must be raid leader/assistant to remove assignments")
        end
    end)

    local padding = 5

    -- Regular marks 1-8
    local function MakeCustomEmptySlots(parent, numSlots)
        for slot = 1, numSlots do
            local ghost = CreateFrame("Frame", nil, parent)
            ghost:SetWidth(80)
            ghost:SetHeight(25)
            -- Matches: f:SetPoint("LEFT", markFrame, "RIGHT", 10 + (85*(slot-1)), 0)
            ghost:SetPoint("LEFT", parent, "RIGHT", 10 + (85 * (slot - 1)), 0)
            ghost:SetFrameStrata("DIALOG")
            local eT = ghost:CreateTexture(nil, "ARTWORK")
            eT:SetTexture("Interface\\Buttons\\WHITE8X8") eT:SetVertexColor(1,1,1,0.06) eT:SetHeight(1)
            eT:SetPoint("TOPLEFT",ghost,"TOPLEFT",0,0) eT:SetPoint("TOPRIGHT",ghost,"TOPRIGHT",0,0)
            local eB = ghost:CreateTexture(nil, "ARTWORK")
            eB:SetTexture("Interface\\Buttons\\WHITE8X8") eB:SetVertexColor(1,1,1,0.06) eB:SetHeight(1)
            eB:SetPoint("BOTTOMLEFT",ghost,"BOTTOMLEFT",0,0) eB:SetPoint("BOTTOMRIGHT",ghost,"BOTTOMRIGHT",0,0)
            local eL = ghost:CreateTexture(nil, "ARTWORK")
            eL:SetTexture("Interface\\Buttons\\WHITE8X8") eL:SetVertexColor(1,1,1,0.06) eL:SetWidth(1)
            eL:SetPoint("TOPLEFT",ghost,"TOPLEFT",0,0) eL:SetPoint("BOTTOMLEFT",ghost,"BOTTOMLEFT",0,0)
            local eR = ghost:CreateTexture(nil, "ARTWORK")
            eR:SetTexture("Interface\\Buttons\\WHITE8X8") eR:SetVertexColor(1,1,1,0.06) eR:SetWidth(1)
            eR:SetPoint("TOPRIGHT",ghost,"TOPRIGHT",0,0) eR:SetPoint("BOTTOMRIGHT",ghost,"BOTTOMRIGHT",0,0)
        end
    end

    for displayOrder = 1, 8 do
        local m = 9 - displayOrder
        local r, l, t, b = RaidAssignments:GetMarkPos(m)
        local icon = CreateFrame("Frame", "C"..i.."_M"..m, frame)
        icon:SetWidth(35)
        icon:SetHeight(35)
        icon:SetPoint("TOPLEFT", 50, -75 - ((35 + padding) * (displayOrder - 1)))
        icon:EnableMouse(true)
        icon:SetScript("OnEnter", function()
            RaidAssignments:OpenCustomToolTip(this:GetName(), i)
        end)
        icon:SetScript("OnLeave", function() end)

        icon.Icon = icon:CreateTexture(nil, "ARTWORK")
        icon.Icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        icon.Icon:SetTexCoord(r, l, t, b)
        icon.Icon:SetAllPoints(icon)
        MakeCustomEmptySlots(icon, 5)  -- 5 slots for regular custom marks
    end

    -- Custom marks 9 and 10
    for m = 9, 10 do
        local displayOrder = m
        local icon = CreateFrame("Frame", "C"..i.."_M"..m, frame)
        icon:SetWidth(35)
        icon:SetHeight(35)
        icon:SetPoint("TOPLEFT", 50, -75 - ((35 + padding) * (displayOrder - 1)) - ((m-9) * 30))
        icon:EnableMouse(true)
        icon:SetScript("OnEnter", function()
            RaidAssignments:OpenCustomToolTip(this:GetName(), i)
        end)
        icon:SetScript("OnLeave", function() end)

        icon.Icon = icon:CreateTexture(nil, "ARTWORK")
        icon.Icon:SetTexture("Interface\\AddOns\\RaidAssignments\\assets\\Custom.tga")
        icon.Icon:SetAllPoints(icon)
        MakeCustomEmptySlots(icon, 6)  -- 6 slots for custom marks 9-10

        local editBoxName = "C"..i.."_"..m.."_Edit"
        local editBox = RaidAssignments:MakeEditBox(editBoxName, frame, 90, 24)
        editBox:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", -20, -5)

        local defaultText = RaidAssignments.CustomRealMarks[i][m] or ("Custom " .. (m - 8))
        editBox:SetText(defaultText)

        -- Auto-sync on label change
        editBox:SetScript("OnEnterPressed", function()
            local txt = this:GetText()
            if txt and txt ~= "" then
                RaidAssignments.CustomRealMarks[i][m] = txt
                RaidAssignments:SendCustomLabels(i)
                RaidAssignments:UpdateCustom(i)
            else
                local defaultText = "Custom " .. (m - 8)
                this:SetText(defaultText)
                RaidAssignments.CustomRealMarks[i][m] = defaultText
                RaidAssignments:SendCustomLabels(i)
            end
            this:ClearFocus()
        end)

        editBox:SetScript("OnEscapePressed", function()
            local currentText = RaidAssignments.CustomRealMarks[i][m] or ("Custom " .. (m - 8))
            this:SetText(currentText)
            this:ClearFocus()
        end)
    end

    local postBtn = RaidAssignments:MakeBtn(frame, 160, 24, "Post Assignments", function()
        if IsRaidOfficer() then
            PlaySound("igMainMenuOptionCheckBoxOn")
            RaidAssignments:PostCustomAssignments(i)
        end
    end)
    postBtn:SetPoint("BOTTOM", frame, "BOTTOM", -100, 20)
    postBtn:SetFrameStrata("DIALOG")

    local backBtn = RaidAssignments:MakeBtn(frame, 160, 24, "Back to Main", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        frame:Hide()
        RaidAssignments.Settings["Animation"] = false
        RaidAssignments.Settings["MainFrame"] = false
        RaidAssignments.Settings["SizeX"] = 0
        RaidAssignments.Settings["SizeY"] = 0
        RaidAssignments:Show()
    end)
    backBtn:SetPoint("BOTTOM", frame, "BOTTOM", 100, 20)
    backBtn:SetFrameStrata("DIALOG")

    frame:Hide()
    RaidAssignments.CustomFrames[i].frame = frame
end

function RaidAssignments:ConfigAllCustomFrames()
    for i = 1, 8 do
        RaidAssignments:ConfigCustomFrame(i)
    end
end

function RaidAssignments:UpdateCustom(i)
    local frameData = RaidAssignments.CustomFrames[i]
    if not frameData or not frameData.frame then return end
    local parent = frameData.frame
    RaidAssignments.CustomFrames[i].frames = RaidAssignments.CustomFrames[i].frames or {}
    local inRaid = GetRaidRosterInfo(1) or RaidAssignments.TestMode

    if inRaid then
        for mark = 1, 10 do
            local maxSlots = (mark >= 9 and mark <= 10) and 6 or 5
            RaidAssignments.CustomFrames[i].frames[mark] = RaidAssignments.CustomFrames[i].frames[mark] or {}

            -- Hide all frames first
            for _, f in pairs(RaidAssignments.CustomFrames[i].frames[mark]) do
                if f and f.Hide then f:Hide() end
            end

            -- Show assigned players
            for slot = 1, maxSlots do
                local pname = RaidAssignments.CustomMarks[i][mark] and RaidAssignments.CustomMarks[i][mark][slot]
                if pname and pname ~= "" then
                    if not RaidAssignments.CustomFrames[i].frames[mark][pname] then
                        local f = CreateFrame("Button", nil, parent)
                        f:SetWidth(80)
                        f:SetHeight(25)
                        f:EnableMouse(true)

                        -- Black background
                        local fbg = f:CreateTexture(nil, "BACKGROUND")
                        fbg:SetTexture("Interface\\Buttons\\WHITE8X8")
                        fbg:SetVertexColor(0.04, 0.04, 0.04, 0.96)
                        fbg:SetAllPoints(f)
                        f.fbg = fbg

                        -- Class-coloured border lines
                        local function MkL() local t = f:CreateTexture(nil, "BORDER"); t:SetTexture("Interface\\Buttons\\WHITE8X8"); return t end
                        local bT=MkL(); local bB=MkL(); local bL=MkL(); local bR=MkL()
                        bT:SetHeight(1); bT:SetPoint("TOPLEFT",f,"TOPLEFT",0,0);         bT:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0)
                        bB:SetHeight(1); bB:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",0,0);   bB:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",0,0)
                        bL:SetWidth(1);  bL:SetPoint("TOPLEFT",f,"TOPLEFT",0,0);         bL:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",0,0)
                        bR:SetWidth(1);  bR:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0);       bR:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",0,0)
                        f.borderLines = {bT, bB, bL, bR}

                        -- Inner colour fill
                        local fill = f:CreateTexture(nil, "ARTWORK")
                        fill:SetTexture("Interface\\Buttons\\WHITE8X8")
                        fill:SetPoint("TOPLEFT",     f, "TOPLEFT",     1, -1)
                        fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
                        f.fill = fill
                        f.texture = fill  -- alias

                        -- Hover glow
                        local glow = f:CreateTexture(nil, "OVERLAY")
                        glow:SetTexture("Interface\\Buttons\\WHITE8X8")
                        glow:SetAllPoints(f)
                        glow:Hide()
                        f.glow = glow

                        -- Player name
                        f.name = f:CreateFontString(nil, "OVERLAY")
                        f.name:SetPoint("CENTER", f, "CENTER", 0, 0)
                        f.name:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 11)
                        f.name:SetTextColor(1, 1, 1, 1)
                        f.name:SetShadowOffset(1, -1)
                        f.name:SetShadowColor(0, 0, 0, 1)
                        f.name:SetText(pname)

                        f:SetScript("OnEnter", function() f.glow:Show() end)
                        f:SetScript("OnLeave", function() f.glow:Hide() end)

                        -- Store context for removal
                        f.customIndex = i
                        f.mark = mark
                        f.playerName = pname
                        f.slot = slot

                        f:SetScript("OnClick", function()
                            if IsRaidOfficer() then
                                local maxSlots = (this.mark >= 9 and this.mark <= 10) and 6 or 5
                                local removed = false
                                for k = 1, maxSlots do
                                    if RaidAssignments.CustomMarks[this.customIndex][this.mark] and
                                       RaidAssignments.CustomMarks[this.customIndex][this.mark][k] == this.playerName then
                                        RaidAssignments.CustomMarks[this.customIndex][this.mark][k] = nil
                                        removed = true
                                        break
                                    end
                                end
                                if removed then
                                    this:Hide()
                                    if RaidAssignments.CustomFrames[this.customIndex].frames[this.mark] then
                                        RaidAssignments.CustomFrames[this.customIndex].frames[this.mark][this.playerName] = nil
                                    end
                                    RaidAssignments:UpdateCustom(this.customIndex)
                                    RaidAssignments:SendCustom(this.customIndex)
                                end
                            end
                        end)

                        f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                        f:SetFrameStrata("TOOLTIP")
                        RaidAssignments.CustomFrames[i].frames[mark][pname] = f
                    end

                    local f = RaidAssignments.CustomFrames[i].frames[mark][pname]
                    f:ClearAllPoints()
                    local markFrame = _G["C"..i.."_M"..mark]
                    if markFrame then
                        f:SetPoint("LEFT", markFrame, "RIGHT", 10 + (85 * (slot - 1)), 0)
                    else
                        f:SetPoint("LEFT", parent, "LEFT", 100 + (85 * slot), -60 - ((35 + 5) * (mark - 1)))
                    end

                    local r, g, b = RaidAssignments:GetClassColors(pname, "rgb")
                    RA_ApplyFrameColor(f, r, g, b)

                    f:Show()
                end
            end
        end
    else
        for mark = 1, 10 do
            for _, v in pairs(RaidAssignments.CustomFrames[i].frames[mark] or {}) do
                if v and v.Hide then v:Hide() end
            end
        end
    end
end

-- (Custom frames are fully initialized in the ADDON_LOADED handler above)

--  Attach 8 Custom Assignment Buttons to Main Frame

function RaidAssignments:CreateCustomAssignmentButtons()
    if not RaidAssignments.bg then return end

    local parent = RaidAssignments.bg

    -- Remove existing buttons if any
    if RaidAssignments.CustomButtons then
        for _, b in ipairs(RaidAssignments.CustomButtons) do
            if b and b.Hide then b:Hide() end
        end
    end
    RaidAssignments.CustomButtons = {}

    -- Create buttons: C1-C8, centered in row 2
    -- Row2: 11x76px + 10x8px = 916px -> x_start = (960-916)/2 = 22
    local ROW2_W   = 76
    local ROW2_GAP = 8
    local ROW2_X   = math.floor((960 - (11 * ROW2_W + 10 * ROW2_GAP)) / 2)  -- 22
    local ROW2_Y   = 14

    for i = 1, 8 do
        local xOff = ROW2_X + (i - 1) * (ROW2_W + ROW2_GAP)
        local btn = RaidAssignments:MakeBtn(parent, ROW2_W, 24, "C"..i, nil)
        btn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", xOff, ROW2_Y)
        -- Green tint to visually distinguish C-buttons from Post/nav buttons
        for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(0.20, 0.60, 0.25, 1) end
        btn.label:SetTextColor(0.45, 0.90, 0.50, 1)

        -- Button click handler
        btn:SetScript("OnClick", (function(customIndex)
            return function()
                PlaySound("igMainMenuOptionCheckBoxOn")
                if RaidAssignments.ToolTip then RaidAssignments.ToolTip:Hide() end
                if RaidAssignments.HealToolTip then RaidAssignments.HealToolTip:Hide() end
                RaidAssignments.Settings["Animation"] = true
                RaidAssignments.Settings["MainFrame"] = false

                RaidAssignments:ConfigCustomFrame(customIndex)
                RaidAssignments:Hide()
                if RaidAssignments.CustomFrames[customIndex] and RaidAssignments.CustomFrames[customIndex].frame then
                    RaidAssignments.CustomFrames[customIndex].frame:Show()
                    RaidAssignments:UpdateCustom(customIndex)
                    -- NOTE: Intentionally NOT auto-sending here.
                    -- If the officer just loaded in, their CustomMarks may be empty,
                    -- and sending would wipe everyone else's data for this window.
                    -- Data will be sent on the next manual add/remove action.
                end
            end
        end)(i))

        -- Add tooltip (augment MakeBtn's OnEnter/OnLeave to also show tooltip)
        btn:SetScript("OnEnter", (function(btnIndex, b)
            return function()
                b.glow:Show()
                b.glow:SetVertexColor(0.10, 0.55, 0.15, 0.25)
                for _, ln in ipairs(b.borderLines) do ln:SetVertexColor(0.35, 0.90, 0.40, 1) end
                b.label:SetTextColor(0.70, 1.0, 0.75, 1)
                GameTooltip:SetOwner(b, "ANCHOR_TOP")
                GameTooltip:SetText("Custom Assignments " .. btnIndex)
                GameTooltip:Show()
            end
        end)(i, btn))

        btn:SetScript("OnLeave", (function(b)
            return function()
                b.glow:Hide()
                for _, ln in ipairs(b.borderLines) do ln:SetVertexColor(0.20, 0.60, 0.25, 1) end
                b.label:SetTextColor(0.45, 0.90, 0.50, 1)
                GameTooltip:Hide()
            end
        end)(btn))

        table.insert(RaidAssignments.CustomButtons, btn)
    end

    -- Remove the container frame since it's no longer needed
    if RaidAssignments.CustomButtonsContainer then
        RaidAssignments.CustomButtonsContainer:Hide()
        RaidAssignments.CustomButtonsContainer = nil
    end
end

SLASH_RAIDASSIGNMENTS1 = "/rc"
SlashCmdList["RAIDASSIGNMENTS"] = function(msg)
    local spacePos = string.find(msg, " ")
    local cmd, arg
    if spacePos then
        cmd = string.sub(msg, 1, spacePos - 1)
        arg = string.sub(msg, spacePos + 1)
    else
        cmd = msg
        arg = ""
    end

    cmd = string.lower(cmd or "")

    if cmd == "custom" and tonumber(arg) then
        local i = tonumber(arg)
        if i >= 1 and i <= 8 then
            RaidAssignments:ConfigCustomFrame(i)
            if RaidAssignments.CustomFrames[i] and RaidAssignments.CustomFrames[i].frame then
                RaidAssignments.CustomFrames[i].frame:Show()
                RaidAssignments:UpdateCustom(i)
                DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99RaidAssignments:|r Opened Custom Assignments " .. i)
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99RaidAssignments:|r Usage: /rc custom [1-8]")
        end
    elseif cmd == "resetpos" then
        -- Reset YourMarkFrame anchor + frame
        RaidAssignments_Settings["YourMarkFrameX"]     = 0
        RaidAssignments_Settings["YourMarkFrameY"]     = 0
        RaidAssignments_Settings["YourMarkFramePoint"] = "CENTER"
        RaidAssignments_Settings["YourMarkFrameRP"]    = "CENTER"
        RaidAssignments_Settings["YourMarkFrameScale"] = nil
        local markAnchor = getglobal("RaidAssignmentsYourMarkAnchor")
        if markAnchor then
            markAnchor:ClearAllPoints()
            markAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        if RaidAssignments.YourMarkFrame then
            RaidAssignments.YourMarkFrame:SetScale(1.0)
        end
        -- Reset YourCurseFrame anchor + frame
        RaidAssignments_Settings["YourCurseFrameX"]     = 0
        RaidAssignments_Settings["YourCurseFrameY"]     = -50
        RaidAssignments_Settings["YourCurseFramePoint"] = "CENTER"
        RaidAssignments_Settings["YourCurseFrameRP"]    = "CENTER"
        RaidAssignments_Settings["YourCurseFrameScale"] = nil
        local curseAnchor = getglobal("RaidAssignmentsYourCurseAnchor")
        if curseAnchor then
            curseAnchor:ClearAllPoints()
            curseAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -50)
        end
        if RaidAssignments.YourCurseFrame then
            RaidAssignments.YourCurseFrame:SetScale(1.0)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99RaidAssignments:|r Frames reset to center of screen.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99RaidAssignments:|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /rc custom [1-8] - Open a Custom Assignments window")
        DEFAULT_CHAT_FRAME:AddMessage("  /rc resetpos     - Reset frames to center of screen")
    end
end

function RaidAssignments:OpenCustomToolTip(frameName, customIndex)
    if GetRaidRosterInfo(1) or RaidAssignments.TestMode then
        -- Parse frame name to get mark number
        local mark = tonumber(string.sub(frameName, string.find(frameName, "M") + 1))
        if not mark then return end

        -- Hide any existing custom tooltip first
        if RaidAssignments.CustomToolTip and RaidAssignments.CustomToolTip:IsShown() then
            RaidAssignments.CustomToolTip:Hide()
        end

        -- Create tooltip frame if it doesn't exist, otherwise reuse
        if not RaidAssignments.CustomToolTip then
            RaidAssignments.CustomToolTip = CreateFrame("Frame", "RaidAssignmentsCustomToolTip", UIParent)
            RaidAssignments.CustomToolTip:SetFrameStrata("FULLSCREEN")
            RaidAssignments.CustomToolTip:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                tile = false,
                tileSize = 16,
                edgeSize = 2,
                insets = { left = 1, right = 1, top = 1, bottom = 1 }
            })
            RaidAssignments.CustomToolTip:SetBackdropColor(0, 0, 0, 1)
            RaidAssignments.CustomToolTip:SetBackdropBorderColor(1, 1, 1, 0.5)
            RaidAssignments.CustomToolTip:EnableMouse(true)
            RaidAssignments.CustomToolTip:EnableMouseWheel(true)
        end

        local tooltip = RaidAssignments.CustomToolTip

        -- Clear ALL existing frames from ALL custom indexes to prevent cross-contamination
        for i = 1, 8 do
            if RaidAssignments.CustomFrames[i] and RaidAssignments.CustomFrames[i].tooltipFrames then
                for name, frame in pairs(RaidAssignments.CustomFrames[i].tooltipFrames) do
                    if frame and frame.Hide then
                        frame:Hide()
                        frame:SetParent(nil)
                    end
                end
                RaidAssignments.CustomFrames[i].tooltipFrames = {}
            end
        end

        -- Initialize tooltip frames storage for this custom index if needed
        if not RaidAssignments.CustomFrames[customIndex].tooltipFrames then
            RaidAssignments.CustomFrames[customIndex].tooltipFrames = {}
        end

        local roster = RaidAssignments.TestMode and RaidAssignments.TestRoster or {}
        local numMembers = RaidAssignments.TestMode and table.getn(RaidAssignments.TestRoster) or GetNumRaidMembers()

        -- Collect eligible players
        local eligiblePlayers = {}
        for i = 1, numMembers do
            local name, class
            if RaidAssignments.TestMode then
                name = roster[i] and roster[i].name
                class = roster[i] and roster[i].class
            else
                name = UnitName("raid"..i)
                class = UnitClass("raid"..i)
            end
            if name and class then
                local f = false
                -- Check if player is already assigned to ANY mark in this custom window
                for m = 1, 10 do
                    local maxSlots = (m >= 9 and m <= 10) and 6 or 5
                    for s = 1, maxSlots do
                        if RaidAssignments.CustomMarks[customIndex][m] and
                           RaidAssignments.CustomMarks[customIndex][m][s] == name then
                            f = true
                            break
                        end
                    end
                    if f then break end
                end
                if not f and RaidAssignments_Settings[class] == 1 then
                    table.insert(eligiblePlayers, name)
                end
            end
        end

        -- Calculate columns
        local totalPlayers = table.getn(eligiblePlayers)
        if totalPlayers == 0 then
            tooltip:Hide()
            return
        end

        local maxPlayersPerColumn = 10
        local numColumns = math.ceil(totalPlayers / maxPlayersPerColumn)
        local playersPerColumn = math.ceil(totalPlayers / numColumns)
        local actualRows = math.min(playersPerColumn, totalPlayers)

        -- Create columns
        local columnWidth = 80
        local totalWidth = columnWidth * numColumns
        local totalHeight = 25 * actualRows

        -- Set up the tooltip backdrop
        tooltip:SetWidth(totalWidth)
        tooltip:SetHeight(totalHeight)
        -- Position tooltip on LEFT side of the mark
        tooltip:SetPoint("TOPRIGHT", frameName, "TOPLEFT", 0, 0)

        -- Store custom index and mark for later use
        tooltip.customIndex = customIndex
        tooltip.mark = mark
        tooltip.originalMark = _G[frameName]
        tooltip.isVisible = true

        -- Walk the full parent chain to check if 'child' is under 'ancestor'.
        local function IsUnder(child, ancestor)
            local f = child
            while f do
                if f == ancestor then return true end
                f = f:GetParent()
            end
            return false
        end

        local function HideCustomTooltip()
            RaidAssignments.CustomToolTip.isVisible = false
            RaidAssignments.CustomToolTip:Hide()
            if RaidAssignments.CustomFrames[customIndex] and RaidAssignments.CustomFrames[customIndex].tooltipFrames then
                for _, frame in pairs(RaidAssignments.CustomFrames[customIndex].tooltipFrames) do
                    if frame and frame.Hide then
                        frame:Hide()
                        frame:SetParent(nil)
                    end
                end
                RaidAssignments.CustomFrames[customIndex].tooltipFrames = {}
            end
        end

        tooltip:SetScript("OnLeave", function()
            local mouseFocus = GetMouseFocus()
            local overTooltip = mouseFocus and IsUnder(mouseFocus, this)
            local overMark    = mouseFocus and IsUnder(mouseFocus, this.originalMark)
            if not overTooltip and not overMark then
                HideCustomTooltip()
            end
        end)

        if tooltip.originalMark then
            tooltip.originalMark:SetScript("OnLeave", function()
                local mouseFocus = GetMouseFocus()
                local overMark    = mouseFocus and IsUnder(mouseFocus, this)
                local overTooltip = mouseFocus and IsUnder(mouseFocus, RaidAssignments.CustomToolTip)
                if not overMark and not overTooltip then
                    HideCustomTooltip()
                end
            end)
        end

        -- Create player frames
        for col = 1, numColumns do
            local startIndex = (col - 1) * playersPerColumn + 1
            local endIndex = math.min(startIndex + playersPerColumn - 1, totalPlayers)

            for i = startIndex, endIndex do
                local name = eligiblePlayers[i]
                local rowIndex = i - startIndex

                -- Create new frame
                local frame = RaidAssignments:AddCustomToolTipFrame(name, tooltip, customIndex)
                RaidAssignments.CustomFrames[customIndex].tooltipFrames[name] = frame

                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", tooltip, "TOPLEFT", (col - 1) * columnWidth + 2, -2 - (25 * rowIndex))
                local r, g, b = RaidAssignments:GetClassColors(name, "rgb")
                RA_ApplyFrameColor(frame, r, g, b)
                frame:Show()
            end
        end

        tooltip:Show()
    end
end

function RaidAssignments:AddCustomToolTipFrame(name, tooltip, customIndex)
    -- Clean up any existing frame with this name first
    if RaidAssignments.CustomFrames[customIndex].tooltipFrames and RaidAssignments.CustomFrames[customIndex].tooltipFrames[name] then
        local oldFrame = RaidAssignments.CustomFrames[customIndex].tooltipFrames[name]
        if oldFrame and oldFrame.Hide then
            oldFrame:Hide()
            oldFrame:SetParent(nil)
        end
        RaidAssignments.CustomFrames[customIndex].tooltipFrames[name] = nil
    end

    local frame = CreateFrame("Button", nil, tooltip)
    frame:SetWidth(80)
    frame:SetHeight(25)
    frame:EnableMouse(true)

    -- Black background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.04, 0.04, 0.04, 0.96)
    bg:SetAllPoints(frame)
    frame.bg = bg

    -- Class-coloured border lines
    local function MkLine()
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        return t
    end
    local bT = MkLine(); local bB = MkLine(); local bL = MkLine(); local bR = MkLine()
    bT:SetHeight(1); bT:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);         bT:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
    bB:SetHeight(1); bB:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0);   bB:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    bL:SetWidth(1);  bL:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0);         bL:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0)
    bR:SetWidth(1);  bR:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0);       bR:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    frame.borderLines = {bT, bB, bL, bR}

    -- Subtle inner colour fill
    local fill = frame:CreateTexture(nil, "ARTWORK")
    fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    fill:SetPoint("TOPLEFT",     frame, "TOPLEFT",     1, -1)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.fill = fill
    frame.texture = fill

    -- Hover glow
    local glow = frame:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    glow:SetAllPoints(frame)
    glow:Hide()
    frame.glow = glow

    -- Player name
    frame.name = frame:CreateFontString(nil, "OVERLAY")
    frame.name:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.name:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 11)
    frame.name:SetTextColor(1, 1, 1, 1)
    frame.name:SetShadowOffset(1, -1)
    frame.name:SetShadowColor(0, 0, 0, 1)
    frame.name:SetText(name)

    frame:SetScript("OnEnter", function() frame.glow:Show() end)
    frame:SetScript("OnLeave", function() frame.glow:Hide() end)

    -- Toggle add/remove for custom assignments
    frame:SetScript("OnClick", function()
        if IsRaidOfficer() then
            local mark = tooltip.mark
            local cIndex = tooltip.customIndex
            local f = true
            local maxSlots = (mark >= 9 and mark <= 10) and 6 or 5

            -- Check if player is already assigned
            for k = 1, maxSlots do
                if RaidAssignments.CustomMarks[cIndex][mark] and
                   RaidAssignments.CustomMarks[cIndex][mark][k] == name then
                    f = false
                    RaidAssignments.CustomMarks[cIndex][mark][k] = nil
                    this:Hide()
                    if RaidAssignments.CustomFrames[cIndex].frames[mark] then
                        RaidAssignments.CustomFrames[cIndex].frames[mark][name] = nil
                    end
                    RaidAssignments:UpdateCustom(cIndex)
                    RaidAssignments:SendCustom(cIndex)
                    if RaidAssignments.CustomToolTip and RaidAssignments.CustomToolTip:IsShown() then
                        RaidAssignments.CustomToolTip:Hide()
                        RaidAssignments:OpenCustomToolTip("C" .. cIndex .. "_M" .. mark, cIndex)
                    end
                    return
                end
            end

            -- Add player if not assigned
            if f then
                local slot = nil
                for i = 1, maxSlots do
                    if not RaidAssignments.CustomMarks[cIndex][mark][i] then
                        slot = i
                        break
                    end
                end
                if slot then
                    RaidAssignments.CustomMarks[cIndex][mark][slot] = name
                    RaidAssignments:UpdateCustom(cIndex)
                    RaidAssignments:SendCustom(cIndex)
                    this:Hide()
                    if RaidAssignments.CustomToolTip and RaidAssignments.CustomToolTip:IsShown() then
                        RaidAssignments.CustomToolTip:Hide()
                        RaidAssignments:OpenCustomToolTip("C" .. cIndex .. "_M" .. mark, cIndex)
                    end
                end
            end
        end
    end)
    return frame
end

function RaidAssignments:AddCustomAssignment(name, mark, customIndex)
    mark = tonumber(mark)
    customIndex = tonumber(customIndex)

    -- Ensure the mark exists in the table
    if not RaidAssignments.CustomMarks[customIndex][mark] then
        RaidAssignments.CustomMarks[customIndex][mark] = {}
    end

    -- Find the first available slot
    local slot = nil
    local maxSlots = (mark >= 9 and mark <= 10) and 6 or 5
    for i = 1, maxSlots do
        if not RaidAssignments.CustomMarks[customIndex][mark][i] then
            slot = i
            break
        end
    end

    if slot then
        RaidAssignments.CustomMarks[customIndex][mark][slot] = name
    end
end

function RaidAssignments:OpenGeneralToolTip(frameName)
    if GetRaidRosterInfo(1) or RaidAssignments.TestMode then
        -- Clear existing tooltip frames
        if RaidAssignments.Frames["GeneralToolTip"] then
            for k, v in pairs(RaidAssignments.Frames["GeneralToolTip"]) do
                if v and v.Hide then
                    v:Hide()
                end
            end
        else
            RaidAssignments.Frames["GeneralToolTip"] = {}
        end

        local n = tonumber(string.sub(frameName, 2))
        local roster = RaidAssignments.TestMode and RaidAssignments.TestRoster or {}
        local numMembers = RaidAssignments.TestMode and table.getn(RaidAssignments.TestRoster) or GetNumRaidMembers()

        -- Collect eligible players (same logic as before)
        local eligiblePlayers = {}
        for i = 1, numMembers do
            local name, class
            if RaidAssignments.TestMode then
                name = roster[i] and roster[i].name
                class = roster[i] and roster[i].class
            else
                name = UnitName("raid"..i)
                class = UnitClass("raid"..i)
            end
            if name and class then
                local f = false
                -- Check if player is already assigned to ANY general mark (1-10)
                for j = 1, 10 do
                    local maxSlots = (j >= 9 and j <= 10) and 7 or 5
                    for k = 1, maxSlots do
                        if RaidAssignments.GeneralMarks[j] and RaidAssignments.GeneralMarks[j][k] == name then
                            f = true
                            break
                        end
                    end
                    if f then break end
                end
                if not f and RaidAssignments_Settings[class] == 1 then
                    table.insert(eligiblePlayers, name)
                end
            end
        end

        local totalPlayers = table.getn(eligiblePlayers)
        if totalPlayers == 0 then
            RaidAssignments.GeneralToolTip:Hide()
            return
        end

        -- Use the same column calculation as other tooltips
        local maxPlayersPerColumn = 10
        local numColumns = math.ceil(totalPlayers / maxPlayersPerColumn)
        local playersPerColumn = math.ceil(totalPlayers / numColumns)
        local actualRows = math.min(playersPerColumn, totalPlayers)

        local columnWidth = 80
        local totalWidth = columnWidth * numColumns
        local totalHeight = 25 * actualRows

        -- Position and size the tooltip
        RaidAssignments.GeneralToolTip:SetWidth(totalWidth)
        RaidAssignments.GeneralToolTip:SetHeight(totalHeight)
        RaidAssignments.GeneralToolTip:SetPoint("TOPRIGHT", frameName, "TOPLEFT", 0, 0)

        -- ENSURE PROPER STRATA WHEN SHOWN
        RaidAssignments.GeneralToolTip:SetFrameStrata("FULLSCREEN")

        -- Store references
        RaidAssignments.GeneralToolTip.originalMark = _G[frameName]
        RaidAssignments.GeneralToolTip.isVisible = true

        -- Improved mouse handling
        RaidAssignments.GeneralToolTip:SetScript("OnLeave", function()
            -- Check if mouse is actually leaving both the tooltip AND the original mark
            local mouseFocus = GetMouseFocus()
            local overTooltip = (mouseFocus == this) or (mouseFocus and mouseFocus:GetParent() == this)
            local overMark = (mouseFocus == this.originalMark) or (mouseFocus and mouseFocus:GetParent() == this.originalMark)

            if not overTooltip and not overMark then
                this.isVisible = false
                this:Hide()
            end
        end)

        -- Improved OnLeave for the original mark frame
        if RaidAssignments.GeneralToolTip.originalMark then
            RaidAssignments.GeneralToolTip.originalMark:SetScript("OnLeave", function()
                -- Check if mouse is actually leaving both the mark AND the tooltip
                local mouseFocus = GetMouseFocus()
                local overMark = (mouseFocus == this) or (mouseFocus and mouseFocus:GetParent() == this)
                local overTooltip = (mouseFocus == RaidAssignments.GeneralToolTip) or (mouseFocus and mouseFocus:GetParent() == RaidAssignments.GeneralToolTip)

                if not overMark and not overTooltip then
                    RaidAssignments.GeneralToolTip.isVisible = false
                    RaidAssignments.GeneralToolTip:Hide()
                end
            end)
        end

        -- Create player frames
        for col = 1, numColumns do
            local startIndex = (col - 1) * playersPerColumn + 1
            local endIndex = math.min(startIndex + playersPerColumn - 1, totalPlayers)

            for i = startIndex, endIndex do
                local name = eligiblePlayers[i]
                local rowIndex = i - startIndex

                RaidAssignments.Frames["GeneralToolTip"][name] = RaidAssignments.Frames["GeneralToolTip"][name] or RaidAssignments:AddToolTipFrame(name, RaidAssignments.GeneralToolTip)
                local frame = RaidAssignments.Frames["GeneralToolTip"][name]
                frame:SetPoint("TOPLEFT", RaidAssignments.GeneralToolTip, "TOPLEFT", (col - 1) * columnWidth + 2, -2 - (25 * rowIndex))
                local r, g, b = RaidAssignments:GetClassColors(name, "rgb")
                RA_ApplyFrameColor(frame, r, g, b)
                frame:Show()
            end
        end

        RaidAssignments.Settings["active_general"] = n
        RaidAssignments.GeneralToolTip:Show()
    end
end

function RaidAssignments:SyncClassFilters()
    -- Update all class icons in main frame
    for _, class in pairs(RaidAssignments.Classes) do
        local classframe = _G[class]
        if classframe and classframe.Icon then
            if RaidAssignments_Settings[class] == 1 then
                classframe.Icon:SetVertexColor(1.0, 1.0, 1.0)
            else
                classframe.Icon:SetVertexColor(0.5, 0.5, 0.5)
            end
        end
    end

    -- Update class icons in general frame
    for _, class in pairs(RaidAssignments.Classes) do
        local classframe = _G[class.."_General"]
        if classframe and classframe.Icon then
            if RaidAssignments_Settings[class] == 1 then
                classframe.Icon:SetVertexColor(1.0, 1.0, 1.0)
            else
                classframe.Icon:SetVertexColor(0.5, 0.5, 0.5)
            end
        end
    end

    -- Update class icons in custom frames
    for i = 1, 8 do
        for _, class in pairs(RaidAssignments.Classes) do
            local classframe = _G[class.."_Custom"..i]
            if classframe and classframe.Icon then
                if RaidAssignments_Settings[class] == 1 then
                    classframe.Icon:SetVertexColor(1.0, 1.0, 1.0)
                else
                    classframe.Icon:SetVertexColor(0.5, 0.5, 0.5)
                end
            end
        end
    end

    if RaidAssignments.ToolTip and RaidAssignments.ToolTip:IsShown() then
        local activeMark = RaidAssignments.Settings["active"]
        if activeMark then
            RaidAssignments.ToolTip:Hide()
            RaidAssignments:OpenToolTip("T"..activeMark)
        end
    end

    if RaidAssignments.HealToolTip and RaidAssignments.HealToolTip:IsShown() then
        local activeMark = RaidAssignments.Settings["active_heal"]
        if activeMark then
            RaidAssignments.HealToolTip:Hide()
            RaidAssignments:OpenHealToolTip("H"..activeMark)
        end
    end

    if RaidAssignments.GeneralToolTip and RaidAssignments.GeneralToolTip:IsShown() then
        local activeMark = RaidAssignments.Settings["active_general"]
        if activeMark then
            RaidAssignments.GeneralToolTip:Hide()
            RaidAssignments:OpenGeneralToolTip("G"..activeMark)
        end
    end

    if RaidAssignments.CustomToolTip and RaidAssignments.CustomToolTip:IsShown() then
        local customIndex = RaidAssignments.CustomToolTip.customIndex
        local mark = RaidAssignments.CustomToolTip.mark
        if customIndex and mark then
            RaidAssignments.CustomToolTip:Hide()
            RaidAssignments:OpenCustomToolTip("C"..customIndex.."_M"..mark, customIndex)
        end
    end
end

function RaidAssignments:AddCustomWindowTitleEditBox(frame, i)
    local titleEditBox = RaidAssignments:MakeEditBox("CustomWindowTitle"..i, frame, 200, 24)
    titleEditBox:SetPoint("TOP", frame, "TOP", 0, -10)

    -- Ensure saved variables structure exists
    RaidAssignments_Settings.CustomWindowTitles = RaidAssignments_Settings.CustomWindowTitles or {}
    RaidAssignments.CustomWindowTitles = RaidAssignments_Settings.CustomWindowTitles

    local defaultTitle = RaidAssignments.CustomWindowTitles[i] or "Custom Assignments " .. tostring(i)
    titleEditBox:SetText(defaultTitle)

    -- Update the frame title initially
    if frame.title then
        frame.title:SetText(defaultTitle)
    end

    titleEditBox:SetScript("OnEnterPressed", function()
        local txt = this:GetText()
        if txt and txt ~= "" then
            RaidAssignments.CustomWindowTitles[i] = txt
            RaidAssignments_Settings.CustomWindowTitles[i] = txt
            if frame.title then
                frame.title:SetText(txt)
            end
            RaidAssignments:SendCustomWindowTitle(i)
        else
            local defaultTitle = "Custom Assignments " .. tostring(i)
            this:SetText(defaultTitle)
            RaidAssignments.CustomWindowTitles[i] = defaultTitle
            RaidAssignments_Settings.CustomWindowTitles[i] = defaultTitle
            if frame.title then
                frame.title:SetText(defaultTitle)
            end
            RaidAssignments:SendCustomWindowTitle(i)
        end
        this._sentOnEnter = true
        this:ClearFocus()
    end)

    titleEditBox:SetScript("OnEscapePressed", function()
        local currentTitle = RaidAssignments.CustomWindowTitles[i] or "Custom Assignments " .. tostring(i)
        this:SetText(currentTitle)
        this:ClearFocus()
    end)

    titleEditBox:SetScript("OnEditFocusLost", function()
        -- If OnEnterPressed already committed and sent, skip to avoid double-send
        if this._sentOnEnter then
            this._sentOnEnter = false
            return
        end
        local txt = this:GetText()
        if not txt or txt == "" then
            local defaultTitle = "Custom Assignments " .. tostring(i)
            this:SetText(defaultTitle)
            RaidAssignments.CustomWindowTitles[i] = defaultTitle
            RaidAssignments_Settings.CustomWindowTitles[i] = defaultTitle
            if frame.title then
                frame.title:SetText(defaultTitle)
            end
            RaidAssignments:SendCustomWindowTitle(i)
        end
    end)

    return titleEditBox
end

function RaidAssignments:UpdateYourMarkToggleState()
    local btn = self.bg and self.bg.yourMarkToggle or nil
    -- Walk up to find the button via the main frame reference
    local toggle = RaidAssignments.bg and RaidAssignments.bg.yourMarkToggle
        or (RaidAssignments.ConfigMainFrame and nil)  -- fallback search below
    -- The toggle is stored on the main frame's bg child; find it generically
    if not toggle then
        -- Stored as self.yourMarkToggle during ConfigMainFrame; keep a global ref
        toggle = RaidAssignments._yourMarkToggle
    end
    if not toggle then return end
    local on = RaidAssignments_Settings["showYourMarkFrame"]
    if on then
        -- ON: green border, brighter label
        for _, ln in ipairs(toggle.borderLines) do ln:SetVertexColor(0.25, 0.85, 0.40, 1) end
        toggle.bg:SetVertexColor(0.04, 0.12, 0.06, 0.95)
        toggle.label:SetTextColor(0.45, 1.00, 0.58, 1)
    else
        -- OFF: dim red border, muted label
        for _, ln in ipairs(toggle.borderLines) do ln:SetVertexColor(0.55, 0.18, 0.18, 1) end
        toggle.bg:SetVertexColor(0.12, 0.04, 0.04, 0.95)
        toggle.label:SetTextColor(0.75, 0.35, 0.35, 1)
    end
end

function RaidAssignments:UpdateMarkSoundToggleState()
    local toggle = RaidAssignments._markSoundToggle
    if not toggle then return end
    local on = RaidAssignments_Settings["markSound"]
    if on then
        -- ON: green border, sound icon
        for _, ln in ipairs(toggle.borderLines) do ln:SetVertexColor(0.25, 0.85, 0.40, 1) end
        toggle.bg:SetVertexColor(0.04, 0.12, 0.06, 0.95)
        toggle.label:SetTextColor(0.45, 1.00, 0.58, 1)
    else
        -- OFF: dim red border, muted
        for _, ln in ipairs(toggle.borderLines) do ln:SetVertexColor(0.55, 0.18, 0.18, 1) end
        toggle.bg:SetVertexColor(0.12, 0.04, 0.04, 0.95)
        toggle.label:SetTextColor(0.75, 0.35, 0.35, 1)
    end
end

function RaidAssignments:SendCustomWindowTitle(i)
    if not (RaidAssignments.TestMode or IsRaidOfficer()) then
        return
    end

    if not (i and i >= 1 and i <= 8) then
        return
    end

    RaidAssignments_Settings.CustomWindowTitles = RaidAssignments_Settings.CustomWindowTitles or {}
    local title = RaidAssignments_Settings.CustomWindowTitles[i] or "Custom Assignments " .. tostring(i)

    local channel = (RaidAssignments.TestMode and not (GetNumRaidMembers() > 0)) and "GUILD" or "RAID"
    SendAddonMessage("RACTitle" .. tostring(i), title, channel)
end

function RaidAssignments:SendCustom(customIndex)
    if not (RaidAssignments.TestMode or IsRaidOfficer()) then return end
    if not (customIndex and customIndex >= 1 and customIndex <= 8) then return end
    if not RaidAssignments._marksPopulated then return end

    local payload = ""
    for mark = 1, 10 do
        local maxSlots = (mark >= 9 and mark <= 10) and 6 or 5
        for slot = 1, maxSlots do
            local name = RaidAssignments.CustomMarks[customIndex] and
                         RaidAssignments.CustomMarks[customIndex][mark] and
                         RaidAssignments.CustomMarks[customIndex][mark][slot]
            if name and name ~= "" then
                payload = payload .. mark .. "_" .. slot .. "_" .. name .. ","
            end
        end
    end

    local channel = (RaidAssignments.TestMode and not (GetNumRaidMembers() > 0)) and "GUILD" or "RAID"
    ChunkSend("RACMarks" .. tostring(customIndex), payload, channel)

    -- Sync metadata too
    self:SendCustomWindowTitle(customIndex)
    self:SendCustomLabels(customIndex)
end

-- ======================================================
-- DEBUG: FORCE-SHOW MINIMAP BUTTON
-- ======================================================
function RaidAssignments:CreateMinimapButton()
    if RaidAssignmentsMinimapButton then
        RaidAssignmentsMinimapButton:Show()
        return
    end

    local button = CreateFrame("Button", "RaidAssignmentsMinimapButton", Minimap)
    button:SetFrameStrata("TOOLTIP")
    button:SetWidth(33)
    button:SetHeight(33)
    button:EnableMouse(true)
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    -- Icon (bright red target)
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\Ability_Defend")
    icon:SetWidth(24)
    icon:SetHeight(24)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    -- Border
    local border = button:CreateTexture(nil, "ARTWORK")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(54)
    border:SetHeight(54)
    border:SetPoint("CENTER", 10, -10)

    -- Force a visible position
    local angle = math.rad(245)
    local x = 80 * math.cos(angle)
    local y = 80 * math.sin(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)

    -- Tooltip
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_LEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("RaidAssignments", 1, 1, 0.5)
        GameTooltip:AddLine("Left-click: Toggle window", 1, 1, 1)
        GameTooltip:AddLine("Drag to move", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Clicks
    button:SetScript("OnClick", function()
        if arg1 == "LeftButton" then
            if RaidAssignments:IsShown() then
                RaidAssignments:Hide()
            else
                RaidAssignments:Show()
            end
        end
    end)

    button:SetScript("OnDragStart", function()
        this:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local dx, dy = px / scale - mx, py / scale - my
            local angle = math.atan2(dy, dx)
            local x = 80 * math.cos(angle)
            local y = 80 * math.sin(angle)
            this:ClearAllPoints()
            this:SetPoint("CENTER", Minimap, "CENTER", x, y)
        end)
    end)
    button:SetScript("OnDragStop", function()
        this:SetScript("OnUpdate", nil)
    end)

    button:Show()
end

-- ======================================================
-- YOUR MARK FRAME
-- Shows your assigned raid mark icon, the target's name, HP bar and % HP.
-- Click to target. Uses SuperWoW "mark1"-"mark8" unit IDs.
-- Layout: [mark icon] | YOUR MARK
--                     | [target name]
--                     | [====hp bar====] xx%
-- ======================================================

-- Mark border colours (r, g, b)
RaidAssignments.MarkColors = {
    [1] = {1.00, 0.96, 0.41},  -- Star     - yellow
    [2] = {1.00, 0.60, 0.00},  -- Circle   - orange
    [3] = {0.80, 0.00, 1.00},  -- Diamond  - purple
    [4] = {0.40, 1.00, 0.00},  -- Triangle - green
    [5] = {0.81, 0.93, 0.96},  -- Moon     - pale blue
    [6] = {0.00, 0.71, 1.00},  -- Square   - blue
    [7] = {1.00, 0.20, 0.20},  -- Cross    - red
    [8] = {1.00, 1.00, 1.00},  -- Skull    - white
}

function RaidAssignments:CreateYourMarkFrame()
    if RaidAssignments.YourMarkFrame then return end

    local ICON_SIZE = 28
    local INFO_W    = 160   -- adjusted for 25% wider frame
    local BAR_H     = 12
    local PAD       = 8
    local FRAME_W   = PAD + ICON_SIZE + PAD + INFO_W + PAD
    local FRAME_H   = PAD + ICON_SIZE + PAD

    -- Invisible 1x1 anchor: the only frame with SetMovable(true).
    -- Drag events fire on the visible frame, which calls anchor:StartMoving().
    -- The visible frame follows because it is SetPoint("CENTER", anchor).
    -- OnDragStop reads anchor:GetPoint() directly -- no GetLeft/scale math.
    local anchor = CreateFrame("Frame", "RaidAssignmentsYourMarkAnchor", UIParent)
    anchor:SetWidth(1)
    anchor:SetHeight(1)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)

    local savedPoint = RaidAssignments_Settings["YourMarkFramePoint"] or "CENTER"
    local savedRP    = RaidAssignments_Settings["YourMarkFrameRP"]    or "CENTER"
    local savedX     = RaidAssignments_Settings["YourMarkFrameX"]     or 0
    local savedY     = RaidAssignments_Settings["YourMarkFrameY"]     or 0
    if savedPoint == "TOPLEFT" then  -- discard old pixel-based saves
        savedPoint, savedRP, savedX, savedY = "CENTER", "CENTER", 0, 0
    end
    anchor:SetPoint(savedPoint, UIParent, savedRP, savedX, savedY)

    local frame = CreateFrame("Frame", "RaidAssignmentsYourMarkFrame", UIParent)
    frame:SetWidth(FRAME_W)
    frame:SetHeight(FRAME_H)
    -- NOTE: no SetMovable on frame; only anchor is movable
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetFrameStrata("TOOLTIP")
    frame:SetPoint("CENTER", anchor, "CENTER", 0, 0)

    local savedScale = RaidAssignments_Settings["YourMarkFrameScale"] or 1.0
    frame:SetScale(savedScale)

    frame:SetScript("OnDragStart", function()
        frame._wasDragging = true
        anchor:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        local p, _, rp, x, y = anchor:GetPoint()
        RaidAssignments_Settings["YourMarkFramePoint"] = p
        RaidAssignments_Settings["YourMarkFrameRP"]    = rp
        RaidAssignments_Settings["YourMarkFrameX"]     = x
        RaidAssignments_Settings["YourMarkFrameY"]     = y
    end)
    frame:SetScript("OnMouseWheel", function()
        local s = frame:GetScale()
        if arg1 > 0 then
            s = math.min(s + 0.05, 3.0)
        else
            s = math.max(s - 0.05, 0.3)
        end
        frame:SetScale(s)
        RaidAssignments_Settings["YourMarkFrameScale"] = s
    end)

    -- Dark solid background (no WoW backdrop edge so we control the border ourselves)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "",
        tile = false, tileSize = 0, edgeSize = 0,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame:SetBackdropColor(0.06, 0.06, 0.06, 0.93)

    -- -- Coloured border: four solid 2-px lines ------------------------
    -- We use WHITE8X8 which is a guaranteed 1-colour-fill texture in every client.
    local function MakeLine(parent)
        local t = parent:CreateTexture(nil, "BORDER")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        return t
    end

    local bT = MakeLine(frame)  -- top
    bT:SetHeight(1)
    bT:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0,  0)
    bT:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0,  0)

    local bB = MakeLine(frame)  -- bottom
    bB:SetHeight(1)
    bB:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  0, 0)
    bB:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    local bL = MakeLine(frame)  -- left
    bL:SetWidth(1)
    bL:SetPoint("TOPLEFT",    frame, "TOPLEFT",    0,  0)
    bL:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0,  0)

    local bR = MakeLine(frame)  -- right
    bR:SetWidth(1)
    bR:SetPoint("TOPRIGHT",    frame, "TOPRIGHT",    0,  0)
    bR:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0,  0)

    frame.borderLines = { bT, bB, bL, bR }
    -- Border is always black
    for _, line in ipairs(frame.borderLines) do
        line:SetVertexColor(0, 0, 0, 1)
    end

    -- -- Mark icon -----------------------------------------------------
    -- Icon sits on ARTWORK; nothing above it except OVERLAY text.
    local markIcon = frame:CreateTexture("RaidAssignmentsYourMarkIcon", "ARTWORK")
    markIcon:SetWidth(ICON_SIZE)
    markIcon:SetHeight(ICON_SIZE)
    markIcon:SetPoint("LEFT", frame, "LEFT", PAD, 0)
    frame.markIcon = markIcon

    -- -- Info section --------------------------------------------------
    local infoLeft = PAD + ICON_SIZE + PAD

    -- Target name
    local nameLabel = frame:CreateFontString(nil, "OVERLAY")
    nameLabel:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 13)
    nameLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", infoLeft, -PAD)
    nameLabel:SetWidth(INFO_W)
    nameLabel:SetHeight(16)
    nameLabel:SetJustifyH("LEFT")
    nameLabel:SetText("")
    nameLabel:SetTextColor(1, 1, 1, 1)
    frame.nameLabel = nameLabel

    -- HP bar track (dark background)
    local barTrack = frame:CreateTexture(nil, "ARTWORK")
    barTrack:SetTexture("Interface\\Buttons\\WHITE8X8")
    barTrack:SetVertexColor(0.12, 0.12, 0.12, 1)
    barTrack:SetHeight(BAR_H)
    barTrack:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  infoLeft, PAD)
    barTrack:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD,     PAD)
    frame.barTrack = barTrack

    -- HP bar fill (WHITE8X8 = flat solid colour, no texture shimmer)
    local hpBar = frame:CreateTexture(nil, "OVERLAY")
    hpBar:SetTexture("Interface\\Buttons\\WHITE8X8")
    hpBar:SetHeight(BAR_H)
    hpBar:SetPoint("LEFT",   barTrack, "LEFT",   0, 0)
    hpBar:SetPoint("TOP",    barTrack, "TOP",    0, 0)
    hpBar:SetPoint("BOTTOM", barTrack, "BOTTOM", 0, 0)
    hpBar:SetWidth(INFO_W)
    hpBar:SetVertexColor(0.20, 0.85, 0.20, 1)
    frame.hpBar = hpBar

    -- Store the bar's max width once the frame is laid out
    -- We calculate it from INFO_W minus pads
    frame.hpBarMaxW = INFO_W

    -- HP percent (right edge of bar track, small)
    local hpPct = frame:CreateFontString(nil, "OVERLAY")
    hpPct:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 13)
    hpPct:SetPoint("RIGHT", barTrack, "RIGHT", -2, 0)
    hpPct:SetText("")
    hpPct:SetTextColor(1, 1, 1, 1)
    hpPct:SetShadowColor(0, 0, 0, 1)
    hpPct:SetShadowOffset(1, -1)
    frame.hpPct = hpPct

    -- -- Click ---------------------------------------------------------
    -- OnMouseUp instead of OnClick so dragging doesn't trigger target-unit.
    frame:SetScript("OnMouseUp", function()
        if arg1 == "LeftButton" and not frame._wasDragging then
            local mi = frame.assignedMarkIndex
            if not mi then return end
            if UnitExists("mark"..mi) then
                TargetUnit("mark"..mi)
            end
        end
        frame._wasDragging = false
    end)

    -- -- Tooltip -------------------------------------------------------
    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        local mi = frame.assignedMarkIndex
        if mi then
            local mn = RaidAssignments.RealMarks[mi] or ("Mark "..mi)
            GameTooltip:AddLine("Your Mark: "..mn, 1, 1, 0.5)
            if UnitExists("mark"..mi) then
                GameTooltip:AddLine("Left-click to target", 0.6, 0.6, 0.6)
            else
                GameTooltip:AddLine("Mark not on any unit", 1, 0.5, 0.5)
            end
        end
        GameTooltip:AddLine("Drag to move  |  Scroll to resize", 0.45, 0.45, 0.45)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- -- OnUpdate: live name + HP (throttled to ~10Hz) --------------------
    frame._updateT = 0
    frame:SetScript("OnUpdate", function()
        local f = frame
        if not f or not f:IsShown() then return end
        f._updateT = f._updateT + arg1
        if f._updateT < 0.1 then return end
        f._updateT = 0

        local mi = f.assignedMarkIndex
        if not mi then return end
        local mu = "mark"..mi
        if UnitExists(mu) and UnitHealth(mu) > 0 then
            f.nameLabel:SetText(UnitName(mu) or "")

            local hp    = UnitHealth(mu)    or 0
            local hpMax = UnitHealthMax(mu) or 1
            if hpMax < 1 then hpMax = 1 end
            local pct = hp / hpMax

            local bw = math.floor(f.hpBarMaxW * pct)
            if bw < 1 then bw = 1 end
            f.hpBar:SetWidth(bw)

            f.hpPct:SetText(math.floor(pct * 100).."%")

            -- green -> yellow -> red
            if pct > 0.5 then
                f.hpBar:SetVertexColor((1 - pct) * 2, 1, 0, 1)
            else
                f.hpBar:SetVertexColor(1, pct * 2, 0, 1)
            end
        else
            -- No valid target or target is dead -- hide the frame
            f.assignedMarkIndex = nil
            f:Hide()
        end
    end)

    -- Sound toggle button (top-right corner, S=sound on, M=muted)
    local soundBtn = CreateFrame("Button", nil, frame)
    soundBtn:SetWidth(14)
    soundBtn:SetHeight(14)
    soundBtn:SetPoint("CENTER", frame, "TOPRIGHT", -7, -7)
    soundBtn:SetFrameLevel(frame:GetFrameLevel() + 10)

    local soundBtnTex = soundBtn:CreateFontString(nil, "OVERLAY")
    soundBtnTex:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 9)
    soundBtnTex:SetAllPoints(soundBtn)
    soundBtnTex:SetJustifyH("CENTER")
    soundBtnTex:SetJustifyV("MIDDLE")
    soundBtn.label = soundBtnTex

    local function UpdateSoundBtn()
        if RaidAssignments_Settings["markSound"] then
            soundBtn.label:SetText("|cff88ff88S|r")
        else
            soundBtn.label:SetText("|cffff5555M|r")
        end
    end
    UpdateSoundBtn()

    soundBtn:SetScript("OnClick", function()
        RaidAssignments_Settings["markSound"] = not RaidAssignments_Settings["markSound"]
        UpdateSoundBtn()
        -- Sync back to the main panel sound toggle
        RaidAssignments:UpdateMarkSoundToggleState()
    end)
    soundBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        if RaidAssignments_Settings["markSound"] then
            GameTooltip:AddLine("Mark sound: ON", 0.4, 1, 0.4)
            GameTooltip:AddLine("Click to mute", 0.6, 0.6, 0.6)
        else
            GameTooltip:AddLine("Mark sound: OFF", 1, 0.4, 0.4)
            GameTooltip:AddLine("Click to unmute", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    soundBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.soundBtn = soundBtn

    frame.assignedMarkIndex = nil
    frame:Hide()
    RaidAssignments.YourMarkFrame = frame

    -- -- Always-running ticker: polls every 0.5s even when the mark frame is hidden.
    -- OnUpdate does NOT fire on hidden frames in WoW 1.12, so we need a separate
    -- always-visible frame to drive the check.
    local ticker = CreateFrame("Frame", "RaidAssignmentsMarkTicker", UIParent)
    ticker:SetWidth(1)
    ticker:SetHeight(1)
    ticker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    ticker._t = 0
    ticker:SetScript("OnUpdate", function()
        ticker._t = ticker._t + arg1
        if ticker._t < 0.5 then return end
        ticker._t = 0
        RaidAssignments:UpdateYourMarkFrame()
    end)
end

-- Set border colour + re-apply mark icon texcoords
-- Border is always black regardless of mark colour
function RaidAssignments:SetYourMarkFrameColor(r, g, b)
    local f = RaidAssignments.YourMarkFrame
    if not f then return end
    for _, line in ipairs(f.borderLines) do
        line:SetVertexColor(0, 0, 0, 1)
    end
end

function RaidAssignments:UpdateYourMarkFrame()
    if not RaidAssignments.YourMarkFrame then return end
    if RaidAssignments_Settings["showYourMarkFrame"] == false then
        RaidAssignments.YourMarkFrame:Hide()
        return
    end

    local playerName = UnitName("player")
    local foundMark  = nil

    for markIndex = 1, 8 do
        local slots = RaidAssignments.Marks[markIndex]
        if slots then
            for _, name in pairs(slots) do
                if name == playerName then
                    foundMark = markIndex
                    break
                end
            end
        end
        if foundMark then break end
    end

    if foundMark then
        -- Hide the frame if the marked target doesn't exist or is dead (0% HP)
        local unitId = "mark" .. foundMark
        if not UnitExists(unitId) or UnitHealth(unitId) <= 0 then
            RaidAssignments.YourMarkFrame.assignedMarkIndex = nil
            RaidAssignments.YourMarkFrame:Hide()
            -- Clear target so the next valid unit on this mark fires a new notification
            RaidAssignments._lastNotifiedTarget = nil
            return
        end

        local frame = RaidAssignments.YourMarkFrame
        frame.assignedMarkIndex = foundMark

        -- Apply icon: set texture first, THEN texcoords
        frame.markIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        local cr, cl, ct, cb = RaidAssignments:GetMarkPos(foundMark)
        frame.markIcon:SetTexCoord(cr, cl, ct, cb)

        local col = RaidAssignments.MarkColors[foundMark] or {0.8, 0.8, 0.8}
        RaidAssignments:SetYourMarkFrameColor(col[1], col[2], col[3])

        frame:Show()

        -- Chat notification: fire when the mark index OR the unit on that mark changes
        local currentTarget = UnitExists("mark"..foundMark) and UnitName("mark"..foundMark) or nil
        if RaidAssignments._lastNotifiedMark ~= foundMark or RaidAssignments._lastNotifiedTarget ~= currentTarget then
            RaidAssignments._lastNotifiedMark   = foundMark
            RaidAssignments._lastNotifiedTarget = currentTarget
            local markName = RaidAssignments.RealMarks[foundMark] or ("Mark "..foundMark)
            local unitId   = "mark"..foundMark
            local targetName = currentTarget
            local col3 = RaidAssignments.MarkColors[foundMark] or {0.8, 0.8, 0.8}
            local r, g, b = col3[1], col3[2], col3[3]
            local hexCol = string.format("%02x%02x%02x",
                math.floor(r*255), math.floor(g*255), math.floor(b*255))
            local msg = "|cffFFD700[RaidAssignments]|r Your mark: |cff"..hexCol..markName.."|r"
            local linkText = targetName and ("["..targetName.."]") or ("[Target "..markName.."]")
            local clickLink = "|HRAmark:"..foundMark.."|h|cff00ccff"..linkText.."|r|h"
            msg = msg .. " -> " .. clickLink
            DEFAULT_CHAT_FRAME:AddMessage(msg)
            if RaidAssignments_Settings["markSound"] then
                PlaySoundFile("Interface\\AddOns\\RaidAssignments\\assets\\FFXIV_Incoming_Tell_1.mp3")
            end
        end
    else
        RaidAssignments.YourMarkFrame.assignedMarkIndex = nil
        RaidAssignments.YourMarkFrame:Hide()
        -- Clear notification state when unassigned
        RaidAssignments._lastNotifiedMark   = nil
        RaidAssignments._lastNotifiedTarget = nil
    end
end

-- ======================================================
-- YOUR CURSE FRAME
-- Shows your assigned warlock curse as a reminder display.
-- No click-to-target needed - just a visual cue of your curse.
-- ======================================================

-- Curse border colours (r, g, b) - warlock purples
RaidAssignments.CurseColors = {
    [9]  = {0.58, 0.51, 0.79},  -- Curse of Tongues    - warlock purple
    [10] = {0.80, 0.30, 0.30},  -- Curse of Recklessness - reddish
    [11] = {0.50, 0.20, 0.70},  -- Curse of Shadow     - deep purple
    [12] = {0.30, 0.60, 0.90},  -- Curse of the Elements - blue
}

function RaidAssignments:CreateYourCurseFrame()
    if RaidAssignments.YourCurseFrame then return end

    local ICON_SIZE = 32

    local anchor = CreateFrame("Frame", "RaidAssignmentsYourCurseAnchor", UIParent)
    anchor:SetWidth(1)
    anchor:SetHeight(1)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)

    local savedPoint = RaidAssignments_Settings["YourCurseFramePoint"] or "CENTER"
    local savedRP    = RaidAssignments_Settings["YourCurseFrameRP"]    or "CENTER"
    local savedX     = RaidAssignments_Settings["YourCurseFrameX"]     or 0
    local savedY     = RaidAssignments_Settings["YourCurseFrameY"]     or -50
    if savedPoint == "TOPLEFT" then
        savedPoint, savedRP, savedX, savedY = "CENTER", "CENTER", 0, -50
    end
    anchor:SetPoint(savedPoint, UIParent, savedRP, savedX, savedY)

    local frame = CreateFrame("Frame", "RaidAssignmentsYourCurseFrame", UIParent)
    frame:SetWidth(ICON_SIZE)
    frame:SetHeight(ICON_SIZE)
    -- NOTE: no SetMovable on frame; only anchor is movable
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetFrameStrata("TOOLTIP")
    frame:SetPoint("CENTER", anchor, "CENTER", 0, 0)

    local savedScale = RaidAssignments_Settings["YourCurseFrameScale"] or 1.0
    frame:SetScale(savedScale)

    frame:SetScript("OnDragStart", function() anchor:StartMoving() end)
    frame:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        local p, _, rp, x, y = anchor:GetPoint()
        RaidAssignments_Settings["YourCurseFramePoint"] = p
        RaidAssignments_Settings["YourCurseFrameRP"]    = rp
        RaidAssignments_Settings["YourCurseFrameX"]     = x
        RaidAssignments_Settings["YourCurseFrameY"]     = y
    end)
    frame:SetScript("OnMouseWheel", function()
        local s = frame:GetScale()
        if arg1 > 0 then
            s = math.min(s + 0.05, 3.0)
        else
            s = math.max(s - 0.05, 0.3)
        end
        frame:SetScale(s)
        RaidAssignments_Settings["YourCurseFrameScale"] = s
    end)

    -- Curse icon (fills the entire frame)
    local curseIcon = frame:CreateTexture("RaidAssignmentsYourCurseIcon", "ARTWORK")
    curseIcon:SetAllPoints(frame)
    frame.curseIcon = curseIcon

    -- Stub so UpdateYourCurseFrame doesn't error on borderLines
    frame.borderLines = {}

    -- Tooltip
    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        local ci = RaidAssignments.YourCurseFrame.assignedCurseIndex
        if ci then
            local data = RaidAssignments.WarlockMarks[ci]
            GameTooltip:AddLine("Your Curse Assignment", 1, 1, 0.5)
            GameTooltip:AddLine(data and data.name or "Unknown", 1, 1, 1)
        end
        GameTooltip:AddLine("Drag to move  |  Scroll to resize", 0.45, 0.45, 0.45)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    frame.assignedCurseIndex = nil
    frame:Hide()
    RaidAssignments.YourCurseFrame = frame
end

function RaidAssignments:UpdateYourCurseFrame()
    if not RaidAssignments.YourCurseFrame then return end
    if RaidAssignments_Settings["showYourMarkFrame"] == false then
        RaidAssignments.YourCurseFrame:Hide()
        return
    end

    -- Only relevant for Warlocks, but we check the data regardless
    local playerName = UnitName("player")
    local foundCurse = nil

    -- Search curse marks (indices 9-12)
    for markIndex = 9, 12 do
        local slots = RaidAssignments.Marks[markIndex]
        if slots then
            for _, name in pairs(slots) do
                if name == playerName then
                    foundCurse = markIndex
                    break
                end
            end
        end
        if foundCurse then break end
    end

    if foundCurse then
        local frame = RaidAssignments.YourCurseFrame
        frame.assignedCurseIndex = foundCurse

        local data = RaidAssignments.WarlockMarks[foundCurse]
        if data then
            frame.curseIcon:SetTexture(data.icon)
        end

        local col = RaidAssignments.CurseColors[foundCurse] or {0.58, 0.51, 0.79}
        for _, line in ipairs(frame.borderLines) do
            line:SetVertexColor(col[1], col[2], col[3], 1)
        end

        frame:Show()
    else
        RaidAssignments.YourCurseFrame.assignedCurseIndex = nil
        RaidAssignments.YourCurseFrame:Hide()
    end
end

-- ======================================================
-- KEYBINDING: Target Your Mark
-- Registered via BINDINGS-TEMPLATE.xml so users can
-- configure the key in the in-game Key Bindings menu.
-- ======================================================
function RAIDASSIGNMENTS_TARGET_MARK()
    local index = RaidAssignments.YourMarkFrame and RaidAssignments.YourMarkFrame.assignedMarkIndex
    if index then
        TargetUnit("mark" .. index)
    end
end