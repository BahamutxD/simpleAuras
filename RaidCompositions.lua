-- RaidCompositions.lua
-- Raid group composition save/load panel for RaidAssignments
-- Snaps to the right edge of the main frame.
-- Persists to RaidAssignments_Compositions (account-wide SavedVariables).

-- --- Constants ----------------------------------------------------------------

local RC_NUM_SLOTS = 8
local RC_PANEL_W   = 295
local RC_HEADER_H  = 36
local RC_PANEL_H   = 668   -- 36 header + 8 x 79 rows = exact fit
local RC_ROW_H     = math.floor((RC_PANEL_H - RC_HEADER_H) / RC_NUM_SLOTS)  -- 79px
local RC_PAD       = 10

-- Class colours (WoW standard)
local RC_CLASS_COLOR = {
    ["Warrior"] = {0.78, 0.61, 0.43},
    ["Hunter"]  = {0.67, 0.83, 0.45},
    ["Mage"]    = {0.41, 0.80, 0.94},
    ["Rogue"]   = {1.00, 0.96, 0.41},
    ["Warlock"] = {0.58, 0.51, 0.79},
    ["Druid"]   = {1.00, 0.49, 0.04},
    ["Shaman"]  = {0.00, 0.44, 0.87},
    ["Priest"]  = {0.90, 0.90, 0.90},
    ["Paladin"] = {0.96, 0.55, 0.73},
}

-- --- SavedVariables bootstrap -------------------------------------------------

local function RC_EnsureDB()
    if not RaidAssignments_Compositions then
        RaidAssignments_Compositions = {}
    end
    for i = 1, RC_NUM_SLOTS do
        if not RaidAssignments_Compositions[i] then
            RaidAssignments_Compositions[i] = {
                name        = "Slot " .. i,
                layout      = nil,
                classes     = nil,
                playerCount = 0,
            }
        end
    end
end

-- --- Raid data helpers --------------------------------------------------------

local function RC_GetCurrentLayout()
    local layout  = {}
    local classes = {}
    for i = 1, GetNumRaidMembers() do
        local name, _, subgroup, _, class = GetRaidRosterInfo(i)
        if name then
            layout[name]  = subgroup
            classes[name] = class
        end
    end
    return layout, classes
end

-- Build the final desired { [name]=group } config for RC_ConfigureRaid.
-- Priority:
--   1. Exact name match from saved layout
--   2. Unassigned player of the same class
--   3. Any remaining unassigned player
--   4. Still-unassigned current raiders go into lowest-population group
local function RC_BuildDesiredConfig(savedLayout, savedClasses)
    local currentLayout, currentClasses = RC_GetCurrentLayout()

    -- Pool: current raiders not yet assigned a slot
    local unassigned = {}
    for name in pairs(currentLayout) do
        unassigned[name] = true
    end

    local desired = {}

    -- Pass 1: exact name matches
    for savedName, group in pairs(savedLayout) do
        if currentLayout[savedName] then
            desired[savedName]    = group
            unassigned[savedName] = nil
        end
    end

    -- Pass 2: class autofill for missing saved players
    local missingSlots = {}
    for savedName, group in pairs(savedLayout) do
        if not desired[savedName] then
            local class = savedClasses and savedClasses[savedName] or nil
            table.insert(missingSlots, { class = class, group = group })
        end
    end

    for _, slot in ipairs(missingSlots) do
        local filled = false
        -- Prefer matching class first
        if slot.class then
            for name in pairs(unassigned) do
                if currentClasses[name] == slot.class then
                    desired[name]    = slot.group
                    unassigned[name] = nil
                    filled = true
                    break
                end
            end
        end
        -- Fall back to any unassigned player
        if not filled then
            for name in pairs(unassigned) do
                desired[name]    = slot.group
                unassigned[name] = nil
                break
            end
        end
    end

    -- Pass 3: place still-unassigned raiders into lowest-population groups
    local groupPop = {}
    for g = 1, 8 do groupPop[g] = 0 end
    for _, g in pairs(desired) do
        groupPop[g] = groupPop[g] + 1
    end
    for name in pairs(unassigned) do
        local bestGroup, bestCount = 1, 999
        for g = 1, 8 do
            if groupPop[g] < bestCount and groupPop[g] < 5 then
                bestGroup = g
                bestCount = groupPop[g]
            end
        end
        desired[name]       = bestGroup
        groupPop[bestGroup] = groupPop[bestGroup] + 1
    end

    return desired
end

-- --- Raid mover ---------------------------------------------------------------

local function RC_ConfigureRaid(desiredConfig)
    local currentConfig = {}
    local raidUnits     = {}
    for i = 1, GetNumRaidMembers() do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if name then
            currentConfig[name] = subgroup
            raidUnits[name]     = i
        end
    end

    local subgroupCount = {}
    for i = 1, 8 do subgroupCount[i] = 0 end
    for _, sg in pairs(currentConfig) do
        subgroupCount[sg] = subgroupCount[sg] + 1
    end

    local function MoveOrSwap(name, desired, visited)
        if currentConfig[name] == desired then return true end
        if visited[name] then return false end
        visited[name] = true

        if subgroupCount[desired] < 5 then
            SetRaidSubgroup(raidUnits[name], desired)
            subgroupCount[currentConfig[name]] = subgroupCount[currentConfig[name]] - 1
            subgroupCount[desired]             = subgroupCount[desired] + 1
            currentConfig[name]                = desired
            return true
        end

        for tempName, tempSG in pairs(currentConfig) do
            if tempSG == desired and (desiredConfig[tempName] or 0) ~= desired then
                SwapRaidSubgroup(raidUnits[name], raidUnits[tempName])
                currentConfig[name], currentConfig[tempName] =
                    currentConfig[tempName], currentConfig[name]
                return MoveOrSwap(tempName, desiredConfig[tempName] or tempSG, visited)
            end
        end
        return false
    end

    local queue = {}
    for name, desired in pairs(desiredConfig) do
        if currentConfig[name] then
            table.insert(queue, { name = name, desired = desired })
        end
    end

    local maxPasses = 50
    local pass = 0
    while table.getn(queue) > 0 and pass < maxPasses do
        pass = pass + 1
        local remaining    = {}
        local madeProgress = false
        for _, entry in ipairs(queue) do
            if MoveOrSwap(entry.name, entry.desired, {}) then
                madeProgress = true
            else
                table.insert(remaining, entry)
            end
        end
        if not madeProgress and table.getn(remaining) > 0 then
            local entry = table.remove(remaining, 1)
            for tempName, tempSG in pairs(currentConfig) do
                if tempSG == entry.desired then
                    SwapRaidSubgroup(raidUnits[entry.name], raidUnits[tempName])
                    currentConfig[entry.name], currentConfig[tempName] =
                        currentConfig[tempName], currentConfig[entry.name]
                    break
                end
            end
        end
        queue = remaining
    end
end

-- --- Button tint helpers ------------------------------------------------------

local function RC_TintBtn(btn, r, g, b)
    if not btn or not btn.borderLines then return end
    for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(r, g, b, 1) end
    btn.label:SetTextColor(r + 0.18, g + 0.18, b + 0.18, 1)
    if btn.bg then btn.bg:SetVertexColor(r * 0.12, g * 0.12, b * 0.12, 0.95) end
end

local function RC_HoverBtn(btn, r, g, b)
    -- In vanilla 1.12, SetScript handlers use `this` for the frame, not upvalue closures
    RC_TintBtn(btn, r, g, b)
    btn:SetScript("OnEnter", function()
        this.glow:Show()
        this.glow:SetVertexColor(r, g, b, 0.22)
        for _, ln in ipairs(this.borderLines) do ln:SetVertexColor(r + 0.2, g + 0.2, b + 0.2, 1) end
        this.label:SetTextColor(1, 1, 0.85, 1)
    end)
    btn:SetScript("OnLeave", function()
        this.glow:Hide()
        RC_TintBtn(this, r, g, b)
    end)
end

local function RC_DimBtn(btn)
    for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(0.18, 0.18, 0.20, 1) end
    btn.label:SetTextColor(0.28, 0.28, 0.30, 1)
    if btn.bg then btn.bg:SetVertexColor(0.04, 0.04, 0.05, 0.95) end
    -- Clear any hover scripts from a previous RC_HoverBtn call so the button
    -- doesn't briefly re-highlight when moused over while dimmed.
    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)
end

-- --- Confirm dialog -----------------------------------------------------------

local function RC_ShowConfirmDialog(msg, onConfirm)
    local d = CreateFrame("Frame", nil, UIParent)
    d:SetFrameStrata("FULLSCREEN_DIALOG")
    d:SetWidth(280)
    d:SetHeight(100)
    d:SetPoint("CENTER", 0, 0)
    d:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = {left=0, right=0, top=0, bottom=0},
    })
    d:SetBackdropColor(0.07, 0.06, 0.04, 0.98)
    d:SetBackdropBorderColor(0.72, 0.20, 0.20, 1)

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
    for _, ln in ipairs(yes.borderLines) do ln:SetVertexColor(0.52, 0.16, 0.16, 1) end
    yes.label:SetTextColor(0.90, 0.45, 0.45, 1)
    yes:SetScript("OnEnter", function()
        this.glow:Show()
        this.glow:SetVertexColor(0.9, 0.2, 0.2, 0.25)
        for _, ln in ipairs(this.borderLines) do ln:SetVertexColor(0.9, 0.3, 0.3, 1) end
        this.label:SetTextColor(1, 0.6, 0.6, 1)
    end)
    yes:SetScript("OnLeave", function()
        this.glow:Hide()
        for _, ln in ipairs(this.borderLines) do ln:SetVertexColor(0.52, 0.16, 0.16, 1) end
        this.label:SetTextColor(0.90, 0.45, 0.45, 1)
    end)

    local no = RaidAssignments:MakeBtn(d, 90, 26, "Cancel", function()
        d:Hide()
    end)
    no:SetPoint("BOTTOMLEFT", d, "BOTTOM", 6, 12)
    RC_HoverBtn(no, 0.18, 0.45, 0.18)

    d:EnableMouse(true)
    d:Show()
end

-- --- Panel --------------------------------------------------------------------

function RaidAssignments:CreateCompositionsPanel()
    if RaidAssignments.CompositionsPanel then return end

    -- RC_EnsureDB is called from VARIABLES_LOADED below, so saved data is
    -- already populated before the user can click to open this panel.

    -- Outer frame -- not movable, snapped to main frame
    local panel = CreateFrame("Frame", "RaidAssignmentsCompositionsPanel", RaidAssignments)
    panel:SetFrameStrata("DIALOG")
    panel:SetWidth(RC_PANEL_W)
    local initH = (RaidAssignments:GetHeight() and RaidAssignments:GetHeight() > 0)
                  and RaidAssignments:GetHeight() or RC_PANEL_H
    panel:SetHeight(initH)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    panel:SetBackdropColor(0.07, 0.07, 0.09, 0.97)
    panel:SetBackdropBorderColor(0.15, 0.15, 0.18, 1)

    -- Title bar background
    local titleBg = panel:CreateTexture(nil, "BACKGROUND")
    titleBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    titleBg:SetVertexColor(0.04, 0.04, 0.06, 1)
    titleBg:SetPoint("TOPLEFT",  panel, "TOPLEFT",  1, -1)
    titleBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    titleBg:SetHeight(RC_HEADER_H - 2)

    -- Teal accent line below title
    local accentLine = panel:CreateTexture(nil, "ARTWORK")
    accentLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    accentLine:SetVertexColor(0.15, 0.65, 0.80, 1)
    accentLine:SetHeight(2)
    accentLine:SetPoint("TOPLEFT",  panel, "TOPLEFT",  1, -37)
    accentLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -37)

    -- Title text
    local titleText = panel:CreateFontString(nil, "OVERLAY")
    titleText:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 16)
    titleText:SetTextColor(0.9, 0.9, 0.95, 1)
    titleText:SetShadowOffset(1, -1)
    titleText:SetShadowColor(0, 0, 0, 1)
    titleText:SetText("RAID COMPOSITIONS")
    titleText:SetPoint("TOP", panel, "TOP", 0, -10)
    titleText:SetJustifyH("CENTER")

    -- Close button removed; panel is toggled via the arrow tab

    -- -- Per-slot row logic -------------------------------------------------

    local slotRows = {}

    local function RC_RefreshRow(i)
        local row  = slotRows[i]
        local comp = RaidAssignments_Compositions[i]
        if not row or not comp then return end

        local hasData = comp.layout ~= nil

        -- Name label -- FontString always renders correctly, no hidden-frame issues
        if row.nameLabel then
            row.nameLabel:SetText(comp.name or ("Slot " .. i))
        end

        -- Status dot
        if hasData then
            row.dot:SetVertexColor(0.22, 0.82, 0.40, 1)
        else
            row.dot:SetVertexColor(0.20, 0.20, 0.24, 1)
        end

        -- Count / status label
        if hasData and comp.playerCount and comp.playerCount > 0 then
            row.countLabel:SetText(comp.playerCount .. " players")
            row.countLabel:SetTextColor(0.50, 0.50, 0.56, 1)
        elseif hasData then
            row.countLabel:SetText("saved")
            row.countLabel:SetTextColor(0.42, 0.42, 0.48, 1)
        else
            row.countLabel:SetText("empty")
            row.countLabel:SetTextColor(0.26, 0.26, 0.30, 1)
        end

        -- Group colour pips (8 pips, one per group, coloured by dominant class)
        if hasData and comp.layout and comp.classes then
            local groupClasses = {}
            for g = 1, 8 do groupClasses[g] = {} end
            for pName, grp in pairs(comp.layout) do
                local cls = comp.classes[pName]
                if cls and grp >= 1 and grp <= 8 then
                    table.insert(groupClasses[grp], cls)
                end
            end
            for g = 1, 8 do
                if table.getn(groupClasses[g]) > 0 then
                    local col = RC_CLASS_COLOR[groupClasses[g][1]] or {0.45, 0.45, 0.45}
                    row.groupPips[g]:SetVertexColor(col[1], col[2], col[3], 1)
                else
                    row.groupPips[g]:SetVertexColor(0.14, 0.14, 0.17, 1)
                end
            end
        else
            for g = 1, 8 do
                row.groupPips[g]:SetVertexColor(0.14, 0.14, 0.17, 1)
            end
        end

        -- Button active/dim state
        if hasData then
            RC_HoverBtn(row.loadBtn,  0.60, 0.46, 0.10)
            RC_HoverBtn(row.clearBtn, 0.52, 0.16, 0.16)
        else
            RC_DimBtn(row.loadBtn)
            RC_DimBtn(row.clearBtn)
            -- Override hover to do nothing when dimmed
            row.loadBtn:SetScript("OnEnter",  nil)
            row.loadBtn:SetScript("OnLeave",  nil)
            row.clearBtn:SetScript("OnEnter", nil)
            row.clearBtn:SetScript("OnLeave", nil)
        end
    end

    local function RC_SaveSlot(i)
        if not IsRaidOfficer() and not IsRaidLeader() then
            DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6ERaidAssignments Compositions:|r Must be raid officer to save.")
            return
        end
        if GetNumRaidMembers() == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6ERaidAssignments Compositions:|r Must be in a raid to save.")
            return
        end

        local layout, classes = RC_GetCurrentLayout()
        local comp = RaidAssignments_Compositions[i]
        -- Name is already committed to comp.name by the nameBox OnEnterPressed/OnEditFocusLost
        -- but fall back to the label text if somehow not set
        if not comp.name or comp.name == "" then
            comp.name = slotRows[i] and slotRows[i].nameLabel:GetText() or ("Slot " .. i)
        end
        comp.layout      = layout
        comp.classes     = classes
        comp.playerCount = GetNumRaidMembers()

        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffC79C6ERaidAssignments Compositions:|r Saved \"" ..
            comp.name .. "\" -- " .. comp.playerCount .. " players."
        )
        RC_RefreshRow(i)
    end

    local function RC_LoadSlot(i)
        if not IsRaidOfficer() and not IsRaidLeader() then
            DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6ERaidAssignments Compositions:|r Must be raid officer to load.")
            return
        end
        local comp = RaidAssignments_Compositions[i]
        if not comp.layout then
            DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6ERaidAssignments Compositions:|r Slot " .. i .. " is empty.")
            return
        end
        if GetNumRaidMembers() == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffC79C6ERaidAssignments Compositions:|r Must be in a raid to load.")
            return
        end

        local desired = RC_BuildDesiredConfig(comp.layout, comp.classes)
        RC_ConfigureRaid(desired)
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffC79C6ERaidAssignments Compositions:|r Loaded \"" .. comp.name .. "\"."
        )
    end

    local function RC_ClearSlot(i)
        local comp = RaidAssignments_Compositions[i]
        local defaultName = "Slot " .. i
        comp.layout      = nil
        comp.classes     = nil
        comp.playerCount = 0
        comp.name        = defaultName
        if slotRows[i] then
            slotRows[i].nameLabel:SetText(defaultName)
        end
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffC79C6ERaidAssignments Compositions:|r Cleared slot " .. i .. "."
        )
        RC_RefreshRow(i)
    end

    -- Forward declaration so row-click closures can reference it
    local RC_OpenEditor

    -- -- Editor -------------------------------------------------------------
    -- ED_ prefixed locals live inside CreateCompositionsPanel so they share
    -- access to RC_RefreshRow and RaidAssignments_Compositions.

    local ED_W          = 620
    local ED_H          = 502
    local ED_PAD        = 10
    local ED_GROUP_W    = 64   -- width of each group column
    local ED_SLOT_H     = 24   -- height of each player slot button
    local ED_SLOT_GAP   = 3
    local ED_HEADER_H   = 40
    local ED_POOL_W     = 120  -- right-side unassigned pool width

    local editorFrame   = nil
    local ed_slotSlot   = nil  -- currently selected {group=, slot=} or {pool=index}
    local ed_editIndex  = nil  -- which composition slot we're editing
    -- Working copy: groups[g] = { "PlayerName", ... } (up to 5), pool = { names }
    local ed_groups     = {}
    local ed_classes    = {}   -- { [name] = class }
    local ed_pool       = {}
    -- UI refs
    local ed_groupBtns  = {}   -- ed_groupBtns[g][s] = button frame
    local ed_poolBtns   = {}   -- ed_poolBtns[i] = button frame
    local ed_selected   = nil  -- the currently selected button frame

    local function ED_ClassColor(name)
        local cls = ed_classes[name]
        if cls and RC_CLASS_COLOR[cls] then
            return RC_CLASS_COLOR[cls][1], RC_CLASS_COLOR[cls][2], RC_CLASS_COLOR[cls][3]
        end
        return 0.55, 0.55, 0.60
    end

    local function ED_SetSelected(btn)
        -- Deselect previous
        if ed_selected and ed_selected ~= btn then
            local prev = ed_selected
            -- Restore previous button colour
            if prev.rcName then
                local r, g2, b = ED_ClassColor(prev.rcName)
                for _, ln in ipairs(prev.borderLines) do ln:SetVertexColor(r*0.6, g2*0.6, b*0.6, 1) end
                prev.label:SetTextColor(r, g2, b, 1)
            else
                -- empty slot
                for _, ln in ipairs(prev.borderLines) do ln:SetVertexColor(0.18, 0.18, 0.22, 1) end
                prev.label:SetTextColor(0.30, 0.30, 0.34, 1)
            end
            prev.glow:Hide()
        end
        ed_selected = btn
        if btn then
            btn.glow:Show()
            btn.glow:SetVertexColor(0.95, 0.85, 0.20, 0.35)
            for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(0.95, 0.85, 0.20, 1) end
            btn.label:SetTextColor(1, 1, 0.7, 1)
        end
    end

    local function ED_RefreshGroupBtn(g, s)
        local btn  = ed_groupBtns[g][s]
        local name = ed_groups[g][s]
        if name then
            btn.rcName = name
            btn.label:SetText(name)
            local r, g2, b = ED_ClassColor(name)
            if btn == ed_selected then
                for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(0.95, 0.85, 0.20, 1) end
                btn.label:SetTextColor(1, 1, 0.7, 1)
            else
                for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(r*0.6, g2*0.6, b*0.6, 1) end
                btn.label:SetTextColor(r, g2, b, 1)
                btn.glow:Hide()
            end
        else
            btn.rcName = nil
            btn.label:SetText("")
            if btn == ed_selected then
                for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(0.95, 0.85, 0.20, 1) end
            else
                for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(0.18, 0.18, 0.22, 1) end
                btn.glow:Hide()
            end
        end
    end

    local function ED_RefreshPoolBtn(i)
        local btn  = ed_poolBtns[i]
        if not btn then return end
        local name = ed_pool[i]
        if name then
            btn.rcName = name
            btn.label:SetText(name)
            local r, g2, b = ED_ClassColor(name)
            if btn == ed_selected then
                for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(0.95, 0.85, 0.20, 1) end
                btn.label:SetTextColor(1, 1, 0.7, 1)
            else
                for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(r*0.6, g2*0.6, b*0.6, 1) end
                btn.label:SetTextColor(r, g2, b, 1)
                btn.glow:Hide()
            end
            btn:Show()
        else
            btn.rcName = nil
            btn:Hide()
        end
    end

    local function ED_RefreshAll()
        for g = 1, 8 do
            for s = 1, 5 do
                ED_RefreshGroupBtn(g, s)
            end
        end
        for i = 1, table.getn(ed_poolBtns) do
            ED_RefreshPoolBtn(i)
        end
    end

    -- Click handler: select or place
    local function ED_OnClickGroupSlot(g, s)
        local btn      = ed_groupBtns[g][s]
        local slotName = ed_groups[g][s]

        if ed_selected == nil then
            -- Nothing selected yet -- select this if occupied, or do nothing
            if slotName then
                ED_SetSelected(btn)
            end
            return
        end

        if ed_selected == btn then
            -- Deselect
            ED_SetSelected(nil)
            ED_RefreshGroupBtn(g, s)
            return
        end

        -- Something is selected -- place/swap
        local srcBtn = ed_selected

        -- Find source location
        if srcBtn.rcGroup then
            -- Source is a group slot
            local sg, ss = srcBtn.rcGroup, srcBtn.rcSlot
            local srcName = ed_groups[sg][ss]
            -- Swap
            ed_groups[sg][ss] = slotName
            ed_groups[g][s]   = srcName
            ED_SetSelected(nil)
            ED_RefreshGroupBtn(sg, ss)
            ED_RefreshGroupBtn(g, s)
        elseif srcBtn.rcPoolIdx then
            -- Source is pool
            local pi      = srcBtn.rcPoolIdx
            local srcName = ed_pool[pi]
            if slotName then
                -- Swap: send current occupant to pool
                ed_pool[pi]    = slotName
                ed_groups[g][s] = srcName
            else
                -- Move to empty slot
                ed_groups[g][s] = srcName
                table.remove(ed_pool, pi)
            end
            ED_SetSelected(nil)
            ED_RefreshAll()
        end
    end

    local function ED_OnClickPoolSlot(i)
        local btn      = ed_poolBtns[i]
        if not btn or not ed_pool[i] then return end

        if ed_selected == nil then
            ED_SetSelected(btn)
            return
        end

        if ed_selected == btn then
            ED_SetSelected(nil)
            ED_RefreshPoolBtn(i)
            return
        end

        local srcBtn = ed_selected

        if srcBtn.rcGroup then
            -- Move from group to pool, put pool player into group
            local sg, ss  = srcBtn.rcGroup, srcBtn.rcSlot
            local srcName = ed_groups[sg][ss]
            local dstName = ed_pool[i]
            ed_groups[sg][ss] = dstName
            ed_pool[i]        = srcName
            ED_SetSelected(nil)
            ED_RefreshAll()
        elseif srcBtn.rcPoolIdx then
            -- Swap two pool entries
            local si = srcBtn.rcPoolIdx
            ed_pool[si], ed_pool[i] = ed_pool[i], ed_pool[si]
            ED_SetSelected(nil)
            ED_RefreshAll()
        end
    end

    local function ED_BuildFrame()
        if editorFrame then return end

        editorFrame = CreateFrame("Frame", "RCEditorFrame", UIParent)
        editorFrame:SetFrameStrata("FULLSCREEN")
        editorFrame:SetWidth(ED_W)
        editorFrame:SetHeight(ED_H)
        editorFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        editorFrame:SetMovable(true)
        editorFrame:EnableMouse(true)
        editorFrame:RegisterForDrag("LeftButton")
        editorFrame:SetScript("OnDragStart", function() this:StartMoving() end)
        editorFrame:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
        editorFrame:EnableMouseWheel(true)
        editorFrame:SetScript("OnMouseWheel", function()
            local scale = editorFrame:GetScale()
            if arg1 > 0 then
                scale = math.min(scale + 0.05, 2.0)
            else
                scale = math.max(scale - 0.05, 0.5)
            end
            editorFrame:SetScale(scale)
        end)
        editorFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false, edgeSize = 1,
            insets = { left=0, right=0, top=0, bottom=0 },
        })
        editorFrame:SetBackdropColor(0.06, 0.06, 0.08, 0.98)
        editorFrame:SetBackdropBorderColor(0.15, 0.60, 0.72, 1)

        -- Title bar bg
        local titleBg = editorFrame:CreateTexture(nil, "BACKGROUND")
        titleBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        titleBg:SetVertexColor(0.04, 0.04, 0.06, 1)
        titleBg:SetPoint("TOPLEFT",  editorFrame, "TOPLEFT",  1, -1)
        titleBg:SetPoint("TOPRIGHT", editorFrame, "TOPRIGHT", -1, -1)
        titleBg:SetHeight(ED_HEADER_H - 2)

        local accent = editorFrame:CreateTexture(nil, "ARTWORK")
        accent:SetTexture("Interface\\Buttons\\WHITE8X8")
        accent:SetVertexColor(0.15, 0.65, 0.80, 1)
        accent:SetHeight(2)
        accent:SetPoint("TOPLEFT",  editorFrame, "TOPLEFT",  1, -(ED_HEADER_H - 2))
        accent:SetPoint("TOPRIGHT", editorFrame, "TOPRIGHT", -1, -(ED_HEADER_H - 2))

        -- Title label (updated when opened)
        local titleLbl = editorFrame:CreateFontString(nil, "OVERLAY")
        titleLbl:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 14)
        titleLbl:SetTextColor(0.35, 0.88, 0.96, 1)
        titleLbl:SetShadowOffset(1, -1)
        titleLbl:SetShadowColor(0, 0, 0, 1)
        titleLbl:SetPoint("LEFT", editorFrame, "TOPLEFT", ED_PAD, -(ED_HEADER_H/2) + 2)
        editorFrame.titleLbl = titleLbl

        -- Close button
        local closeBtn = RaidAssignments:MakeBtn(editorFrame, 22, 22, "X", function()
            editorFrame:Hide()
        end)
        closeBtn.label:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 13)
        closeBtn:SetPoint("TOPRIGHT", editorFrame, "TOPRIGHT", -4, -6)
        closeBtn:SetFrameStrata("FULLSCREEN")
        RC_HoverBtn(closeBtn, 0.65, 0.18, 0.18)

        -- -- Save button (commits edit back to composition slot) -------------
        local saveEditBtn = RaidAssignments:MakeBtn(editorFrame, 80, 24, "Save Layout", function()
            if ed_editIndex == nil then return end
            local comp    = RaidAssignments_Compositions[ed_editIndex]
            local layout  = {}
            local classes = {}
            local count   = 0
            for g = 1, 8 do
                for s = 1, 5 do
                    local name = ed_groups[g][s]
                    if name then
                        layout[name]  = g
                        classes[name] = ed_classes[name]
                        count = count + 1
                    end
                end
            end
            comp.layout      = layout
            comp.classes     = classes
            comp.playerCount = count
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cffC79C6ERaidAssignments Compositions:|r Saved edits to \"" .. comp.name .. "\"."
            )
            RC_RefreshRow(ed_editIndex)
            editorFrame:Hide()
        end)
        saveEditBtn:SetPoint("BOTTOMRIGHT", editorFrame, "BOTTOMRIGHT", -ED_PAD, ED_PAD)
        RC_HoverBtn(saveEditBtn, 0.18, 0.55, 0.22)

        -- Hint label
        local hintLbl = editorFrame:CreateFontString(nil, "OVERLAY")
        hintLbl:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 10)
        hintLbl:SetTextColor(0.30, 0.30, 0.35, 1)
        hintLbl:SetText("Click a player to select, then click a slot to move them")
        hintLbl:SetPoint("BOTTOMLEFT", editorFrame, "BOTTOMLEFT", ED_PAD, ED_PAD + 4)

        -- -- "Add current raid" button --------------------------------------
        local addRaidBtn = RaidAssignments:MakeBtn(editorFrame, 100, 20, "Add Raid Members", function()
            if GetNumRaidMembers() == 0 then return end
            -- Add any current raiders not already in groups or pool to the pool
            local inComp = {}
            for g = 1, 8 do
                for s = 1, 5 do
                    if ed_groups[g][s] then inComp[ed_groups[g][s]] = true end
                end
            end
            for _, pname in ipairs(ed_pool) do inComp[pname] = true end

            for i2 = 1, GetNumRaidMembers() do
                local rname, _, _, _, rclass = GetRaidRosterInfo(i2)
                if rname and not inComp[rname] then
                    ed_classes[rname] = rclass
                    table.insert(ed_pool, rname)
                    inComp[rname] = true
                end
            end
            ED_RefreshAll()
        end)
        addRaidBtn:SetPoint("BOTTOMRIGHT", saveEditBtn, "BOTTOMLEFT", -ED_PAD, 0)
        RC_HoverBtn(addRaidBtn, 0.20, 0.45, 0.65)

        -- -- Group columns (4 columns x 2 rows layout) ----------------------
        -- Groups 1-4 in the top row, groups 5-8 in the bottom row.
        -- Each player slot button is double the width of the old single-row layout.
        local GROUPS_AREA_W = ED_W - ED_POOL_W - ED_PAD * 3
        local COL_W         = math.floor(GROUPS_AREA_W / 4)   -- 4 columns instead of 8
        -- Row 1: groups 1-4 at the normal top offset
        -- Row 2: groups 5-8 below row 1's 5 slots + a small gap
        local ROW_GROUP_H   = ED_HEADER_H + 18 + 5 * (ED_SLOT_H + ED_SLOT_GAP) + 16  -- height of one row-block

        for g = 1, 8 do
            ed_groupBtns[g] = {}
            -- Groups 1-4 -> columns 0-3 (top row)
            -- Groups 5-8 -> columns 0-3 (bottom row)
            local col   = math.mod(g - 1, 4)   -- 0-3
            local rowOff = math.floor((g - 1) / 4) * ROW_GROUP_H  -- 0 or ROW_GROUP_H
            local colX  = ED_PAD + col * COL_W

            -- Group header label
            local gLbl = editorFrame:CreateFontString(nil, "OVERLAY")
            gLbl:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 11)
            gLbl:SetTextColor(0.45, 0.45, 0.52, 1)
            gLbl:SetText("G" .. g)
            gLbl:SetPoint("TOPLEFT", editorFrame, "TOPLEFT", colX + 2, -ED_HEADER_H - 4 - rowOff)

            -- Column background
            local colBg = editorFrame:CreateTexture(nil, "BACKGROUND")
            colBg:SetTexture("Interface\\Buttons\\WHITE8X8")
            colBg:SetVertexColor(0.09, 0.09, 0.12, 1)
            colBg:SetWidth(COL_W - 2)
            colBg:SetHeight(5 * (ED_SLOT_H + ED_SLOT_GAP) + 4)
            colBg:SetPoint("TOPLEFT", editorFrame, "TOPLEFT", colX, -ED_HEADER_H - 18 - rowOff)

            for s = 1, 5 do
                local slotY = -(ED_HEADER_H + 18 + (s-1) * (ED_SLOT_H + ED_SLOT_GAP) + rowOff)
                local btn   = RaidAssignments:MakeBtn(editorFrame, COL_W - 4, ED_SLOT_H, "", nil)
                btn:SetPoint("TOPLEFT", editorFrame, "TOPLEFT", colX + 1, slotY)
                btn:SetFrameStrata("FULLSCREEN")
                btn.rcGroup = g
                btn.rcSlot  = s
                btn.rcName  = nil
                -- Default empty style
                for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(0.18, 0.18, 0.22, 1) end
                btn.label:SetTextColor(0.30, 0.30, 0.34, 1)
                btn.label:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 10)

                -- Capture g and s for the closure
                local bg2, bs = g, s
                btn:SetScript("OnClick", function()
                    ED_OnClickGroupSlot(bg2, bs)
                end)
                btn:SetScript("OnEnter", function()
                    if this ~= ed_selected then
                        this.glow:Show()
                        this.glow:SetVertexColor(0.35, 0.55, 0.65, 0.18)
                    end
                end)
                btn:SetScript("OnLeave", function()
                    if this ~= ed_selected then
                        this.glow:Hide()
                    end
                end)

                ed_groupBtns[g][s] = btn
            end
        end

        -- -- Unassigned pool (right side) -----------------------------------
        local poolX = ED_W - ED_POOL_W - ED_PAD

        local poolBg = editorFrame:CreateTexture(nil, "BACKGROUND")
        poolBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        poolBg:SetVertexColor(0.08, 0.08, 0.10, 1)
        poolBg:SetWidth(ED_POOL_W)
        poolBg:SetPoint("TOPLEFT",    editorFrame, "TOPLEFT",    poolX,  -ED_HEADER_H - 4)
        poolBg:SetPoint("BOTTOMLEFT", editorFrame, "BOTTOMLEFT", poolX, ED_PAD + 30)

        local poolLbl = editorFrame:CreateFontString(nil, "OVERLAY")
        poolLbl:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 11)
        poolLbl:SetTextColor(0.45, 0.45, 0.52, 1)
        poolLbl:SetText("Unassigned")
        poolLbl:SetPoint("TOPLEFT", editorFrame, "TOPLEFT", poolX + 2, -ED_HEADER_H - 4)

        local poolDivider = editorFrame:CreateTexture(nil, "ARTWORK")
        poolDivider:SetTexture("Interface\\Buttons\\WHITE8X8")
        poolDivider:SetVertexColor(0.15, 0.60, 0.72, 0.6)
        poolDivider:SetWidth(1)
        poolDivider:SetPoint("TOPLEFT",    editorFrame, "TOPLEFT",    poolX - 1, -ED_HEADER_H)
        poolDivider:SetPoint("BOTTOMLEFT", editorFrame, "BOTTOMLEFT", poolX - 1, ED_PAD + 30)

        -- Create 40 pool slot buttons (max raid size)
        for i2 = 1, 40 do
            local pyOff = -(ED_HEADER_H + 18 + (i2 - 1) * (ED_SLOT_H + ED_SLOT_GAP))
            local btn = RaidAssignments:MakeBtn(editorFrame, ED_POOL_W - 4, ED_SLOT_H, "", nil)
            btn:SetPoint("TOPLEFT", editorFrame, "TOPLEFT", poolX + 2, pyOff)
            btn:SetFrameStrata("FULLSCREEN")
            btn.rcPoolIdx = i2
            btn.rcName    = nil
            for _, ln in ipairs(btn.borderLines) do ln:SetVertexColor(0.18, 0.18, 0.22, 1) end
            btn.label:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 10)

            local pi = i2
            btn:SetScript("OnClick", function()
                ED_OnClickPoolSlot(pi)
            end)
            btn:SetScript("OnEnter", function()
                if this ~= ed_selected and this.rcName then
                    this.glow:Show()
                    this.glow:SetVertexColor(0.35, 0.55, 0.65, 0.18)
                end
            end)
            btn:SetScript("OnLeave", function()
                if this ~= ed_selected then
                    this.glow:Hide()
                end
            end)

            btn:Hide()
            ed_poolBtns[i2] = btn
        end
    end -- ED_BuildFrame

    -- Open editor for slot i, loading its current saved data
    RC_OpenEditor = function(i)
        ED_BuildFrame()

        ed_editIndex = i
        ed_selected  = nil

        local comp = RaidAssignments_Compositions[i]

        -- Reset working data
        ed_groups  = {}
        ed_classes = {}
        ed_pool    = {}
        for g = 1, 8 do
            ed_groups[g] = {}
            for s = 1, 5 do
                ed_groups[g][s] = nil
            end
        end

        if comp.layout then
            -- Rebuild groups from saved layout
            local groupCount = {}
            for g = 1, 8 do groupCount[g] = 0 end
            -- Sort names deterministically so slot order is stable
            local names = {}
            for name, _ in pairs(comp.layout) do table.insert(names, name) end
            table.sort(names)
            for _, name in ipairs(names) do
                local g = comp.layout[name]
                if g and g >= 1 and g <= 8 and groupCount[g] < 5 then
                    groupCount[g] = groupCount[g] + 1
                    ed_groups[g][groupCount[g]] = name
                end
            end
            -- Copy class data
            if comp.classes then
                for name, cls in pairs(comp.classes) do
                    ed_classes[name] = cls
                end
            end
        end

        -- Also pull in any live raiders not already in the layout into the pool
        if GetNumRaidMembers() > 0 then
            local inLayout = {}
            for g = 1, 8 do
                for s = 1, 5 do
                    if ed_groups[g][s] then inLayout[ed_groups[g][s]] = true end
                end
            end
            for ri = 1, GetNumRaidMembers() do
                local rname, _, _, _, rclass = GetRaidRosterInfo(ri)
                if rname and not inLayout[rname] then
                    ed_classes[rname] = rclass
                    table.insert(ed_pool, rname)
                end
            end
        end

        editorFrame.titleLbl:SetText("EDITING: " .. (comp.name or ("Slot " .. i)))
        ED_RefreshAll()
        editorFrame:Show()
    end

    -- -- Build rows ---------------------------------------------------------
    for i = 1, RC_NUM_SLOTS do
        local yTop    = -(RC_HEADER_H + (i - 1) * RC_ROW_H)
        local comp_i  = i   -- captured upvalue

        -- Row background (texture only, not a button -- avoids blocking child widgets)
        local rowBg = panel:CreateTexture(nil, "BACKGROUND")
        rowBg:SetTexture("Interface\\Buttons\\WHITE8X8")
        if math.mod(i, 2) == 0 then
            rowBg:SetVertexColor(0.08, 0.08, 0.10, 1)
        else
            rowBg:SetVertexColor(0.06, 0.06, 0.08, 1)
        end
        rowBg:SetPoint("TOPLEFT",  panel, "TOPLEFT",  1,  yTop)
        rowBg:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, yTop)
        rowBg:SetHeight(RC_ROW_H - 1)

        -- Row separator
        local sep = panel:CreateTexture(nil, "ARTWORK")
        sep:SetTexture("Interface\\Buttons\\WHITE8X8")
        sep:SetVertexColor(0.13, 0.13, 0.16, 1)
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  1,  yTop)
        sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, yTop)

        -- Status dot -- top-left
        local dot = panel:CreateTexture(nil, "ARTWORK")
        dot:SetTexture("Interface\\Buttons\\WHITE8X8")
        dot:SetWidth(6)
        dot:SetHeight(6)
        dot:SetPoint("TOPLEFT", panel, "TOPLEFT", RC_PAD, yTop - 12)
        dot:SetVertexColor(0.20, 0.20, 0.24, 1)

        -- Name display: a FontString shows the saved name reliably at all
        -- times (FontStrings are immune to the vanilla 1.12 SetText-on-hidden-
        -- frame bug that affects EditBoxes).
        local nameLabel = panel:CreateFontString(nil, "OVERLAY")
        nameLabel:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 11)
        nameLabel:SetTextColor(0.92, 0.86, 0.62, 1)
        nameLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", RC_PAD, yTop - 26)
        nameLabel:SetWidth(148)
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetText("Slot " .. i)

        -- Hidden EditBox -- only shown when user double-clicks the label to rename.
        local nameBox = RaidAssignments:MakeEditBox("RCNameBox" .. i, panel, 148, 22)
        nameBox:SetPoint("TOPLEFT", panel, "TOPLEFT", RC_PAD, yTop - 26)
        nameBox:SetMaxLetters(32)
        nameBox:Hide()
        nameBox:SetScript("OnEnterPressed", function()
            local newName = this:GetText()
            if newName == "" then newName = "Slot " .. comp_i end
            RaidAssignments_Compositions[comp_i].name = newName
            nameLabel:SetText(newName)
            this:Hide()
            nameLabel:Show()
            this:ClearFocus()
        end)
        nameBox:SetScript("OnEscapePressed", function()
            this:SetText(RaidAssignments_Compositions[comp_i].name or ("Slot " .. comp_i))
            this:Hide()
            nameLabel:Show()
            this:ClearFocus()
        end)
        nameBox:SetScript("OnEditFocusLost", function()
            -- Also commit on focus lost (clicking away)
            local newName = this:GetText()
            if newName == "" then newName = "Slot " .. comp_i end
            RaidAssignments_Compositions[comp_i].name = newName
            nameLabel:SetText(newName)
            this:Hide()
            nameLabel:Show()
        end)

        -- Double-click the label to enter rename mode
        local clickFrame = CreateFrame("Button", nil, panel)
        clickFrame:SetPoint("TOPLEFT", nameLabel, "TOPLEFT", 0, 0)
        clickFrame:SetPoint("BOTTOMRIGHT", nameLabel, "BOTTOMRIGHT", 0, 0)
        clickFrame:RegisterForClicks("LeftButtonUp")
        clickFrame:SetScript("OnDoubleClick", function()
            nameLabel:Hide()
            nameBox:Show()
            nameBox:SetText(RaidAssignments_Compositions[comp_i].name or ("Slot " .. comp_i))
            nameBox:SetFocus()
            nameBox:HighlightText()
        end)

        -- Count label -- below name box
        local countLabel = panel:CreateFontString(nil, "OVERLAY")
        countLabel:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 10)
        countLabel:SetTextColor(0.26, 0.26, 0.30, 1)
        countLabel:SetText("empty")
        countLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", RC_PAD + 2, yTop - 46)

        -- Group colour pips -- pinned to bottom of row with a bit of padding
        local PIP_TOTAL = RC_PANEL_W - RC_PAD * 2 - 2
        local PIP_W     = math.floor(PIP_TOTAL / 8)
        local PIP_H     = 5
        local groupPips = {}
        for g = 1, 8 do
            local pip = panel:CreateTexture(nil, "ARTWORK")
            pip:SetTexture("Interface\\Buttons\\WHITE8X8")
            pip:SetWidth(PIP_W - 2)
            pip:SetHeight(PIP_H)
            pip:SetVertexColor(0.14, 0.14, 0.17, 1)
            pip:SetPoint(
                "TOPLEFT", panel, "TOPLEFT",
                RC_PAD + (g - 1) * PIP_W,
                yTop - RC_ROW_H + PIP_H + 4
            )
            groupPips[g] = pip
        end

        -- 2x2 button grid -- vertically centred in the row
        -- [ Load ][ Save ]
        -- [ Edit ][ Clear ]
        local BTN_W    = 48
        local BTN_H    = 20
        local BTN_GAP  = 4
        local GRID_H   = BTN_H * 2 + BTN_GAP
        local BTN_YOFF = -math.floor((RC_ROW_H - GRID_H) / 2)   -- centres the 2x2 grid

        local saveBtn = RaidAssignments:MakeBtn(panel, BTN_W, BTN_H, "Save", function()
            RC_SaveSlot(comp_i)
        end)
        saveBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -RC_PAD, yTop + BTN_YOFF)
        RC_HoverBtn(saveBtn, 0.18, 0.55, 0.22)

        local loadBtn = RaidAssignments:MakeBtn(panel, BTN_W, BTN_H, "Load", function()
            RC_LoadSlot(comp_i)
        end)
        loadBtn:SetPoint("TOPRIGHT", saveBtn, "TOPLEFT", -BTN_GAP, 0)
        RC_DimBtn(loadBtn)

        local clearBtn = RaidAssignments:MakeBtn(panel, BTN_W, BTN_H, "Clear", function()
            local comp = RaidAssignments_Compositions[comp_i]
            if not comp or not comp.layout then return end
            local slotName = (comp.name and comp.name ~= "") and comp.name or ("Slot " .. comp_i)
            RC_ShowConfirmDialog("Clear \"" .. slotName .. "\"?", function()
                RC_ClearSlot(comp_i)
            end)
        end)
        clearBtn:SetPoint("TOPLEFT", saveBtn, "BOTTOMLEFT", 0, -BTN_GAP)
        RC_DimBtn(clearBtn)

        local editBtn = RaidAssignments:MakeBtn(panel, BTN_W, BTN_H, "Edit", function()
            RC_OpenEditor(comp_i)
        end)
        editBtn:SetPoint("TOPRIGHT", clearBtn, "TOPLEFT", -BTN_GAP, 0)
        editBtn:SetFrameStrata("DIALOG")
        RC_HoverBtn(editBtn, 0.20, 0.45, 0.65)

        slotRows[i] = {
            dot        = dot,
            nameLabel  = nameLabel,
            nameBox    = nameBox,
            countLabel = countLabel,
            groupPips  = groupPips,
            saveBtn    = saveBtn,
            loadBtn    = loadBtn,
            clearBtn   = clearBtn,
            editBtn    = editBtn,
        }

        RC_RefreshRow(i)
    end

    panel:SetScript("OnShow", function()
        for i = 1, RC_NUM_SLOTS do
            RC_RefreshRow(i)
        end
    end)

    panel:Hide()
    RaidAssignments.CompositionsPanel  = panel
    RaidAssignments.CompositionRows    = slotRows
    RaidAssignments._RC_RefreshRow     = RC_RefreshRow
end

-- --- SavedVariables ready -----------------------------------------------------
-- ADDON_LOADED fires before SavedVariables exist; VARIABLES_LOADED is when
-- they are actually populated.  RC_EnsureDB must only run here.

do
    local rcLoader = CreateFrame("Frame")
    rcLoader:RegisterEvent("VARIABLES_LOADED")
    rcLoader:SetScript("OnEvent", function()
        RC_EnsureDB()
        rcLoader:UnregisterEvent("VARIABLES_LOADED")
    end)
end

-- --- Snapping -----------------------------------------------------------------

local function RC_Snap()
    local p = RaidAssignments.CompositionsPanel
    if not p or not p:IsShown() then return end
    local mainH = RaidAssignments:GetHeight()
    if mainH and mainH > 0 then
        p:SetHeight(mainH)
    end
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", RaidAssignments, "TOPRIGHT", 2, 0)
end

-- --- Toggle button + main frame hooks ----------------------------------------

function RaidAssignments:CreateCompositionsButton()

    -- Hook the main frame's bg to snap and co-hide the panel
    local bg = RaidAssignments.bg

    local origBgUpdate = bg:GetScript("OnUpdate")
    bg:SetScript("OnUpdate", function()
        if origBgUpdate then origBgUpdate() end
        RC_Snap()
    end)

    local origBgHide = bg:GetScript("OnHide")
    bg:SetScript("OnHide", function()
        if origBgHide then origBgHide() end
        if RaidAssignments.CompositionsPanel then
            RaidAssignments.CompositionsPanel:Hide()
        end
    end)

    -- -- Arrow tab -------------------------------------------------------------
    -- A slim vertical tab pinned to the right edge of the main frame,
    -- vertically centred. It shows ">" when the panel is closed, "<" when open.
    -- No text, no border clutter -- just a discreet clickable sliver.

    local TAB_W = 14   -- narrow tab width
    local TAB_H = 60   -- tall enough to click easily

    local arrow = CreateFrame("Button", "RaidAssignmentsGroupsArrow", RaidAssignments.bg)
    arrow:SetWidth(TAB_W)
    arrow:SetHeight(TAB_H)
    -- Sit flush against the inside of the right edge of the main frame, vertically centred
    arrow:SetPoint("RIGHT", RaidAssignments.bg, "RIGHT", -1, 0)
    arrow:SetFrameStrata("DIALOG")
    arrow:EnableMouse(true)

    -- Dark bg matching the main frame aesthetic
    local tabBg = arrow:CreateTexture(nil, "BACKGROUND")
    tabBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    tabBg:SetVertexColor(0.07, 0.07, 0.09, 0.97)
    tabBg:SetAllPoints(arrow)

    -- Left-side accent line (cyan, matches the frame's border colour)
    local tabLine = arrow:CreateTexture(nil, "BORDER")
    tabLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    tabLine:SetVertexColor(0.15, 0.60, 0.72, 1)
    tabLine:SetWidth(1)
    tabLine:SetPoint("TOPLEFT",    arrow, "TOPLEFT",    0, 0)
    tabLine:SetPoint("BOTTOMLEFT", arrow, "BOTTOMLEFT", 0, 0)

    -- Top edge
    local tabTop = arrow:CreateTexture(nil, "BORDER")
    tabTop:SetTexture("Interface\\Buttons\\WHITE8X8")
    tabTop:SetVertexColor(0.15, 0.60, 0.72, 1)
    tabTop:SetHeight(1)
    tabTop:SetPoint("TOPLEFT",  arrow, "TOPLEFT",  0, 0)
    tabTop:SetPoint("TOPRIGHT", arrow, "TOPRIGHT", 0, 0)

    -- Bottom edge
    local tabBot = arrow:CreateTexture(nil, "BORDER")
    tabBot:SetTexture("Interface\\Buttons\\WHITE8X8")
    tabBot:SetVertexColor(0.15, 0.60, 0.72, 1)
    tabBot:SetHeight(1)
    tabBot:SetPoint("BOTTOMLEFT",  arrow, "BOTTOMLEFT",  0, 0)
    tabBot:SetPoint("BOTTOMRIGHT", arrow, "BOTTOMRIGHT", 0, 0)

    -- Hover glow overlay
    local tabGlow = arrow:CreateTexture(nil, "ARTWORK")
    tabGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    tabGlow:SetVertexColor(0.15, 0.60, 0.72, 0.20)
    tabGlow:SetAllPoints(arrow)
    tabGlow:Hide()

    -- Arrow glyph label (">" / "<")
    local arrowLbl = arrow:CreateFontString(nil, "OVERLAY")
    arrowLbl:SetFont("Interface\\AddOns\\RaidAssignments\\assets\\BalooBhaina.ttf", 11)
    arrowLbl:SetTextColor(0.35, 0.85, 0.95, 1)
    arrowLbl:SetShadowOffset(1, -1)
    arrowLbl:SetShadowColor(0, 0, 0, 1)
    arrowLbl:SetPoint("CENTER", arrow, "CENTER", 0, 0)
    arrowLbl:SetText(">")
    arrow.arrowLbl = arrowLbl

    local function UpdateArrowGlyph()
        local p = RaidAssignments.CompositionsPanel
        if p and p:IsShown() then
            arrowLbl:SetText("<")
            arrowLbl:SetTextColor(0.65, 1.0, 1.0, 1)
            tabLine:SetVertexColor(0.30, 0.88, 1.00, 1)
            tabTop:SetVertexColor(0.30, 0.88, 1.00, 1)
            tabBot:SetVertexColor(0.30, 0.88, 1.00, 1)
            tabBg:SetVertexColor(0.05, 0.12, 0.16, 0.97)
        else
            arrowLbl:SetText(">")
            arrowLbl:SetTextColor(0.35, 0.85, 0.95, 1)
            tabLine:SetVertexColor(0.15, 0.60, 0.72, 1)
            tabTop:SetVertexColor(0.15, 0.60, 0.72, 1)
            tabBot:SetVertexColor(0.15, 0.60, 0.72, 1)
            tabBg:SetVertexColor(0.07, 0.07, 0.09, 0.97)
        end
    end

    arrow:SetScript("OnClick", function()
        RaidAssignments:CreateCompositionsPanel()
        local p = RaidAssignments.CompositionsPanel
        if p:IsShown() then
            p:Hide()
        else
            RC_Snap()
            p:Show()
        end
        UpdateArrowGlyph()
    end)

    arrow:SetScript("OnEnter", function()
        tabGlow:Show()
        tabLine:SetVertexColor(0.30, 0.88, 1.00, 1)
        tabTop:SetVertexColor(0.30, 0.88, 1.00, 1)
        tabBot:SetVertexColor(0.30, 0.88, 1.00, 1)
        arrowLbl:SetTextColor(0.80, 1.0, 1.0, 1)
        GameTooltip:SetOwner(arrow, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Raid Compositions", 1, 1, 0.55)
        GameTooltip:AddLine("Save and load raid group layouts", 0.65, 0.65, 0.65)
        GameTooltip:Show()
    end)

    arrow:SetScript("OnLeave", function()
        tabGlow:Hide()
        GameTooltip:Hide()
        UpdateArrowGlyph()
    end)

    -- Keep glyph in sync whenever the panel is shown/hidden externally
    RaidAssignments.CompositionsPanel_UpdateArrow = UpdateArrowGlyph

    arrow:Show()   -- visible whenever bg is visible (parented to bg)
    RaidAssignments.CompositionsArrow = arrow
    RaidAssignments.CompositionsButton = arrow  -- keep the old reference valid
end
