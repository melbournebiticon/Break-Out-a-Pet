-- BlockoutLobby.luau
-- NOT part of Rojo. Paste into the Studio command bar in Edit mode and press Ctrl+Enter.

local CollectionService = game:GetService("CollectionService")

local function build()
	if workspace:FindFirstChild("Lobby") then
		warn("Workspace.Lobby already exists.")
		return
	end

	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	lobby.Parent = workspace

	local board = Instance.new("Part")
	board.Name = "LeaderboardBoard"
	board.Size = Vector3.new(16, 11, 1)
	board.Position = Vector3.new(0, 6.5, -15)
	board.Color = Color3.fromRGB(25, 30, 45)
	board.Anchored = true
	board.Parent = lobby
	CollectionService:AddTag(board, "LeaderboardBoard")

	print("Lobby leaderboard board done! Now press Ctrl+S to save the place.")
end

build()
