--[[
simpleAuras_MageFire.lua
Scorch / Ignite tracker for simpleAuras, powered by Nampower events.

Nampower (https://gitea.com/avitasia/nampower) fires these as standard
WoW RegisterEvent calls with structured parameters (no text parsing):

  SPELL_DAMAGE_EVENT_SELF / OTHER
    arg1=targetGuid, arg2=casterGuid, arg3=spellId, arg4=amount,
    arg5=mitigationStr, arg6=hitInfo, arg7=spellSchool, arg8=effectAuraStr
    hitInfo==2 means crit.  spellSchool==2 means Fire.

  DEBUFF_ADDED_OTHER / DEBUFF_REMOVED_OTHER
    arg1=guid, arg2=slot, arg3=spellId, arg4=stackCount, arg5=auraLevel

  UNIT_DIED
    arg1=guid

Writes into sA.mf* state tables defined in init.lua.
Read back by sA:UpdateMageFireData() in core.lua for rendering.

Installation:
  1. Drop this file in the simpleAuras addon folder.
  2. Add one line to simpleAuras.toc (after core.lua):
       simpleAuras_MageFire.lua
--]]

-- ── Constants (identical to MageToolEventsV2) ────────────────────────────
local SPELL_SCHOOL_FIRE = 2
local HIT_INFO_CRIT     = 2
local MAX_SCORCH        = 5
local MAX_IGNITE        = 5
local IGNITE_DURATION   = 4  -- seconds before stale ignite state expires

-- ── Spell ID tables ───────────────────────────────────────────────────────

local IGNITE_SPELL_IDS = {
  -- Blast Wave R1-5
  [11113]=1,[13018]=1,[13019]=1,[13020]=1,[13021]=1,
  -- Fire Blast R1-7
  [2136]=1,[2137]=1,[2138]=1,[8412]=1,[8413]=1,[10197]=1,[10199]=1,
  -- Fireball R1-12
  [133]=1,[143]=1,[145]=1,[3140]=1,[8400]=1,[8401]=1,[8402]=1,
  [10148]=1,[10149]=1,[10150]=1,[10151]=1,[25306]=1,
  -- Flamestrike R1-6
  [2120]=1,[2121]=1,[8422]=1,[8423]=1,[10215]=1,[10216]=1,
  -- Pyroblast R1-9
  [11366]=1,[12505]=1,[12522]=1,[12523]=1,[12524]=1,[12525]=1,
  [12526]=1,[12527]=1,[18809]=1,
  -- Scorch R1-7
  [2948]=1,[8444]=1,[8445]=1,[8446]=1,[10205]=1,[10206]=1,[10207]=1,
}

local SCORCH_FIREBLAST_IDS = {
  -- Scorch R1-7
  [2948]=1,[8444]=1,[8445]=1,[8446]=1,[10205]=1,[10206]=1,[10207]=1,
  -- Fire Blast R1-7
  [2136]=1,[2137]=1,[2138]=1,[8412]=1,[8413]=1,[10197]=1,[10199]=1,
}

local IGNITE_DEBUFF_IDS   = { [12654]=1 }
local FIREVULN_DEBUFF_IDS = { [22959]=1 }

-- ── Event frame ───────────────────────────────────────────────────────────
local gsub = string.gsub
local function strip(g)
  if not g then return nil end
  return gsub(g, "^0x", "")
end

local frame = CreateFrame("Frame")

frame:RegisterEvent("SPELL_DAMAGE_EVENT_SELF")
frame:RegisterEvent("SPELL_DAMAGE_EVENT_OTHER")
frame:RegisterEvent("DEBUFF_ADDED_OTHER")
frame:RegisterEvent("DEBUFF_REMOVED_OTHER")
frame:RegisterEvent("UNIT_DIED")

frame:SetScript("OnEvent", function()

  -- SPELL_DAMAGE_EVENT_SELF / SPELL_DAMAGE_EVENT_OTHER
  if event == "SPELL_DAMAGE_EVENT_SELF" or event == "SPELL_DAMAGE_EVENT_OTHER" then
    local targetGuid  = strip(arg1)
    local casterGuid  = strip(arg2)
    local spellId     = arg3
    local amount      = arg4
    local hitInfo     = arg6
    local spellSchool = arg7

    if not targetGuid or not spellId then return end
    if spellSchool ~= SPELL_SCHOOL_FIRE then return end

    local isCrit = (hitInfo == HIT_INFO_CRIT)

    -- Expire stale ignite state
    local lastIgnite = sA.mfIgniteTimer[targetGuid]
    if lastIgnite and (GetTime() - lastIgnite) > IGNITE_DURATION then
      sA.mfIgniteStacks[targetGuid] = nil
      sA.mfIgniteTimer[targetGuid]  = nil
      sA.mfIgniteDamage[targetGuid] = nil
      sA.mfIgniteOwner[targetGuid]  = nil
    end

    -- Ignite DoT tick
    if IGNITE_DEBUFF_IDS[spellId] then
      sA.mfIgniteDamage[targetGuid] = amount
      if casterGuid then sA.mfIgniteOwner[targetGuid] = casterGuid end
      sA.mfIgniteTimer[targetGuid] = GetTime()
      return
    end

    -- Scorch / Fire Blast hit → local stack increment (DEBUFF_ADDED_OTHER is authoritative)
    if SCORCH_FIREBLAST_IDS[spellId] then
      local s = sA.mfScorchStacks[targetGuid] or 0
      if s < MAX_SCORCH then sA.mfScorchStacks[targetGuid] = s + 1 end
      sA.mfScorchTimer[targetGuid] = GetTime()
    end

    -- Fire crit → local Ignite stack increment
    if isCrit and IGNITE_SPELL_IDS[spellId] and casterGuid then
      local ig = sA.mfIgniteStacks[targetGuid] or 0
      if ig < MAX_IGNITE then sA.mfIgniteStacks[targetGuid] = ig + 1 end
      if not sA.mfIgniteOwner[targetGuid] then
        sA.mfIgniteOwner[targetGuid] = casterGuid
      end
      sA.mfIgniteTimer[targetGuid] = GetTime()
    end
    return
  end

  -- DEBUFF_ADDED_OTHER: authoritative stack counts from server
  if event == "DEBUFF_ADDED_OTHER" then
    local guid    = strip(arg1)
    local spellId = arg3
    local stacks  = arg4
    if not guid or not spellId then return end

    if FIREVULN_DEBUFF_IDS[spellId] then
      sA.mfScorchStacks[guid] = stacks or 1
      sA.mfScorchTimer[guid]  = GetTime()
    end
    if IGNITE_DEBUFF_IDS[spellId] then
      sA.mfIgniteStacks[guid] = stacks or 1
      sA.mfIgniteTimer[guid]  = GetTime()
    end
    return
  end

  -- DEBUFF_REMOVED_OTHER
  if event == "DEBUFF_REMOVED_OTHER" then
    local guid    = strip(arg1)
    local spellId = arg3
    if not guid or not spellId then return end

    if FIREVULN_DEBUFF_IDS[spellId] then
      sA.mfScorchStacks[guid] = nil
      sA.mfScorchTimer[guid]  = nil
    end
    if IGNITE_DEBUFF_IDS[spellId] then
      sA.mfIgniteStacks[guid] = nil
      sA.mfIgniteTimer[guid]  = nil
      sA.mfIgniteDamage[guid] = nil
      sA.mfIgniteOwner[guid]  = nil
    end
    return
  end

  -- UNIT_DIED
  if event == "UNIT_DIED" then
    local guid = strip(arg1)
    if not guid then return end
    sA.mfScorchStacks[guid] = nil
    sA.mfScorchTimer[guid]  = nil
    sA.mfIgniteStacks[guid] = nil
    sA.mfIgniteTimer[guid]  = nil
    sA.mfIgniteDamage[guid] = nil
    sA.mfIgniteOwner[guid]  = nil
    return
  end

end)
