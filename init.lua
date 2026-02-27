local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:SetScript("OnEvent", function()
	
	---------------------------------------------------
	-- SavedVariables Initialization
	---------------------------------------------------

	-- Ensure tables exist
	simpleAuras = simpleAuras or {}
	simpleAuras.auras   = simpleAuras.auras   or {}
	simpleAuras.refresh = simpleAuras.refresh or 5
	simpleAuras.reactiveDurations = simpleAuras.reactiveDurations or {}  -- Reactive spell durations
	if sA.SuperWoW then
	  simpleAuras.auradurations = simpleAuras.auradurations or {}
	  simpleAuras.updating      = simpleAuras.updating or 0
	  simpleAuras.showlearning  = simpleAuras.showlearning or 0
	  simpleAuras.learnall      = simpleAuras.learnall or 0
	  simpleAuras.nolearning    = simpleAuras.nolearning or {}  -- Spells excluded from learning
	end
		
		sA.SettingsLoaded = 1
		
		sA:CreateTestAuras()

		table.insert(UISpecialFrames, "sATest")
		table.insert(UISpecialFrames, "sATestDual")

end)

-- runtime only
sA = sA or { 
  auraTimers = {}, 
  learnCastTimers = {}, 
  learnNew = {}, 
  frames = {}, 
  dualframes = {}, 
  draggers = {}, 
  activeAuras = {},
  reactiveTimers = {},      -- [spellName] = {expiry, warnedOnce}
  itemIDCache = {},         -- [itemName] = itemID (for cooldown tracking)
  igniteData = {}           -- [targetGUID] = {stacks, damage, expiry}
}

-- Get version from .toc file
sA.VERSION = GetAddOnMetadata("simpleAuras", "Version") or "1.0"

sA.SuperWoW = SetAutoloot and true or false
local _, playerGUID = UnitExists("player")
sA.playerGUID = playerGUID
sA.SettingsLoaded = nil

-- perf: cache globals we use a lot (Lua 5.0-safe)
local gsub   = string.gsub
local find   = string.find
local lower  = string.lower
local floor  = math.floor
local tinsert = table.insert
local getn   = table.getn
local GetTime = GetTime

-- message helper
sA.PREFIX = "|c194b7dccsimple|cffffffffAuras: "
function sA:Msg(msg)
  DEFAULT_CHAT_FRAME:AddMessage(self.PREFIX .. msg)
end

---------------------------------------------------
-- Helper Functions
---------------------------------------------------

local function GetAuraDurationBySpellID(spellID, casterGUID)
  if not spellID or not casterGUID then return nil end
  if type(simpleAuras.auradurations[spellID]) ~= "table" then
	simpleAuras.auradurations[spellID] = nil
	return nil
  end
  return simpleAuras.auradurations[spellID][casterGUID]
end

local function getAuraID(spellName)
    local auraFound = {}
    for auraID, aura in ipairs(simpleAuras.auras) do
        if aura.name == spellName then
            table.insert(auraFound, auraID)
        end
    end
    if getn(auraFound) > 0 then
        return auraFound
    else
        return {}
    end
end

-- SuperWoW: learn and track aura durations
if sA.SuperWoW then
  local sADuration = CreateFrame("Frame")
  sADuration:RegisterEvent("RAW_COMBATLOG")
  sADuration:RegisterEvent("UNIT_CASTEVENT")
  sADuration:SetScript("OnEvent", function()
    local timestamp = GetTime()

    if event == "RAW_COMBATLOG" and simpleAuras.auradurations then
      local raw = arg2
      if not raw or not find(raw, "fades from") then return end

      local _, _, spellName  = string.find(raw, "^(.-) fades from ")
      local _, _, targetGUID = string.find(raw, "from (.-).$")

      if lower(targetGUID or "") == "you" then _, targetGUID = UnitExists("player") end
      targetGUID = gsub(targetGUID or "", "^0x", "")
      if not spellName or targetGUID == "" then return end
      if not sA.auraTimers[targetGUID] then return end

      for spellID in pairs(sA.auraTimers[targetGUID]) do
        local n = SpellInfo(spellID)
        if n then
          n = gsub(n, "%s*%(%s*Rank%s+%d+%s*%)", "")
          if n == spellName then
            -- if we were learning this duration, compute actual
			
            if sA.learnCastTimers[targetGUID] and sA.learnCastTimers[targetGUID][spellID] and sA.learnCastTimers[targetGUID][spellID].duration then
              local castTime = sA.learnCastTimers[targetGUID][spellID].duration
              local actual   = timestamp - castTime
			  local casterGUID = sA.learnCastTimers[targetGUID][spellID].castby
			  simpleAuras.auradurations[spellID] = simpleAuras.auradurations[spellID] or {}
              simpleAuras.auradurations[spellID][casterGUID] = floor(actual + 0.5)
			  sA.learnNew[spellID] = nil
              if simpleAuras.updating == 1 then
                sA:Msg("Updated " .. spellName .. " (ID:"..spellID..") to: " .. floor(actual + 0.5) .. "s")
              elseif simpleAuras.showlearning == 1 then
				sA:Msg("Learned " .. spellName .. " (ID:"..spellID..") duration: " .. floor(actual + 0.5) .. "s")
			  end
              sA.learnCastTimers[targetGUID][spellID].duration = nil
              sA.learnCastTimers[targetGUID][spellID].castby = nil
            end
			
			if sA.auraTimers[targetGUID][spellID].duration <= timestamp then
				sA.auraTimers[targetGUID][spellID] = nil
			end
			
            if not next(sA.auraTimers[targetGUID]) then
              sA.auraTimers[targetGUID] = nil
            end
            break
          end
        end
      end

    elseif event == "UNIT_CASTEVENT" then
      local casterGUID, targetGUID, evType, spellID = arg1, arg2, arg3, arg4
      if evType ~= "CAST" or not spellID then return end
	  
      local spellName = SpellInfo(spellID)
      
      -- Check if player used a reactive spell (deactivate it)
      if casterGUID then
        local _, playerGUID = UnitExists("player")
        if playerGUID then playerGUID = gsub(playerGUID, "^0x", "") end
        casterGUID = gsub(casterGUID or "", "^0x", "")
        
        if casterGUID == playerGUID and spellName then
          sA:HandleReactiveSpellUsed(spellName)
        end
      end
      
	  local auraIDs = getAuraID(spellName)

	  if ((auraIDs and getn(auraIDs) > 0) or simpleAuras.learnall == 1) and spellID and simpleAuras.auradurations then

		  if sA.playerGUID then
			sA.playerGUID = gsub(sA.playerGUID, "^0x", "")
		  else
			local _, playerGUID = UnitExists("player")
			sA.playerGUID = playerGUID
		  end
		  
		  casterGUID = gsub(casterGUID or "", "^0x", "")
		  if targetGUID then targetGUID = gsub(targetGUID, "^0x", "") end

		  local dur = GetAuraDurationBySpellID(spellID,casterGUID)
	  
		  -- Apply known duration if available (only for player casts when not in learnall mode)
		  if dur and dur > 0 and simpleAuras.updating == 0 and (casterGUID == sA.playerGUID or simpleAuras.learnall == 1) then
			sA.auraTimers[targetGUID] = sA.auraTimers[targetGUID] or {}
			sA.auraTimers[targetGUID][spellID] = sA.auraTimers[targetGUID][spellID] or {}
			if not sA.auraTimers[targetGUID][spellID].duration or (dur + timestamp) > sA.auraTimers[targetGUID][spellID].duration then
				sA.auraTimers[targetGUID][spellID].duration = timestamp + dur
				sA.auraTimers[targetGUID][spellID].castby = casterGUID
			end
			sA.learnNew[spellID] = nil
		  -- Learn new duration (for player casts, or any cast when learnall is enabled)
		  -- Skip learning if spell is in nolearning list
		  elseif (casterGUID == sA.playerGUID or simpleAuras.learnall == 1) and not simpleAuras.nolearning[spellID] then

			local showLearn = nil
						
			if not targetGUID or targetGUID == "" then targetGUID = sA.playerGUID end
			
			sA.learnCastTimers[targetGUID] = sA.learnCastTimers[targetGUID] or {}
			sA.learnCastTimers[targetGUID][spellID] = sA.learnCastTimers[targetGUID][spellID] or {}
			sA.learnCastTimers[targetGUID][spellID].duration = timestamp
			sA.learnCastTimers[targetGUID][spellID].castby = casterGUID
			
			sA.auraTimers[targetGUID] = sA.auraTimers[targetGUID] or {}
			sA.auraTimers[targetGUID][spellID] = sA.auraTimers[targetGUID][spellID] or {}
			sA.auraTimers[targetGUID][spellID].duration = 0
			sA.auraTimers[targetGUID][spellID].castby = casterGUID
									
			-- Check if we should show learning message (only for configured auras)
			for _, auraID in ipairs(auraIDs) do
				if simpleAuras.auras[auraID].unit ~= "Player" and simpleAuras.auras[auraID].type ~= "Cooldown" and simpleAuras.auras[auraID].type ~= "Reactive" then
					showLearn = true
					break
				end
			end
						
			-- Mark for learning: if showLearn is true (for configured auras) or learnall is enabled, and target is not player
			if (showLearn or simpleAuras.learnall == 1) and targetGUID ~= sA.playerGUID then
				sA.learnNew[spellID] = 1
			end
			
			if simpleAuras.updating == 1 then
			  sA:Msg("Updating " .. (spellName or spellID) .. " (ID:"..spellID..")...")
			elseif simpleAuras.showlearning == 1 then
			  sA:Msg("Learning " .. (spellName or spellID) .. " (ID:"..spellID..")...")
			end
			
		  end
		  
	  end
	  
    end
  end)
end

---------------------------------------------------
-- Ignite Tracking
-- Tracks Ignite debuff stacks, per-tick damage, and remaining duration
-- for all targets, keyed by GUID (SuperWoW) or name (fallback).
-- Only the current target's data is shown via UpdateIgniteData().
--
-- sA.igniteData[guid] = { stacks, damage, expiry }
---------------------------------------------------

-- Ignite spell IDs (the debuff itself, rank 1 only in 1.12)
local IGNITE_DEBUFF_ID = 12654
-- Duration is always 4 seconds per ignite application
local IGNITE_DURATION = 4

-- All mage fire spells that can proc ignite (all ranks)
local IGNITE_FIRE_SPELL_IDS = {
  -- Blast Wave
  [11113]=true,[13018]=true,[13019]=true,[13020]=true,[13021]=true,
  -- Fire Blast
  [2136]=true,[2137]=true,[2138]=true,[8412]=true,[8413]=true,[10197]=true,[10199]=true,
  -- Fireball
  [133]=true,[143]=true,[145]=true,[3140]=true,[8400]=true,[8401]=true,[8402]=true,
  [10148]=true,[10149]=true,[10150]=true,[10151]=true,[25306]=true,
  -- Flamestrike
  [2120]=true,[2121]=true,[8422]=true,[8423]=true,[10215]=true,[10216]=true,
  -- Pyroblast
  [11366]=true,[12505]=true,[12522]=true,[12523]=true,[12524]=true,
  [12525]=true,[12526]=true,[12527]=true,[18809]=true,
  -- Scorch
  [2948]=true,[8444]=true,[8445]=true,[8446]=true,[10205]=true,[10206]=true,[10207]=true,
}

local sAIgniteTracker = CreateFrame("Frame")

if sA.SuperWoW then
  -- SuperWoW path: use structured events for GUID-based stack/expire tracking
  -- but still parse chat for damage since SPELL_DAMAGE_EVENT doesn't fire for DoT ticks

  sAIgniteTracker:RegisterEvent("DEBUFF_ADDED_OTHER")
  sAIgniteTracker:RegisterEvent("DEBUFF_REMOVED_OTHER")
  sAIgniteTracker:RegisterEvent("UNIT_DIED")
  -- Chat events for damage value (works in both SuperWoW and vanilla)
  sAIgniteTracker:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
  sAIgniteTracker:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")
  sAIgniteTracker:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE")

  local PAT_IGNITE_TICK       = "^(.+) suffers (%d+) Fire damage from (.+) Ignite"
  local PAT_IGNITE_TICK_SELF  = "^You suffer (%d+) Fire damage from (.+) Ignite"

  sAIgniteTracker:SetScript("OnEvent", function()
    if not sA.SettingsLoaded then return end
    sA.igniteData = sA.igniteData or {}

    if event == "DEBUFF_ADDED_OTHER" then
      -- arg1=targetGUID, arg2=slot, arg3=spellId, arg4=stacks
      local targetGUID = arg1
      local spellId    = arg3
      local stacks     = arg4

      if spellId == IGNITE_DEBUFF_ID and targetGUID then
        targetGUID = gsub(targetGUID, "^0x", "")
        local existing = sA.igniteData[targetGUID] or {}
        sA.igniteData[targetGUID] = {
          stacks = stacks or 1,
          damage = existing.damage or 0,
          expiry = GetTime() + IGNITE_DURATION,
        }
        sA:UpdateIgniteData()
      end

    elseif event == "DEBUFF_REMOVED_OTHER" then
      local targetGUID = arg1
      local spellId    = arg3

      if spellId == IGNITE_DEBUFF_ID and targetGUID then
        targetGUID = gsub(targetGUID, "^0x", "")
        sA.igniteData[targetGUID] = nil
        sA:UpdateIgniteData()
      end

    elseif event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"
        or event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE"
        or event == "CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE" then
      local msg = arg1
      local amount = nil

      local _, _, target, dmg = string.find(msg, PAT_IGNITE_TICK)
      if target and dmg then
        amount = tonumber(dmg)
      else
        local _, _, dmg2 = string.find(msg, PAT_IGNITE_TICK_SELF)
        if dmg2 then amount = tonumber(dmg2) end
      end

      if amount then
        local _, tguid = UnitExists("target")
        if tguid then tguid = gsub(tguid, "^0x", "") end

        -- Prefer the GUID key if it already exists (set by DEBUFF_ADDED_OTHER).
        -- Fall back to name key (non-SuperWoW entries or first-tick race).
        -- IMPORTANT: never fall back to current tguid if no existing entry is found —
        -- that would store the tick under the wrong (currently selected) target's GUID.
        local key
        if tguid and sA.igniteData[tguid] then
          key = tguid
        elseif target and sA.igniteData[target] then
          key = target
        else
          -- No existing entry for this tick's target — store under the name from the
          -- chat message only.  Do NOT use tguid here: the current target may be a
          -- completely different unit that has never had Ignite.
          key = target
        end

        if key then
          local existing = sA.igniteData[key] or {}
          sA.igniteData[key] = {
            stacks = existing.stacks or 1,
            damage = amount,
            expiry = GetTime() + IGNITE_DURATION,
          }
          sA:UpdateIgniteData()
        end
      end

    elseif event == "UNIT_DIED" then
      local guid = arg1
      if guid then
        guid = gsub(guid, "^0x", "")
        if sA.igniteData[guid] then
          sA.igniteData[guid] = nil
          sA:UpdateIgniteData()
        end
      end
    end
  end)

else
  -- Fallback path: parse chat combat log messages (no SuperWoW)
  -- Tracks ignite by target NAME (less precise but workable for single target play)
  sAIgniteTracker:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE")
  sAIgniteTracker:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE")
  sAIgniteTracker:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_OTHER")
  sAIgniteTracker:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")

  -- Patterns
  local PAT_IGNITE_TICK   = "^(.+) suffers (%d+) Fire damage from (.+) Ignite"
  local PAT_IGNITE_GAINS  = "^(.+) gains Ignite"
  local PAT_IGNITE_AFFLICT= "^(.+) is afflicted by Ignite(.*)"
  local PAT_IGNITE_FADES  = "^Ignite fades from (.+)%."
  local PAT_DEATH_SLAIN   = "(.+) is slain by (.+)"
  local PAT_DEATH_YOU     = "You have slain (.+)"
  local PAT_DEATH_DIES    = "(.+) dies%."

  sAIgniteTracker:SetScript("OnEvent", function()
    if not sA.SettingsLoaded then return end
    sA.igniteData = sA.igniteData or {}
    local msg = arg1

    if event == "CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"
    or event == "CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE" then

      -- Ignite tick: capture damage and refresh timer
      local _, _, target, dmg = string.find(msg, PAT_IGNITE_TICK)
      if target and dmg then
        local existing = sA.igniteData[target] or {}
        sA.igniteData[target] = {
          stacks = existing.stacks or 1,
          damage = tonumber(dmg) or 0,
          expiry = GetTime() + IGNITE_DURATION,
        }
        sA:UpdateIgniteData()
        return
      end

      -- Ignite applied (afflicted / gains) — stack count from suffix "(N)"
      local _, _, afflicted, stackInfo = string.find(msg, PAT_IGNITE_AFFLICT)
      if not afflicted then
        _, _, afflicted, stackInfo = string.find(msg, PAT_IGNITE_GAINS)
      end
      if afflicted then
        local _, _, stackNum = string.find(stackInfo or "", "(%d+)")
        local stacks = stackNum and tonumber(stackNum) or 1
        local existing = sA.igniteData[afflicted] or {}
        sA.igniteData[afflicted] = {
          stacks = stacks,
          damage = existing.damage or 0,
          expiry = GetTime() + IGNITE_DURATION,
        }
        sA:UpdateIgniteData()
      end

    elseif event == "CHAT_MSG_SPELL_AURA_GONE_OTHER" then
      local _, _, fadeTarget = string.find(msg, PAT_IGNITE_FADES)
      if fadeTarget then
        sA.igniteData[fadeTarget] = nil
        sA:UpdateIgniteData()
      end

    elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
      local _, _, dead = string.find(msg, PAT_DEATH_SLAIN)
      if not dead then _, _, dead = string.find(msg, PAT_DEATH_YOU) end
      if not dead then _, _, dead = string.find(msg, PAT_DEATH_DIES) end
      if dead and sA.igniteData[dead] then
        sA.igniteData[dead] = nil
        sA:UpdateIgniteData()
      end
    end
  end)
end

-- Timed updates (RENDERING ONLY - fixed 20 FPS)
local sAEvent = CreateFrame("Frame", "sAEvent", UIParent)
sAEvent:SetScript("OnUpdate", function()
  if not sA.SettingsLoaded then return end

	local time = GetTime()
	local renderRate = 0.05  -- Fixed 20 FPS for rendering
	if (time - (sAEvent.lastUpdate or 0)) < renderRate then return end
		
  -- Cache the UI scale in a safe context
  sA.uiScale = UIParent:GetEffectiveScale()

  -- Handle Move Mode with Ctrl Key
  local mainFrame = _G["sAGUI"]
  if mainFrame and mainFrame:IsVisible() and IsControlKeyDown() and IsAltKeyDown() and IsShiftKeyDown() then

	if sA.moveAuras ~= 1 then
			
		-- TestAura
		if sA.TestAura and sA.TestAura:IsVisible() then
			
			sA.draggers[0]:Show()
			gui:SetAlpha(0)
			gui.editor:SetAlpha(0)
			
		else
	  
			-- Continuously show draggers for any visible frames while in move mode
			for id, frame in pairs(sA.frames) do
			  if frame:IsVisible() and sA.draggers[id] then
				sA.draggers[id]:Show()
				gui:SetAlpha(0)
				if gui.editor then
				  gui.editor:SetAlpha(0)
				end
			  end
			end
			
		end

		sA.moveAuras = 1

	end
	
  else

	if sA.moveAuras == 1 then
				
		-- Hide all draggers when not in move mode
	    for id, dragger in pairs(sA.draggers) do
	      if dragger then
			dragger:Hide()
	        gui:SetAlpha(1)
			if gui.editor then
	          gui.editor:SetAlpha(1)
			end
		  end
	    end
		
		-- Reload data if in editor
		if gui.editor and gui.auraEdit and sA.draggers[0] and sA.draggers[0]:IsVisible() then
			
			sA:SaveAura(gui.auraEdit)
			
		end

		sA.moveAuras = 0

	end
	
  end
		
  sAEvent.lastUpdate = time
  sA:UpdateAuras()
		
end)

-- Periodic data updates (controlled by /sa refresh setting)
-- This is the HEAVY operation: scans UnitBuff, UnitDebuff, GetSpellCooldown
local sADataUpdate = CreateFrame("Frame", "sADataUpdate", UIParent)
sADataUpdate:SetScript("OnUpdate", function()
  if not sA.SettingsLoaded then return end
  
  local time = GetTime()
  -- Frequency controlled by simpleAuras.refresh (1-10 per second)
  local dataRefreshRate = 1 / (simpleAuras.refresh or 5)
  if (time - (sADataUpdate.lastUpdate or 0)) < dataRefreshRate then return end
  
  sADataUpdate.lastUpdate = time
  
  -- Rescan auras (catches missed events + provides periodic fallback)
  sA:UpdateAuraDataForUnit("Player")
  if UnitExists("target") then
    sA:UpdateAuraDataForUnit("Target")
  else
    -- Clear target auras if no target exists
    for id, aura in ipairs(simpleAuras.auras or {}) do
      if aura and aura.unit == "Target" and sA.activeAuras[id] then
        sA.activeAuras[id].active = false
        sA.activeAuras[id].expiry = nil
      end
    end
  end
  
  -- Update cooldown and reactive states (poison has its own 3-second timer)
  sA:UpdateCooldownData()
  sA:UpdateReactiveData()
  -- Ignite: refresh which target's data is currently displayed
  sA:UpdateIgniteData()
end)

-- Poison data updates (fixed 3-second interval, independent of refresh rate)
local sAPoisonUpdate = CreateFrame("Frame", "sAPoisonUpdate", UIParent)
sAPoisonUpdate:SetScript("OnUpdate", function()
  if not sA.SettingsLoaded then return end
  
  local time = GetTime()
  -- Fixed 3-second interval for poison updates
  local poisonRefreshRate = 3.0
  if (time - (sAPoisonUpdate.lastUpdate or 0)) < poisonRefreshRate then return end
  
  sAPoisonUpdate.lastUpdate = time
  
  -- Update poison data
  sA:UpdatePoisonData()
end)

-- Combat state
local sACombat = CreateFrame("Frame")
sACombat:RegisterEvent("PLAYER_REGEN_DISABLED")
sACombat:RegisterEvent("PLAYER_REGEN_ENABLED")
sACombat:SetScript("OnEvent", function()
  if event == "PLAYER_REGEN_DISABLED" then
    sAinCombat = true
  elseif event == "PLAYER_REGEN_ENABLED" then
    sAinCombat = nil
  end
end)

-- Aura tracking events (event-driven updates)
local sAAuraTracker = CreateFrame("Frame")
sAAuraTracker:RegisterEvent("UNIT_AURA")
sAAuraTracker:RegisterEvent("PLAYER_AURAS_CHANGED")
sAAuraTracker:RegisterEvent("PLAYER_TARGET_CHANGED")
sAAuraTracker:RegisterEvent("SPELL_UPDATE_COOLDOWN")
sAAuraTracker:RegisterEvent("SPELL_UPDATE_USABLE")
sAAuraTracker:RegisterEvent("COMBAT_TEXT_UPDATE")
sAAuraTracker:RegisterEvent("BAG_UPDATE")
sAAuraTracker:RegisterEvent("BAG_UPDATE_COOLDOWN")
sAAuraTracker:RegisterEvent("UNIT_INVENTORY_CHANGED")
sAAuraTracker:SetScript("OnEvent", function()
  if not sA.SettingsLoaded then return end
  
  if event == "UNIT_AURA" then
    local unit = arg1
    -- Update data for auras tracking this unit
    if unit == "player" then
      sA:UpdateAuraDataForUnit("Player")
    elseif unit == "target" then
      sA:UpdateAuraDataForUnit("Target")
    end
    
  elseif event == "PLAYER_AURAS_CHANGED" then
    -- Fallback event for player auras
    sA:UpdateAuraDataForUnit("Player")
    
  elseif event == "PLAYER_TARGET_CHANGED" then
    -- Target changed, clear old target auras first, then scan new target
    for id, aura in ipairs(simpleAuras.auras or {}) do
      if aura and aura.unit == "Target" and sA.activeAuras[id] then
        sA.activeAuras[id].active = false
        sA.activeAuras[id].expiry = nil
      end
    end
    -- Now scan new target
    if UnitExists("target") then
      sA:UpdateAuraDataForUnit("Target")
    end
    -- Ignite: immediately switch displayed data to new target
    sA:UpdateIgniteData()
    
  elseif event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE" or event == "BAG_UPDATE_COOLDOWN" then
    -- Update all cooldown-type auras (spells and items)
    sA:UpdateCooldownData()
    
  elseif event == "UNIT_INVENTORY_CHANGED" then
    -- Equipped items changed (trinkets, weapons with poisons, etc)
    if arg1 == "player" then
      sA:UpdateCooldownData()
      sA:UpdatePoisonData()
    end
    
  elseif event == "SPELL_UPDATE_USABLE" then
    -- Update reactive spell states (proc-based abilities)
    sA:UpdateReactiveData()
    
  elseif event == "COMBAT_TEXT_UPDATE" then
    -- Floating Combat Text event - fires for reactive ability activation
    local updateType = arg1
    local spellName = arg2
    
    if updateType == "SPELL_ACTIVE" and spellName then
      -- Trim whitespace from spell name
      spellName = gsub(spellName, "^%s+", "")
      spellName = gsub(spellName, "%s+$", "")
      
      -- Reactive ability became active
      sA:HandleReactiveActivation(spellName)
    end
  end
end)

---------------------------------------------------
-- Slash Commands
---------------------------------------------------
SLASH_sA1 = "/sa"
SLASH_sA2 = "/simpleauras"
SlashCmdList["sA"] = function(msg)

	-- Get Command
	if type(msg) ~= "string" then
		msg = ""
	end

	-- Get Command Arguments
	local cmd, val
	local s, e, a, b, c = string.find(msg, "^(%S+)%s*(%S*)%s*(%S*)$")
	if a then cmd = a else cmd = "" end
	if b then val = b else val = "" end
	if c then fad = c else fad = "" end
	
	-- hide / show or no command
	if cmd == "" or cmd == "show" or cmd == "hide" then
		if gui.auraEdit then gui.auraEdit = nil end
		if cmd == "show" then
			if not gui:IsVisible() then gui:Show() end
		elseif cmd == "hide" then
			if gui:IsVisible() then gui:Hide() sA.TestAura:Hide() sA.TestAuraDual:Hide() end
		else 
			if gui:IsVisible() then gui:Hide() sA.TestAura:Hide() sA.TestAuraDual:Hide() else gui:Show() end
		end
		sA:RefreshAuraList()
		return
	end
	
	-- refresh command
	if cmd == "refresh" then
		local num = tonumber(val)
		if num and num >= 1 and num <= 10 then
			simpleAuras.refresh = num
			sA:Msg("Refresh set to " .. num .. " times per second")
		else
			sA:Msg("Usage: /sa refresh X - set refresh rate. (1 to 10 updates per second. Default: 5).")
			sA:Msg("Current refresh = " .. simpleAuras.refresh .. " times per second.")
		end
		return
	end
	
	-- learnall command
	if cmd == "learnall" then
		if sA.SuperWoW then
			local num = tonumber(val)
			if num and (num == 0 or num == 1) then
				simpleAuras.learnall = num
				sA:Msg("LearnAll set to " .. num)
			else
				sA:Msg("Usage: /sa learnall X - learn all AuraDurations, even if no Aura is set up. (1 = Active. Default: 0).")
				sA:Msg("Current LearnAll status = " .. simpleAuras.learnall)
			end
		else
			sA:Msg("/sa showlearning needs SuperWoW to be installed!")
		end
		return
	end
	
	-- refresh command
	if cmd == "update" or cmd == "relearn" then
		local num = tonumber(val)
		if num and (num == 0 or num == 1) then
			simpleAuras.updating = num
			sA:Msg("Aura durations update status set to " .. num)
		else
			sA:Msg("Usage: /sa update X - force aura durations updates (1 = re-learn aura durations. Default: 0).")
			sA:Msg("Current update status = " .. simpleAuras.updating)
		end
		return
	end
	
	-- manual learning of durations
	if cmd == "learn" then
		if sA.SuperWoW then
			local spell = tonumber(val)
			local fade = tonumber(fad)
			if spell and fade then
				local _, playerGUID = UnitExists("player")
				playerGUID = gsub(playerGUID, "^0x", "")
				simpleAuras.auradurations[spell] = simpleAuras.auradurations[spell] or {}
				simpleAuras.auradurations[spell][playerGUID] = fade
				sA:Msg("Set Duration of "..SpellInfo(spell).."("..spell..") to " .. fade .. " seconds.")
			else
				sA:Msg("Usage: /sa learn X Y - manually set duration Y of spellID X.")
			end
		else
			sA:Msg("/sa learn needs SuperWoW to be installed!")
		end
		return
	end
	
	-- track others
	if cmd == "showlearning" then
		local num = tonumber(val)
		if num and (num == 0 or num == 1) then
			simpleAuras.showlearning = num
			sA:Msg("ShowLearning status set to " .. num)
		else
			sA:Msg("Usage: /sa showlearning X - shows learning messages in chat (1 = show. Default: 0).")
			sA:Msg("Works for both auras (SuperWoW) and reactive spells.")
			sA:Msg("Current ShowLearning status = " .. simpleAuras.showlearning)
		end
		return
	end
	
	-- nolearning command - exclude spells from learning
	if cmd == "nolearning" then
		if sA.SuperWoW then
			if val and val ~= "" then
				local spellID = tonumber(val)
				if spellID then
					if simpleAuras.nolearning[spellID] then
						-- Remove from nolearning list
						simpleAuras.nolearning[spellID] = nil
						local spellName = SpellInfo(spellID)
						sA:Msg("Removed " .. (spellName or "Unknown") .. " (ID:"..spellID..") from nolearning list.")
					else
						-- Add to nolearning list
						simpleAuras.nolearning[spellID] = true
						local spellName = SpellInfo(spellID)
						sA:Msg("Added " .. (spellName or "Unknown") .. " (ID:"..spellID..") to nolearning list.")
					end
				elseif val == "list" then
					-- Show list of excluded spells
					local count = 0
					for id, _ in pairs(simpleAuras.nolearning) do
						count = count + 1
					end
					if count == 0 then
						sA:Msg("Nolearning list is empty.")
					else
						sA:Msg("Nolearning list (" .. count .. " spells):")
						for id, _ in pairs(simpleAuras.nolearning) do
							local spellName = SpellInfo(id)
							sA:Msg("  - " .. (spellName or "Unknown") .. " (ID:"..id..")")
						end
					end
				elseif val == "clear" then
					-- Clear all nolearning entries
					local count = 0
					for id, _ in pairs(simpleAuras.nolearning) do
						count = count + 1
					end
					simpleAuras.nolearning = {}
					sA:Msg("Cleared " .. count .. " spell(s) from nolearning list.")
				else
					sA:Msg("Usage: /sa nolearning <spellID> - toggle spell exclusion from learning.")
					sA:Msg("Usage: /sa nolearning list - show all excluded spells.")
					sA:Msg("Usage: /sa nolearning clear - clear all excluded spells.")
				end
			else
				sA:Msg("Usage: /sa nolearning <spellID> - toggle spell exclusion from learning.")
				sA:Msg("Usage: /sa nolearning list - show all excluded spells.")
				sA:Msg("Usage: /sa nolearning clear - clear all excluded spells.")
			end
		else
			sA:Msg("/sa nolearning needs SuperWoW to be installed!")
		end
		return
	end
	
	-- reactduration command (special parsing for spell names with spaces)
	if cmd == "reactduration" then
		-- Extract everything after "reactduration" and parse manually
		local fullArgs = string.match(msg, "^reactduration%s+(.+)$")
		
		if fullArgs then
			-- Find last number (duration)
			local duration = tonumber(string.match(fullArgs, "(%d+)%s*$"))
			if duration and duration > 0 then
				-- Extract spell name/ID (everything before last number)
				local spellIdentifier = string.match(fullArgs, "^(.-)%s*%d+%s*$")
				-- Remove quotes if present
				spellIdentifier = string.gsub(spellIdentifier or "", "^[\"']+", "")
				spellIdentifier = string.gsub(spellIdentifier, "[\"']+$", "")
				spellIdentifier = string.gsub(spellIdentifier, "^%s+", "")
				spellIdentifier = string.gsub(spellIdentifier, "%s+$", "")
				
				if spellIdentifier and spellIdentifier ~= "" then
					simpleAuras.reactiveDurations[spellIdentifier] = duration
					sA:Msg("Set reactive duration of '" .. spellIdentifier .. "' to " .. duration .. " seconds.")
				else
					sA:Msg("Invalid spell name!")
				end
			else
				sA:Msg("Invalid duration!")
			end
		else
			sA:Msg("Usage: /sa reactduration \"Spell Name\" X - set duration X for reactive spell.")
			sA:Msg("Example: /sa reactduration Riposte 5")
		end
		return
	end
	
	-- delete
	if cmd == "forget" or cmd == "unlearn" or cmd == "delete" then
		if sA.SuperWoW then
			local arg = val
			if val and val == "all" then
				simpleAuras.auradurations = {}
				sA:Msg("Forgot all learned AuraDurations.")
			elseif val then
				local val = tonumber(val)
				if simpleAuras.auradurations[val] and type(simpleAuras.auradurations[val]) == "table" then
					simpleAuras.auradurations[val] = nil
					sA:Msg("Forgot learned AuraDuration for " .. SpellInfo(val) .. " (ID:"..val..").")
				else
					sA:Msg("No learned AuraDuration for SpellID " .. val.. ".")
				end
				
				-- local _, playerGUID = UnitExists("player")
				-- playerGUID = gsub(playerGUID, "^0x", "")
				-- for spellID, units in pairs(simpleAuras.auradurations) do
					-- if type(units) == "table" and units[playerGUID] then
						-- units[playerGUID] = nil
						-- if next(units) == nil then
							-- simpleAuras.auradurations[spellID] = nil
						-- end
					-- elseif type(units) ~= "table" and simpleAuras.auradurations[spellID] then
						-- simpleAuras.auradurations[spellID] = nil
					-- end
				-- end
				-- sA:Msg("All learned AuraDurations casted by unitGUID "..unitGUID.." deleted.")
			else
				sA:Msg("Usage: /sa forget X - forget AuraDuration of SpellID X (or use 'all' instead to delete all durations).")
			end
		else
			sA:Msg("/sa forget needs SuperWoW to be installed!")
		end
		return
	end
	

	-- ignite debug
	if cmd == "ignite" then
		sA:Msg("=== Ignite Debug ===")
		sA:Msg("igniteData entries:")
		local count = 0
		for k, v in pairs(sA.igniteData or {}) do
			count = count + 1
			sA:Msg("  ["..tostring(k).."] stacks="..tostring(v.stacks).." dmg="..tostring(v.damage).." expiry="..tostring(v.expiry and string.format("%.1f", v.expiry - GetTime()).."s" or "nil"))
		end
		if count == 0 then sA:Msg("  (empty)") end
		sA:Msg("activeAuras (Ignite type):")
		local found = 0
		for id, aura in ipairs(simpleAuras.auras or {}) do
			if aura and aura.type == "Ignite" then
				found = found + 1
				local d = sA.activeAuras[id]
				if d then
					sA:Msg("  [aura "..id.."] name='"..tostring(aura.name).."' active="..tostring(d.active).." stacks="..tostring(d.stacks).." dmg="..tostring(d.damage).." expiry="..tostring(d.expiry and string.format("%.1f", d.expiry - GetTime()).."s" or "nil"))
				else
					sA:Msg("  [aura "..id.."] name='"..tostring(aura.name).."' no activeAuras entry")
				end
			end
		end
		if found == 0 then
			sA:Msg("  (none found - listing all aura types:)")
			for id, aura in ipairs(simpleAuras.auras or {}) do
				if aura then sA:Msg("  [aura "..id.."] type='"..tostring(aura.type).."' name='"..tostring(aura.name).."'") end
			end
		end
		local _, tguid = UnitExists("target")
		sA:Msg("target GUID: "..tostring(tguid))
		sA:Msg("target name: "..tostring(UnitName("target")))
		return
	end

	-- help or unknown command fallback
	sA:Msg("Usage:")
	sA:Msg("/sa or /sa show or /sa hide - show/hide simpleAuras Settings.")
	sA:Msg("/sa refresh X - set refresh rate. (1 to 10 updates per second. Default: 5).")
	if sA.SuperWoW then
		sA:Msg("/sa learn X Y - manually set duration Y of spellID X.")
		sA:Msg("/sa forget X - forget AuraDuration of SpellID X (or use 'all' instead to delete all durations).")
		sA:Msg("/sa update X - force AuraDurations updates (1 = re-learn aura durations. Default: 0).")
		sA:Msg("/sa showlearning X - shows learning of new AuraDurations in chat (1 = show. Default: 0).")
		sA:Msg("/sa learnall X - learn all AuraDurations, even if no Aura is set up. (1 = Active. Default: 0).")
		sA:Msg("/sa nolearning X - exclude spellID X from learning (toggle). Use 'list' to show, 'clear' to clear all.")
	end

end


