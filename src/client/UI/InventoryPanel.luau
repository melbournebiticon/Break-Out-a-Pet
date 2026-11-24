--!strict
-- InventoryPanel.luau (CLIENT)
-- Slide-Left Dropdown Drawer on the right side of the screen!
-- Lists Active Pets placed on your plot (and bag pets) sorted from highest $/sec down to lowest $/sec,
-- with quick Recall / Place / Equip Best / Sell buttons and a red ">" collapse tab on the left edge.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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

local drawerFrame: Frame
local isOpen = false
local currentPets: { ClientPet } = {}
local sellConfirmUid: string? = nil
local listeners: { (pets: { ClientPet }) -> () } = {}

local OPEN_POS = UDim2.new(1, -12, 0.5, 0)
local CLOSED_POS = UDim2.new(1, 260, 0.5, 0)

local function getPetIncome(item: ClientPet): number
	local info = PetData.Get(item.PetId)
	if not info then
		return 0
	end
	return info.IncomePerSec * MutationData.GetMultiplier(item.Mutation)
end

function InventoryPanel.GetPets(): { ClientPet }
	return currentPets
end

function InventoryPanel.OnInventoryChanged(fn: (pets: { ClientPet }) -> ())
	table.insert(listeners, fn)
end

function InventoryPanel.SetVisible(visible: boolean)
	if not drawerFrame then
		return
	end
	isOpen = visible
	if visible then
		drawerFrame.Visible = true
		TweenService:Create(drawerFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = OPEN_POS,
		}):Play()
	else
		local tw = TweenService:Create(drawerFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = CLOSED_POS,
		})
		tw:Play()
		task.delay(0.19, function()
			if not isOpen and drawerFrame then
				drawerFrame.Visible = false
			end
		end)
	end
end

function InventoryPanel.IsVisible(): boolean
	return isOpen
end

function InventoryPanel.Init(screenGui: ScreenGui, onClose: () -> ())
	local player = Players.LocalPlayer
	local petActionFn = Remotes.GetFunction("PetActionRequest")
	local shopFn = Remotes.GetFunction("ShopRequest")

	-- Compact Slide-Left Dropdown Drawer (replaces right-side menu while open!)
	drawerFrame = Theme.MakeFrame(
		"ActivePetsDrawer",
		UDim2.fromOffset(236, 236),
		CLOSED_POS,
		Color3.fromRGB(28, 30, 38),
		10,
		screenGui
	)
	drawerFrame.AnchorPoint = Vector2.new(1, 0.5)
	drawerFrame.Visible = false
	drawerFrame.ZIndex = 18
	Theme.AddStroke(drawerFrame, Color3.fromRGB(15, 16, 22), 3)

	-- Red ">" Collapse Tab on the Left Edge (restores right-side menu on close!)
	local collapseBtn = Theme.MakeButton(
		"CollapseTab",
		">",
		UDim2.fromOffset(28, 32),
		UDim2.new(0, -32, 0.5, -16),
		Color3.fromRGB(215, 42, 42),
		drawerFrame,
		onClose
	)
	Theme.AddStroke(collapseBtn, Color3.fromRGB(20, 20, 25), 2)

	-- Header Bar
	local header = Theme.MakeFrame("Header", UDim2.new(1, -10, 0, 34), UDim2.fromOffset(5, 5), Color3.fromRGB(20, 22, 28), 8, drawerFrame)
	local headerTitle = Theme.MakeLabel(
		"Title",
		"Active Pets (0/3)",
		UDim2.new(0.62, 0, 1, 0),
		UDim2.fromOffset(6, 0),
		Theme.FontTitle,
		Color3.fromRGB(255, 235, 180),
		header
	)
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left

	Theme.MakeButton(
		"EquipBestBtn",
		"⚡ Best",
		UDim2.fromOffset(68, 24),
		UDim2.new(1, -72, 0.5, -12),
		Color3.fromRGB(185, 145, 75),
		header,
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
	scroll.Name = "PetRows"
	scroll.Size = UDim2.new(1, -10, 1, -46)
	scroll.Position = UDim2.fromOffset(5, 42)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Parent = drawerFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scroll

	local function rebuild()
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local activePets: { ClientPet } = {}
		local bagPets: { ClientPet } = {}
		for _, p in currentPets do
			if p.State == "Placed" or p.Equipped then
				table.insert(activePets, p)
			else
				table.insert(bagPets, p)
			end
		end

		-- Sort Active Pets from HIGHEST $/sec down to LOWEST $/sec!
		table.sort(activePets, function(a, b)
			local ia = getPetIncome(a)
			local ib = getPetIncome(b)
			if ia ~= ib then
				return ia > ib
			end
			return a.Uid < b.Uid
		end)

		-- Sort Bag Pets from HIGHEST $/sec down to LOWEST $/sec!
		table.sort(bagPets, function(a, b)
			local ia = getPetIncome(a)
			local ib = getPetIncome(b)
			if ia ~= ib then
				return ia > ib
			end
			return a.Uid < b.Uid
		end)

		local placedCount = 0
		for _, p in activePets do
			if p.State == "Placed" then
				placedCount += 1
			end
		end
		local totalSlotsAttr = player:GetAttribute("PetSlots")
		local totalSlots = if typeof(totalSlotsAttr) == "number" then totalSlotsAttr else 3
		headerTitle.Text = `🐾 Active Pets ({placedCount}/{totalSlots})`

		local order = 0
		local function addRow(item: ClientPet, isActive: boolean)
			local info = PetData.Get(item.PetId)
			if not info then
				return
			end
			order += 1
			local rarity = Rarities.Get(info.Rarity)
			local mutInfo = MutationData.Get(item.Mutation)
			local income = getPetIncome(item)

			local row = Theme.MakeFrame(
				item.Uid,
				UDim2.new(1, -4, 0, 44),
				UDim2.fromScale(0, 0),
				if isActive then Color3.fromRGB(42, 48, 62) else Color3.fromRGB(34, 36, 46),
				8,
				scroll
			)
			row.LayoutOrder = order
			Theme.AddStroke(row, if mutInfo then mutInfo.Color else rarity.Color, 1.5)

			local prefix = if mutInfo then `[{mutInfo.Name}] ` else ""
			local nameLbl = Theme.MakeLabel(
				"Name",
				`{info.Emoji} {prefix}{info.DisplayName}`,
				UDim2.new(0.54, 0, 0, 22),
				UDim2.fromOffset(8, 2),
				Theme.FontTitle,
				if mutInfo then mutInfo.Color else rarity.Color,
				row
			)
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left

			local rateText = if income > 0
				then `+{NumberFormat.Short(income)}/s`
				else (if info.Ability then `⚡ {info.Ability.AbilityId}` else "Power")
			local rateLbl = Theme.MakeLabel(
				"Rate",
				rateText,
				UDim2.new(0.54, 0, 0, 18),
				UDim2.fromOffset(8, 23),
				Theme.FontBody,
				Theme.AccentGreen,
				row
			)
			rateLbl.TextXAlignment = Enum.TextXAlignment.Left

			if isActive then
				local actionCmd = if item.Equipped then "Unequip" else "Unplace"
				Theme.MakeButton(
					"ActionBtn",
					"Recall",
					UDim2.fromOffset(72, 30),
					UDim2.new(1, -78, 0.5, -15),
					Color3.fromRGB(75, 165, 90),
					row,
					function()
						local res = petActionFn:InvokeServer(actionCmd, item.Uid)
						if typeof(res) == "table" and not res.Ok then
							Toasts.Show(tostring(res.Message), Theme.AccentRed)
						end
					end
				)
			else
				local hasAbility = info.Ability ~= nil
				local canPlace = info.Type == "Money" or info.Type == "Hybrid"
				local btnX = -6

				local sellVal = ShopData.GetSellValue(item.PetId)
				local confirming = (sellConfirmUid == item.Uid)
				Theme.MakeButton(
					"SellBtn",
					if confirming then "Sure?" else "Sell",
					UDim2.fromOffset(44, 28),
					UDim2.new(1, btnX - 44, 0.5, -14),
					Theme.AccentRed,
					row,
					function()
						if sellConfirmUid ~= item.Uid then
							sellConfirmUid = item.Uid
							rebuild()
							return
						end
						sellConfirmUid = nil
						local res = shopFn:InvokeServer("SellPet", item.Uid)
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
				btnX -= 48

				if canPlace then
					Theme.MakeButton(
						"PlaceBtn",
						"Place",
						UDim2.fromOffset(48, 28),
						UDim2.new(1, btnX - 48, 0.5, -14),
						Theme.AccentGreen,
						row,
						function()
							local res = petActionFn:InvokeServer("Place", item.Uid)
							if typeof(res) == "table" and not res.Ok then
								Toasts.Show(tostring(res.Message), Theme.AccentRed)
							end
						end
					)
					btnX -= 52
				end

				if hasAbility then
					Theme.MakeButton(
						"EquipBtn",
						"⚡",
						UDim2.fromOffset(30, 28),
						UDim2.new(1, btnX - 30, 0.5, -14),
						Theme.AccentPurple,
						row,
						function()
							local res = petActionFn:InvokeServer("Equip", item.Uid)
							if typeof(res) == "table" then
								if res.Ok then
									SoundController.Play("Purchase")
									Toasts.Show(`⚡ Equipped {info.DisplayName} skill!`, Theme.AccentPurple)
								else
									Toasts.Show(tostring(res.Message), Theme.AccentRed)
								end
							end
						end
					)
				end
			end
		end

		for _, item in activePets do
			addRow(item, true)
		end

		if #bagPets > 0 then
			order += 1
			local divider = Theme.MakeLabel(
				"BagHeader",
				`🎒 In Backpack ({#bagPets}) — Sorted Highest $/s`,
				UDim2.new(1, -8, 0, 22),
				UDim2.fromScale(0, 0),
				Theme.FontBody,
				Theme.TextMuted,
				scroll
			)
			divider.LayoutOrder = order
			divider.TextXAlignment = Enum.TextXAlignment.Left

			for _, item in bagPets do
				addRow(item, false)
			end
		end
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
