--!strict
-- PamaloConfig.luau
-- Defines the 5 Tatak Pinoy non-violent comedy slapstick Pamalo tools and builds their 3D low-poly models.

export type PamaloInfo = {
	Id: string,
	DisplayName: string,
	Emoji: string,
	Order: number,
	Cost: number,
	Cooldown: number,
	Reach: number,
	Knockback: number,
	GuardStun: number,
	IsAoE: boolean,
	RagdollSeconds: number,
	SpeedBoostMult: number,
	SpeedBoostSeconds: number,
	Description: string,
}

local Tools: { [string]: PamaloInfo } = {
	tsinelas_spartan = {
		Id = "tsinelas_spartan",
		DisplayName = "Tsinelas (Spartan)",
		Emoji = "🩴",
		Order = 1,
		Cost = 0,
		Cooldown = 1.2,
		Reach = 6.5,
		Knockback = 25,
		GuardStun = 1.0,
		IsAoE = false,
		RagdollSeconds = 1.1,
		SpeedBoostMult = 1.0,
		SpeedBoostSeconds = 0,
		Description = "Starter Pinoy rubber slipper! Slaps players face-down & drops cages!",
	},
	nakarolyong_dyaryo = {
		Id = "nakarolyong_dyaryo",
		DisplayName = "Nakarolyong Dyaryo",
		Emoji = "🗞️",
		Order = 2,
		Cost = 500,
		Cooldown = 0.7,
		Reach = 7.5,
		Knockback = 30,
		GuardStun = 1.2,
		IsAoE = false,
		RagdollSeconds = 1.2,
		SpeedBoostMult = 1.0,
		SpeedBoostSeconds = 0,
		Description = "Fast-swinging rolled newspaper with extra reach!",
	},
	walis_tingting = {
		Id = "walis_tingting",
		DisplayName = "Walis Tingting",
		Emoji = "🧹",
		Order = 3,
		Cost = 3500,
		Cooldown = 0.85,
		Reach = 9.0,
		Knockback = 40,
		GuardStun = 1.5,
		IsAoE = false,
		RagdollSeconds = 1.35,
		SpeedBoostMult = 1.0,
		SpeedBoostSeconds = 0,
		Description = "Long-reach coconut broomstick that knocks players face-down!",
	},
	walis_tambo = {
		Id = "walis_tambo",
		DisplayName = "Walis Tambo",
		Emoji = "🧹",
		Order = 4,
		Cost = 25000,
		Cooldown = 1.1,
		Reach = 9.0,
		Knockback = 55,
		GuardStun = 2.0,
		IsAoE = true,
		RagdollSeconds = 1.5,
		SpeedBoostMult = 1.0,
		SpeedBoostSeconds = 0,
		Description = "Wide cone AoE sweep! Knocks multiple players face-down!",
	},
	gintong_tsinelas = {
		Id = "gintong_tsinelas",
		DisplayName = "Gintong Tsinelas",
		Emoji = "✨",
		Order = 5,
		Cost = 150000,
		Cooldown = 0.75,
		Reach = 10.5,
		Knockback = 70,
		GuardStun = 2.5,
		IsAoE = true,
		RagdollSeconds = 1.8,
		SpeedBoostMult = 1.25,
		SpeedBoostSeconds = 2.0,
		Description = "Legendary Golden Slipper! Massive knockback + 25% speed boost on hit!",
	},
}

local OrderedList: { PamaloInfo } = {
	Tools.tsinelas_spartan,
	Tools.nakarolyong_dyaryo,
	Tools.walis_tingting,
	Tools.walis_tambo,
	Tools.gintong_tsinelas,
}

local PamaloConfig = {
	Tools = Tools,
	OrderedList = OrderedList,
}

function PamaloConfig.Get(id: string): PamaloInfo?
	return Tools[id]
end

local function makeSubPart(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, parent: Instance, anchored: boolean): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.Anchored = anchored
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function weldParts(a: BasePart, b: BasePart)
	if a == b then
		return
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- Builds the 3D low-poly parts for a Pamalo tool (used both for the equippable Tool and the shop stand displays).
function PamaloConfig.BuildToolParts(toolId: string, baseCF: CFrame, parent: Instance, anchored: boolean): BasePart
	local handle = makeSubPart("Handle", Vector3.new(0.45, 1.2, 0.45), baseCF, Color3.fromRGB(220, 220, 225), Enum.Material.SmoothPlastic, parent, anchored)
	local created: { BasePart } = {}

	if toolId == "tsinelas_spartan" or toolId == "gintong_tsinelas" then
		local isGold = (toolId == "gintong_tsinelas")
		local soleColor = if isGold then Color3.fromRGB(255, 200, 35) else Color3.fromRGB(20, 105, 220)
		local strapColor = if isGold then Color3.fromRGB(255, 240, 150) else Color3.fromRGB(245, 248, 255)
		local mat = if isGold then Enum.Material.Neon else Enum.Material.SmoothPlastic

		handle.Size = Vector3.new(0.85, 1.7, 0.22)
		handle.Color = soleColor
		handle.Material = mat

		-- White inner sole layer + Y-shape tsinelas straps
		table.insert(created, makeSubPart("InnerSole", Vector3.new(0.8, 1.65, 0.08), baseCF * CFrame.new(0, 0, -0.12), strapColor, Enum.Material.SmoothPlastic, parent, anchored))
		table.insert(created, makeSubPart("StrapL", Vector3.new(0.14, 0.75, 0.18), baseCF * CFrame.new(-0.18, 0.2, -0.22) * CFrame.Angles(0, 0, math.rad(-22)), strapColor, mat, parent, anchored))
		table.insert(created, makeSubPart("StrapR", Vector3.new(0.14, 0.75, 0.18), baseCF * CFrame.new(0.18, 0.2, -0.22) * CFrame.Angles(0, 0, math.rad(22)), strapColor, mat, parent, anchored))

	elseif toolId == "nakarolyong_dyaryo" then
		local paperColor = Color3.fromRGB(238, 232, 215)
		local inkBand = Color3.fromRGB(45, 45, 52)
		handle.Size = Vector3.new(0.42, 2.5, 0.42)
		handle.Color = paperColor
		handle.Material = Enum.Material.SmoothPlastic
		table.insert(created, makeSubPart("PrintBand1", Vector3.new(0.45, 0.25, 0.45), baseCF * CFrame.new(0, 0.55, 0), inkBand, Enum.Material.SmoothPlastic, parent, anchored))
		table.insert(created, makeSubPart("PrintBand2", Vector3.new(0.45, 0.18, 0.45), baseCF * CFrame.new(0, -0.25, 0), Color3.fromRGB(200, 45, 45), Enum.Material.SmoothPlastic, parent, anchored))

	elseif toolId == "walis_tingting" then
		local stickColor = Color3.fromRGB(145, 102, 54)
		handle.Size = Vector3.new(0.38, 1.5, 0.38)
		handle.Color = stickColor
		handle.Material = Enum.Material.Wood
		table.insert(created, makeSubPart("RedTie", Vector3.new(0.44, 0.25, 0.44), baseCF * CFrame.new(0, 0.45, 0), Color3.fromRGB(215, 40, 40), Enum.Material.Fabric, parent, anchored))
		table.insert(created, makeSubPart("TingtingFan", Vector3.new(1.1, 2.2, 0.28), baseCF * CFrame.new(0, 1.75, 0), Color3.fromRGB(175, 130, 72), Enum.Material.WoodPlanks, parent, anchored))

	elseif toolId == "walis_tambo" then
		local woodGrip = Color3.fromRGB(160, 110, 62)
		handle.Size = Vector3.new(0.32, 1.8, 0.32)
		handle.Color = woodGrip
		handle.Material = Enum.Material.Wood
		table.insert(created, makeSubPart("WeaveNeck", Vector3.new(0.65, 0.55, 0.38), baseCF * CFrame.new(0, 1.0, 0), Color3.fromRGB(220, 45, 45), Enum.Material.Fabric, parent, anchored))
		table.insert(created, makeSubPart("WeaveBand", Vector3.new(0.95, 0.35, 0.38), baseCF * CFrame.new(0, 1.35, 0), Color3.fromRGB(250, 200, 40), Enum.Material.Fabric, parent, anchored))
		table.insert(created, makeSubPart("TamboFan", Vector3.new(2.1, 1.9, 0.32), baseCF * CFrame.new(0, 2.35, 0), Color3.fromRGB(225, 195, 115), Enum.Material.Grass, parent, anchored))
	end

	if not anchored then
		for _, part in created do
			weldParts(handle, part)
		end
	end

	return handle
end

return PamaloConfig
