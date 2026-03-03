--[[
  simpleAuras – pfUI libdebuff External Hook Integration
  -------------------------------------------------------
  Drop this file into the simpleAuras addon folder and add it to simpleAuras.toc
  AFTER core.lua and init.lua:

      libs\libdebuff_integration.lua

  This module is fully optional: if pfUI / libdebuff is not present at load time
  the file does nothing and simpleAuras continues to work exactly as before.

  What it does when libdebuff IS present:
    • Replaces the homegrown RAW_COMBATLOG + UNIT_CASTEVENT listeners used for
      aura-duration learning with the equivalent libdebuff hook callbacks, so
      simpleAuras no longer registers duplicate event listeners for those events.
    • Uses libdebuff:UnitOwnDebuff() and libdebuff:UnitDebuff() as a higher-
      quality data source for target debuff duration/stacks (falls back to the
      existing SuperWoW / tooltip paths if libdebuff returns nothing).
    • Forwards PLAYER_TARGET_CHANGED and UNIT_HEALTH signals so the aura cache
      is still refreshed correctly.

  Integration is opt-in and non-destructive:
    • The existing SuperWoW frame (sADuration) is suppressed only when libdebuff
      hooks are confirmed available; the original fallback logic is never removed.
    • Every hook is registered under the key "simpleAuras" so it can be removed
      cleanly (pfUI.libdebuff_*["simpleAuras"] = nil) without side-effects.
--]]

-- Guard: only run once, and only after VARIABLES_LOADED (sA must exist).
if sA and sA._libdebuffHooked then return end

-------------------------------------------------------------------------------
-- Utility: strip leading 0x from GUIDs (matches simpleAuras convention)
-------------------------------------------------------------------------------
local function stripGUID(g)
  if not g then return nil end
  return string.gsub(g, "^0x", "")
end

-------------------------------------------------------------------------------
-- Deferred initialisation – runs after VARIABLES_LOADED so that both
-- simpleAuras SavedVariables and pfUI are fully loaded.
-------------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("VARIABLES_LOADED")
initFrame:SetScript("OnEvent", function()
  initFrame:UnregisterAllEvents()

  -- -------------------------------------------------------------------------
  -- Bail out silently if pfUI or libdebuff is not available.
  -- -------------------------------------------------------------------------
  if not pfUI or not pfUI.api or not pfUI.api.libdebuff then return end

  local hookTables = {
    pfUI.libdebuff_spell_go_hooks,
    pfUI.libdebuff_spell_go_other_hooks,
    pfUI.libdebuff_spell_start_self_hooks,
    pfUI.libdebuff_spell_start_other_hooks,
    pfUI.libdebuff_spell_cast_hooks,
    pfUI.libdebuff_debuff_removed_other_hooks,
    pfUI.libdebuff_unit_died_hooks,
    pfUI.libdebuff_player_target_changed_hooks,
    pfUI.libdebuff_unit_health_hooks,
  }
  -- Confirm that at least the core hook tables exist.
  for _, t in ipairs(hookTables) do
    if type(t) ~= "table" then return end
  end

  local libdebuff = pfUI.api.libdebuff

  -- -------------------------------------------------------------------------
  -- Suppress the built-in sADuration frame so we don't double-process events.
  -- We do this by replacing its OnEvent with a no-op.  The frame object still
  -- exists (don't destroy it) so nothing else breaks if it holds references.
  -- -------------------------------------------------------------------------
  local sADurationFrame = _G["sADuration"]   -- created in init.lua when SuperWoW
  if sADurationFrame then
    sADurationFrame:UnregisterAllEvents()
    sADurationFrame:SetScript("OnEvent", function() end)
  end

  -- Flag so we never run this setup twice.
  sA._libdebuffHooked = true

  sA:Msg("pfUI libdebuff detected – activating enhanced integration.")

  ---------------------------------------------------------------------------
  -- Local helpers (mirror logic from init.lua so we stay self-contained)
  ---------------------------------------------------------------------------
  local floor    = math.floor
  local gsub     = string.gsub
  local find     = string.find
  local lower    = string.lower
  local GetTime  = GetTime

  local function getAuraIDs(spellName)
    local found = {}
    if not simpleAuras or not simpleAuras.auras then return found end
    for id, aura in ipairs(simpleAuras.auras) do
      if aura and aura.name == spellName then
        table.insert(found, id)
      end
    end
    return found
  end

  local function getAuraDurationBySpellID(spellID, casterGUID)
    if not spellID or not casterGUID then return nil end
    if not simpleAuras or not simpleAuras.auradurations then return nil end
    if type(simpleAuras.auradurations[spellID]) ~= "table" then
      simpleAuras.auradurations[spellID] = nil
      return nil
    end
    return simpleAuras.auradurations[spellID][casterGUID]
  end

  ---------------------------------------------------------------------------
  -- HOOK 1 – SPELL_CAST_EVENT (your own successful cast, equivalent to the
  --           UNIT_CASTEVENT "CAST" branch in init.lua for the player).
  --
  -- Signature: fn(success, spellId, castType, targetGuid)
  ---------------------------------------------------------------------------
  pfUI.libdebuff_spell_cast_hooks["simpleAuras"] = function(success, spellID, castType, targetGUID)
    if not sA.SettingsLoaded then return end
    if not success or not spellID then return end
    if not simpleAuras or not simpleAuras.auradurations then return end

    local timestamp  = GetTime()
    local spellName  = SpellInfo(spellID)
    if not spellName then return end

    -- Deactivate reactive spells when player casts them.
    sA:HandleReactiveSpellUsed(spellName)

    local auraIDs = getAuraIDs(spellName)
    local _, rawPlayerGUID = UnitExists("player")
    local playerGUID = stripGUID(rawPlayerGUID) or sA.playerGUID
    targetGUID = stripGUID(targetGUID)

    if (table.getn(auraIDs) > 0 or simpleAuras.learnall == 1) then

      local dur = getAuraDurationBySpellID(spellID, playerGUID)

      if dur and dur > 0 and simpleAuras.updating == 0 then
        -- Apply known duration
        if not targetGUID or targetGUID == "" then targetGUID = playerGUID end
        sA.auraTimers[targetGUID] = sA.auraTimers[targetGUID] or {}
        sA.auraTimers[targetGUID][spellID] = sA.auraTimers[targetGUID][spellID] or {}
        if not sA.auraTimers[targetGUID][spellID].duration
            or (dur + timestamp) > sA.auraTimers[targetGUID][spellID].duration then
          sA.auraTimers[targetGUID][spellID].duration = timestamp + dur
          sA.auraTimers[targetGUID][spellID].castby   = playerGUID
        end
        sA.learnNew[spellID] = nil

      elseif not simpleAuras.nolearning[spellID] then
        -- Start learning this duration
        if not targetGUID or targetGUID == "" then targetGUID = playerGUID end

        sA.learnCastTimers[targetGUID] = sA.learnCastTimers[targetGUID] or {}
        sA.learnCastTimers[targetGUID][spellID] = sA.learnCastTimers[targetGUID][spellID] or {}
        sA.learnCastTimers[targetGUID][spellID].duration = timestamp
        sA.learnCastTimers[targetGUID][spellID].castby   = playerGUID

        sA.auraTimers[targetGUID] = sA.auraTimers[targetGUID] or {}
        sA.auraTimers[targetGUID][spellID] = sA.auraTimers[targetGUID][spellID] or {}
        sA.auraTimers[targetGUID][spellID].duration = 0
        sA.auraTimers[targetGUID][spellID].castby   = playerGUID

        -- Only mark "learning" for non-player / non-special auras
        local showLearn = false
        for _, id in ipairs(auraIDs) do
          local a = simpleAuras.auras[id]
          if a and a.unit ~= "Player" and a.type ~= "Cooldown" and a.type ~= "Reactive" then
            showLearn = true; break
          end
        end
        if (showLearn or simpleAuras.learnall == 1) and targetGUID ~= playerGUID then
          sA.learnNew[spellID] = 1
        end
        if simpleAuras.showlearning == 1 then
          sA:Msg("Learning " .. (spellName or spellID) .. " (ID:" .. spellID .. ")...")
        end
      end
    end
  end

  ---------------------------------------------------------------------------
  -- HOOK 2 – SPELL_GO_OTHER (another unit completes a cast).
  -- Replaces the UNIT_CASTEVENT branch for non-player casters.
  --
  -- Signature: fn(spellId, casterGuid, targetGuid)
  ---------------------------------------------------------------------------
  pfUI.libdebuff_spell_go_other_hooks["simpleAuras"] = function(spellID, casterGUID, targetGUID)
    if not sA.SettingsLoaded then return end
    if not spellID then return end
    if not simpleAuras or not simpleAuras.learnall == 1 then return end
    if not simpleAuras.auradurations then return end

    local timestamp = GetTime()
    local spellName = SpellInfo(spellID)
    if not spellName then return end

    casterGUID = stripGUID(casterGUID)
    targetGUID = stripGUID(targetGUID)

    local _, rawPlayerGUID = UnitExists("player")
    local playerGUID = stripGUID(rawPlayerGUID) or sA.playerGUID

    -- learnall path: learn durations cast by others too.
    if simpleAuras.learnall == 1 and casterGUID ~= playerGUID
        and not simpleAuras.nolearning[spellID] then

      local dur = getAuraDurationBySpellID(spellID, casterGUID)

      if not targetGUID or targetGUID == "" then targetGUID = casterGUID end

      if dur and dur > 0 and simpleAuras.updating == 0 then
        sA.auraTimers[targetGUID] = sA.auraTimers[targetGUID] or {}
        sA.auraTimers[targetGUID][spellID] = sA.auraTimers[targetGUID][spellID] or {}
        if not sA.auraTimers[targetGUID][spellID].duration
            or (dur + timestamp) > sA.auraTimers[targetGUID][spellID].duration then
          sA.auraTimers[targetGUID][spellID].duration = timestamp + dur
          sA.auraTimers[targetGUID][spellID].castby   = casterGUID
        end
        sA.learnNew[spellID] = nil
      else
        sA.learnCastTimers[targetGUID] = sA.learnCastTimers[targetGUID] or {}
        sA.learnCastTimers[targetGUID][spellID] = sA.learnCastTimers[targetGUID][spellID] or {}
        sA.learnCastTimers[targetGUID][spellID].duration = timestamp
        sA.learnCastTimers[targetGUID][spellID].castby   = casterGUID

        sA.auraTimers[targetGUID] = sA.auraTimers[targetGUID] or {}
        sA.auraTimers[targetGUID][spellID] = sA.auraTimers[targetGUID][spellID] or {}
        sA.auraTimers[targetGUID][spellID].duration = 0
        sA.auraTimers[targetGUID][spellID].castby   = casterGUID

        sA.learnNew[spellID] = 1

        if simpleAuras.showlearning == 1 then
          sA:Msg("Learning (other) " .. (spellName or spellID) .. " (ID:" .. spellID .. ")...")
        end
      end
    end
  end

  ---------------------------------------------------------------------------
  -- HOOK 3 – DEBUFF_REMOVED_OTHER
  -- Replaces the RAW_COMBATLOG "fades from" branch that computed aura durations.
  --
  -- Signature: fn(guid, luaSlot, spellId, stackCount)
  ---------------------------------------------------------------------------
  pfUI.libdebuff_debuff_removed_other_hooks["simpleAuras"] = function(guid, luaSlot, spellID, stackCount)
    if not sA.SettingsLoaded then return end
    if not spellID then return end
    if not simpleAuras or not simpleAuras.auradurations then return end

    local timestamp  = GetTime()
    local targetGUID = stripGUID(guid)
    local spellName  = SpellInfo(spellID)
    if not spellName then return end

    if not sA.auraTimers[targetGUID] then return end
    if not sA.auraTimers[targetGUID][spellID] then return end

    -- If we were learning this duration, compute it now.
    if sA.learnCastTimers[targetGUID]
        and sA.learnCastTimers[targetGUID][spellID]
        and sA.learnCastTimers[targetGUID][spellID].duration then

      local castTime   = sA.learnCastTimers[targetGUID][spellID].duration
      local casterGUID = sA.learnCastTimers[targetGUID][spellID].castby
      local actual     = timestamp - castTime

      simpleAuras.auradurations[spellID] = simpleAuras.auradurations[spellID] or {}
      simpleAuras.auradurations[spellID][casterGUID] = floor(actual + 0.5)
      sA.learnNew[spellID] = nil

      if simpleAuras.updating == 1 then
        sA:Msg("Updated " .. spellName .. " (ID:" .. spellID .. ") to: " .. floor(actual + 0.5) .. "s")
      elseif simpleAuras.showlearning == 1 then
        sA:Msg("Learned " .. spellName .. " (ID:" .. spellID .. ") duration: " .. floor(actual + 0.5) .. "s")
      end

      sA.learnCastTimers[targetGUID][spellID].duration = nil
      sA.learnCastTimers[targetGUID][spellID].castby   = nil
    end

    -- Clean up auraTimers entry if expired.
    if sA.auraTimers[targetGUID][spellID].duration
        and sA.auraTimers[targetGUID][spellID].duration <= timestamp then
      sA.auraTimers[targetGUID][spellID] = nil
    end
    if sA.auraTimers[targetGUID] and not next(sA.auraTimers[targetGUID]) then
      sA.auraTimers[targetGUID] = nil
    end
  end

  ---------------------------------------------------------------------------
  -- HOOK 4 – UNIT_DIED
  -- Clear auraTimers for a unit that dies so stale data isn't kept.
  --
  -- Signature: fn(guid)
  ---------------------------------------------------------------------------
  pfUI.libdebuff_unit_died_hooks["simpleAuras"] = function(guid)
    local targetGUID = stripGUID(guid)
    if targetGUID and sA.auraTimers[targetGUID] then
      sA.auraTimers[targetGUID] = nil
    end
    if targetGUID and sA.learnCastTimers[targetGUID] then
      sA.learnCastTimers[targetGUID] = nil
    end
  end

  ---------------------------------------------------------------------------
  -- HOOK 5 – PLAYER_TARGET_CHANGED
  -- Mirrors the existing sAAuraTracker PLAYER_TARGET_CHANGED handler.
  --
  -- Signature: fn()
  ---------------------------------------------------------------------------
  pfUI.libdebuff_player_target_changed_hooks["simpleAuras"] = function()
    if not sA.SettingsLoaded then return end
    if not simpleAuras or not simpleAuras.auras then return end

    -- Clear stale target auras.
    for id, aura in ipairs(simpleAuras.auras) do
      if aura and aura.unit == "Target" and sA.activeAuras[id] then
        sA.activeAuras[id].active = false
        sA.activeAuras[id].expiry = nil
      end
    end
    if UnitExists("target") then
      sA:UpdateAuraDataForUnit("Target")
    end
  end

  ---------------------------------------------------------------------------
  -- HOOK 6 – UNIT_HEALTH
  -- pfUI fires this for every unit whose health changes; use it as a light-
  -- weight trigger to keep aura states up to date for the player and target.
  --
  -- Signature: fn(unitToken)
  ---------------------------------------------------------------------------
  pfUI.libdebuff_unit_health_hooks["simpleAuras"] = function(unitToken)
    if not sA.SettingsLoaded then return end
    if unitToken == "player" then
      sA:UpdateAuraDataForUnit("Player")
    elseif unitToken == "target" then
      sA:UpdateAuraDataForUnit("Target")
    end
  end

  ---------------------------------------------------------------------------
  -- Enhanced debuff data source
  -- Wrap sA:GetSuperAuraInfos so that for Debuff/Buff auras on the target,
  -- libdebuff:UnitOwnDebuff() is tried first for accurate duration/stacks.
  -- Falls back to the original function transparently.
  ---------------------------------------------------------------------------
  local _origGetSuperAuraInfos = sA.GetSuperAuraInfos

  sA.GetSuperAuraInfos = function(self, name, unit, auratype, myCast)
    -- Only enhance target debuff / buff lookups; leave everything else alone.
    if unit == "Target" and (auratype == "Debuff" or auratype == "Buff") then

      -- Try UnitOwnDebuff first (returns your own aura, with duration from libdebuff).
	local name2, rank, tex, stacks, debuffType, duration, timeleft, caster =
	libdebuff:UnitOwnDebuff("target", name)
	local spellId = nil -- UnitOwnDebuff by-name doesn't return spellId

      if tex and timeleft and timeleft > 0 then
        -- libdebuff returned good data – use it.
        return spellId, tex, timeleft, stacks or 0
      end

      -- If myCast is not required, also try the general slot scan via UnitDebuff.
      if not myCast or myCast == 0 then
        -- Walk slots until we find a matching name.
        local slot = 1
        while true do
local n, rank, t, s, dt, dur, tl, caster = libdebuff:UnitDebuff("target", slot)
if not t then break end
if n == name then
  if tl and tl > 0 then
    return nil, t, tl, s or 0  -- no spellId available here
  end
end
          slot = slot + 1
        end
      end
    end

    -- Fall back to original implementation for everything else.
    return _origGetSuperAuraInfos(self, name, unit, auratype, myCast)
  end

  sA:Msg("pfUI libdebuff hooks registered successfully.")
end)
