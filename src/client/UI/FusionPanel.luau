--!strict
-- FusionPanel.luau (CLIENT)
-- Pick 3 pets of the same rarity to fuse into the next rarity tier. Also opens from FusionMachine ProximityPrompts.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FusionData = require(Shared:WaitForChild("FusionData"))
local PetData = require(Shared:WaitForChild("PetData"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))
local InventoryPanel = require(script.Parent:WaitForChild("InventoryPanel"))
local SoundController = require(script.Parent.Parent:WaitForChild("SoundController"))

local FusionPanel = {}

local modalFrame: Frame
local selectedUids: { string } = {}
local rebuildFn: (() -> ())? = nil

function FusionPanel.SetVisible(visible: boolean)
	if modalFrame then
		modalFrame.Visible = visible
		if visible and rebuildFn then
			selectedUids = {}
			rebuildFn()
		end
	end
end

function FusionPanel.IsVisible(): boolean
	return if modalFrame then modalFrame.Visible else false
end

local function isSelected(uid: string): number?
	for i, id in selectedUids do
		if id == uid then
			return i
		end
	end
	return nil
end

function FusionPanel.Init(screenGui: ScreenGui, onClose: () -> (), onOpenRequest: () -> ())
	local player = Players.LocalPlayer
	local fusionFn = Remotes.GetFunction("FusionRequest")

	local modal, content = Theme.MakeModalShell(screenGui, "⚗️ PET FUSION MACHINE", onClose)
	modalFrame = modal

	local infoLabel = Theme.MakeLabel(
		"Info",
		"Pick 3 unequipped pets of the SAME rarity to fuse!",
		UDim2.new(1, 0, 0, 28),
		UDim2.fromOffset(0, 0),
		Theme.FontBody,
		Theme.TextPrimary,
		content
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
	grid.CellSize = UDim2.fromOffset(135, 110)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.Parent = scroll

	local fuseBtn = Theme.MakeButton(
		"FuseBtn",
		"Select 3 Pets",
		UDim2.fromOffset(240, 48),
		UDim2.new(0.5, -120, 1, -50),
		Theme.AccentPurple,
		content,
		function()
			if #selectedUids ~= FusionData.FuseCount then
				Toasts.Show("Select 3 pets of the same rarity first!", Theme.AccentRed)
				return
			end
			local res = fusionFn:InvokeServer(selectedUids)
			if typeof(res) == "table" then
				if res.Ok then
					SoundController.Play("Purchase")
					Toasts.Show(tostring(res.Message), if res.Success then Theme.AccentGold else Theme.AccentBlue)
					selectedUids = {}
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
		local chosenRarity: string? = nil
		if #selectedUids > 0 then
			for _, p in pets do
				if p.Uid == selectedUids[1] then
					local pInfo = PetData.Get(p.PetId)
					if pInfo then
						chosenRarity = pInfo.Rarity
					end
					break
				end
			end
		end

		for idx, item in pets do
			local info = PetData.Get(item.PetId)
			if info and not item.Equipped and FusionData.GetRule(info.Rarity) ~= nil then
				local rarity = Rarities.Get(info.Rarity)
				local selIdx = isSelected(item.Uid)

				local card = Instance.new("TextButton")
				card.Name = item.Uid
				card.LayoutOrder = idx
				card.BackgroundColor3 = if selIdx then Color3.fromRGB(70, 50, 110) else Theme.BgCard
				card.BorderSizePixel = 0
				card.Text = ""
				Theme.AddCorner(card, 10)
				Theme.AddStroke(card, if selIdx then Theme.AccentGold else rarity.Color, if selIdx then 3 else 2)
				card.Parent = scroll

				Theme.MakeLabel("Emoji", info.Emoji, UDim2.fromScale(1, 0.42), UDim2.fromScale(0, 0.05), Theme.FontTitle, Theme.TextPrimary, card)
				Theme.MakeLabel("Name", info.DisplayName, UDim2.fromScale(0.92, 0.24), UDim2.fromScale(0.04, 0.48), Theme.FontTitle, rarity.Color, card)
				Theme.MakeLabel("Rarity", if selIdx then `SELECTED #{selIdx}` else info.Rarity, UDim2.fromScale(0.92, 0.20), UDim2.fromScale(0.04, 0.74), Theme.FontBody, if selIdx then Theme.AccentGold else Theme.TextMuted, card)

				card.Activated:Connect(function()
					SoundController.Play("UiClick")
					local existing = isSelected(item.Uid)
					if existing then
						table.remove(selectedUids, existing)
					else
						if #selectedUids >= FusionData.FuseCount then
							return
						end
						if chosenRarity and info.Rarity ~= chosenRarity then
							Toasts.Show(`Pick another {chosenRarity} pet!`, Theme.AccentRed)
							return
						end
						table.insert(selectedUids, item.Uid)
					end
					rebuild()
				end)
			end
		end

		if chosenRarity then
			local rule = FusionData.GetRule(chosenRarity)
			if rule then
				local pct = math.floor(rule.SuccessChance * 100 + 0.5)
				infoLabel.Text = `{chosenRarity} ➔ {rule.NextRarity}  |  Chance: {pct}%  |  Cost: $${NumberFormat.Short(rule.Cost)}`
				fuseBtn.Text = if #selectedUids == FusionData.FuseCount
					then `⚗️ FUSE ($${NumberFormat.Short(rule.Cost)})`
					else `Selected {#selectedUids}/{FusionData.FuseCount}`
			end
		else
			infoLabel.Text = "Pick 3 unequipped pets of the SAME rarity to fuse!"
			fuseBtn.Text = `Selected {#selectedUids}/{FusionData.FuseCount}`
		end
	end

	rebuildFn = rebuild
	InventoryPanel.OnInventoryChanged(function()
		if modalFrame.Visible then
			rebuild()
		end
	end)

	-- Hook FusionMachine ProximityPrompts on plots
	local function setupMachine(inst: Instance)
		if not inst:IsA("BasePart") then
			return
		end
		if inst:FindFirstChildOfClass("ProximityPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open Fusion"
		prompt.ObjectText = "⚗️ Fusion Machine"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(triggerPlayer: Player)
			if triggerPlayer == player then
				onOpenRequest()
			end
		end)
		prompt.Parent = inst
	end

	for _, inst in CollectionService:GetTagged("FusionMachine") do
		task.spawn(setupMachine, inst)
	end
	CollectionService:GetInstanceAddedSignal("FusionMachine"):Connect(setupMachine)
end

return FusionPanel
