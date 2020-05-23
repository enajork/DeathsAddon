--[[
  written by topkek
--]]
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
local MAX_SIZE = 40
local groupSize = 0
local group = {}
local groupNames = {}
local enabled = true

function shallowcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
      copy = {}
      for orig_key, orig_value in pairs(orig) do
          copy[orig_key] = orig_value
      end
  else
      copy = orig
  end
  return copy
end

function UpdateGroupTable()
  groupNames = {}
  groupSize = GetNumGroupMembers();
  local myName, myRealm = UnitName("player")
  local fullName = myName
  if myRealm ~= nil and myRealm ~= "" then
    fullName = myName .. "-" .. myRealm
  end
  local id = UnitGUID("player")
  if group[id] == nil then
    group[id] = {}
  end
  group[id]["name"] = fullName
  groupNames[fullName] = true
  if UnitGUID("raid1") == nil then
    for i = 1, groupSize - 1 do
      local myName, myRealm = UnitName("party" .. i)
      local fullName = myName
      if myRealm ~= nil and myRealm ~= "" then
        fullName = myName .. "-" .. myRealm
      end
      local id = UnitGUID("party" .. i)
      if group[id] == nil then
        group[id] = {}
      end
      group[id]["name"] = fullName
      groupNames[fullName] = true
    end
  else
    for i = 1, groupSize - 1 do
      local myName, myRealm = UnitName("raid" .. i)
      local fullName = myName
      if myRealm ~= nil and myRealm ~= "" then
        fullName = myName .. "-" .. myRealm
      end
      local id = UnitGUID("raid" .. i)
      if group[id] == nil then
        group[id] = {}
      end
      group[id]["name"] = fullName
      groupNames[fullName] = true
    end
  end
  for key, value in pairs(group) do
    if not groupNames[value["name"]] then
      group[key] = nil
    end
  end
end

function shiftEvents(destGUID)
  if group[destGUID]["1"] == nil or next(group[destGUID]["1"]) == nil then
    group[destGUID]["1"] = {}
  else
    group[destGUID]["3"] = shallowcopy(group[destGUID]["2"])
    group[destGUID]["2"] = shallowcopy(group[destGUID]["1"])
  end
end

function HandleCombatLog(...)
  local _, subevent, _, _, sourceName, _, _, destGUID, destName = ...
	local spellName, amount, overkill
  local eventPrefix, eventSuffix = subevent:match("^(.-)_?([^_]*)$")
  if group[destGUID] ~= nil then
    if eventSuffix == "DAMAGE" or eventSuffixeventSuffix == "INSTAKILL" then
      if eventPrefix == "SWING" then
        amount, overkill = select(12, ...)
        if amount == 0 then
          return
        end
        shiftEvents(destGUID)
        group[destGUID]["1"]["spell"] = "Melee"
      elseif eventPrefix == "ENVIRONMENTAL" then
        environmentalType, amount, overkill = select(12, ...)
        if amount == 0 then
          return
        end
        shiftEvents(destGUID)
        group[destGUID]["1"]["spell"] = environmentalType
        group[destGUID]["1"]["source"] = "the environment"
      elseif eventPrefix == "SPELL" or eventPrefix == "SPELL_PERIODIC" 
          or eventPrefix == "SPELL_BUILDING" 
          or eventPrefix == "RANGE" then
        _, spellName, _, amount, overkill = select(12, ...)
        if amount == 0 then
          return
        end
        shiftEvents(destGUID)
        group[destGUID]["1"]["spell"] = spellName
      end
      if overkill == nil then
        overkill = -1
      end
      if overkill == -1 then
        group[destGUID]["1"]["damage"] = amount
      else
        group[destGUID]["1"]["damage"] = amount - overkill
        group[destGUID]["1"]["overkill"] = overkill
      end
      if sourceName ~= nil then
        group[destGUID]["1"]["source"] = sourceName
      end
      group[destGUID]["1"]["overkill"] = overkill
      if eventSuffix == "INSTAKILL" then
        group[destGUID]["1"]["damage"] = "Instakill"
        group[destGUID]["1"]["spell"] = spellName
        group[destGUID]["1"]["source"] = sourceName
        if spellName == nil then
          group[destGUID]["1"]["spell"] = "Instakill"
        end
        if sourceName == nil then
          group[destGUID]["1"]["source"] = "an unknown source"
        end
      end
    end
    if subevent == "UNIT_DIED" then
      if enabled then
        print("|cffFF0000Player death: " .. destName .. "|r")
        if group[destGUID]["3"] ~= nil then
          print("|cffFF00003: " .. group[destGUID]["3"]["damage"] 
            .. " damage from " .. group[destGUID]["3"]["source"] 
            .. "'s " .. group[destGUID]["3"]["spell"] .. ".|r")
        end
        if group[destGUID]["2"] ~= nil then
          print("|cffFF00002: " .. group[destGUID]["2"]["damage"] 
            .. " damage from " .. group[destGUID]["2"]["source"] 
            .. "'s " .. group[destGUID]["2"]["spell"] .. ".|r")
        end
        local result = "|cffFF00001: " .. group[destGUID]["1"]["damage"] 
          .. " damage"
        if group[destGUID]["1"]["overkill"] > 0 then
          result = result .. " (" .. group[destGUID]["1"]["overkill"] .. " overkill)"
        end
        result = result .. " from " .. group[destGUID]["1"]["source"] 
          .. "'s " .. group[destGUID]["1"]["spell"] .. ".|r"
        print(result)
      end
    end
  end
end

function handleEvents(self, event, msg, sender)
  if event == "PLAYER_LOGIN" then
    UpdateGroupTable()
    print("|cffFF0000Loaded Topkek's Death Addon v0.1|r")
  end
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    HandleCombatLog(CombatLogGetCurrentEventInfo())
  end
  if event == "GROUP_ROSTER_UPDATE" then
    UpdateGroupTable()
  end
end

frame:SetScript("OnEvent", handleEvents)

function slashCommand(msg)
  enabled = not enabled
  if enabled then
    print("|cffFF0000Deaths enabled|r")
  else
    print("|cffFF0000Deaths disabled|r")
  end
end

SLASH_DEATHS1 = "/death"
SLASH_DEATHS2 = "/deaths"
SlashCmdList["DEATHS"] = slashCommand
