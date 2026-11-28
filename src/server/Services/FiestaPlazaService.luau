--!strict
-- FiestaPlazaService.luau (SERVER)
-- Runs interactive Tatak Pinoy Fiesta Minigames & Post-Fiesta Boodle Fight in the Safe Zone Fiesta Event Plaza:
-- 1) 🏺 HAMPAS PALAYOK RUSH (Pamalo-driven giant clay piñata boss with swinging mud shockwaves & Fiesta-mutated pet drops!)
-- 2) 🐖 AGAWAN BIIK HOUR (Greased golden piglet chase leaving slippery oil puddles + Pamalo tag scoring & rival slap-slip!)
-- 3) 🎋 FIESTA PABITIN & 🎲 PERYA COLOR GAME
-- 4) 🍌 POST-FIESTA "BOODLE FIGHT" FEAST (30s banana-leaf feast table granting 10m "Busog & Swerte" +25% Pet Luck & +15% WalkSpeed!)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventData = require(Shared:WaitForChild("EventData"))
local PamaloConfig = require(Shared:WaitForChild("PamaloConfig"))
local PetData = require(Shared:WaitForChild("PetData"))
local PetVisuals = require(Shared:WaitForChild("PetVisuals"))
local MutationData = require(Shared:WaitForChild("MutationData"))
local ShopData = require(Shared:WaitForChild("ShopData"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))
local RateLimiter = require(Shared:WaitForChild("RateLimiter"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require(script.Parent:WaitForChild("DataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local StatsService = require(script.Parent:WaitForChild("StatsService"))
local ClientSyncService = require(script.Parent:WaitForChild("ClientSyncService"))

local FiestaPlazaService = {}

local rng = Random.new()
local BOOST_DURATION_SECONDS = 180 -- 3 minutes per Fiesta participation boost

type ActiveSessionInfo = {
	EventId: string,
	BannerTitle: string,
	BannerSubtitle: string,
	Center: Vector3,
}

local currentSession: ActiveSessionInfo? = nil
local seenCutsceneUsers: { [number]: boolean } = {}
local slipCooldownUntil: { [Player]: number } = {}

-- Active Pamalo-targetable state for Hampas Palayok & Agawan Biik
local activePalayokHandler: ((player: Player, dmg: number, info: PamaloConfig.PamaloInfo) -> boolean)? = nil
local activePalayokPosition: (() -> Vector3?)? = nil

local activeBiikHandler: ((player: Player, pts: number, info: PamaloConfig.PamaloInfo) -> boolean)? = nil
local activeBiikPosition: (() -> Vector3?)? = nil
local isAgawanBiikRunning = false

local function getPlazaCenter(): Vector3
	for _, inst in CollectionService:GetTagged("FiestaArenaCenter") do
		if inst:IsA("BasePart") then
			return inst.Position
		end
	end
	return Vector3.new(0, 0.35, 150)
end

function FiestaPlazaService.GetPlazaCenter(): Vector3
	return getPlazaCenter()
end

function FiestaPlazaService.IsAgawanBiikActive(): boolean
	return isAgawanBiikRunning
end

function FiestaPlazaService.IsPositionInPlaza(pos: Vector3): boolean
	local center = getPlazaCenter()
	local flat = Vector3.new(pos.X - center.X, 0, pos.Z - center.Z)
	return flat.Magnitude <= EventData.Fiesta.ArenaRadius
end

function FiestaPlazaService.IsPlayerInActiveArena(player: Player): boolean
	if not currentSession then
		return false
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	return FiestaPlazaService.IsPositionInPlaza(root.Position)
end

-- Comedic non-lethal slip/knockdown used by Palayok mud shockwaves, Biik oil puddles, and Agawan Biik rival slaps!
function FiestaPlazaService.ApplyPlazaComedicSlip(target: Player, pushDir: Vector3, popupText: string, popupColor: Color3?)
	local now = os.clock()
	if (slipCooldownUntil[target] or 0) > now then
		return
	end
	local char = target.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or not root:IsA("BasePart") or hum.Health <= 0 then
		return
	end
	slipCooldownUntil[target] = now + 1.8

	local flat = Vector3.new(pushDir.X, 0, pushDir.Z)
	local dir = if flat.Magnitude > 0.05 then flat.Unit else Vector3.new(0, 0, -1)

	local gui = Instance.new("BillboardGui")
	gui.Name = "FiestaSlipPopup"
	gui.Size = UDim2.fromScale(4.4, 1.3)
	gui.StudsOffset = Vector3.new(0, 3.1, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = true
	gui.Adornee = root

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.TextColor3 = popupColor or Color3.fromRGB(255, 215, 55)
	lbl.TextStrokeColor3 = Color3.fromRGB(20, 15, 15)
	lbl.TextStrokeTransparency = 0
	lbl.Text = popupText
	lbl.Parent = gui
	gui.Parent = root

	task.delay(0.9, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)

	hum.PlatformStand = true
	local basePos = root.Position + Vector3.new(0, 0.45, 0)
	root.CFrame = CFrame.new(basePos, basePos + dir) * CFrame.Angles(math.rad(-80), 0, 0)
	root.AssemblyLinearVelocity = dir * 20 + Vector3.new(0, 11, 0)

	task.delay(0.95, function()
		if hum.Parent and root.Parent then
			hum.PlatformStand = false
			root.CFrame = CFrame.new(root.Position + Vector3.new(0, 2.4, 0), root.Position + Vector3.new(0, 2.4, 0) + dir)
		end
	end)
end

-- Called from PamaloService on melee swing or Sipat throw!
function FiestaPlazaService.RegisterPamaloHit(
	player: Player,
	attackerPos: Vector3,
	lookVector: Vector3,
	reach: number,
	info: PamaloConfig.PamaloInfo
): (boolean, Vector3?)
	local baseDmg = EventData.Fiesta.PamaloDamage[info.Id] or 25

	-- 1) Check Hampas Palayok Boss Hit
	if activePalayokHandler and activePalayokPosition then
		local palayokPos = activePalayokPosition()
		if palayokPos then
			local delta = palayokPos - attackerPos
			local flatDist = Vector3.new(delta.X, 0, delta.Z).Magnitude
			if flatDist <= reach + 4.8 and math.abs(delta.Y) <= 9.5 then
				local ok = activePalayokHandler(player, baseDmg, info)
				if ok then
					return true, palayokPos
				end
			end
		end
	end

	-- 2) Check Agawan Biik (Greased Piglet) Tag Hit
	if activeBiikHandler and activeBiikPosition then
		local biikPos = activeBiikPosition()
		if biikPos then
			local delta = biikPos - attackerPos
			local flatDist = Vector3.new(delta.X, 0, delta.Z).Magnitude
			if flatDist <= reach + 3.8 and math.abs(delta.Y) <= 6.5 then
				local ok = activeBiikHandler(player, baseDmg, info)
				if ok then
					return true, biikPos
				end
			end
		end
	end

	-- 3) During Agawan Biik, Pamalo swings inside the Fiesta Plaza can comedically slip rival players!
	if isAgawanBiikRunning and FiestaPlazaService.IsPositionInPlaza(attackerPos) then
		local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)
		local unitLook = if flatLook.Magnitude > 0.05 then flatLook.Unit else Vector3.new(0, 0, -1)
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local char = other.Character
				local oRoot = char and char:FindFirstChild("HumanoidRootPart")
				if oRoot and oRoot:IsA("BasePart") and FiestaPlazaService.IsPositionInPlaza(oRoot.Position) then
					local delta = oRoot.Position - attackerPos
					local flatDelta = Vector3.new(delta.X, 0, delta.Z)
					local dist = flatDelta.Magnitude
					if dist <= reach + 1.5 then
						local dir = if dist > 0.05 then flatDelta.Unit else unitLook
						if dist <= 3.5 or dir:Dot(unitLook) >= (if info.IsAoE then 0.15 else 0.35) then
							FiestaPlazaService.ApplyPlazaComedicSlip(
								other,
								dir,
								`🩴 TABI! ({info.Emoji})`,
								Color3.fromRGB(255, 200, 55)
							)
							return true, oRoot.Position
						end
					end
				end
			end
		end
	end

	return false, nil
end

local function updateStageSigns(title: string, subtitle: string, titleColor: Color3)
	workspace:SetAttribute("FiestaEventTitle", title)
	workspace:SetAttribute("FiestaEventSub", subtitle)
	for _, sign in CollectionService:GetTagged("FiestaStageSign") do
		if sign:IsA("BasePart") then
			for _, sg in sign:GetChildren() do
				if sg:IsA("SurfaceGui") then
					local bg = sg:FindFirstChildOfClass("Frame")
					if bg then
						local labels: { TextLabel } = {}
						for _, child in bg:GetChildren() do
							if child:IsA("TextLabel") then
								table.insert(labels, child)
							end
						end
						if labels[1] then
							labels[1].Text = title
							labels[1].TextColor3 = titleColor
						end
						if labels[2] then
							labels[2].Text = subtitle
						end
					end
				end
			end
		end
	end
end

local function extendPlayerBoost(player: Player, attrName: string, addSeconds: number)
	local now = workspace:GetServerTimeNow()
	local currentAttr = player:GetAttribute(attrName)
	local currentUntil = if typeof(currentAttr) == "number" and currentAttr > now then currentAttr else now
	local newUntil = math.min(now + 900, currentUntil + addSeconds)
	player:SetAttribute(attrName, newUntil)
	if attrName == "FiestaMoneyBoostUntil" then
		EconomyService.RefreshPlayer(player)
	end
end

local function checkPlayersEnteringFiestaPlaza()
	local session = currentSession
	if not session then
		return
	end
	local cutsceneEvent = Remotes.GetEvent("FiestaCutscene")
	for _, player in Players:GetPlayers() do
		if not seenCutsceneUsers[player.UserId] and FiestaPlazaService.IsPlayerInActiveArena(player) then
			if player:GetAttribute("IsCarryingCage") ~= true and player:GetAttribute("IsCarryingStolen") ~= true then
				seenCutsceneUsers[player.UserId] = true
				cutsceneEvent:FireClient(
					player,
					"Enter",
					session.EventId,
					session.BannerTitle,
					session.BannerSubtitle,
					session.Center
				)
			end
		end
	end
end

local function beginFiestaSessionCutscene(eventId: string, bannerTitle: string, bannerSubtitle: string)
	local center = getPlazaCenter()
	currentSession = {
		EventId = eventId,
		BannerTitle = bannerTitle,
		BannerSubtitle = bannerSubtitle,
		Center = center,
	}
	seenCutsceneUsers = {}
	-- Only play the cutscene for players who actually enter / are inside the Fiesta Plaza (never interrupt players running in the zones!)
	checkPlayersEnteringFiestaPlaza()
end

local function endFiestaSession()
	currentSession = nil
	seenCutsceneUsers = {}
end

local function awardFiestaPetReward(player: Player, originPos: Vector3, forceFiestaChance: number): (string?, string?)
	if not DataService.IsLoaded(player) then
		return nil, nil
	end
	local pool = EventData.Fiesta.RewardPets
	local petId = pool[rng:NextInteger(1, #pool)]
	local mutation: string? = nil
	if rng:NextNumber() <= forceFiestaChance then
		mutation = "Fiesta"
	else
		mutation = MutationData.RollMutation(2.0)
	end
	InventoryService.AddPet(player, petId, mutation)
	Remotes.GetEvent("CageOpenedAnim"):FireClient(player, originPos, petId, mutation)
	return petId, mutation
end

-- POST-FIESTA "BOODLE FIGHT" COMMUNITY BUFF TABLE (30s) ---------------------
local function runBoodleFightFeast(announceEvent: RemoteEvent)
	local center = getPlazaCenter()
	local folder = Instance.new("Folder")
	folder.Name = "BoodleFightFeastFolder"
	folder.Parent = workspace

	announceEvent:FireAllClients(
		"🍌 BOODLE FIGHT FEAST served in the Fiesta Plaza! Eat within 30s for 🍽️ 10m Busog & Swerte (+25% Pet Luck & +15% WalkSpeed)!",
		workspace:GetServerTimeNow() + EventData.Fiesta.BoodleDurationSeconds,
		Color3.fromRGB(115, 245, 110)
	)

	local tableModel = Instance.new("Model")
	tableModel.Name = "BoodleFightTable"
	tableModel.Parent = folder

	local function makePart(name: string, size: Vector3, pos: Vector3, color: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.Position = pos
		p.Anchored = true
		p.CanCollide = false
		p.Color = color
		p.Material = mat
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = tableModel
		return p
	end

	-- Long Bamboo/Wood Feast Table + Green Banana Leaves ("Dahon ng Saging")
	local tableTop = makePart("TableTop", Vector3.new(20, 0.5, 5.2), center + Vector3.new(0, 2.4, 0), Color3.fromRGB(138, 92, 48), Enum.Material.WoodPlanks)
	tableTop.CanCollide = true
	tableModel.PrimaryPart = tableTop

	for _, lx in { -8.5, -2.8, 2.8, 8.5 } do
		makePart(`TableLegL_{lx}`, Vector3.new(0.6, 2.2, 0.6), center + Vector3.new(lx, 1.1, -2.0), Color3.fromRGB(108, 70, 34), Enum.Material.Wood)
		makePart(`TableLegR_{lx}`, Vector3.new(0.6, 2.2, 0.6), center + Vector3.new(lx, 1.1, 2.0), Color3.fromRGB(108, 70, 34), Enum.Material.Wood)
	end

	-- Banana Leaf Runners
	makePart("BananaLeafSheet", Vector3.new(19.0, 0.14, 4.4), center + Vector3.new(0, 2.72, 0), Color3.fromRGB(65, 185, 65), Enum.Material.SmoothPlastic)
	makePart("BananaLeafCenter", Vector3.new(18.2, 0.16, 2.8), center + Vector3.new(0, 2.76, 0), Color3.fromRGB(85, 215, 75), Enum.Material.SmoothPlastic)

	-- Steamed Garlic Rice Mounds, Roasted Golden Lechon Centerpiece, Grilled Bangus & Mangoes!
	for rx = -7.5, 7.5, 3.0 do
		makePart(`RiceMound_{rx}`, Vector3.new(1.5, 0.7, 2.1), center + Vector3.new(rx, 3.0, 0), Color3.fromRGB(248, 246, 238), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		makePart(`MangoSide_{rx}`, Vector3.new(0.75, 0.45, 0.95), center + Vector3.new(rx + 0.8, 2.95, 1.35), Color3.fromRGB(255, 205, 35), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		makePart(`BangusSide_{rx}`, Vector3.new(0.65, 0.3, 1.45), center + Vector3.new(rx - 0.8, 2.92, -1.35), Color3.fromRGB(175, 185, 198), Enum.Material.SmoothPlastic)
	end

	-- Golden Lechon Cebu Centerpiece
	makePart("LechonBody", Vector3.new(3.6, 1.65, 2.0), center + Vector3.new(0, 3.45, 0), Color3.fromRGB(215, 105, 32), Enum.Material.SmoothPlastic)
	makePart("LechonHead", Vector3.new(1.3, 1.25, 1.4), center + Vector3.new(-2.1, 3.45, 0), Color3.fromRGB(215, 105, 32), Enum.Material.SmoothPlastic)
	makePart("RedApple", Vector3.new(0.45, 0.45, 0.45), center + Vector3.new(-2.8, 3.35, 0), Color3.fromRGB(235, 45, 45), Enum.Material.Neon, Enum.PartType.Ball)

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(7.5, 1.8)
	bb.StudsOffset = Vector3.new(0, 4.2, 0)
	bb.MaxDistance = 75
	bb.AlwaysOnTop = true
	bb.Adornee = tableTop

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.fromScale(1, 1)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.FredokaOne
	titleLbl.TextScaled = true
	titleLbl.TextColor3 = Color3.fromRGB(120, 255, 130)
	titleLbl.TextStrokeTransparency = 0
	titleLbl.Text = "🍌 BOODLE FIGHT FEAST! (Press E: +25% Luck & +15% Speed for 10m!)"
	titleLbl.Parent = bb
	bb.Parent = tableTop

	local eatenThisFeast: { [Player]: boolean } = {}

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Kain Tayo! (+25% Luck & +15% Speed)"
	prompt.ObjectText = "🍌 Fiesta Boodle Fight (10m Buff)"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		if not RateLimiter.Check(player, "BoodleFightEat", 0.4) then
			return
		end
		local now = workspace:GetServerTimeNow()
		player:SetAttribute("BoodleBuffUntil", now + EventData.Fiesta.BoodleBuffSeconds)
		StatsService.Refresh(player)
		Remotes.GetEvent("FiestaVfx"):FireClient(player, "BoodleEat", tableTop.Position)

		if not eatenThisFeast[player] then
			eatenThisFeast[player] = true
			local cashSnack = math.max(1500, EconomyService.GetIncomePerSec(player) * 20)
			EconomyService.AddMoney(player, cashSnack)
			ClientSyncService.Notify(
				player,
				`🍽️ BUSOG & SWERTE! +25% Pet Luck & +15% WalkSpeed for 10 Minutes (+$${NumberFormat.Short(cashSnack)})!`,
				Color3.fromRGB(115, 255, 130)
			)
		else
			ClientSyncService.Notify(
				player,
				"🍽️ Refreshed your 10-minute Busog & Swerte (Boodle Fight) buff!",
				Color3.fromRGB(115, 255, 130)
			)
		end
	end)
	prompt.Parent = tableTop

	local duration = EventData.Fiesta.BoodleDurationSeconds
	local startClock = os.clock()
	while os.clock() - startClock < duration do
		local rem = math.max(0, math.ceil(duration - (os.clock() - startClock)))
		titleLbl.Text = `🍌 BOODLE FIGHT ({rem}s) — Press E for 10m +25% Luck & +15% WalkSpeed!`
		updateStageSigns(
			`🍌 BOODLE FIGHT FEAST ({rem}s)`,
			"Eat at the Banana-Leaf Feast Table for 🍽️ 10m Busog & Swerte (+25% Pet Luck & +15% WalkSpeed)!",
			Color3.fromRGB(120, 255, 130)
		)
		task.wait(0.5)
	end

	folder:Destroy()
end

-- EVENT 1: 🏺 HAMPAS PALAYOK / FIESTA PIÑATA RUSH (Pamalo-Driven + Shockwaves!)
local function runHampasPalayokEvent(announceEvent: RemoteEvent)
	local center = getPlazaCenter()
	local folder = Instance.new("Folder")
	folder.Name = "ActiveFiestaProps"
	folder.Parent = workspace

	local duration = EventData.Fiesta.PalayokDurationSeconds
	beginFiestaSessionCutscene(
		"HampasPalayok",
		"FIESTA NA! - HAMPAS PALAYOK RUSH!",
		"Swing your Pamalo to smash the giant Palayok & jump over Mud Shockwaves!"
	)

	announceEvent:FireAllClients(
		"🏺 HAMPAS PALAYOK RUSH started in the Fiesta Plaza! Swing your Pamalo & jump over mud shockwaves for Fiesta Pets & 2x Luck!",
		workspace:GetServerTimeNow() + duration,
		Color3.fromRGB(255, 175, 45)
	)

	local playerCount = math.max(1, #Players:GetPlayers())
	local maxHp = EventData.Fiesta.PalayokBaseHp + (playerCount - 1) * EventData.Fiesta.PalayokPerPlayerHp
	local currentHp = maxHp
	local contributions: { [Player]: number } = {}
	local swingImpulse = 0

	-- Build Hanging Giant Clay Palayok / Pinoy Piñata Rig
	local anchorTop = center + Vector3.new(0, 13.5, 0)
	local restPos = center + Vector3.new(0, 4.4, 0)

	local beamSupport = Instance.new("Part")
	beamSupport.Name = "PalayokTopBeam"
	beamSupport.Size = Vector3.new(18, 0.7, 0.9)
	beamSupport.Position = anchorTop
	beamSupport.Anchored = true
	beamSupport.CanCollide = false
	beamSupport.Color = Color3.fromRGB(145, 98, 48)
	beamSupport.Material = Enum.Material.Wood
	beamSupport.Parent = folder

	local rope = Instance.new("Part")
	rope.Name = "HangingRope"
	rope.Size = Vector3.new(0.35, 9.0, 0.35)
	rope.Position = center + Vector3.new(0, 9.0, 0)
	rope.Anchored = true
	rope.CanCollide = false
	rope.Color = Color3.fromRGB(215, 185, 115)
	rope.Material = Enum.Material.Fabric
	rope.Parent = folder

	local palayokCore = Instance.new("Part")
	palayokCore.Name = "GiantPalayok"
	palayokCore.Shape = Enum.PartType.Ball
	palayokCore.Size = Vector3.new(6.6, 6.6, 6.6)
	palayokCore.Position = restPos
	palayokCore.Anchored = true
	palayokCore.CanCollide = false
	palayokCore.Color = Color3.fromRGB(205, 102, 42)
	palayokCore.Material = Enum.Material.SmoothPlastic
	palayokCore.Parent = folder

	local goldRim = Instance.new("Part")
	goldRim.Name = "PalayokGoldRim"
	goldRim.Size = Vector3.new(4.4, 1.1, 4.4)
	goldRim.Position = restPos + Vector3.new(0, 2.9, 0)
	goldRim.Anchored = true
	goldRim.CanCollide = false
	goldRim.Color = Color3.fromRGB(255, 205, 45)
	goldRim.Material = Enum.Material.Neon
	goldRim.Parent = folder

	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(255, 195, 55)
	hl.OutlineColor = Color3.fromRGB(255, 255, 255)
	hl.FillTransparency = 0.55
	hl.Parent = palayokCore

	-- World-space HP Bar BillboardGui
	local hpGui = Instance.new("BillboardGui")
	hpGui.Name = "PalayokHpGui"
	hpGui.Size = UDim2.fromScale(7.5, 2.1)
	hpGui.StudsOffset = Vector3.new(0, 5.2, 0)
	hpGui.MaxDistance = 85
	hpGui.AlwaysOnTop = true
	hpGui.Adornee = palayokCore
	hpGui.Parent = palayokCore

	local hpTitle = Instance.new("TextLabel")
	hpTitle.Size = UDim2.fromScale(1, 0.45)
	hpTitle.BackgroundTransparency = 1
	hpTitle.Font = Enum.Font.FredokaOne
	hpTitle.TextScaled = true
	hpTitle.TextColor3 = Color3.fromRGB(255, 225, 75)
	hpTitle.TextStrokeTransparency = 0
	hpTitle.Text = `🏺 GIANT FIESTA PALAYOK — {currentHp}/{maxHp} HP`
	hpTitle.Parent = hpGui

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.fromScale(0.88, 0.28)
	barBg.Position = UDim2.fromScale(0.06, 0.48)
	barBg.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
	barBg.BorderSizePixel = 0
	barBg.Parent = hpGui
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0.4, 0)
	bgCorner.Parent = barBg

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = Color3.fromRGB(85, 235, 110)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBg
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.4, 0)
	fillCorner.Parent = barFill

	local hintSub = Instance.new("TextLabel")
	hintSub.Size = UDim2.fromScale(1, 0.22)
	hintSub.Position = UDim2.fromScale(0, 0.78)
	hintSub.BackgroundTransparency = 1
	hintSub.Font = Enum.Font.GothamBold
	hintSub.TextScaled = true
	hintSub.TextColor3 = Color3.fromRGB(240, 245, 255)
	hintSub.TextStrokeTransparency = 0.2
	hintSub.Text = "🩴 Equip & Swing your Pamalo! Jump over Mud Shockwaves!"
	hintSub.Parent = hpGui

	local function refreshHpUi()
		local ratio = math.clamp(currentHp / math.max(1, maxHp), 0, 1)
		barFill.Size = UDim2.fromScale(ratio, 1)
		barFill.BackgroundColor3 = if ratio > 0.5
			then Color3.fromRGB(85, 235, 110)
			elseif ratio > 0.25 then Color3.fromRGB(255, 200, 45)
			else Color3.fromRGB(255, 75, 65)
		hpTitle.Text = `🏺 GIANT FIESTA PALAYOK — {math.max(0, math.ceil(currentHp))}/{maxHp} HP`
	end

	local function applyPalayokHit(player: Player, dmg: number, info: PamaloConfig.PamaloInfo): boolean
		if currentHp <= 0 or not palayokCore.Parent then
			return false
		end
		currentHp = math.max(0, currentHp - dmg)
		contributions[player] = (contributions[player] or 0) + dmg
		swingImpulse = math.min(2.2, swingImpulse + 0.55)
		refreshHpUi()

		local smallCash = math.max(150, math.floor(EconomyService.GetIncomePerSec(player) * 2.5))
		EconomyService.AddMoney(player, smallCash)
		Remotes.GetEvent("FiestaVfx"):FireAllClients("PalayokHit", palayokCore.Position, dmg, info.Emoji)
		return true
	end

	activePalayokHandler = applyPalayokHit
	activePalayokPosition = function(): Vector3?
		return if palayokCore.Parent then palayokCore.Position else nil
	end

	-- Hazard Twist: Expanding Ground Mud Shockwave Ring that slips players who don't jump!
	local function spawnMudShockwave()
		if not folder.Parent then
			return
		end
		task.spawn(function()
			local ring = Instance.new("Part")
			ring.Name = "PalayokMudShockwave"
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.45, 2.5, 2.5)
			ring.CFrame = CFrame.new(center + Vector3.new(0, 0.85, 0)) * CFrame.Angles(0, 0, math.rad(90))
			ring.Anchored = true
			ring.CanCollide = false
			ring.Color = Color3.fromRGB(255, 145, 40)
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.25
			ring.Parent = folder

			local maxRad = EventData.Fiesta.PalayokShockwaveRadius
			local waveDur = 0.9
			local t0 = os.clock()
			while os.clock() - t0 < waveDur and ring.Parent do
				local alpha = math.clamp((os.clock() - t0) / waveDur, 0, 1)
				local curRadius = 1.5 + alpha * (maxRad - 1.5)
				ring.Size = Vector3.new(0.45, curRadius * 2, curRadius * 2)
				ring.Transparency = 0.2 + alpha * 0.65

				for _, player in Players:GetPlayers() do
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						local delta = root.Position - center
						local flatDist = Vector3.new(delta.X, 0, delta.Z).Magnitude
						local heightAboveFloor = root.Position.Y - center.Y
						-- Must jump (heightAboveFloor >= 3.5) when the shockwave rim passes under them!
						if math.abs(flatDist - curRadius) <= 2.2 and heightAboveFloor < 3.5 then
							local outDir = if flatDist > 0.1 then Vector3.new(delta.X, 0, delta.Z).Unit else Vector3.new(0, 0, 1)
							FiestaPlazaService.ApplyPlazaComedicSlip(
								player,
								outDir,
								"💦 NADULAS SA PUTIK! (Jump!)",
								Color3.fromRGB(255, 165, 55)
							)
						end
					end
				end
				task.wait(0.05)
			end
			if ring.Parent then
				ring:Destroy()
			end
		end)
	end

	local startClock = os.clock()
	local lastShockwaveAt = startClock + 1.5
	while os.clock() - startClock < duration and currentHp > 0 do
		local now = os.clock()
		local elapsed = now - startClock
		local rem = math.max(0, math.ceil(duration - elapsed))

		swingImpulse = math.max(0.25, swingImpulse - 0.08)
		local swingAngleX = math.sin(elapsed * 4.2) * math.rad(12 + swingImpulse * 16)
		local swingAngleZ = math.cos(elapsed * 3.5) * math.rad(10 + swingImpulse * 14)
		local pivotCF = CFrame.new(anchorTop) * CFrame.Angles(swingAngleX, elapsed * 1.6, swingAngleZ)
		local potCF = pivotCF * CFrame.new(0, -9.0, 0)
		local midCF = pivotCF * CFrame.new(0, -4.5, 0)

		palayokCore.CFrame = potCF
		goldRim.CFrame = potCF * CFrame.new(0, 2.9, 0)
		rope.CFrame = midCF

		if (now - lastShockwaveAt) >= EventData.Fiesta.PalayokShockwaveInterval then
			lastShockwaveAt = now
			spawnMudShockwave()
		end

		updateStageSigns(
			`🏺 HAMPAS PALAYOK RUSH ({rem}s) — {math.ceil(currentHp)}/{maxHp} HP`,
			"Swing your Pamalo (Tsinelas/Walis) to smash the Palayok & jump over Mud Shockwaves!",
			Color3.fromRGB(255, 180, 55)
		)
		task.wait(0.05)
	end

	activePalayokHandler = nil
	activePalayokPosition = nil

	-- Reward contributors!
	local totalDamage = 0
	for _, dmg in contributions do
		totalDamage += dmg
	end

	if currentHp <= 0 then
		Remotes.GetEvent("FiestaVfx"):FireAllClients("PalayokBreak", palayokCore.Position)
	end

	for player, dmg in contributions do
		if player.Parent and dmg > 0 then
			local share = math.clamp(dmg / math.max(1, totalDamage), 0.15, 1.0)
			extendPlayerBoost(player, "FiestaLuckBoostUntil", BOOST_DURATION_SECONDS)
			local cashBurst = math.max(3500, math.floor(EconomyService.GetIncomePerSec(player) * (35 + share * 50)))
			EconomyService.AddMoney(player, cashBurst)

			local fiestaChance = math.clamp(EventData.Fiesta.FiestaMutationChance * (0.65 + share * 0.75), 0.2, 0.75)
			local petId, mut = awardFiestaPetReward(player, center + Vector3.new(0, 3.5, 0), fiestaChance)
			local petInfo = if petId then PetData.Get(petId) else nil
			local petLabel = if petInfo
				then `{if mut then `[{mut}] ` else ""}{petInfo.Emoji} {petInfo.DisplayName}`
				else "Mystery Pet"

			ClientSyncService.Notify(
				player,
				`🏺 BASAG ANG PALAYOK! +$${NumberFormat.Short(cashBurst)}, 🍀 2x Luck (3m) & {petLabel}!`,
				Color3.fromRGB(255, 215, 55)
			)
		end
	end

	endFiestaSession()
	folder:Destroy()
	runBoodleFightFeast(announceEvent)
end

-- EVENT 2: 🐖 AGAWAN BIIK HOUR (Greased Piglet Chase + Pamalo Slap Tag!) -----
local function runAgawanBiikEvent(announceEvent: RemoteEvent)
	local center = getPlazaCenter()
	local folder = Instance.new("Folder")
	folder.Name = "ActiveFiestaProps"
	folder.Parent = workspace

	local duration = EventData.Fiesta.BiikDurationSeconds
	isAgawanBiikRunning = true
	beginFiestaSessionCutscene(
		"AgawanBiik",
		"FIESTA NA! - AGAWAN BIIK HOUR!",
		"Chase the greased golden Biik & slap it with your Pamalo for points!"
	)

	announceEvent:FireAllClients(
		"🐖 AGAWAN BIIK HOUR started in the Fiesta Plaza! Chase & slap the greased piglet with your Pamalo for Fiesta Prizes!",
		workspace:GetServerTimeNow() + duration,
		Color3.fromRGB(255, 195, 65)
	)

	local biikPos = center + Vector3.new(0, 1.8, 0)
	local biikTarget = center + Vector3.new(10, 1.8, -10)
	local biikFacing = 0
	local biikStunUntil = 0
	local scores: { [Player]: number } = {}

	local biikModel = PetVisuals.BuildModel("golden_pig", "Golden", CFrame.new(biikPos), 1.75)
	biikModel.Name = "GreasedBiik"
	biikModel.Parent = folder

	local biikPrimary = biikModel.PrimaryPart
	if biikPrimary then
		local hl = Instance.new("Highlight")
		hl.FillColor = Color3.fromRGB(255, 225, 75)
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.FillTransparency = 0.4
		hl.Parent = biikModel

		local bb = Instance.new("BillboardGui")
		bb.Name = "BiikTagGui"
		bb.Size = UDim2.fromScale(6.0, 1.6)
		bb.StudsOffset = Vector3.new(0, 3.2, 0)
		bb.MaxDistance = 75
		bb.AlwaysOnTop = true
		bb.Adornee = biikPrimary
		bb.Parent = biikPrimary

		local lbl = Instance.new("TextLabel")
		lbl.Name = "TagText"
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextScaled = true
		lbl.TextColor3 = Color3.fromRGB(255, 230, 65)
		lbl.TextStrokeTransparency = 0
		lbl.Text = "🐖 MADULAS NA BIIK! (Slap with Pamalo!)"
		lbl.Parent = bb
	end

	local function pickRandomBiikTarget(): Vector3
		local rx = (rng:NextNumber() * 2 - 1) * 13.5
		local rz = (rng:NextNumber() * 2 - 1) * 13.5
		return Vector3.new(center.X + rx, center.Y + 1.8, center.Z + rz)
	end

	local function spawnOilPuddle(pos: Vector3)
		if not folder.Parent then
			return
		end
		local puddle = Instance.new("Part")
		puddle.Name = "BiikOilPuddle"
		puddle.Shape = Enum.PartType.Cylinder
		puddle.Size = Vector3.new(0.18, 3.4, 3.4)
		puddle.CFrame = CFrame.new(Vector3.new(pos.X, center.Y + 0.42, pos.Z)) * CFrame.Angles(0, 0, math.rad(90))
		puddle.Anchored = true
		puddle.CanCollide = false
		puddle.Color = Color3.fromRGB(165, 115, 38)
		puddle.Material = Enum.Material.Glass
		puddle.Transparency = 0.25
		puddle.Parent = folder

		task.delay(4.0, function()
			if puddle.Parent then
				puddle:Destroy()
			end
		end)
	end

	local function onBiikSlapped(player: Player, pts: number, info: PamaloConfig.PamaloInfo): boolean
		if not biikModel.Parent then
			return false
		end
		scores[player] = (scores[player] or 0) + pts
		biikStunUntil = os.clock() + 0.45
		biikTarget = pickRandomBiikTarget()

		local tickCash = math.max(400, math.floor(EconomyService.GetIncomePerSec(player) * 4))
		EconomyService.AddMoney(player, tickCash)
		extendPlayerBoost(player, "FiestaSpeedBoostUntil", 45)
		extendPlayerBoost(player, "FiestaMoneyBoostUntil", 45)

		Remotes.GetEvent("FiestaVfx"):FireAllClients("BiikTagged", biikPos, player.DisplayName, pts, info.Emoji)
		return true
	end

	activeBiikHandler = onBiikSlapped
	activeBiikPosition = function(): Vector3?
		return if biikModel.Parent then biikPos else nil
	end

	local startClock = os.clock()
	local nextDashAt = startClock + 1.0
	local nextPuddleAt = startClock + 0.7

	while os.clock() - startClock < duration do
		local now = os.clock()
		local elapsed = now - startClock
		local rem = math.max(0, math.ceil(duration - elapsed))

		if now >= nextDashAt then
			nextDashAt = now + EventData.Fiesta.BiikDashInterval * (0.7 + rng:NextNumber() * 0.5)
			biikTarget = pickRandomBiikTarget()
		end

		if now >= biikStunUntil then
			local toTarget = Vector3.new(biikTarget.X - biikPos.X, 0, biikTarget.Z - biikPos.Z)
			if toTarget.Magnitude <= 1.2 then
				biikTarget = pickRandomBiikTarget()
			else
				local dir = toTarget.Unit
				local step = math.min(toTarget.Magnitude, 24.0 * 0.05)
				biikPos += dir * step
				biikFacing = math.atan2(-dir.X, -dir.Z)
			end
		end

		local hopY = math.abs(math.sin(elapsed * 16)) * 0.65
		local wiggle = math.sin(elapsed * 20) * math.rad(12)
		if biikModel.Parent then
			biikModel:PivotTo(
				CFrame.new(biikPos + Vector3.new(0, hopY, 0))
					* CFrame.Angles(0, biikFacing, wiggle)
			)
		end

		if now >= nextPuddleAt then
			nextPuddleAt = now + 0.75
			spawnOilPuddle(biikPos)
		end

		-- Check players stepping on oil puddles
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") and child.Name == "BiikOilPuddle" then
				for _, player in Players:GetPlayers() do
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						local flat = Vector3.new(root.Position.X - child.Position.X, 0, root.Position.Z - child.Position.Z)
						local dy = root.Position.Y - center.Y
						if flat.Magnitude <= 1.85 and dy < 3.4 then
							child:Destroy()
							FiestaPlazaService.ApplyPlazaComedicSlip(
								player,
								root.CFrame.LookVector,
								"🛢️ NADULAS SA MANTIKA!",
								Color3.fromRGB(255, 200, 65)
							)
							break
						end
					end
				end
			end
		end

		updateStageSigns(
			`🐖 AGAWAN BIIK HOUR ({rem}s)`,
			"Chase & Slap the Greased Golden Piglet with your Pamalo for Fiesta Pets, Cash & 2x Boosts!",
			Color3.fromRGB(255, 205, 55)
		)
		task.wait(0.05)
	end

	isAgawanBiikRunning = false
	activeBiikHandler = nil
	activeBiikPosition = nil

	-- Find top scorer and reward all participants!
	local bestScore = 0
	for _, sc in scores do
		if sc > bestScore then
			bestScore = sc
		end
	end

	for player, sc in scores do
		if player.Parent and sc > 0 then
			local ratio = math.clamp(sc / math.max(1, bestScore), 0.25, 1.0)
			extendPlayerBoost(player, "FiestaSpeedBoostUntil", BOOST_DURATION_SECONDS)
			extendPlayerBoost(player, "FiestaMoneyBoostUntil", BOOST_DURATION_SECONDS)
			local prizeCash = math.max(4000, math.floor(EconomyService.GetIncomePerSec(player) * (40 + ratio * 45)))
			EconomyService.AddMoney(player, prizeCash)

			local tier = StatsService.GetSpeedLevel(player)
			local bonusSpeed = math.max(75, ShopData.GetTrainerGainPerSec(tier) * 25)
			StatsService.AddTrainedSpeed(player, bonusSpeed)

			local petId, mut = awardFiestaPetReward(player, biikPos, EventData.Fiesta.FiestaMutationChance * ratio)
			local petInfo = if petId then PetData.Get(petId) else nil
			local petLabel = if petInfo
				then `{if mut then `[{mut}] ` else ""}{petInfo.Emoji} {petInfo.DisplayName}`
				else "Golden Pig"

			ClientSyncService.Notify(
				player,
				`🐖 NAHULI ANG BIIK ({sc} pts)! +$${NumberFormat.Short(prizeCash)}, +${NumberFormat.Short(bonusSpeed)} Speed & {petLabel}!`,
				Color3.fromRGB(255, 215, 55)
			)
		end
	end

	endFiestaSession()
	folder:Destroy()
	runBoodleFightFeast(announceEvent)
end

-- EVENT 3: 🎋 FIESTA PABITIN (Jump & Grab Hanging Prizes!) ------------------
local function runPabitinEvent(announceEvent: RemoteEvent)
	local center = getPlazaCenter()
	local folder = Instance.new("Folder")
	folder.Name = "ActiveFiestaProps"
	folder.Parent = workspace

	beginFiestaSessionCutscene(
		"FiestaPabitin",
		"FIESTA NA! - PABITIN JUMP RUSH!",
		"Jump & grab hanging prizes from the bamboo lattice for 2x Speed Boost!"
	)

	announceEvent:FireAllClients(
		"🎋 FIESTA PABITIN started in the Fiesta Plaza! Jump & grab prizes for ⚡ 2x Treadmill Speed Boost!",
		workspace:GetServerTimeNow() + 35,
		Color3.fromRGB(80, 235, 255)
	)

	local frameBar = Instance.new("Part")
	frameBar.Name = "PabitinLattice"
	frameBar.Size = Vector3.new(16, 0.45, 16)
	frameBar.Position = center + Vector3.new(0, 11, 0)
	frameBar.Anchored = true
	frameBar.CanCollide = false
	frameBar.Color = Color3.fromRGB(185, 140, 72)
	frameBar.Material = Enum.Material.Wood
	frameBar.Parent = folder

	local prizeColors = {
		Color3.fromRGB(255, 75, 75),
		Color3.fromRGB(255, 215, 50),
		Color3.fromRGB(65, 225, 255),
		Color3.fromRGB(95, 245, 120),
		Color3.fromRGB(245, 95, 235),
	}

	type PrizeBox = {
		Part: Part,
		Offset: Vector3,
		Claimed: boolean,
	}
	local prizes: { PrizeBox } = {}

	local idx = 0
	for gx = -1, 1 do
		for gz = -1, 1 do
			idx += 1
			local off = Vector3.new(gx * 5.2, -1.6, gz * 5.2)
			local box = Instance.new("Part")
			box.Name = `PabitinPrize_{idx}`
			box.Size = Vector3.new(2.4, 2.4, 2.4)
			box.Position = frameBar.Position + off
			box.Anchored = true
			box.CanCollide = false
			box.Color = prizeColors[((idx - 1) % #prizeColors) + 1]
			box.Material = Enum.Material.Neon
			box.Parent = folder

			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromScale(4, 1.2)
			bb.StudsOffset = Vector3.new(0, 2.0, 0)
			bb.MaxDistance = 60
			bb.Adornee = box
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.FredokaOne
			lbl.TextScaled = true
			lbl.TextColor3 = Color3.fromRGB(255, 245, 150)
			lbl.TextStrokeTransparency = 0
			lbl.Text = "🎁 JUMP TO GRAB! (2x Speed)"
			lbl.Parent = bb
			bb.Parent = box

			table.insert(prizes, {
				Part = box,
				Offset = off,
				Claimed = false,
			})
		end
	end

	local duration = 35
	local startClock = os.clock()
	while os.clock() - startClock < duration do
		local elapsed = os.clock() - startClock
		local rem = math.max(0, math.ceil(duration - elapsed))
		local bobY = 8.8 - math.sin(elapsed * 2.4) * 2.8
		local framePos = center + Vector3.new(0, bobY, 0)
		frameBar.Position = framePos

		local remainingBoxes = 0
		for _, pz in prizes do
			if not pz.Claimed and pz.Part.Parent then
				remainingBoxes += 1
				pz.Part.CFrame = CFrame.new(framePos + pz.Offset) * CFrame.Angles(0, elapsed * 1.8, 0)

				for _, player in Players:GetPlayers() do
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						if (root.Position - pz.Part.Position).Magnitude <= 4.6 then
							pz.Claimed = true
							pz.Part:Destroy()
							extendPlayerBoost(player, "FiestaSpeedBoostUntil", BOOST_DURATION_SECONDS)
							local tier = StatsService.GetSpeedLevel(player)
							local bonusSpeed = math.max(50, ShopData.GetTrainerGainPerSec(tier) * 20)
							StatsService.AddTrainedSpeed(player, bonusSpeed)
							ClientSyncService.Notify(
								player,
								`🎋 Snatched a Pabitin Prize! +${NumberFormat.Short(bonusSpeed)} Speed & ⚡ 2x Treadmill Boost (3m)!`,
								Color3.fromRGB(80, 235, 255)
							)
							break
						end
					end
				end
			end
		end

		updateStageSigns(
			`🎋 FIESTA PABITIN ({rem}s)`,
			`Jump & Grab Hanging Prizes for ⚡ 2x Treadmill Speed Boost! ({remainingBoxes} left)`,
			Color3.fromRGB(80, 235, 255)
		)

		if remainingBoxes == 0 then
			break
		end
		task.wait(0.1)
	end

	endFiestaSession()
	folder:Destroy()
	runBoodleFightFeast(announceEvent)
end

-- EVENT 4: 🎲 PERYA COLOR GAME (Stand on the Winning Color Tile!) -----------
local function runColorGameEvent(announceEvent: RemoteEvent)
	local center = getPlazaCenter()
	local folder = Instance.new("Folder")
	folder.Name = "ActiveFiestaProps"
	folder.Parent = workspace

	beginFiestaSessionCutscene(
		"PeryaColorGame",
		"FIESTA NA! - PERYA COLOR GAME!",
		"Stand on the winning Color Tile for 2x Pet Cash & Jackpot Prizes!"
	)

	announceEvent:FireAllClients(
		"🎲 PERYA COLOR GAME started in the Fiesta Plaza! Stand on a color tile for 💰 2x Pet Cash Boost!",
		workspace:GetServerTimeNow() + 33,
		Color3.fromRGB(255, 215, 55)
	)

	local colorOptions = {
		{ Name = "RED", Color = Color3.fromRGB(235, 55, 55) },
		{ Name = "BLUE", Color = Color3.fromRGB(55, 145, 245) },
		{ Name = "YELLOW", Color = Color3.fromRGB(250, 210, 45) },
		{ Name = "GREEN", Color = Color3.fromRGB(65, 215, 95) },
		{ Name = "PINK", Color = Color3.fromRGB(245, 95, 210) },
		{ Name = "WHITE", Color = Color3.fromRGB(240, 245, 255) },
	}

	local dice = Instance.new("Part")
	dice.Name = "PeryaColorCube"
	dice.Size = Vector3.new(4.8, 4.8, 4.8)
	dice.Position = center + Vector3.new(0, 7.5, 0)
	dice.Anchored = true
	dice.CanCollide = false
	dice.Material = Enum.Material.Neon
	dice.Color = colorOptions[1].Color
	dice.Parent = folder

	for round = 1, 3 do
		local spinStart = os.clock()
		while os.clock() - spinStart < 8.0 do
			local elapsed = os.clock() - spinStart
			local rem = math.max(1, math.ceil(8.0 - elapsed))
			local preview = colorOptions[(math.floor(elapsed * 6) % #colorOptions) + 1]
			dice.Color = preview.Color
			dice.CFrame = CFrame.new(center + Vector3.new(0, 7.5 + math.sin(elapsed * 4) * 0.6, 0))
				* CFrame.Angles(elapsed * 3.5, elapsed * 4.2, elapsed * 2.1)
			updateStageSigns(
				`🎲 PERYA COLOR GAME — Round {round}/3 ({rem}s)`,
				"Stand on any Color Tile! Matching the winning color gives 💰 2x Pet Cash Boost!",
				preview.Color
			)
			task.wait(0.1)
		end

		local winner = colorOptions[rng:NextInteger(1, #colorOptions)]
		dice.Color = winner.Color
		dice.CFrame = CFrame.new(center + Vector3.new(0, 7.5, 0))
		updateStageSigns(
			`🎲 WINNING COLOR: {winner.Name}! (Round {round}/3)`,
			"Winners get 💰 2x Pet Cash Boost (3m) + Instant Cash Jackpot!",
			winner.Color
		)

		for _, tile in CollectionService:GetTagged("FiestaColorTile") do
			if tile:IsA("BasePart") then
				local tileColorName = tostring(tile:GetAttribute("ColorName") or "")
				local isWinTile = (tileColorName == winner.Name)
				tile.Material = if isWinTile then Enum.Material.Neon else Enum.Material.SmoothPlastic

				for _, player in Players:GetPlayers() do
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						local dx = math.abs(root.Position.X - tile.Position.X)
						local dz = math.abs(root.Position.Z - tile.Position.Z)
						local dy = math.abs(root.Position.Y - tile.Position.Y)
						if dx <= tile.Size.X * 0.55 and dz <= tile.Size.Z * 0.55 and dy <= 8 then
							if isWinTile then
								extendPlayerBoost(player, "FiestaMoneyBoostUntil", BOOST_DURATION_SECONDS)
								local jackpot = math.max(2500, EconomyService.GetIncomePerSec(player) * 45)
								EconomyService.AddMoney(player, jackpot)
								ClientSyncService.Notify(
									player,
									`🎲 JACKPOT ({winner.Name})! Won $${NumberFormat.Short(jackpot)} & 💰 2x Pet Cash Boost (3m)!`,
									Color3.fromRGB(95, 255, 130)
								)
							else
								extendPlayerBoost(player, "FiestaMoneyBoostUntil", 60)
								ClientSyncService.Notify(
									player,
									`🎲 Color Game Participation! +1m of 💰 2x Pet Cash Boost! (Winning color: {winner.Name})`,
									Color3.fromRGB(255, 215, 75)
								)
							end
						end
					end
				end
			end
		end

		task.wait(3.0)
		for _, tile in CollectionService:GetTagged("FiestaColorTile") do
			if tile:IsA("BasePart") then
				tile.Material = Enum.Material.SmoothPlastic
			end
		end
	end

	endFiestaSession()
	folder:Destroy()
	runBoodleFightFeast(announceEvent)
end

function FiestaPlazaService.Init()
	local announceEvent = Remotes.GetEvent("EventAnnounce")
	Remotes.GetEvent("FiestaCutscene")
	Remotes.GetEvent("FiestaVfx")

	Players.PlayerRemoving:Connect(function(player: Player)
		slipCooldownUntil[player] = nil
	end)

	-- Watch for players walking into the Fiesta Plaza during an active event to play their entrance cutscene!
	task.spawn(function()
		while true do
			task.wait(0.25)
			if currentSession then
				checkPlayersEnteringFiestaPlaza()
			end
		end
	end)

	-- Register 2x Cash Income Multiplier when FiestaMoneyBoostUntil is active!
	EconomyService.AddMultiplierProvider("FiestaPlazaBoost", function(player: Player): number
		local untilAttr = player:GetAttribute("FiestaMoneyBoostUntil")
		if typeof(untilAttr) == "number" and untilAttr > workspace:GetServerTimeNow() then
			return 2.0
		end
		return 1.0
	end)

	-- Rotate through the Fiesta Plaza Minigames (starting with Hampas Palayok & Agawan Biik!)
	task.spawn(function()
		local nextEventIndex = 1
		local eventNames = {
			"🏺 Hampas Palayok Rush (Fiesta Pets & 2x Luck)",
			"🐖 Agawan Biik Hour (Greased Piglet Chase)",
			"🎋 Fiesta Pabitin (2x Speed Boost)",
			"🎲 Perya Color Game (2x Cash Boost)",
		}

		for rem = 25, 1, -1 do
			updateStageSigns(
				`🎪 NEXT FIESTA IN {rem}s`,
				`Up Next: {eventNames[nextEventIndex]} — Gather at the Fiesta Plaza behind the plots!`,
				Color3.fromRGB(255, 215, 55)
			)
			task.wait(1.0)
		end

		while true do
			if nextEventIndex == 1 then
				runHampasPalayokEvent(announceEvent)
			elseif nextEventIndex == 2 then
				runAgawanBiikEvent(announceEvent)
			elseif nextEventIndex == 3 then
				runPabitinEvent(announceEvent)
			else
				runColorGameEvent(announceEvent)
			end

			nextEventIndex = (nextEventIndex % #eventNames) + 1

			for rem = 150, 1, -1 do
				local min = rem // 60
				local sec = rem % 60
				local timeStr = if min > 0 then string.format("%dm %02ds", min, sec) else `{sec}s`
				updateStageSigns(
					`🎪 NEXT FIESTA IN {timeStr}`,
					`Up Next: {eventNames[nextEventIndex]} — Gather at the Fiesta Plaza behind the plots!`,
					Color3.fromRGB(255, 215, 55)
				)
				task.wait(1.0)
			end
		end
	end)
end

return FiestaPlazaService
