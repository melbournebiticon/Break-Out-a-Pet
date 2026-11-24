-- Blockout.luau
-- NOT part of the Rojo project. Copy ALL of this, paste it into the Roblox Studio
-- COMMAND BAR (bottom of the Output window), and press Ctrl+Enter.
-- Run it in EDIT mode (not while playing). It builds:
--   Workspace.Prison (Zone1, Zone2 with 4 tagged Cage models each)
--   Workspace.BasePlots (Plot1..Plot6, each with Floor, Spawn, and a green DropZone)
-- Afterwards press Ctrl+S to save the place file.

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

local function build()
	if workspace:FindFirstChild("Prison") or workspace:FindFirstChild("BasePlots") then
		warn("Prison or BasePlots already exists. Delete them first if you want to rebuild.")
		return
	end

	-- PRISON ------------------------------------------------------------
	local prison = Instance.new("Folder")
	prison.Name = "Prison"
	prison.Parent = workspace

	local zones = {
		{ name = "Zone1", z = -80, color = Color3.fromRGB(120, 120, 130) },
		{ name = "Zone2", z = -160, color = Color3.fromRGB(150, 110, 90) },
	}

	for _, zoneInfo in zones do
		local zone = Instance.new("Folder")
		zone.Name = zoneInfo.name
		zone.Parent = prison

		makePart("Floor", Vector3.new(80, 1, 60), Vector3.new(0, 0.5, zoneInfo.z), zoneInfo.color, zone)

		for i = 1, 4 do
			local cage = Instance.new("Model")
			cage.Name = "Cage" .. i

			local body = makePart(
				"Body",
				Vector3.new(4, 4, 4),
				Vector3.new(-30 + i * 12, 3, zoneInfo.z),
				Color3.fromRGB(60, 60, 60),
				cage
			)
			body.Material = Enum.Material.Metal

			cage.PrimaryPart = body
			cage:SetAttribute("Zone", zoneInfo.name)
			CollectionService:AddTag(cage, "Cage")
			cage.Parent = zone
		end
	end

	-- BASE PLOTS --------------------------------------------------------
	local plots = Instance.new("Folder")
	plots.Name = "BasePlots"
	plots.Parent = workspace

	for i = 1, 6 do
		local x = (i - 3.5) * 50

		local plot = Instance.new("Model")
		plot.Name = "Plot" .. i

		local floor = makePart("Floor", Vector3.new(40, 1, 40), Vector3.new(x, 0.5, 40), Color3.fromRGB(90, 160, 90), plot)
		plot.PrimaryPart = floor

		local spawnPart = Instance.new("SpawnLocation")
		spawnPart.Name = "Spawn"
		spawnPart.Size = Vector3.new(6, 1, 6)
		spawnPart.Position = Vector3.new(x, 1.5, 50)
		spawnPart.Anchored = true
		spawnPart.Neutral = true
		spawnPart.Duration = 0
		spawnPart.Parent = plot

		local drop = makePart("DropZone", Vector3.new(14, 1, 14), Vector3.new(x, 1.5, 28), Color3.fromRGB(60, 255, 120), plot)
		drop.Material = Enum.Material.Neon
		drop.Transparency = 0.5
		drop.CanCollide = false
		CollectionService:AddTag(drop, "DropZone")

		plot.Parent = plots
	end

	print("Blockout done! Now press Ctrl+S to save the place.")
end

build()
