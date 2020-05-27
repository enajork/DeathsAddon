--[[
  written by topkek
--]]
local AddOn, config = ...
local Deaths = LibStub("AceAddon-3.0"):NewAddon("Deaths", "AceComm-3.0", "AceSerializer-3.0")
local LibDeflate = LibStub:GetLibrary("LibDeflate");
local frame = CreateFrame("Frame")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
local MAX_SIZE = 40
local groupSize = 0
local _group = {}
local groupNames = {}
local raidEnabled = true
local enabled = false
local raid = false

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
  groupSize = GetNumGroupMembers()
  if groupSize == 0 then
    local name = UnitName("player")
    local id = UnitGUID(name)
    if _group[id] == nil then
      _group[id] = {}
    end
    _group[id]["name"] = name
    _group[id]["num"] = 0
    _group[id]["reported"] = false
    groupNames[name] = true
  else
    for i = 1, groupSize do
      local name = GetRaidRosterInfo(i)
      if name == nil then
        return
      end
      local id = UnitGUID(name)
      if _group[id] == nil then
        _group[id] = {}
      end
      _group[id]["name"] = name
      _group[id]["num"] = i
      local isDead = select(9, GetRaidRosterInfo(i))
      if not isDead then
        _group[id]["reported"] = false
      end
      groupNames[name] = true
    end
  end
  for key, value in pairs(_group) do
    if not groupNames[value["name"]] then
      _group[key] = nil
    end
  end
end

function shiftEvents(destGUID)
  if _group[destGUID]["1"] == nil or next(_group[destGUID]["1"]) == nil then
    _group[destGUID]["1"] = {}
  else
    _group[destGUID]["3"] = shallowcopy(_group[destGUID]["2"])
    _group[destGUID]["2"] = shallowcopy(_group[destGUID]["1"])
  end
end

function printDeath(group, destGUID, destName)
  if group[destGUID]["1"] == nil then
    return
  end
  if (not enabled and not raid) or (raid and not raidEnabled) then
    return
  end
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
    print("|cffFF0000" .. spacer(group, max, 3, destGUID) .. "-" .. string.format("%.2f", group[destGUID]["1"]["time"] - group[destGUID]["3"]["time"]) 
      .. ": " .. destName .. " took " .. group[destGUID]["3"]["damage"] .. " " .. group[destGUID]["3"]["spell"]
      .. " damage from " .. group[destGUID]["3"]["source"] .. ".|r")
  end
  if group[destGUID]["2"] ~= nil then
    print("|cffFF0000" .. spacer(group, max, 2, destGUID) .. "-" .. string.format("%.2f", group[destGUID]["1"]["time"] - group[destGUID]["2"]["time"]) 
      .. ": " .. destName .. " took " .. group[destGUID]["2"]["damage"] .. " " .. group[destGUID]["2"]["spell"]
      .. " damage from " .. group[destGUID]["2"]["source"] .. ".|r")
  end
  local result = "|cffFF0000" .. spacer(group, max, 1, destGUID) .. " 0.00: " .. destName .. " took " .. group[destGUID]["1"]["damage"]
  if group[destGUID]["1"]["overkill"] > 0 then
    result = result .. " (" .. group[destGUID]["1"]["overkill"] .. " overkill)"
  end
  result = result .. " " ..  group[destGUID]["1"]["spell"] .. " damage from "
    .. group[destGUID]["1"]["source"] .. ".|r"
  print(result)
  _group[destGUID]["reported"] = true
end

function spacer(group, max, i, guid)
  local size = #string.format("%.2f", group[guid]["1"]["time"] - group[guid][tostring(i)]["time"])
  local result = ""
  for i = 1, max - size do
    result = result .. "  "
  end
  return result
end

function Deaths:OnCommReceive(prefix, msg, distribution, sender)
  if UnitGUID(sender) == UnitGUID(UnitName("player")) then
    return
  end
  UpdateGroupTable()
	local decoded = LibDeflate:DecodeForWoWAddonChannel(msg)
	local decompressed = LibDeflate:DecompressDeflate(decoded)
  local ok, data, destGUID, destName = Deaths:Deserialize(decompressed)
  if not ok then
    return
  end
  if _group[destGUID]["reported"] == false then
    printDeath(data, destGUID, destName)
  end
end

function HandleCombatLog(...)
  UpdateGroupTable()
  local time, subevent, _, _, sourceName, _, _, destGUID, destName = ...
	local spellName, amount, overkill
  local eventPrefix, eventSuffix = subevent:match("^(.-)_?([^_]*)$")
  if _group[destGUID] ~= nil then
    if eventSuffix == "DAMAGE" or eventSuffixeventSuffix == "INSTAKILL" then
      local name = GetRaidRosterInfo(1)
      if eventPrefix == "SWING" then
        amount, overkill = select(12, ...)
        if amount == 0 then
          return
        end
        shiftEvents(destGUID)
        _group[destGUID]["1"]["spell"] = "Melee"
      elseif eventPrefix == "ENVIRONMENTAL" then
        environmentalType, amount, overkill = select(12, ...)
        if amount == 0 then
          return
        end
        shiftEvents(destGUID)
        _group[destGUID]["1"]["spell"] = environmentalType
        _group[destGUID]["1"]["source"] = "the environment"
      elseif eventPrefix == "SPELL" or eventPrefix == "SPELL_PERIODIC" 
          or eventPrefix == "SPELL_BUILDING" 
          or eventPrefix == "RANGE" then
        _, spellName, _, amount, overkill = select(12, ...)
        if amount == 0 then
          return
        end
        shiftEvents(destGUID)
        _group[destGUID]["1"]["spell"] = spellName
      end
      if overkill == nil then
        overkill = -1
      end
      if overkill == -1 then
        _group[destGUID]["1"]["damage"] = amount
      else
        _group[destGUID]["1"]["damage"] = amount - overkill
        _group[destGUID]["1"]["overkill"] = overkill
      end
      if sourceName ~= nil then
        _group[destGUID]["1"]["source"] = sourceName
      end
      _group[destGUID]["1"]["overkill"] = overkill
      if eventSuffix == "INSTAKILL" then
        _group[destGUID]["1"]["damage"] = "Instakill"
        _group[destGUID]["1"]["spell"] = spellName
        _group[destGUID]["1"]["source"] = sourceName
        if spellName == nil then
          _group[destGUID]["1"]["spell"] = "Instakill"
        end
        if sourceName == nil then
          _group[destGUID]["1"]["source"] = "an unknown source"
        end
      end
      _group[destGUID]["1"]["time"] = time
    end
    if subevent == "UNIT_DIED" then
      if destGUID == UnitGUID(UnitName("player")) or select(9, GetRaidRosterInfo(_group[destGUID]["num"])) then
        local serialized = Deaths:Serialize(_group, destGUID, destName)
        local compressed = LibDeflate:CompressDeflate(serialized, {level = 9})
        local data = LibDeflate:EncodeForWoWAddonChannel(compressed)
        if raid then
          Deaths:SendCommMessage("Deaths", data, "RAID")
        else
          Deaths:SendCommMessage("Deaths", data, "PARTY")
        end
        if enabled or (raid and raidEnabled) then
          printDeath(_group, destGUID, destName)
        end
      end
    end
  end
end

function IsInRaidInstance()
  raid = false
  if UnitGUID("raid1") == nil or UnitInBattleground("player") ~= nil or not IsInInstance() then
    return false
  end
  local zone = GetZoneText()
  for i = 1, #config.raids do
    if zone == config.raids[i] then
      raid = true
      return true
    end
  end
  return false
end

function handleEvents(self, event, msg, sender)
  if event == "PLAYER_LOGIN" then
    print("|cffFF0000Loaded Topkek's Death Addon v0.2|r")
    Deaths:RegisterComm("Deaths", "OnCommReceive")
    UpdateGroupTable()
    IsInRaidInstance()
  end
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    UpdateGroupTable()
    HandleCombatLog(CombatLogGetCurrentEventInfo())
  end
  if event == "GROUP_ROSTER_UPDATE" then
    UpdateGroupTable()
    IsInRaidInstance()
  end
  if event == "ZONE_CHANGED" then
    IsInRaidInstance()
  end
end

frame:SetScript("OnEvent", handleEvents)

function slashCommand(msg)
  if raid then
    raidEnabled = not raidEnabled
    if raidEnabled then
      print("|cffFF0000Deaths raid enabled|r")
    else
      print("|cffFF0000Deaths raid disabled|r")
    end
  else
    enabled = not enabled
    if enabled then
      print("|cffFF0000Deaths enabled|r")
    else
      print("|cffFF0000Deaths disabled|r")
    end
  end
end

SLASH_DEATHS1 = "/death"
SLASH_DEATHS2 = "/deaths"
SlashCmdList["DEATHS"] = slashCommand
