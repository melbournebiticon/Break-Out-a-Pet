--!strict
-- InventoryPanel.luau (CLIENT)
-- Modal panel displaying owned pets in the player's Bag with "⚡ Equip Best", Place/Unplace, Equip/Unequip, and 2-tap Sell.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetData = require(Shared:WaitForChild("PetData"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local MutationData = require(Shared:WaitForChild("MutationData"))
local ShopData = require(Shared:WaitForChild("ShopData"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))
local SoundController = require(script.Parent.Parent:WaitForChild("SoundController"))

export type ClientPet = {
	Uid: string,
	PetId: string,
	State: "Stored" | "Placed",
	SlotIndex: number?,
	Equipped: boolean,
	Mutation: string?,
	InTransit: boolean?,
}

local InventoryPanel = {}

local modalFrame: Frame
local currentPets: { ClientPet } = {}
local selectedUid: string? = nil
local sellConfirmUid: string? = nil
local listeners: { (pets: { ClientPet }) -> () } = {}

function InventoryPanel.GetPets(): { ClientPet }
	return currentPets
end

function InventoryPanel.OnInventoryChanged(fn: (pets: { ClientPet }) -> ())
	table.insert(listeners, fn)
end

function InventoryPanel.SetVisible(visible: boolean)
	if modalFrame then
		modalFrame.Visible = visible
	end
end

function InventoryPanel.IsVisible(): boolean
	return if modalFrame then modalFrame.Visible else false
end

function InventoryPanel.Init(screenGui: ScreenGui, onClose: () -> ())
	local player = Players.LocalPlayer
	local petActionFn = Remotes.GetFunction("PetActionRequest")
	local shopFn = Remotes.GetFunction("ShopRequest")

	local modal, content = Theme.MakeModalShell(screenGui, "🐾 MY PET BAG", onClose)
	modalFrame = modal

	local slotsLabel = Theme.MakeLabel(
		"SlotsCount",
		"Plot Slots: 0 / 3",
		UDim2.new(0.62, 0, 0, 32),
		UDim2.fromOffset(0, 2),
		Theme.FontBody,
		Theme.TextMuted,
		content
	)
	slotsLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Prominent "⚡ Equip Best" button at top-right of the Pets panel
	Theme.MakeButton(
		"EquipBestBtn",
		"⚡ Equip Best",
		UDim2.fromOffset(155, 34),
		UDim2.new(1, -158, 0, 0),
		Theme.AccentGreen,
		content,
		function()
			local res = petActionFn:InvokeServer("EquipBest")
			if typeof(res) == "table" then
				if res.Ok then
					SoundController.Play("Purchase")
					Toasts.Show(tostring(res.Message), Theme.AccentGreen)
				else
					Toasts.Show(tostring(res.Message), Theme.AccentRed)
				end
			end
		end
	)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Grid"
	scroll.Size = UDim2.new(1, 0, 1, -98)
	scroll.Position = UDim2.fromOffset(0, 38)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Parent = content

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(145, 130)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	local actionBar = Theme.MakeFrame("ActionBar", UDim2.new(1, 0, 0, 54), UDim2.new(0, 0, 1, -54), Theme.BgCard, 12, content)

	local function findSelectedPet(): ClientPet?
		if not selectedUid then
			return nil
		end
		for _, p in currentPets do
			if p.Uid == selectedUid then
				return p
			end
		end
		return nil
	end

	local function rebuild()
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		actionBar:ClearAllChildren()
		Theme.AddCorner(actionBar, 12)

		local placedCount = 0
		for _, p in currentPets do
			if p.State == "Placed" then
				placedCount += 1
			end
		end
		local totalSlotsAttr = player:GetAttribute("PetSlots")
		local totalSlots = if typeof(totalSlotsAttr) == "number" then totalSlotsAttr else 3
		slotsLabel.Text = `Plot Slots Used: {placedCount} / {totalSlots}   |   Bag Pets: {#currentPets}`

		for idx, item in currentPets do
			local info = PetData.Get(item.PetId)
			if info then
				local rarity = Rarities.Get(info.Rarity)
				local mutInfo = MutationData.Get(item.Mutation)
				local mutMult = MutationData.GetMultiplier(item.Mutation)
				local income = info.IncomePerSec * mutMult

				local card = Instance.new("TextButton")
				card.Name = item.Uid
				card.LayoutOrder = idx
				card.BackgroundColor3 = if selectedUid == item.Uid then Color3.fromRGB(55, 68, 96) else Theme.BgCard
				card.BorderSizePixel = 0
				card.Text = ""
				Theme.AddCorner(card, 12)
				Theme.AddStroke(card, if mutInfo then mutInfo.Color else rarity.Color, if selectedUid == item.Uid then 3 else 2)
				card.Parent = scroll

				Theme.MakeLabel("Emoji", info.Emoji, UDim2.fromScale(1, 0.36), UDim2.fromScale(0, 0.04), Theme.FontTitle, Theme.TextPrimary, card)

				local prefix = if mutInfo then `[{mutInfo.Name}] ` else ""
				Theme.MakeLabel("Name", `{prefix}{info.DisplayName}`, UDim2.fromScale(0.92, 0.20), UDim2.fromScale(0.04, 0.40), Theme.FontTitle, if mutInfo then mutInfo.Color else rarity.Color, card)

				local subText = if income > 0 then `+${NumberFormat.Short(income)}/s` else (if info.Ability then info.Ability.AbilityId else "Power")
				Theme.MakeLabel("Rate", subText, UDim2.fromScale(0.92, 0.16), UDim2.fromScale(0.04, 0.60), Theme.FontBody, Theme.AccentGreen, card)

				local badgeText = if item.Equipped
					then "⚡ EQUIPPED"
					elseif item.State == "Placed" then `🏠 SLOT #{item.SlotIndex or "?"}`
					else "🎒 IN BAG"
				local badgeColor = if item.Equipped
					then Theme.AccentGold
					elseif item.State == "Placed" then Theme.AccentBlue
					else Theme.TextMuted
				Theme.MakeLabel("Badge", badgeText, UDim2.fromScale(0.92, 0.16), UDim2.fromScale(0.04, 0.79), Theme.FontTitle, badgeColor, card)

				card.Activated:Connect(function()
					SoundController.Play("UiClick")
					selectedUid = item.Uid
					sellConfirmUid = nil
					rebuild()
				end)
			end
		end

		local sel = findSelectedPet()
		if not sel then
			Theme.MakeLabel("Hint", "Tap a pet card to Place, Equip, or Sell — or click ⚡ Equip Best!", UDim2.fromScale(0.94, 0.7), UDim2.fromScale(0.03, 0.15), Theme.FontBody, Theme.TextMuted, actionBar)
			return
		end

		local info = PetData.Get(sel.PetId)
		if not info then
			return
		end

		local row = Instance.new("Frame")
		row.Size = UDim2.fromScale(0.96, 0.82)
		row.Position = UDim2.fromScale(0.02, 0.09)
		row.BackgroundTransparency = 1
		row.Parent = actionBar

		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.Padding = UDim.new(0, 10)
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		rowLayout.Parent = row

		if info.Type == "Money" or info.Type == "Hybrid" then
			local isPlaced = sel.State == "Placed"
			Theme.MakeButton(
				"PlaceBtn",
				if isPlaced then "Unplace" else "Place on Plot",
				UDim2.fromOffset(140, 40),
				UDim2.fromScale(0, 0),
				if isPlaced then Theme.BgHeader else Theme.AccentBlue,
				row,
				function()
					local res = petActionFn:InvokeServer(if isPlaced then "Unplace" else "Place", sel.Uid)
					if typeof(res) == "table" and not res.Ok then
						Toasts.Show(tostring(res.Message), Theme.AccentRed)
					end
				end
			)
		end

		if info.Ability ~= nil then
			local isEq = sel.Equipped
			Theme.MakeButton(
				"EquipBtn",
				if isEq then "Unequip" else "Equip Ability",
				UDim2.fromOffset(145, 40),
				UDim2.fromScale(0, 0),
				if isEq then Theme.BgHeader else Theme.AccentPurple,
				row,
				function()
					local res = petActionFn:InvokeServer(if isEq then "Unequip" else "Equip", sel.Uid)
					if typeof(res) == "table" and not res.Ok then
						Toasts.Show(tostring(res.Message), Theme.AccentRed)
					end
				end
			)
		end

		local sellVal = ShopData.GetSellValue(sel.PetId)
		local confirming = (sellConfirmUid == sel.Uid)
		Theme.MakeButton(
			"SellBtn",
			if confirming then `Confirm (${NumberFormat.Short(sellVal)})?` else `Sell (${NumberFormat.Short(sellVal)})`,
			UDim2.fromOffset(155, 40),
			UDim2.fromScale(0, 0),
			Theme.AccentRed,
			row,
			function()
				if sellConfirmUid ~= sel.Uid then
					sellConfirmUid = sel.Uid
					rebuild()
					return
				end
				sellConfirmUid = nil
				local res = shopFn:InvokeServer("SellPet", sel.Uid)
				if typeof(res) == "table" then
					if res.Ok then
						SoundController.Play("Purchase")
						Toasts.Show(tostring(res.Message), Theme.AccentGreen)
						selectedUid = nil
					else
						Toasts.Show(tostring(res.Message), Theme.AccentRed)
					end
				end
			end
		)
	end

	player:GetAttributeChangedSignal("PetSlots"):Connect(rebuild)

	Remotes.GetEvent("InventorySync").OnClientEvent:Connect(function(pets: any)
		if typeof(pets) == "table" then
			currentPets = pets
			rebuild()
			for _, fn in listeners do
				task.spawn(fn, currentPets)
			end
		end
	end)

	rebuild()
end

return InventoryPanel
