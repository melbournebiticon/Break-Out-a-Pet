-- BlockoutSlots.luau
-- NOT part of Rojo. Paste into the Studio command bar in Edit mode and press Ctrl+Enter.

local function makeSlot(name, size, position, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = Color3.fromRGB(190, 190, 190)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function build()
	local plots = workspace:FindFirstChild("BasePlots")
	if not plots then
		warn("Workspace.BasePlots not found. Run studio/Blockout.luau first.")
		return
	end

	local xOffsets = { -12, 0, 12 }
	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") then
			if plot:FindFirstChild("Slot1") then
				warn(`{plot.Name} already has Slot1; skipping.`)
			else
				local floor = plot:FindFirstChild("Floor")
				if floor and floor:IsA("BasePart") then
					for row = 1, 2 do
						local zOff = if row == 1 then -1.5 else 4.5
						for col = 1, 3 do
							local idx = (row - 1) * 3 + col
							makeSlot(`Slot{idx}`, Vector3.new(5, 0.4, 5), floor.Position + Vector3.new(xOffsets[col], 0.7, zOff), plot)
						end
					end
				end
			end
		end
	end

	print("Slots done! Now press Ctrl+S to save the place.")
end

build()
