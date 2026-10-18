--!strict
-- Avant le coup d'envoi : choix du poste (un seul gardien par équipe) puis
-- d'un archétype de ce poste. Les deux équipes sont affichées sur les côtés.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Cards = require(script.Parent.Parent.UI.Cards)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local LocalPlayer = Players.LocalPlayer

local MatchSetup = {}

local POSTES = { Gardien = "Gardien", Defenseur = "Défenseur", Attaquant = "Attaquant" }
local POSTE_ORDER = { "Gardien", "Defenseur", "Attaquant" }
local POSTE_COLORS = { Gardien = C.Sky, Defenseur = C.Success, Attaquant = C.Accent }
local POSTE_HINTS = {
	Gardien = "Un seul par équipe · arrêts et relances",
	Defenseur = "Contres, interceptions, contacts",
	Attaquant = "Vitesse, feintes et tirs",
}

type PosteCard = { Button: TextButton, Face: Frame, Stroke: UIStroke, Status: TextLabel }

local gui: ScreenGui
local title: TextLabel
local timer: TextLabel
local columns: { [string]: Frame } = {}
local posteCards: { [string]: PosteCard } = {}
local posteTaken: { [string]: boolean } = {}
local currentPoste: string? = nil
local cardRow: ScrollingFrame
local powers: Frame
local ready: Kit.Button
local hint: TextLabel

local function mine(setup: any): any
	for _, entry in setup.Participants do
		if entry.UserId == LocalPlayer.UserId then
			return entry
		end
	end
	return nil
end

local function paintPostes()
	for id, card in posteCards do
		local color = POSTE_COLORS[id]
		local on = currentPoste == id
		local taken = posteTaken[id] == true
		card.Face.BackgroundColor3 = if on then color elseif taken then C.Surface3 else C.White
		card.Stroke.Color = if on then Theme.darken(color, 0.2) else C.Border
		card.Stroke.Thickness = if on then 3 else 2
		for _, object in card.Face:GetDescendants() do
			if object:IsA("TextLabel") and object.Name ~= "Statut" then
				object.TextColor3 = if on then C.White elseif taken then C.TextFaint else C.Text
			end
		end
		card.Status.Text = if taken and not on then "Déjà pris" elseif on then "Choisi" else ""
		card.Status.TextColor3 = if on then C.White else C.Danger
	end
end

local function renderTeams(setup: any)
	for team, column in columns do
		Kit.clear(column)
		local order = 0
		for _, entry in setup.Participants do
			if entry.Team == team then
				order += 1
				local isMe = entry.UserId == LocalPlayer.UserId
				local posteColor = if entry.Poste then POSTE_COLORS[entry.Poste] else C.TextFaint
				local row = Kit.surface({
					Color = if isMe then Color3.fromRGB(255, 244, 230) else C.White,
					Transparency = 0.03,
					BorderColor = if isMe then C.Accent else C.White,
					BorderThickness = 2,
					Radius = 16,
					Size = UDim2.new(1, 0, 0, 58),
					Order = order,
					ZIndex = 5,
					Parent = column,
				})
				local bar = Kit.new("Frame", {
					BackgroundColor3 = posteColor,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(6, 38),
					Position = UDim2.fromOffset(10, 10),
					ZIndex = 6,
					Parent = row,
				})
				Kit.round(bar)
				Kit.label({
					Text = entry.Name,
					Font = Theme.Fonts.Display,
					TextSize = Theme.Text.Small + 1,
					Color = C.Text,
					Size = UDim2.new(1, -70, 0, 20),
					Position = UDim2.fromOffset(26, 9),
					ZIndex = 6,
					Parent = row,
				})
				local archetype = Archetypes.get(entry.Archetype)
				Kit.label({
					Text = if entry.Poste
						then `{POSTES[entry.Poste]}{if archetype then " · " .. archetype.Name else ""}`
						else "Choisit son poste…",
					Font = Theme.Fonts.Bold,
					TextSize = Theme.Text.Tiny + 1,
					Color = if entry.Poste then Theme.darken(posteColor, 0.15) else C.TextFaint,
					Size = UDim2.new(1, -70, 0, 18),
					Position = UDim2.fromOffset(26, 30),
					ZIndex = 6,
					Parent = row,
				})
				local status = Kit.new("Frame", {
					BackgroundColor3 = if entry.Ready then C.Success else C.Surface3,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(26, 26),
					Position = UDim2.new(1, -14, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					ZIndex = 6,
					Parent = row,
				})
				Kit.round(status)
				if entry.Ready then
					Kit.label({
						Text = "✓",
						Font = Theme.Fonts.Bold,
						TextSize = 16,
						Color = C.White,
						AlignX = Enum.TextXAlignment.Center,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 7,
						Parent = status,
					})
				end
			end
		end
	end
end

local function render(setup: any)
	if not setup or setup.Closed then
		gui.Enabled = false
		return
	end
	local me = mine(setup)
	if not me then
		return
	end
	gui.Enabled = true
	local modeInfo = Config.Modes[setup.Mode]
	title.Text = `{modeInfo.Label}{if setup.Ranked
		then " · Classé"
		elseif setup.Training then " · Entraînement"
		else ""}  ·  Équipe {string.lower(Theme.Team[me.Team].Name)}`
	renderTeams(setup)

	local keeperTaken = false
	for _, entry in setup.Participants do
		if entry.Team == me.Team and entry.Poste == "Gardien" and entry.UserId ~= LocalPlayer.UserId then
			keeperTaken = true
		end
	end
	posteTaken.Gardien = keeperTaken
	currentPoste = me.Poste
	paintPostes()

	Kit.clear(cardRow)
	if me.Poste then
		local profile = State.Profile
		local list = Archetypes.byPoste(me.Poste)
		table.sort(list, function(a, b)
			return (Rarities.get(a.Rarity) :: any).Rank < (Rarities.get(b.Rarity) :: any).Rank
		end)
		for index, archetype in list do
			local owned = profile ~= nil and profile.Archetypes[archetype.Id] == true
			Cards.archetype(cardRow, archetype, {
				Size = UDim2.fromOffset(150, 204),
				Owned = owned,
				Selected = me.Archetype == archetype.Id,
				Order = index,
				ZIndex = 5,
				OnClick = if owned
					then function()
						State.request("MatchSetupAction", "Archetype", archetype.Id)
					end
					else nil,
			})
		end
		hint.Visible = false
	else
		hint.Visible = true
	end

	Kit.clear(powers)
	local archetype = Archetypes.get(me.Archetype)
	if archetype then
		for _, power in archetype.Powers do
			Cards.power(powers, power, { Size = UDim2.new(1 / 3, -8, 1, 0), Order = power.Slot, ZIndex = 5 })
		end
	end
	ready.SetEnabled(me.Poste ~= nil and not me.Ready)
	ready.SetText(if me.Ready then "PRÊT · EN ATTENTE DES AUTRES" else "JE SUIS PRÊT")
end

function MatchSetup.start()
	local root
	gui, root = Kit.screen("ChoixDuPoste", 40, LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false
	Kit.backdrop(root, C.Sky, 1)
	local page =
		Kit.box({ Size = UDim2.new(1, -80, 1, -64), Position = UDim2.fromOffset(40, 32), ZIndex = 2, Parent = root })

	-- En-tête.
	local heading = Kit.title({
		Text = "CHOIX DU POSTE",
		TextSize = 44,
		StrokeColor = C.SkyDark,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -600, 0, 56),
		Position = UDim2.fromOffset(300, 0),
		ZIndex = 3,
		Parent = page,
	})
	Kit.pop(heading.Instance, 0.9)
	title = Kit.label({
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Body,
		Color = C.White,
		Stroke = 1.5,
		StrokeColor = C.SkyDark,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, -600, 0, 22),
		Position = UDim2.fromOffset(300, 56),
		ZIndex = 3,
		Parent = page,
	})
	local clock = Kit.new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(72, 72),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 3,
		Parent = page,
	})
	Kit.round(clock)
	Kit.border(clock, C.SkyLight, 4)
	timer = Kit.label({
		Text = "",
		Font = Theme.Fonts.Number,
		TextSize = 30,
		Color = C.Text,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = clock,
	})

	-- Colonnes d'équipe.
	for index, team in { "Rouge", "Bleu" } do
		local info = Theme.Team[team]
		local left = index == 1
		local panel = Kit.box({
			Size = UDim2.new(0, 280, 1, -100),
			Position = if left then UDim2.fromOffset(0, 100) else UDim2.new(1, 0, 0, 100),
			AnchorPoint = if left then Vector2.zero else Vector2.new(1, 0),
			ZIndex = 3,
			Parent = page,
		})
		local header = Kit.new("Frame", {
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 46),
			ZIndex = 4,
			Parent = panel,
		})
		Kit.corner(header, 23)
		Kit.gradient(header, info.Light, info.Main, 90)
		Kit.border(header, C.White, 3)
		Kit.label({
			Text = `ÉQUIPE {info.Name}`,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H3,
			Color = C.White,
			Stroke = 1.5,
			StrokeColor = info.Dark,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = header,
		})
		local column = Kit.box({
			Size = UDim2.new(1, 0, 1, -60),
			Position = UDim2.fromOffset(0, 60),
			ZIndex = 4,
			Parent = panel,
		})
		Kit.list(column, 8)
		columns[team] = column
	end

	-- Centre : postes, archétypes, pouvoirs, prêt.
	local center = Kit.surface({
		Transparency = 0.03,
		BorderColor = C.White,
		BorderThickness = 3,
		Radius = 24,
		Size = UDim2.new(1, -620, 1, -100),
		Position = UDim2.fromOffset(310, 100),
		ZIndex = 3,
		Parent = page,
	})
	local inner = Kit.box({
		Size = UDim2.new(1, -40, 1, -36),
		Position = UDim2.fromOffset(20, 18),
		ZIndex = 4,
		Parent = center,
	})
	local posteRow = Kit.box({ Size = UDim2.new(1, 0, 0, 96), ZIndex = 4, Parent = inner })
	Kit.list(posteRow, 12, true, Enum.HorizontalAlignment.Center)
	for index, id in POSTE_ORDER do
		local color = POSTE_COLORS[id]
		local button = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.new(1 / 3, -8, 1, 0),
			LayoutOrder = index,
			ZIndex = 4,
			Parent = posteRow,
		})
		local face = Kit.new("Frame", {
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Parent = button,
		})
		Kit.corner(face, 18)
		local stroke = Kit.border(face, C.Border, 2)
		Kit.label({
			Text = string.upper(POSTES[id]),
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H3,
			Color = C.Text,
			Size = UDim2.new(1, -28, 0, 26),
			Position = UDim2.fromOffset(16, 16),
			ZIndex = 5,
			Parent = face,
		})
		Kit.label({
			Text = POSTE_HINTS[id],
			Font = Theme.Fonts.Semibold,
			TextSize = Theme.Text.Tiny + 1,
			Color = C.Text,
			Wrap = true,
			AlignY = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -28, 0, 36),
			Position = UDim2.fromOffset(16, 46),
			ZIndex = 5,
			Parent = face,
		})
		local status = Kit.label({
			Name = "Statut",
			Text = "",
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.Tiny,
			Color = C.Danger,
			AlignX = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -28, 0, 16),
			Position = UDim2.fromOffset(12, 20),
			ZIndex = 5,
			Parent = face,
		})
		local dot = Kit.new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(10, 10),
			Position = UDim2.new(1, -24, 1, -24),
			ZIndex = 5,
			Parent = face,
		})
		Kit.round(dot)
		Kit.border(dot, C.White, 2)
		button.Activated:Connect(function()
			if posteTaken[id] or currentPoste == id then
				return
			end
			Kit.pop(face, 0.92)
			Kit.playSound(Theme.Sounds.Click, 0.35)
			currentPoste = id
			paintPostes()
			State.request("MatchSetupAction", "Poste", id)
		end)
		posteCards[id] = { Button = button, Face = face, Stroke = stroke, Status = status }
	end
	paintPostes()

	Kit.label({
		Text = "ARCHÉTYPE",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 112),
		ZIndex = 4,
		Parent = inner,
	})
	cardRow = Kit.scroll({
		Horizontal = true,
		Size = UDim2.new(1, 0, 0, 222),
		Position = UDim2.fromOffset(0, 136),
		ZIndex = 4,
		Parent = inner,
	})
	Kit.list(cardRow, 12, true)
	Kit.padding(cardRow, 4, 6)
	hint = Kit.label({
		Text = "Choisis d'abord ton poste.",
		Font = Theme.Fonts.Semibold,
		Color = C.TextMuted,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 222),
		Position = UDim2.fromOffset(0, 136),
		ZIndex = 4,
		Parent = inner,
	})
	powers = Kit.box({
		Size = UDim2.new(1, 0, 0, 116),
		Position = UDim2.fromOffset(0, 370),
		ZIndex = 4,
		Parent = inner,
	})
	Kit.list(powers, 12, true)
	ready = Kit.button({
		Text = "JE SUIS PRÊT",
		Variant = "Primary",
		TextSize = Theme.Text.H3,
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.new(0, 0, 1, -60),
		ZIndex = 5,
		Parent = inner,
		OnClick = function()
			State.request("MatchSetupAction", "Ready")
		end,
	})

	State.SetupChanged:Connect(render)
	State.MatchEvent:Connect(function(kind)
		if kind == "Leave" then
			gui.Enabled = false
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local setup = State.Setup
			if gui.Enabled and setup and not setup.Closed then
				local remaining = math.max(0, setup.Deadline - Workspace:GetServerTimeNow())
				timer.Text = `{math.ceil(remaining)}`
				timer.TextColor3 = if remaining < 6 then C.Danger else C.Text
			end
		end
	end)
end

return MatchSetup
