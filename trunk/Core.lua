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

local itemTable = {}

local function scanItems(items, apply)
	local missing, text
	for i, invSlot in ipairs(slots) do
		local item = items[invSlot]
		if item then
			item = MogIt:ItemToID(item)
			local slotID = GetInventorySlotInfo(invSlot)
			local isTransmogrified, canTransmogrify, cannotTransmogrifyReason, _, _, visibleItemID = GetTransmogrifySlotInfo(slotID)
			local found
			if item == GetInventoryItemID("player", slotID) then
				-- searched item is the one equipped
				if isTransmogrified and apply then
					-- if it's transmogged into something else, revert that
					ClickTransmogrifySlot(slotID)
				end
				found = true
			elseif canTransmogrify then
				if visibleItemID == item then
					-- item is already transmogged into search item
					found = true
				else
					wipe(itemTable)
					GetInventoryItemsForSlot(slotID, itemTable, "transmogrify")
					for location, itemID in pairs(itemTable) do
						if itemID == item then
							if apply then
								local player, bank, bags, voidStorage, slot, bag, tab, voidSlot = EquipmentManager_UnpackLocation(location)
								if voidStorage then
									UseVoidItemForTransmogrify(tab, voidSlot, slotID)
								else
									UseItemForTransmogrify(bag, slot, slotID)
								end
								TransmogrifyConfirmationPopup.slot = nil
							end
							found = true
							break
						end
					end
				end
			end
			if not apply and not found then
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
	if apply then
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
	return missing, text
end

local function onClick(self, items)
	local soundCVar = GetCVar("Sound_EnableSFX")
	SetCVar("Sound_EnableSFX", 0)
	for i, slot in ipairs(slots) do
		ClearTransmogrifySlot(GetInventorySlotInfo(slot))
	end
	scanItems(items, true)
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
		local missing, text = scanItems(set.items)
		if missing then
			info.tooltipTitle = set.name
			info.tooltipText = text
			info.tooltipLines = true
			info.icon = [[Interface\Minimap\ObjectIcons]]
			info.tCoordLeft = 1/8
			info.tCoordRight = 2/8
			info.tCoordTop = 1/8
			info.tCoordBottom = 2/8
		end
		self:AddButton(info)
	end
end

ItemInfo.RegisterCallback(menuButton.menu, "OnItemInfoReceivedBatch", function()
	menuButton.menu:Rebuild()
end)