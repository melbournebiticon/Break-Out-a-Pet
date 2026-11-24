-- BlockoutFusion.luau
-- NOT part of Rojo. Paste into the Studio command bar in Edit mode and press Ctrl+Enter.

local CollectionService = game:GetService("CollectionService")

local function build()
	local plots = workspace:FindFirstChild("BasePlots")
	if not plots then
		warn("Workspace.BasePlots not found.")
		return
	end

	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") then
			if plot:FindFirstChild("FusionMachine") then
				warn(`{plot.Name} already has FusionMachine; skipping.`)
			else
				local floor = plot:FindFirstChild("Floor")
				if floor and floor:IsA("BasePart") then
					local fm = Instance.new("Part")
					fm.Name = "FusionMachine"
					fm.Size = Vector3.new(5, 5, 5)
					fm.Position = floor.Position + Vector3.new(14, 3, 14)
					fm.Color = Color3.fromRGB(165, 75, 255)
					fm.Material = Enum.Material.Neon
					fm.Anchored = true
					fm.Parent = plot
					CollectionService:AddTag(fm, "FusionMachine")
				end
			end
		end
	end

	print("Fusion machines done! Now press Ctrl+S to save the place.")
end

build()
