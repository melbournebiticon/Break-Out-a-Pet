-- BlockoutEnemies.luau
-- NOT part of the Rojo project. Copy ALL of this, paste it into the Roblox Studio
-- COMMAND BAR (bottom of the Output window), and press Ctrl+Enter.
-- Run it in EDIT mode (not while playing). It builds:
--   Workspace.PatrolPoints (4 patrol points in Zone1 and 4 in Zone2)
--   Workspace.EnemySpawns  (Zone1 Warden, Zone2 Warden + Guard Dog)
-- Afterwards press Ctrl+S to save the place file.

local CollectionService = game:GetService("CollectionService")

local function makeMarker(name, position, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(2, 2, 2)
	part.Position = position
	part.Color = color
	part.Transparency = 0.5
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function build()
	if workspace:FindFirstChild("EnemySpawns") then
		warn("Workspace.EnemySpawns already exists. Delete EnemySpawns (and PatrolPoints) first if you want to rebuild.")
		return
	end

	-- PATROL POINTS -----------------------------------------------------
	local patrolFolder = workspace:FindFirstChild("PatrolPoints")
	if not patrolFolder then
		patrolFolder = Instance.new("Folder")
		patrolFolder.Name = "PatrolPoints"
		patrolFolder.Parent = workspace
	end

	local patrolPoints = {
		Zone1 = {
			Vector3.new(-30, 3, -100),
			Vector3.new(30, 3, -100),
			Vector3.new(30, 3, -60),
			Vector3.new(-30, 3, -60),
		},
		Zone2 = {
			Vector3.new(-30, 3, -180),
			Vector3.new(30, 3, -180),
			Vector3.new(30, 3, -140),
			Vector3.new(-30, 3, -140),
		},
	}

	for zoneName, list in patrolPoints do
		for i, pos in list do
			local point = makeMarker(`{zoneName}_Patrol{i}`, pos, Color3.fromRGB(255, 220, 60), patrolFolder)
			point:SetAttribute("Zone", zoneName)
			CollectionService:AddTag(point, "PatrolPoint")
		end
	end

	-- ENEMY SPAWNS ------------------------------------------------------
	local spawnsFolder = Instance.new("Folder")
	spawnsFolder.Name = "EnemySpawns"
	spawnsFolder.Parent = workspace

	local spawns = {
		{ name = "Zone1_Warden", enemyType = "Warden", zone = "Zone1", pos = Vector3.new(0, 3, -55), speedMult = 0.85 },
		{ name = "Zone2_Warden", enemyType = "Warden", zone = "Zone2", pos = Vector3.new(-30, 3, -140), speedMult = 1 },
		{ name = "Zone2_Dog", enemyType = "Dog", zone = "Zone2", pos = Vector3.new(30, 3, -140), speedMult = 1 },
	}

	for _, info in spawns do
		local spawnPart = makeMarker(info.name, info.pos, Color3.fromRGB(255, 70, 70), spawnsFolder)
		spawnPart:SetAttribute("EnemyType", info.enemyType)
		spawnPart:SetAttribute("Zone", info.zone)
		spawnPart:SetAttribute("SpeedMultiplier", info.speedMult)
		CollectionService:AddTag(spawnPart, "EnemySpawn")
	end

	print("Enemy blockout done! Now press Ctrl+S to save the place.")
end

build()
