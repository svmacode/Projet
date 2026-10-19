--!strict
-- Minimal, readable team kit for Phase 1: red or blue jersey, darker shorts,
-- a distinct shade for goalkeepers and a number on the back and chest.
-- Cosmetics (masks, gloves, shoes, outfits) arrive in Phase 6.

local Appearance = {}

local KITS = {
	Red = {
		Field = Color3.fromRGB(214, 38, 52),
		Keeper = Color3.fromRGB(255, 150, 30),
		Shorts = Color3.fromRGB(28, 22, 30),
	},
	Blue = {
		Field = Color3.fromRGB(32, 98, 230),
		Keeper = Color3.fromRGB(30, 205, 190),
		Shorts = Color3.fromRGB(240, 240, 245),
	},
}

local NUMBER_FONT = Font.fromEnum(Enum.Font.GothamBlack)

local function numberGui(torso: BasePart, face: Enum.NormalId, number: number, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "HL_Number_" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 1
	gui.Parent = torso
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = NUMBER_FONT
	label.Text = tostring(number)
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.18, 0)
	padding.PaddingBottom = UDim.new(0.18, 0)
	padding.Parent = label
end

-- Applies the kit. Clothing templates are removed so the body colours read
-- clearly; the player's avatar is restored when the character reloads.
function Appearance.apply(model: Model, team: string, role: string, number: number)
	local kit = KITS[team] or KITS.Red
	local jersey = if role == "Goalkeeper" then kit.Keeper else kit.Field
	for _, child in model:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end
	local bodyColors: BodyColors
	local existing = model:FindFirstChildOfClass("BodyColors")
	if existing then
		bodyColors = existing
	else
		bodyColors = Instance.new("BodyColors")
		bodyColors.Parent = model
	end
	bodyColors.TorsoColor3 = jersey
	bodyColors.LeftArmColor3 = jersey
	bodyColors.RightArmColor3 = jersey
	bodyColors.LeftLegColor3 = kit.Shorts
	bodyColors.RightLegColor3 = kit.Shorts

	local torso = model:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		for _, child in torso:GetChildren() do
			if child:IsA("SurfaceGui") and string.sub(child.Name, 1, 10) == "HL_Number_" then
				child:Destroy()
			end
		end
		local ink = if (jersey.R * 0.299 + jersey.G * 0.587 + jersey.B * 0.114) > 0.6
			then Color3.fromRGB(20, 20, 28)
			else Color3.fromRGB(255, 255, 255)
		numberGui(torso, Enum.NormalId.Back, number, ink)
		numberGui(torso, Enum.NormalId.Front, number, ink)
	end
end

function Appearance.teamColor(team: string, role: string?): Color3
	local kit = KITS[team] or KITS.Red
	return if role == "Goalkeeper" then kit.Keeper else kit.Field
end

return Appearance
