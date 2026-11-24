--!strict
-- Blockout.luau (SERVER)
-- Builds the full 6-Zone Tatak Pinoy Corridor (84 studs wide x 900 studs long, Zone1..Zone6),
-- Wooden-Fenced BasePlots, Safe Zone Line, 6-Zone Speed Karatula, Central Fusion Machine,
-- Leaderboard Board, and the 3D Interactive "🏃 TAKBUHAN TREADMILL STATION" in the Lobby!

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CageVisuals = require(Shared:WaitForChild("CageVisuals"))
local PamaloConfig = require(Shared:WaitForChild("PamaloConfig"))
local NumberFormat = require(Shared:WaitForChild("NumberFormat"))

local Blockout = {}

local function makePart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance, mat: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = mat or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeMarker(name: string, position: Vector3, color: Color3, parent: Instance): Part
	local part = makePart(name, Vector3.new(2, 2, 2), position, color, parent)
	part.Transparency = 1
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

local function addSurfaceSign(part: BasePart, face: Enum.NormalId, titleText: string, subText: string, accentColor: Color3)
	local sgui = Instance.new("SurfaceGui")
	sgui.Name = "SurfaceSign"
	sgui.Face = face
	sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sgui.PixelsPerStud = 35
	sgui.Parent = part

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	bg.BorderSizePixel = 0
	bg.Parent = sgui

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor
	stroke.Thickness = 4
	stroke.Parent = bg

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(0.94, if subText ~= "" then 0.56 else 0.84)
	title.Position = UDim2.fromScale(0.03, 0.06)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = accentColor
	title.Text = titleText
	title.Parent = bg

	if subText ~= "" then
		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.fromScale(0.94, 0.34)
		sub.Position = UDim2.fromScale(0.03, 0.62)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.TextColor3 = Color3.fromRGB(230, 235, 245)
		sub.Text = subText
		sub.Parent = bg
	end
end

local function buildSpeedKaratula(parent: Instance, pos: Vector3)
	local signModel = Instance.new("Model")
	signModel.Name = "SpeedGuideKaratula"
	signModel.Parent = parent

	makePart("PostLeft", Vector3.new(0.8, 9, 0.8), pos + Vector3.new(-6.0, 4.5, 0), Color3.fromRGB(95, 65, 40), signModel, Enum.Material.Wood)
	makePart("PostRight", Vector3.new(0.8, 9, 0.8), pos + Vector3.new(6.0, 4.5, 0), Color3.fromRGB(95, 65, 40), signModel, Enum.Material.Wood)
	local board = makePart("SignBoard", Vector3.new(14, 8.5, 0.7), pos + Vector3.new(0, 6.2, 0), Color3.fromRGB(28, 32, 44), signModel, Enum.Material.WoodPlanks)

	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		local sgui = Instance.new("SurfaceGui")
		sgui.Name = "SpeedChart"
		sgui.Face = face
		sgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sgui.PixelsPerStud = 40
		sgui.Parent = board

		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
		bg.BorderSizePixel = 0
		bg.Parent = sgui

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 200, 50)
		stroke.Thickness = 5
		stroke.Parent = bg

		local header = Instance.new("TextLabel")
		header.Size = UDim2.fromScale(0.92, 0.16)
		header.Position = UDim2.fromScale(0.04, 0.03)
		header.BackgroundTransparency = 1
		header.Font = Enum.Font.FredokaOne
		header.TextScaled = true
		header.TextColor3 = Color3.fromRGB(255, 210, 60)
		header.Text = "⚡ RECOMMENDED SPEED ⚡"
		header.Parent = bg

		local lines = {
			{ text = "🌾 Zone 1 (Sabungan):   Speed 16+", color = Color3.fromRGB(145, 235, 110), y = 0.21 },
			{ text = "🏪 Zone 2 (Palengke):   Speed 19+", color = Color3.fromRGB(255, 195, 70), y = 0.34 },
			{ text = "🏛️ Zone 3 (Hacienda):   Speed 22+", color = Color3.fromRGB(255, 140, 85), y = 0.47 },
			{ text = "🌴 Zone 4 (Gubat):      Speed 26+", color = Color3.fromRGB(95, 230, 175), y = 0.60 },
			{ text = "🌋 Zone 5 (Mayon):      Speed 30+", color = Color3.fromRGB(255, 95, 75), y = 0.73 },
			{ text = "👑 Zone 6 (Intramuros): Speed 35+", color = Color3.fromRGB(255, 215, 55), y = 0.86 },
		}
		for _, line in lines do
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(0.90, 0.12)
			lbl.Position = UDim2.fromScale(0.05, line.y)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.FredokaOne
			lbl.TextScaled = true
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.TextColor3 = line.color
			lbl.Text = line.text
			lbl.Parent = bg
		end
	end
end

local function buildDetailedCage(name: string, centerPos: Vector3, zoneName: string, slotIdx: number, accentColor: Color3, parent: Instance)
	local cage = Instance.new("Model")
	cage.Name = name

	local body = makePart("Body", Vector3.new(4.8, 5.0, 4.8), centerPos, Color3.fromRGB(50, 54, 62), cage, Enum.Material.Metal)
	body.Transparency = 1

	local style = CageVisuals.PickStyleForZoneSlot(zoneName, slotIdx)
	CageVisuals.PopulateCageModel(cage, centerPos, style, accentColor)

	cage.PrimaryPart = body
	cage:SetAttribute("Zone", zoneName)
	cage:SetAttribute("CageStyle", style)
	CollectionService:AddTag(cage, "Cage")
	cage.Parent = parent
end

local function buildRoosterTeepee(parent: Instance, pos: Vector3)
	local teepee = Instance.new("Model")
	teepee.Name = "RoosterTeepee"
	teepee.Parent = parent

	local cf = CFrame.new(pos)
	local plankColor = Color3.fromRGB(165, 138, 105)

	local slopeL = makePart("SlopeL", Vector3.new(4.5, 0.25, 5.2), pos, plankColor, teepee, Enum.Material.WoodPlanks)
	slopeL.CFrame = cf * CFrame.new(-1.35, 1.8, 0) * CFrame.Angles(0, 0, math.rad(55))
	local slopeR = makePart("SlopeR", Vector3.new(4.5, 0.25, 5.2), pos, plankColor, teepee, Enum.Material.WoodPlanks)
	slopeR.CFrame = cf * CFrame.new(1.35, 1.8, 0) * CFrame.Angles(0, 0, math.rad(-55))
	makePart("TopBar", Vector3.new(0.35, 0.35, 6.2), pos + Vector3.new(0, 3.65, 0), Color3.fromRGB(120, 85, 48), teepee, Enum.Material.Wood)
end

local function buildZoneArchHeader(parent: Instance, zPos: number, title: string, accentColor: Color3)
	local arch = Instance.new("Model")
	arch.Name = "ZoneArch"
	arch.Parent = parent

	makePart("PillarL", Vector3.new(3, 15, 3), Vector3.new(-40.5, 8, zPos), Color3.fromRGB(55, 45, 35), arch, Enum.Material.Wood)
	makePart("PillarR", Vector3.new(3, 15, 3), Vector3.new(40.5, 8, zPos), Color3.fromRGB(55, 45, 35), arch, Enum.Material.Wood)
	local header = makePart("HeaderSign", Vector3.new(44, 3.4, 1.8), Vector3.new(0, 14.5, zPos), Color3.fromRGB(28, 32, 44), arch, Enum.Material.Metal)
	addSurfaceSign(header, Enum.NormalId.Back, title, "", accentColor)
	addSurfaceSign(header, Enum.NormalId.Front, title, "", accentColor)
end

local function buildPlotFence(plot: Model, centerPos: Vector3, sizeHalf: number)
	local fenceColor = Color3.fromRGB(155, 105, 55)
	makePart("FenceLeft", Vector3.new(1.0, 3.0, sizeHalf * 2), centerPos + Vector3.new(-sizeHalf, 2.0, 0), fenceColor, plot, Enum.Material.Wood)
	makePart("FenceRight", Vector3.new(1.0, 3.0, sizeHalf * 2), centerPos + Vector3.new(sizeHalf, 2.0, 0), fenceColor, plot, Enum.Material.Wood)
	makePart("FenceBack", Vector3.new(sizeHalf * 2, 3.0, 1.0), centerPos + Vector3.new(0, 2.0, sizeHalf), fenceColor, plot, Enum.Material.Wood)
end

local function buildPlotTreadmill(plot: Model, centerPos: Vector3)
	local tm = Instance.new("Model")
	tm.Name = "PlotTreadmill"
	tm:SetAttribute("TreadmillTier", 0)
	tm:SetAttribute("BeltSpeed", 12)
	tm.Parent = plot

	makePart("Platform", Vector3.new(8.5, 0.4, 12.5), centerPos + Vector3.new(0, 0.2, 0), Color3.fromRGB(115, 78, 42), tm, Enum.Material.WoodPlanks)

	local deckCenter = centerPos + Vector3.new(0, 0.65, 0.5)
	local belt = makePart("TreadmillBelt", Vector3.new(5.4, 0.45, 10.2), deckCenter, Color3.fromRGB(45, 38, 32), tm, Enum.Material.SmoothPlastic)
	CollectionService:AddTag(belt, "TreadmillPad")

	-- Scrolling neon belt strips (animated on client based on BeltSpeed!)
	for idx = 1, 5 do
		local zOff = -4.0 + (idx - 1) * 2.0
		local strip = makePart(`Strip{idx}`, Vector3.new(4.4, 0.48, 0.45), deckCenter + Vector3.new(0, 0.02, zOff), Color3.fromRGB(0, 225, 255), tm, Enum.Material.Neon)
		strip.CanCollide = false
		strip:SetAttribute("StripIndex", idx)
	end

	-- Front & back rollers
	local rollerF = makePart("RollerFront", Vector3.new(0.6, 5.2, 0.6), deckCenter + Vector3.new(0, 0, -4.9), Color3.fromRGB(90, 95, 110), tm, Enum.Material.Metal)
	rollerF.Shape = Enum.PartType.Cylinder
	rollerF.CFrame = CFrame.new(deckCenter + Vector3.new(0, 0, -4.9)) * CFrame.Angles(0, 0, math.rad(90))
	local rollerB = makePart("RollerBack", Vector3.new(0.6, 5.2, 0.6), deckCenter + Vector3.new(0, 0, 4.9), Color3.fromRGB(90, 95, 110), tm, Enum.Material.Metal)
	rollerB.Shape = Enum.PartType.Cylinder
	rollerB.CFrame = CFrame.new(deckCenter + Vector3.new(0, 0, 4.9)) * CFrame.Angles(0, 0, math.rad(90))

	makePart("RailL", Vector3.new(0.45, 3.2, 9.2), deckCenter + Vector3.new(-2.7, 1.8, 0), Color3.fromRGB(145, 102, 56), tm, Enum.Material.Wood)
	makePart("RailR", Vector3.new(0.45, 3.2, 9.2), deckCenter + Vector3.new(2.7, 1.8, 0), Color3.fromRGB(145, 102, 56), tm, Enum.Material.Wood)

	-- Tier Upgrade Visual Add-ons (unlocked progressively as Tier increases!)
	local sideGlowL = makePart("TierAddon_SideGlowL", Vector3.new(0.18, 0.35, 9.0), deckCenter + Vector3.new(-2.95, 2.5, 0), Color3.fromRGB(0, 225, 255), tm, Enum.Material.Neon)
	sideGlowL.Transparency = 1
	sideGlowL.CanCollide = false
	local sideGlowR = makePart("TierAddon_SideGlowR", Vector3.new(0.18, 0.35, 9.0), deckCenter + Vector3.new(2.95, 2.5, 0), Color3.fromRGB(0, 225, 255), tm, Enum.Material.Neon)
	sideGlowR.Transparency = 1
	sideGlowR.CanCollide = false

	-- Tier 3+: Overhead Gym Arch & Digital Handlebar
	local archL = makePart("TierAddon_ArchL", Vector3.new(0.55, 6.2, 0.55), deckCenter + Vector3.new(-2.7, 3.2, -2.5), Color3.fromRGB(85, 95, 115), tm, Enum.Material.Metal)
	archL.Transparency = 1
	archL.CanCollide = false
	local archR = makePart("TierAddon_ArchR", Vector3.new(0.55, 6.2, 0.55), deckCenter + Vector3.new(2.7, 3.2, -2.5), Color3.fromRGB(85, 95, 115), tm, Enum.Material.Metal)
	archR.Transparency = 1
	archR.CanCollide = false
	local archTop = makePart("TierAddon_ArchTop", Vector3.new(6.0, 0.55, 0.55), deckCenter + Vector3.new(0, 6.3, -2.5), Color3.fromRGB(0, 225, 255), tm, Enum.Material.Neon)
	archTop.Transparency = 1
	archTop.CanCollide = false

	-- Tier 5+: Twin Turbo Boosters / Exhaust Pipes on the sides
	local turboL = makePart("TierAddon_TurboL", Vector3.new(1.1, 2.6, 2.6), deckCenter + Vector3.new(-3.45, 1.4, 1.5), Color3.fromRGB(255, 135, 45), tm, Enum.Material.Neon)
	turboL.Transparency = 1
	turboL.CanCollide = false
	local turboR = makePart("TierAddon_TurboR", Vector3.new(1.1, 2.6, 2.6), deckCenter + Vector3.new(3.45, 1.4, 1.5), Color3.fromRGB(255, 135, 45), tm, Enum.Material.Neon)
	turboR.Transparency = 1
	turboR.CanCollide = false

	-- Tier 8+: Rear Holo Speed Wings & Crown Finials
	local wingL = makePart("TierAddon_WingL", Vector3.new(0.3, 4.5, 2.2), deckCenter + Vector3.new(-3.3, 3.8, -3.5), Color3.fromRGB(215, 80, 255), tm, Enum.Material.Neon)
	wingL.CFrame = CFrame.new(deckCenter + Vector3.new(-3.3, 3.8, -3.5)) * CFrame.Angles(math.rad(-25), 0, math.rad(20))
	wingL.Transparency = 1
	wingL.CanCollide = false
	local wingR = makePart("TierAddon_WingR", Vector3.new(0.3, 4.5, 2.2), deckCenter + Vector3.new(3.3, 3.8, -3.5), Color3.fromRGB(215, 80, 255), tm, Enum.Material.Neon)
	wingR.CFrame = CFrame.new(deckCenter + Vector3.new(3.3, 3.8, -3.5)) * CFrame.Angles(math.rad(-25), 0, math.rad(-20))
	wingR.Transparency = 1
	wingR.CanCollide = false

	local console = makePart("TreadmillConsole", Vector3.new(5.6, 3.8, 1.1), deckCenter + Vector3.new(0, 2.0, -4.9), Color3.fromRGB(45, 52, 68), tm, Enum.Material.Metal)
	CollectionService:AddTag(console, "PlotTreadmillConsole")

	local header = makePart("TreadmillSign", Vector3.new(8.6, 2.5, 0.8), deckCenter + Vector3.new(0, 4.9, -4.9), Color3.fromRGB(22, 26, 38), tm, Enum.Material.Metal)
	addSurfaceSign(header, Enum.NormalId.Back, "🏃 Tsinelas Lakad Pad (Tier 0)", "+0.20 Speed/sec • Press E to Upgrade!", Color3.fromRGB(80, 230, 255))
	addSurfaceSign(header, Enum.NormalId.Front, "🏃 Tsinelas Lakad Pad (Tier 0)", "+0.20 Speed/sec • Press E to Upgrade!", Color3.fromRGB(80, 230, 255))
end

local function buildPamaloShopStand(lobby: Instance, centerPos: Vector3)
	local stand = Instance.new("Model")
	stand.Name = "TindahanNgPamalo"
	stand.Parent = lobby

	-- Wooden Market Counter + Striped Sari-Sari Awning Roof
	makePart("CounterBase", Vector3.new(26, 3.2, 4.5), centerPos + Vector3.new(0, 1.6, 0), Color3.fromRGB(138, 92, 48), stand, Enum.Material.WoodPlanks)
	makePart("CounterTop", Vector3.new(27, 0.4, 5.2), centerPos + Vector3.new(0, 3.35, 0), Color3.fromRGB(185, 138, 78), stand, Enum.Material.Wood)
	makePart("PostL", Vector3.new(0.8, 9.5, 0.8), centerPos + Vector3.new(-12.2, 4.75, -1.8), Color3.fromRGB(110, 72, 36), stand, Enum.Material.Wood)
	makePart("PostR", Vector3.new(0.8, 9.5, 0.8), centerPos + Vector3.new(12.2, 4.75, -1.8), Color3.fromRGB(110, 72, 36), stand, Enum.Material.Wood)
	makePart("Awning", Vector3.new(27.5, 0.5, 6.2), centerPos + Vector3.new(0, 8.8, -0.2), Color3.fromRGB(215, 55, 45), stand, Enum.Material.Fabric)

	local header = makePart("PamaloSign", Vector3.new(25.5, 2.5, 1.0), centerPos + Vector3.new(0, 10.2, -1.8), Color3.fromRGB(26, 30, 42), stand, Enum.Material.Metal)
	addSurfaceSign(header, Enum.NormalId.Back, "🩴 TINDAHAN NG PAMALO 🧹", "Comedy Slap Tools: Stun Guards & Knock Cages from Players!", Color3.fromRGB(255, 205, 55))
	addSurfaceSign(header, Enum.NormalId.Front, "🩴 TINDAHAN NG PAMALO 🧹", "Comedy Slap Tools: Stun Guards & Knock Cages from Players!", Color3.fromRGB(255, 205, 55))

	-- 5 Tool Pedestals on the counter
	for idx, info in PamaloConfig.OrderedList do
		local xOff = (idx - 3) * 5.0
		local pedPos = centerPos + Vector3.new(xOff, 3.8, 0)
		local ped = makePart(`Pedestal_{info.Id}`, Vector3.new(3.8, 0.5, 3.4), pedPos, Color3.fromRGB(36, 42, 56), stand, Enum.Material.Metal)
		ped:SetAttribute("PamaloId", info.Id)
		CollectionService:AddTag(ped, "PamaloDisplay")

		local priceStr = if info.Cost == 0 then "FREE" else `$${NumberFormat.Short(info.Cost)}`
		addSurfaceSign(ped, Enum.NormalId.Front, `{info.Emoji} {info.DisplayName}`, priceStr, Color3.fromRGB(255, 215, 65))
		addSurfaceSign(ped, Enum.NormalId.Back, `{info.Emoji} {info.DisplayName}`, priceStr, Color3.fromRGB(255, 215, 65))

		local displayModel = Instance.new("Model")
		displayModel.Name = `Display_{info.Id}`
		displayModel.Parent = stand
		PamaloConfig.BuildToolParts(
			info.Id,
			CFrame.new(pedPos + Vector3.new(0, 2.0, 0)) * CFrame.Angles(math.rad(15), math.rad(25), math.rad(-20)),
			displayModel,
			true
		)
	end
end

function Blockout.EnsureMap()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Size = Vector3.new(2048, 20, 2048)
		baseplate.Position = Vector3.new(0, -10, -350)
	end

	local defaultSpawn = workspace:FindFirstChild("SpawnLocation")
	if defaultSpawn and defaultSpawn:IsA("SpawnLocation") then
		defaultSpawn:Destroy()
	end

	local existingPrison = workspace:FindFirstChild("Prison")
	if existingPrison and not existingPrison:GetAttribute("RedesignedV16") then
		existingPrison:Destroy()
		for _, folderName in { "BasePlots", "Lobby", "PatrolPoints", "EnemySpawns", "Enemies" } do
			local f = workspace:FindFirstChild(folderName)
			if f then
				f:Destroy()
			end
		end
	end

	-- 1) 8-ZONE CORRIDOR (84 studs wide x 1200 studs long, Z from -50 to -1250!)
	local prison = workspace:FindFirstChild("Prison")
	if not prison then
		prison = Instance.new("Folder")
		prison.Name = "Prison"
		prison:SetAttribute("RedesignedV16", true)
		prison.Parent = workspace

		local safeLine = makePart("SafeZoneLine", Vector3.new(84, 0.35, 3.5), Vector3.new(0, 0.9, -47.5), Color3.fromRGB(60, 255, 120), prison, Enum.Material.Neon)
		safeLine.CanCollide = false
		addSurfaceSign(safeLine, Enum.NormalId.Top, "🛡️ SAFE ZONE LINE 🛡️", "Cross here with a cage to secure it!", Color3.fromRGB(80, 255, 140))

		buildSpeedKaratula(prison, Vector3.new(54, 0.5, -45))

		-- Corridor side walls spanning the full 1200-stud length (Z = -50 to -1250, center Z = -650)
		makePart("WallLeft", Vector3.new(3, 14, 1202), Vector3.new(-43.5, 7.5, -650), Color3.fromRGB(145, 105, 65), prison, Enum.Material.Brick)
		makePart("WallLeftTop", Vector3.new(3.4, 1.2, 1202), Vector3.new(-43.5, 15.1, -650), Color3.fromRGB(85, 175, 85), prison, Enum.Material.Grass)
		makePart("WallRight", Vector3.new(3, 14, 1202), Vector3.new(43.5, 7.5, -650), Color3.fromRGB(145, 105, 65), prison, Enum.Material.Brick)
		makePart("WallRightTop", Vector3.new(3.4, 1.2, 1202), Vector3.new(43.5, 15.1, -650), Color3.fromRGB(85, 175, 85), prison, Enum.Material.Grass)
		makePart("WallBack", Vector3.new(90, 14, 3), Vector3.new(0, 7.5, -1251), Color3.fromRGB(60, 55, 75), prison, Enum.Material.Brick)

		local zones = {
			{
				name = "Zone1",
				title = "🌾 ZONE 1: BUKID & SABUNGAN (Speed 16+)",
				zCenter = -125,
				archZ = -50,
				color = Color3.fromRGB(105, 155, 82),
				mat = Enum.Material.Grass,
				accent = Color3.fromRGB(145, 235, 110),
				lasers = false,
			},
			{
				name = "Zone2",
				title = "🏪 ZONE 2: PALENGKE & TIANGGE (Speed 19+)",
				zCenter = -275,
				archZ = -200,
				color = Color3.fromRGB(185, 150, 95),
				mat = Enum.Material.Sand,
				accent = Color3.fromRGB(255, 195, 70),
				lasers = false,
			},
			{
				name = "Zone3",
				title = "🏛️ ZONE 3: HACIENDA COMPOUND (Speed 22+)",
				zCenter = -425,
				archZ = -350,
				color = Color3.fromRGB(115, 85, 65),
				mat = Enum.Material.Cobblestone,
				accent = Color3.fromRGB(255, 145, 75),
				lasers = true,
			},
			{
				name = "Zone4",
				title = "🌴 ZONE 4: BOHOL & PALAWAN GUBAT (Speed 26+)",
				zCenter = -575,
				archZ = -500,
				color = Color3.fromRGB(58, 125, 78),
				mat = Enum.Material.LeafyGrass,
				accent = Color3.fromRGB(95, 235, 175),
				lasers = false,
			},
			{
				name = "Zone5",
				title = "🌋 ZONE 5: BULKANG MAYON RIDGE (Speed 30+)",
				zCenter = -725,
				archZ = -650,
				color = Color3.fromRGB(75, 52, 48),
				mat = Enum.Material.Basalt,
				accent = Color3.fromRGB(255, 95, 65),
				lasers = true,
			},
			{
				name = "Zone6",
				title = "👑 ZONE 6: INTRAMUROS ROYAL VAULT (Speed 35+)",
				zCenter = -875,
				archZ = -800,
				color = Color3.fromRGB(68, 62, 85),
				mat = Enum.Material.Marble,
				accent = Color3.fromRGB(255, 215, 55),
				lasers = true,
			},
			{
				name = "Zone7",
				title = "🌸 ZONE 7: MYTHICAL SANCTUARY (Speed 40+)",
				zCenter = -1025,
				archZ = -950,
				color = Color3.fromRGB(185, 130, 165),
				mat = Enum.Material.Grass,
				accent = Color3.fromRGB(255, 140, 200),
				lasers = false,
			},
			{
				name = "Zone8",
				title = "🌌 ZONE 8: CELESTIAL VAULT (Speed 45+)",
				zCenter = -1175,
				archZ = -1100,
				color = Color3.fromRGB(35, 40, 75),
				mat = Enum.Material.Marble,
				accent = Color3.fromRGB(0, 245, 225),
				lasers = false,
			},
		}

		for _, zoneInfo in zones do
			local zone = Instance.new("Folder")
			zone.Name = zoneInfo.name
			zone.Parent = prison

			makePart("Floor", Vector3.new(84, 1, 148), Vector3.new(0, 0.5, zoneInfo.zCenter), zoneInfo.color, zone, zoneInfo.mat)
			buildZoneArchHeader(zone, zoneInfo.archZ, zoneInfo.title, zoneInfo.accent)

			makePart("VaultPad", Vector3.new(32, 0.4, 28), Vector3.new(0, 1.1, zoneInfo.zCenter), Color3.fromRGB(48, 52, 64), zone, Enum.Material.Metal)

			local cagePositions = {
				Vector3.new(-10, 3.7, zoneInfo.zCenter - 8),
				Vector3.new(10, 3.7, zoneInfo.zCenter - 8),
				Vector3.new(-10, 3.7, zoneInfo.zCenter + 8),
				Vector3.new(10, 3.7, zoneInfo.zCenter + 8),
			}
			for i, cPos in cagePositions do
				buildDetailedCage(`Cage{i}`, cPos, zoneInfo.name, i, zoneInfo.accent, zone)
			end

			if zoneInfo.name == "Zone1" then
				buildRoosterTeepee(zone, Vector3.new(-30, 0.5, zoneInfo.zCenter - 32))
				buildRoosterTeepee(zone, Vector3.new(30, 0.5, zoneInfo.zCenter - 32))
				buildRoosterTeepee(zone, Vector3.new(-30, 0.5, zoneInfo.zCenter + 32))
				buildRoosterTeepee(zone, Vector3.new(30, 0.5, zoneInfo.zCenter + 32))
			end
		end
	end

	-- 2) WOODEN-FENCED BASE PLOTS (Plot1..Plot6: 60x60 studs each)
	local plotsFolder = workspace:FindFirstChild("BasePlots")
	if not plotsFolder then
		plotsFolder = Instance.new("Folder")
		plotsFolder.Name = "BasePlots"
		plotsFolder.Parent = workspace

		for i = 1, 6 do
			local x = (i - 3.5) * 70

			local plot = Instance.new("Model")
			plot.Name = "Plot" .. i

			local floor = makePart("Floor", Vector3.new(60, 1, 60), Vector3.new(x, 0.55, 62), Color3.fromRGB(85, 165, 90), plot, Enum.Material.Grass)
			plot.PrimaryPart = floor
			CollectionService:AddTag(floor, "PlotFloor")
			buildPlotFence(plot, floor.Position, 29.5)

			-- Personal Upgradable Treadmill right on each player's own Plot!
			buildPlotTreadmill(plot, floor.Position + Vector3.new(21.5, 0.5, -18.5))

			local drop = makePart("DropZone", Vector3.new(58, 2, 58), Vector3.new(x, 1.5, 62), Color3.fromRGB(55, 235, 115), plot, Enum.Material.SmoothPlastic)
			drop.Transparency = 1
			drop.CanCollide = false
			CollectionService:AddTag(drop, "DropZone")

			local spawnPart = Instance.new("SpawnLocation")
			spawnPart.Name = "Spawn"
			spawnPart.Size = Vector3.new(7, 0.6, 7)
			spawnPart.Position = Vector3.new(x, 1.2, 84)
			spawnPart.Color = Color3.fromRGB(220, 225, 235)
			spawnPart.Material = Enum.Material.SmoothPlastic
			spawnPart.Anchored = true
			spawnPart.Neutral = true
			spawnPart.Duration = 0
			spawnPart.TopSurface = Enum.SurfaceType.Smooth
			spawnPart.BottomSurface = Enum.SurfaceType.Smooth
			spawnPart.Parent = plot

			plot.Parent = plotsFolder
		end
	end

	-- 3) CENTRAL LOBBY (Takbuhan Treadmill Station + Central Fusion Machine + Leaderboard Board)
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		lobby = Instance.new("Folder")
		lobby.Name = "Lobby"
		lobby.Parent = workspace

		makePart("PlazaPath", Vector3.new(52, 0.6, 76), Vector3.new(0, 0.3, -10), Color3.fromRGB(80, 85, 98), lobby, Enum.Material.Cobblestone)

		-- 3D Tindahan ng Pamalo (Slap & Steal Tools Market Stand) right near the Prison entrance!
		buildPamaloShopStand(lobby, Vector3.new(0, 0.5, -24))

		local fmCenter = Vector3.new(-34, 0, -18)
		makePart("FusionBase", Vector3.new(11, 1.2, 11), fmCenter + Vector3.new(0, 0.6, 0), Color3.fromRGB(45, 48, 62), lobby, Enum.Material.Metal)
		makePart("FusionRing", Vector3.new(8.5, 0.4, 8.5), fmCenter + Vector3.new(0, 1.3, 0), Color3.fromRGB(170, 80, 255), lobby, Enum.Material.Neon)
		local fmHeader = makePart("FusionSign", Vector3.new(10, 2.4, 1.2), fmCenter + Vector3.new(0, 9.2, -4.0), Color3.fromRGB(28, 32, 44), lobby, Enum.Material.Metal)
		addSurfaceSign(fmHeader, Enum.NormalId.Back, "⚗️ FUSION MACHINE", "Combine 3 Same-Rarity Pets", Color3.fromRGB(190, 110, 255))
		addSurfaceSign(fmHeader, Enum.NormalId.Front, "⚗️ FUSION MACHINE", "Combine 3 Same-Rarity Pets", Color3.fromRGB(190, 110, 255))

		local fmCore = makePart("FusionMachine", Vector3.new(4.5, 5.5, 4.5), fmCenter + Vector3.new(0, 4.2, 0), Color3.fromRGB(165, 75, 255), lobby, Enum.Material.Neon)
		fmCore.Transparency = 0.2
		CollectionService:AddTag(fmCore, "FusionMachine")

		makePart("BoardStand", Vector3.new(16, 1.2, 3), Vector3.new(34, 0.6, -18), Color3.fromRGB(50, 55, 70), lobby, Enum.Material.Metal)
		local board = makePart("LeaderboardBoard", Vector3.new(16, 11, 1), Vector3.new(34, 6.7, -18), Color3.fromRGB(25, 30, 45), lobby, Enum.Material.Metal)
		CollectionService:AddTag(board, "LeaderboardBoard")
	end

	-- 4) PATROL POINTS FOR ALL 6 ZONES
	local patrolFolder = workspace:FindFirstChild("PatrolPoints")
	if not patrolFolder then
		patrolFolder = Instance.new("Folder")
		patrolFolder.Name = "PatrolPoints"
		patrolFolder.Parent = workspace
	end

	local zoneCenters = {
		Zone1 = -125,
		Zone2 = -275,
		Zone3 = -425,
		Zone4 = -575,
		Zone5 = -725,
		Zone6 = -875,
		Zone7 = -1025,
		Zone8 = -1175,
	}

	for zoneName, zc in zoneCenters do
		if not patrolFolder:FindFirstChild(`{zoneName}_Patrol1`) then
			local pts = {
				Vector3.new(-22, 3, zc + 21),
				Vector3.new(22, 3, zc + 21),
				Vector3.new(22, 3, zc - 21),
				Vector3.new(-22, 3, zc - 21),
			}
			for i, pos in pts do
				local point = makeMarker(`{zoneName}_Patrol{i}`, pos, Color3.fromRGB(255, 220, 60), patrolFolder)
				point:SetAttribute("Zone", zoneName)
				CollectionService:AddTag(point, "PatrolPoint")
			end
		end
	end

	-- 5) ENEMY SPAWNS FOR ALL 6 ZONES
	local spawnsFolder = workspace:FindFirstChild("EnemySpawns")
	if not spawnsFolder then
		spawnsFolder = Instance.new("Folder")
		spawnsFolder.Name = "EnemySpawns"
		spawnsFolder.Parent = workspace
	end

	local spawns = {
		{ name = "Zone1_Warden", enemyType = "Warden", zone = "Zone1", pos = Vector3.new(0, 3, -104), speedMult = 0.85 },
		{ name = "Zone2_Warden", enemyType = "Warden", zone = "Zone2", pos = Vector3.new(-20, 3, -254), speedMult = 1.0 },
		{ name = "Zone2_Dog", enemyType = "Dog", zone = "Zone2", pos = Vector3.new(20, 3, -296), speedMult = 1.0 },
		{ name = "Zone3_Warden", enemyType = "Warden", zone = "Zone3", pos = Vector3.new(-22, 3, -404), speedMult = 1.1 },
		{ name = "Zone3_Dog", enemyType = "Dog", zone = "Zone3", pos = Vector3.new(22, 3, -446), speedMult = 1.1 },
		{ name = "Zone4_Warden", enemyType = "Warden", zone = "Zone4", pos = Vector3.new(-22, 3, -554), speedMult = 1.25 },
		{ name = "Zone4_Dog", enemyType = "Dog", zone = "Zone4", pos = Vector3.new(22, 3, -596), speedMult = 1.2 },
		{ name = "Zone5_Warden", enemyType = "Warden", zone = "Zone5", pos = Vector3.new(-22, 3, -704), speedMult = 1.42 },
		{ name = "Zone5_Dog", enemyType = "Dog", zone = "Zone5", pos = Vector3.new(22, 3, -746), speedMult = 1.35 },
		{ name = "Zone6_Warden", enemyType = "Warden", zone = "Zone6", pos = Vector3.new(-22, 3, -854), speedMult = 1.62 },
		{ name = "Zone6_Dog", enemyType = "Dog", zone = "Zone6", pos = Vector3.new(22, 3, -896), speedMult = 1.5 },
		{ name = "Zone7_Warden", enemyType = "Warden", zone = "Zone7", pos = Vector3.new(-22, 3, -1004), speedMult = 1.8 },
		{ name = "Zone7_Dog", enemyType = "Dog", zone = "Zone7", pos = Vector3.new(22, 3, -1046), speedMult = 1.65 },
		{ name = "Zone8_Warden", enemyType = "Warden", zone = "Zone8", pos = Vector3.new(-22, 3, -1154), speedMult = 2.0 },
		{ name = "Zone8_Dog", enemyType = "Dog", zone = "Zone8", pos = Vector3.new(22, 3, -1196), speedMult = 1.85 },
	}

	for _, info in spawns do
		if not spawnsFolder:FindFirstChild(info.name) then
			local spawnPart = makeMarker(info.name, info.pos, Color3.fromRGB(255, 70, 70), spawnsFolder)
			spawnPart:SetAttribute("EnemyType", info.enemyType)
			spawnPart:SetAttribute("Zone", info.zone)
			spawnPart:SetAttribute("SpeedMultiplier", info.speedMult)
			CollectionService:AddTag(spawnPart, "EnemySpawn")
		end
	end
end

return Blockout
