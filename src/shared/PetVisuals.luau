--!strict
-- PetVisuals.luau
-- Procedural 3D chibi animal model builder for all pets in the game.
-- Creates recognizable 3D pet models (head, eyes, snout, ears/horns/wings/tail/shell) with rarity & mutation styling.

local PetData = require(script.Parent.PetData)
local Rarities = require(script.Parent.Rarities)
local MutationData = require(script.Parent.MutationData)

local PetVisuals = {}

export type SpeciesPalette = {
	Main: Color3,
	Accent: Color3,
	Feature: string, -- "ears_round" | "ears_tall" | "ears_pointed" | "duck" | "turtle" | "pig" | "raccoon" | "panda" | "chameleon" | "phoenix" | "octopus" | "capybara" | "dragon" | "kitsune" | "unicorn" | "cat"
}

local Palettes: { [string]: SpeciesPalette } = {
	chicken = { Main = Color3.fromRGB(250, 248, 240), Accent = Color3.fromRGB(225, 45, 45), Feature = "chicken" },
	duckling = { Main = Color3.fromRGB(255, 225, 65), Accent = Color3.fromRGB(255, 145, 35), Feature = "duck" },
	puspin = { Main = Color3.fromRGB(235, 155, 75), Accent = Color3.fromRGB(250, 240, 225), Feature = "cat" },
	bunny = { Main = Color3.fromRGB(245, 240, 250), Accent = Color3.fromRGB(255, 175, 195), Feature = "ears_tall" },
	aspin = { Main = Color3.fromRGB(175, 120, 68), Accent = Color3.fromRGB(235, 205, 165), Feature = "ears_pointed" },
	kalabaw = { Main = Color3.fromRGB(72, 68, 70), Accent = Color3.fromRGB(215, 210, 195), Feature = "dragon" },

	turtle = { Main = Color3.fromRGB(95, 195, 95), Accent = Color3.fromRGB(45, 125, 55), Feature = "turtle" },
	bangus = { Main = Color3.fromRGB(235, 205, 75), Accent = Color3.fromRGB(255, 245, 185), Feature = "duck" },
	alimango = { Main = Color3.fromRGB(215, 65, 45), Accent = Color3.fromRGB(255, 145, 75), Feature = "octopus" },
	golden_pig = { Main = Color3.fromRGB(255, 200, 75), Accent = Color3.fromRGB(255, 150, 165), Feature = "pig" },
	ninja_cat = { Main = Color3.fromRGB(45, 48, 62), Accent = Color3.fromRGB(220, 45, 55), Feature = "cat" },

	bayawak = { Main = Color3.fromRGB(85, 145, 65), Accent = Color3.fromRGB(215, 205, 95), Feature = "chameleon" },
	pawikan = { Main = Color3.fromRGB(65, 165, 135), Accent = Color3.fromRGB(35, 95, 75), Feature = "turtle" },
	tarsier = { Main = Color3.fromRGB(145, 105, 68), Accent = Color3.fromRGB(255, 210, 90), Feature = "ears_round" },
	chameleon = { Main = Color3.fromRGB(80, 225, 120), Accent = Color3.fromRGB(255, 215, 60), Feature = "chameleon" },

	pilandok = { Main = Color3.fromRGB(165, 110, 62), Accent = Color3.fromRGB(245, 235, 220), Feature = "ears_pointed" },
	agila = { Main = Color3.fromRGB(120, 85, 55), Accent = Color3.fromRGB(245, 240, 230), Feature = "phoenix" },
	butanding = { Main = Color3.fromRGB(55, 125, 195), Accent = Color3.fromRGB(225, 245, 255), Feature = "octopus" },
	phoenix = { Main = Color3.fromRGB(255, 110, 30), Accent = Color3.fromRGB(255, 220, 55), Feature = "phoenix" },

	tamaraw = { Main = Color3.fromRGB(58, 52, 48), Accent = Color3.fromRGB(220, 215, 200), Feature = "dragon" },
	sigbin = { Main = Color3.fromRGB(45, 35, 52), Accent = Color3.fromRGB(255, 65, 85), Feature = "ears_pointed" },
	minokawa = { Main = Color3.fromRGB(35, 45, 75), Accent = Color3.fromRGB(255, 195, 45), Feature = "phoenix" },

	sarimanok = { Main = Color3.fromRGB(255, 185, 35), Accent = Color3.fromRGB(235, 45, 85), Feature = "phoenix" },
	tikbalang = { Main = Color3.fromRGB(95, 65, 42), Accent = Color3.fromRGB(255, 185, 55), Feature = "unicorn" },
	bakunawa = { Main = Color3.fromRGB(25, 55, 95), Accent = Color3.fromRGB(0, 245, 220), Feature = "dragon" },

	hamster = { Main = Color3.fromRGB(235, 175, 110), Accent = Color3.fromRGB(255, 235, 210), Feature = "ears_round" },
	raccoon = { Main = Color3.fromRGB(135, 140, 150), Accent = Color3.fromRGB(40, 42, 48), Feature = "raccoon" },
	panda = { Main = Color3.fromRGB(245, 245, 245), Accent = Color3.fromRGB(30, 30, 35), Feature = "panda" },
	octopus = { Main = Color3.fromRGB(235, 85, 145), Accent = Color3.fromRGB(255, 165, 205), Feature = "octopus" },
	diamond_capybara = { Main = Color3.fromRGB(115, 225, 255), Accent = Color3.fromRGB(210, 250, 255), Feature = "capybara" },
	wolf = { Main = Color3.fromRGB(130, 140, 160), Accent = Color3.fromRGB(220, 225, 235), Feature = "ears_pointed" },
	mini_dragon = { Main = Color3.fromRGB(215, 45, 65), Accent = Color3.fromRGB(255, 185, 45), Feature = "dragon" },
	shadow_kitsune = { Main = Color3.fromRGB(35, 25, 55), Accent = Color3.fromRGB(170, 85, 255), Feature = "kitsune" },
	rainbow_unicorn = { Main = Color3.fromRGB(250, 245, 255), Accent = Color3.fromRGB(255, 120, 220), Feature = "unicorn" },
}

local function makePart(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, parent: Instance, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
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

function PetVisuals.BuildModel(petId: string, mutation: string?, centerCFrame: CFrame): Model
	local info = PetData.Get(petId)
	local palette = Palettes[petId] or {
		Main = if info then Rarities.Get(info.Rarity).Color else Color3.fromRGB(200, 200, 200),
		Accent = Color3.fromRGB(255, 255, 255),
		Feature = "ears_round",
	}

	local mutInfo = MutationData.Get(mutation)
	local mainColor = if mutInfo then mutInfo.Color else palette.Main
	local accentColor = palette.Accent
	local baseMat = if mutInfo then mutInfo.Material else Enum.Material.SmoothPlastic

	local model = Instance.new("Model")
	model.Name = `PetModel_{petId}`

	-- Chibi rounded torso/head body
	local body = makePart("Body", Vector3.new(2.4, 2.2, 2.6), centerCFrame, mainColor, baseMat, model)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Brick
	mesh.Parent = body
	model.PrimaryPart = body

	-- Belly / chest patch
	makePart("Belly", Vector3.new(1.6, 1.3, 0.2), centerCFrame * CFrame.new(0, -0.2, -1.25), accentColor, Enum.Material.SmoothPlastic, model)

	-- Cute eyes
	local eyeColor = if mutInfo and mutInfo.Name == "Shadow" then Color3.fromRGB(255, 70, 220) else Color3.fromRGB(25, 25, 30)
	local eyeMat = if mutInfo and mutInfo.Name == "Shadow" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	makePart("LeftEye", Vector3.new(0.35, 0.45, 0.2), centerCFrame * CFrame.new(-0.55, 0.35, -1.26), eyeColor, eyeMat, model)
	makePart("RightEye", Vector3.new(0.35, 0.45, 0.2), centerCFrame * CFrame.new(0.55, 0.35, -1.26), eyeColor, eyeMat, model)
	-- Eye shine
	makePart("LeftShine", Vector3.new(0.14, 0.14, 0.22), centerCFrame * CFrame.new(-0.48, 0.45, -1.28), Color3.new(1, 1, 1), Enum.Material.Neon, model)
	makePart("RightShine", Vector3.new(0.14, 0.14, 0.22), centerCFrame * CFrame.new(0.62, 0.45, -1.28), Color3.new(1, 1, 1), Enum.Material.Neon, model)

	-- 4 cute little feet
	local footPositions = {
		Vector3.new(-0.75, -1.1, -0.75),
		Vector3.new(0.75, -1.1, -0.75),
		Vector3.new(-0.75, -1.1, 0.75),
		Vector3.new(0.75, -1.1, 0.75),
	}
	for i, fp in footPositions do
		makePart(`Foot{i}`, Vector3.new(0.6, 0.4, 0.7), centerCFrame * CFrame.new(fp), accentColor, baseMat, model)
	end

	-- Species-specific 3D features
	local feat = palette.Feature
	if feat == "ears_round" then
		makePart("EarL", Vector3.new(0.7, 0.7, 0.3), centerCFrame * CFrame.new(-0.85, 1.15, -0.3), mainColor, baseMat, model)
		makePart("EarR", Vector3.new(0.7, 0.7, 0.3), centerCFrame * CFrame.new(0.85, 1.15, -0.3), mainColor, baseMat, model)
		makePart("Snout", Vector3.new(0.5, 0.35, 0.3), centerCFrame * CFrame.new(0, 0.05, -1.35), Color3.fromRGB(255, 150, 165), Enum.Material.SmoothPlastic, model)
	elseif feat == "ears_tall" then
		makePart("EarL", Vector3.new(0.5, 1.6, 0.35), centerCFrame * CFrame.new(-0.6, 1.7, -0.2), mainColor, baseMat, model)
		makePart("EarR", Vector3.new(0.5, 1.6, 0.35), centerCFrame * CFrame.new(0.6, 1.7, -0.2), mainColor, baseMat, model)
		makePart("InnerL", Vector3.new(0.28, 1.2, 0.38), centerCFrame * CFrame.new(-0.6, 1.65, -0.22), accentColor, Enum.Material.SmoothPlastic, model)
		makePart("InnerR", Vector3.new(0.28, 1.2, 0.38), centerCFrame * CFrame.new(0.6, 1.65, -0.22), accentColor, Enum.Material.SmoothPlastic, model)
		makePart("Tail", Vector3.new(0.65, 0.65, 0.65), centerCFrame * CFrame.new(0, -0.3, 1.45), Color3.new(1, 1, 1), baseMat, model, Enum.PartType.Ball)
	elseif feat == "ears_pointed" or feat == "kitsune" then
		makePart("EarL", Vector3.new(0.6, 0.9, 0.4), centerCFrame * CFrame.new(-0.75, 1.35, -0.3), mainColor, baseMat, model)
		makePart("EarR", Vector3.new(0.6, 0.9, 0.4), centerCFrame * CFrame.new(0.75, 1.35, -0.3), mainColor, baseMat, model)
		makePart("Snout", Vector3.new(0.9, 0.6, 0.7), centerCFrame * CFrame.new(0, -0.05, -1.45), accentColor, baseMat, model)
		makePart("Nose", Vector3.new(0.3, 0.25, 0.25), centerCFrame * CFrame.new(0, 0.12, -1.8), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic, model)
		if feat == "kitsune" then
			for t = -1, 1 do
				makePart(`Tail{t}`, Vector3.new(0.55, 1.4, 1.2), centerCFrame * CFrame.new(t * 0.65, 0.3, 1.6) * CFrame.Angles(math.rad(-25), math.rad(t * 22), 0), accentColor, Enum.Material.Neon, model)
			end
		else
			makePart("Tail", Vector3.new(0.75, 0.75, 1.6), centerCFrame * CFrame.new(0, 0, 1.8) * CFrame.Angles(math.rad(20), 0, 0), mainColor, baseMat, model)
			makePart("TailTip", Vector3.new(0.65, 0.65, 0.6), centerCFrame * CFrame.new(0, 0.28, 2.55), accentColor, baseMat, model)
		end
	elseif feat == "duck" then
		makePart("Beak", Vector3.new(1.0, 0.35, 0.65), centerCFrame * CFrame.new(0, 0.05, -1.5), accentColor, Enum.Material.SmoothPlastic, model)
		makePart("WingL", Vector3.new(0.3, 1.0, 1.4), centerCFrame * CFrame.new(-1.3, 0, 0), mainColor, baseMat, model)
		makePart("WingR", Vector3.new(0.3, 1.0, 1.4), centerCFrame * CFrame.new(1.3, 0, 0), mainColor, baseMat, model)
	elseif feat == "chicken" then
		makePart("Beak", Vector3.new(0.55, 0.35, 0.65), centerCFrame * CFrame.new(0, 0.05, -1.5), Color3.fromRGB(255, 165, 35), Enum.Material.SmoothPlastic, model)
		makePart("Comb", Vector3.new(0.35, 0.65, 1.0), centerCFrame * CFrame.new(0, 1.35, -0.2), accentColor, Enum.Material.SmoothPlastic, model)
		makePart("Wattle", Vector3.new(0.35, 0.4, 0.3), centerCFrame * CFrame.new(0, -0.35, -1.35), accentColor, Enum.Material.SmoothPlastic, model)
		makePart("WingL", Vector3.new(0.3, 1.0, 1.4), centerCFrame * CFrame.new(-1.3, 0, 0), mainColor, baseMat, model)
		makePart("WingR", Vector3.new(0.3, 1.0, 1.4), centerCFrame * CFrame.new(1.3, 0, 0), mainColor, baseMat, model)
	elseif feat == "turtle" then
		makePart("Shell", Vector3.new(2.8, 1.7, 3.0), centerCFrame * CFrame.new(0, 0.25, 0.1), accentColor, Enum.Material.SmoothPlastic, model)
	elseif feat == "pig" then
		makePart("Snout", Vector3.new(1.0, 0.65, 0.45), centerCFrame * CFrame.new(0, 0.05, -1.42), accentColor, Enum.Material.SmoothPlastic, model)
		makePart("EarL", Vector3.new(0.55, 0.6, 0.3), centerCFrame * CFrame.new(-0.8, 1.15, -0.5), mainColor, baseMat, model)
		makePart("EarR", Vector3.new(0.55, 0.6, 0.3), centerCFrame * CFrame.new(0.8, 1.15, -0.5), mainColor, baseMat, model)
	elseif feat == "cat" then
		makePart("EarL", Vector3.new(0.55, 0.75, 0.35), centerCFrame * CFrame.new(-0.75, 1.3, -0.3), mainColor, baseMat, model)
		makePart("EarR", Vector3.new(0.55, 0.75, 0.35), centerCFrame * CFrame.new(0.75, 1.3, -0.3), mainColor, baseMat, model)
		makePart("Headband", Vector3.new(2.5, 0.38, 2.7), centerCFrame * CFrame.new(0, 0.72, 0), accentColor, Enum.Material.Neon, model)
		makePart("Tail", Vector3.new(0.35, 1.4, 0.35), centerCFrame * CFrame.new(0, 0.4, 1.45) * CFrame.Angles(math.rad(-25), 0, 0), mainColor, baseMat, model)
	elseif feat == "raccoon" or feat == "panda" then
		makePart("Mask", Vector3.new(2.2, 0.65, 0.25), centerCFrame * CFrame.new(0, 0.35, -1.22), accentColor, Enum.Material.SmoothPlastic, model)
		makePart("EarL", Vector3.new(0.65, 0.65, 0.35), centerCFrame * CFrame.new(-0.85, 1.2, -0.3), accentColor, Enum.Material.SmoothPlastic, model)
		makePart("EarR", Vector3.new(0.65, 0.65, 0.35), centerCFrame * CFrame.new(0.85, 1.2, -0.3), accentColor, Enum.Material.SmoothPlastic, model)
		if feat == "raccoon" then
			makePart("Tail", Vector3.new(0.75, 0.75, 1.6), centerCFrame * CFrame.new(0, -0.1, 1.8), accentColor, baseMat, model)
		end
	elseif feat == "phoenix" or feat == "dragon" then
		makePart("WingL", Vector3.new(1.8, 0.3, 1.5), centerCFrame * CFrame.new(-1.8, 0.3, 0.1) * CFrame.Angles(0, 0, math.rad(20)), accentColor, Enum.Material.Neon, model)
		makePart("WingR", Vector3.new(1.8, 0.3, 1.5), centerCFrame * CFrame.new(1.8, 0.3, 0.1) * CFrame.Angles(0, 0, math.rad(-20)), accentColor, Enum.Material.Neon, model)
		makePart("Crest", Vector3.new(0.4, 1.0, 1.2), centerCFrame * CFrame.new(0, 1.4, 0), accentColor, Enum.Material.Neon, model)
	elseif feat == "unicorn" then
		makePart("Horn", Vector3.new(0.35, 1.3, 0.35), centerCFrame * CFrame.new(0, 1.6, -0.9) * CFrame.Angles(math.rad(20), 0, 0), Color3.fromRGB(255, 220, 60), Enum.Material.Neon, model)
		makePart("Mane", Vector3.new(0.45, 1.3, 1.5), centerCFrame * CFrame.new(0, 1.1, 0.4), accentColor, Enum.Material.Neon, model)
	elseif feat == "octopus" then
		for a = 1, 6 do
			local ang = (a / 6) * math.pi * 2
			makePart(`Tentacle{a}`, Vector3.new(0.55, 0.4, 1.3), centerCFrame * CFrame.new(math.cos(ang) * 1.3, -0.9, math.sin(ang) * 1.3), accentColor, baseMat, model)
		end
	elseif feat == "capybara" or feat == "chameleon" then
		makePart("Snout", Vector3.new(1.2, 0.85, 0.7), centerCFrame * CFrame.new(0, 0.05, -1.45), accentColor, baseMat, model)
		makePart("Crown", Vector3.new(0.9, 0.6, 0.9), centerCFrame * CFrame.new(0, 1.35, 0), Color3.fromRGB(120, 245, 255), Enum.Material.Neon, model)
	end

	-- Weld all parts to PrimaryPart so the model can be carried or animated as one unit
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and desc ~= body then
			weldTo(desc, body)
		end
	end

	return model
end

return PetVisuals
