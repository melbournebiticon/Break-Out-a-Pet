--!strict
-- Blockout.luau (SERVER)
-- Builds the full 6-Zone Tatak Pinoy Corridor (84 studs wide x 900 studs long, Zone1..Zone6),
-- Wooden-Fenced BasePlots, Safe Zone Line, 6-Zone Speed Karatula, Central Fusion Machine,
-- Leaderboard Board, and the 3D Interactive "🏃 TAKBUHAN TREADMILL STATION" in the Lobby!

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
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
			{ text = "🌾 Zone 1 (Sabungan):   Speed 900+", color = Color3.fromRGB(145, 235, 110), y = 0.19 },
			{ text = "🏪 Zone 2 (Palengke):   Speed 3.5K+", color = Color3.fromRGB(255, 195, 70), y = 0.29 },
			{ text = "🏛️ Zone 3 (Hacienda):   Speed 10K+", color = Color3.fromRGB(255, 140, 85), y = 0.39 },
			{ text = "🌴 Zone 4 (Gubat):      Speed 25K+", color = Color3.fromRGB(95, 230, 175), y = 0.49 },
			{ text = "🌋 Zone 5 (Mayon):      Speed 60K+", color = Color3.fromRGB(255, 95, 75), y = 0.59 },
			{ text = "👑 Zone 6 (Intramuros): Speed 140K+", color = Color3.fromRGB(255, 215, 55), y = 0.69 },
			{ text = "🌸 Zone 7..12:          320K - 19M+", color = Color3.fromRGB(255, 140, 200), y = 0.79 },
			{ text = "✨ Zone 13..20:         42M - 12B+", color = Color3.fromRGB(0, 245, 225), y = 0.89 },
		}
		for _, line in lines do
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(0.90, 0.095)
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
	addSurfaceSign(header, Enum.NormalId.Back, "🏃 Tsinelas Lakad Pad (Tier 0)", "+2 Speed/sec • Press E to Upgrade!", Color3.fromRGB(80, 230, 255))
	addSurfaceSign(header, Enum.NormalId.Front, "🏃 Tsinelas Lakad Pad (Tier 0)", "+2 Speed/sec • Press E to Upgrade!", Color3.fromRGB(80, 230, 255))
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

local function buildDecorativeTree(parent: Instance, pos: Vector3)
	local tree = Instance.new("Model")
	tree.Name = "IslandTree"
	tree.Parent = parent

	makePart("Trunk", Vector3.new(1.8, 9.5, 1.8), pos + Vector3.new(0, 4.75, 0), Color3.fromRGB(135, 88, 45), tree, Enum.Material.Wood)
	makePart("Canopy1", Vector3.new(8.5, 3.8, 8.5), pos + Vector3.new(0, 10.2, 0), Color3.fromRGB(78, 195, 65), tree, Enum.Material.Grass)
	makePart("Canopy2", Vector3.new(6.2, 3.2, 6.2), pos + Vector3.new(0, 13.0, 0), Color3.fromRGB(98, 215, 78), tree, Enum.Material.Grass)
	makePart("Canopy3", Vector3.new(3.8, 2.2, 3.8), pos + Vector3.new(0, 15.2, 0), Color3.fromRGB(120, 232, 92), tree, Enum.Material.Grass)
end

local function configureSunnyLighting()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(135, 148, 165)
	Lighting.OutdoorAmbient = Color3.fromRGB(155, 172, 190)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.5

	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Parent = Lighting
	end
	atmo.Density = 0.24
	atmo.Offset = 0.15
	atmo.Color = Color3.fromRGB(185, 225, 255)
	atmo.Decay = Color3.fromRGB(135, 195, 250)
	atmo.Glare = 0
	atmo.Haze = 1.2
end

function Blockout.EnsureMap()
	configureSunnyLighting()

	-- Turn the default Baseplate into a vibrant Tropical Blue Ocean (respecting Roblox's 2048 max size limit!)
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Size = Vector3.new(2048, 20, 2048)
		baseplate.Position = Vector3.new(0, -14, -400)
		baseplate.Color = Color3.fromRGB(28, 152, 238)
		baseplate.Material = Enum.Material.SmoothPlastic
		baseplate.TopSurface = Enum.SurfaceType.Smooth
		local tex = baseplate:FindFirstChildOfClass("Texture")
		if tex then
			tex.Transparency = 0.82
		end
	end

	local defaultSpawn = workspace:FindFirstChild("SpawnLocation")
	if defaultSpawn and defaultSpawn:IsA("SpawnLocation") then
		defaultSpawn:Destroy()
	end

	local existingPrison = workspace:FindFirstChild("Prison")
	if existingPrison and not existingPrison:GetAttribute("RedesignedV27") then
		existingPrison:Destroy()
		for _, folderName in { "BasePlots", "Lobby", "PatrolPoints", "EnemySpawns", "Enemies" } do
			local f = workspace:FindFirstChild(folderName)
			if f then
				f:Destroy()
			end
		end
	end

	-- 1) 20-ZONE CORRIDOR (84 studs wide x 3000 studs long, Z from -50 to -3050!)
	local prison = workspace:FindFirstChild("Prison")
	if not prison then
		prison = Instance.new("Folder")
		prison.Name = "Prison"
		prison:SetAttribute("RedesignedV27", true)
		prison.Parent = workspace

		-- Far Ocean Water extension so water stretches seamlessly all the way past Zone 20!
		makePart("OceanFar", Vector3.new(2048, 20, 2048), Vector3.new(0, -14, -2448), Color3.fromRGB(28, 152, 238), prison, Enum.Material.SmoothPlastic)

		-- Golden Earth Cliff foundation beneath the entire 20-Zone Corridor
		makePart("CorridorCliff1", Vector3.new(90, 12, 2000), Vector3.new(0, -6.0, -1050), Color3.fromRGB(188, 132, 74), prison, Enum.Material.Sandstone)
		makePart("CorridorCliff2", Vector3.new(90, 12, 1004), Vector3.new(0, -6.0, -2550), Color3.fromRGB(188, 132, 74), prison, Enum.Material.Sandstone)

		local safeLine = makePart("SafeZoneLine", Vector3.new(84, 0.35, 3.5), Vector3.new(0, 0.9, -47.5), Color3.fromRGB(60, 255, 120), prison, Enum.Material.Neon)
		safeLine.CanCollide = false
		addSurfaceSign(safeLine, Enum.NormalId.Top, "🛡️ SAFE ZONE LINE 🛡️", "Cross here with a cage to secure it!", Color3.fromRGB(80, 255, 140))

		buildSpeedKaratula(prison, Vector3.new(54, 0.5, -45))

		-- Warm Terracotta Corridor Side Walls + Bright Lime Grass Top (Steal-a-Pet style!)
		local wallColor = Color3.fromRGB(202, 142, 80)
		local grassTopColor = Color3.fromRGB(82, 212, 62)
		makePart("WallLeft", Vector3.new(3, 14, 2000), Vector3.new(-43.5, 7.5, -1050), wallColor, prison, Enum.Material.Sandstone)
		makePart("WallLeft2", Vector3.new(3, 14, 1002), Vector3.new(-43.5, 7.5, -2550), wallColor, prison, Enum.Material.Sandstone)
		makePart("WallLeftTop", Vector3.new(3.6, 1.4, 2000), Vector3.new(-43.5, 15.1, -1050), grassTopColor, prison, Enum.Material.Grass)
		makePart("WallLeftTop2", Vector3.new(3.6, 1.4, 1002), Vector3.new(-43.5, 15.1, -2550), grassTopColor, prison, Enum.Material.Grass)
		makePart("WallRight", Vector3.new(3, 14, 2000), Vector3.new(43.5, 7.5, -1050), wallColor, prison, Enum.Material.Sandstone)
		makePart("WallRight2", Vector3.new(3, 14, 1002), Vector3.new(43.5, 7.5, -2550), wallColor, prison, Enum.Material.Sandstone)
		makePart("WallRightTop", Vector3.new(3.6, 1.4, 2000), Vector3.new(43.5, 15.1, -1050), grassTopColor, prison, Enum.Material.Grass)
		makePart("WallRightTop2", Vector3.new(3.6, 1.4, 1002), Vector3.new(43.5, 15.1, -2550), grassTopColor, prison, Enum.Material.Grass)
		makePart("WallBack", Vector3.new(90, 14, 3), Vector3.new(0, 7.5, -3051), wallColor, prison, Enum.Material.Sandstone)
		makePart("WallBackTop", Vector3.new(91, 1.4, 3.6), Vector3.new(0, 15.1, -3051), grassTopColor, prison, Enum.Material.Grass)

		local zones = {
			{
				name = "Zone1",
				title = "🌾 ZONE 1: BUKID & SABUNGAN (Speed 900+)",
				zCenter = -125,
				archZ = -50,
				color = Color3.fromRGB(105, 155, 82),
				mat = Enum.Material.Grass,
				accent = Color3.fromRGB(145, 235, 110),
				lasers = false,
			},
			{
				name = "Zone2",
				title = "🏪 ZONE 2: PALENGKE & TIANGGE (Speed 3.5K+)",
				zCenter = -275,
				archZ = -200,
				color = Color3.fromRGB(185, 150, 95),
				mat = Enum.Material.Sand,
				accent = Color3.fromRGB(255, 195, 70),
				lasers = false,
			},
			{
				name = "Zone3",
				title = "🏛️ ZONE 3: HACIENDA COMPOUND (Speed 10K+)",
				zCenter = -425,
				archZ = -350,
				color = Color3.fromRGB(115, 85, 65),
				mat = Enum.Material.Cobblestone,
				accent = Color3.fromRGB(255, 145, 75),
				lasers = true,
			},
			{
				name = "Zone4",
				title = "🌴 ZONE 4: BOHOL & PALAWAN GUBAT (Speed 25K+)",
				zCenter = -575,
				archZ = -500,
				color = Color3.fromRGB(58, 125, 78),
				mat = Enum.Material.LeafyGrass,
				accent = Color3.fromRGB(95, 235, 175),
				lasers = false,
			},
			{
				name = "Zone5",
				title = "🌋 ZONE 5: BULKANG MAYON RIDGE (Speed 60K+)",
				zCenter = -725,
				archZ = -650,
				color = Color3.fromRGB(75, 52, 48),
				mat = Enum.Material.Basalt,
				accent = Color3.fromRGB(255, 95, 65),
				lasers = true,
			},
			{
				name = "Zone6",
				title = "👑 ZONE 6: INTRAMUROS ROYAL VAULT (Speed 140K+)",
				zCenter = -875,
				archZ = -800,
				color = Color3.fromRGB(68, 62, 85),
				mat = Enum.Material.Marble,
				accent = Color3.fromRGB(255, 215, 55),
				lasers = true,
			},
			{
				name = "Zone7",
				title = "🌸 ZONE 7: MYTHICAL SANCTUARY (Speed 320K+)",
				zCenter = -1025,
				archZ = -950,
				color = Color3.fromRGB(185, 130, 165),
				mat = Enum.Material.Grass,
				accent = Color3.fromRGB(255, 140, 200),
				lasers = false,
			},
			{
				name = "Zone8",
				title = "🌌 ZONE 8: CELESTIAL VAULT (Speed 750K+)",
				zCenter = -1175,
				archZ = -1100,
				color = Color3.fromRGB(35, 40, 75),
				mat = Enum.Material.Marble,
				accent = Color3.fromRGB(0, 245, 225),
				lasers = false,
			},
			{
				name = "Zone9",
				title = "⚔️ ZONE 9: VALHALLA COLISEUM (Speed 1.7M+)",
				zCenter = -1325,
				archZ = -1250,
				color = Color3.fromRGB(58, 68, 95),
				mat = Enum.Material.Marble,
				accent = Color3.fromRGB(120, 215, 255),
				lasers = false,
			},
			{
				name = "Zone10",
				title = "🔱 ZONE 10: OLYMPUS TITAN REALM (Speed 3.8M+)",
				zCenter = -1475,
				archZ = -1400,
				color = Color3.fromRGB(145, 115, 65),
				mat = Enum.Material.Marble,
				accent = Color3.fromRGB(255, 165, 45),
				lasers = false,
			},
			{
				name = "Zone11",
				title = "🐉 ZONE 11: DRAGON EMPEROR CITADEL (Speed 8.5M+)",
				zCenter = -1625,
				archZ = -1550,
				color = Color3.fromRGB(85, 25, 32),
				mat = Enum.Material.Basalt,
				accent = Color3.fromRGB(255, 55, 85),
				lasers = false,
			},
			{
				name = "Zone12",
				title = "👑 ZONE 12: BATHALA INFINITY THRONE (Speed 19M+)",
				zCenter = -1775,
				archZ = -1700,
				color = Color3.fromRGB(30, 28, 65),
				mat = Enum.Material.Neon,
				accent = Color3.fromRGB(255, 225, 95),
				lasers = false,
			},
			{
				name = "Zone13",
				title = "❄️ ZONE 13: FROSTBITE GLACIER KEEP (Speed 42M+)",
				zCenter = -1925,
				archZ = -1850,
				color = Color3.fromRGB(135, 205, 235),
				mat = Enum.Material.Ice,
				accent = Color3.fromRGB(120, 235, 255),
				lasers = false,
			},
			{
				name = "Zone14",
				title = "🏜️ ZONE 14: PHARAOH GOLDEN PYRAMID (Speed 95M+)",
				zCenter = -2075,
				archZ = -2000,
				color = Color3.fromRGB(215, 175, 85),
				mat = Enum.Material.Sandstone,
				accent = Color3.fromRGB(255, 215, 55),
				lasers = false,
			},
			{
				name = "Zone15",
				title = "🌊 ZONE 15: ATLANTIS ABYSSAL TRENCH (Speed 210M+)",
				zCenter = -2225,
				archZ = -2150,
				color = Color3.fromRGB(22, 85, 115),
				mat = Enum.Material.Marble,
				accent = Color3.fromRGB(0, 255, 215),
				lasers = false,
			},
			{
				name = "Zone16",
				title = "⚡ ZONE 16: CYBER NEON METROPOLIS (Speed 460M+)",
				zCenter = -2375,
				archZ = -2300,
				color = Color3.fromRGB(28, 32, 48),
				mat = Enum.Material.Metal,
				accent = Color3.fromRGB(0, 245, 255),
				lasers = false,
			},
			{
				name = "Zone17",
				title = "🩸 ZONE 17: UNDERWORLD HADES CORE (Speed 1.0B+)",
				zCenter = -2525,
				archZ = -2450,
				color = Color3.fromRGB(58, 18, 22),
				mat = Enum.Material.Basalt,
				accent = Color3.fromRGB(255, 75, 45),
				lasers = false,
			},
			{
				name = "Zone18",
				title = "☄️ ZONE 18: ASTRAL NEBULA DIMENSION (Speed 2.2B+)",
				zCenter = -2675,
				archZ = -2600,
				color = Color3.fromRGB(48, 22, 78),
				mat = Enum.Material.Marble,
				accent = Color3.fromRGB(235, 110, 255),
				lasers = false,
			},
			{
				name = "Zone19",
				title = "⏳ ZONE 19: CHRONOS TIME CITADEL (Speed 5.0B+)",
				zCenter = -2825,
				archZ = -2750,
				color = Color3.fromRGB(35, 85, 92),
				mat = Enum.Material.Marble,
				accent = Color3.fromRGB(110, 255, 230),
				lasers = false,
			},
			{
				name = "Zone20",
				title = "✨ ZONE 20: OMNIVERSE GODLY SANCTUARY (Speed 12B+)",
				zCenter = -2975,
				archZ = -2900,
				color = Color3.fromRGB(42, 35, 85),
				mat = Enum.Material.Neon,
				accent = Color3.fromRGB(255, 240, 140),
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

			-- Personal Upgradable Treadmill placed well OUTSIDE the front-right of each player's Plot so even Titanic pets never cover it!
			buildPlotTreadmill(plot, floor.Position + Vector3.new(21.5, 0.0, -50.5))

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

	-- 3) CENTRAL LOBBY & LUSH GREEN SAFE-ZONE ISLAND (Spans all 6 plots!)
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then
		lobby = Instance.new("Folder")
		lobby.Name = "Lobby"
		lobby.Parent = workspace

		-- Full-width Tropical Island Platform beneath all 6 Plots & Safe Zone Plaza!
		makePart("IslandCliffBase", Vector3.new(480, 12, 235), Vector3.new(0, -6.2, 58), Color3.fromRGB(188, 132, 74), lobby, Enum.Material.Sandstone)
		makePart("IslandMeadowGrass", Vector3.new(484, 0.8, 238), Vector3.new(0, 0.0, 58), Color3.fromRGB(96, 198, 72), lobby, Enum.Material.Grass)

		-- Stone Promenade Boardwalk connecting all 6 Plots & Treadmills to the Central Plaza
		makePart("PlotBoardwalk", Vector3.new(436, 0.35, 22), Vector3.new(0, 0.32, 20), Color3.fromRGB(218, 202, 168), lobby, Enum.Material.Cobblestone)
		makePart("PlazaPath", Vector3.new(72, 0.45, 76), Vector3.new(0, 0.35, -10), Color3.fromRGB(205, 190, 158), lobby, Enum.Material.Cobblestone)

		-- Central Grand Pathway leading straight through to the Fiesta Plaza behind the plots
		makePart("FiestaAccessPath", Vector3.new(22, 0.35, 68), Vector3.new(0, 0.33, 114), Color3.fromRGB(218, 202, 168), lobby, Enum.Material.Cobblestone)

		-- Decorative Island Trees framing the Safe Zone plaza
		for _, tPos in {
			Vector3.new(-225, 0.4, -35),
			Vector3.new(225, 0.4, -35),
			Vector3.new(-225, 0.4, 95),
			Vector3.new(225, 0.4, 95),
			Vector3.new(-95, 0.4, -35),
			Vector3.new(95, 0.4, -35),
			Vector3.new(-65, 0.4, 150),
			Vector3.new(65, 0.4, 150),
		} do
			buildDecorativeTree(lobby, tPos)
		end

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

		-- 🎪 FIESTA EVENT PLAZA (Placed centrally BEHIND the plots: Z = 150, equal distance for all players!)
		local fiestaCenter = Vector3.new(0, 0, 150)
		local fiestaModel = Instance.new("Model")
		fiestaModel.Name = "FiestaEventPlaza"
		fiestaModel.Parent = lobby

		local arenaBase = makePart("FiestaArenaBase", Vector3.new(34, 0.7, 34), fiestaCenter + Vector3.new(0, 0.35, 0), Color3.fromRGB(142, 96, 52), fiestaModel, Enum.Material.WoodPlanks)
		CollectionService:AddTag(arenaBase, "FiestaArenaCenter")
		makePart("FiestaStageTrim", Vector3.new(35.5, 0.4, 35.5), fiestaCenter + Vector3.new(0, 0.2, 0), Color3.fromRGB(255, 200, 55), fiestaModel, Enum.Material.Neon)

		-- 6 Perya Color Game Tiles on the Arena Floor (enlarged & centered)
		local peryaColors = {
			{ Name = "RED", Color = Color3.fromRGB(235, 55, 55), Offset = Vector3.new(-9.5, 0.78, -6.5) },
			{ Name = "BLUE", Color = Color3.fromRGB(55, 145, 245), Offset = Vector3.new(0, 0.78, -6.5) },
			{ Name = "YELLOW", Color = Color3.fromRGB(250, 210, 45), Offset = Vector3.new(9.5, 0.78, -6.5) },
			{ Name = "GREEN", Color = Color3.fromRGB(65, 215, 95), Offset = Vector3.new(-9.5, 0.78, 6.5) },
			{ Name = "PINK", Color = Color3.fromRGB(245, 95, 210), Offset = Vector3.new(0, 0.78, 6.5) },
			{ Name = "WHITE", Color = Color3.fromRGB(240, 245, 255), Offset = Vector3.new(9.5, 0.78, 6.5) },
		}
		for _, tc in peryaColors do
			local tile = makePart(`ColorTile_{tc.Name}`, Vector3.new(8.2, 0.22, 10.2), fiestaCenter + tc.Offset, tc.Color, fiestaModel, Enum.Material.SmoothPlastic)
			tile:SetAttribute("ColorName", tc.Name)
			CollectionService:AddTag(tile, "FiestaColorTile")
		end

		-- 4 Corner Fiesta Bamboo Pillars + Banderitas Overhead
		local postOffsets = {
			Vector3.new(-16, 7.5, -16),
			Vector3.new(16, 7.5, -16),
			Vector3.new(-16, 7.5, 16),
			Vector3.new(16, 7.5, 16),
		}
		for idx, pOff in postOffsets do
			makePart(`FiestaPost_{idx}`, Vector3.new(1.2, 15, 1.2), fiestaCenter + pOff, Color3.fromRGB(165, 118, 58), fiestaModel, Enum.Material.Wood)
		end

		local banderitaPalette = {
			Color3.fromRGB(255, 65, 65),
			Color3.fromRGB(255, 215, 45),
			Color3.fromRGB(55, 200, 255),
			Color3.fromRGB(75, 235, 105),
			Color3.fromRGB(245, 95, 220),
		}
		for i = -14, 14, 4 do
			local c = banderitaPalette[((math.abs(i) // 4) % #banderitaPalette) + 1]
			makePart(`BanderitaFront_{i}`, Vector3.new(2.4, 1.0, 0.25), fiestaCenter + Vector3.new(i, 14.2, -16), c, fiestaModel, Enum.Material.Neon)
			makePart(`BanderitaBack_{i}`, Vector3.new(2.4, 1.0, 0.25), fiestaCenter + Vector3.new(i, 14.2, 16), c, fiestaModel, Enum.Material.Neon)
		end

		local fiestaSign = makePart("FiestaStageSign", Vector3.new(26, 3.6, 1.2), fiestaCenter + Vector3.new(0, 15.6, -16), Color3.fromRGB(28, 22, 42), fiestaModel, Enum.Material.Metal)
		addSurfaceSign(fiestaSign, Enum.NormalId.Back, "🎪 FIESTA EVENT PLAZA 🎉", "Join Rotating Pinoy Fiesta Events for 2x Speed, Cash & Luck Boosts!", Color3.fromRGB(255, 215, 55))
		addSurfaceSign(fiestaSign, Enum.NormalId.Front, "🎪 FIESTA EVENT PLAZA 🎉", "Join Rotating Pinoy Fiesta Events for 2x Speed, Cash & Luck Boosts!", Color3.fromRGB(255, 215, 55))
		CollectionService:AddTag(fiestaSign, "FiestaStageSign")

		-- BENTAHAN NG PET (Enlarged Grand Pet Buy & Sell Market Stand + Big Glowing Step-On Pad!)
		local sellCenter = Vector3.new(32, 0, -21)
		local sellStand = Instance.new("Model")
		sellStand.Name = "BentahanNgPet"
		sellStand.Parent = lobby

		makePart("SellCounterBase", Vector3.new(20, 3.4, 4.8), sellCenter + Vector3.new(0, 1.7, -2.5), Color3.fromRGB(138, 92, 48), sellStand, Enum.Material.WoodPlanks)
		makePart("SellCounterTop", Vector3.new(21, 0.45, 5.4), sellCenter + Vector3.new(0, 3.55, -2.5), Color3.fromRGB(245, 195, 55), sellStand, Enum.Material.Wood)
		makePart("SellPostL", Vector3.new(0.85, 9.8, 0.85), sellCenter + Vector3.new(-9.2, 4.9, -4.3), Color3.fromRGB(110, 72, 36), sellStand, Enum.Material.Wood)
		makePart("SellPostR", Vector3.new(0.85, 9.8, 0.85), sellCenter + Vector3.new(9.2, 4.9, -4.3), Color3.fromRGB(110, 72, 36), sellStand, Enum.Material.Wood)
		makePart("SellAwning", Vector3.new(21.6, 0.55, 6.2), sellCenter + Vector3.new(0, 9.0, -2.5), Color3.fromRGB(45, 185, 85), sellStand, Enum.Material.Fabric)

		-- Decorative Gold Ingots & Cash Crates on the Bentahan Counter
		for gx = -6, 6, 4 do
			makePart(`GoldStack_{gx}`, Vector3.new(2.2, 1.1, 1.6), sellCenter + Vector3.new(gx, 4.25, -2.5), Color3.fromRGB(255, 215, 55), sellStand, Enum.Material.Neon)
		end

		local sellSign = makePart("SellSign", Vector3.new(20.5, 2.7, 1.0), sellCenter + Vector3.new(0, 10.5, -4.3), Color3.fromRGB(22, 34, 28), sellStand, Enum.Material.Metal)
		addSurfaceSign(sellSign, Enum.NormalId.Back, "💰 BENTAHAN NG PET 💰", "Step on Green Pad to Sell Unused Pets for Instant Cash!", Color3.fromRGB(95, 255, 130))
		addSurfaceSign(sellSign, Enum.NormalId.Front, "💰 BENTAHAN NG PET 💰", "Step on Green Pad to Sell Unused Pets for Instant Cash!", Color3.fromRGB(95, 255, 130))

		-- Larger Glowing Step-On Pad in front of the Bentahan counter
		makePart("SellPadBase", Vector3.new(14.0, 0.45, 11.0), sellCenter + Vector3.new(0, 0.45, 4.5), Color3.fromRGB(38, 46, 54), sellStand, Enum.Material.Metal)
		local sellPad = makePart("PetSellPad", Vector3.new(12.6, 0.55, 9.6), sellCenter + Vector3.new(0, 0.58, 4.5), Color3.fromRGB(65, 235, 115), sellStand, Enum.Material.Neon)
		CollectionService:AddTag(sellPad, "PetSellPad")

		makePart("BoardStand", Vector3.new(16, 1.2, 3), Vector3.new(56, 0.6, -18), Color3.fromRGB(50, 55, 70), lobby, Enum.Material.Metal)
		local board = makePart("LeaderboardBoard", Vector3.new(16, 11, 1), Vector3.new(56, 6.7, -18), Color3.fromRGB(25, 30, 45), lobby, Enum.Material.Metal)
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
		Zone9 = -1325,
		Zone10 = -1475,
		Zone11 = -1625,
		Zone12 = -1775,
		Zone13 = -1925,
		Zone14 = -2075,
		Zone15 = -2225,
		Zone16 = -2375,
		Zone17 = -2525,
		Zone18 = -2675,
		Zone19 = -2825,
		Zone20 = -2975,
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
		{ name = "Zone9_Warden", enemyType = "Warden", zone = "Zone9", pos = Vector3.new(-22, 3, -1304), speedMult = 2.1 },
		{ name = "Zone9_Dog", enemyType = "Dog", zone = "Zone9", pos = Vector3.new(22, 3, -1346), speedMult = 1.95 },
		{ name = "Zone10_Warden", enemyType = "Warden", zone = "Zone10", pos = Vector3.new(-22, 3, -1454), speedMult = 2.2 },
		{ name = "Zone10_Dog", enemyType = "Dog", zone = "Zone10", pos = Vector3.new(22, 3, -1496), speedMult = 2.05 },
		{ name = "Zone11_Warden", enemyType = "Warden", zone = "Zone11", pos = Vector3.new(-22, 3, -1604), speedMult = 2.3 },
		{ name = "Zone11_Dog", enemyType = "Dog", zone = "Zone11", pos = Vector3.new(22, 3, -1646), speedMult = 2.15 },
		{ name = "Zone12_Warden", enemyType = "Warden", zone = "Zone12", pos = Vector3.new(-22, 3, -1754), speedMult = 2.4 },
		{ name = "Zone12_Dog", enemyType = "Dog", zone = "Zone12", pos = Vector3.new(22, 3, -1796), speedMult = 2.25 },
		{ name = "Zone13_Warden", enemyType = "Warden", zone = "Zone13", pos = Vector3.new(-22, 3, -1904), speedMult = 2.5 },
		{ name = "Zone13_Dog", enemyType = "Dog", zone = "Zone13", pos = Vector3.new(22, 3, -1946), speedMult = 2.35 },
		{ name = "Zone14_Warden", enemyType = "Warden", zone = "Zone14", pos = Vector3.new(-22, 3, -2054), speedMult = 2.6 },
		{ name = "Zone14_Dog", enemyType = "Dog", zone = "Zone14", pos = Vector3.new(22, 3, -2096), speedMult = 2.45 },
		{ name = "Zone15_Warden", enemyType = "Warden", zone = "Zone15", pos = Vector3.new(-22, 3, -2204), speedMult = 2.7 },
		{ name = "Zone15_Dog", enemyType = "Dog", zone = "Zone15", pos = Vector3.new(22, 3, -2246), speedMult = 2.55 },
		{ name = "Zone16_Warden", enemyType = "Warden", zone = "Zone16", pos = Vector3.new(-22, 3, -2354), speedMult = 2.8 },
		{ name = "Zone16_Dog", enemyType = "Dog", zone = "Zone16", pos = Vector3.new(22, 3, -2396), speedMult = 2.65 },
		{ name = "Zone17_Warden", enemyType = "Warden", zone = "Zone17", pos = Vector3.new(-22, 3, -2504), speedMult = 2.9 },
		{ name = "Zone17_Dog", enemyType = "Dog", zone = "Zone17", pos = Vector3.new(22, 3, -2546), speedMult = 2.75 },
		{ name = "Zone18_Warden", enemyType = "Warden", zone = "Zone18", pos = Vector3.new(-22, 3, -2654), speedMult = 3.0 },
		{ name = "Zone18_Dog", enemyType = "Dog", zone = "Zone18", pos = Vector3.new(22, 3, -2696), speedMult = 2.85 },
		{ name = "Zone19_Warden", enemyType = "Warden", zone = "Zone19", pos = Vector3.new(-22, 3, -2804), speedMult = 3.1 },
		{ name = "Zone19_Dog", enemyType = "Dog", zone = "Zone19", pos = Vector3.new(22, 3, -2846), speedMult = 2.95 },
		{ name = "Zone20_Warden", enemyType = "Warden", zone = "Zone20", pos = Vector3.new(-22, 3, -2954), speedMult = 3.2 },
		{ name = "Zone20_Dog", enemyType = "Dog", zone = "Zone20", pos = Vector3.new(22, 3, -2996), speedMult = 3.05 },
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
