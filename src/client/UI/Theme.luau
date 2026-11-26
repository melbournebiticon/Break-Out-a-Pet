--!strict
-- Theme.luau (CLIENT)
-- Shared mobile-first UI colors, fonts, corners, strokes, and press-tween button builders.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundController = require(script.Parent.Parent:WaitForChild("SoundController"))

local Theme = {
	BgDark = Color3.fromRGB(22, 25, 36),
	BgCard = Color3.fromRGB(34, 40, 56),
	BgHeader = Color3.fromRGB(45, 54, 78),
	AccentGreen = Color3.fromRGB(70, 210, 110),
	AccentBlue = Color3.fromRGB(65, 150, 255),
	AccentPurple = Color3.fromRGB(165, 85, 255),
	AccentGold = Color3.fromRGB(255, 195, 45),
	AccentRed = Color3.fromRGB(235, 75, 75),
	TextPrimary = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(175, 185, 205),

	FontTitle = Enum.Font.FredokaOne,
	FontBody = Enum.Font.GothamBold,
}

function Theme.AddCorner(parent: GuiObject, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function Theme.AddStroke(parent: GuiObject, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Theme.MakeFrame(name: string, size: UDim2, position: UDim2, color: Color3, radius: number, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	Theme.AddCorner(frame, radius)
	frame.Parent = parent
	return frame
end

function Theme.MakeLabel(name: string, text: string, size: UDim2, position: UDim2, font: Enum.Font, color: Color3, parent: Instance): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = size
	lbl.Position = position
	lbl.BackgroundTransparency = 1
	lbl.Font = font
	lbl.TextColor3 = color
	lbl.TextScaled = true
	lbl.TextStrokeTransparency = 0.35
	lbl.Text = text
	lbl.Parent = parent
	return lbl
end

function Theme.MakeButton(name: string, text: string, size: UDim2, position: UDim2, bgColor: Color3, parent: Instance, onClick: (() -> ())?): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = size
	btn.Position = position
	btn.BackgroundColor3 = bgColor
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Font = Theme.FontTitle
	btn.TextColor3 = Theme.TextPrimary
	btn.TextScaled = true
	btn.TextStrokeTransparency = 0.25
	btn.Text = text
	Theme.AddCorner(btn, 10)
	btn.Parent = parent

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 24
	constraint.MinTextSize = 11
	constraint.Parent = btn

	local baseSize = size
	btn.Activated:Connect(function()
		SoundController.Play("UiClick")
		local shrink = UDim2.new(baseSize.X.Scale * 0.95, math.floor(baseSize.X.Offset * 0.95), baseSize.Y.Scale * 0.95, math.floor(baseSize.Y.Offset * 0.95))
		TweenService:Create(btn, TweenInfo.new(0.06), { Size = shrink }):Play()
		task.delay(0.06, function()
			if btn.Parent then
				TweenService:Create(btn, TweenInfo.new(0.08), { Size = baseSize }):Play()
			end
		end)
		if onClick then
			onClick()
		end
	end)

	return btn
end

function Theme.IsCompactScreen(): boolean
	local cam = workspace.CurrentCamera
	if cam then
		local vp = cam.ViewportSize
		if vp.Y > 0 and (vp.Y < 540 or vp.X < 900) then
			return true
		end
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Theme.BindResponsiveScale(target: GuiObject, compactScale: number, onUpdate: ((isCompact: boolean) -> ())?): UIScale
	local uiScale = target:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = target
	end

	local function refresh()
		local compact = Theme.IsCompactScreen()
		local cam = workspace.CurrentCamera
		local vpY = if cam and cam.ViewportSize.Y > 0 then cam.ViewportSize.Y else 720
		if compact then
			-- Scale proportionally for smaller mobile viewports (e.g. 340px..500px height)
			local dynamic = math.clamp((vpY / 480) * compactScale, compactScale * 0.85, compactScale)
			uiScale.Scale = dynamic
		else
			uiScale.Scale = 1.0
		end
		if onUpdate then
			onUpdate(compact)
		end
	end

	refresh()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local newCam = workspace.CurrentCamera
		if newCam then
			newCam:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
			refresh()
		end
	end)

	return uiScale
end

function Theme.MakeModalShell(screenGui: ScreenGui, titleText: string, onClose: () -> ()): (Frame, Frame)
	local modal = Theme.MakeFrame(
		titleText .. "Modal",
		UDim2.fromScale(0.72, 0.75),
		UDim2.fromScale(0.5, 0.45),
		Theme.BgDark,
		14,
		screenGui
	)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Visible = false
	modal.ZIndex = 20
	Theme.AddStroke(modal, Theme.BgHeader, 3)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(380, 235)
	sizeConstraint.MaxSize = Vector2.new(660, 440)
	sizeConstraint.Parent = modal

	local header = Theme.MakeFrame("Header", UDim2.new(1, 0, 0, 38), UDim2.fromScale(0, 0), Theme.BgHeader, 12, modal)
	local title = Theme.MakeLabel("Title", titleText, UDim2.new(0.82, 0, 0.82, 0), UDim2.fromScale(0.03, 0.09), Theme.FontTitle, Theme.TextPrimary, header)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local closeBtn = Theme.MakeButton("Close", "X", UDim2.fromOffset(34, 28), UDim2.new(1, -40, 0, 5), Theme.AccentRed, header, onClose)
	closeBtn.AnchorPoint = Vector2.new(0, 0)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -16, 1, -46)
	content.Position = UDim2.fromOffset(8, 42)
	content.BackgroundTransparency = 1
	content.Parent = modal

	return modal, content
end

return Theme
