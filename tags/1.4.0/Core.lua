local Libra = LibStub("Libra")
local ItemInfo = LibStub("LibItemInfo-1.0")

local Wishlist = MogIt:GetModule("Wishlist")

local OUTFIT_FRAME_ADDED_PIXELS = 90

local hideVisualCategories = {
	["HeadSlot"] = LE_TRANSMOG_COLLECTION_TYPE_HEAD,
	["ShoulderSlot"] = LE_TRANSMOG_COLLECTION_TYPE_SHOULDER,
	["BackSlot"] = LE_TRANSMOG_COLLECTION_TYPE_BACK,
}

local hideVisualSources = {}

local accessorySlots = {
	"ShirtSlot",
	"TabardSlot",
}

local model = CreateFrame("DressUpModel")
model:SetAutoDress(false)

local function getSourceFromItem(item, slot)
	model:SetUnit("player")
	model:Undress()
	model:TryOn(item)
	local sourceID = model:GetSlotTransmogSources(slot)
	return sourceID
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
			local sourceID = getSourceFromItem(item, slotID)
			local categoryID, appearanceID, canEnchant, icon, isCollected = C_TransmogCollection.GetAppearanceSourceInfo(sourceID)
			-- print(invSlot, sourceID, isTransmogrified, canTransmogrify, baseSourceID)
			-- if not C_TransmogCollection.PlayerKnowsSource(sourceID) then
			if not isCollected then
				C_Transmog.ClearPending(slotID, LE_TRANSMOG_TYPE_APPEARANCE)
			elseif sourceID == baseSourceID then
				-- if isTransmogrified or hasPending then
					-- if it's transmogged into something else, revert that
					C_Transmog.ClearPending(slotID, LE_TRANSMOG_TYPE_APPEARANCE)
					-- C_Transmog.SetPending(slotID, LE_TRANSMOG_TYPE_APPEARANCE, 0)
				-- end
			elseif canTransmogrify then
				-- if appliedSourceID ~= sourceID then
					C_Transmog.SetPending(slotID, LE_TRANSMOG_TYPE_APPEARANCE, sourceID)
					-- TransmogrifyConfirmationPopup.slot = nil
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

local function onClick2(self, items)
	PlaySound("igMainMenuOptionCheckBoxOn")
	WardrobeOutfitFrame:Hide()
	if self.outfitID then
		-- WardrobeOutfitFrame.dropDown:SelectOutfit(self.outfitID, true);
		UIDropDownMenu_SetText(WardrobeOutfitFrame.dropDown, Wishlist:GetSets()[self.outfitID].name)
		applyItems(Wishlist:GetSets()[self.outfitID].items)
	end
	-- local soundCVar = GetCVar("Sound_EnableSFX")
	-- SetCVar("Sound_EnableSFX", 0)
	-- for i, slot in ipairs(slots) do
		-- ClearTransmogrifySlot(GetInventorySlotInfo(slot))
	-- end
	-- applyItems(items)
	-- StaticPopupSpecial_Hide(TransmogrifyConfirmationPopup)
	-- TransmogrifyFrame_UpdateApplyButton()
	-- SetCVar("Sound_EnableSFX", soundCVar)
end

local onClick = WardrobeOutfitButtonMixin.OnClick

hooksecurefunc(WardrobeOutfitFrame, "Update", function(self)
	local buttons = self.Buttons
	local numOutfits = #C_TransmogCollection.GetOutfits()
	for i = 1, numOutfits + 1 do
		buttons[i]:SetScript("OnClick", onClick)
		buttons[i].Icon:Show()
	end
	local stringWidth = 0
	local minStringWidth = self.dropDown.minMenuStringWidth or OUTFIT_FRAME_MIN_STRING_WIDTH
	local maxStringWidth = self.dropDown.maxMenuStringWidth or OUTFIT_FRAME_MAX_STRING_WIDTH
	for i, set in ipairs(Wishlist:GetSets()) do
		local index = numOutfits + 1 + i
		local button = buttons[index]
		if not button then
			button = CreateFrame("BUTTON", nil, self, "WardrobeOutfitButtonTemplate")
			button:SetPoint("TOPLEFT", buttons[index - 1], "BOTTOMLEFT", 0, 0)
			button:SetPoint("TOPRIGHT", buttons[index - 1], "BOTTOMRIGHT", 0, 0)
		end
		button:Show()
		button:SetScript("OnClick", onClick2)
		-- if ( outfits[i].outfitID == self.dropDown.selectedOutfitID ) then
			-- button.Check:Show()
			-- button.Selection:Show()
		-- else
			button.Selection:Hide()
			button.Check:Hide()
		-- end
		button.Text:SetWidth(0)
		button:SetText(NORMAL_FONT_COLOR_CODE..set.name..FONT_COLOR_CODE_CLOSE)
		button.Icon:Hide()
		button.outfitID = i
		stringWidth = max(stringWidth, button.Text:GetStringWidth())
		if button.Text:GetStringWidth() > maxStringWidth then
			button.Text:SetWidth(maxStringWidth)
		end
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
		-- self:AddButton(info)
	end
	stringWidth = max(stringWidth, minStringWidth)
	stringWidth = min(stringWidth, maxStringWidth)
	self:SetWidth(max(self:GetWidth(), stringWidth + OUTFIT_FRAME_ADDED_PIXELS))
	self:SetHeight(30 + (numOutfits + 1 + #Wishlist:GetSets()) * 20)
end)

-- ItemInfo.RegisterCallback(menuButton.menu, "OnItemInfoReceivedBatch", function()
	-- menuButton.menu:Rebuild()
-- end)