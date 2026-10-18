--!strict
-- Écran RECHERCHE : choix du mode (2v2 à 5v5), Normal ou Classé.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Court = require(ReplicatedStorage.Shared.Court)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Kit = require(script.Parent.Parent.UI.Kit)
local ScreenFrame = require(script.Parent.Parent.UI.ScreenFrame)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local SearchScreen = {}

local MODE_COLORS = { ["2v2"] = C.Green, ["3v3"] = C.Blue, ["4v4"] = C.Purple, ["5v5"] = C.Red }
local SIZE_LABEL =
	{ ["2v2"] = "PETIT TERRAIN", ["3v3"] = "TERRAIN MOYEN", ["4v4"] = "GRAND TERRAIN", ["5v5"] = "TERRAIN OFFICIEL" }

export type ModePicker = {
	Selected: () -> string,
	Refresh: () -> (),
}

-- Rangée de cartes de mode, réutilisée par l'écran Entraînement.
function SearchScreen.modePicker(parent: Instance, onChange: (string) -> ()): ModePicker
	local row = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 250),
		ZIndex = 22,
		Parent = parent,
	})
	Kit.list(row, 22, true)
	local selected = "3v3"
	local cards: { [string]: { Face: Frame, Container: Frame } } = {}
	local function refresh()
		for mode, card in cards do
			local stroke = card.Face:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if mode == selected then C.Yellow else C.Ink
				stroke.Thickness = if mode == selected then 7 else 4
			end
			card.Container.Rotation = if mode == selected then -2 else 0
		end
	end
	for index, mode in Config.ModeOrder do
		local info = Config.Modes[mode]
		local dims = Court.get(mode)
		local color = MODE_COLORS[mode] or C.Blue
		local face, container = Kit.panel({
			Size = UDim2.fromOffset(240, 236),
			Color = color,
			Order = index,
			ZIndex = 23,
			Clip = true,
			Parent = row,
		})
		Kit.sunburst(face, color, Theme.shade(color, 0.12), 10, false).ZIndex = 23
		Kit.text({
			Text = info.Label,
			Color = C.Paper,
			Stroke = C.Ink,
			StrokeThickness = 4,
			Size = UDim2.new(1, -20, 0, 80),
			Position = UDim2.fromOffset(10, 22),
			ZIndex = 25,
			Parent = face,
		})
		local strip = Kit.new("Frame", {
			BackgroundColor3 = C.Ink,
			Size = UDim2.new(1, 0, 0, 34),
			Position = UDim2.fromOffset(0, 116),
			ZIndex = 25,
			Parent = face,
		})
		Kit.text({
			Text = SIZE_LABEL[mode] or "",
			Color = C.Yellow,
			Size = UDim2.new(1, -12, 1, -8),
			Position = UDim2.fromOffset(6, 4),
			ZIndex = 26,
			Parent = strip,
		})
		Kit.text({
			Text = `{dims.Length} × {dims.Width} studs\n{if info.RankedAllowed
				then "Classé disponible"
				else "Normal uniquement"}`,
			Font = Theme.Fonts.Body,
			Color = C.Paper,
			Stroke = C.Ink,
			StrokeThickness = 2,
			Size = UDim2.new(1, -20, 0, 60),
			Position = UDim2.fromOffset(10, 160),
			ZIndex = 25,
			Parent = face,
		})
		cards[mode] = { Face = face, Container = container }
		local hit = Kit.new(
			"TextButton",
			{ BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = container }
		)
		hit.Activated:Connect(function()
			selected = mode
			Kit.pop(container, 0.9)
			refresh()
			onChange(mode)
		end)
	end
	refresh()
	return {
		Selected = function()
			return selected
		end,
		Refresh = refresh,
	}
end

function SearchScreen.create(parent: Instance, close: () -> ()): ScreenFrame.Screen
	local screen = ScreenFrame.new(parent, "RECHERCHE", "試合を探す", C.Yellow, close)
	local content = screen.Content
	local ranked = false

	local picker: ModePicker
	local rankedButton: Kit.Button
	local normalButton: Kit.Button
	local launch: Kit.Button

	local info = Kit.text({
		Text = "",
		Font = Theme.Fonts.Body,
		Size = UDim2.new(1, -20, 0, 50),
		Position = UDim2.fromOffset(10, 300),
		AlignX = Enum.TextXAlignment.Left,
		MaxSize = 22,
		ZIndex = 22,
		Parent = content,
	})

	local rankCard, _ = Kit.panel({
		Size = UDim2.fromOffset(330, 150),
		Position = UDim2.new(1, -340, 0, 290),
		Color = C.Night,
		ZIndex = 22,
		Parent = content,
	})
	local rankTitle = Kit.text({
		Text = "",
		Color = C.Yellow,
		Stroke = C.Ink,
		Size = UDim2.new(1, -20, 0, 50),
		Position = UDim2.fromOffset(10, 12),
		ZIndex = 23,
		Parent = rankCard,
	})
	local rankSub = Kit.text({
		Text = "",
		Font = Theme.Fonts.Body,
		Color = C.Paper,
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 66),
		ZIndex = 23,
		Parent = rankCard,
	})
	local _, setRankBar = Kit.progress(
		rankCard,
		{ Size = UDim2.new(1, -40, 0, 18), Position = UDim2.fromOffset(20, 108), Color = C.Yellow, ZIndex = 23 }
	)

	local function refresh()
		local profile = State.Profile
		local mode = if picker then picker.Selected() else "3v3"
		local modeInfo = Config.Modes[mode]
		local level = if profile then profile.Level else 1
		local rankedUnlocked = level >= Config.RankedUnlockLevel
		local rankedPossible = rankedUnlocked and modeInfo.RankedAllowed
		if not rankedPossible then
			ranked = false
		end
		if rankedButton then
			rankedButton.SetEnabled(rankedPossible)
			rankedButton.SetColor(if ranked then C.Red else C.PaperDark)
			rankedButton.SetText(if rankedUnlocked then "CLASSÉ" else `CLASSÉ 🔒 NIV. {Config.RankedUnlockLevel}`)
			normalButton.SetColor(if ranked then C.PaperDark else C.Yellow)
		end
		local rp = if profile then profile.RP else 0
		local rank, index = Progression.getRank(rp)
		local nextRank = Progression.Ranks[index + 1]
		rankTitle.Text = `{string.upper(rank.Name)} {Progression.getDivision(rp)}`
		rankTitle.TextColor3 = rank.Color
		rankSub.Text = if nextRank
			then `{rp} RP  ·  prochain : {nextRank.Name} ({nextRank.MinRP})`
			else `{rp} RP  ·  rang maximum`
		setRankBar(if nextRank then (rp - rank.MinRP) / (nextRank.MinRP - rank.MinRP) else 1)

		local party = State.Party
		local isLeader = party == nil or party.LeaderId == game:GetService("Players").LocalPlayer.UserId
		local partySize = if party then #party.Members else 1
		local lines = {}
		table.insert(
			lines,
			`{modeInfo.Label} · mi-temps de {math.floor(modeInfo.HalfDuration / 60)} min {modeInfo.HalfDuration % 60} s`
		)
		if partySize > modeInfo.TeamSize then
			table.insert(lines, "Ton groupe est trop grand pour ce mode.")
		elseif partySize > 1 then
			table.insert(lines, `Groupe de {partySize} : vous serez dans la même équipe.`)
		end
		if not modeInfo.RankedAllowed then
			table.insert(lines, "Le classé se joue à partir du 3v3.")
		end
		info.Text = table.concat(lines, "\n")
		if launch then
			launch.SetEnabled(isLeader and partySize <= modeInfo.TeamSize and State.Queue.State == "Idle")
			launch.SetText(
				if not isLeader
					then "LE CHEF LANCE"
					elseif State.Queue.State ~= "Idle" then "EN RECHERCHE…"
					else "RECHERCHER"
			)
		end
	end

	picker = SearchScreen.modePicker(content, function()
		refresh()
	end)

	local toggles = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(560, 60),
		Position = UDim2.fromOffset(0, 380),
		ZIndex = 22,
		Parent = content,
	})
	Kit.list(toggles, 18, true)
	normalButton = Kit.button({
		Text = "NORMAL",
		Color = C.Yellow,
		Size = UDim2.fromOffset(220, 56),
		Order = 1,
		ZIndex = 23,
		Parent = toggles,
		OnClick = function()
			ranked = false
			refresh()
		end,
	})
	rankedButton = Kit.button({
		Text = "CLASSÉ",
		Color = C.PaperDark,
		Size = UDim2.fromOffset(300, 56),
		Order = 2,
		ZIndex = 23,
		Parent = toggles,
		OnClick = function()
			ranked = true
			refresh()
		end,
	})

	launch = Kit.button({
		Text = "RECHERCHER",
		Color = C.Red,
		TextColor = C.Paper,
		TextStroke = C.Ink,
		Size = UDim2.fromOffset(420, 90),
		Position = UDim2.new(0.5, 0, 1, -50),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -2,
		ShadowOffset = 8,
		StrokeThickness = 5,
		ZIndex = 23,
		Parent = content,
		OnClick = function()
			local ok = State.request("QueueAction", "Search", picker.Selected(), ranked)
			if ok then
				close()
			end
		end,
	})

	State.ProfileChanged:Connect(refresh)
	State.PartyChanged:Connect(refresh)
	State.QueueChanged:Connect(refresh)
	local open = screen.Open
	screen.Open = function()
		refresh()
		open()
	end
	refresh()
	return screen
end

return SearchScreen
