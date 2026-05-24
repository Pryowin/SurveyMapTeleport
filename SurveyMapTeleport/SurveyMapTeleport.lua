--[[
    Survey Map Teleport
    Right-click an opened survey or treasure map in inventory and choose "Call to Zone"
    to fast-travel via Beam Me Up (BMU.sc_porting / BMU.getDataMapInfo).
]]

local ADDON_NAME = "SurveyMapTeleport"

local string_lower = string.lower
local string_find = string.find
local string_sub = string.sub

ZO_CreateStringId("SI_SMT_CALL_TO_ZONE", "Call to Zone")
ZO_CreateStringId("SI_SMT_BMU_MISSING", "Survey Map Teleport requires Beam Me Up to be enabled.")
ZO_CreateStringId("SI_SMT_ZONE_UNKNOWN", "Survey Map Teleport: Could not determine the zone for this map.")

local surveyMarkerLower
local treasureMarkerLower

local function refreshLocalizedMarkers()
    if BMU and BMU.SI then
        surveyMarkerLower = string_lower(BMU.SI.get("SI_CONSTANT_SURVEY_MAP"))
        treasureMarkerLower = string_lower(BMU.SI.get("SI_CONSTANT_TREASURE_MAP"))
    else
        surveyMarkerLower = "survey:"
        treasureMarkerLower = "treasure map"
    end
end

local function formatItemName(itemName)
    if BMU and BMU.formatName then
        return BMU.formatName(itemName, false)
    end
    return ZO_CachedStrFormat("< >", itemName)
end

-- Opened maps are trophy survey/treasure items, not sealed stackable containers.
local function isOpenedSurveyOrTreasureMap(bagId, slotIndex)
    local _, specializedItemType = GetItemType(bagId, slotIndex)
    if specializedItemType == SPECIALIZED_ITEMTYPE_CONTAINER_STACKABLE then
        return false
    end
    if specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT
        or specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP then
        return true
    end

    refreshLocalizedMarkers()
    local itemNameLower = string_lower(GetItemName(bagId, slotIndex))
    if string_find(itemNameLower, surveyMarkerLower, 1, true) then
        return true
    end
    if string_find(itemNameLower, treasureMarkerLower, 1, true) then
        return true
    end
    return false
end

local function extractZoneNameFromMapItemName(itemName)
    local name = formatItemName(itemName)
    if not name or name == "" then
        return nil
    end

    local colonPos = string_find(name, ": ", 1, true)
    if colonPos then
        return zo_strtrim(string_sub(name, colonPos + 2))
    end

    local commaPos = string_find(name, ", ", 1, true)
    if commaPos then
        return zo_strtrim(string_sub(name, commaPos + 2))
    end

    return nil
end

local function resolveZoneId(bagId, slotIndex)
    if not BMU or not BMU.getDataMapInfo then
        return nil
    end

    local itemId = GetItemId(bagId, slotIndex)
    local _, zoneId, isContainer = BMU.getDataMapInfo(itemId)
    if isContainer then
        return nil
    end
    if zoneId then
        return zoneId
    end

    if not BMU.getZoneIdFromZoneName then
        return nil
    end

    local zoneName = extractZoneNameFromMapItemName(GetItemName(bagId, slotIndex))
    if zoneName then
        return BMU.getZoneIdFromZoneName(zoneName)
    end
    return nil
end

local function callToZone(bagId, slotIndex)
    if not BMU or not BMU.sc_porting then
        CHAT_ROUTER:AddSystemMessage(GetString(SI_SMT_BMU_MISSING))
        return
    end

    local zoneId = resolveZoneId(bagId, slotIndex)
    if not zoneId then
        CHAT_ROUTER:AddSystemMessage(GetString(SI_SMT_ZONE_UNKNOWN))
        return
    end

    BMU.sc_porting(zoneId)
end

local function onInventoryContextMenu(inventorySlot, slotActions)
    if not BMU or not BMU.getDataMapInfo or not BMU.sc_porting then
        return
    end

    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bagId or slotIndex == nil then
        return
    end

    if not isOpenedSurveyOrTreasureMap(bagId, slotIndex) then
        return
    end

    if not resolveZoneId(bagId, slotIndex) then
        return
    end

    slotActions:AddCustomSlotAction(
        GetString(SI_SMT_CALL_TO_ZONE),
        function()
            callToZone(bagId, slotIndex)
        end,
        ""
    )
end

local function initialize()
    refreshLocalizedMarkers()

    local lib = LibCustomMenu
    if not lib or not lib.RegisterContextMenu then
        CHAT_ROUTER:AddSystemMessage("Survey Map Teleport requires LibCustomMenu.")
        return
    end

    lib:RegisterContextMenu(onInventoryContextMenu, lib.CATEGORY_LATE)
end

local function onAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onAddOnLoaded)
