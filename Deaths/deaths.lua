--[[
  written by topkek
--]]
-- local Ace = LibStub("AceComm-3.0", "AceSerializer-3.0")
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
  if groupSize == 0 then
    local name = UnitName("player")
    local id = UnitGUID(name)
    if group[id] == nil then
      group[id] = {}
    end
    group[id]["name"] = name
    group[id]["num"] = 0
    groupNames[name] = true
  else
    for i = 1, groupSize do
      local name = GetRaidRosterInfo(i)
      local id = UnitGUID(name)
      if group[id] == nil then
        group[id] = {}
      end
      group[id]["name"] = name
      group[id]["num"] = i
      groupNames[name] = true
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

function spacer(max, i, guid)
  local size = #string.format("%.2f", group[guid]["1"]["time"] - group[guid][tostring(i)]["time"])
  local result = ""
  for i = 1, max - size do
    result = result .. "  "
  end
  return result
end

function HandleCombatLog(...)
  UpdateGroupTable()
  local time, subevent, _, _, sourceName, _, _, destGUID, destName = ...
	local spellName, amount, overkill
  local eventPrefix, eventSuffix = subevent:match("^(.-)_?([^_]*)$")
  if group[destGUID] ~= nil then
    if eventSuffix == "DAMAGE" or eventSuffixeventSuffix == "INSTAKILL" then
      local name, rank, subgroup, level, class, fileName,   zone, online, isDead, role, isML = GetRaidRosterInfo(1)
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
      group[destGUID]["1"]["time"] = time
    end
    if true or subevent == "UNIT_DIED" then
      if destGUID == UnitGUID(UnitName("player")) or select(9, GetRaidRosterInfo(group[destGUID]["num"])) then
        if enabled then
          local max = 4
          for i = 2, 3 do
            if group[destGUID][tostring(i)] ~= nil then
              local size = #string.format("%.2f", group[destGUID]["1"]["time"] - group[destGUID][tostring(i)]["time"])
              if size > max then
                max = size
              end
            end
          end
          if group[destGUID]["3"] ~= nil then
            print("|cffFF0000" .. spacer(max, 3, destGUID) .. "-" .. string.format("%.2f", group[destGUID]["1"]["time"] - group[destGUID]["3"]["time"]) 
              .. ": " .. destName .. " took " .. group[destGUID]["3"]["damage"] .. " " .. group[destGUID]["3"]["spell"]
              .. " damage from " .. group[destGUID]["3"]["source"] .. ".|r")
          end
          if group[destGUID]["2"] ~= nil then
            print("|cffFF0000" .. spacer(max, 2, destGUID) .. "-" .. string.format("%.2f", group[destGUID]["1"]["time"] - group[destGUID]["2"]["time"]) 
              .. ": " .. destName .. " took " .. group[destGUID]["2"]["damage"] .. " " .. group[destGUID]["2"]["spell"]
              .. " damage from " .. group[destGUID]["2"]["source"] .. ".|r")
          end
          local result = "|cffFF0000" .. spacer(max, 1, destGUID) .. "0.00: " .. destName .. " took " .. group[destGUID]["1"]["damage"] 
          if group[destGUID]["1"]["overkill"] > 0 then
            result = result .. " (" .. group[destGUID]["1"]["overkill"] .. " overkill)"
          end
          result = result .. "  " ..  group[destGUID]["1"]["spell"] .. " damage from "
            .. group[destGUID]["1"]["source"] .. ".|r"
          print(result)
        end
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
    -- if UnitGUID("raid1") == nil or UnitInBattleground("player") ~= nil or not IsInInstance() then
    --   return
    -- end
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
