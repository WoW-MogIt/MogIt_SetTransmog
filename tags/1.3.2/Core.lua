local Libra = LibStub("Libra")
local ItemInfo = LibStub("LibItemInfo-1.0")

local Wishlist = MogIt:GetModule("Wishlist")

local slots = {
	"HeadSlot",
	"ShoulderSlot",
	"BackSlot",
	"ChestSlot",
	"WristSlot",
	"HandsSlot",
	"WaistSlot",
	"LegsSlot",
	"FeetSlot",
	"MainHandSlot",
	"SecondaryHandSlot",
}

local accessorySlots = {
	"ShirtSlot",
	"TabardSlot",
}

local function getLinkFromLocation(location)
	local player, bank, bags, voidStorage, slot, bag, tab, voidSlot = EquipmentManager_UnpackLocation(location)
	if voidStorage then
		return GetVoidItemHyperlinkString((tab - 1) * 80 + voidSlot)
	elseif not bags then
		return GetInventoryItemLink("player", slot)
	else
		return GetContainerItemLink(bag, slot)
	end
end

local itemTable = {}

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
	for invSlot, item in pairs(items) do
		local slotID = GetInventorySlotInfo(invSlot)
		if MogIt.mogSlots[slotID] then
			local isTransmogrified, canTransmogrify, cannotTransmogrifyReason, _, _, visibleItemID = GetTransmogrifySlotInfo(slotID)
			if item == GetInventoryItemID("player", slotID) then
				-- searched item is the one equipped
				if isTransmogrified then
					-- if it's transmogged into something else, revert that
					ClickTransmogrifySlot(slotID)
				end
			elseif canTransmogrify then
				if visibleItemID ~= item then
					wipe(itemTable)
					GetInventoryItemsForSlot(slotID, itemTable, "transmogrify")
					for location in pairs(itemTable) do
						if MogIt:NormaliseItemString(getLinkFromLocation(location)) == item then
							local player, bank, bags, voidStorage, slot, bag, tab, voidSlot = EquipmentManager_UnpackLocation(location)
							if voidStorage then
								UseVoidItemForTransmogrify(tab, voidSlot, slotID)
							else
								UseItemForTransmogrify(bag, slot, slotID)
							end
							TransmogrifyConfirmationPopup.slot = nil
							break
						end
					end
				end
			end
		end
	end
	for i, invSlot in ipairs(accessorySlots) do
		local slotID = GetInventorySlotInfo(invSlot)
		if items[invSlot] then
			TransmogrifyModelFrame:TryOn(items[invSlot])
		else
			TransmogrifyModelFrame:UndressSlot(slotID)
		end
	end
	if not items["HeadSlot"] then
		TransmogrifyModelFrame:UndressSlot(INVSLOT_HEAD)
	end
	if not items["BackSlot"] then
		TransmogrifyModelFrame:UndressSlot(INVSLOT_BACK)
	end
end

local function onClick(self, items)
	local soundCVar = GetCVar("Sound_EnableSFX")
	SetCVar("Sound_EnableSFX", 0)
	for i, slot in ipairs(slots) do
		ClearTransmogrifySlot(GetInventorySlotInfo(slot))
	end
	applyItems(items)
	StaticPopupSpecial_Hide(TransmogrifyConfirmationPopup)
	TransmogrifyFrame_UpdateApplyButton()
	SetCVar("Sound_EnableSFX", soundCVar)
end

local menuButton = Libra:CreateButton(TransmogrifyFrame)
menuButton:SetWidth(64)
menuButton:SetPoint("TOPRIGHT", -24, -38)
menuButton:SetFrameLevel(TransmogrifyFrame:GetFrameLevel() + 3)
menuButton.arrow:Show()
menuButton:SetText("Sets")
menuButton:SetScript("OnClick", function(self)
	self.menu:Toggle()
	PlaySound("igMainMenuOptionCheckBoxOn")
end)
menuButton:SetScript("OnHide", function(self)
	self.menu:Close()
end)

menuButton.menu = Libra:CreateDropdown("Menu")
menuButton.menu.relativeTo = menuButton
menuButton.menu.relativePoint = "TOPRIGHT"
menuButton.menu.initialize = function(self)
	for i, set in ipairs(Wishlist:GetSets()) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = set.name
		info.func = onClick
		info.arg1 = set.items
		info.notCheckable = true
		local missing, text, isApplied = scanItems(set.items)
		if missing then
			info.tooltipTitle = set.name
			info.tooltipText = text
			info.tooltipLines = true
			info.icon = [[Interface\Minimap\ObjectIcons]]
			info.tCoordLeft = 1/8
			info.tCoordRight = 2/8
			info.tCoordTop = 1/8
			info.tCoordBottom = 2/8
		elseif isApplied then
			info.icon = [[Interface\RaidFrame\ReadyCheck-Ready]]
		end
		self:AddButton(info)
	end
end

ItemInfo.RegisterCallback(menuButton.menu, "OnItemInfoReceivedBatch", function()
	menuButton.menu:Rebuild()
end)