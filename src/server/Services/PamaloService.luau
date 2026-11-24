--!strict
-- PamaloService.luau (SERVER)
-- Manages the 5 Tatak Pinoy non-violent comedy slapstick Pamalo tools:
--   * Spawns the player's equipped Pamalo Tool (Tsinelas Spartan by default)
--   * Handles Tindahan ng Pamalo shop stand purchases & equips
--   * Handles Player-vs-Guard stun/knockback and Player-vs-Player cage drop + pet passive checks (Kalabaw, Bangus, Pawikan)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PamaloConfig = require(Shared:WaitForChild("PamaloConfig"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local StatsService = require(script.Parent:WaitForChild("StatsService"))
local CageService = require(script.Parent:WaitForChild("CageService"))
local EnemyService = require(script.Parent:WaitForChild("EnemyService"))
local StealService = require(script.Parent:WaitForChild("StealService"))
local ClientSyncService = require(script.Parent:WaitForChild("ClientSyncService"))

local PamaloService = {}

local lastSwingAt: { [Player]: number } = {}
local boostActiveUntil: { [Player]: number } = {}
local boostMultiplier: { [Player]: number } = {}
local bangusDodgeReadyAt: { [Player]: number } = {}
local pawikanShieldReadyAt: { [Player]: number } = {}
local kalabawFirstHitAt: { [Player]: number } = {}
local setupDone: { [Instance]: boolean } = {}

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

local function spawnComedyPopup(targetPart: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PakPopup"
	gui.Size = UDim2.fromScale(4.2, 1.4)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 55
	gui.AlwaysOnTop = true
	gui.Adornee = targetPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(15, 15, 20)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	gui.Parent = targetPart

	local snd = Instance.new("Sound")
	snd.SoundId = "rbxasset://sounds/snap.mp3"
	snd.PlaybackSpeed = 0.95
	snd.Volume = 0.9
	snd.Parent = targetPart
	snd:Play()

	task.delay(0.85, function()
		if gui.Parent then
			gui:Destroy()
		end
		if snd.Parent then
			snd:Destroy()
		end
	end)
end

-- Checks if the target player currently has the given petId either Equipped OR inside their carried cage.
local function playerHasActiveOrCarriedPet(player: Player, petId: string): boolean
	local equipped = InventoryService.GetEquipped(player)
	if equipped and equipped.PetId == petId then
		return true
	end
	if CageService.GetCarriedPetId(player) == petId then
		return true
	end
	return false
end

local function applyPlayerSlap(attacker: Player, target: Player, info: PamaloConfig.PamaloInfo, hitDir: Vector3): boolean
	local tHum, tRoot = getHumanoidAndRoot(target)
	if not tHum or not tRoot or tHum.Health <= 0 then
		return false
	end

	local now = os.clock()

	-- 1) Pawikan Guard Shield Check (60s cooldown)
	if playerHasActiveOrCarriedPet(target, "pawikan") then
		local readyAt = pawikanShieldReadyAt[target] or 0
		if now >= readyAt then
			pawikanShieldReadyAt[target] = now + 60
			spawnComedyPopup(tRoot, "🛡️ PAWIKAN SHIELD!", Color3.fromRGB(90, 235, 255))
			ClientSyncService.Notify(target, "🛡️ Your Pawikan blocked a Pamalo slap!", Color3.fromRGB(90, 235, 255))
			return true
		end
	end

	-- 2) Golden Bangus Dodge 1st Slap Check (15s cooldown)
	if playerHasActiveOrCarriedPet(target, "bangus") then
		local readyAt = bangusDodgeReadyAt[target] or 0
		if now >= readyAt then
			bangusDodgeReadyAt[target] = now + 15
			spawnComedyPopup(tRoot, "🐟 SLIPPERY!", Color3.fromRGB(255, 225, 70))
			ClientSyncService.Notify(target, "🐟 Golden Bangus slipped past a slap!", Color3.fromRGB(255, 225, 70))
			return true
		end
	end

	-- 3) Kalabaw Heavy Carry / Knockback Resist (60% less knockback + requires 2 hits within 4s to drop cage!)
	local hasKalabaw = playerHasActiveOrCarriedPet(target, "kalabaw")
	local kbForce = if hasKalabaw then (info.Knockback * 0.4) else info.Knockback
	local shouldDropCage = true

	if hasKalabaw and (CageService.IsCarrying(target) or StealService.IsCarryingStolen(target)) then
		local firstHit = kalabawFirstHitAt[target] or 0
		if (now - firstHit) > 4.0 then
			kalabawFirstHitAt[target] = now
			shouldDropCage = false
			spawnComedyPopup(tRoot, "🐃 MATIBAY! (1/2)", Color3.fromRGB(255, 195, 75))
		else
			kalabawFirstHitAt[target] = 0
			shouldDropCage = true
		end
	end

	if shouldDropCage then
		spawnComedyPopup(tRoot, `💥 PAK! ({info.Emoji})`, Color3.fromRGB(255, 215, 45))
		if CageService.IsCarrying(target) then
			CageService.DropCageToGround(target)
		elseif StealService.IsCarryingStolen(target) then
			StealService.DropStolenPet(target, "caught")
		end
	end

	-- Apply comedy horizontal knockback + face-down ("nakataob") knockdown!
	local knockSeconds = math.max(1.0, info.RagdollSeconds)
	tHum.PlatformStand = true
	tRoot.CFrame = CFrame.new(tRoot.Position + Vector3.new(0, 0.5, 0), tRoot.Position + Vector3.new(0, 0.5, 0) + hitDir)
		* CFrame.Angles(math.rad(-85), 0, 0)
	tRoot.AssemblyLinearVelocity = hitDir * kbForce + Vector3.new(0, 14, 0)

	task.delay(knockSeconds, function()
		if tHum.Parent and tRoot.Parent then
			tHum.PlatformStand = false
			tRoot.CFrame = CFrame.new(tRoot.Position + Vector3.new(0, 2.5, 0))
		end
	end)

	return true
end

local function onPamaloSwung(player: Player, tool: Tool, info: PamaloConfig.PamaloInfo)
	local now = os.clock()
	local prev = lastSwingAt[player] or 0
	if (now - prev) < info.Cooldown then
		return
	end
	lastSwingAt[player] = now

	local hum, root = getHumanoidAndRoot(player)
	if not hum or not root or hum.Health <= 0 then
		return
	end

	-- Trigger Roblox's native arm slash animation + smooth 3-stage slap arc + visual slash wave!
	local animTag = Instance.new("StringValue")
	animTag.Name = "toolanim"
	animTag.Value = "Slash"
	animTag.Parent = tool

	local handle = tool:FindFirstChild("Handle")
	local trail: Trail? = nil
	if handle and handle:IsA("BasePart") then
		trail = handle:FindFirstChild("SwingTrail") :: Trail?
		if trail then
			trail.Enabled = true
		end
		local whoosh = Instance.new("Sound")
		whoosh.SoundId = "rbxasset://sounds/swordslash.wav"
		whoosh.PlaybackSpeed = 1.25
		whoosh.Volume = 0.65
		whoosh.Parent = handle
		whoosh:Play()
		task.delay(0.5, function()
			if whoosh.Parent then
				whoosh:Destroy()
			end
		end)
	end

	-- Spawn a quick visible curved slap arc in front of the player
	local slashWave = Instance.new("Part")
	slashWave.Name = "PamaloSlashArc"
	slashWave.Size = Vector3.new(if info.IsAoE then 6.5 else 4.2, 0.25, 2.4)
	slashWave.CFrame = root.CFrame * CFrame.new(0, 0.4, -3.2) * CFrame.Angles(0, 0, math.rad(-18))
	slashWave.Color = if info.Id == "gintong_tsinelas" then Color3.fromRGB(255, 215, 55) else Color3.fromRGB(235, 248, 255)
	slashWave.Material = Enum.Material.Neon
	slashWave.Transparency = 0.35
	slashWave.Anchored = true
	slashWave.CanCollide = false
	slashWave.CanTouch = false
	slashWave.CanQuery = false
	slashWave.Parent = workspace
	task.delay(0.14, function()
		if slashWave.Parent then
			slashWave:Destroy()
		end
	end)

	local baseGrip = CFrame.new(0, -0.65, 0)
	-- Stage 1: Quick wind-up back
	tool.Grip = baseGrip * CFrame.Angles(math.rad(35), math.rad(-25), math.rad(20))
	task.delay(0.05, function()
		if tool.Parent then
			-- Stage 2: Fast diagonal slap forward & down
			tool.Grip = baseGrip * CFrame.Angles(math.rad(-95), math.rad(15), math.rad(-25))
		end
	end)
	task.delay(0.14, function()
		if tool.Parent then
			-- Stage 3: Follow-through sweep
			tool.Grip = baseGrip * CFrame.Angles(math.rad(-115), math.rad(35), math.rad(-35))
		end
	end)
	task.delay(0.26, function()
		if trail then
			trail.Enabled = false
		end
		if tool.Parent then
			tool.Grip = baseGrip
		end
	end)

	local attackerPos = root.Position
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local unitLook = if flatLook.Magnitude > 0.01 then flatLook.Unit else Vector3.new(0, 0, -1)

	-- Strictly disabled inside the Safe Zone (Z > Config.SafeZoneZ)!
	if attackerPos.Z > Config.SafeZoneZ then
		return
	end

	local landedHit = false

	-- Player vs. Other Players ONLY (only inside the danger zones, Z <= Config.SafeZoneZ)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local _, oRoot = getHumanoidAndRoot(other)
			if oRoot and oRoot.Position.Z <= Config.SafeZoneZ then
				local delta = oRoot.Position - attackerPos
				local flatDelta = Vector3.new(delta.X, 0, delta.Z)
				local dist = flatDelta.Magnitude
				if dist <= info.Reach + 1.5 then
					local dir = if dist > 0.05 then flatDelta.Unit else unitLook
					local dot = dir:Dot(unitLook)
					if dist <= 3.5 or dot >= (if info.IsAoE then 0.15 else 0.35) then
						if applyPlayerSlap(player, other, info, dir) then
							landedHit = true
							if not info.IsAoE then
								break
							end
						end
					end
				end
			end
		end
	end

	-- 3) Gintong Tsinelas Speed Boost on Hit
	if landedHit and info.SpeedBoostSeconds > 0 and info.SpeedBoostMult > 1 then
		boostActiveUntil[player] = os.clock() + info.SpeedBoostSeconds
		boostMultiplier[player] = info.SpeedBoostMult
		StatsService.Refresh(player)
		task.delay(info.SpeedBoostSeconds, function()
			if player.Parent then
				StatsService.Refresh(player)
			end
		end)
	end
end

local function giveEquippedPamaloTool(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile or not player.Parent then
		return
	end

	local toolId = profile.EquippedPamalo
	local info = PamaloConfig.Get(toolId) or PamaloConfig.Get("tsinelas_spartan")
	if not info then
		return
	end

	-- Clear existing Pamalo tools from Backpack & Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("IsPamalo") == true then
				child:Destroy()
			end
		end
	end
	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("IsPamalo") == true then
				child:Destroy()
			end
		end
	end

	local tool = Instance.new("Tool")
	tool.Name = `{info.Emoji} {info.DisplayName}`
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("IsPamalo", true)
	tool:SetAttribute("PamaloId", info.Id)

	PamaloConfig.BuildToolParts(info.Id, CFrame.new(), tool, false)
	tool.Grip = CFrame.new(0, -0.65, 0)

	tool.Activated:Connect(function()
		onPamaloSwung(player, tool, info)
	end)

	if backpack then
		tool.Parent = backpack
	end
end

local function onStandPromptTriggered(player: Player, toolId: string)
	local profile = DataService.GetProfile(player)
	local info = PamaloConfig.Get(toolId)
	if not profile or not info then
		return
	end

	if profile.OwnedPamalos[toolId] then
		profile.EquippedPamalo = toolId
		DataService.MarkDirty(player)
		giveEquippedPamaloTool(player)
		ClientSyncService.Notify(player, `{info.Emoji} Equipped {info.DisplayName}!`, Color3.fromRGB(100, 255, 130))
		return
	end

	if not EconomyService.TrySpend(player, info.Cost) then
		ClientSyncService.Notify(
			player,
			`Need $${NumberFormat.Short(info.Cost)} to buy {info.Emoji} {info.DisplayName}!`,
			Color3.fromRGB(255, 95, 95)
		)
		return
	end

	profile.OwnedPamalos[toolId] = true
	profile.EquippedPamalo = toolId
	DataService.MarkDirty(player)
	giveEquippedPamaloTool(player)
	ClientSyncService.Notify(
		player,
		`🎉 Purchased & Equipped {info.Emoji} {info.DisplayName}! Check your Backpack!`,
		Color3.fromRGB(255, 215, 55)
	)
end

local function setupPamaloDisplay(instance: Instance)
	if setupDone[instance] then
		return
	end
	if not instance:IsA("BasePart") or not instance:IsDescendantOf(workspace) then
		return
	end

	local toolId = instance:GetAttribute("PamaloId")
	if typeof(toolId) ~= "string" then
		return
	end
	local info = PamaloConfig.Get(toolId)
	if not info then
		return
	end

	setupDone[instance] = true
	instance.Destroying:Connect(function()
		setupDone[instance] = nil
	end)

	local priceText = if info.Cost == 0 then "FREE" else `$${NumberFormat.Short(info.Cost)}`
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `Buy / Equip ({priceText})`
	prompt.ObjectText = `{info.Emoji} {info.DisplayName}`
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		onStandPromptTriggered(player, toolId)
	end)
	prompt.Parent = instance
end

local function watchPlayer(player: Player)
	local profile = DataService.WaitForProfile(player)
	if not profile or not player.Parent then
		return
	end

	player.CharacterAdded:Connect(function()
		task.delay(0.4, function()
			if player.Parent then
				giveEquippedPamaloTool(player)
			end
		end)
	end)

	if player.Character then
		task.delay(0.4, function()
			if player.Parent then
				giveEquippedPamaloTool(player)
			end
		end)
	end
end

function PamaloService.Init()
	StatsService.AddSpeedModifier("PamaloBoost", function(player: Player): number
		local untilTime = boostActiveUntil[player]
		if untilTime and os.clock() < untilTime then
			return boostMultiplier[player] or 1
		end
		return 1
	end)

	for _, instance in CollectionService:GetTagged("PamaloDisplay") do
		task.spawn(setupPamaloDisplay, instance)
	end
	CollectionService:GetInstanceAddedSignal("PamaloDisplay"):Connect(setupPamaloDisplay)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(watchPlayer, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(watchPlayer, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastSwingAt[player] = nil
		boostActiveUntil[player] = nil
		boostMultiplier[player] = nil
		bangusDodgeReadyAt[player] = nil
		pawikanShieldReadyAt[player] = nil
		kalabawFirstHitAt[player] = nil
	end)
end

return PamaloService
