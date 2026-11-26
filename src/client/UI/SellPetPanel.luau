--!strict
-- SellPetPanel.luau (CLIENT)
-- "💰 BENTAHAN NG PET" — Opens when the player steps on the PetSellPad in the Safe Zone Plaza.
-- Displays all unused/stored pets with 3D previews and sell prices; players click to select pets and sell them!

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetData = require(Shared:WaitForChild("PetData"))
local PetVisuals = require(Shared:WaitForChild("PetVisuals"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local MutationData = require(Shared:WaitForChild("MutationData"))
local ShopData = require(Shared:WaitForChild("ShopData"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))
local InventoryPanel = require(script.Parent:WaitForChild("InventoryPanel"))
local SoundController = require(script.Parent.Parent:WaitForChild("SoundController"))

local SellPetPanel = {}

local modalFrame: Frame
local selectedMap: { [string]: boolean } = {}
local rebuildFn: (() -> ())? = nil

function SellPetPanel.SetVisible(visible: boolean)
	if modalFrame then
		modalFrame.Visible = visible
		if visible and rebuildFn then
			selectedMap = {}
			rebuildFn()
		end
	end
end

function SellPetPanel.IsVisible(): boolean
	return if modalFrame then modalFrame.Visible else false
end

function SellPetPanel.Init(screenGui: ScreenGui, onClose: () -> (), onOpenRequest: () -> ())
	local player = Players.LocalPlayer
	local shopFn = Remotes.GetFunction("ShopRequest")

	local modal, content = Theme.MakeModalShell(screenGui, "💰 BENTAHAN NG PET (UNUSED PETS)", onClose)
	modalFrame = modal

	local infoLabel = Theme.MakeLabel(
		"Info",
		"Click the unused pets you want to sell, then press SELL SELECTED!",
		UDim2.new(1, -140, 0, 28),
		UDim2.fromOffset(0, 0),
		Theme.FontBody,
		Theme.TextPrimary,
		content
	)
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left

	local selectAllBtn = Theme.MakeButton(
		"SelectAllBtn",
		"☑️ Select All",
		UDim2.fromOffset(130, 28),
		UDim2.new(1, -130, 0, 0),
		Theme.AccentBlue,
		content,
		function()
			local pets = InventoryPanel.GetPets()
			local unused: { string } = {}
			local allSelected = true
			for _, p in pets do
				if p.State ~= "Placed" and not p.Equipped then
					table.insert(unused, p.Uid)
					if not selectedMap[p.Uid] then
						allSelected = false
					end
				end
			end
			if allSelected then
				selectedMap = {}
			else
				for _, uid in unused do
					selectedMap[uid] = true
				end
			end
			if rebuildFn then
				rebuildFn()
			end
		end
	)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Grid"
	scroll.Size = UDim2.new(1, 0, 1, -96)
	scroll.Position = UDim2.fromOffset(0, 34)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Parent = content

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(152, 134)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	local sellBtn = Theme.MakeButton(
		"SellSelectedBtn",
		"Select Pets to Sell",
		UDim2.fromOffset(290, 48),
		UDim2.new(0.5, -145, 1, -50),
		Theme.AccentGreen,
		content,
		function()
			local batch: { string } = {}
			for uid, isSel in selectedMap do
				if isSel then
					table.insert(batch, uid)
				end
			end
			if #batch == 0 then
				Toasts.Show("Click on the pets you want to sell first!", Theme.AccentRed)
				return
			end
			local res = shopFn:InvokeServer("SellPetsBatch", batch)
			if typeof(res) == "table" then
				if res.Ok then
					SoundController.Play("Purchase")
					Toasts.Show(tostring(res.Message), Theme.AccentGreen)
					selectedMap = {}
					if rebuildFn then
						rebuildFn()
					end
				else
					Toasts.Show(tostring(res.Message), Theme.AccentRed)
				end
			end
		end
	)

	local function rebuild()
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local pets = InventoryPanel.GetPets()
		local unusedPets = {}
		for _, item in pets do
			if item.State ~= "Placed" and not item.Equipped then
				table.insert(unusedPets, item)
			end
		end

		-- Sort unused pets from highest sell price down to lowest
		table.sort(unusedPets, function(a, b)
			local va = ShopData.GetSellValue(a.PetId, a.Mutation)
			local vb = ShopData.GetSellValue(b.PetId, b.Mutation)
			if va ~= vb then
				return va > vb
			end
			return a.Uid < b.Uid
		end)

		local selectedCount = 0
		local selectedTotalValue = 0

		if #unusedPets == 0 then
			local emptyLbl = Theme.MakeLabel(
				"Empty",
				"No unused pets in your Backpack right now!\n(Placed or Equipped pets are protected from selling.)",
				UDim2.new(1, -20, 0, 80),
				UDim2.fromOffset(10, 20),
				Theme.FontTitle,
				Theme.TextMuted,
				scroll
			)
			emptyLbl.TextWrapped = true
		end

		for idx, item in unusedPets do
			local info = PetData.Get(item.PetId)
			if info then
				local rarity = Rarities.Get(info.Rarity)
				local mutInfo = MutationData.Get(item.Mutation)
				local sellVal = ShopData.GetSellValue(item.PetId, item.Mutation)
				local isSel = selectedMap[item.Uid] == true
				if isSel then
					selectedCount += 1
					selectedTotalValue += sellVal
				else
					selectedMap[item.Uid] = nil
				end

				local borderColor = if isSel
					then Theme.AccentGreen
					elseif mutInfo then mutInfo.Color
					else rarity.Color

				local card = Instance.new("TextButton")
				card.Name = item.Uid
				card.LayoutOrder = idx
				card.BackgroundColor3 = if isSel then Color3.fromRGB(32, 74, 48) else Theme.BgCard
				card.BorderSizePixel = 0
				card.Text = ""
				Theme.AddCorner(card, 10)
				Theme.AddStroke(card, borderColor, if isSel then 3 else 1.8)
				card.Parent = scroll

				-- 3D Pet Viewport (frameless, no dark background!)
				local vpHolder = Instance.new("Frame")
				vpHolder.Name = "ViewportHolder"
				vpHolder.Size = UDim2.fromOffset(66, 62)
				vpHolder.Position = UDim2.new(0.5, -33, 0, 4)
				vpHolder.BackgroundTransparency = 1
				vpHolder.Parent = card
				PetVisuals.MountViewport(vpHolder, item.PetId, item.Mutation, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))

				if isSel then
					local badge = Theme.MakeLabel("SelBadge", "✅ SELL", UDim2.fromOffset(58, 18), UDim2.fromOffset(4, 4), Theme.FontTitle, Theme.AccentGreen, card)
					badge.TextXAlignment = Enum.TextXAlignment.Left
				end

				local prefix = if mutInfo then `[{mutInfo.Name}] ` else ""
				Theme.MakeLabel(
					"Name",
					`{prefix}{info.DisplayName}`,
					UDim2.new(0.92, 0, 0, 20),
					UDim2.fromOffset(6, 68),
					Theme.FontTitle,
					if mutInfo then mutInfo.Color else rarity.Color,
					card
				)

				Theme.MakeLabel(
					"Price",
					`💵 $${NumberFormat.Short(sellVal)}`,
					UDim2.new(0.92, 0, 0, 22),
					UDim2.fromOffset(6, 90),
					Theme.FontTitle,
					Theme.AccentGold,
					card
				)

				Theme.MakeLabel(
					"Hint",
					if isSel then "Click to Unselect" else "Click to Select",
					UDim2.new(0.92, 0, 0, 16),
					UDim2.fromOffset(6, 113),
					Theme.FontBody,
					if isSel then Theme.AccentGreen else Theme.TextMuted,
					card
				)

				card.Activated:Connect(function()
					SoundController.Play("UiClick")
					if selectedMap[item.Uid] then
						selectedMap[item.Uid] = nil
					else
						selectedMap[item.Uid] = true
					end
					rebuild()
				end)
			end
		end

		local allSelected = (#unusedPets > 0 and selectedCount == #unusedPets)
		selectAllBtn.Text = if allSelected then "✖️ Clear All" else "☑️ Select All"

		if selectedCount > 0 then
			infoLabel.Text = `Selected: {selectedCount} Unused Pet(s)  |  Total Payout: $${NumberFormat.Short(selectedTotalValue)}`
			sellBtn.Text = `💰 SELL {selectedCount} PET(S) FOR $${NumberFormat.Short(selectedTotalValue)}`
			sellBtn.BackgroundColor3 = Theme.AccentGreen
		else
			infoLabel.Text = `Unused Pets in Backpack: {#unusedPets} — Click pets below to sell!`
			sellBtn.Text = "Click Pets Above to Sell"
			sellBtn.BackgroundColor3 = Theme.BgHeader
		end
	end

	rebuildFn = rebuild
	InventoryPanel.OnInventoryChanged(function()
		if modalFrame.Visible then
			rebuild()
		end
	end)

	-- Automatically open when the player steps on PetSellPad in the Safe Zone!
	local wasStandingOnPad = false
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			wasStandingOnPad = false
			return
		end

		local onPadNow = false
		for _, pad in CollectionService:GetTagged("PetSellPad") do
			if pad:IsA("BasePart") then
				local dx = math.abs(root.Position.X - pad.Position.X)
				local dz = math.abs(root.Position.Z - pad.Position.Z)
				local dy = math.abs(root.Position.Y - pad.Position.Y)
				if dx <= pad.Size.X * 0.55 and dz <= pad.Size.Z * 0.55 and dy <= 8 then
					onPadNow = true
					break
				end
			end
		end

		if onPadNow and not wasStandingOnPad then
			wasStandingOnPad = true
			if not modalFrame.Visible then
				SoundController.Play("UiClick")
				onOpenRequest()
			end
		elseif not onPadNow and wasStandingOnPad then
			wasStandingOnPad = false
			if modalFrame.Visible then
				onClose()
			end
		end
	end)
end

return SellPetPanel
