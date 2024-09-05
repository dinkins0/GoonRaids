-- Define the addon, namespaces, and default variables
local addonName, ns = ...
local frame = CreateFrame("Frame")
local deaths = {}
local highestDeathCount = 0
local highestDamage = 0
local highestDamageAbility = ""
local highestDamagePlayer = ""
local addonActive = true  -- State variable to control the addon activity
local piActive = true

-- Constants
local POWER_INFUSION_SPELL_ID = 10060 -- Assuming this is the correct ID for Power Infusion

-- Slash command setup
SLASH_GOONRAIDS1 = "/goonraids"
SlashCmdList["GOONRAIDS"] = function(msg)
    local cmd, channel = strsplit(" ", msg)
    if cmd == "list" and (channel == "raid" or channel == "guild") then
        if addonActive then
            ListDeaths(channel)
        else
            print("GoonRaids is currently paused.")
        end
    elseif cmd == "stop" then
        addonActive = false
        print("GoonRaids has been paused.")
    elseif cmd == "start" then
        addonActive = true
        print("GoonRaids has been resumed.")
    elseif cmd == "pi" then
        if piActive then
            piActive = false
            print("GoonRaids PI feature has been disabled.")
        else
            piActive = true
            print("GoonRaids PI feature has been enabled.")
        end
    end
end

-- Function to list deaths
function ListDeaths(chatChannel)
    local sortedDeaths = {}
    for playerName, data in pairs(deaths) do
        tinsert(sortedDeaths, {name = playerName, count = data.count})
    end
    table.sort(sortedDeaths, function(a, b) return a.count > b.count end)

    -- Sending sorted death counts to the specified chat channel
    SendChatMessage("Death counts:", strupper(chatChannel))
    for _, player in ipairs(sortedDeaths) do
        SendChatMessage(player.name .. " has died " .. player.count .. " times.", strupper(chatChannel))
    end
end

-- Event handler function
local function EventHandler(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        print(addonName .. " loaded and active.")
    elseif not addonActive then
        return  -- If the addon is paused, ignore all events
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags, _, spellId, spellName, _, amount = CombatLogGetCurrentEventInfo()
        
        -- Handle death events and Power Infusion casts
        if subevent == "UNIT_DIED" then
            HandleDeathEvent(destName, amount, spellName)
        elseif subevent == "SPELL_CAST_SUCCESS" and spellId == POWER_INFUSION_SPELL_ID then
            HandlePowerInfusionCast(destName)
        end
    end
end

function HandleDeathEvent(destName, amount, spellName)
    -- Ensure the destination is a player and part of the raid
    if UnitIsPlayer(destName) and UnitInRaid(destName) then
        local deathCount = (deaths[destName] and deaths[destName].count or 0) + 1
        deaths[destName] = { count = deathCount, lastDamage = amount, lastAbility = spellName }

        -- Check for most deaths
        if deathCount > highestDeathCount then
            highestDeathCount = deathCount
            SendChatMessage(destName .. " HAS DIED. THEY NOW LEAD WITH " .. deathCount .. " DEATHS", "RAID_WARNING")
        end

        -- Check for highest damage taken
        if amount > highestDamage then
            highestDamage = amount
            highestDamageAbility = spellName
            highestDamagePlayer = destName
            SendChatMessage("NEW FUNNIEST DEATH: " .. destName .. " HAS DIED TO " .. spellName .. " FOR " .. BreakUpLargeNumbers(amount), "RAID_WARNING")
        end
    end
end

function HandlePowerInfusionCast(destName)
    if piActive then
        if destName ~= UnitName("player") then
            SendChatMessage("INCORRECT PI CAST DETECTED, PLEASE PI DINKINS", "RAID_WARNING")
        end
    end
end

-- Registering events to the frame
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", EventHandler)

-- Utility functions for raid checks
function IsRaidLeader()
    return UnitIsGroupLeader("player")
end

function IsRaidOfficer()
    return UnitIsGroupAssistant("player") or IsRaidLeader()
end
