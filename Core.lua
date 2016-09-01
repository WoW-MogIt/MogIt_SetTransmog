local Libra = LibStub("Libra")
local ItemInfo = LibStub("LibItemInfo-1.0")

local Wishlist = MogIt:GetModule("Wishlist")

local hideVisualCategories = {
	["HeadSlot"] = LE_TRANSMOG_COLLECTION_TYPE_HEAD,
	["ShoulderSlot"] = LE_TRANSMOG_COLLECTION_TYPE_SHOULDER,
	["BackSlot"] = LE_TRANSMOG_COLLECTION_TYPE_BACK,
}

local hideVisualSources = {}

local accessorySlots = {
	["ShirtSlot"] = LE_TRANSMOG_COLLECTION_TYPE_SHIRT,
	["TabardSlot"] = LE_TRANSMOG_COLLECTION_TYPE_TABARD,
}

local model = CreateFrame("DressUpModel")
model:SetAutoDress(false)

local tryOnSlots = {
	MainHandSlot = "MAINHANDSLOT",
	SecondaryHandSlot = "SECONDARYHANDSLOT",
}

local function getSourceFromItem(item, slot)
	if accessorySlots[slot] then
		local itemID = GetItemInfoInstant(item)
		for i, appearance in ipairs(C_TransmogCollection.GetCategoryAppearances(accessorySlots[slot])) do
			for i, source in ipairs(C_TransmogCollection.GetAppearanceSources(appearance.visualID)) do
				local categoryID, appearanceID, canEnchant, icon, isCollected, link = C_TransmogCollection.GetAppearanceSourceInfo(source.sourceID)
				if itemID == GetItemInfoInstant(link) then
					return source.sourceID
				end
			end
		end
		return
	end
	model:SetUnit("player")
	model:Undress()
	model:TryOn(item, tryOnSlots[slot])
	return model:GetSlotTransmogSources(GetInventorySlotInfo(slot))
end

local function scanItems(items)
	local missing, text
	local isApplied = true
	for i, invSlot in ipairs(slots) do
		local item = items[invSlot]
		if item then
			local slotID = GetInventorySlotInfo(invSlot)
			local isTransmogrified, canTransmogrify, cannotTransmogrifyReason, _, _, visibleItemID = GetTransmogrifySlotInfo(slotID)
			local found
			local equippedItem = MogIt:NormaliseItemString(GetInventoryItemLink("player", slotID))
			if item == equippedItem then
				-- searched item is the one equipped
				found = true
			elseif canTransmogrify then
				if visibleItemID == item then
					-- item is already transmogged into search item
					found = true
				else
					wipe(itemTable)
					GetInventoryItemsForSlot(slotID, itemTable, "transmogrify")
					for location in pairs(itemTable) do
						if MogIt:NormaliseItemString(getLinkFromLocation(location)) == item then
							found = true
							break
						end
					end
				end
			end
			if item ~= equippedItem and visibleItemID ~= item then
				isApplied = false
			end
			if not found then
				missing = true
				local message, color
				if canTransmogrify then
					if not MogIt:HasItem(item) then
						text = (text or "")..format("%s: %s |cffff2020not found.\n", _G[strupper(invSlot)], MogIt:GetItemLabel(item))
					else
						text = (text or "")..format("%s: %s |cffff2020cannot be used to transmogrify this item.\n", _G[strupper(invSlot)], MogIt:GetItemLabel(item))
					end
				else
					text = (text or "")..format("%s: |cffff2020%s\n", _G[strupper(invSlot)], _G["TRANSMOGRIFY_INVALID_REASON"..cannotTransmogrifyReason])
				end
			end
		end
	end
	return missing, text, isApplied
end

local function applyItems(items)
	for i, invSlot in ipairs(MogIt.slots) do
		local slotID = GetInventorySlotInfo(invSlot)
		local item = items[invSlot]
		local hideVisualCategory = hideVisualCategories[invSlot]
		if item then
			local baseSourceID, baseVisualID, appliedSourceID, appliedVisualID, pendingSourceID, pendingVisualID, hasPendingUndo = C_Transmog.GetSlotVisualInfo(slotID, LE_TRANSMOG_TYPE_APPEARANCE)
			local isTransmogrified, hasPending, isPendingCollected, canTransmogrify, cannotTransmogrifyReason, hasUndo, isHideVisual = C_Transmog.GetSlotInfo(slotID, LE_TRANSMOG_TYPE_APPEARANCE)
			local sourceID = getSourceFromItem(item, invSlot)
			local appearance = C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
			-- C_Transmog.CanTransmogItemWithItem(GetInventoryItemID("player", slotID), item)
			-- print(invSlot, sourceID, isTransmogrified, canTransmogrify, baseSourceID)
			-- if not C_TransmogCollection.PlayerKnowsSource(sourceID) then
			-- print(invSlot, sourceID, appearance)
			if not (appearance and appearance.appearanceIsUsable) then
				C_Transmog.ClearPending(slotID, LE_TRANSMOG_TYPE_APPEARANCE)
			elseif sourceID == baseSourceID then
				-- if isTransmogrified or hasPending then
					-- if it's transmogged into something else, revert that
					C_Transmog.ClearPending(slotID, LE_TRANSMOG_TYPE_APPEARANCE)
					-- C_Transmog.SetPending(slotID, LE_TRANSMOG_TYPE_APPEARANCE, 0)
				-- end
			elseif canTransmogrify then
				-- if appliedSourceID ~= sourceID then
					for i, source in ipairs(C_TransmogCollection.GetAppearanceSources(appearance.appearanceID)) do
						if source.isCollected then
							C_Transmog.SetPending(slotID, LE_TRANSMOG_TYPE_APPEARANCE, source.sourceID)
						end
					end
					C_Transmog.SetPending(slotID, LE_TRANSMOG_TYPE_APPEARANCE, sourceID)
				-- end
			end
		elseif hideVisualCategory then
			local hideVisualSource = hideVisualSources[invSlot]
			if not hideVisualSource then
				for i, appearance in pairs(C_TransmogCollection.GetCategoryAppearances(hideVisualCategory)) do
					local sources = C_TransmogCollection.GetAppearanceSources(appearance.visualID)
					if appearance.isHideVisual then
						hideVisualSource = sources[1].sourceID
						hideVisualSources[invSlot] = hideVisualSource
					end
				end
			end
			C_Transmog.SetPending(slotID, LE_TRANSMOG_TYPE_APPEARANCE, hideVisualSource)
		else
			C_Transmog.ClearPending(slotID, LE_TRANSMOG_TYPE_APPEARANCE)
		end
	end
end

-- ItemInfo.RegisterCallback(menuButton.menu, "OnItemInfoReceivedBatch", function()
	-- menuButton.menu:Rebuild()
-- end)

local selectedSet

local function selectSet(set)
	applyItems(set.items)
	UIDropDownMenu_SetText(WardrobeOutfitDropDown, set.name)
end

local dropdown = Libra:CreateDropdown("Menu")
dropdown:SetDisplayMode(nil)
dropdown.relativeTo = WardrobeOutfitDropDownLeft
dropdown.xOffset = nil
dropdown.yOffset = nil
dropdown.initialize = function(self, level)
	local info = UIDropDownMenu_CreateInfo()
	info.text = TRANSMOG_OUTFIT_NEW
	info.colorCode = GREEN_FONT_COLOR_CODE
	info.icon = [[Interface\PaperDollInfoFrame\Character-Plus]]
	info.notCheckable = true
	info.func = function(self, outfitID)
		if WardrobeTransmogFrame and WardrobeTransmogFrame.OutfitHelpBox:IsShown() then
			WardrobeTransmogFrame.OutfitHelpBox:Hide()
			SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_TRANSMOG_OUTFIT_DROPDOWN, true)
		end
		WardrobeOutfitDropDown:CheckOutfitForSave()
		PlaySound("igMainMenuOptionCheckBoxOn")
	end
	self:AddButton(info)
	
	for i, outfit in ipairs(C_TransmogCollection.GetOutfits()) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = outfit.name
		info.checked = (outfit.outfitID == WardrobeOutfitDropDown.selectedOutfitID)
		info.func = function(self, outfitID)
			if IsShiftKeyDown() then
				WardrobeOutfitEditFrame:ShowForOutfit(outfitID)
			else
				WardrobeOutfitDropDown:SelectOutfit(outfitID, true)
				selectedSet = nil
			end
			PlaySound("igMainMenuOptionCheckBoxOn")
		end
		info.arg1 = outfit.outfitID
		self:AddButton(info)
	end
	
	local sets = Wishlist:GetSets()
	if #sets == 0 then return end
	
	local info = UIDropDownMenu_CreateInfo()
	info.text = "MogIt"
	info.isTitle = true
	info.notCheckable = true
	self:AddButton(info)
	
	for i, set in ipairs(sets) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = set.name
		-- local missing, text, isApplied = scanItems(set.items)
		-- if missing then
			-- info.tooltipTitle = set.name
			-- info.tooltipText = text
			-- info.tooltipLines = true
			-- info.icon = [[Interface\Minimap\ObjectIcons]]
			-- info.tCoordLeft = 1/8
			-- info.tCoordRight = 2/8
			-- info.tCoordTop = 1/8
			-- info.tCoordBottom = 2/8
		-- elseif isApplied then
			-- info.icon = [[Interface\RaidFrame\ReadyCheck-Ready]]
		-- end
		info.checked = (set == selectedSet)
		info.func = function(self, set)
			selectSet(set)
			selectedSet = set
			WardrobeOutfitDropDown.selectedOutfitID = nil
			SetCVar("lastTransmogOutfitID", "")
			PlaySound("igMainMenuOptionCheckBoxOn")
		end
		info.arg1 = set
		self:AddButton(info)
	end
end

WardrobeOutfitFrame:SetScript("OnUpdate", nil)
WardrobeOutfitFrame:SetScript("OnHide", nil)

WardrobeOutfitDropDownButton:SetScript("OnClick", function(self)
	dropdown:Toggle()
	PlaySound("igMainMenuOptionCheckBoxOn")
end)

WardrobeOutfitDropDown:HookScript("OnShow", function(self)
	if selectedSet then
		selectSet(selectedSet)
	end
end)

WardrobeOutfitDropDown:HookScript("OnEvent", function(self, event)
	if event == "TRANSMOG_OUTFITS_CHANGED" and selectedSet then
		selectSet(selectedSet)
	end
end)