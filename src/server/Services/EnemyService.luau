--!strict
-- EnemyService.luau (SERVER)
-- Spawns and drives zone-themed Wardens and 4-legged Guard Dogs:
--   * Zone1: Blue Security Cell Warden
--   * Zone2: Crimson Tactical Riot Warden + Brown Guard Dog
--   * Zone3: Obsidian & Neon Purple Cyber Boss Warden + Cyber Hellhound

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local EnemyData = require(Shared:WaitForChild("EnemyData"))
local CageService = require(script.Parent:WaitForChild("CageService"))

type EnemyState = "Patrol" | "Chase" | "Stunned"

type Enemy = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Head: BasePart,
	EnemyType: string,
	Stats: EnemyData.EnemyStats,
	Zone: string,
	SpeedMultiplier: number,
	SpawnCFrame: CFrame,

	State: EnemyState,
	Target: Player?,
	ChaseStartedAt: number,
	LastSawTargetAt: number,
	StunEndsAt: number,
	FrozenUntil: number,
	ReChaseAvailableAt: number,

	NextDetectionAt: number,
	NextPathRecomputeAt: number,
	LastPathTargetPos: Vector3?,
	Waypoints: { PathWaypoint },
	WaypointIndex: number,

	PatrolTargetPos: Vector3?,
	PatrolWaitUntil: number,
	LastProgressPos: Vector3,
	LastProgressAt: number,
}

local EnemyService = {}

local enemies: { Enemy } = {}
local setupDone: { [Instance]: boolean } = {}
local rng = Random.new()

local sightMultiplierGetter: ((Player, string) -> number)? = nil
local extraCarryingCheck: ((Player) -> (boolean, Model?))? = nil
local extraCatchHandler: ((Player) -> ())? = nil

function EnemyService.SetSightMultiplierGetter(fn: (Player, string) -> number)
	sightMultiplierGetter = fn
end

function EnemyService.SetExtraCarryingCheck(fn: (Player) -> (boolean, Model?))
	extraCarryingCheck = fn
end

function EnemyService.SetExtraCatchHandler(fn: (Player) -> ())
	extraCatchHandler = fn
end

-- Zone Visual Themes --------------------------------------------------------

type WardenTheme = {
	Title: string,
	TagColor: Color3,
	SkinColor: Color3,
	ShirtColor: Color3,
	PantsColor: Color3,
	AccentColor: Color3,
	EyeColor: Color3,
	Scale: number,
}

local WARDEN_THEMES: { [string]: WardenTheme } = {
	Zone1 = {
		-- Photo 1 Sabungero Fit: Woven Brown Buri Hat, Clean White Polo Shirt, Blue Denim Shorts & Tan Legs!
		Title = "🐓 SABUNGERO",
		TagColor = Color3.fromRGB(130, 240, 110),
		SkinColor = Color3.fromRGB(215, 160, 115),
		ShirtColor = Color3.fromRGB(245, 248, 252),
		PantsColor = Color3.fromRGB(70, 130, 195),
		AccentColor = Color3.fromRGB(155, 100, 52),
		EyeColor = Color3.fromRGB(30, 25, 20),
		Scale = 1.25,
	},
	Zone2 = {
		-- Palengke / Tiangge Vendor: White Sando, Red Market Apron & Bimpo Towel
		Title = "🔪 TINDERO SA PALENGKE",
		TagColor = Color3.fromRGB(255, 175, 65),
		SkinColor = Color3.fromRGB(205, 150, 108),
		ShirtColor = Color3.fromRGB(240, 240, 245),
		PantsColor = Color3.fromRGB(45, 52, 65),
		AccentColor = Color3.fromRGB(210, 45, 45),
		EyeColor = Color3.fromRGB(30, 25, 20),
		Scale = 1.35,
	},
	Zone3 = {
		-- Hacienda Security Chief (Sikyo / Guardia): Crisp Light-Blue Pinoy Security Polo, Navy Slacks, Gold Patches & Batuta
		Title = "👮‍♂️ HACIENDA SIKYO",
		TagColor = Color3.fromRGB(255, 215, 65),
		SkinColor = Color3.fromRGB(210, 155, 112),
		ShirtColor = Color3.fromRGB(165, 205, 245),
		PantsColor = Color3.fromRGB(22, 30, 58),
		AccentColor = Color3.fromRGB(245, 195, 50),
		EyeColor = Color3.fromRGB(30, 25, 20),
		Scale = 1.42,
	},
	Zone4 = {
		-- Bohol / Palawan Jungle Ranger
		Title = "🏹 BANTAY GUBAT",
		TagColor = Color3.fromRGB(95, 235, 175),
		SkinColor = Color3.fromRGB(205, 150, 108),
		ShirtColor = Color3.fromRGB(52, 98, 58),
		PantsColor = Color3.fromRGB(45, 62, 42),
		AccentColor = Color3.fromRGB(165, 120, 65),
		EyeColor = Color3.fromRGB(30, 25, 20),
		Scale = 1.45,
	},
	Zone5 = {
		-- Mayon Volcano Guardian
		Title = "🔥 BANTAY BULKAN",
		TagColor = Color3.fromRGB(255, 105, 65),
		SkinColor = Color3.fromRGB(195, 140, 102),
		ShirtColor = Color3.fromRGB(135, 35, 28),
		PantsColor = Color3.fromRGB(42, 32, 32),
		AccentColor = Color3.fromRGB(255, 145, 35),
		EyeColor = Color3.fromRGB(255, 180, 40),
		Scale = 1.50,
	},
	Zone6 = {
		-- Intramuros Royal Guardia Sibil Captain
		Title = "⚔️ GUARDIA CAPTAIN",
		TagColor = Color3.fromRGB(255, 215, 55),
		SkinColor = Color3.fromRGB(215, 165, 120),
		ShirtColor = Color3.fromRGB(32, 42, 78),
		PantsColor = Color3.fromRGB(240, 235, 225),
		AccentColor = Color3.fromRGB(255, 205, 45),
		EyeColor = Color3.fromRGB(30, 25, 20),
		Scale = 1.55,
	},
	Zone7 = {
		Title = "🥷 SHINOBI GUARD",
		TagColor = Color3.fromRGB(255, 130, 195),
		SkinColor = Color3.fromRGB(220, 185, 150),
		ShirtColor = Color3.fromRGB(35, 32, 48),
		PantsColor = Color3.fromRGB(22, 20, 32),
		AccentColor = Color3.fromRGB(255, 95, 165),
		EyeColor = Color3.fromRGB(255, 70, 140),
		Scale = 1.58,
	},
	Zone8 = {
		Title = "🌌 COSMIC GUARDIAN",
		TagColor = Color3.fromRGB(130, 240, 255),
		SkinColor = Color3.fromRGB(55, 65, 95),
		ShirtColor = Color3.fromRGB(28, 30, 68),
		PantsColor = Color3.fromRGB(18, 20, 48),
		AccentColor = Color3.fromRGB(0, 245, 225),
		EyeColor = Color3.fromRGB(0, 245, 225),
		Scale = 1.62,
	},
}

-- Rig builders --------------------------------------------------------------

local function makeAttachedPart(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, attachTo: BasePart, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent

	local w = Instance.new("WeldConstraint")
	w.Part0 = attachTo
	w.Part1 = p
	w.Parent = p
	return p
end

local function addNameTag(head: BasePart, displayName: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "EnemyTag"
	gui.Size = UDim2.fromScale(3.6, 0.85)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.MaxDistance = 42
	gui.AlwaysOnTop = false
	gui.Adornee = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.1
	label.Text = displayName
	label.Parent = gui

	gui.Parent = head
end

local function decorateWardenByZone(model: Model, head: BasePart, root: BasePart, zone: string, theme: WardenTheme)
	local hcf = head.CFrame
	local upperTorso = model:FindFirstChild("UpperTorso")
	local torsoPart: BasePart = if upperTorso and upperTorso:IsA("BasePart") then upperTorso else root
	local tcf = torsoPart.CFrame
	local rightHand = model:FindFirstChild("RightHand")
	local handPart: BasePart = if rightHand and rightHand:IsA("BasePart") then rightHand else torsoPart

	-- Glowing Eyes / Visor
	makeAttachedPart("EyeL", Vector3.new(0.34, 0.18, 0.15), hcf * CFrame.new(-0.32, 0.15, -0.78), theme.EyeColor, Enum.Material.Neon, head, model)
	makeAttachedPart("EyeR", Vector3.new(0.34, 0.18, 0.15), hcf * CFrame.new(0.32, 0.15, -0.78), theme.EyeColor, Enum.Material.Neon, head, model)

	-- Belt
	makeAttachedPart("Belt", Vector3.new(2.7, 0.35, 1.45), tcf * CFrame.new(0, -0.85, 0), Color3.fromRGB(20, 20, 25), Enum.Material.SmoothPlastic, torsoPart, model)
	makeAttachedPart("BeltBuckle", Vector3.new(0.5, 0.4, 0.2), tcf * CFrame.new(0, -0.85, -0.72), theme.AccentColor, Enum.Material.Neon, torsoPart, model)

	if zone == "Zone1" then
		-- Photo 1 Sabungero Fit:
		-- 1) Woven Brown Buri Fedora/Cowboy Hat (curved brim + woven crown + dark band)
		local hatBrown = Color3.fromRGB(148, 96, 52)
		local hatDark = Color3.fromRGB(98, 60, 30)
		makeAttachedPart("BuriBrim", Vector3.new(2.7, 0.2, 2.5), hcf * CFrame.new(0, 0.58, 0), hatBrown, Enum.Material.WoodPlanks, head, model)
		makeAttachedPart("BuriBrimSideL", Vector3.new(0.35, 0.25, 2.3), hcf * CFrame.new(-1.3, 0.68, 0) * CFrame.Angles(0, 0, math.rad(-18)), hatBrown, Enum.Material.WoodPlanks, head, model)
		makeAttachedPart("BuriBrimSideR", Vector3.new(0.35, 0.25, 2.3), hcf * CFrame.new(1.3, 0.68, 0) * CFrame.Angles(0, 0, math.rad(18)), hatBrown, Enum.Material.WoodPlanks, head, model)
		makeAttachedPart("BuriBand", Vector3.new(1.75, 0.22, 1.85), hcf * CFrame.new(0, 0.72, 0), hatDark, Enum.Material.Fabric, head, model)
		makeAttachedPart("BuriCrown", Vector3.new(1.65, 0.75, 1.75), hcf * CFrame.new(0, 1.05, 0), hatBrown, Enum.Material.WoodPlanks, head, model)

		-- 2) White Polo Collar & V-Neck
		makeAttachedPart("PoloCollarL", Vector3.new(0.65, 0.3, 0.4), tcf * CFrame.new(-0.45, 0.98, -0.55) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(250, 250, 255), Enum.Material.Fabric, torsoPart, model)
		makeAttachedPart("PoloCollarR", Vector3.new(0.65, 0.3, 0.4), tcf * CFrame.new(0.45, 0.98, -0.55) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(250, 250, 255), Enum.Material.Fabric, torsoPart, model)

		-- 3) Short Polo Sleeves (tan lower arms + dark forearm tattoo on left arm like Photo 1!)
		for _, armName in { "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand" } do
			local part = model:FindFirstChild(armName)
			if part and part:IsA("BasePart") then
				part.Color = theme.SkinColor
			end
		end
		local leftLowerArm = model:FindFirstChild("LeftLowerArm")
		if leftLowerArm and leftLowerArm:IsA("BasePart") then
			makeAttachedPart("ForearmTattoo", Vector3.new(1.05, 0.9, 1.05), leftLowerArm.CFrame, Color3.fromRGB(58, 55, 52), Enum.Material.SmoothPlastic, leftLowerArm, model)
		end

		-- 4) Denim Jorts (tan calves below the knee + white distressed rip patch on right thigh + hanging keychain!)
		for _, legName in { "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" } do
			local part = model:FindFirstChild(legName)
			if part and part:IsA("BasePart") then
				part.Color = theme.SkinColor
			end
		end
		local rightUpperLeg = model:FindFirstChild("RightUpperLeg")
		if rightUpperLeg and rightUpperLeg:IsA("BasePart") then
			makeAttachedPart("JortsRipPatch", Vector3.new(0.55, 0.35, 0.15), rightUpperLeg.CFrame * CFrame.new(0.1, -0.15, -0.55), Color3.fromRGB(235, 240, 250), Enum.Material.Fabric, rightUpperLeg, model)
			makeAttachedPart("Keychain", Vector3.new(0.18, 0.55, 0.18), rightUpperLeg.CFrame * CFrame.new(0.45, 0.45, -0.55), Color3.fromRGB(30, 30, 35), Enum.Material.Metal, rightUpperLeg, model)
		end

	elseif zone == "Zone2" then
		-- Palengke Tindero: Red Market Apron, White Bimpo Towel on Shoulder, Market Cleaver/Pamalo
		makeAttachedPart("RedApron", Vector3.new(2.2, 2.2, 0.25), tcf * CFrame.new(0, -0.35, -0.72), theme.AccentColor, Enum.Material.Fabric, torsoPart, model)
		makeAttachedPart("BimpoTowel", Vector3.new(0.65, 0.25, 1.6), tcf * CFrame.new(-0.95, 0.95, -0.1), Color3.fromRGB(245, 245, 250), Enum.Material.Fabric, torsoPart, model)
		makeAttachedPart("VisorCap", Vector3.new(1.8, 0.5, 1.9), hcf * CFrame.new(0, 0.65, -0.1), theme.AccentColor, Enum.Material.Fabric, head, model)
		makeAttachedPart("Pamalo", Vector3.new(0.38, 0.38, 2.6), handPart.CFrame * CFrame.new(0, -0.2, -0.9), Color3.fromRGB(145, 98, 52), Enum.Material.Wood, handPart, model)

	else
		-- Zone3: Hacienda Sikyo (Pinoy Security Guard Cap, Gold Badge, Shoulder Epaulettes & Batuta Nightstick)
		makeAttachedPart("SikyoCap", Vector3.new(1.85, 0.65, 1.85), hcf * CFrame.new(0, 0.72, 0), Color3.fromRGB(22, 30, 58), Enum.Material.Fabric, head, model)
		makeAttachedPart("SikyoVisor", Vector3.new(1.75, 0.18, 0.75), hcf * CFrame.new(0, 0.48, -0.85), Color3.fromRGB(15, 15, 20), Enum.Material.SmoothPlastic, head, model)
		makeAttachedPart("CapBadge", Vector3.new(0.45, 0.45, 0.15), hcf * CFrame.new(0, 0.76, -0.92), theme.AccentColor, Enum.Material.Metal, head, model)
		makeAttachedPart("ChestBadge", Vector3.new(0.45, 0.55, 0.15), tcf * CFrame.new(-0.6, 0.45, -0.78), theme.AccentColor, Enum.Material.Metal, torsoPart, model)
		makeAttachedPart("EpauletteL", Vector3.new(0.85, 0.2, 0.9), tcf * CFrame.new(-1.35, 0.95, 0), Color3.fromRGB(22, 30, 58), Enum.Material.Fabric, torsoPart, model)
		makeAttachedPart("EpauletteR", Vector3.new(0.85, 0.2, 0.9), tcf * CFrame.new(1.35, 0.95, 0), Color3.fromRGB(22, 30, 58), Enum.Material.Fabric, torsoPart, model)
		makeAttachedPart("Batuta", Vector3.new(0.35, 0.35, 2.6), handPart.CFrame * CFrame.new(0, -0.2, -1.0), Color3.fromRGB(25, 25, 32), Enum.Material.Metal, handPart, model)
	end
end

local function buildQuadrupedDogRig(stats: EnemyData.EnemyStats, zone: string): (Model, Humanoid, BasePart, BasePart)
	local model = Instance.new("Model")
	local isCyber = (zone == "Zone3")
	local furColor = if isCyber then Color3.fromRGB(28, 25, 38) else stats.BodyColor
	local darkShade = if isCyber then Color3.fromRGB(16, 14, 24) else Color3.fromRGB(70, 42, 22)
	local accentColor = if isCyber then Color3.fromRGB(185, 70, 255) else Color3.fromRGB(185, 130, 80)
	local collarColor = if isCyber then Color3.fromRGB(0, 245, 225) else Color3.fromRGB(210, 35, 35)
	local eyeColor = if isCyber then Color3.fromRGB(255, 50, 180) else Color3.fromRGB(255, 180, 35)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2.2, 2.2, 3.4)
	root.Transparency = 1
	root.Anchored = false
	root.CanCollide = true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model

	local rcf = root.CFrame

	makeAttachedPart("TorsoBody", Vector3.new(1.7, 1.4, 3.0), rcf * CFrame.new(0, 0.1, 0.1), furColor, Enum.Material.SmoothPlastic, root, model)
	makeAttachedPart("Chest", Vector3.new(1.8, 1.5, 1.2), rcf * CFrame.new(0, 0.2, -1.0), darkShade, Enum.Material.SmoothPlastic, root, model)
	makeAttachedPart("Collar", Vector3.new(1.9, 0.4, 0.45), rcf * CFrame.new(0, 0.65, -1.45) * CFrame.Angles(math.rad(25), 0, 0), collarColor, Enum.Material.Neon, root, model)

	local head = makeAttachedPart("Head", Vector3.new(1.5, 1.35, 1.45), rcf * CFrame.new(0, 1.05, -1.85), furColor, Enum.Material.SmoothPlastic, root, model)
	makeAttachedPart("Snout", Vector3.new(0.95, 0.7, 1.0), rcf * CFrame.new(0, 0.85, -2.75), accentColor, Enum.Material.SmoothPlastic, root, model)
	makeAttachedPart("Nose", Vector3.new(0.4, 0.3, 0.25), rcf * CFrame.new(0, 1.08, -3.26), Color3.fromRGB(20, 20, 22), Enum.Material.SmoothPlastic, root, model)
	makeAttachedPart("EarL", Vector3.new(0.4, 0.85, 0.45), rcf * CFrame.new(-0.55, 1.9, -1.75) * CFrame.Angles(math.rad(15), 0, math.rad(10)), darkShade, Enum.Material.SmoothPlastic, root, model)
	makeAttachedPart("EarR", Vector3.new(0.4, 0.85, 0.45), rcf * CFrame.new(0.55, 1.9, -1.75) * CFrame.Angles(math.rad(15), 0, math.rad(-10)), darkShade, Enum.Material.SmoothPlastic, root, model)
	makeAttachedPart("EyeL", Vector3.new(0.24, 0.22, 0.15), rcf * CFrame.new(-0.42, 1.25, -2.56), eyeColor, Enum.Material.Neon, root, model)
	makeAttachedPart("EyeR", Vector3.new(0.24, 0.22, 0.15), rcf * CFrame.new(0.42, 1.25, -2.56), eyeColor, Enum.Material.Neon, root, model)

	if isCyber then
		makeAttachedPart("CyberSpine", Vector3.new(0.3, 0.45, 2.4), rcf * CFrame.new(0, 0.95, 0.2), accentColor, Enum.Material.Neon, root, model)
	end

	local legOffsets = {
		Vector3.new(-0.62, -0.9, -1.05),
		Vector3.new(0.62, -0.9, -1.05),
		Vector3.new(-0.62, -0.9, 1.15),
		Vector3.new(0.62, -0.9, 1.15),
	}
	for idx, lo in legOffsets do
		makeAttachedPart(`Leg{idx}`, Vector3.new(0.5, 1.3, 0.55), rcf * CFrame.new(lo), furColor, Enum.Material.SmoothPlastic, root, model)
		makeAttachedPart(`Paw{idx}`, Vector3.new(0.55, 0.3, 0.7), rcf * CFrame.new(lo + Vector3.new(0, -0.6, -0.1)), accentColor, Enum.Material.SmoothPlastic, root, model)
	end

	makeAttachedPart("Tail", Vector3.new(0.38, 0.38, 1.4), rcf * CFrame.new(0, 0.75, 2.0) * CFrame.Angles(math.rad(35), 0, 0), if isCyber then accentColor else darkShade, if isCyber then Enum.Material.Neon else Enum.Material.SmoothPlastic, root, model)

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 0.65
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.Parent = model

	model.PrimaryPart = root
	local dogTitle = if isCyber then "🐕‍🦺 BANTAY ASO" else "🐕 ASPIN"
	addNameTag(head, dogTitle, if isCyber then Color3.fromRGB(255, 195, 65) else Color3.fromRGB(255, 185, 95))
	return model, humanoid, root, head
end

local function buildFallbackWardenRig(theme: WardenTheme): Model
	local model = Instance.new("Model")
	local scale = theme.Scale

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 4, 1) * scale
	root.Color = theme.ShirtColor
	root.Anchored = false
	root.CanCollide = true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.5, 1.5) * scale
	head.Color = theme.SkinColor
	head.CFrame = root.CFrame * CFrame.new(0, 2.75 * scale, 0)
	head.Anchored = false
	head.CanCollide = false
	head.TopSurface = Enum.SurfaceType.Smooth
	head.BottomSurface = Enum.SurfaceType.Smooth
	head.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = head

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2 * scale
	humanoid.Parent = model

	model.PrimaryPart = root
	return model
end

local function createEnemyRig(enemyType: string, zone: string, stats: EnemyData.EnemyStats): (Model, Humanoid, BasePart, BasePart)
	if enemyType == "Dog" then
		return buildQuadrupedDogRig(stats, zone)
	end

	local theme = WARDEN_THEMES[zone] or WARDEN_THEMES.Zone1

	local description = Instance.new("HumanoidDescription")
	description.HeightScale = theme.Scale
	description.WidthScale = theme.Scale
	description.DepthScale = theme.Scale
	description.HeadScale = theme.Scale
	description.HeadColor = theme.SkinColor
	description.LeftArmColor = theme.ShirtColor
	description.RightArmColor = theme.ShirtColor
	description.TorsoColor = theme.ShirtColor
	description.LeftLegColor = theme.PantsColor
	description.RightLegColor = theme.PantsColor

	local ok, created = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	description:Destroy()

	local model: Model
	if ok and created and created:IsA("Model") then
		model = created
	else
		model = buildFallbackWardenRig(theme)
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	if not humanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		model = buildFallbackWardenRig(theme)
		humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		root = model:FindFirstChild("HumanoidRootPart") :: BasePart
		head = model:FindFirstChild("Head") :: BasePart
	end

	local headPart: BasePart = if head and head:IsA("BasePart") then head else root :: BasePart
	local hum = humanoid :: Humanoid
	local rootPart = root :: BasePart

	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = false
		end
	end

	decorateWardenByZone(model, headPart, rootPart, zone, theme)
	addNameTag(headPart, theme.Title, theme.TagColor)
	return model, hum, rootPart, headPart
end

-- Helpers -------------------------------------------------------------------

local function getEnemiesFolder(): Folder
	local existing = workspace:FindFirstChild("Enemies")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace
	return folder
end

local function isPlayerCarryingAnything(player: Player): (boolean, Model?)
	if CageService.IsCarrying(player) then
		if CageService.IsSecured(player) then
			return false, nil
		end
		return true, CageService.GetCarriedCage(player)
	end
	if extraCarryingCheck then
		return extraCarryingCheck(player)
	end
	return false, nil
end

local function isInsidePrison(pos: Vector3): boolean
	return pos.Z <= Config.SafeZoneZ and math.abs(pos.X) <= 41
end

local function getPlayerRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getEffectiveSightRange(enemy: Enemy, player: Player): number
	local mult = if sightMultiplierGetter then sightMultiplierGetter(player, enemy.EnemyType) else 1
	return enemy.Stats.SightRange * mult
end

local function hasLineOfSight(enemy: Enemy, player: Player, targetRoot: BasePart): boolean
	local character = player.Character
	if not character then
		return false
	end

	local filter: { Instance } = { enemy.Model, character }
	local _, carriedModel = isPlayerCarryingAnything(player)
	if carriedModel then
		table.insert(filter, carriedModel)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = true

	local origin = enemy.Head.Position
	local direction = targetRoot.Position - origin
	local result = workspace:Raycast(origin, direction, params)
	return result == nil
end

local function findTarget(enemy: Enemy): Player?
	local bestPlayer: Player? = nil
	local bestDist = math.huge

	for _, player in Players:GetPlayers() do
		local carryingNow = isPlayerCarryingAnything(player)
		if carryingNow then
			local sightRange = getEffectiveSightRange(enemy, player)
			if sightRange > 0 then
				local targetRoot = getPlayerRoot(player)
				if targetRoot and isInsidePrison(targetRoot.Position) then
					local dist = (targetRoot.Position - enemy.Root.Position).Magnitude
					if dist <= sightRange and dist < bestDist and hasLineOfSight(enemy, player, targetRoot) then
						bestDist = dist
						bestPlayer = player
					end
				end
			end
		end
	end

	return bestPlayer
end

local function pickPatrolPoint(zone: string, currentTarget: Vector3?): Vector3?
	local points: { Vector3 } = {}
	for _, inst in CollectionService:GetTagged("PatrolPoint") do
		if inst:IsA("BasePart") and inst:IsDescendantOf(workspace) and inst:GetAttribute("Zone") == zone then
			table.insert(points, inst.Position)
		end
	end
	if #points == 0 then
		return nil
	end
	if #points == 1 then
		return points[1]
	end

	local candidates: { Vector3 } = {}
	for _, pos in points do
		if not currentTarget or (pos - currentTarget).Magnitude > 1 then
			table.insert(candidates, pos)
		end
	end
	local list = if #candidates > 0 then candidates else points
	return list[rng:NextInteger(1, #list)]
end

local function updateBeingChasedAttributes()
	local counts: { [Player]: number } = {}
	for _, enemy in enemies do
		if enemy.State == "Chase" and enemy.Target and enemy.Model.Parent then
			counts[enemy.Target] = (counts[enemy.Target] or 0) + 1
		end
	end
	for _, player in Players:GetPlayers() do
		local chased = (counts[player] or 0) > 0
		if player:GetAttribute("BeingChased") ~= chased then
			player:SetAttribute("BeingChased", chased)
		end
	end
end

-- State transitions ---------------------------------------------------------

local function enterPatrol(enemy: Enemy, now: number)
	local wasChase = enemy.State == "Chase"
	enemy.State = "Patrol"
	enemy.Target = nil
	enemy.Waypoints = {}
	enemy.WaypointIndex = 1
	enemy.LastPathTargetPos = nil
	enemy.PatrolTargetPos = nil
	enemy.PatrolWaitUntil = now
	enemy.Humanoid.WalkSpeed = enemy.Stats.WalkSpeed * enemy.SpeedMultiplier
	if wasChase then
		updateBeingChasedAttributes()
	end
end

local function enterChase(enemy: Enemy, target: Player, now: number)
	enemy.State = "Chase"
	enemy.Target = target
	enemy.ChaseStartedAt = now
	enemy.LastSawTargetAt = now
	enemy.NextPathRecomputeAt = 0
	enemy.LastPathTargetPos = nil
	enemy.Waypoints = {}
	enemy.WaypointIndex = 1
	enemy.PatrolTargetPos = nil
	enemy.Humanoid.WalkSpeed = enemy.Stats.ChaseSpeed * enemy.SpeedMultiplier
	updateBeingChasedAttributes()
end

local function enterStunned(enemy: Enemy, now: number)
	enemy.State = "Stunned"
	enemy.Target = nil
	enemy.Waypoints = {}
	enemy.WaypointIndex = 1
	enemy.LastPathTargetPos = nil
	enemy.StunEndsAt = now + enemy.Stats.StunSeconds
	enemy.Humanoid.WalkSpeed = 0
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	updateBeingChasedAttributes()
end

function EnemyService.FreezeNearby(position: Vector3, radius: number, durationSeconds: number): number
	local now = os.clock()
	local count = 0
	for _, enemy in enemies do
		if enemy.Root.Parent and (enemy.Root.Position - position).Magnitude <= radius then
			enemy.FrozenUntil = math.max(enemy.FrozenUntil, now + durationSeconds)
			enemy.Humanoid.WalkSpeed = 0
			enemy.Humanoid:MoveTo(enemy.Root.Position)
			count += 1
		end
	end
	return count
end

-- Slaps/stuns any Guard or Dog within the attacker's Pamalo reach & front cone!
function EnemyService.SlapEnemiesInCone(
	attackerPos: Vector3,
	lookVector: Vector3,
	reach: number,
	knockback: number,
	stunSeconds: number,
	isAoE: boolean
): { BasePart }
	local now = os.clock()
	local hitRoots: { BasePart } = {}

	for _, enemy in enemies do
		if enemy.Root.Parent then
			local delta = enemy.Root.Position - attackerPos
			local flatDelta = Vector3.new(delta.X, 0, delta.Z)
			local dist = flatDelta.Magnitude
			if dist <= reach + 2.0 then
				local dir = if dist > 0.05 then flatDelta.Unit else lookVector
				local dot = dir:Dot(Vector3.new(lookVector.X, 0, lookVector.Z).Unit)
				if dist <= 3.5 or dot >= (if isAoE then 0.15 else 0.35) then
					enemy.FrozenUntil = math.max(enemy.FrozenUntil, now + stunSeconds)
					enterStunned(enemy, now)
					enemy.StunEndsAt = math.max(enemy.StunEndsAt, now + stunSeconds)
					enemy.Root.AssemblyLinearVelocity = dir * knockback + Vector3.new(0, 14, 0)
					table.insert(hitRoots, enemy.Head)
					if not isAoE then
						break
					end
				end
			end
		end
	end

	return hitRoots
end

-- Pathfinding ---------------------------------------------------------------

local function recomputeChasePath(enemy: Enemy, targetPos: Vector3)
	local path = PathfindingService:CreatePath({
		AgentRadius = EnemyData.AgentRadius,
		AgentHeight = EnemyData.AgentHeight,
		AgentCanJump = EnemyData.AgentCanJump,
	})

	local ok = pcall(function()
		path:ComputeAsync(enemy.Root.Position, targetPos)
	end)

	if ok and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		enemy.Waypoints = waypoints
		enemy.WaypointIndex = if #waypoints >= 2 then 2 else 1
		enemy.LastPathTargetPos = targetPos
	else
		enemy.Waypoints = {}
		enemy.WaypointIndex = 1
		enemy.LastPathTargetPos = targetPos
		enemy.Humanoid:MoveTo(targetPos)
	end
end

local function followWaypoints(enemy: Enemy, fallbackPos: Vector3)
	local waypoints = enemy.Waypoints
	local idx = enemy.WaypointIndex
	if #waypoints == 0 or idx > #waypoints then
		enemy.Humanoid:MoveTo(fallbackPos)
		return
	end

	local wp = waypoints[idx]
	local flatDelta = Vector3.new(wp.Position.X - enemy.Root.Position.X, 0, wp.Position.Z - enemy.Root.Position.Z)
	if flatDelta.Magnitude <= EnemyData.WaypointReachDistance then
		idx += 1
		enemy.WaypointIndex = idx
		if idx > #waypoints then
			enemy.Humanoid:MoveTo(fallbackPos)
			return
		end
		wp = waypoints[idx]
	end

	if wp.Action == Enum.PathWaypointAction.Jump then
		enemy.Humanoid.Jump = true
	end
	enemy.Humanoid:MoveTo(wp.Position)
end

-- Per-enemy tick ------------------------------------------------------------

local function stepEnemy(enemy: Enemy, now: number)
	if not enemy.Model.Parent or not enemy.Root.Parent then
		return
	end

	if enemy.Root.Position.Y < EnemyData.FallResetY or not isInsidePrison(enemy.Root.Position) then
		enemy.Model:PivotTo(enemy.SpawnCFrame)
		enemy.LastProgressPos = enemy.SpawnCFrame.Position
		enemy.LastProgressAt = now
		enterPatrol(enemy, now)
		return
	end

	if now < enemy.FrozenUntil then
		enemy.Humanoid.WalkSpeed = 0
		return
	end

	if enemy.State == "Stunned" then
		if now >= enemy.StunEndsAt then
			enemy.ReChaseAvailableAt = now + enemy.Stats.ReChaseCooldownSeconds
			enterPatrol(enemy, now)
		end
		return
	end

	if enemy.State == "Patrol" then
		enemy.Humanoid.WalkSpeed = enemy.Stats.WalkSpeed * enemy.SpeedMultiplier
		if now >= enemy.NextDetectionAt and now >= enemy.ReChaseAvailableAt then
			enemy.NextDetectionAt = now + EnemyData.DetectionIntervalSeconds
			local target = findTarget(enemy)
			if target then
				enterChase(enemy, target, now)
				return
			end
		end

		if not enemy.PatrolTargetPos then
			enemy.LastProgressPos = enemy.Root.Position
			enemy.LastProgressAt = now
			if now >= enemy.PatrolWaitUntil then
				local nextPos = pickPatrolPoint(enemy.Zone, nil)
				if nextPos then
					enemy.PatrolTargetPos = nextPos
					recomputeChasePath(enemy, nextPos)
				else
					enemy.PatrolWaitUntil = now + EnemyData.PatrolWaitSeconds
				end
			end
		else
			if (enemy.Root.Position - enemy.LastProgressPos).Magnitude > 1.5 then
				enemy.LastProgressPos = enemy.Root.Position
				enemy.LastProgressAt = now
			elseif (now - enemy.LastProgressAt) > 4.0 then
				enemy.Model:PivotTo(enemy.SpawnCFrame)
				enemy.LastProgressPos = enemy.SpawnCFrame.Position
				enemy.LastProgressAt = now
				enemy.PatrolTargetPos = nil
				enemy.PatrolWaitUntil = now + 0.5
				return
			end

			local targetPos = enemy.PatrolTargetPos
			local flatDelta = Vector3.new(targetPos.X - enemy.Root.Position.X, 0, targetPos.Z - enemy.Root.Position.Z)
			if flatDelta.Magnitude <= EnemyData.WaypointReachDistance then
				enemy.PatrolWaitUntil = now + EnemyData.PatrolWaitSeconds
				local waitPos = enemy.Root.Position
				enemy.PatrolTargetPos = nil
				enemy.Waypoints = {}
				enemy.Humanoid:MoveTo(waitPos)
			else
				followWaypoints(enemy, targetPos)
			end
		end
		return
	end

	-- State == "Chase"
	local target = enemy.Target
	if not target or not isPlayerCarryingAnything(target) then
		enterPatrol(enemy, now)
		return
	end

	local targetRoot = getPlayerRoot(target)
	if not targetRoot or not isInsidePrison(targetRoot.Position) then
		enterPatrol(enemy, now)
		return
	end

	local effectiveSight = getEffectiveSightRange(enemy, target)
	if now >= enemy.NextDetectionAt then
		enemy.NextDetectionAt = now + EnemyData.DetectionIntervalSeconds
		if effectiveSight > 0 and hasLineOfSight(enemy, target, targetRoot) then
			enemy.LastSawTargetAt = now
		end
	end

	if effectiveSight <= 0 or (now - enemy.LastSawTargetAt) >= enemy.Stats.LoseSightSeconds then
		enterPatrol(enemy, now)
		return
	end

	local dist = (targetRoot.Position - enemy.Root.Position).Magnitude
	if dist <= enemy.Stats.CatchDistance then
		if CageService.IsCarrying(target) then
			CageService.DropCage(target, "caught")
		elseif extraCatchHandler then
			extraCatchHandler(target)
		end
		enterStunned(enemy, now)
		return
	end

	local speed = enemy.Stats.ChaseSpeed * enemy.SpeedMultiplier
	if enemy.Stats.BoostAfterSeconds > 0 and (now - enemy.ChaseStartedAt) >= enemy.Stats.BoostAfterSeconds then
		speed *= enemy.Stats.BoostMultiplier
	end
	enemy.Humanoid.WalkSpeed = speed

	local targetPos = targetRoot.Position
	if now >= enemy.NextPathRecomputeAt then
		enemy.NextPathRecomputeAt = now + EnemyData.PathRecomputeSeconds
		local lastPos = enemy.LastPathTargetPos
		if not lastPos or (targetPos - lastPos).Magnitude > EnemyData.TargetMoveThreshold or #enemy.Waypoints == 0 then
			recomputeChasePath(enemy, targetPos)
		end
	end

	followWaypoints(enemy, targetPos)
end

-- Spawning ------------------------------------------------------------------

function EnemyService.SpawnTemporaryEnemy(enemyType: string, zone: string, cframe: CFrame, speedMultiplier: number): Model?
	local stats = EnemyData.Get(enemyType)
	if not stats then
		return nil
	end

	local model, humanoid, root, head = createEnemyRig(enemyType, zone, stats)
	model.Name = `{enemyType}_{zone}`
	model:PivotTo(cframe)
	model.Parent = getEnemiesFolder()

	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local now = os.clock()
	local enemy: Enemy = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Head = head,
		EnemyType = enemyType,
		Stats = stats,
		Zone = zone,
		SpeedMultiplier = speedMultiplier,
		SpawnCFrame = cframe,

		State = "Patrol",
		Target = nil,
		ChaseStartedAt = 0,
		LastSawTargetAt = 0,
		StunEndsAt = 0,
		FrozenUntil = 0,
		ReChaseAvailableAt = 0,

		NextDetectionAt = now,
		NextPathRecomputeAt = 0,
		LastPathTargetPos = nil,
		Waypoints = {},
		WaypointIndex = 1,

		PatrolTargetPos = nil,
		PatrolWaitUntil = now,
		LastProgressPos = cframe.Position,
		LastProgressAt = now,
	}

	enterPatrol(enemy, now)
	table.insert(enemies, enemy)
	return model
end

local function setupSpawn(instance: Instance)
	if setupDone[instance] then
		return
	end
	if not instance:IsA("BasePart") or not instance:IsDescendantOf(workspace) then
		return
	end

	local enemyType = instance:GetAttribute("EnemyType")
	local zone = instance:GetAttribute("Zone")
	if typeof(enemyType) ~= "string" or typeof(zone) ~= "string" then
		warn(`EnemySpawn "{instance.Name}" requires string attributes EnemyType and Zone`)
		return
	end

	local stats = EnemyData.Get(enemyType)
	if not stats then
		warn(`EnemySpawn "{instance.Name}" has unknown EnemyType "{enemyType}"`)
		return
	end

	local rawMult = instance:GetAttribute("SpeedMultiplier")
	local speedMultiplier = if typeof(rawMult) == "number" and rawMult > 0 then rawMult else 1

	setupDone[instance] = true
	instance.Destroying:Connect(function()
		setupDone[instance] = nil
	end)

	EnemyService.SpawnTemporaryEnemy(enemyType, zone, instance.CFrame, speedMultiplier)
end

function EnemyService.Init()
	local folder = getEnemiesFolder()
	folder:ClearAllChildren()

	for _, instance in CollectionService:GetTagged("EnemySpawn") do
		task.spawn(setupSpawn, instance)
	end
	CollectionService:GetInstanceAddedSignal("EnemySpawn"):Connect(function(instance)
		task.spawn(setupSpawn, instance)
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for i = #enemies, 1, -1 do
			local enemy = enemies[i]
			if not enemy.Model.Parent then
				table.remove(enemies, i)
			else
				stepEnemy(enemy, now)
			end
		end
	end)
end

return EnemyService
