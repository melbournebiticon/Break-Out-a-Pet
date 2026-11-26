--!strict
-- PetVisuals.luau
-- Detailed "Grow a Garden"-style 3D voxel animal builder for every pet species in Break Out a Pet!
-- Each pet has a distinct multi-part silhouette (torso, belly, distinct head, snout/beak, 4 legs/paws/flippers,
-- wings, horns, shell, pincers, fins, or multi-tails) tailored to its exact name and species.
-- Also supports custom 3D models if placed in ReplicatedStorage.PetModels.<petId>.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetData = require(script.Parent.PetData)
local Rarities = require(script.Parent.Rarities)
local MutationData = require(script.Parent.MutationData)

local PetVisuals = {}

export type SpeciesPalette = {
	Main: Color3,
	Secondary: Color3,
	Accent: Color3,
	Category: string,
}

local Palettes: { [string]: SpeciesPalette } = {
	-- Poultry & Birds
	chicken = { Main = Color3.fromRGB(248, 244, 232), Secondary = Color3.fromRGB(230, 215, 190), Accent = Color3.fromRGB(225, 38, 38), Category = "rooster" },
	duckling = { Main = Color3.fromRGB(255, 222, 55), Secondary = Color3.fromRGB(255, 240, 140), Accent = Color3.fromRGB(255, 135, 25), Category = "duck" },
	agila = { Main = Color3.fromRGB(115, 78, 48), Secondary = Color3.fromRGB(245, 242, 235), Accent = Color3.fromRGB(255, 195, 45), Category = "eagle" },
	phoenix = { Main = Color3.fromRGB(255, 95, 25), Secondary = Color3.fromRGB(255, 215, 45), Accent = Color3.fromRGB(255, 45, 125), Category = "royal_bird" },
	minokawa = { Main = Color3.fromRGB(32, 38, 68), Secondary = Color3.fromRGB(75, 95, 155), Accent = Color3.fromRGB(255, 195, 45), Category = "eagle" },
	sarimanok = { Main = Color3.fromRGB(255, 185, 30), Secondary = Color3.fromRGB(235, 45, 75), Accent = Color3.fromRGB(45, 225, 185), Category = "royal_bird" },
	void_phoenix = { Main = Color3.fromRGB(48, 24, 85), Secondary = Color3.fromRGB(145, 55, 235), Accent = Color3.fromRGB(255, 65, 195), Category = "royal_bird" },
	titanic_agila = { Main = Color3.fromRGB(130, 88, 52), Secondary = Color3.fromRGB(250, 248, 240), Accent = Color3.fromRGB(255, 215, 55), Category = "eagle" },
	titanic_sarimanok = { Main = Color3.fromRGB(255, 195, 35), Secondary = Color3.fromRGB(255, 45, 115), Accent = Color3.fromRGB(0, 245, 225), Category = "royal_bird" },

	-- Carabao / Tamaraw (Horned Livestock)
	kalabaw = { Main = Color3.fromRGB(68, 64, 68), Secondary = Color3.fromRGB(95, 90, 95), Accent = Color3.fromRGB(225, 220, 205), Category = "carabao" },
	tamaraw = { Main = Color3.fromRGB(52, 46, 44), Secondary = Color3.fromRGB(82, 72, 68), Accent = Color3.fromRGB(235, 225, 205), Category = "carabao" },
	titanic_kalabaw = { Main = Color3.fromRGB(55, 50, 58), Secondary = Color3.fromRGB(90, 82, 95), Accent = Color3.fromRGB(255, 210, 65), Category = "carabao" },

	-- Cats, Dogs, Wolves, Kitsune, Lion
	puspin = { Main = Color3.fromRGB(238, 152, 72), Secondary = Color3.fromRGB(252, 242, 225), Accent = Color3.fromRGB(255, 165, 180), Category = "cat" },
	ninja_cat = { Main = Color3.fromRGB(38, 42, 56), Secondary = Color3.fromRGB(65, 72, 92), Accent = Color3.fromRGB(225, 38, 48), Category = "ninja_cat" },
	aspin = { Main = Color3.fromRGB(178, 122, 68), Secondary = Color3.fromRGB(238, 208, 168), Accent = Color3.fromRGB(45, 35, 28), Category = "dog" },
	pilandok = { Main = Color3.fromRGB(168, 112, 60), Secondary = Color3.fromRGB(248, 238, 222), Accent = Color3.fromRGB(95, 62, 35), Category = "deer" },
	wolf = { Main = Color3.fromRGB(125, 135, 155), Secondary = Color3.fromRGB(225, 230, 240), Accent = Color3.fromRGB(55, 62, 75), Category = "dog" },
	shadow_kitsune = { Main = Color3.fromRGB(36, 22, 58), Secondary = Color3.fromRGB(75, 42, 115), Accent = Color3.fromRGB(195, 85, 255), Category = "kitsune" },
	mecha_lion = { Main = Color3.fromRGB(225, 172, 42), Secondary = Color3.fromRGB(145, 85, 25), Accent = Color3.fromRGB(0, 235, 255), Category = "lion" },

	-- Aquatic & Seafood (Fish, Whale Shark, Crab, Octopus)
	bangus = { Main = Color3.fromRGB(235, 205, 72), Secondary = Color3.fromRGB(255, 248, 205), Accent = Color3.fromRGB(255, 170, 35), Category = "fish" },
	butanding = { Main = Color3.fromRGB(48, 115, 185), Secondary = Color3.fromRGB(225, 242, 255), Accent = Color3.fromRGB(255, 255, 255), Category = "whale" },
	alimango = { Main = Color3.fromRGB(215, 58, 38), Secondary = Color3.fromRGB(245, 125, 65), Accent = Color3.fromRGB(30, 30, 35), Category = "crab" },
	octopus = { Main = Color3.fromRGB(235, 78, 142), Secondary = Color3.fromRGB(255, 155, 198), Accent = Color3.fromRGB(255, 225, 240), Category = "octopus" },

	-- Reptiles & Turtles
	turtle = { Main = Color3.fromRGB(105, 195, 95), Secondary = Color3.fromRGB(52, 125, 58), Accent = Color3.fromRGB(215, 185, 115), Category = "turtle" },
	pawikan = { Main = Color3.fromRGB(65, 168, 138), Secondary = Color3.fromRGB(38, 102, 82), Accent = Color3.fromRGB(195, 235, 185), Category = "turtle" },
	bayawak = { Main = Color3.fromRGB(78, 135, 58), Secondary = Color3.fromRGB(52, 92, 40), Accent = Color3.fromRGB(225, 205, 75), Category = "lizard" },
	chameleon = { Main = Color3.fromRGB(75, 225, 115), Secondary = Color3.fromRGB(155, 250, 95), Accent = Color3.fromRGB(255, 205, 55), Category = "lizard" },

	-- Cute Mammals (Bunny, Pig, Tarsier, Hamster, Raccoon, Panda, Capybara)
	bunny = { Main = Color3.fromRGB(248, 244, 252), Secondary = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(255, 168, 192), Category = "bunny" },
	golden_pig = { Main = Color3.fromRGB(255, 202, 72), Secondary = Color3.fromRGB(255, 225, 135), Accent = Color3.fromRGB(255, 145, 165), Category = "pig" },
	tarsier = { Main = Color3.fromRGB(148, 102, 62), Secondary = Color3.fromRGB(195, 152, 108), Accent = Color3.fromRGB(255, 205, 55), Category = "tarsier" },
	hamster = { Main = Color3.fromRGB(238, 175, 105), Secondary = Color3.fromRGB(252, 238, 218), Accent = Color3.fromRGB(255, 165, 178), Category = "hamster" },
	raccoon = { Main = Color3.fromRGB(132, 138, 148), Secondary = Color3.fromRGB(225, 230, 238), Accent = Color3.fromRGB(38, 40, 46), Category = "raccoon" },
	panda = { Main = Color3.fromRGB(246, 246, 250), Secondary = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(28, 30, 36), Category = "panda" },
	diamond_capybara = { Main = Color3.fromRGB(110, 222, 255), Secondary = Color3.fromRGB(195, 245, 255), Accent = Color3.fromRGB(255, 215, 65), Category = "capybara" },

	-- Folklore, Horses, Dragons & Titans
	sigbin = { Main = Color3.fromRGB(48, 36, 58), Secondary = Color3.fromRGB(78, 58, 92), Accent = Color3.fromRGB(255, 55, 85), Category = "sigbin" },
	tikbalang = { Main = Color3.fromRGB(108, 72, 44), Secondary = Color3.fromRGB(62, 40, 24), Accent = Color3.fromRGB(255, 195, 55), Category = "unicorn" },
	rainbow_unicorn = { Main = Color3.fromRGB(250, 245, 255), Secondary = Color3.fromRGB(255, 165, 235), Accent = Color3.fromRGB(85, 235, 255), Category = "unicorn" },
	godly_bathala = { Main = Color3.fromRGB(255, 235, 135), Secondary = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(110, 245, 255), Category = "unicorn" },

	bakunawa = { Main = Color3.fromRGB(24, 58, 102), Secondary = Color3.fromRGB(48, 115, 175), Accent = Color3.fromRGB(0, 245, 220), Category = "dragon" },
	mini_dragon = { Main = Color3.fromRGB(215, 42, 58), Secondary = Color3.fromRGB(255, 155, 45), Accent = Color3.fromRGB(255, 215, 65), Category = "dragon" },
	semi_typhon = { Main = Color3.fromRGB(52, 142, 198), Secondary = Color3.fromRGB(115, 205, 245), Accent = Color3.fromRGB(185, 250, 255), Category = "dragon" },
	semi_hydra = { Main = Color3.fromRGB(36, 138, 72), Secondary = Color3.fromRGB(85, 195, 110), Accent = Color3.fromRGB(165, 255, 95), Category = "hydra" },
	semi_golem = { Main = Color3.fromRGB(122, 95, 68), Secondary = Color3.fromRGB(88, 68, 48), Accent = Color3.fromRGB(255, 145, 35), Category = "golem" },
	titanic_bakunawa = { Main = Color3.fromRGB(20, 36, 78), Secondary = Color3.fromRGB(45, 95, 165), Accent = Color3.fromRGB(0, 250, 230), Category = "dragon" },
	titanic_dragon = { Main = Color3.fromRGB(188, 26, 42), Secondary = Color3.fromRGB(245, 135, 40), Accent = Color3.fromRGB(255, 215, 55), Category = "dragon" },
	godly_astralis = { Main = Color3.fromRGB(26, 36, 92), Secondary = Color3.fromRGB(75, 115, 215), Accent = Color3.fromRGB(165, 255, 255), Category = "dragon" },
}

local function makePart(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function weldTo(part: BasePart, root: BasePart)
	if part == root then
		return
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = part
	w.Parent = part
end

local function addEyes(model: Model, headCF: CFrame, halfWidth: number, yOff: number, zFront: number, eyeColor: Color3?)
	local col = eyeColor or Color3.fromRGB(20, 22, 28)
	makePart("EyeL", Vector3.new(0.28, 0.34, 0.14), headCF * CFrame.new(-halfWidth, yOff, zFront), col, Enum.Material.SmoothPlastic, model)
	makePart("EyeR", Vector3.new(0.28, 0.34, 0.14), headCF * CFrame.new(halfWidth, yOff, zFront), col, Enum.Material.SmoothPlastic, model)
	makePart("PupilL", Vector3.new(0.12, 0.14, 0.16), headCF * CFrame.new(-halfWidth + 0.04, yOff + 0.06, zFront - 0.01), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, model)
	makePart("PupilR", Vector3.new(0.12, 0.14, 0.16), headCF * CFrame.new(halfWidth + 0.04, yOff + 0.06, zFront - 0.01), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, model)
end

local function addFourLegs(model: Model, centerCF: CFrame, xSpread: number, zFront: number, zBack: number, legSize: Vector3, legColor: Color3, pawColor: Color3, mat: Enum.Material)
	local offsets = {
		Vector3.new(-xSpread, -0.75, zFront),
		Vector3.new(xSpread, -0.75, zFront),
		Vector3.new(-xSpread, -0.75, zBack),
		Vector3.new(xSpread, -0.75, zBack),
	}
	for i, off in offsets do
		makePart(`Leg{i}`, legSize, centerCF * CFrame.new(off), legColor, mat, model)
		makePart(`Paw{i}`, Vector3.new(legSize.X + 0.08, 0.24, legSize.Z + 0.18), centerCF * CFrame.new(off + Vector3.new(0, -legSize.Y * 0.5 + 0.08, -0.06)), pawColor, mat, model)
	end
end

function PetVisuals.BuildModel(petId: string, mutation: string?, centerCFrame: CFrame): Model
	local info = PetData.Get(petId)
	local mutInfo = MutationData.Get(mutation)
	local isSizeMutation = mutInfo ~= nil and mutInfo.ScaleMultiplier ~= nil

	-- 1) Check if the developer placed a custom 3D model in ReplicatedStorage.PetModels.<petId>
	local customFolder = ReplicatedStorage:FindFirstChild("PetModels")
	local customTemplate = customFolder and customFolder:FindFirstChild(petId)
	if customTemplate and customTemplate:IsA("Model") and customTemplate.PrimaryPart then
		local cloned = customTemplate:Clone()
		cloned.Name = `PetModel_{petId}`
		cloned:PivotTo(centerCFrame)
		local primary = cloned.PrimaryPart :: BasePart
		for _, desc in cloned:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
				desc.CanTouch = false
				desc.CanQuery = false
				if mutInfo and not isSizeMutation then
					desc.Color = mutInfo.Color
					desc.Material = mutInfo.Material
				end
				if desc ~= primary then
					weldTo(desc, primary)
				end
			end
		end
		local baseScale = if info and typeof(info.Scale) == "number" and info.Scale > 0 then info.Scale else 1
		local mutScale = if mutInfo and typeof(mutInfo.ScaleMultiplier) == "number" then mutInfo.ScaleMultiplier else 1
		local scale = math.min(11.5, baseScale * mutScale)
		if math.abs(scale - 1) > 0.01 then
			local pivotPos = centerCFrame.Position
			for _, desc in cloned:GetDescendants() do
				if desc:IsA("BasePart") then
					desc.Size *= scale
					local rel = desc.CFrame.Position - pivotPos
					local rot = desc.CFrame - desc.CFrame.Position
					desc.CFrame = CFrame.new(pivotPos + rel * scale) * rot
				end
			end
			cloned:SetAttribute("PetScale", scale)
		end
		return cloned
	end

	-- 2) Built-in Grow-a-Garden Style Voxel Species Builder
	local palette = Palettes[petId] or {
		Main = if info then Rarities.Get(info.Rarity).Color else Color3.fromRGB(200, 200, 200),
		Secondary = Color3.fromRGB(240, 240, 245),
		Accent = Color3.fromRGB(255, 200, 50),
		Category = "dog",
	}

	local mainColor = if mutInfo and not isSizeMutation then mutInfo.Color else palette.Main
	local secColor = if mutInfo and not isSizeMutation then mutInfo.Color else palette.Secondary
	local accentColor = palette.Accent
	local baseMat = if mutInfo and not isSizeMutation then mutInfo.Material else Enum.Material.SmoothPlastic
	local cat = palette.Category

	local model = Instance.new("Model")
	model.Name = `PetModel_{petId}`

	-- Root PrimaryPart (Torso)
	local body = makePart("Body", Vector3.new(1.7, 1.35, 2.2), centerCFrame, mainColor, baseMat, model)
	model.PrimaryPart = body

	if cat == "rooster" or cat == "duck" or cat == "eagle" or cat == "royal_bird" then
		-- Plump bird body + breast + distinct raised head + beak + wings + tail feathers + 2 bird legs
		body.Size = Vector3.new(1.55, 1.35, 1.85)
		makePart("Breast", Vector3.new(1.35, 1.15, 0.55), centerCFrame * CFrame.new(0, 0.05, -0.95), secColor, baseMat, model)
		local headCF = centerCFrame * CFrame.new(0, 1.05, -0.75)
		makePart("Head", Vector3.new(1.15, 1.1, 1.15), headCF, if cat == "eagle" then secColor else mainColor, baseMat, model)
		addEyes(model, headCF, 0.36, 0.1, -0.58)

		-- Beak
		if cat == "duck" then
			makePart("Bill", Vector3.new(0.78, 0.26, 0.65), headCF * CFrame.new(0, -0.1, -0.82), accentColor, baseMat, model)
		elseif cat == "eagle" then
			makePart("UpperBeak", Vector3.new(0.46, 0.34, 0.65), headCF * CFrame.new(0, -0.02, -0.82), accentColor, baseMat, model)
			makePart("BeakHook", Vector3.new(0.36, 0.28, 0.24), headCF * CFrame.new(0, -0.22, -1.04), accentColor, baseMat, model)
		else
			makePart("Beak", Vector3.new(0.42, 0.32, 0.58), headCF * CFrame.new(0, -0.05, -0.8), Color3.fromRGB(255, 175, 35), baseMat, model)
		end

		-- Rooster Comb & Wattle OR Royal Crest
		if cat == "rooster" then
			makePart("Comb1", Vector3.new(0.24, 0.48, 0.35), headCF * CFrame.new(0, 0.68, -0.2), accentColor, baseMat, model)
			makePart("Comb2", Vector3.new(0.24, 0.58, 0.35), headCF * CFrame.new(0, 0.74, 0.1), accentColor, baseMat, model)
			makePart("Wattle", Vector3.new(0.26, 0.36, 0.28), headCF * CFrame.new(0, -0.42, -0.62), accentColor, baseMat, model)
		elseif cat == "royal_bird" or cat == "eagle" then
			for i = -1, 1 do
				makePart(`CrownPlume{i}`, Vector3.new(0.2, 0.75, 0.28), headCF * CFrame.new(i * 0.24, 0.78, 0.1) * CFrame.Angles(math.rad(-22), 0, math.rad(i * -14)), accentColor, Enum.Material.Neon, model)
			end
		end

		-- Wings (multi-layered for eagles/royal birds)
		local wingSpan = if cat == "eagle" or cat == "royal_bird" then 1.35 else 0.32
		local wingLen = if cat == "eagle" or cat == "royal_bird" then 1.65 else 1.3
		makePart("WingL", Vector3.new(wingSpan, 0.85, wingLen), centerCFrame * CFrame.new(-0.85 - wingSpan * 0.35, 0.15, 0.05) * CFrame.Angles(0, 0, math.rad(15)), secColor, baseMat, model)
		makePart("WingR", Vector3.new(wingSpan, 0.85, wingLen), centerCFrame * CFrame.new(0.85 + wingSpan * 0.35, 0.15, 0.05) * CFrame.Angles(0, 0, math.rad(-15)), secColor, baseMat, model)

		-- Tail Feathers Fan
		for i = -1, 1 do
			local tailCol = if cat == "royal_bird" and i == 0 then accentColor else secColor
			local tailMat = if cat == "royal_bird" then Enum.Material.Neon else baseMat
			makePart(`TailFeather{i}`, Vector3.new(0.28, 0.85, 0.95), centerCFrame * CFrame.new(i * 0.32, 0.45, 1.15) * CFrame.Angles(math.rad(32), math.rad(i * 18), 0), tailCol, tailMat, model)
		end

		-- 2 Bird Legs & Feet
		for _, side in { -0.42, 0.42 } do
			makePart("BirdLeg", Vector3.new(0.24, 0.75, 0.24), centerCFrame * CFrame.new(side, -0.85, -0.1), Color3.fromRGB(245, 165, 35), baseMat, model)
			makePart("BirdFoot", Vector3.new(0.44, 0.18, 0.58), centerCFrame * CFrame.new(side, -1.18, -0.22), Color3.fromRGB(245, 165, 35), baseMat, model)
		end

	elseif cat == "carabao" then
		-- Muscular Kalabaw / Tamaraw body + wide head + muzzle + iconic sweeping curved horns + 4 legs with hooves
		body.Size = Vector3.new(1.95, 1.55, 2.55)
		makePart("Belly", Vector3.new(1.75, 0.35, 2.2), centerCFrame * CFrame.new(0, -0.68, 0), secColor, baseMat, model)
		local headCF = centerCFrame * CFrame.new(0, 0.45, -1.55)
		makePart("Head", Vector3.new(1.45, 1.25, 1.25), headCF, mainColor, baseMat, model)
		makePart("Muzzle", Vector3.new(1.15, 0.72, 0.55), headCF * CFrame.new(0, -0.2, -0.78), secColor, baseMat, model)
		makePart("NostrilL", Vector3.new(0.18, 0.18, 0.12), headCF * CFrame.new(-0.28, -0.15, -1.04), Color3.fromRGB(25, 25, 30), baseMat, model)
		makePart("NostrilR", Vector3.new(0.18, 0.18, 0.12), headCF * CFrame.new(0.28, -0.15, -1.04), Color3.fromRGB(25, 25, 30), baseMat, model)
		addEyes(model, headCF, 0.48, 0.18, -0.62)

		-- Sweeping Carabao Horns (Inner base + curved outer tips)
		makePart("HornBaseL", Vector3.new(0.95, 0.32, 0.34), headCF * CFrame.new(-1.05, 0.48, -0.05) * CFrame.Angles(0, 0, math.rad(12)), accentColor, baseMat, model)
		makePart("HornTipL", Vector3.new(0.32, 0.85, 0.32), headCF * CFrame.new(-1.48, 0.88, -0.15) * CFrame.Angles(math.rad(15), 0, math.rad(-15)), accentColor, baseMat, model)
		makePart("HornBaseR", Vector3.new(0.95, 0.32, 0.34), headCF * CFrame.new(1.05, 0.48, -0.05) * CFrame.Angles(0, 0, math.rad(-12)), accentColor, baseMat, model)
		makePart("HornTipR", Vector3.new(0.32, 0.85, 0.32), headCF * CFrame.new(1.48, 0.88, -0.15) * CFrame.Angles(math.rad(15), 0, math.rad(15)), accentColor, baseMat, model)

		makePart("EarL", Vector3.new(0.45, 0.28, 0.25), headCF * CFrame.new(-0.85, 0.18, 0.1), mainColor, baseMat, model)
		makePart("EarR", Vector3.new(0.45, 0.28, 0.25), headCF * CFrame.new(0.85, 0.18, 0.1), mainColor, baseMat, model)
		makePart("Tail", Vector3.new(0.26, 0.95, 0.26), centerCFrame * CFrame.new(0, 0.05, 1.38) * CFrame.Angles(math.rad(22), 0, 0), mainColor, baseMat, model)
		addFourLegs(model, centerCFrame, 0.65, -0.85, 0.85, Vector3.new(0.48, 0.95, 0.48), mainColor, Color3.fromRGB(32, 30, 35), baseMat)

	elseif cat == "fish" or cat == "whale" then
		-- Streamlined Fish / Butanding Whale Shark with dorsal fin, pectoral side fins & forked tail fin
		local isWhale = (cat == "whale")
		body.Size = if isWhale then Vector3.new(2.2, 1.35, 2.8) else Vector3.new(1.25, 1.25, 2.4)
		makePart("Underbelly", Vector3.new(body.Size.X * 0.92, 0.45, body.Size.Z * 0.94), centerCFrame * CFrame.new(0, -0.45, 0), secColor, baseMat, model)
		makePart("Snout", Vector3.new(body.Size.X * 0.85, 0.85, 0.65), centerCFrame * CFrame.new(0, -0.05, -body.Size.Z * 0.5 - 0.25), mainColor, baseMat, model)
		addEyes(model, centerCFrame * CFrame.new(0, 0.1, -body.Size.Z * 0.35), body.Size.X * 0.5, 0.08, -0.25)

		-- Dorsal Fin + Side Pectoral Fins + Tail Fin
		makePart("DorsalFin", Vector3.new(0.24, 0.85, 0.95), centerCFrame * CFrame.new(0, 0.95, 0.1) * CFrame.Angles(math.rad(-25), 0, 0), mainColor, baseMat, model)
		makePart("FinL", Vector3.new(1.05, 0.2, 0.75), centerCFrame * CFrame.new(-body.Size.X * 0.5 - 0.4, -0.25, -0.35) * CFrame.Angles(0, math.rad(20), math.rad(-15)), mainColor, baseMat, model)
		makePart("FinR", Vector3.new(1.05, 0.2, 0.75), centerCFrame * CFrame.new(body.Size.X * 0.5 + 0.4, -0.25, -0.35) * CFrame.Angles(0, math.rad(-20), math.rad(15)), mainColor, baseMat, model)
		makePart("TailBase", Vector3.new(0.65, 0.65, 0.85), centerCFrame * CFrame.new(0, 0, body.Size.Z * 0.5 + 0.35), mainColor, baseMat, model)
		makePart("TailUpper", Vector3.new(0.24, 0.95, 0.65), centerCFrame * CFrame.new(0, 0.42, body.Size.Z * 0.5 + 0.85) * CFrame.Angles(math.rad(30), 0, 0), accentColor, baseMat, model)
		makePart("TailLower", Vector3.new(0.24, 0.85, 0.65), centerCFrame * CFrame.new(0, -0.38, body.Size.Z * 0.5 + 0.85) * CFrame.Angles(math.rad(-30), 0, 0), accentColor, baseMat, model)

		if isWhale then
			for r = -1, 1 do
				for c = -1, 1 do
					makePart(`Spot_{r}_{c}`, Vector3.new(0.26, 0.1, 0.26), centerCFrame * CFrame.new(c * 0.55, 0.68, r * 0.7), accentColor, baseMat, model)
				end
			end
		end

	elseif cat == "crab" or cat == "octopus" then
		if cat == "crab" then
			-- Wide Alimango Crab carapace + 2 stalked eyes + 2 big front pincer claws + 6 side legs
			body.Size = Vector3.new(2.35, 1.05, 1.75)
			makePart("TopShell", Vector3.new(2.1, 0.35, 1.5), centerCFrame * CFrame.new(0, 0.6, 0), secColor, baseMat, model)
			makePart("EyeStalkL", Vector3.new(0.22, 0.45, 0.22), centerCFrame * CFrame.new(-0.48, 0.72, -0.78), mainColor, baseMat, model)
			makePart("EyeStalkR", Vector3.new(0.22, 0.45, 0.22), centerCFrame * CFrame.new(0.48, 0.72, -0.78), mainColor, baseMat, model)
			makePart("EyeL", Vector3.new(0.26, 0.26, 0.26), centerCFrame * CFrame.new(-0.48, 0.95, -0.82), accentColor, baseMat, model)
			makePart("EyeR", Vector3.new(0.26, 0.26, 0.26), centerCFrame * CFrame.new(0.48, 0.95, -0.82), accentColor, baseMat, model)
			-- Big Front Pincer Claws (Sipit)
			for _, side in { -1, 1 } do
				makePart(`Arm{side}`, Vector3.new(0.45, 0.4, 0.95), centerCFrame * CFrame.new(side * 1.15, 0.05, -0.95) * CFrame.Angles(0, math.rad(side * -25), 0), mainColor, baseMat, model)
				makePart(`PincerOuter{side}`, Vector3.new(0.58, 0.48, 0.95), centerCFrame * CFrame.new(side * 1.15, 0.1, -1.65) * CFrame.Angles(0, math.rad(side * 18), 0), mainColor, baseMat, model)
				makePart(`PincerInner{side}`, Vector3.new(0.28, 0.35, 0.75), centerCFrame * CFrame.new(side * 0.82, 0.05, -1.58), secColor, baseMat, model)
			end
			for zIdx = -1, 1 do
				makePart(`CrabLegL{zIdx}`, Vector3.new(0.85, 0.25, 0.26), centerCFrame * CFrame.new(-1.45, -0.35, zIdx * 0.5) * CFrame.Angles(0, 0, math.rad(28)), mainColor, baseMat, model)
				makePart(`CrabLegR{zIdx}`, Vector3.new(0.85, 0.25, 0.26), centerCFrame * CFrame.new(1.45, -0.35, zIdx * 0.5) * CFrame.Angles(0, 0, math.rad(-28)), mainColor, baseMat, model)
			end
		else
			-- Octopus rounded dome head + cute eyes + 8 curled tentacles
			body.Size = Vector3.new(1.85, 1.75, 1.85)
			makePart("HeadTop", Vector3.new(1.55, 0.45, 1.55), centerCFrame * CFrame.new(0, 1.0, 0), secColor, baseMat, model)
			addEyes(model, centerCFrame, 0.48, 0.1, -0.92)
			makePart("MouthFunnel", Vector3.new(0.42, 0.38, 0.35), centerCFrame * CFrame.new(0, -0.35, -0.98), accentColor, baseMat, model)
			for a = 1, 8 do
				local ang = (a / 8) * math.pi * 2
				local dirCF = centerCFrame * CFrame.Angles(0, ang, 0)
				makePart(`Tentacle{a}`, Vector3.new(0.42, 0.36, 1.25), dirCF * CFrame.new(0, -0.78, -1.15) * CFrame.Angles(math.rad(12), 0, 0), secColor, baseMat, model)
				makePart(`TentacleTip{a}`, Vector3.new(0.32, 0.32, 0.45), dirCF * CFrame.new(0, -0.62, -1.82) * CFrame.Angles(math.rad(35), 0, 0), accentColor, baseMat, model)
			end
		end

	elseif cat == "turtle" then
		-- Pagong / Pawikan: Layered domed shell + extended front head + 4 flippers/legs + tail
		body.Size = Vector3.new(2.1, 0.85, 2.35)
		body.Color = accentColor
		makePart("ShellLower", Vector3.new(2.35, 0.65, 2.55), centerCFrame * CFrame.new(0, 0.35, 0.05), secColor, baseMat, model)
		makePart("ShellDome", Vector3.new(1.85, 0.55, 2.05), centerCFrame * CFrame.new(0, 0.82, 0.05), mainColor, baseMat, model)
		local headCF = centerCFrame * CFrame.new(0, 0.25, -1.58)
		makePart("Head", Vector3.new(0.95, 0.88, 1.05), headCF, mainColor, baseMat, model)
		addEyes(model, headCF, 0.34, 0.12, -0.52)
		addFourLegs(model, centerCFrame, 0.95, -0.78, 0.82, Vector3.new(0.55, 0.55, 0.65), mainColor, secColor, baseMat)
		makePart("Tail", Vector3.new(0.32, 0.28, 0.55), centerCFrame * CFrame.new(0, -0.1, 1.45), mainColor, baseMat, model)

	elseif cat == "lizard" then
		-- Bayawak / Hunyanggo Chameleon: Sleek reptile body + dorsal spine ridge + big turret eyes + curled tail + 4 splayed legs
		body.Size = Vector3.new(1.35, 1.15, 2.35)
		local headCF = centerCFrame * CFrame.new(0, 0.35, -1.48)
		makePart("Head", Vector3.new(1.2, 1.05, 1.25), headCF, mainColor, baseMat, model)
		makePart("HeadCrest", Vector3.new(0.45, 0.65, 0.85), headCF * CFrame.new(0, 0.55, 0.15) * CFrame.Angles(math.rad(-25), 0, 0), secColor, baseMat, model)
		addEyes(model, headCF, 0.55, 0.18, -0.35, accentColor)
		for s = -2, 2 do
			makePart(`Spine{s}`, Vector3.new(0.22, 0.42, 0.34), centerCFrame * CFrame.new(0, 0.72, s * 0.44), accentColor, baseMat, model)
		end
		makePart("Tail1", Vector3.new(0.65, 0.65, 1.15), centerCFrame * CFrame.new(0, 0.05, 1.55), mainColor, baseMat, model)
		makePart("TailCurl", Vector3.new(0.48, 0.75, 0.75), centerCFrame * CFrame.new(0, 0.25, 2.25), accentColor, baseMat, model)
		addFourLegs(model, centerCFrame, 0.78, -0.75, 0.75, Vector3.new(0.42, 0.72, 0.42), secColor, accentColor, baseMat)

	elseif cat == "dragon" or cat == "hydra" then
		-- Epic Voxel Dragon / Bakunawa / Hydra: Armored chest, horned dragon head(s), large wings, spiked back & long tail
		body.Size = Vector3.new(1.9, 1.55, 2.55)
		makePart("ChestArmor", Vector3.new(1.55, 1.35, 2.25), centerCFrame * CFrame.new(0, -0.15, -0.08), secColor, baseMat, model)

		local headOffsets = if cat == "hydra"
			then { Vector3.new(-0.95, 0.85, -1.55), Vector3.new(0, 1.15, -1.75), Vector3.new(0.95, 0.85, -1.55) }
			else { Vector3.new(0, 0.85, -1.65) }

		for hIdx, hOff in headOffsets do
			local headCF = centerCFrame * CFrame.new(hOff)
			makePart(`Neck{hIdx}`, Vector3.new(0.75, 0.95, 0.85), centerCFrame * CFrame.new(hOff * 0.55), mainColor, baseMat, model)
			makePart(`Head{hIdx}`, Vector3.new(1.25, 1.1, 1.25), headCF, mainColor, baseMat, model)
			makePart(`Snout{hIdx}`, Vector3.new(0.95, 0.62, 0.85), headCF * CFrame.new(0, -0.15, -0.88), mainColor, baseMat, model)
			addEyes(model, headCF, 0.46, 0.18, -0.62, accentColor)
			makePart(`HornL{hIdx}`, Vector3.new(0.26, 0.88, 0.28), headCF * CFrame.new(-0.42, 0.78, 0.2) * CFrame.Angles(math.rad(-32), 0, math.rad(16)), accentColor, Enum.Material.Neon, model)
			makePart(`HornR{hIdx}`, Vector3.new(0.26, 0.88, 0.28), headCF * CFrame.new(0.42, 0.78, 0.2) * CFrame.Angles(math.rad(-32), 0, math.rad(-16)), accentColor, Enum.Material.Neon, model)
		end

		-- Mighty Dragon Wings
		for _, side in { -1, 1 } do
			makePart(`WingArm{side}`, Vector3.new(1.65, 0.32, 0.35), centerCFrame * CFrame.new(side * 1.6, 0.75, -0.35) * CFrame.Angles(0, 0, math.rad(side * -22)), mainColor, baseMat, model)
			makePart(`WingMembrane{side}`, Vector3.new(1.85, 0.18, 1.75), centerCFrame * CFrame.new(side * 1.85, 0.58, 0.35) * CFrame.Angles(math.rad(10), 0, math.rad(side * -18)), accentColor, Enum.Material.Neon, model)
		end

		-- Spiked Spine & Tail
		for s = -1, 2 do
			makePart(`BackSpike{s}`, Vector3.new(0.26, 0.55, 0.38), centerCFrame * CFrame.new(0, 0.95, s * 0.58) * CFrame.Angles(math.rad(-20), 0, 0), accentColor, Enum.Material.Neon, model)
		end
		makePart("Tail1", Vector3.new(0.95, 0.85, 1.35), centerCFrame * CFrame.new(0, -0.05, 1.75), mainColor, baseMat, model)
		makePart("Tail2", Vector3.new(0.65, 0.6, 1.25), centerCFrame * CFrame.new(0, 0.15, 2.75) * CFrame.Angles(math.rad(15), 0, 0), mainColor, baseMat, model)
		makePart("TailBlade", Vector3.new(0.85, 0.28, 0.85), centerCFrame * CFrame.new(0, 0.32, 3.45), accentColor, Enum.Material.Neon, model)
		addFourLegs(model, centerCFrame, 0.72, -0.82, 0.82, Vector3.new(0.55, 0.95, 0.55), mainColor, accentColor, baseMat)

	elseif cat == "golem" then
		-- Hulking Semi-Titanic Golem with broad shoulders, glowing core crystal, horned helm & heavy fists
		body.Size = Vector3.new(2.35, 1.95, 1.85)
		makePart("CoreCrystal", Vector3.new(0.85, 0.85, 0.35), centerCFrame * CFrame.new(0, 0.15, -0.85) * CFrame.Angles(0, 0, math.rad(45)), accentColor, Enum.Material.Neon, model)
		local headCF = centerCFrame * CFrame.new(0, 1.45, -0.15)
		makePart("Head", Vector3.new(1.35, 1.15, 1.25), headCF, mainColor, baseMat, model)
		addEyes(model, headCF, 0.38, 0.08, -0.62, accentColor)
		makePart("ShoulderL", Vector3.new(1.1, 1.1, 1.25), centerCFrame * CFrame.new(-1.65, 0.55, 0), secColor, baseMat, model)
		makePart("ShoulderR", Vector3.new(1.1, 1.1, 1.25), centerCFrame * CFrame.new(1.65, 0.55, 0), secColor, baseMat, model)
		makePart("ArmL", Vector3.new(0.85, 1.65, 0.85), centerCFrame * CFrame.new(-1.75, -0.45, -0.15), mainColor, baseMat, model)
		makePart("ArmR", Vector3.new(0.85, 1.65, 0.85), centerCFrame * CFrame.new(1.75, -0.45, -0.15), mainColor, baseMat, model)
		makePart("LegL", Vector3.new(0.9, 1.15, 0.95), centerCFrame * CFrame.new(-0.68, -1.25, 0), secColor, baseMat, model)
		makePart("LegR", Vector3.new(0.9, 1.15, 0.95), centerCFrame * CFrame.new(0.68, -1.25, 0), secColor, baseMat, model)

	elseif cat == "unicorn" then
		-- Tikbalang / Rainbow Unicorn / Godly Bathala: Proud equine head, snout, flowing mane, horn/crown, 4 hooves & tail
		body.Size = Vector3.new(1.65, 1.45, 2.35)
		makePart("Neck", Vector3.new(0.95, 1.25, 0.95), centerCFrame * CFrame.new(0, 0.78, -0.95) * CFrame.Angles(math.rad(18), 0, 0), mainColor, baseMat, model)
		local headCF = centerCFrame * CFrame.new(0, 1.48, -1.35)
		makePart("Head", Vector3.new(1.15, 1.05, 1.25), headCF, mainColor, baseMat, model)
		makePart("Snout", Vector3.new(0.85, 0.68, 0.75), headCF * CFrame.new(0, -0.15, -0.85), secColor, baseMat, model)
		addEyes(model, headCF, 0.44, 0.15, -0.58)
		makePart("Horn", Vector3.new(0.28, 1.15, 0.28), headCF * CFrame.new(0, 0.85, -0.35) * CFrame.Angles(math.rad(26), 0, 0), accentColor, Enum.Material.Neon, model)
		makePart("EarL", Vector3.new(0.28, 0.58, 0.26), headCF * CFrame.new(-0.42, 0.68, 0.2), mainColor, baseMat, model)
		makePart("EarR", Vector3.new(0.28, 0.58, 0.26), headCF * CFrame.new(0.42, 0.68, 0.2), mainColor, baseMat, model)
		for m = 0, 3 do
			makePart(`Mane{m}`, Vector3.new(0.34, 0.55, 0.45), headCF * CFrame.new(0, 0.35 - m * 0.36, 0.65 + m * 0.12), accentColor, Enum.Material.Neon, model)
		end
		makePart("Tail", Vector3.new(0.45, 1.15, 0.55), centerCFrame * CFrame.new(0, 0.1, 1.38) * CFrame.Angles(math.rad(25), 0, 0), accentColor, Enum.Material.Neon, model)
		addFourLegs(model, centerCFrame, 0.55, -0.82, 0.82, Vector3.new(0.42, 1.05, 0.42), mainColor, secColor, baseMat)

	else
		-- Quadruped Mammals (cat, ninja_cat, dog, deer, kitsune, lion, bunny, pig, tarsier, hamster, raccoon, panda, capybara, sigbin)
		body.Size = Vector3.new(1.65, 1.35, 2.15)
		makePart("Belly", Vector3.new(1.42, 0.32, 1.85), centerCFrame * CFrame.new(0, -0.58, 0), secColor, baseMat, model)

		local headCF = centerCFrame * CFrame.new(0, 0.72, -1.15)
		local headSize = if cat == "tarsier" or cat == "hamster" then Vector3.new(1.55, 1.35, 1.35) else Vector3.new(1.42, 1.25, 1.32)
		makePart("Head", headSize, headCF, mainColor, baseMat, model)

		-- Species Muzzle / Snout / Facial Mask
		if cat == "pig" then
			makePart("PigSnout", Vector3.new(0.82, 0.56, 0.42), headCF * CFrame.new(0, -0.12, -0.78), accentColor, baseMat, model)
			makePart("NostrilL", Vector3.new(0.16, 0.22, 0.12), headCF * CFrame.new(-0.18, -0.12, -0.96), Color3.fromRGB(165, 65, 85), baseMat, model)
			makePart("NostrilR", Vector3.new(0.16, 0.22, 0.12), headCF * CFrame.new(0.18, -0.12, -0.96), Color3.fromRGB(165, 65, 85), baseMat, model)
		elseif cat == "capybara" then
			makePart("CapySnout", Vector3.new(1.15, 0.88, 0.85), headCF * CFrame.new(0, -0.08, -0.85), secColor, baseMat, model)
			makePart("DiamondCrown", Vector3.new(0.75, 0.48, 0.75), headCF * CFrame.new(0, 0.82, 0), accentColor, Enum.Material.Neon, model)
		elseif cat == "panda" or cat == "raccoon" then
			makePart("EyePatchL", Vector3.new(0.52, 0.52, 0.14), headCF * CFrame.new(-0.36, 0.08, -0.64), accentColor, baseMat, model)
			makePart("EyePatchR", Vector3.new(0.52, 0.52, 0.14), headCF * CFrame.new(0.36, 0.08, -0.64), accentColor, baseMat, model)
			makePart("Muzzle", Vector3.new(0.68, 0.46, 0.42), headCF * CFrame.new(0, -0.2, -0.78), secColor, baseMat, model)
			makePart("Nose", Vector3.new(0.26, 0.2, 0.16), headCF * CFrame.new(0, -0.1, -0.98), accentColor, baseMat, model)
		else
			makePart("Muzzle", Vector3.new(0.75, 0.48, 0.48), headCF * CFrame.new(0, -0.18, -0.78), secColor, baseMat, model)
			makePart("Nose", Vector3.new(0.26, 0.2, 0.18), headCF * CFrame.new(0, -0.08, -1.0), accentColor, baseMat, model)
		end

		-- Eyes (Tarsier gets huge glowing golden eyes!)
		if cat == "tarsier" then
			makePart("SaucerEyeL", Vector3.new(0.62, 0.62, 0.22), headCF * CFrame.new(-0.4, 0.12, -0.68), accentColor, Enum.Material.Neon, model)
			makePart("SaucerEyeR", Vector3.new(0.62, 0.62, 0.22), headCF * CFrame.new(0.4, 0.12, -0.68), accentColor, Enum.Material.Neon, model)
			makePart("PupilL", Vector3.new(0.26, 0.28, 0.26), headCF * CFrame.new(-0.4, 0.12, -0.72), Color3.fromRGB(20, 20, 25), baseMat, model)
			makePart("PupilR", Vector3.new(0.26, 0.28, 0.26), headCF * CFrame.new(0.4, 0.12, -0.72), Color3.fromRGB(20, 20, 25), baseMat, model)
		else
			addEyes(model, headCF, 0.38, 0.12, -0.67, if cat == "sigbin" or cat == "kitsune" then accentColor else nil)
		end

		-- Species Ears / Mane / Headband
		if cat == "bunny" then
			for _, side in { -1, 1 } do
				makePart(`EarOuter{side}`, Vector3.new(0.38, 1.35, 0.28), headCF * CFrame.new(side * 0.42, 1.15, 0.05) * CFrame.Angles(0, 0, math.rad(side * -8)), mainColor, baseMat, model)
				makePart(`EarInner{side}`, Vector3.new(0.22, 1.05, 0.14), headCF * CFrame.new(side * 0.42, 1.12, -0.05) * CFrame.Angles(0, 0, math.rad(side * -8)), accentColor, baseMat, model)
			end
		elseif cat == "lion" then
			makePart("LionMane", Vector3.new(2.05, 1.95, 1.15), headCF * CFrame.new(0, 0.05, 0.18), secColor, baseMat, model)
			makePart("MechaVisor", Vector3.new(1.15, 0.28, 0.22), headCF * CFrame.new(0, 0.16, -0.65), accentColor, Enum.Material.Neon, model)
		elseif cat == "panda" or cat == "raccoon" or cat == "hamster" or cat == "tarsier" or cat == "capybara" then
			local earCol = if cat == "panda" or cat == "raccoon" then accentColor else mainColor
			makePart("EarL", Vector3.new(0.46, 0.46, 0.26), headCF * CFrame.new(-0.56, 0.68, 0.05), earCol, baseMat, model)
			makePart("EarR", Vector3.new(0.46, 0.46, 0.26), headCF * CFrame.new(0.56, 0.68, 0.05), earCol, baseMat, model)
		else
			makePart("EarL", Vector3.new(0.42, 0.68, 0.32), headCF * CFrame.new(-0.48, 0.78, 0.05) * CFrame.Angles(0, 0, math.rad(12)), mainColor, baseMat, model)
			makePart("EarR", Vector3.new(0.42, 0.68, 0.32), headCF * CFrame.new(0.48, 0.78, 0.05) * CFrame.Angles(0, 0, math.rad(-12)), mainColor, baseMat, model)
			if cat == "ninja_cat" then
				makePart("NinjaBand", Vector3.new(1.48, 0.28, 1.38), headCF * CFrame.new(0, 0.32, 0), accentColor, Enum.Material.Neon, model)
				makePart("Katana", Vector3.new(0.18, 0.22, 2.15), centerCFrame * CFrame.new(0.55, 0.65, 0.15) * CFrame.Angles(math.rad(25), 0, math.rad(-20)), accentColor, Enum.Material.Neon, model)
			end
		end

		-- Species Tails (Kitsune gets 5 fanned glowing tails!)
		if cat == "kitsune" then
			for t = -2, 2 do
				makePart(`KitsuneTail{t}`, Vector3.new(0.38, 0.45, 1.55), centerCFrame * CFrame.new(t * 0.34, 0.35, 1.55) * CFrame.Angles(math.rad(28), math.rad(t * 18), 0), mainColor, baseMat, model)
				makePart(`KitsuneTip{t}`, Vector3.new(0.42, 0.48, 0.55), centerCFrame * CFrame.new(t * 0.55, 0.72, 2.25) * CFrame.Angles(math.rad(28), math.rad(t * 18), 0), accentColor, Enum.Material.Neon, model)
			end
		elseif cat == "bunny" or cat == "hamster" or cat == "deer" then
			makePart("PuffTail", Vector3.new(0.48, 0.48, 0.48), centerCFrame * CFrame.new(0, 0.15, 1.22), secColor, baseMat, model)
		else
			makePart("Tail", Vector3.new(0.34, 0.38, 1.15), centerCFrame * CFrame.new(0, 0.28, 1.42) * CFrame.Angles(math.rad(28), 0, 0), if cat == "raccoon" then accentColor else mainColor, baseMat, model)
		end

		local legCol = if cat == "panda" or cat == "raccoon" then accentColor else mainColor
		addFourLegs(model, centerCFrame, 0.54, -0.68, 0.68, Vector3.new(0.42, 0.85, 0.42), legCol, secColor, baseMat)
	end

	-- Weld all parts to PrimaryPart so the model can be carried or animated as one unit
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and desc ~= body then
			weldTo(desc, body)
		end
	end

	-- Apply Semi-Titanic (4.5x) or Titanic (9.0x..11.0x) scale around centerCFrame!
	local baseScale = if info and typeof(info.Scale) == "number" and info.Scale > 0 then info.Scale else 1
	local mutScale = if mutInfo and typeof(mutInfo.ScaleMultiplier) == "number" then mutInfo.ScaleMultiplier else 1
	local scale = math.min(11.5, baseScale * mutScale)
	if math.abs(scale - 1) > 0.01 then
		local pivotPos = centerCFrame.Position
		for _, desc in model:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Size *= scale
				local rel = desc.CFrame.Position - pivotPos
				local rot = desc.CFrame - desc.CFrame.Position
				desc.CFrame = CFrame.new(pivotPos + rel * scale) * rot
			end
		end
		model:SetAttribute("PetScale", scale)
	end

	return model
end

return PetVisuals
