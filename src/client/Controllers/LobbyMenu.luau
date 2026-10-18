--!strict
-- Interface du lobby, style « anime sport » : chaque onglet a sa couleur.
--   Barre du haut : JOUER · CASIER · BOUTIQUE · CLAN, Tutoriel, Nouveautés,
--                   Hand Coins, profil.
--   Accueil (JOUER) : le quartier 3D reste visible ; panneau de lancement en
--                   bas à gauche, groupe en bas à droite.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Court = require(ReplicatedStorage.Shared.Court)
local PatchNotes = require(ReplicatedStorage.Shared.Data.PatchNotes)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Kit = require(script.Parent.Parent.UI.Kit)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local ClanScreen = require(script.Parent.Parent.Screens.ClanScreen)
local LockerScreen = require(script.Parent.Parent.Screens.LockerScreen)
local ShopScreen = require(script.Parent.Parent.Screens.ShopScreen)
local TutorialScreen = require(script.Parent.Parent.Screens.TutorialScreen)
local UpdatesScreen = require(script.Parent.Parent.Screens.UpdatesScreen)

local C = Theme.Colors
local LocalPlayer = Players.LocalPlayer

local LobbyMenu = {}

local gui: ScreenGui
local root: Frame
local pages: { [string]: any } = {}
local tabEntries: { [string]: { Label: TextLabel, Plate: Frame, Stroke: UIStroke, Color: Color3 } } = {}
local currentTab = "JOUER"
local home: Frame
local tabStripe: Frame
local updatesDot: Frame
local tutorialDot: Frame
local shopDot: Frame

local TAB_COLORS: { [string]: Color3 } = {
	JOUER = Theme.Section.Play,
	CASIER = Theme.Section.Locker,
	BOUTIQUE = Theme.Section.Shop,
	CLAN = Theme.Section.Clan,
}

local function paintTab(name: string, hover: boolean)
	local entry = tabEntries[name]
	local on = name == currentTab
	entry.Plate.BackgroundTransparency = if on then 0 elseif hover then 0.55 else 1
	entry.Stroke.Enabled = on or hover
	entry.Label.TextColor3 = if on then Theme.onColor(entry.Color) elseif hover then C.White else C.TextMuted
end

local function selectTab(name: string)
	currentTab = name
	for key in tabEntries do
		paintTab(key, false)
	end
	local entry = tabEntries[name]
	if entry then
		Kit.pop(entry.Plate, 0.8)
		Kit.tween(tabStripe, Theme.Motion.Base, { BackgroundColor3 = entry.Color })
	end
	for key, page in pages do
		if key == name then
			page.Open()
		elseif key ~= "TUTORIEL" and key ~= "NOUVEAUTÉS" then
			page.Close()
		end
	end
	home.Visible = name == "JOUER"
	State.setScreen(if name == "JOUER" then nil else name)
end

local function openModal(name: string)
	local page = pages[name]
	if page then
		page.Open()
		State.setScreen(name)
	end
end

local function closeModal(name: string)
	local page = pages[name]
	if page then
		page.Close()
	end
	State.setScreen(if currentTab == "JOUER" then nil else currentTab)
end

-- Pastille rouge « nouveau » cerclée d'encre.
local function dot(parent: Instance): Frame
	local badge = Kit.new("Frame", {
		BackgroundColor3 = C.Danger,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(1, 4, 0, -4),
		AnchorPoint = Vector2.new(1, 0),
		Visible = false,
		ZIndex = 26,
		Parent = parent,
	})
	Kit.corner(badge, 7)
	Kit.border(badge, C.Ink, 2)
	return badge
end

-- Barre du haut ------------------------------------------------------------------------------

local function buildTopBar()
	local bar = Kit.new("Frame", {
		Name = "Barre",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 72),
		ZIndex = 20,
		Parent = root,
	})
	Kit.gradient(bar, C.Ink, C.BackgroundTop, 0)
	Kit.speedLines({ Parent = bar, Color = C.White, Count = 8, Transparency = 0.92, ZIndex = 20 })
	-- Liseré qui prend la couleur de l'onglet actif.
	tabStripe = Kit.new("Frame", {
		BackgroundColor3 = Theme.Section.Play,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.new(0, 0, 1, 0),
		ZIndex = 21,
		Parent = bar,
	})
	Kit.new("Frame", {
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 3),
		Position = UDim2.new(0, 0, 1, 4),
		ZIndex = 21,
		Parent = bar,
	})

	-- Logo en lettrage BD.
	local logo = Kit.box({
		Size = UDim2.fromOffset(280, 72),
		Position = UDim2.fromOffset(36, 0),
		Rotation = -4,
		ZIndex = 21,
		Parent = bar,
	})
	Kit.label({
		Text = `HANDBALL <font color="#{C.Accent:ToHex()}">LEGENDS</font>`,
		Rich = true,
		Font = Theme.Fonts.Hero,
		TextSize = 34,
		Stroke = 2.5,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 22,
		Parent = logo,
	})

	local tabs =
		Kit.box({ Size = UDim2.fromOffset(640, 72), Position = UDim2.fromOffset(320, 0), ZIndex = 21, Parent = bar })
	Kit.list(tabs, 10, true, nil, Enum.VerticalAlignment.Center)
	for index, name in { "JOUER", "CASIER", "BOUTIQUE", "CLAN" } do
		local color = TAB_COLORS[name]
		local button = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromOffset(0, 46),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = index,
			ZIndex = 21,
			Parent = tabs,
		})
		local plate = Kit.new("Frame", {
			BackgroundColor3 = color,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Rotation = Theme.Tilt - 2,
			ZIndex = 21,
			Parent = button,
		})
		local plateStroke = Kit.border(plate, C.Ink, 3)
		plateStroke.Enabled = false
		Kit.shade(plate, 0.2)
		local label = Kit.label({
			Text = name,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H2 - 2,
			Color = C.TextMuted,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(0, 46),
			AutoSize = Enum.AutomaticSize.X,
			Rotation = Theme.Tilt,
			ZIndex = 22,
			Parent = button,
		})
		Kit.padding(label, 20, 0)
		tabEntries[name] = { Label = label, Plate = plate, Stroke = plateStroke, Color = color }
		if name == "BOUTIQUE" then
			shopDot = dot(button)
		end
		button.MouseEnter:Connect(function()
			paintTab(name, true)
		end)
		button.MouseLeave:Connect(function()
			paintTab(name, false)
		end)
		button.Activated:Connect(function()
			Kit.playSound(Theme.Sounds.Click, 0.35)
			selectTab(name)
		end)
	end

	local right = Kit.box({
		Size = UDim2.fromOffset(760, 72),
		Position = UDim2.new(1, -36, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 21,
		Parent = bar,
	})
	Kit.list(right, 14, true, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local tutorial = Kit.button({
		Text = "TUTORIEL",
		Variant = "Ghost",
		Color = Theme.Section.Tutorial,
		Font = Theme.Fonts.Display,
		AutoSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		Rotation = -2,
		Order = 1,
		ZIndex = 22,
		Parent = right,
		OnClick = function()
			openModal("TUTORIEL")
		end,
	})
	tutorialDot = dot(tutorial.Instance)
	local updates = Kit.button({
		Text = "NOUVEAUTÉS",
		Variant = "Ghost",
		Color = Theme.Section.Updates,
		Font = Theme.Fonts.Display,
		AutoSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		Rotation = -2,
		Order = 2,
		ZIndex = 22,
		Parent = right,
		OnClick = function()
			openModal("NOUVEAUTÉS")
		end,
	})
	updatesDot = dot(updates.Instance)

	-- Hand Coins : pastille jaune.
	local coins = Kit.new("Frame", {
		BackgroundColor3 = C.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		Rotation = -2,
		LayoutOrder = 3,
		ZIndex = 22,
		Parent = right,
	})
	Kit.corner(coins, 20)
	Kit.border(coins, C.Ink, 3)
	Kit.shade(coins, 0.2)
	Kit.padding(coins, 8, 0)
	local coinRow =
		Kit.box({ Size = UDim2.fromOffset(0, 40), AutoSize = Enum.AutomaticSize.X, ZIndex = 22, Parent = coins })
	Kit.list(coinRow, 8, true, nil, Enum.VerticalAlignment.Center)
	local coinIcon = Kit.new("Frame", {
		BackgroundColor3 = C.Orange,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(26, 26),
		LayoutOrder = 1,
		ZIndex = 23,
		Parent = coinRow,
	})
	Kit.corner(coinIcon, 13)
	Kit.border(coinIcon, C.Ink, 2)
	Kit.label({
		Text = "H",
		Font = Theme.Fonts.Hero,
		TextSize = 20,
		Color = C.White,
		Stroke = 1.5,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 24,
		Parent = coinIcon,
	})
	local coinText = Kit.label({
		Text = "0",
		Font = Theme.Fonts.Number,
		TextSize = Theme.Text.H3 + 2,
		Color = C.TextOnAccent,
		Size = UDim2.fromOffset(0, 40),
		AutoSize = Enum.AutomaticSize.X,
		Order = 2,
		ZIndex = 23,
		Parent = coinRow,
	})
	Kit.box({ Size = UDim2.fromOffset(4, 40), Order = 3, Parent = coinRow })

	-- Profil : badge de niveau en losange + pseudo.
	local profile = Kit.surface({
		Color = C.Surface2,
		Size = UDim2.fromOffset(0, 44),
		AutoSize = Enum.AutomaticSize.X,
		BorderThickness = 3,
		Order = 4,
		ZIndex = 22,
		Parent = right,
	})
	Kit.padding(profile, 8, 0)
	local profileRow =
		Kit.box({ Size = UDim2.fromOffset(0, 44), AutoSize = Enum.AutomaticSize.X, ZIndex = 22, Parent = profile })
	Kit.list(profileRow, 12, true, nil, Enum.VerticalAlignment.Center)
	local levelHolder = Kit.box({ Size = UDim2.fromOffset(34, 34), Order = 1, ZIndex = 23, Parent = profileRow })
	local diamond = Kit.new("Frame", {
		BackgroundColor3 = C.Pink,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		Rotation = 45,
		ZIndex = 23,
		Parent = levelHolder,
	})
	Kit.border(diamond, C.Ink, 2.5)
	Kit.shade(diamond, 0.2)
	local levelText = Kit.label({
		Text = "1",
		Font = Theme.Fonts.Number,
		TextSize = Theme.Text.Body,
		Color = C.White,
		Stroke = 1.5,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 24,
		Parent = levelHolder,
	})
	local nameBox = Kit.box({
		Size = UDim2.fromOffset(0, 44),
		AutoSize = Enum.AutomaticSize.X,
		Order = 2,
		ZIndex = 23,
		Parent = profileRow,
	})
	Kit.label({
		Text = LocalPlayer.DisplayName,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Body,
		Size = UDim2.fromOffset(0, 26),
		AutoSize = Enum.AutomaticSize.X,
		ZIndex = 23,
		Parent = nameBox,
	})
	local levelCaption = Kit.label({
		Text = "NIVEAU 1",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Tiny,
		Color = C.Pink,
		Size = UDim2.fromOffset(0, 14),
		AutoSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(0, 24),
		ZIndex = 23,
		Parent = nameBox,
	})
	Kit.box({ Size = UDim2.fromOffset(4, 44), Order = 3, Parent = profileRow })

	local lastCoins: number? = nil
	local function refresh(data: any)
		if not data then
			return
		end
		coinText.Text = Format.number(data.Coins)
		if lastCoins and lastCoins ~= data.Coins then
			Kit.pop(coins, 1.2)
		end
		lastCoins = data.Coins
		levelText.Text = tostring(data.Level)
		levelCaption.Text = `NIVEAU {data.Level}`
		local balls = 0
		for _, count in data.Balls do
			balls += count
		end
		shopDot.Visible = balls > 0 or data.CosmeticPacks > 0
		tutorialDot.Visible = not data.TutorialDone
		local latest = PatchNotes[1]
		updatesDot.Visible = latest ~= nil and data.SeenPatch ~= latest.Version
	end
	State.ProfileChanged:Connect(refresh)
	refresh(State.Profile)
end

-- Panneau JOUER -----------------------------------------------------------------------------------

local KINDS = {
	{ Id = "Normal", Label = "NORMAL", Caption = "Partie rapide", Color = Theme.Section.Play },
	{ Id = "Classe", Label = "CLASSÉ", Caption = "Rang et RP", Color = C.Orange },
	{ Id = "Entrainement", Label = "ENTRAÎNEMENT", Caption = "Entre amis", Color = Theme.Section.Training },
}

local function kindColor(id: string): Color3
	for _, kind in KINDS do
		if kind.Id == id then
			return kind.Color
		end
	end
	return C.Accent
end

-- Tuiles de type de partie (même interface qu'un Kit.segmented).
local function kindTiles(parent: Instance, z: number, onChange: (string) -> ()): Kit.Segmented
	local row = Kit.box({ Size = UDim2.new(1, 0, 0, 86), ZIndex = z, Parent = parent })
	Kit.list(row, 10, true)
	local current = "Normal"
	local disabled: { [string]: boolean } = {}
	local tiles: { [string]: { Face: Frame, Title: TextLabel, Caption: TextLabel, Stripe: Frame } } = {}
	local function paint()
		for _, kind in KINDS do
			local tile = tiles[kind.Id]
			local on = kind.Id == current
			local off = disabled[kind.Id] == true
			tile.Face.BackgroundColor3 = if off then C.Surface elseif on then kind.Color else C.Surface2
			tile.Face.Rotation = if on then -3 else 0
			tile.Stripe.Visible = not on and not off
			tile.Title.TextColor3 = if off then C.TextFaint elseif on then Theme.onColor(kind.Color) else kind.Color
			tile.Caption.TextColor3 = if off then C.TextFaint elseif on then Theme.onColor(kind.Color) else C.TextMuted
			tile.Caption.Text = if off then `NIVEAU {Config.RankedUnlockLevel} REQUIS` else string.upper(kind.Caption)
		end
	end
	for index, kind in KINDS do
		local button = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.new(1 / 3, -7, 1, 0),
			LayoutOrder = index,
			ZIndex = z,
			Parent = row,
		})
		local shadow = Kit.new("Frame", {
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -4, 1, -4),
			Position = UDim2.fromOffset(4, 4),
			ZIndex = z,
			Parent = button,
		})
		Kit.corner(shadow, Theme.Radius)
		local face = Kit.new("Frame", {
			BackgroundColor3 = C.Surface2,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -4, 1, -4),
			ZIndex = z,
			Parent = button,
		})
		Kit.corner(face, Theme.Radius)
		Kit.border(face, C.Ink, 3)
		Kit.shade(face, 0.22)
		local stripe = Kit.new("Frame", {
			BackgroundColor3 = kind.Color,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 5),
			ZIndex = z + 1,
			Parent = face,
		})
		Kit.corner(stripe, 3)
		local title = Kit.label({
			Text = kind.Label,
			Font = Theme.Fonts.Display,
			TextSize = if #kind.Label > 8 then Theme.Text.H3 else Theme.Text.H2,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -8, 0, 36),
			Position = UDim2.fromOffset(4, 14),
			ZIndex = z + 1,
			Parent = face,
		})
		local caption = Kit.label({
			Text = kind.Caption,
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.Tiny,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -8, 0, 16),
			Position = UDim2.fromOffset(4, 52),
			ZIndex = z + 1,
			Parent = face,
		})
		tiles[kind.Id] = { Face = face, Title = title, Caption = caption, Stripe = stripe }
		button.MouseEnter:Connect(function()
			if kind.Id ~= current and not disabled[kind.Id] then
				face.BackgroundColor3 = C.Surface3
			end
		end)
		button.MouseLeave:Connect(paint)
		button.Activated:Connect(function()
			if disabled[kind.Id] or current == kind.Id then
				return
			end
			current = kind.Id
			paint()
			Kit.pop(face, 0.85)
			Kit.playSound(Theme.Sounds.Click, 0.35)
			onChange(current)
		end)
	end
	paint()
	return {
		Instance = row,
		Select = function(id: string)
			current = id
			paint()
		end,
		SetEnabled = function(id: string, value: boolean)
			disabled[id] = not value
			paint()
		end,
		Value = function()
			return current
		end,
	}
end

local function sectionLabel(parent: Instance, text: string, y: number, z: number)
	Kit.label({
		Text = text,
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, y),
		ZIndex = z,
		Parent = parent,
	})
end

local function buildPlayPanel()
	local card = Kit.surface({
		Name = "Jouer",
		Color = C.Surface,
		Size = UDim2.fromOffset(500, 452),
		Position = UDim2.new(0, 40, 1, -40),
		AnchorPoint = Vector2.new(0, 1),
		Radius = Theme.RadiusLarge,
		BorderThickness = 3,
		Shadow = true,
		ShadowOffset = 8,
		ShadowColor = C.Accent,
		ZIndex = 5,
		Parent = home,
	})
	Kit.halftone({
		Parent = card,
		Color = C.Accent,
		Columns = 12,
		Rows = 6,
		Spacing = 14,
		Transparency = 0.82,
		Flip = true,
		Position = UDim2.new(1, -6, 0, 6),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 5,
	})
	-- Bandeau « JOUER » qui dépasse du panneau.
	local header = Kit.plate({
		Color = C.Accent,
		Size = UDim2.fromOffset(190, 52),
		Position = UDim2.fromOffset(18, -30),
		ShadowColor = C.Pink,
		ZIndex = 7,
		Parent = card,
	})
	Kit.title({
		Text = "JOUER",
		TextSize = 48,
		Color = C.TextOnAccent,
		ShadowColor = C.White,
		Stroke = 0.01,
		Offset = 3,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
		Parent = header,
	})
	local body =
		Kit.box({ Size = UDim2.new(1, -48, 1, -64), Position = UDim2.fromOffset(24, 40), ZIndex = 6, Parent = card })

	local kind = "Normal"
	local fillBots = true

	local kindSelector: Kit.Segmented
	local modeSelector: Kit.Segmented
	local info: TextLabel
	local botsButton: Kit.Button
	local launch: Kit.Button
	local cancel: Kit.Button
	local searchPanel: Frame
	local searchTitle: TextLabel
	local searchClock: TextLabel

	local function refresh()
		local profile = State.Profile
		local level = if profile then profile.Level else 1
		local rankedUnlocked = level >= Config.RankedUnlockLevel
		kindSelector.SetEnabled("Classe", rankedUnlocked)
		local mode = modeSelector.Value()
		local modeInfo = Config.Modes[mode]
		modeSelector.SetEnabled("2v2", kind ~= "Classe")
		if kind == "Classe" and mode == "2v2" then
			modeSelector.Select("3v3")
			mode = "3v3"
			modeInfo = Config.Modes[mode]
		end
		local party = State.Party
		local partySize = if party then #party.Members else 1
		local isLeader = party == nil or party.LeaderId == LocalPlayer.UserId
		local dims = Court.get(mode)
		local lines = {
			`{modeInfo.Label}  ·  2 × {Format.clock(modeInfo.HalfDuration)}  ·  terrain {dims.Length} × {dims.Width}`,
		}
		if kind == "Classe" and profile then
			local rank = Progression.getRank(profile.RP)
			table.insert(lines, `Rang : {rank.Name} {Progression.getDivision(profile.RP)}  ·  {profile.RP} RP`)
		elseif kind == "Entrainement" then
			table.insert(lines, "Partie amicale avec ton groupe, sans récompense.")
		elseif not rankedUnlocked then
			table.insert(lines, `Le classé se débloque au niveau {Config.RankedUnlockLevel}.`)
		end
		if partySize > modeInfo.TeamSize and kind ~= "Entrainement" then
			table.insert(lines, "Ton groupe est trop grand pour ce mode.")
		end
		info.Text = table.concat(lines, "\n")
		botsButton.Instance.Visible = kind == "Entrainement"
		botsButton.SetText(if fillBots then "BOTS : ACTIVÉS" else "BOTS : DÉSACTIVÉS")
		botsButton.SetColor(if fillBots then C.Lime else C.Surface3)
		local searching = State.Queue.State ~= "Idle"
		launch.Instance.Visible = not searching
		cancel.Instance.Visible = searching and State.Queue.State == "Searching"
		searchPanel.Visible = searching
		launch.SetText(
			if not isLeader then "LE CHEF LANCE" elseif kind == "Entrainement" then "S'ENTRAÎNER" else "RECHERCHER"
		)
		launch.SetColor(kindColor(kind))
		launch.SetEnabled(isLeader and (kind == "Entrainement" or partySize <= modeInfo.TeamSize))
	end

	sectionLabel(body, "TYPE DE PARTIE", 0, 6)
	local tilesHolder =
		Kit.box({ Size = UDim2.new(1, 0, 0, 86), Position = UDim2.fromOffset(0, 22), ZIndex = 7, Parent = body })
	kindSelector = kindTiles(tilesHolder, 7, function(value: string)
		kind = value
		refresh()
	end)
	sectionLabel(body, "MODE", 118, 6)
	local modeOptions = {}
	for _, mode in Config.ModeOrder do
		table.insert(modeOptions, { Id = mode, Label = mode })
	end
	modeSelector = Kit.segmented({
		Options = modeOptions,
		Value = "3v3",
		Color = C.Cyan,
		TextSize = Theme.Text.H3,
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.fromOffset(0, 140),
		ZIndex = 7,
		Parent = body,
		OnChange = function()
			refresh()
		end,
	})
	info = Kit.label({
		Text = "",
		Font = Theme.Fonts.Semibold,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Wrap = true,
		AlignY = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.fromOffset(0, 200),
		ZIndex = 6,
		Parent = body,
	})
	botsButton = Kit.button({
		Text = "BOTS : ACTIVÉS",
		Variant = "Ghost",
		Font = Theme.Fonts.Display,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 250),
		TextSize = Theme.Text.Small + 1,
		ZIndex = 7,
		Parent = body,
		OnClick = function()
			fillBots = not fillBots
			refresh()
		end,
	})

	-- État de recherche : lignes de vitesse, gros chrono.
	searchPanel = Kit.surface({
		Color = C.Ink,
		Gradient = false,
		Size = UDim2.new(1, -150, 0, 68),
		Position = UDim2.new(0, 0, 1, -68),
		BorderColor = C.Accent,
		Clip = true,
		Visible = false,
		ZIndex = 7,
		Parent = body,
	})
	Kit.speedLines({ Parent = searchPanel, Color = C.Accent, Count = 12, Transparency = 0.6, Speed = 0.6, ZIndex = 7 })
	searchTitle = Kit.label({
		Text = "",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Small,
		Color = C.Accent,
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(14, 8),
		ZIndex = 8,
		Parent = searchPanel,
	})
	searchClock = Kit.label({
		Text = "0:00",
		Font = Theme.Fonts.Number,
		TextSize = 36,
		Color = C.White,
		Stroke = 2,
		Size = UDim2.new(1, -24, 0, 38),
		Position = UDim2.fromOffset(14, 24),
		ZIndex = 8,
		Parent = searchPanel,
	})

	launch = Kit.button({
		Text = "RECHERCHER",
		Variant = "Primary",
		Font = Theme.Fonts.Hero,
		TextSize = 42,
		Size = UDim2.new(1, 0, 0, 66),
		Position = UDim2.new(0, 0, 1, -66),
		Rotation = -2,
		ZIndex = 7,
		Parent = body,
		OnClick = function()
			local mode = modeSelector.Value()
			if kind == "Entrainement" then
				State.request("QueueAction", "Training", mode, fillBots)
			else
				State.request("QueueAction", "Search", mode, kind == "Classe")
			end
		end,
	})
	cancel = Kit.button({
		Text = "ANNULER",
		Variant = "Danger",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.H3,
		Size = UDim2.fromOffset(136, 60),
		Position = UDim2.new(1, 0, 1, -64),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 7,
		Parent = body,
		OnClick = function()
			State.request("QueueAction", "Cancel")
		end,
	})
	cancel.Instance.Visible = false

	-- Chronomètre de recherche.
	local lastSecond = -1
	task.spawn(function()
		while card.Parent do
			local queue = State.Queue
			if queue.State == "Searching" and queue.Since then
				local mode = Config.Modes[queue.Mode or "3v3"]
				local elapsed = math.max(0, os.time() - queue.Since)
				searchTitle.Text = `RECHERCHE {if mode then string.upper(mode.Label) else ""}{if queue.Ranked
					then " · CLASSÉ"
					else ""}`
				searchClock.Text = Format.clock(elapsed)
				if elapsed ~= lastSecond then
					lastSecond = elapsed
					Kit.pop(searchClock, 1.12)
				end
			elseif queue.State == "Found" then
				searchTitle.Text = "ADVERSAIRES TROUVÉS"
				searchClock.Text = "PARTIE TROUVÉE !"
			elseif queue.State == "Teleporting" then
				searchTitle.Text = "EN ROUTE"
				searchClock.Text = "CONNEXION…"
			end
			task.wait(0.25)
		end
	end)

	State.ProfileChanged:Connect(refresh)
	State.PartyChanged:Connect(refresh)
	State.QueueChanged:Connect(refresh)
	refresh()
	Kit.reveal(card, 0.1, 40)
end

-- Groupe ---------------------------------------------------------------------------------------------

local thumbnails: { [number]: string } = {}

local function avatar(userId: number, parent: Instance, size: number, z: number): ImageLabel
	local image = Kit.new("ImageLabel", {
		BackgroundColor3 = C.Surface3,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size, size),
		Image = thumbnails[userId] or "",
		ZIndex = z,
		Parent = parent,
	})
	Kit.corner(image, math.floor(size / 2))
	Kit.border(image, C.Ink, 3)
	if not thumbnails[userId] then
		task.spawn(function()
			local ok, url = pcall(function()
				return Players:GetUserThumbnailAsync(
					userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size150x150
				)
			end)
			if ok then
				thumbnails[userId] = url
				image.Image = url
			end
		end)
	end
	return image
end

local SLOT_COLORS = { C.Accent, C.Pink, C.Cyan, C.Lime, C.Violet }

local function buildParty()
	local strip = Kit.box({
		Size = UDim2.fromOffset(600, 170),
		Position = UDim2.new(1, -40, 1, -40),
		AnchorPoint = Vector2.new(1, 1),
		ZIndex = 5,
		Parent = home,
	})
	local tag = Kit.plate({
		Color = C.Violet,
		Size = UDim2.fromOffset(110, 28),
		Position = UDim2.new(1, -6, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BorderThickness = 2.5,
		ShadowOffset = 3,
		ZIndex = 6,
		Parent = strip,
	})
	Kit.label({
		Text = "GROUPE",
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Body,
		Color = C.White,
		Stroke = 1.5,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
		Parent = tag,
	})
	local slots =
		Kit.box({ Size = UDim2.new(1, 0, 0, 132), Position = UDim2.fromOffset(0, 38), ZIndex = 6, Parent = strip })
	Kit.list(slots, 12, true, Enum.HorizontalAlignment.Right)
	local picker: Frame? = nil

	local function closePicker()
		if picker then
			picker:Destroy()
			picker = nil
		end
	end

	local function openPicker()
		closePicker()
		local panel = Kit.surface({
			Color = C.Surface,
			Size = UDim2.fromOffset(360, 400),
			Position = UDim2.new(1, -40, 1, -230),
			AnchorPoint = Vector2.new(1, 1),
			Radius = Theme.RadiusLarge,
			BorderThickness = 3,
			Shadow = true,
			ShadowColor = C.Cyan,
			ShadowOffset = 7,
			ZIndex = 40,
			Parent = home,
		})
		picker = panel
		local plate = Kit.plate({
			Color = C.Cyan,
			Size = UDim2.fromOffset(150, 40),
			Position = UDim2.fromOffset(16, -16),
			ZIndex = 41,
			Parent = panel,
		})
		Kit.label({
			Text = "INVITER",
			Font = Theme.Fonts.Hero,
			TextSize = 30,
			Color = C.TextOnAccent,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 42,
			Parent = plate,
		})
		Kit.button({
			Text = "Fermer",
			Variant = "Ghost",
			Size = UDim2.fromOffset(90, 34),
			Position = UDim2.new(1, -16, 0, 14),
			AnchorPoint = Vector2.new(1, 0),
			TextSize = Theme.Text.Small,
			ZIndex = 42,
			Parent = panel,
			OnClick = closePicker,
		})
		local list = Kit.scroll({
			Size = UDim2.new(1, -24, 1, -76),
			Position = UDim2.fromOffset(12, 64),
			ZIndex = 41,
			Parent = panel,
		})
		Kit.list(list, 8)
		Kit.padding(list, 4, 4)
		local count = 0
		local party = State.Party
		for _, other in Players:GetPlayers() do
			local inParty = false
			if party then
				for _, member in party.Members do
					if member.UserId == other.UserId then
						inParty = true
					end
				end
			end
			if other ~= LocalPlayer and not inParty then
				count += 1
				local row = Kit.surface({
					Color = C.Surface2,
					Size = UDim2.new(1, -12, 0, 56),
					Order = count,
					ZIndex = 42,
					Parent = list,
				})
				local face = avatar(other.UserId, row, 38, 43)
				face.BackgroundColor3 = SLOT_COLORS[(count - 1) % #SLOT_COLORS + 1]
				face.Position = UDim2.fromOffset(10, 9)
				Kit.label({
					Text = other.DisplayName,
					Font = Theme.Fonts.Bold,
					Position = UDim2.fromOffset(58, 0),
					Size = UDim2.new(1, -160, 1, 0),
					ZIndex = 43,
					Parent = row,
				})
				Kit.button({
					Text = "INVITER",
					Variant = "Primary",
					Font = Theme.Fonts.Display,
					TextSize = Theme.Text.Small,
					Size = UDim2.fromOffset(90, 36),
					Position = UDim2.new(1, -12, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					ZIndex = 43,
					Parent = row,
					OnClick = function()
						if State.request("PartyAction", "Invite", other.UserId) then
							State.Notify:Fire(`Invitation envoyée à {other.DisplayName}`, "Success")
						end
					end,
				})
			end
		end
		if count == 0 then
			Kit.label({
				Text = "Aucun autre joueur sur ce serveur.",
				Font = Theme.Fonts.Semibold,
				Color = C.TextMuted,
				TextSize = Theme.Text.Small,
				Wrap = true,
				Size = UDim2.new(1, 0, 0, 40),
				ZIndex = 42,
				Parent = list,
			})
		end
		Kit.pop(panel, 0.85)
	end

	local function render(party: any)
		Kit.clear(slots)
		local members = if party
			then party.Members
			else {
				{
					UserId = LocalPlayer.UserId,
					Name = LocalPlayer.DisplayName,
					Level = if State.Profile then State.Profile.Level else 1,
				},
			}
		local leaderId = if party then party.LeaderId else LocalPlayer.UserId
		local iAmLeader = leaderId == LocalPlayer.UserId
		for index = 1, Config.MaxPartySize do
			local member = members[index]
			local color = SLOT_COLORS[(index - 1) % #SLOT_COLORS + 1]
			-- Le support reste dans le layout ; la carte et son ombre vivent dedans.
			local holder = Kit.box({ Size = UDim2.fromOffset(104, 128), Order = index, ZIndex = 6, Parent = slots })
			local slot = Kit.surface({
				Color = if member then C.Surface2 else C.Surface,
				Size = UDim2.new(1, -6, 1, -6),
				BorderThickness = 3,
				Shadow = member ~= nil,
				ShadowColor = color,
				ShadowOffset = 5,
				ZIndex = 6,
				Parent = holder,
			})
			if member then
				Kit.new("Frame", {
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 30),
					ZIndex = 6,
					Parent = slot,
				})
				local face = avatar(member.UserId, slot, 62, 7)
				face.BackgroundColor3 = color
				face.Position = UDim2.fromOffset(18, 8)
				Kit.label({
					Text = member.Name,
					Font = Theme.Fonts.Bold,
					TextSize = Theme.Text.Small,
					AlignX = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, -10, 0, 18),
					Position = UDim2.fromOffset(5, 74),
					ZIndex = 7,
					Parent = slot,
				})
				local isLeader = member.UserId == leaderId
				local badge = Kit.new("Frame", {
					BackgroundColor3 = if isLeader then C.Accent else C.Ink,
					BorderSizePixel = 0,
					Size = UDim2.fromOffset(64, 18),
					Position = UDim2.new(0.5, 0, 0, 96),
					AnchorPoint = Vector2.new(0.5, 0),
					Rotation = -3,
					ZIndex = 7,
					Parent = slot,
				})
				Kit.corner(badge, 4)
				Kit.border(badge, if isLeader then C.Ink else color, 2)
				Kit.label({
					Text = if isLeader then "CHEF" else `NIV. {member.Level}`,
					Font = Theme.Fonts.Display,
					TextSize = Theme.Text.Tiny,
					Color = if isLeader then C.TextOnAccent else color,
					AlignX = Enum.TextXAlignment.Center,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 8,
					Parent = badge,
				})
				if iAmLeader and member.UserId ~= LocalPlayer.UserId then
					local kick = Kit.new("TextButton", {
						AutoButtonColor = false,
						BackgroundTransparency = 1,
						Text = "",
						Size = UDim2.fromScale(1, 1),
						ZIndex = 9,
						Parent = slot,
					})
					kick.Activated:Connect(function()
						State.request("PartyAction", "Kick", member.UserId)
					end)
				end
			elseif iAmLeader then
				local add = Kit.new("TextButton", {
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					Text = "",
					Size = UDim2.fromScale(1, 1),
					ZIndex = 8,
					Parent = slot,
				})
				local plus = Kit.label({
					Text = "+",
					Font = Theme.Fonts.Hero,
					TextSize = 56,
					Color = C.TextFaint,
					AlignX = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 70),
					Position = UDim2.fromOffset(0, 10),
					ZIndex = 7,
					Parent = slot,
				})
				local caption = Kit.label({
					Text = "INVITER",
					Font = Theme.Fonts.Display,
					TextSize = Theme.Text.Small,
					Color = C.TextMuted,
					AlignX = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 18),
					Position = UDim2.fromOffset(0, 86),
					ZIndex = 7,
					Parent = slot,
				})
				add.MouseEnter:Connect(function()
					slot.BackgroundColor3 = Theme.darken(color, 0.55)
					plus.TextColor3 = color
					caption.TextColor3 = C.White
				end)
				add.MouseLeave:Connect(function()
					slot.BackgroundColor3 = C.Surface
					plus.TextColor3 = C.TextFaint
					caption.TextColor3 = C.TextMuted
				end)
				add.Activated:Connect(openPicker)
			end
		end
		if party then
			local leave = Kit.button({
				Text = "QUITTER",
				Variant = "Danger",
				Font = Theme.Fonts.Display,
				TextSize = Theme.Text.Small,
				Size = UDim2.fromOffset(96, 30),
				Position = UDim2.fromOffset(0, -2),
				ZIndex = 7,
				Parent = strip,
				OnClick = function()
					State.request("PartyAction", "Leave")
				end,
			})
			leave.Instance.Name = "Quitter"
		else
			local old = strip:FindFirstChild("Quitter")
			if old then
				old:Destroy()
			end
		end
	end
	State.PartyChanged:Connect(function(party)
		local old = strip:FindFirstChild("Quitter")
		if old then
			old:Destroy()
		end
		render(party)
	end)
	State.ProfileChanged:Connect(function()
		if not State.Party then
			render(nil)
		end
	end)
	render(State.Party)
end

function LobbyMenu.start()
	if not State.isLobby() then
		return
	end
	gui, root = Kit.screen("Lobby", 10, LocalPlayer:WaitForChild("PlayerGui"))
	gui.Enabled = false
	home = Kit.box({ Name = "Accueil", ZIndex = 5, Parent = root })

	buildTopBar()
	buildPlayPanel()
	buildParty()

	local pageLayer = Kit.box({ Name = "Pages", ZIndex = 10, Parent = root })
	pages["CASIER"] = LockerScreen.create(pageLayer)
	pages["BOUTIQUE"] = ShopScreen.create(pageLayer)
	pages["CLAN"] = ClanScreen.create(pageLayer)
	pages["TUTORIEL"] = TutorialScreen.create(pageLayer, function()
		closeModal("TUTORIEL")
	end)
	pages["NOUVEAUTÉS"] = UpdatesScreen.create(pageLayer, function()
		closeModal("NOUVEAUTÉS")
	end)

	local function updateVisibility()
		gui.Enabled = State.Started and not State.inMatch() and State.Setup == nil
	end
	State.Began:Connect(function()
		updateVisibility()
		selectTab("JOUER")
		local profile = State.Profile
		if profile and not profile.TutorialDone and profile.Stats.Matches == 0 then
			openModal("TUTORIEL")
		end
	end)
	State.MatchChanged:Connect(function()
		if State.inMatch() then
			selectTab("JOUER")
		end
		updateVisibility()
	end)
	State.SetupChanged:Connect(function()
		selectTab("JOUER")
		updateVisibility()
	end)
	State.MatchEvent:Connect(function(kind)
		if kind == "Leave" then
			State.Setup = nil
			updateVisibility()
		end
	end)
	updateVisibility()
end

return LobbyMenu
