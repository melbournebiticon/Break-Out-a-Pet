--!strict
-- BaseService.luau (SERVER)
-- Spawns the player's active Placed Pets across designated, non-overlapping Habitat Spots on their safe plot,
-- detects active "Barkada Combo" synergies (+25% plot income & celebratory aura particles),
-- and attaches proximity-culled PetInfo labels that respect the client "Hide Pet Labels" toggle.

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
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))

local BaseService = {}

local PetModelRenderedEvent = Instance.new("BindableEvent")
BaseService.PetModelRendered = PetModelRenderedEvent.Event

-- 25 Designated, Well-Spaced Habitat Spots across the 60x60 Plot Courtyard (leaves front entrance & back Kubo clear!)
local HABITAT_OFFSETS: { Vector3 } = {
	-- Inner Courtyard Ring (Slots 1..8)
	Vector3.new(-12.5, 2.1, -12.0),
	Vector3.new(0.0, 2.1, -12.0),
	Vector3.new(12.5, 2.1, -12.0),
	Vector3.new(-12.5, 2.1, 0.0),
	Vector3.new(0.0, 2.1, 0.0),
	Vector3.new(12.5, 2.1, 0.0),
	Vector3.new(-12.5, 2.1, 11.5),
	Vector3.new(0.0, 2.1, 11.5),
	-- Outer Courtyard Habitat Ring (Slots 9..25)
	Vector3.new(-22.5, 2.1, -16.0),
	Vector3.new(-6.5, 2.1, -21.0),
	Vector3.new(6.5, 2.1, -21.0),
	Vector3.new(21.5, 2.1, -16.0),
	Vector3.new(-22.5, 2.1, -5.0),
	Vector3.new(22.5, 2.1, -5.0),
	Vector3.new(-22.5, 2.1, 6.0),
	Vector3.new(22.5, 2.1, 6.0),
	Vector3.new(-22.5, 2.1, 17.5),
	Vector3.new(-11.0, 2.1, 21.0),
	Vector3.new(0.0, 2.1, 21.0),
	Vector3.new(11.0, 2.1, 11.5),
	Vector3.new(-6.5, 2.1, -6.0),
	Vector3.new(6.5, 2.1, -6.0),
	Vector3.new(-6.5, 2.1, 6.0),
	Vector3.new(6.5, 2.1, 6.0),
	Vector3.new(-17.5, 2.1, 11.5),
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

local function getHabitatsFolder(plot: Model): Folder
	local existing = plot:FindFirstChild("HabitatPads")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "HabitatPads"
	folder.Parent = plot
	return folder
end

local function attachBarkadaComboAura(primary: BasePart)
	local att = Instance.new("Attachment")
	att.Name = "BarkadaAuraAtt"
	att.Position = Vector3.new(0, 0.5, 0)
	att.Parent = primary

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "BarkadaComboAura"
	emitter.Color = ColorSequence.new(
		Color3.fromRGB(255, 225, 75),
		Color3.fromRGB(85, 255, 145)
	)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.6, 0.32),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.8, 1.3)
	emitter.Rate = 7
	emitter.Speed = NumberRange.new(1.8, 3.4)
	emitter.SpreadAngle = Vector2.new(180, 45)
	emitter.LightEmission = 0.85
	emitter.Parent = att
end

local function buildHabitatPad(slotIdx: number, floorY: number, spawnPos: Vector3, rarityColor: Color3, isComboMember: boolean, folder: Folder)
	local pad = Instance.new("Part")
	pad.Name = `HabitatPad_{slotIdx}`
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(0.16, 4.6, 4.6)
	pad.CFrame = CFrame.new(spawnPos.X, floorY + 0.55, spawnPos.Z) * CFrame.Angles(0, 0, math.rad(90))
	pad.Anchored = true
	pad.CanCollide = false
	pad.CanTouch = false
	pad.CanQuery = false
	pad.Color = if isComboMember then Color3.fromRGB(255, 215, 55) else rarityColor
	pad.Material = if isComboMember then Enum.Material.Neon else Enum.Material.WoodPlanks
	pad.Transparency = if isComboMember then 0.35 else 0.45
	pad.Parent = folder
end

local function buildPetModel(
	owned: InventoryService.OwnedPet,
	spawnPos: Vector3,
	isComboMember: boolean,
	isBusog: boolean,
	petsFolder: Folder
): Model?
	local info = PetData.Get(owned.PetId)
	if not info then
		return nil
	end
	local rarity = Rarities.Get(info.Rarity)
	local mutInfo = MutationData.Get(owned.Mutation)
	local mutMult = MutationData.GetMultiplier(owned.Mutation)
	local income = info.IncomePerSec * mutMult

	local petScaleOverride = if typeof(owned.Scale) == "number" and owned.Scale > 0
		then owned.Scale
		else MutationData.GetScale(owned.Mutation, info.Scale)
	local centerCF = CFrame.new(spawnPos)
	local model = PetVisuals.BuildModel(owned.PetId, owned.Mutation, centerCF, petScaleOverride)
	local petScaleAttr = model:GetAttribute("PetScale")
	local petScale = if typeof(petScaleAttr) == "number" and petScaleAttr > 0 then petScaleAttr else petScaleOverride
	if petScale > 1 then
		model:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 1.1 * (petScale - 1), 0)))
	end

	model.Name = `PetModel_{owned.Uid}`
	model:SetAttribute("Uid", owned.Uid)
	model:SetAttribute("PetId", owned.PetId)
	model:SetAttribute("IncomePerSec", income)
	model:SetAttribute("HabitatHomePos", spawnPos)
	model:SetAttribute("IsBarkadaMember", isComboMember)

	local primary = model.PrimaryPart
	if primary then
		if isComboMember then
			attachBarkadaComboAura(primary)
		end

		-- Compact, proximity-based PetInfo label (MaxDistance capped at 28 studs so giant pets never clutter the screen!)
		local guiScale = math.clamp(petScale, 1.0, 1.85)
		local gui = Instance.new("BillboardGui")
		gui.Name = "PetInfo"
		gui.Size = UDim2.fromScale(3.2 * guiScale, 1.25 * guiScale)
		gui.StudsOffset = Vector3.new(0, 2.1 * petScale, 0)
		gui.MaxDistance = 28
		gui.AlwaysOnTop = false
		gui.Adornee = primary

		local prefix = if mutInfo then `[{mutInfo.Name}] ` else ""
		local comboTag = if isComboMember then "🤝 " else ""
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0.5, 0)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = if mutInfo then mutInfo.Color else rarity.Color
		title.TextStrokeTransparency = 0.1
		title.Text = `{comboTag}{prefix}{info.DisplayName}`
		title.Parent = gui

		local busogTag = if isBusog then " 🍡" else ""
		local rateLabel = Instance.new("TextLabel")
		rateLabel.Name = "Rate"
		rateLabel.Position = UDim2.fromScale(0, 0.5)
		rateLabel.Size = UDim2.new(1, 0, 0.5, 0)
		rateLabel.BackgroundTransparency = 1
		rateLabel.Font = Enum.Font.FredokaOne
		rateLabel.TextScaled = true
		rateLabel.TextColor3 = Color3.fromRGB(75, 255, 110)
		rateLabel.TextStrokeTransparency = 0.05
		rateLabel.Text = `+${NumberFormat.Short(income)}/s{busogTag}`
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
	local padsFolder = plot:FindFirstChild("HabitatPads")
	if padsFolder then
		padsFolder:ClearAllChildren()
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

	local placedPets = InventoryService.GetPlaced(player)
	local placedIds: { string } = {}
	for _, owned in placedPets do
		if not owned.InTransit then
			table.insert(placedIds, owned.PetId)
		end
	end

	-- Evaluate thematic Pinoy "Barkada Combo" Synergy!
	local hasCombo, comboTitles, comboMembers = PetData.EvaluateBarkadaCombos(placedIds)
	local comboStr = table.concat(comboTitles, " & ")
	player:SetAttribute("BarkadaComboActive", hasCombo)
	player:SetAttribute("BarkadaComboTitle", comboStr)

	local busogUntilAttr = player:GetAttribute("PetBusogUntil")
	local isBusog = typeof(busogUntilAttr) == "number" and busogUntilAttr > workspace:GetServerTimeNow()

	local petsFolder = getPetsFolder(plot)
	petsFolder:ClearAllChildren()
	local padsFolder = getHabitatsFolder(plot)
	padsFolder:ClearAllChildren()

	for idx, owned in placedPets do
		if not owned.InTransit then
			local slotIdx = owned.SlotIndex or idx
			local offset = HABITAT_OFFSETS[((slotIdx - 1) % #HABITAT_OFFSETS) + 1]
			local spawnPos = floor.Position + offset
			local isMember = comboMembers[owned.PetId] == true
			local pInfo = PetData.Get(owned.PetId)
			local rColor = if pInfo then Rarities.Get(pInfo.Rarity).Color else Color3.fromRGB(180, 180, 180)

			buildHabitatPad(slotIdx, floor.Position.Y, spawnPos, rColor, isMember, padsFolder)
			local model = buildPetModel(owned, spawnPos, isMember, isBusog, petsFolder)
			if model then
				PetModelRenderedEvent:Fire(player, plot, owned, model)
			end
		end
	end

	EconomyService.GetIncomePerSec(player)
	PlotService.UpdatePlotArchitecture(player)
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
