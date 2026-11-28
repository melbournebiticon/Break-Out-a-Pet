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
local Remotes = require(Shared:WaitForChild("Remotes"))
local CageService = require(script.Parent:WaitForChild("CageService"))

type EnemyState = "Sleep" | "Waking" | "Chase" | "Stunned"

type Enemy = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Head: BasePart,
	NameLabel: TextLabel?,
	EnemyType: string,
	DisplayTitle: string,
	TagColor: Color3,
	Stats: EnemyData.EnemyStats,
	Zone: string,
	BaseWalkSpeed: number,
	BaseChaseSpeed: number,
	SpeedMultiplier: number,
	SpawnCFrame: CFrame,

	State: EnemyState,
	Target: Player?,
	ChaseStartedAt: number,
	WakingEndsAt: number,
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

local ZONE_BOUNDS: { [string]: { MinZ: number, MaxZ: number, RequiredSpeedStat: number, WalkSpeed: number, ChaseSpeed: number } } = {
	Zone1 = { MinZ = -200, MaxZ = -48, RequiredSpeedStat = 900, WalkSpeed = 13.0, ChaseSpeed = 16.5 },
	Zone2 = { MinZ = -350, MaxZ = -200, RequiredSpeedStat = 3500, WalkSpeed = 15.0, ChaseSpeed = 20.5 },
	Zone3 = { MinZ = -500, MaxZ = -350, RequiredSpeedStat = 10000, WalkSpeed = 17.0, ChaseSpeed = 24.0 },
	Zone4 = { MinZ = -650, MaxZ = -500, RequiredSpeedStat = 25000, WalkSpeed = 19.0, ChaseSpeed = 27.5 },
	Zone5 = { MinZ = -800, MaxZ = -650, RequiredSpeedStat = 60000, WalkSpeed = 21.0, ChaseSpeed = 30.5 },
	Zone6 = { MinZ = -950, MaxZ = -800, RequiredSpeedStat = 140000, WalkSpeed = 23.0, ChaseSpeed = 33.5 },
	Zone7 = { MinZ = -1100, MaxZ = -950, RequiredSpeedStat = 320000, WalkSpeed = 25.0, ChaseSpeed = 36.5 },
	Zone8 = { MinZ = -1255, MaxZ = -1100, RequiredSpeedStat = 750000, WalkSpeed = 27.0, ChaseSpeed = 39.5 },
	Zone9 = { MinZ = -1400, MaxZ = -1255, RequiredSpeedStat = 1700000, WalkSpeed = 29.0, ChaseSpeed = 42.5 },
	Zone10 = { MinZ = -1550, MaxZ = -1400, RequiredSpeedStat = 3800000, WalkSpeed = 31.0, ChaseSpeed = 45.5 },
	Zone11 = { MinZ = -1700, MaxZ = -1550, RequiredSpeedStat = 8500000, WalkSpeed = 33.0, ChaseSpeed = 48.5 },
	Zone12 = { MinZ = -1850, MaxZ = -1700, RequiredSpeedStat = 19000000, WalkSpeed = 36.0, ChaseSpeed = 52.0 },
	Zone13 = { MinZ = -2000, MaxZ = -1850, RequiredSpeedStat = 42000000, WalkSpeed = 38.0, ChaseSpeed = 55.0 },
	Zone14 = { MinZ = -2150, MaxZ = -2000, RequiredSpeedStat = 95000000, WalkSpeed = 40.0, ChaseSpeed = 58.0 },
	Zone15 = { MinZ = -2300, MaxZ = -2150, RequiredSpeedStat = 210000000, WalkSpeed = 42.0, ChaseSpeed = 61.0 },
	Zone16 = { MinZ = -2450, MaxZ = -2300, RequiredSpeedStat = 460000000, WalkSpeed = 44.0, ChaseSpeed = 64.0 },
	Zone17 = { MinZ = -2600, MaxZ = -2450, RequiredSpeedStat = 1000000000, WalkSpeed = 46.0, ChaseSpeed = 67.0 },
	Zone18 = { MinZ = -2750, MaxZ = -2600, RequiredSpeedStat = 2200000000, WalkSpeed = 48.0, ChaseSpeed = 70.0 },
	Zone19 = { MinZ = -2900, MaxZ = -2750, RequiredSpeedStat = 5000000000, WalkSpeed = 50.0, ChaseSpeed = 73.0 },
	Zone20 = { MinZ = -3055, MaxZ = -2900, RequiredSpeedStat = 12000000000, WalkSpeed = 52.0, ChaseSpeed = 76.0 },
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
	Zone9 = {
		Title = "⚡ THOR GUARD",
		TagColor = Color3.fromRGB(120, 215, 255),
		SkinColor = Color3.fromRGB(215, 180, 145),
		ShirtColor = Color3.fromRGB(45, 65, 115),
		PantsColor = Color3.fromRGB(28, 36, 62),
		AccentColor = Color3.fromRGB(120, 215, 255),
		EyeColor = Color3.fromRGB(165, 245, 255),
		Scale = 1.66,
	},
	Zone10 = {
		Title = "🔱 TITAN WARDEN",
		TagColor = Color3.fromRGB(255, 175, 55),
		SkinColor = Color3.fromRGB(195, 155, 95),
		ShirtColor = Color3.fromRGB(145, 105, 35),
		PantsColor = Color3.fromRGB(75, 55, 25),
		AccentColor = Color3.fromRGB(255, 205, 65),
		EyeColor = Color3.fromRGB(255, 195, 45),
		Scale = 1.72,
	},
	Zone11 = {
		Title = "🐉 DRAGON GUARD",
		TagColor = Color3.fromRGB(255, 65, 85),
		SkinColor = Color3.fromRGB(115, 32, 38),
		ShirtColor = Color3.fromRGB(65, 18, 24),
		PantsColor = Color3.fromRGB(32, 12, 16),
		AccentColor = Color3.fromRGB(255, 95, 45),
		EyeColor = Color3.fromRGB(255, 205, 45),
		Scale = 1.78,
	},
	Zone12 = {
		Title = "👑 BATHALA SENTINEL",
		TagColor = Color3.fromRGB(255, 235, 115),
		SkinColor = Color3.fromRGB(255, 215, 115),
		ShirtColor = Color3.fromRGB(42, 32, 85),
		PantsColor = Color3.fromRGB(25, 18, 55),
		AccentColor = Color3.fromRGB(165, 255, 255),
		EyeColor = Color3.fromRGB(255, 255, 255),
		Scale = 1.85,
	},
	Zone13 = {
		Title = "❄️ FROST GIANT",
		TagColor = Color3.fromRGB(145, 235, 255),
		SkinColor = Color3.fromRGB(175, 225, 255),
		ShirtColor = Color3.fromRGB(45, 95, 145),
		PantsColor = Color3.fromRGB(28, 55, 92),
		AccentColor = Color3.fromRGB(185, 248, 255),
		EyeColor = Color3.fromRGB(0, 245, 255),
		Scale = 1.88,
	},
	Zone14 = {
		Title = "🏜️ PHARAOH GUARD",
		TagColor = Color3.fromRGB(255, 215, 65),
		SkinColor = Color3.fromRGB(195, 145, 85),
		ShirtColor = Color3.fromRGB(215, 165, 35),
		PantsColor = Color3.fromRGB(42, 35, 28),
		AccentColor = Color3.fromRGB(0, 215, 235),
		EyeColor = Color3.fromRGB(255, 215, 55),
		Scale = 1.90,
	},
	Zone15 = {
		Title = "🌊 ABYSSAL TRITON",
		TagColor = Color3.fromRGB(0, 255, 215),
		SkinColor = Color3.fromRGB(45, 165, 175),
		ShirtColor = Color3.fromRGB(18, 75, 95),
		PantsColor = Color3.fromRGB(14, 48, 65),
		AccentColor = Color3.fromRGB(0, 255, 205),
		EyeColor = Color3.fromRGB(120, 255, 235),
		Scale = 1.92,
	},
	Zone16 = {
		Title = "⚡ CYBER SHOGUN",
		TagColor = Color3.fromRGB(0, 245, 255),
		SkinColor = Color3.fromRGB(55, 62, 78),
		ShirtColor = Color3.fromRGB(22, 26, 38),
		PantsColor = Color3.fromRGB(15, 18, 28),
		AccentColor = Color3.fromRGB(0, 245, 255),
		EyeColor = Color3.fromRGB(255, 45, 145),
		Scale = 1.94,
	},
	Zone17 = {
		Title = "🩸 HADES OVERLORD",
		TagColor = Color3.fromRGB(255, 75, 45),
		SkinColor = Color3.fromRGB(95, 25, 28),
		ShirtColor = Color3.fromRGB(38, 12, 16),
		PantsColor = Color3.fromRGB(22, 8, 10),
		AccentColor = Color3.fromRGB(255, 95, 25),
		EyeColor = Color3.fromRGB(255, 165, 35),
		Scale = 1.96,
	},
	Zone18 = {
		Title = "☄️ NEBULA ARCHON",
		TagColor = Color3.fromRGB(235, 110, 255),
		SkinColor = Color3.fromRGB(75, 35, 125),
		ShirtColor = Color3.fromRGB(38, 18, 68),
		PantsColor = Color3.fromRGB(22, 12, 42),
		AccentColor = Color3.fromRGB(255, 125, 245),
		EyeColor = Color3.fromRGB(255, 185, 255),
		Scale = 1.98,
	},
	Zone19 = {
		Title = "⏳ CHRONOS KEEPER",
		TagColor = Color3.fromRGB(110, 255, 230),
		SkinColor = Color3.fromRGB(215, 245, 248),
		ShirtColor = Color3.fromRGB(35, 95, 105),
		PantsColor = Color3.fromRGB(22, 58, 65),
		AccentColor = Color3.fromRGB(255, 215, 75),
		EyeColor = Color3.fromRGB(120, 255, 235),
		Scale = 2.00,
	},
	Zone20 = {
		Title = "✨ OMNIVERSE DEITY",
		TagColor = Color3.fromRGB(255, 245, 155),
		SkinColor = Color3.fromRGB(255, 245, 215),
		ShirtColor = Color3.fromRGB(255, 225, 115),
		PantsColor = Color3.fromRGB(235, 235, 250),
		AccentColor = Color3.fromRGB(165, 255, 255),
		EyeColor = Color3.fromRGB(255, 255, 255),
		Scale = 2.05,
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

local function addNameTag(head: BasePart, displayName: string, color: Color3): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "EnemyTag"
	gui.Size = UDim2.fromScale(4.0, 0.9)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.MaxDistance = 45
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
	return label
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
	return pos.Z <= Config.SafeZoneZ and math.abs(pos.X) <= 44.5
end

local function isPositionInZone(pos: Vector3, zone: string): boolean
	if not isInsidePrison(pos) then
		return false
	end
	local bounds = ZONE_BOUNDS[zone]
	if not bounds then
		return true
	end
	return pos.Z >= bounds.MinZ and pos.Z <= bounds.MaxZ
end

local function isPlayerEligibleForZoneEnemy(player: Player, targetRoot: BasePart, zone: string): boolean
	if not isInsidePrison(targetRoot.Position) then
		return false
	end
	local cageZone = player:GetAttribute("CarriedCageZone")
	if typeof(cageZone) == "string" and cageZone ~= "" then
		return cageZone == zone
	end
	return isPositionInZone(targetRoot.Position, zone)
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
				if targetRoot and isPlayerEligibleForZoneEnemy(player, targetRoot, enemy.Zone) then
					local dist = (targetRoot.Position - enemy.Root.Position).Magnitude
					local cageZone = player:GetAttribute("CarriedCageZone")
					local stoleFromThisZone = (typeof(cageZone) == "string" and cageZone == enemy.Zone)
					-- If the player stole a cage from this enemy's zone, keep targeting them even if they outrun SightRange until they reach the Safe Zone!
					if (stoleFromThisZone or dist <= sightRange) and dist < bestDist then
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
	local chaserTitles: { [Player]: string } = {}
	for _, enemy in enemies do
		if enemy.State == "Chase" and enemy.Target and enemy.Model.Parent then
			counts[enemy.Target] = (counts[enemy.Target] or 0) + 1
			if not chaserTitles[enemy.Target] or enemy.EnemyType == "Warden" then
				chaserTitles[enemy.Target] = enemy.DisplayTitle
			end
		end
	end
	for _, player in Players:GetPlayers() do
		local chased = (counts[player] or 0) > 0
		local title = chaserTitles[player] or ""
		if player:GetAttribute("ChaserName") ~= title then
			player:SetAttribute("ChaserName", title)
		end
		if player:GetAttribute("BeingChased") ~= chased then
			player:SetAttribute("BeingChased", chased)
		end
	end
end

-- State transitions ---------------------------------------------------------

local function enterSleep(enemy: Enemy, now: number)
	local wasChase = enemy.State == "Chase"
	enemy.State = "Sleep"
	enemy.Model:SetAttribute("EnemyState", "Sleep")
	enemy.Target = nil
	enemy.Waypoints = {}
	enemy.WaypointIndex = 1
	enemy.LastPathTargetPos = nil
	enemy.PatrolTargetPos = nil
	enemy.PatrolWaitUntil = now
	enemy.Humanoid.WalkSpeed = 0
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	if enemy.NameLabel then
		enemy.NameLabel.Text = `😴 {enemy.DisplayTitle} (Zzz...)`
		enemy.NameLabel.TextColor3 = Color3.fromRGB(180, 210, 255)
	end
	if wasChase then
		updateBeingChasedAttributes()
	end
end

local function enterWaking(enemy: Enemy, target: Player, now: number)
	enemy.State = "Waking"
	enemy.Model:SetAttribute("EnemyState", "Waking")
	enemy.Target = target
	enemy.WakingEndsAt = now + 0.25
	enemy.Waypoints = {}
	enemy.WaypointIndex = 1
	enemy.Humanoid.WalkSpeed = 0
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	if enemy.NameLabel then
		enemy.NameLabel.Text = `❗ NAGISING SI {enemy.DisplayTitle}!`
		enemy.NameLabel.TextColor3 = Color3.fromRGB(255, 225, 65)
	end
	Remotes.GetEvent("EnemyVfx"):FireAllClients("Alert", enemy.Model, enemy.DisplayTitle)
end

local function enterChase(enemy: Enemy, target: Player, now: number)
	enemy.State = "Chase"
	enemy.Model:SetAttribute("EnemyState", "Chase")
	enemy.Target = target
	enemy.ChaseStartedAt = now
	enemy.LastSawTargetAt = now
	enemy.NextPathRecomputeAt = 0
	enemy.LastPathTargetPos = nil
	enemy.Waypoints = {}
	enemy.WaypointIndex = 1
	enemy.PatrolTargetPos = nil
	enemy.LastProgressPos = enemy.Root.Position
	enemy.LastProgressAt = now
	enemy.Humanoid.WalkSpeed = enemy.BaseChaseSpeed
	if enemy.NameLabel then
		enemy.NameLabel.Text = `😡 {enemy.DisplayTitle}`
		enemy.NameLabel.TextColor3 = Color3.fromRGB(255, 85, 85)
	end
	updateBeingChasedAttributes()
end

local function enterStunned(enemy: Enemy, now: number, customStunSeconds: number?)
	local stunDur = if typeof(customStunSeconds) == "number" and customStunSeconds > 0
		then customStunSeconds
		else enemy.Stats.StunSeconds
	enemy.State = "Stunned"
	enemy.Model:SetAttribute("EnemyState", "Stunned")
	enemy.Model:SetAttribute("StunDuration", stunDur)
	enemy.Target = nil
	enemy.Waypoints = {}
	enemy.WaypointIndex = 1
	enemy.LastPathTargetPos = nil
	enemy.StunEndsAt = now + stunDur
	enemy.Humanoid.WalkSpeed = 0
	enemy.Humanoid:MoveTo(enemy.Root.Position)
	if enemy.NameLabel then
		enemy.NameLabel.Text = `💫 {enemy.DisplayTitle}`
		enemy.NameLabel.TextColor3 = enemy.TagColor
	end
	updateBeingChasedAttributes()
	Remotes.GetEvent("EnemyVfx"):FireAllClients("Stun", enemy.Model, stunDur)
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
-- Stunned guards stay in place while knocked down, and immediately resume chasing once they get back up!
function EnemyService.SlapEnemiesInCone(
	attackerPos: Vector3,
	lookVector: Vector3,
	reach: number,
	_knockback: number,
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
					enemy.FrozenUntil = 0
					enterStunned(enemy, now, stunSeconds)
					enemy.StunEndsAt = math.max(enemy.StunEndsAt, now + stunSeconds)
					enemy.Root.AssemblyLinearVelocity = Vector3.zero
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

-- Stuns the closest Guard or Dog hit by a ranged "Sipat" Tsinelas projectile in place!
function EnemyService.SlapNearestEnemyAtPoint(
	point: Vector3,
	hitRadius: number,
	_knockback: number,
	stunSeconds: number,
	_hitDir: Vector3
): BasePart?
	local now = os.clock()
	local bestEnemy: Enemy? = nil
	local bestDist = hitRadius + 1.8

	for _, enemy in enemies do
		if enemy.Root.Parent then
			local delta = enemy.Root.Position - point
			local flatDist = Vector3.new(delta.X, 0, delta.Z).Magnitude
			local dy = math.abs(delta.Y)
			if flatDist <= bestDist and dy <= 6.5 then
				bestDist = flatDist
				bestEnemy = enemy
			end
		end
	end

	if bestEnemy then
		bestEnemy.FrozenUntil = 0
		enterStunned(bestEnemy, now, stunSeconds)
		bestEnemy.StunEndsAt = math.max(bestEnemy.StunEndsAt, now + stunSeconds)
		bestEnemy.Root.AssemblyLinearVelocity = Vector3.zero
		return bestEnemy.Head
	end

	return nil
end

local function tripCaughtPlayer(target: Player, enemyPos: Vector3)
	local character = target.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not hum or not root or not root:IsA("BasePart") or hum.Health <= 0 then
		return
	end

	local away = Vector3.new(root.Position.X - enemyPos.X, 0, root.Position.Z - enemyPos.Z)
	local forwardDir = if away.Magnitude > 0.05 then away.Unit else root.CFrame.LookVector
	forwardDir = Vector3.new(forwardDir.X, 0, forwardDir.Z)
	if forwardDir.Magnitude < 0.05 then
		forwardDir = Vector3.new(0, 0, 1)
	else
		forwardDir = forwardDir.Unit
	end

	-- Popup "💥 NADAPA!" above the player
	local gui = Instance.new("BillboardGui")
	gui.Name = "TripPopup"
	gui.Size = UDim2.fromScale(4.0, 1.3)
	gui.StudsOffset = Vector3.new(0, 3.0, 0)
	gui.MaxDistance = 55
	gui.AlwaysOnTop = true
	gui.Adornee = root

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255, 110, 80)
	lbl.TextStrokeColor3 = Color3.fromRGB(20, 15, 15)
	lbl.TextStrokeTransparency = 0
	lbl.Text = "💥 NADAPA!"
	lbl.Parent = gui
	gui.Parent = root

	task.delay(0.95, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)

	-- Trip face-down ("madadapa") for 1.1s
	hum.PlatformStand = true
	local basePos = root.Position + Vector3.new(0, 0.45, 0)
	root.CFrame = CFrame.new(basePos, basePos + forwardDir) * CFrame.Angles(math.rad(-82), 0, 0)
	root.AssemblyLinearVelocity = forwardDir * 16 + Vector3.new(0, 8, 0)

	task.delay(1.1, function()
		if hum.Parent and root.Parent then
			hum.PlatformStand = false
			root.CFrame = CFrame.new(root.Position + Vector3.new(0, 2.4, 0), root.Position + Vector3.new(0, 2.4, 0) + forwardDir)
		end
	end)
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

	local outOfBounds = enemy.Root.Position.Y < EnemyData.FallResetY or not isInsidePrison(enemy.Root.Position)
	local sleepOutsideZone = enemy.State == "Sleep" and not isPositionInZone(enemy.Root.Position, enemy.Zone)
	if outOfBounds or sleepOutsideZone then
		enemy.Model:PivotTo(enemy.SpawnCFrame)
		enemy.LastProgressPos = enemy.SpawnCFrame.Position
		enemy.LastProgressAt = now
		enterSleep(enemy, now)
		return
	end

	if now < enemy.FrozenUntil then
		enemy.Humanoid.WalkSpeed = 0
		return
	end

	if enemy.State == "Stunned" then
		enemy.Humanoid.WalkSpeed = 0
		if now >= enemy.StunEndsAt then
			enemy.ReChaseAvailableAt = 0
			local resumeTarget = findTarget(enemy)
			if resumeTarget then
				enterChase(enemy, resumeTarget, now)
			else
				enterSleep(enemy, now)
			end
		end
		return
	end

	if enemy.State == "Sleep" then
		enemy.Humanoid.WalkSpeed = 0
		if now >= enemy.NextDetectionAt and now >= enemy.ReChaseAvailableAt then
			enemy.NextDetectionAt = now + EnemyData.DetectionIntervalSeconds
			local target = findTarget(enemy)
			if target then
				enterWaking(enemy, target, now)
				return
			end
		end
		return
	end

	if enemy.State == "Waking" then
		enemy.Humanoid.WalkSpeed = 0
		local target = enemy.Target
		if not target or not isPlayerCarryingAnything(target) then
			enterSleep(enemy, now)
			return
		end
		local targetRoot = getPlayerRoot(target)
		if not targetRoot or not isPlayerEligibleForZoneEnemy(target, targetRoot, enemy.Zone) then
			enterSleep(enemy, now)
			return
		end
		if now >= enemy.WakingEndsAt then
			enterChase(enemy, target, now)
		end
		return
	end

	-- State == "Chase"
	local target = enemy.Target
	if not target or not isPlayerCarryingAnything(target) then
		enterSleep(enemy, now)
		return
	end

	local targetRoot = getPlayerRoot(target)
	if not targetRoot or not isPlayerEligibleForZoneEnemy(target, targetRoot, enemy.Zone) then
		enterSleep(enemy, now)
		return
	end

	local effectiveSight = getEffectiveSightRange(enemy, target)
	if effectiveSight <= 0 then
		enterSleep(enemy, now)
		return
	end

	local dist = (targetRoot.Position - enemy.Root.Position).Magnitude
	if dist <= enemy.Stats.CatchDistance then
		local didCatch = false
		if CageService.IsCarrying(target) then
			didCatch = CageService.DropCage(target, "caught", enemy.DisplayTitle)
		elseif extraCatchHandler then
			extraCatchHandler(target)
			didCatch = true
		end
		if didCatch then
			tripCaughtPlayer(target, enemy.Root.Position)
		end
		enterStunned(enemy, now)
		return
	end

	-- Balanced Chase Speed vs. Player's RequiredSpeedStat & Carried WalkSpeed:
	-- * If player's Speed Stat >= Zone's RequiredSpeedStat, Bantay is capped below the player's carried WalkSpeed (82%..92%) so they can outrun the Bantay!
	-- * If player's Speed Stat < Zone's RequiredSpeedStat, Bantay runs faster than the player (108%..130%) so under-leveled players get caught!
	local zoneBounds = ZONE_BOUNDS[enemy.Zone]
	local reqStat = if zoneBounds then zoneBounds.RequiredSpeedStat else 900
	local playerStatAttr = target:GetAttribute("TotalSpeedStat")
	local playerStat = if typeof(playerStatAttr) == "number" then playerStatAttr else 16
	local targetHum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	local playerCarriedWalkSpeed = if targetHum and targetHum.WalkSpeed > 0 then targetHum.WalkSpeed else 16

	local chaseElapsed = math.max(0, now - enemy.ChaseStartedAt)
	if playerStat >= reqStat then
		local overRatio = math.clamp(playerStat / math.max(1, reqStat), 1, 4)
		-- Right at reqStat (1.0x): Bantay runs at 96%..98.5% of player's WalkSpeed for a thrilling neck-and-neck chase!
		-- At 4x+ reqStat: drops to 84% of player's WalkSpeed.
		local capRatio = 0.96 - ((overRatio - 1) / 3) * 0.12
		local ramp = math.min(0.025, chaseElapsed * 0.003)
		enemy.Humanoid.WalkSpeed = math.max(14, playerCarriedWalkSpeed * (capRatio + ramp))
	else
		local deficit = math.clamp(1 - (playerStat / math.max(1, reqStat)), 0.05, 1)
		local catchMult = 1.07 + deficit * 0.23
		local ramp = math.min(6, chaseElapsed * 0.8)
		enemy.Humanoid.WalkSpeed = math.max(enemy.BaseChaseSpeed, playerCarriedWalkSpeed * catchMult + ramp)
	end

	local targetPos = targetRoot.Position
	-- Direct relentless pursuit along the corridor (prevents PathfindingService waypoint lag from making fast guards turn back toward their zone when outrun!)
	enemy.Humanoid:MoveTo(targetPos)

	if (enemy.Root.Position - enemy.LastProgressPos).Magnitude >= 1.5 then
		enemy.LastProgressPos = enemy.Root.Position
		enemy.LastProgressAt = now
	elseif (now - enemy.LastProgressAt) >= 0.55 then
		enemy.LastProgressPos = enemy.Root.Position
		enemy.LastProgressAt = now
		enemy.Humanoid.Jump = true
	end
end

-- Spawning ------------------------------------------------------------------

function EnemyService.SpawnTemporaryEnemy(enemyType: string, zone: string, cframe: CFrame, speedMultiplier: number): Model?
	local stats = EnemyData.Get(enemyType)
	if not stats then
		return nil
	end

	local model, humanoid, root, head = createEnemyRig(enemyType, zone, stats)
	model.Name = `{enemyType}_{zone}`
	model:SetAttribute("EnemyType", enemyType)
	model:SetAttribute("Zone", zone)
	CollectionService:AddTag(model, "GuardEnemy")
	model:PivotTo(cframe)
	model.Parent = getEnemiesFolder()

	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local theme = WARDEN_THEMES[zone] or WARDEN_THEMES.Zone1
	local displayTitle = if enemyType == "Dog"
		then (if zone == "Zone3" then "🐕‍🦺 BANTAY ASO" else "🐕 ASPIN")
		else theme.Title
	local tagColor = if enemyType == "Dog"
		then (if zone == "Zone3" then Color3.fromRGB(255, 195, 65) else Color3.fromRGB(255, 185, 95))
		else theme.TagColor
	local tagGui = head:FindFirstChild("EnemyTag")
	local nameLabel = if tagGui then tagGui:FindFirstChildOfClass("TextLabel") else nil
	local zonePreset = ZONE_BOUNDS[zone] or ZONE_BOUNDS.Zone1
	local baseWalkSpeed = if enemyType == "Dog" then zonePreset.WalkSpeed + 2.5 else zonePreset.WalkSpeed
	local baseChaseSpeed = if enemyType == "Dog" then zonePreset.ChaseSpeed + 2.5 else zonePreset.ChaseSpeed

	local now = os.clock()
	local enemy: Enemy = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Head = head,
		NameLabel = nameLabel,
		EnemyType = enemyType,
		DisplayTitle = displayTitle,
		TagColor = tagColor,
		Stats = stats,
		Zone = zone,
		BaseWalkSpeed = baseWalkSpeed,
		BaseChaseSpeed = baseChaseSpeed,
		SpeedMultiplier = speedMultiplier,
		SpawnCFrame = cframe,

		State = "Sleep",
		Target = nil,
		ChaseStartedAt = 0,
		WakingEndsAt = 0,
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

	enterSleep(enemy, now)
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
	Remotes.GetEvent("EnemyVfx")
	local folder = getEnemiesFolder()
	folder:ClearAllChildren()

	for _, instance in CollectionService:GetTagged("EnemySpawn") do
		task.spawn(setupSpawn, instance)
	end
	CollectionService:GetInstanceAddedSignal("EnemySpawn"):Connect(function(instance)
		task.spawn(setupSpawn, instance)
	end)

	-- Instant aggro: as soon as a player grabs a cage in a Zone, that Zone's Bantay immediately reacts and chases!
	CageService.CagePickedUp:Connect(function(player: Player)
		local cageZone = player:GetAttribute("CarriedCageZone")
		if typeof(cageZone) ~= "string" or cageZone == "" then
			return
		end
		local now = os.clock()
		local targetRoot = getPlayerRoot(player)
		if not targetRoot or not isInsidePrison(targetRoot.Position) then
			return
		end
		for _, enemy in enemies do
			if enemy.Zone == cageZone and enemy.State == "Sleep" and now >= enemy.FrozenUntil and now >= enemy.ReChaseAvailableAt then
				if getEffectiveSightRange(enemy, player) > 0 then
					enterWaking(enemy, player, now)
				end
			end
		end
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
