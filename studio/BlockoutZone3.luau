-- BlockoutZone3.luau
-- NOT part of Rojo. Paste into the Studio command bar in Edit mode and press Ctrl+Enter.

local CollectionService = game:GetService("CollectionService")

local function makePart(name, size, position, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeMarker(name, position, color, parent)
	local part = makePart(name, Vector3.new(2, 2, 2), position, color, parent)
	part.Transparency = 0.5
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	return part
end

local function build()
	local prison = workspace:FindFirstChild("Prison")
	if not prison then
		warn("Workspace.Prison not found. Run studio/Blockout.luau first.")
		return
	end
	if prison:FindFirstChild("Zone3") then
		warn("Prison.Zone3 already exists.")
		return
	end

	local zone3 = Instance.new("Folder")
	zone3.Name = "Zone3"
	zone3.Parent = prison

	makePart("Floor", Vector3.new(80, 1, 60), Vector3.new(0, 0.5, -240), Color3.fromRGB(85, 65, 110), zone3)

	for i = 1, 4 do
		local cage = Instance.new("Model")
		cage.Name = "Cage" .. i
		local body = makePart("Body", Vector3.new(4, 4, 4), Vector3.new(-30 + i * 12, 3, -240), Color3.fromRGB(60, 60, 60), cage)
		body.Material = Enum.Material.Metal
		cage.PrimaryPart = body
		cage:SetAttribute("Zone", "Zone3")
		CollectionService:AddTag(cage, "Cage")
		cage.Parent = zone3
	end

	for idx, lz in { -220, -240, -260 } do
		local laser = makePart(`Laser{idx}`, Vector3.new(76, 1.2, 0.6), Vector3.new(0, 3.2, lz), Color3.fromRGB(255, 45, 45), zone3)
		laser.Material = Enum.Material.Neon
		laser.CanCollide = false
		laser:SetAttribute("OnSeconds", 2.5)
		laser:SetAttribute("OffSeconds", 2.0)
		CollectionService:AddTag(laser, "Laser")
	end

	local patrolFolder = workspace:FindFirstChild("PatrolPoints")
	if patrolFolder then
		for i, pos in { Vector3.new(-30, 3, -260), Vector3.new(30, 3, -260), Vector3.new(30, 3, -220), Vector3.new(-30, 3, -220) } do
			local pt = makeMarker(`Zone3_Patrol{i}`, pos, Color3.fromRGB(255, 220, 60), patrolFolder)
			pt:SetAttribute("Zone", "Zone3")
			CollectionService:AddTag(pt, "PatrolPoint")
		end
	end

	local spawnsFolder = workspace:FindFirstChild("EnemySpawns")
	if spawnsFolder then
		local w = makeMarker("Zone3_Warden", Vector3.new(-30, 3, -220), Color3.fromRGB(255, 70, 70), spawnsFolder)
		w:SetAttribute("EnemyType", "Warden")
		w:SetAttribute("Zone", "Zone3")
		w:SetAttribute("SpeedMultiplier", 1.1)
		CollectionService:AddTag(w, "EnemySpawn")

		local d = makeMarker("Zone3_Dog", Vector3.new(30, 3, -220), Color3.fromRGB(255, 70, 70), spawnsFolder)
		d:SetAttribute("EnemyType", "Dog")
		d:SetAttribute("Zone", "Zone3")
		d:SetAttribute("SpeedMultiplier", 1.1)
		CollectionService:AddTag(d, "EnemySpawn")
	end

	print("Zone3 blockout done! Now press Ctrl+S to save the place.")
end

build()
