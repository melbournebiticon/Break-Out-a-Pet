--!strict
-- CageVisuals.luau
-- Builds authentic 3D Pinoy cages:
--   1) "DerbyBoxBlue" / "DerbyBoxRed" / "DerbyBoxGold": The iconic Coroplast Derby Carry Box (Cock Box)
--      with blue/red/gold front & pitched roof, white sides, top cutout handle ridge, black straps, and round air holes!
--   2) "BambooTangkal": Traditional woven bamboo/wood slatted farm hutch for rabbits & farm pets.
--   3) "PalengkeCrate": Colorful slatted plastic Palengke / Cartimar crate.
--   4) "RattanKaing": Woven brown bamboo/rattan Kaing basket with tied lid.
--   5) "HaciendaBaul": Carved Narra wood & gold wrought-iron Hacienda vault cage.

local CageVisuals = {}

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
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Exact 3D replica of the Blue & White Coroplast Derby Carry Box (Photo 2)
local function buildDerbyCockBox(model: Model, centerPos: Vector3, mainColor: Color3, sideColor: Color3)
	local cf = CFrame.new(centerPos)
	local strapColor = Color3.fromRGB(22, 24, 28)
	local holeColor = Color3.fromRGB(18, 22, 32)

	-- Box main lower body (white side walls visible on left/right, colored front/back)
	makePart("WhiteCoreBox", Vector3.new(4.3, 3.0, 3.2), cf * CFrame.new(0, -0.5, 0), sideColor, Enum.Material.SmoothPlastic, model)
	makePart("FrontPanel", Vector3.new(4.4, 3.0, 0.18), cf * CFrame.new(0, -0.5, -1.58), mainColor, Enum.Material.SmoothPlastic, model)
	makePart("BackPanel", Vector3.new(4.4, 3.0, 0.18), cf * CFrame.new(0, -0.5, 1.58), mainColor, Enum.Material.SmoothPlastic, model)

	-- Gable triangle filler on left & right sides under the pitched roof
	makePart("SideGableUpper", Vector3.new(4.28, 0.9, 1.6), cf * CFrame.new(0, 1.35, 0), sideColor, Enum.Material.SmoothPlastic, model)

	-- Pitched Angled Roof Flaps (Left & Right slopes meeting at the top handle ridge)
	makePart(
		"RoofFrontSlope",
		Vector3.new(4.55, 0.18, 2.05),
		cf * CFrame.new(0, 1.48, -0.82) * CFrame.Angles(math.rad(28), 0, 0),
		mainColor,
		Enum.Material.SmoothPlastic,
		model
	)
	makePart(
		"RoofBackSlope",
		Vector3.new(4.55, 0.18, 2.05),
		cf * CFrame.new(0, 1.48, 0.82) * CFrame.Angles(math.rad(-28), 0, 0),
		mainColor,
		Enum.Material.SmoothPlastic,
		model
	)

	-- Top Vertical Carry Handle Fin + Cutout Handle Hole + Black Velcro Top Strap
	makePart("HandleFinL", Vector3.new(1.5, 0.85, 0.24), cf * CFrame.new(-1.4, 2.25, 0), mainColor, Enum.Material.SmoothPlastic, model)
	makePart("HandleFinR", Vector3.new(1.5, 0.85, 0.24), cf * CFrame.new(1.4, 2.25, 0), mainColor, Enum.Material.SmoothPlastic, model)
	makePart("HandleTopBar", Vector3.new(4.3, 0.28, 0.26), cf * CFrame.new(0, 2.55, 0), mainColor, Enum.Material.SmoothPlastic, model)
	makePart("TopVelcroStrap", Vector3.new(0.42, 0.15, 1.1), cf * CFrame.new(-0.15, 1.98, -0.35) * CFrame.Angles(math.rad(20), math.rad(15), 0), strapColor, Enum.Material.Fabric, model)

	-- Two Black Bottom Closure Straps on the Front
	makePart("BottomStrapL", Vector3.new(0.32, 0.85, 0.24), cf * CFrame.new(-1.1, -1.6, -1.62), strapColor, Enum.Material.Fabric, model)
	makePart("BottomStrapR", Vector3.new(0.32, 0.85, 0.24), cf * CFrame.new(0.6, -1.6, -1.62), strapColor, Enum.Material.Fabric, model)

	-- Diamond-pattern round ventilation holes on the front panel (just like Photo 2!)
	local frontHoleOffsets = {
		Vector3.new(-1.2, 0.0, -1.68),
		Vector3.new(-0.7, 0.25, -1.68),
		Vector3.new(-0.7, -0.25, -1.68),
		Vector3.new(-0.2, 0.45, -1.68),
		Vector3.new(-0.2, 0.0, -1.68),
		Vector3.new(-0.2, -0.45, -1.68),
		Vector3.new(0.3, 0.25, -1.68),
		Vector3.new(0.3, -0.25, -1.68),
		Vector3.new(0.8, 0.0, -1.68),
	}
	for idx, off in frontHoleOffsets do
		makePart(`VentF{idx}`, Vector3.new(0.26, 0.26, 0.08), cf * CFrame.new(off), holeColor, Enum.Material.SmoothPlastic, model)
	end

	-- Side ventilation holes on the white side panels
	local sideHoleOffsets = {
		Vector3.new(2.18, 0.1, -0.55),
		Vector3.new(2.18, -0.45, -0.55),
		Vector3.new(2.18, 0.1, 0.55),
		Vector3.new(2.18, -0.45, 0.55),
		Vector3.new(-2.18, 0.1, -0.55),
		Vector3.new(-2.18, -0.45, -0.55),
	}
	for idx, off in sideHoleOffsets do
		makePart(`VentS{idx}`, Vector3.new(0.08, 0.26, 0.26), cf * CFrame.new(off), holeColor, Enum.Material.SmoothPlastic, model)
	end
end

local function buildBambooTangkal(model: Model, centerPos: Vector3)
	local woodColor = Color3.fromRGB(185, 140, 78)
	local darkWood = Color3.fromRGB(125, 86, 44)
	makePart("BasePlate", Vector3.new(4.6, 0.4, 4.2), CFrame.new(centerPos + Vector3.new(0, -1.9, 0)), darkWood, Enum.Material.WoodPlanks, model)
	makePart("TopPlate", Vector3.new(4.6, 0.35, 4.2), CFrame.new(centerPos + Vector3.new(0, 1.8, 0)), darkWood, Enum.Material.WoodPlanks, model)
	makePart("NipaRoof", Vector3.new(5.0, 0.5, 4.6), CFrame.new(centerPos + Vector3.new(0, 2.2, 0)), Color3.fromRGB(155, 115, 58), Enum.Material.WoodPlanks, model)

	local barOffsets = {
		Vector3.new(-2.0, 0, -1.8), Vector3.new(-0.7, 0, -1.8), Vector3.new(0.7, 0, -1.8), Vector3.new(2.0, 0, -1.8),
		Vector3.new(-2.0, 0, 0), Vector3.new(2.0, 0, 0),
		Vector3.new(-2.0, 0, 1.8), Vector3.new(-0.7, 0, 1.8), Vector3.new(0.7, 0, 1.8), Vector3.new(2.0, 0, 1.8),
	}
	for idx, off in barOffsets do
		makePart(`BambooBar{idx}`, Vector3.new(0.26, 3.6, 0.26), CFrame.new(centerPos + off), woodColor, Enum.Material.Wood, model)
	end
end

local function buildPalengkeCrate(model: Model, centerPos: Vector3, crateColor: Color3)
	makePart("Base", Vector3.new(4.6, 0.35, 3.8), CFrame.new(centerPos + Vector3.new(0, -1.85, 0)), crateColor, Enum.Material.Plastic, model)
	makePart("Lid", Vector3.new(4.6, 0.3, 3.8), CFrame.new(centerPos + Vector3.new(0, 1.85, 0)), Color3.fromRGB(240, 240, 245), Enum.Material.Plastic, model)
	-- Horizontal plastic crate slats
	for row = -1, 1 do
		local y = row * 1.0
		makePart(`FrontSlat{row}`, Vector3.new(4.6, 0.45, 0.25), CFrame.new(centerPos + Vector3.new(0, y, -1.78)), crateColor, Enum.Material.Plastic, model)
		makePart(`BackSlat{row}`, Vector3.new(4.6, 0.45, 0.25), CFrame.new(centerPos + Vector3.new(0, y, 1.78)), crateColor, Enum.Material.Plastic, model)
		makePart(`LeftSlat{row}`, Vector3.new(0.25, 0.45, 3.8), CFrame.new(centerPos + Vector3.new(-2.18, y, 0)), crateColor, Enum.Material.Plastic, model)
		makePart(`RightSlat{row}`, Vector3.new(0.25, 0.45, 3.8), CFrame.new(centerPos + Vector3.new(2.18, y, 0)), crateColor, Enum.Material.Plastic, model)
	end
	for idx, off in { Vector3.new(-2.15, 0, -1.75), Vector3.new(2.15, 0, -1.75), Vector3.new(-2.15, 0, 1.75), Vector3.new(2.15, 0, 1.75) } do
		makePart(`Corner{idx}`, Vector3.new(0.35, 3.6, 0.35), CFrame.new(centerPos + off), crateColor, Enum.Material.Plastic, model)
	end
end

local function buildRattanKaing(model: Model, centerPos: Vector3)
	local rattan = Color3.fromRGB(168, 118, 62)
	local rim = Color3.fromRGB(115, 75, 35)
	makePart("KaingBody", Vector3.new(3.8, 3.6, 3.8), CFrame.new(centerPos), rattan, Enum.Material.WoodPlanks, model)
	makePart("BottomRim", Vector3.new(4.1, 0.4, 4.1), CFrame.new(centerPos + Vector3.new(0, -1.65, 0)), rim, Enum.Material.Wood, model)
	makePart("MidBand", Vector3.new(4.1, 0.35, 4.1), CFrame.new(centerPos), rim, Enum.Material.Wood, model)
	makePart("TopLid", Vector3.new(4.3, 0.45, 4.3), CFrame.new(centerPos + Vector3.new(0, 1.75, 0)), rim, Enum.Material.Wood, model)
	makePart("RedTie", Vector3.new(1.2, 0.35, 4.4), CFrame.new(centerPos + Vector3.new(0, 1.85, 0)), Color3.fromRGB(215, 45, 45), Enum.Material.Fabric, model)
end

local function buildHaciendaBaul(model: Model, centerPos: Vector3)
	local narra = Color3.fromRGB(85, 42, 24)
	local gold = Color3.fromRGB(245, 195, 55)
	makePart("NarraBase", Vector3.new(4.8, 0.5, 4.4), CFrame.new(centerPos + Vector3.new(0, -1.9, 0)), narra, Enum.Material.Wood, model)
	makePart("NarraRoof", Vector3.new(4.8, 0.55, 4.4), CFrame.new(centerPos + Vector3.new(0, 1.9, 0)), narra, Enum.Material.Wood, model)
	makePart("GoldTrimBottom", Vector3.new(4.9, 0.2, 4.5), CFrame.new(centerPos + Vector3.new(0, -1.6, 0)), gold, Enum.Material.Metal, model)
	makePart("GoldTrimTop", Vector3.new(4.9, 0.2, 4.5), CFrame.new(centerPos + Vector3.new(0, 1.6, 0)), gold, Enum.Material.Metal, model)

	local barOffsets = {
		Vector3.new(-2.1, 0, -1.9), Vector3.new(-0.7, 0, -1.9), Vector3.new(0.7, 0, -1.9), Vector3.new(2.1, 0, -1.9),
		Vector3.new(-2.1, 0, 0), Vector3.new(2.1, 0, 0),
		Vector3.new(-2.1, 0, 1.9), Vector3.new(0, 0, 1.9), Vector3.new(2.1, 0, 1.9),
	}
	for idx, off in barOffsets do
		makePart(`GoldBar{idx}`, Vector3.new(0.28, 3.4, 0.28), CFrame.new(centerPos + off), gold, Enum.Material.Metal, model)
	end
	makePart("Padlock", Vector3.new(0.65, 0.85, 0.35), CFrame.new(centerPos + Vector3.new(0, -0.2, -2.05)), gold, Enum.Material.Neon, model)
end

local function buildBambooKural(model: Model, centerPos: Vector3)
	-- Wooden/Bamboo livestock pen for Kalabaw & Tamaraw
	local bamboo = Color3.fromRGB(165, 122, 66)
	local darkWood = Color3.fromRGB(110, 72, 36)
	makePart("KuralBase", Vector3.new(5.4, 0.4, 5.2), CFrame.new(centerPos + Vector3.new(0, -1.9, 0)), darkWood, Enum.Material.WoodPlanks, model)
	for _, off in { Vector3.new(-2.4, 0, -2.3), Vector3.new(2.4, 0, -2.3), Vector3.new(-2.4, 0, 2.3), Vector3.new(2.4, 0, 2.3) } do
		makePart("Post", Vector3.new(0.4, 3.6, 0.4), CFrame.new(centerPos + off), darkWood, Enum.Material.Wood, model)
	end
	for _, y in { -0.8, 0.2, 1.2 } do
		makePart("RailF", Vector3.new(5.0, 0.3, 0.22), CFrame.new(centerPos + Vector3.new(0, y, -2.3)), bamboo, Enum.Material.Wood, model)
		makePart("RailB", Vector3.new(5.0, 0.3, 0.22), CFrame.new(centerPos + Vector3.new(0, y, 2.3)), bamboo, Enum.Material.Wood, model)
		makePart("RailL", Vector3.new(0.22, 0.3, 4.8), CFrame.new(centerPos + Vector3.new(-2.4, y, 0)), bamboo, Enum.Material.Wood, model)
		makePart("RailR", Vector3.new(0.22, 0.3, 4.8), CFrame.new(centerPos + Vector3.new(2.4, y, 0)), bamboo, Enum.Material.Wood, model)
	end
end

local function buildStyrofoamIceBox(model: Model, centerPos: Vector3)
	-- Classic white Palengke Styrofoam Ice Box with blue lid & stripes for Bangus/Alimango/Butanding/Pawikan
	local styro = Color3.fromRGB(242, 245, 250)
	local blueLid = Color3.fromRGB(35, 135, 225)
	makePart("IceBoxBody", Vector3.new(4.8, 3.2, 3.6), CFrame.new(centerPos + Vector3.new(0, -0.4, 0)), styro, Enum.Material.SmoothPlastic, model)
	makePart("IceBoxLid", Vector3.new(5.0, 0.55, 3.8), CFrame.new(centerPos + Vector3.new(0, 1.45, 0)), blueLid, Enum.Material.Plastic, model)
	makePart("BlueStripe", Vector3.new(4.86, 0.35, 3.66), CFrame.new(centerPos + Vector3.new(0, -0.4, 0)), blueLid, Enum.Material.Plastic, model)
end

local function buildBangaTapayan(model: Model, centerPos: Vector3)
	-- Traditional Brown Clay Jar ("Banga / Tapayan") for mystical folklore pets (Sigbin, Tikbalang, Bakunawa)
	local clay = Color3.fromRGB(152, 84, 48)
	local darkClay = Color3.fromRGB(108, 56, 30)
	makePart("JarBase", Vector3.new(3.4, 0.8, 3.4), CFrame.new(centerPos + Vector3.new(0, -1.7, 0)), darkClay, Enum.Material.Slate, model)
	makePart("JarBelly", Vector3.new(4.4, 2.4, 4.4), CFrame.new(centerPos + Vector3.new(0, -0.3, 0)), clay, Enum.Material.Slate, model, Enum.PartType.Ball)
	makePart("JarNeck", Vector3.new(2.8, 0.9, 2.8), CFrame.new(centerPos + Vector3.new(0, 1.2, 0)), clay, Enum.Material.Slate, model)
	makePart("JarRim", Vector3.new(3.4, 0.4, 3.4), CFrame.new(centerPos + Vector3.new(0, 1.75, 0)), darkClay, Enum.Material.Slate, model)
end

function CageVisuals.PickStyleForZoneSlot(zoneName: string, slotIndex: number): string
	if zoneName == "Zone1" then
		local styles = { "DerbyBoxBlue", "BambooTangkal", "BambooKural", "DerbyBoxRed" }
		return styles[((slotIndex - 1) % #styles) + 1]
	elseif zoneName == "Zone2" then
		local styles = { "StyrofoamIceBox", "PalengkeCrateGreen", "RattanKaing", "PalengkeCrateYellow" }
		return styles[((slotIndex - 1) % #styles) + 1]
	elseif zoneName == "Zone3" then
		local styles = { "HaciendaBaul", "BambooKural", "BambooTangkal", "StyrofoamIceBox" }
		return styles[((slotIndex - 1) % #styles) + 1]
	elseif zoneName == "Zone4" then
		local styles = { "BambooTangkal", "StyrofoamIceBox", "DerbyBoxGold", "RattanKaing" }
		return styles[((slotIndex - 1) % #styles) + 1]
	elseif zoneName == "Zone5" then
		local styles = { "BangaTapayan", "BambooKural", "DerbyBoxGold", "StyrofoamIceBox" }
		return styles[((slotIndex - 1) % #styles) + 1]
	else
		local styles = { "DerbyBoxGold", "BangaTapayan", "HaciendaBaul", "BambooKural" }
		return styles[((slotIndex - 1) % #styles) + 1]
	end
end

function CageVisuals.PickStyleForPet(petId: string, zoneName: string?): string
	if petId == "chicken" or petId == "duckling" or petId == "agila" or petId == "sarimanok" or petId == "minokawa" then
		return if petId == "sarimanok" or petId == "minokawa" then "DerbyBoxGold" else "DerbyBoxBlue"
	elseif petId == "kalabaw" or petId == "tamaraw" then
		return "BambooKural"
	elseif petId == "bangus" or petId == "alimango" or petId == "butanding" or petId == "pawikan" then
		return "StyrofoamIceBox"
	elseif petId == "sigbin" or petId == "tikbalang" or petId == "bakunawa" then
		return "BangaTapayan"
	elseif petId == "bunny" or petId == "puspin" or petId == "pilandok" or petId == "bayawak" then
		return "BambooTangkal"
	elseif zoneName == "Zone2" then
		return "PalengkeCrateGreen"
	elseif zoneName == "Zone3" then
		return "HaciendaBaul"
	end
	return "RattanKaing"
end

function CageVisuals.PopulateCageModel(model: Model, centerPos: Vector3, style: string, coreColor: Color3)
	if style == "DerbyBoxBlue" then
		buildDerbyCockBox(model, centerPos, Color3.fromRGB(0, 118, 215), Color3.fromRGB(238, 242, 248))
	elseif style == "DerbyBoxRed" then
		buildDerbyCockBox(model, centerPos, Color3.fromRGB(215, 38, 45), Color3.fromRGB(238, 242, 248))
	elseif style == "DerbyBoxGold" then
		buildDerbyCockBox(model, centerPos, Color3.fromRGB(235, 175, 30), Color3.fromRGB(35, 35, 45))
	elseif style == "BambooTangkal" then
		buildBambooTangkal(model, centerPos)
	elseif style == "BambooKural" then
		buildBambooKural(model, centerPos)
	elseif style == "StyrofoamIceBox" then
		buildStyrofoamIceBox(model, centerPos)
	elseif style == "BangaTapayan" then
		buildBangaTapayan(model, centerPos)
	elseif style == "PalengkeCrateGreen" then
		buildPalengkeCrate(model, centerPos, Color3.fromRGB(45, 175, 85))
	elseif style == "PalengkeCrateYellow" then
		buildPalengkeCrate(model, centerPos, Color3.fromRGB(235, 180, 35))
	elseif style == "RattanKaing" then
		buildRattanKaing(model, centerPos)
	elseif style == "HaciendaBaul" then
		buildHaciendaBaul(model, centerPos)
	else
		buildDerbyCockBox(model, centerPos, Color3.fromRGB(0, 118, 215), Color3.fromRGB(238, 242, 248))
	end

	local core = makePart("MysteryCore", Vector3.new(1.5, 1.5, 1.5), CFrame.new(centerPos + Vector3.new(0, -0.3, 0)), coreColor, Enum.Material.Neon, model, Enum.PartType.Ball)
	core.Transparency = 0.25
end

return CageVisuals
