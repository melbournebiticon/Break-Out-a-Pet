--!strict
-- BaseService.luau (SERVER)
-- Spawns the player's active Placed Pets (up to their PetSlots limit) directly on their open grass plot
-- where they walk and roam freely across the plot!

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetData = require(Shared:WaitForChild("PetData"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local MutationData = require(Shared:WaitForChild("MutationData"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local PetVisuals = require(Shared:WaitForChild("PetVisuals"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local BaseService = {}

local PetModelRenderedEvent = Instance.new("BindableEvent")
BaseService.PetModelRendered = PetModelRenderedEvent.Event

local SPAWN_OFFSETS: { Vector3 } = {
	Vector3.new(-10, 2.1, -6),
	Vector3.new(0, 2.1, -6),
	Vector3.new(10, 2.1, -6),
	Vector3.new(-10, 2.1, 4),
	Vector3.new(0, 2.1, 4),
	Vector3.new(10, 2.1, 4),
	Vector3.new(-8, 2.1, 11),
	Vector3.new(8, 2.1, 11),
}

local function getPetsFolder(plot: Model): Folder
	local existing = plot:FindFirstChild("Pets")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = plot
	return folder
end

local function buildPetModel(owned: InventoryService.OwnedPet, spawnPos: Vector3, petsFolder: Folder): Model?
	local info = PetData.Get(owned.PetId)
	if not info then
		return nil
	end
	local rarity = Rarities.Get(info.Rarity)
	local mutInfo = MutationData.Get(owned.Mutation)
	local mutMult = MutationData.GetMultiplier(owned.Mutation)
	local income = info.IncomePerSec * mutMult

	local centerCF = CFrame.new(spawnPos)
	local model = PetVisuals.BuildModel(owned.PetId, owned.Mutation, centerCF)
	model.Name = `PetModel_{owned.Uid}`
	model:SetAttribute("Uid", owned.Uid)
	model:SetAttribute("PetId", owned.PetId)
	model:SetAttribute("IncomePerSec", income)

	local primary = model.PrimaryPart
	if primary then
		local gui = Instance.new("BillboardGui")
		gui.Name = "PetInfo"
		gui.Size = UDim2.fromScale(3.6, 1.35)
		gui.StudsOffset = Vector3.new(0, 2.3, 0)
		gui.MaxDistance = 38
		gui.AlwaysOnTop = false
		gui.Adornee = primary

		local prefix = if mutInfo then `[{mutInfo.Name}] ` else ""
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0.5, 0)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = if mutInfo then mutInfo.Color else rarity.Color
		title.TextStrokeTransparency = 0.1
		title.Text = `{prefix}{info.DisplayName}`
		title.Parent = gui

		local rateLabel = Instance.new("TextLabel")
		rateLabel.Position = UDim2.fromScale(0, 0.5)
		rateLabel.Size = UDim2.new(1, 0, 0.5, 0)
		rateLabel.BackgroundTransparency = 1
		rateLabel.Font = Enum.Font.FredokaOne
		rateLabel.TextScaled = true
		rateLabel.TextColor3 = Color3.fromRGB(75, 255, 110)
		rateLabel.TextStrokeTransparency = 0.05
		rateLabel.Text = if owned.InTransit then "⚠️ STOLEN!" else `+${NumberFormat.Short(income)}/s`
		rateLabel.Parent = gui

		gui.Parent = primary
	end

	model.Parent = petsFolder
	return model
end

function BaseService.ClearPlot(plot: Model)
	local petsFolder = plot:FindFirstChild("Pets")
	if petsFolder then
		petsFolder:ClearAllChildren()
	end
end

function BaseService.Refresh(player: Player)
	if not DataService.IsLoaded(player) then
		return
	end
	local plot = PlotService.GetPlot(player)
	if not plot then
		return
	end
	local floor = plot:FindFirstChild("Floor")
	if not floor or not floor:IsA("BasePart") then
		return
	end

	local petsFolder = getPetsFolder(plot)
	petsFolder:ClearAllChildren()

	for idx, owned in InventoryService.GetPlaced(player) do
		if not owned.InTransit then
			local slotIdx = owned.SlotIndex or idx
			local offset = SPAWN_OFFSETS[((slotIdx - 1) % #SPAWN_OFFSETS) + 1]
			local spawnPos = floor.Position + offset
			local model = buildPetModel(owned, spawnPos, petsFolder)
			if model then
				PetModelRenderedEvent:Fire(player, plot, owned, model)
			end
		end
	end
end

function BaseService.Init()
	InventoryService.PetsChanged:Connect(function(player: Player)
		BaseService.Refresh(player)
	end)

	PlotService.PlotClaimed:Connect(function(player: Player)
		BaseService.Refresh(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local plot = PlotService.GetPlot(player)
		if plot then
			BaseService.ClearPlot(plot)
		end
	end)
end

return BaseService
