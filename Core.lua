local Libra = LibStub("Libra")
local ItemInfo = LibStub("LibItemInfo-1.0")

local Wishlist = MogIt:GetModule("Wishlist")

local HIDDEN_SOURCES = {
	HeadSlot = 77344,
	ShoulderSlot = 77343,
	BackSlot = 77345,
	ShirtSlot = 83202,
	TabardSlot = 83203,
	WaistSlot = 84223,
}

local model = CreateFrame("DressUpModel")
model:SetAutoDress(false)

local function getSourceFromItem(item)
	local visualID, sourceID = C_TransmogCollection.GetItemInfo(item)
	if sourceID then
		return visualID, sourceID
	end
	model:SetUnit("player")
	model:Undress()
	model:TryOn(item)
	for i = 1, 19 do
		local sourceID, visualID = model:GetSlotTransmogSources(i)
		if sourceID ~= 0 then
			return visualID, sourceID
		end
	end
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
		local transmogLocation = TransmogUtil.GetTransmogLocation(slotID, Enum.TransmogType.Appearance, Enum.TransmogModification.Main)
		if item then
			local baseSourceID, baseVisualID, appliedSourceID, appliedVisualID, pendingSourceID, pendingVisualID, hasPendingUndo = C_Transmog.GetSlotVisualInfo(transmogLocation)
			local isTransmogrified, hasPending, isPendingCollected, canTransmogrify, cannotTransmogrifyReason, hasUndo, isHideVisual = C_Transmog.GetSlotInfo(transmogLocation)
			local visualID, sourceID = getSourceFromItem(item)
			
			-- C_Transmog.CanTransmogItemWithItem(GetInventoryItemLink("player", slotID), item)
			-- print(invSlot, sourceID, isTransmogrified, canTransmogrify, baseSourceID)
			-- if not C_TransmogCollection.PlayerKnowsSource(sourceID) then
			
			--[[ CASE
				item transmogged into target
				item transmogged into something else
				item is target
				item is target but hidden - restore
				item is target but pending other - clear pending
				target missing and item pending any
				target slot empty
				source cannot be used
				target cannot be used
			]]
			
			C_Transmog.ClearPending(transmogLocation)
			if not canTransmogrify and not hasUndo then
				C_Transmog.ClearPending(transmogLocation)
			elseif sourceID == baseSourceID then
				-- if isTransmogrified or hasPending then
					-- if it's transmogged into something else, revert that
					-- C_Transmog.ClearPending(transmogLocation)
					local pendingInfo = TransmogUtil.CreateTransmogPendingInfo(Enum.TransmogPendingType.Apply, sourceID)
					C_Transmog.SetPending(transmogLocation, pendingInfo)
					-- C_Transmog.SetPending(transmogLocation, 0)
				-- end
			elseif canTransmogrify then
				-- if appliedSourceID ~= sourceID then
					local sources = C_TransmogCollection.GetAppearanceSources(visualID)
					if sources then
						for i, source in ipairs(sources) do
							if source.isCollected then
								local pendingInfo = TransmogUtil.CreateTransmogPendingInfo(Enum.TransmogPendingType.Apply, source.sourceID)
								C_Transmog.SetPending(transmogLocation, pendingInfo)
							end
						end
						local pendingInfo = TransmogUtil.CreateTransmogPendingInfo(Enum.TransmogPendingType.Apply, sourceID)
						C_Transmog.SetPending(transmogLocation, pendingInfo)
					else
						C_Transmog.ClearPending(transmogLocation)
					end
				-- end
			end
		elseif HIDDEN_SOURCES[invSlot] then
			local pendingInfo = TransmogUtil.CreateTransmogPendingInfo(Enum.TransmogPendingType.ToggleOff, HIDDEN_SOURCES[invSlot])
			C_Transmog.SetPending(transmogLocation, pendingInfo)
		else
			C_Transmog.ClearPending(transmogLocation)
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
dropdown.GetItemTransmogInfoList = function()
	local playerActor = DressUpFrame.ModelScene:GetPlayerActor()
	if playerActor then
		return playerActor:GetItemTransmogInfoList();
	end
	return nil
end
dropdown.initialize = function(self, level)
	local info = UIDropDownMenu_CreateInfo()
	info.text = TRANSMOG_OUTFIT_NEW
	info.colorCode = GREEN_FONT_COLOR_CODE
	info.icon = [[Interface\PaperDollInfoFrame\Character-Plus]]
	info.notCheckable = true
	info.func = function(self, outfitID)
		if WardrobeTransmogFrame and HelpTip:IsShowing(WardrobeTransmogFrame, TRANSMOG_OUTFIT_DROPDOWN_TUTORIAL) then
			HelpTip:Hide(WardrobeTransmogFrame, TRANSMOG_OUTFIT_DROPDOWN_TUTORIAL)
			SetCVarBitfield("closedInfoFrames", LE_FRAME_TUTORIAL_TRANSMOG_OUTFIT_DROPDOWN, true)
		end
		WardrobeOutfitFrame:StartOutfitSave(dropdown)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
	self:AddButton(info)
	
	for i, outfitID in ipairs(C_TransmogCollection.GetOutfits()) do
		local outfitName, outfitIcon = C_TransmogCollection.GetOutfitInfo(outfitID)
		local info = UIDropDownMenu_CreateInfo()
		info.text = outfitName
		info.checked = (outfitID == WardrobeOutfitDropDown.selectedOutfitID)
		info.func = function(self, outfitID)
			if IsShiftKeyDown() then
				WardrobeOutfitEditFrame:ShowForOutfit(outfitID)
			else
				WardrobeOutfitDropDown:SelectOutfit(outfitID, true)
				selectedSet = nil
			end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end
		info.arg1 = outfitID
		self:AddButton(info)
	end
	
	local sets = Wishlist:GetSets(nil, true)
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
			if GetCVarBool("transmogCurrentSpecOnly") then
				local specIndex = GetSpecialization()
				SetCVar("lastTransmogOutfitIDSpec"..specIndex, value)
			else
				for specIndex = 1, GetNumSpecializations() do
					SetCVar("lastTransmogOutfitIDSpec"..specIndex, value)
				end
			end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		end
		info.arg1 = set
		self:AddButton(info)
	end
end

WardrobeOutfitFrame:SetScript("OnUpdate", nil)
WardrobeOutfitFrame:SetScript("OnHide", nil)

WardrobeOutfitDropDownButton:SetScript("OnMouseDown", function(self)
	dropdown:Toggle()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
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
