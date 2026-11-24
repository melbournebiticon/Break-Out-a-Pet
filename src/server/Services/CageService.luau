--!strict
-- CageService.luau (SERVER)
-- Full Free-Plot Cage Placement & Unlocking System:
-- 1) Steal a Mystery Cage from the Prison (slows player while inside prison).
-- 2) Cross the Safe Zone Line (Z > Config.SafeZoneZ): cage is AUTOMATICALLY SECURED (guards stop chasing, normal speed).
-- 3) Walk anywhere onto your own Plot grass and press E ("Place Cage Here"): places the cage right where you stand on your plot!
-- 4) After the Unlocking countdown timer finishes, press E ("Open Cage") on the cage -> Pet goes into your Bag (Pets)!

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PetData = require(Shared:WaitForChild("PetData"))
local Rarities = require(Shared:WaitForChild("Rarities"))
local CageLoot = require(Shared:WaitForChild("CageLoot"))
local MutationData = require(Shared:WaitForChild("MutationData"))
local CageVisuals = require(Shared:WaitForChild("CageVisuals"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RateLimiter = require(Shared:WaitForChild("RateLimiter"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local StatsService = require(script.Parent:WaitForChild("StatsService"))
local ClientSyncService = require(script.Parent:WaitForChild("ClientSyncService"))

type Carry = {
	Cage: Model,
	PetId: string,
	Mutation: string?,
	CageStyle: string?,
	Secured: boolean,
	Template: Model?,
	Parent: Instance?,
}

type PlotUnlockCage = {
	Id: string,
	Position: Vector3,
	PetId: string,
	Mutation: string?,
	UnlockAt: number,
	Ready: boolean,
	Model: Model,
	StatusLabel: TextLabel,
}

local CageService = {}

local CagePickedUpEvent = Instance.new("BindableEvent")
local CageDeliveredEvent = Instance.new("BindableEvent")
CageService.CagePickedUp = CagePickedUpEvent.Event
CageService.CageDelivered = CageDeliveredEvent.Event

local carrying: { [Player]: Carry } = {}
local plotUnlockCages: { [Player]: { [string]: PlotUnlockCage } } = {}
local setupDone: { [Instance]: boolean } = {}
local catchInterceptor: ((Player) -> boolean)? = nil
local externalCarryCheck: ((Player) -> boolean)? = nil

function CageService.SetCatchInterceptor(fn: (Player) -> boolean)
	catchInterceptor = fn
end

function CageService.SetExternalCarryCheck(fn: (Player) -> boolean)
	externalCarryCheck = fn
end

-- Helpers -------------------------------------------------------------------

local function setCarryingState(player: Player, carryData: Carry?, zoneName: string?)
	carrying[player] = carryData
	player:SetAttribute("IsCarryingCage", carryData ~= nil)
	player:SetAttribute("CageSecured", if carryData then carryData.Secured else false)
	player:SetAttribute("CarriedCageZone", if carryData then (zoneName or player:GetAttribute("CarriedCageZone") or "") else "")
end

local function getHumanoidAndRoot(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

local function scheduleRespawn(template: Model?, parent: Instance?, delaySeconds: number)
	if not template or not parent then
		return
	end
	task.delay(delaySeconds, function()
		if parent.Parent == nil then
			return
		end
		template:Clone().Parent = parent
	end)
end

function CageService.AddRevealLabel(cage: Model, pet: PetData.Pet, mutation: string?)
	local primary = cage.PrimaryPart
	if not primary then
		return
	end
	local rarity = Rarities.Get(pet.Rarity)
	local mutInfo = MutationData.Get(mutation)

	local gui = Instance.new("BillboardGui")
	gui.Name = "PetReveal"
	gui.Size = UDim2.fromScale(4.2, 1.1)
	gui.StudsOffset = Vector3.new(0, 3.6, 0)
	gui.MaxDistance = 42
	gui.AlwaysOnTop = false
	gui.Adornee = primary
	gui:SetAttribute("Rarity", pet.Rarity)

	local prefix = if mutInfo then `{mutInfo.Name} ` else ""
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = if mutInfo then mutInfo.Color else rarity.Color
	label.TextStrokeTransparency = 0
	label.Text = `🔒 {pet.Rarity} Cage ({prefix}{pet.DisplayName})`
	label.Parent = gui

	gui.Parent = primary
end

function CageService.AttachModelToPlayer(model: Model, root: BasePart)
	local primary = model.PrimaryPart
	if not primary then
		return
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end

	model:PivotTo(root.CFrame * CFrame.new(0, Config.CarryHeight, 0))

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= primary then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primary
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	local carryWeld = Instance.new("WeldConstraint")
	carryWeld.Part0 = root
	carryWeld.Part1 = primary
	carryWeld.Parent = primary
end

-- Public API ----------------------------------------------------------------

function CageService.IsCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

function CageService.IsSecured(player: Player): boolean
	local carry = carrying[player]
	return if carry then carry.Secured else false
end

function CageService.GetCarriedPetId(player: Player): string?
	local carry = carrying[player]
	return if carry then carry.PetId else nil
end

function CageService.GetCarriedCage(player: Player): Model?
	local carry = carrying[player]
	return if carry then carry.Cage else nil
end

function CageService.GetCarryMultiplier(player: Player): number
	local carry = carrying[player]
	if not carry or carry.Secured then
		return 1
	end
	local pet = PetData.Get(carry.PetId)
	if not pet then
		return 1
	end
	return Rarities.Get(pet.Rarity).CarrySpeedMultiplier
end

function CageService.DropCage(player: Player, reason: string?, catcherName: string?): boolean
	local carry = carrying[player]
	if not carry then
		return false
	end

	if reason == "caught" and carry.Secured then
		return false
	end

	if reason == "caught" and catchInterceptor and catchInterceptor(player) then
		return false
	end

	setCarryingState(player, nil, "")
	carry.Cage:Destroy()
	StatsService.Refresh(player)
	scheduleRespawn(carry.Template, carry.Parent, Config.DroppedCageReturnSeconds)

	if reason == "caught" then
		local bantayTitle = if typeof(catcherName) == "string" and catcherName ~= "" then catcherName else "BANTAY"
		ClientSyncService.Notify(player, `🚨 Nahuli ka ng {bantayTitle}! Bumalik ang cage sa Zone.`, Color3.fromRGB(255, 80, 80))
	end
	return true
end

-- Drops a player's carried cage onto the ground right where they stand so anyone can steal/claim it!
function CageService.DropCageToGround(player: Player): boolean
	local carry = carrying[player]
	if not carry then
		return false
	end

	local _, root = getHumanoidAndRoot(player)
	local dropPos = if root then (root.Position + Vector3.new(0, 0.5, 0)) else Vector3.new(0, 3, -30)

	setCarryingState(player, nil)
	StatsService.Refresh(player)

	local droppedCage = carry.Cage
	local primary = droppedCage.PrimaryPart
	if not primary then
		droppedCage:Destroy()
		scheduleRespawn(carry.Template, carry.Parent, Config.DroppedCageReturnSeconds)
		return true
	end

	-- Remove player carry welds and anchor the cage on the ground
	for _, desc in droppedCage:GetDescendants() do
		if desc:IsA("WeldConstraint") and (desc.Part0 == root or desc.Part1 == root) then
			desc:Destroy()
		elseif desc:IsA("BasePart") then
			desc.Anchored = true
		end
	end

	droppedCage:PivotTo(CFrame.new(dropPos))
	droppedCage:SetAttribute("Taken", false)
	droppedCage.Parent = workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Steal Dropped Cage"
	prompt.ObjectText = "💥 Dropped Cage"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = primary

	local claimed = false
	prompt.Triggered:Connect(function(claimer: Player)
		if claimed or carrying[claimer] or not DataService.IsLoaded(claimer) then
			return
		end
		local cHum, cRoot = getHumanoidAndRoot(claimer)
		if not cHum or not cRoot or cHum.Health <= 0 then
			return
		end
		claimed = true
		prompt:Destroy()
		droppedCage:SetAttribute("Taken", true)
		CageService.AttachModelToPlayer(droppedCage, cRoot)

		local droppedZone = droppedCage:GetAttribute("Zone")
		setCarryingState(claimer, {
			Cage = droppedCage,
			PetId = carry.PetId,
			Mutation = carry.Mutation,
			CageStyle = carry.CageStyle,
			Secured = cRoot.Position.Z > Config.SafeZoneZ,
			Template = carry.Template,
			Parent = carry.Parent,
		}, if typeof(droppedZone) == "string" then droppedZone else nil)
		StatsService.Refresh(claimer)
		ClientSyncService.Notify(claimer, "🩴 Snatched the dropped cage!", Color3.fromRGB(100, 255, 130))
	end)

	-- Auto-return to prison if nobody claims it within 18 seconds
	task.delay(18, function()
		if not claimed and droppedCage.Parent == workspace then
			droppedCage:Destroy()
			scheduleRespawn(carry.Template, carry.Parent, 1)
		end
	end)

	ClientSyncService.Notify(player, "💥 PAK! Someone slapped the cage out of your hands!", Color3.fromRGB(255, 95, 95))
	return true
end

-- Plot Cage Free-Placement, Unlocking & Opening -----------------------------

local function buildPlotUnlockCageModel(worldPos: Vector3, pet: PetData.Pet, mutation: string?, cageStyle: string?, parent: Instance): (Model, TextLabel)
	local rarity = Rarities.Get(pet.Rarity)
	local mutInfo = MutationData.Get(mutation)
	local accent = if mutInfo then mutInfo.Color else rarity.Color

	local cage = Instance.new("Model")
	cage.Name = "UnlockingCage"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(4.6, 4.6, 4.6)
	body.Position = worldPos
	body.Transparency = 1
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.Parent = cage
	cage.PrimaryPart = body

	local style = if typeof(cageStyle) == "string" and cageStyle ~= ""
		then cageStyle
		else CageVisuals.PickStyleForPet(pet.Id, nil)
	CageVisuals.PopulateCageModel(cage, worldPos, style, accent)

	local gui = Instance.new("BillboardGui")
	gui.Name = "UnlockStatus"
	gui.Size = UDim2.fromScale(4.0, 1.45)
	gui.StudsOffset = Vector3.new(0, 3.1, 0)
	gui.MaxDistance = 42
	gui.AlwaysOnTop = false
	gui.Adornee = body

	local prefix = if mutInfo then `[{mutInfo.Name}] ` else ""
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.48, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = accent
	title.TextStrokeTransparency = 0.05
	title.Text = `{pet.Emoji} {prefix}{pet.DisplayName}`
	title.Parent = gui

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Timer"
	statusLabel.Position = UDim2.fromScale(0, 0.50)
	statusLabel.Size = UDim2.new(1, 0, 0.50, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.FredokaOne
	statusLabel.TextScaled = true
	statusLabel.TextColor3 = Color3.fromRGB(255, 215, 70)
	statusLabel.TextStrokeTransparency = 0.05
	statusLabel.Text = "⏳ Unlocking..."
	statusLabel.Parent = gui

	gui.Parent = body
	cage.Parent = parent
	return cage, statusLabel
end

local function syncPlayerUnlockCages(player: Player)
	local bucket = plotUnlockCages[player]
	local list = {}
	local now = os.clock()
	if bucket then
		for cageId, entry in bucket do
			table.insert(list, {
				Id = cageId,
				PetId = entry.PetId,
				Mutation = entry.Mutation,
				Remaining = math.max(0, math.ceil(entry.UnlockAt - now)),
				Ready = entry.Ready,
			})
		end
	end
	table.sort(list, function(a, b)
		if a.Ready ~= b.Ready then
			return a.Ready
		end
		return a.Remaining < b.Remaining
	end)
	Remotes.GetEvent("SyncUnlockingCages"):FireClient(player, list)
end

local function openUnlockedPlotCage(player: Player, cageId: string)
	local bucket = plotUnlockCages[player]
	local entry = if bucket then bucket[cageId] else nil
	if not entry or not entry.Ready then
		return
	end

	bucket[cageId] = nil
	syncPlayerUnlockCages(player)

	local pet = PetData.Get(entry.PetId)
	if pet and entry.Model.PrimaryPart then
		local burstGui = Instance.new("BillboardGui")
		burstGui.Name = "PetReveal"
		burstGui.Adornee = entry.Model.PrimaryPart
		burstGui:SetAttribute("Rarity", pet.Rarity)
		burstGui.Parent = entry.Model.PrimaryPart
	end

	-- Fire 3D jump-to-player animation event before destroying the cage
	Remotes.GetEvent("CageOpenedAnim"):FireClient(player, entry.Position, entry.PetId, entry.Mutation)

	task.delay(0.12, function()
		if entry.Model.Parent then
			entry.Model:Destroy()
		end
	end)

	-- Add the unlocked pet directly to the player's Bag ("Stored")!
	InventoryService.AddPetToBag(player, entry.PetId, entry.Mutation)

	local profile = DataService.GetProfile(player)
	if profile then
		profile.TotalRescued += 1
		DataService.MarkDirty(player)
	end

	if pet then
		local rarity = Rarities.Get(pet.Rarity)
		local mutPrefix = if entry.Mutation then `{entry.Mutation} ` else ""
		ClientSyncService.Notify(
			player,
			`🎉 Opened {pet.Emoji} {mutPrefix}{pet.DisplayName}! Added to your Bag (Pets)!`,
			rarity.Color
		)
	end
end

local function findFreeSpotOnPlot(floor: BasePart, desiredPos: Vector3, existingBucket: { [string]: PlotUnlockCage }): Vector3?
	local halfX = floor.Size.X * 0.5 - 3.5
	local halfZ = floor.Size.Z * 0.5 - 3.5
	local y = floor.Position.Y + 2.6

	local function isSpotFree(candidate: Vector3): boolean
		for _, entry in existingBucket do
			local flat = Vector3.new(candidate.X - entry.Position.X, 0, candidate.Z - entry.Position.Z)
			if flat.Magnitude < Config.CageMinSpacingStuds then
				return false
			end
		end
		return true
	end

	-- 1) Try the exact position where the player is standing on their plot
	local clampedX = math.clamp(desiredPos.X - floor.Position.X, -halfX, halfX)
	local clampedZ = math.clamp(desiredPos.Z - floor.Position.Z, -halfZ, halfZ - 3)
	local directSpot = Vector3.new(floor.Position.X + clampedX, y, floor.Position.Z + clampedZ)
	if isSpotFree(directSpot) then
		return directSpot
	end

	-- 2) Spiral search nearby on the plot if another cage is already right under the player's feet
	for radius = 5, 16, 4 do
		for step = 0, 7 do
			local ang = (step / 8) * math.pi * 2
			local cx = math.clamp(clampedX + math.cos(ang) * radius, -halfX, halfX)
			local cz = math.clamp(clampedZ + math.sin(ang) * radius, -halfZ, halfZ - 3)
			local candidate = Vector3.new(floor.Position.X + cx, y, floor.Position.Z + cz)
			if isSpotFree(candidate) then
				return candidate
			end
		end
	end

	return nil
end

local function tryPlaceCarriedCageOnPlot(player: Player, requestedPos: Vector3?)
	local carry = carrying[player]
	if not carry then
		return
	end

	local plot = PlotService.GetPlot(player)
	local floor = plot and plot:FindFirstChild("Floor")
	if not plot or not floor or not floor:IsA("BasePart") then
		return
	end

	local _, root = getHumanoidAndRoot(player)
	if not root then
		return
	end

	-- Check player is standing on or near their plot
	local dx = math.abs(root.Position.X - floor.Position.X)
	local dz = math.abs(root.Position.Z - floor.Position.Z)
	if dx > floor.Size.X * 0.5 + 10 or dz > floor.Size.Z * 0.5 + 10 then
		ClientSyncService.Notify(player, "Walk onto your own Plot grass first to place the cage!", Color3.fromRGB(255, 180, 60))
		return
	end

	local bucket = plotUnlockCages[player]
	if not bucket then
		bucket = {}
		plotUnlockCages[player] = bucket
	end

	local activeCount = 0
	for _ in bucket do
		activeCount += 1
	end
	if activeCount >= Config.MaxPlotUnlockingCages then
		ClientSyncService.Notify(player, "Your plot is full of cages! Open some unlocked cages first!", Color3.fromRGB(255, 180, 60))
		return
	end

	local desiredPos = if typeof(requestedPos) == "Vector3"
		then requestedPos
		else (root.Position + root.CFrame.LookVector * 4.5)
	local placePos = findFreeSpotOnPlot(floor, desiredPos, bucket)
	if not placePos then
		ClientSyncService.Notify(player, "No space right here on your plot! Move to an open spot.", Color3.fromRGB(255, 180, 60))
		return
	end

	local pet = PetData.Get(carry.PetId)
	if not pet then
		return
	end

	setCarryingState(player, nil)
	carry.Cage:Destroy()
	StatsService.Refresh(player)
	scheduleRespawn(carry.Template, carry.Parent, Config.CageRespawnSeconds)

	local unlockDuration = Config.CageUnlockSeconds[pet.Rarity] or 6
	local model, statusLabel = buildPlotUnlockCageModel(placePos, pet, carry.Mutation, carry.CageStyle, plot)
	local cageId = HttpService:GenerateGUID(false)

	local entry: PlotUnlockCage = {
		Id = cageId,
		Position = placePos,
		PetId = carry.PetId,
		Mutation = carry.Mutation,
		UnlockAt = os.clock() + unlockDuration,
		Ready = false,
		Model = model,
		StatusLabel = statusLabel,
	}
	bucket[cageId] = entry
	syncPlayerUnlockCages(player)

	ClientSyncService.Notify(player, `⏳ Cage placed on your plot! Unlocking in {unlockDuration}s...`, Color3.fromRGB(110, 215, 255))
	CageDeliveredEvent:Fire(player, carry.PetId)
end

-- Prison Cages --------------------------------------------------------------

local function onCageTriggered(cage: Model, prompt: ProximityPrompt, player: Player, template: Model?, parent: Instance?)
	if not DataService.IsLoaded(player) then
		return
	end
	if carrying[player] or (externalCarryCheck and externalCarryCheck(player)) or cage:GetAttribute("Taken") then
		return
	end

	local humanoid, root = getHumanoidAndRoot(player)
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local zone = cage:GetAttribute("Zone")
	if typeof(zone) ~= "string" then
		warn(`Cage "{cage.Name}" has no Zone attribute`)
		return
	end

	local lootTableAttr = cage:GetAttribute("LootTable")
	local profile = DataService.GetProfile(player)
	local tableToRoll: string = zone
	if typeof(lootTableAttr) == "string" and lootTableAttr ~= "" then
		tableToRoll = lootTableAttr
	elseif profile and profile.LuckyNextCage then
		profile.LuckyNextCage = false
		DataService.MarkDirty(player)
		tableToRoll = "Lucky"
		ClientSyncService.Notify(player, "🍀 Lucky Cage boost activated!", Color3.fromRGB(255, 215, 50))
	end

	local ok, result = pcall(CageLoot.RollFromTable, tableToRoll)
	if not ok then
		warn(`CageLoot.RollFromTable failed for {tableToRoll}: {result}`)
		return
	end
	local petId: string = result
	local pet = PetData.Get(petId)
	if not pet then
		return
	end

	local mutation = MutationData.RollMutation()

	cage:SetAttribute("Taken", true)
	prompt:Destroy()
	CageService.AttachModelToPlayer(cage, root)
	CageService.AddRevealLabel(cage, pet, mutation)

	local rawStyle = cage:GetAttribute("CageStyle")
	local cageStyle: string? = if typeof(rawStyle) == "string" then rawStyle else nil

	setCarryingState(player, {
		Cage = cage,
		PetId = petId,
		Mutation = mutation,
		CageStyle = cageStyle,
		Secured = false,
		Template = template,
		Parent = parent,
	}, zone)

	StatsService.Refresh(player)
	CagePickedUpEvent:Fire(player, petId)
end

local function setupCage(instance: Instance)
	if setupDone[instance] then
		return
	end
	if not instance:IsA("Model") or not instance:IsDescendantOf(workspace) then
		return
	end

	local cage = instance
	local primary = cage.PrimaryPart
	local parent = cage.Parent
	if not primary or not parent then
		warn(`Cage "{cage.Name}" needs a PrimaryPart.`)
		return
	end

	setupDone[cage] = true
	cage.Destroying:Connect(function()
		setupDone[cage] = nil
	end)

	local isEventCage = cage:GetAttribute("IsEventCage") == true
	local template: Model? = if isEventCage then nil else cage:Clone()

	local prompt = Instance.new("ProximityPrompt")
	local lootTable = cage:GetAttribute("LootTable")
	prompt.ActionText = "Steal Cage"
	prompt.ObjectText = if lootTable == "Rainbow"
		then "🌈 Rainbow Cage"
		elseif lootTable == "Lucky" then "🍀 Lucky Cage"
		else "Mystery Cage"
	prompt.HoldDuration = Config.CagePromptHoldSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		onCageTriggered(cage, prompt, player, template, parent)
	end)
	prompt.Parent = primary
end

-- Players & Heartbeat (Safe Zone check + Unlocking Cage countdowns) ---------

local function watchPlayer(player: Player)
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				CageService.DropCage(player)
			end)
		end
	end

	player.CharacterAdded:Connect(onCharacter)
	player.CharacterRemoving:Connect(function()
		CageService.DropCage(player)
	end)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

function CageService.Init()
	StatsService.AddSpeedModifier("Carry", CageService.GetCarryMultiplier)
	Remotes.GetEvent("CageOpenedAnim")
	Remotes.GetEvent("SyncUnlockingCages")

	local remoteOpenEvent = Remotes.GetEvent("RemoteOpenPlotCage")
	remoteOpenEvent.OnServerEvent:Connect(function(player: Player, targetId: any)
		if not RateLimiter.Check(player, "RemoteOpenPlotCage", 0.15) then
			return
		end
		local bucket = plotUnlockCages[player]
		if not bucket then
			return
		end
		if targetId == "ALL" then
			local readyIds = {}
			for id, entry in bucket do
				if entry.Ready then
					table.insert(readyIds, id)
				end
			end
			for _, id in readyIds do
				openUnlockedPlotCage(player, id)
			end
		elseif typeof(targetId) == "string" then
			openUnlockedPlotCage(player, targetId)
		end
	end)

	local placeCageEvent = Remotes.GetEvent("PlaceCageOnPlot")
	placeCageEvent.OnServerEvent:Connect(function(player: Player, hitPos: any)
		if not RateLimiter.Check(player, "PlaceCageOnPlot", 0.25) then
			return
		end
		local validPos: Vector3? = if typeof(hitPos) == "Vector3" then hitPos else nil
		tryPlaceCarriedCageOnPlot(player, validPos)
	end)

	for _, instance in CollectionService:GetTagged("Cage") do
		task.spawn(setupCage, instance)
	end
	CollectionService:GetInstanceAddedSignal("Cage"):Connect(setupCage)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		CageService.DropCage(player)
		local bucket = plotUnlockCages[player]
		if bucket then
			for _, entry in bucket do
				if entry.Model.Parent then
					entry.Model:Destroy()
				end
			end
			plotUnlockCages[player] = nil
		end
	end)

	local lastTimerTick = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()

		for player, carry in carrying do
			if not carry.Secured then
				local _, root = getHumanoidAndRoot(player)
				if root and root.Position.Z > Config.SafeZoneZ then
					carry.Secured = true
					player:SetAttribute("CageSecured", true)
					StatsService.Refresh(player)
					ClientSyncService.Notify(
						player,
						"🛡️ SAFE ZONE! Click / Tap anywhere on your Plot to place the cage!",
						Color3.fromRGB(80, 255, 130)
					)
				end
			end
		end

		if now - lastTimerTick >= 0.25 then
			lastTimerTick = now
			for player, bucket in plotUnlockCages do
				local anyChanged = false
				for cageId, entry in bucket do
					if not entry.Ready then
						local rem = math.ceil(entry.UnlockAt - now)
						if rem > 0 then
							entry.StatusLabel.Text = `⏳ Unlocking... {rem}s`
						else
							entry.Ready = true
							anyChanged = true
							entry.StatusLabel.Text = "✨ READY! Press E to Open!"
							entry.StatusLabel.TextColor3 = Color3.fromRGB(80, 255, 120)

							local primary = entry.Model.PrimaryPart
							if primary then
								local prompt = Instance.new("ProximityPrompt")
								prompt.Name = "OpenCagePrompt"
								prompt.ActionText = "Open Cage"
								prompt.ObjectText = "✨ Unlocked Cage"
								prompt.HoldDuration = 0
								prompt.MaxActivationDistance = 11
								prompt.RequiresLineOfSight = false
								prompt.Triggered:Connect(function(triggerPlayer: Player)
									if triggerPlayer == player then
										openUnlockedPlotCage(player, cageId)
									end
								end)
								prompt.Parent = primary
							end
						end
					end
				end
				if anyChanged then
					syncPlayerUnlockCages(player)
				end
			end
		end
	end)
end

return CageService
