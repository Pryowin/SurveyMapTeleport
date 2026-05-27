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

local function houseMatchesZone(record, zoneId, parentZoneId)
    if not record then
        return false
    end
    local recordZoneId = record.zoneId
    local recordParentZoneId = record.parentZoneId
    return recordZoneId == zoneId
        or recordZoneId == parentZoneId
        or recordParentZoneId == zoneId
        or recordParentZoneId == parentZoneId
end

local function getPreferredHouseIdForZone(zoneId, parentZoneId)
    if not BMU.getZoneSpecificHouse then
        return nil
    end
    return BMU.getZoneSpecificHouse(zoneId) or BMU.getZoneSpecificHouse(parentZoneId)
end

local function findOwnedHouseInZone(zoneId, parentZoneId)
    local parentZoneName = BMU.formatName(GetZoneNameById(parentZoneId), false)
    local preferredHouseId = getPreferredHouseIdForZone(zoneId, parentZoneId)
    local fallbackHouseId
    local fallbackParentZoneName = parentZoneName

    local ownedHouses
    if BMU.IsNotKeyboard and BMU.IsNotKeyboard() then
        ownedHouses = ZO_COLLECTIBLE_DATA_MANAGER:GetAllCollectibleDataObjects(
            { ZO_CollectibleCategoryData.IsHousingCategory },
            { ZO_CollectibleData.IsUnlocked }
        )
    else
        ownedHouses = COLLECTIONS_BOOK_SINGLETON:GetOwnedHouses()
    end

    for _, house in pairs(ownedHouses) do
        local houseId
        if BMU.IsNotKeyboard and BMU.IsNotKeyboard() then
            houseId = house:GetReferenceId()
        else
            houseId = house.houseId
        end
        if houseId and houseId > 0 then
            local houseParentZoneId = BMU.getParentZoneId(GetHouseZoneId(houseId))
            if houseParentZoneId == zoneId or houseParentZoneId == parentZoneId then
                if preferredHouseId and houseId == preferredHouseId then
                    return houseId, parentZoneName
                end
                if not fallbackHouseId then
                    fallbackHouseId = houseId
                end
            end
        end
    end

    if preferredHouseId and preferredHouseId > 0 then
        return preferredHouseId, parentZoneName
    end
    return fallbackHouseId, fallbackParentZoneName
end

local function resolveHouseForZone(zoneId, resultTable)
    local parentZoneId = BMU.getParentZoneId(zoneId)
    local parentZoneName = BMU.formatName(GetZoneNameById(parentZoneId), false)
    local preferredHouseId = getPreferredHouseIdForZone(zoneId, parentZoneId)

    if preferredHouseId and preferredHouseId > 0 then
        return preferredHouseId, parentZoneName
    end

    local fallbackHouseId
    for _, record in pairs(resultTable) do
        if record and record.isOwnHouse and record.houseId and record.houseId > 0 then
            if houseMatchesZone(record, zoneId, parentZoneId) then
                return record.houseId, record.parentZoneName or parentZoneName
            end
        end
    end

    return findOwnedHouseInZone(zoneId, parentZoneId)
end

local function tryPortToHouseInZone(zoneId, resultTable)
    if not BMU.portToOwnHouse then
        return false
    end
    if not CanJumpToHouseFromCurrentLocation() or not CanLeaveCurrentLocationViaTeleport() then
        return false
    end

    local houseId, parentZoneName = resolveHouseForZone(zoneId, resultTable)
    if not houseId or houseId == 0 then
        return false
    end

    BMU.portToOwnHouse(false, houseId, true, parentZoneName)
    return true
end

-- Player jump first; then own house in zone; then gold wayshrine (BMU setting).
local function portToZone(zoneId)
    local resultTable = BMU.createTable({
        index = BMU.indexListZoneHidden,
        fZoneId = zoneId,
        dontDisplay = true,
    })

    for _, entry in pairs(resultTable) do
        if entry and entry.displayName and entry.displayName ~= "" then
            BMU.PortalToPlayer(
                entry.displayName,
                entry.sourceIndexLeading,
                entry.zoneName,
                entry.zoneId,
                entry.category,
                true,
                true,
                true
            )
            return
        end
    end

    if tryPortToHouseInZone(zoneId, resultTable) then
        return
    end

    if BMU.savedVarsAcc.showZonesWithoutPlayers2 and BMU.isZoneOverlandZone(zoneId) then
        BMU.PortalToZone(zoneId)
        return
    end

    if BMU.sc_porting then
        BMU.sc_porting(zoneId)
    elseif BMU.printToChat and BMU.SI then
        BMU.printToChat(BMU.SI.get("SI_TELE_CHAT_NO_FAST_TRAVEL"))
    end
end

local function callToZone(bagId, slotIndex)
    if not BMU or not BMU.createTable or not BMU.PortalToPlayer or not BMU.portToOwnHouse then
        CHAT_ROUTER:AddSystemMessage(GetString(SI_SMT_BMU_MISSING))
        return
    end

    local zoneId = resolveZoneId(bagId, slotIndex)
    if not zoneId then
        CHAT_ROUTER:AddSystemMessage(GetString(SI_SMT_ZONE_UNKNOWN))
        return
    end

    portToZone(zoneId)
end

local function onInventoryContextMenu(inventoryControl)
    if not BMU or not BMU.getDataMapInfo or not BMU.createTable then
        return
    end

    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventoryControl)
    if not bagId or slotIndex == nil then
        return
    end

    if not isOpenedSurveyOrTreasureMap(bagId, slotIndex) then
        return
    end

    if not resolveZoneId(bagId, slotIndex) then
        return
    end

    AddMenuItem(
        GetString(SI_SMT_CALL_TO_ZONE),
        function()
            callToZone(bagId, slotIndex)
        end,
        "inventory-item"
    )
end

local function initialize()
    refreshLocalizedMarkers()

    local lib = LibCustomMenu
    if not lib or not lib.RegisterContextMenu then
        CHAT_ROUTER:AddSystemMessage("Survey Map Teleport requires LibCustomMenu.")
        return
    end

    lib:RegisterContextMenu(onInventoryContextMenu, lib.CATEGORY_INVENTORY_ITEM)
end

local function onAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, onAddOnLoaded)
