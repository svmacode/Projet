--!strict
-- CLAN : création (1 000 R$), membres et rôles, invitations,
-- personnalisation (emblème, couleurs, motif, accent de tenue).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClanStyle = require(ReplicatedStorage.Shared.Data.ClanStyle)
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.UI.Kit)
local Page = require(script.Parent.Parent.UI.Page)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors
local LocalPlayer = Players.LocalPlayer

local ClanScreen = {}

local Z = 34
local ROLE_COLORS = { Chef = C.Gold, Officier = C.Sky, Membre = C.TextFaint }

-- Blason du clan : bannière arrondie, motif, emblème.
function ClanScreen.crest(parent: Instance, clan: any, size: Vector2, z: number): Frame
	local color = ClanStyle.color(clan.BannerColor)
	local accent = ClanStyle.color(clan.EmblemColor)
	local banner = Kit.new("Frame", {
		Name = "Blason",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(size.X, size.Y),
		ClipsDescendants = true,
		ZIndex = z,
		Parent = parent,
	})
	Kit.corner(banner, math.floor(size.X * 0.18))
	Kit.gradient(banner, Theme.lighten(color, 0.15), Theme.darken(color, 0.12), 90)
	Kit.border(banner, C.White, 3)
	local pattern = clan.BannerPattern
	local function stripe(sizeValue: UDim2, position: UDim2, rotation: number)
		Kit.new("Frame", {
			BackgroundColor3 = accent,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = sizeValue,
			Position = position,
			Rotation = rotation,
			ZIndex = z,
			Parent = banner,
		})
	end
	if pattern == "Bande" then
		stripe(UDim2.new(1.2, 0, 0.2, 0), UDim2.fromScale(0.5, 0.5), 0)
	elseif pattern == "Diagonale" then
		stripe(UDim2.new(1.8, 0, 0.22, 0), UDim2.fromScale(0.5, 0.5), -40)
	elseif pattern == "Soleil" then
		local sun = Kit.new("Frame", {
			BackgroundColor3 = accent,
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.78, 0.78),
			ZIndex = z,
			Parent = banner,
		})
		Kit.round(sun)
	elseif pattern == "Chevron" then
		stripe(UDim2.new(0.9, 0, 0.16, 0), UDim2.new(0.28, 0, 0.78, 0), -35)
		stripe(UDim2.new(0.9, 0, 0.16, 0), UDim2.new(0.72, 0, 0.78, 0), 35)
	end
	Kit.label({
		Text = ClanStyle.emblem(clan.Emblem).Glyph,
		Font = Theme.Fonts.Bold,
		TextSize = math.floor(size.Y * 0.5),
		Color = C.White,
		Stroke = math.max(2, size.Y / 40),
		StrokeColor = Theme.darken(color, 0.4),
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 1,
		Parent = banner,
	})
	return banner
end

local function heading(parent: Instance, text: string, position: UDim2, z: number)
	return Kit.label({
		Text = string.upper(text),
		Font = Theme.Fonts.Display,
		TextSize = Theme.Text.Small,
		Color = C.TextMuted,
		Size = UDim2.new(1, 0, 0, 18),
		Position = position,
		ZIndex = z,
		Parent = parent,
	})
end

-- Rangée de pastilles de couleur.
local function swatches(parent: Instance, y: number, selected: number, z: number, onPick: (number) -> ())
	local row =
		Kit.box({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, y), ZIndex = z, Parent = parent })
	Kit.list(row, 6, true)
	for index, color in ClanStyle.Palette do
		local swatch = Kit.new("TextButton", {
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(28, 28),
			LayoutOrder = index,
			ZIndex = z,
			Parent = row,
		})
		Kit.round(swatch)
		Kit.border(swatch, if index == selected then C.Ink else C.Border, if index == selected then 3 else 1.5)
		swatch.Activated:Connect(function()
			Kit.playSound(Theme.Sounds.Click, 0.3)
			onPick(index)
		end)
	end
end

function ClanScreen.create(parent: Instance, onClose: () -> ()): Page.Page
	local accent = Theme.Section.Clan
	local page = Page.modal(parent, "Clan", Vector2.new(1180, 700), onClose, accent)
	local content = page.Content
	local meta = { Credits = 0, ProductEnabled = false, Price = Config.ProductRobuxPrice.ClanCreation }
	local inviting = false

	local render: () -> ()

	local function renderCreate()
		local preview = {
			BannerColor = 7,
			EmblemColor = 9,
			BannerPattern = "Soleil",
			Emblem = "Dragon",
		}
		local left = Kit.surface({
			Color = C.Surface2,
			Border = false,
			Radius = 18,
			Size = UDim2.new(0.42, 0, 1, 0),
			ZIndex = Z,
			Parent = content,
		})
		local crest = ClanScreen.crest(left, preview, Vector2.new(170, 200), Z + 1)
		crest.AnchorPoint = Vector2.new(0.5, 0)
		crest.Position = UDim2.new(0.5, 0, 0, 40)
		Kit.label({
			Text = "Porte tes couleurs",
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H2,
			Color = C.Text,
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, -40, 0, 32),
			Position = UDim2.fromOffset(20, 270),
			ZIndex = Z + 1,
			Parent = left,
		})
		Kit.label({
			Text = `Jusqu'à {Config.Clan.MaxMembers} membres, un blason personnalisé, un accent de couleur sur vos tenues et un tag affiché au-dessus de vos têtes.`,
			Font = Theme.Fonts.Semibold,
			TextSize = Theme.Text.Body,
			Color = C.TextMuted,
			Wrap = true,
			AlignX = Enum.TextXAlignment.Center,
			AlignY = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -60, 0, 100),
			Position = UDim2.fromOffset(30, 312),
			ZIndex = Z + 1,
			Parent = left,
		})

		local right = Kit.box({
			Size = UDim2.new(0.58, -32, 1, 0),
			Position = UDim2.new(0.42, 32, 0, 0),
			ZIndex = Z,
			Parent = content,
		})
		Kit.label({
			Text = "Créer un clan",
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H1,
			Color = C.Text,
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 20),
			ZIndex = Z,
			Parent = right,
		})
		local function field(label: string, hint: string, y: number): TextBox
			heading(right, label, UDim2.fromOffset(0, y), Z)
			local box = Kit.new("TextBox", {
				BackgroundColor3 = C.Surface2,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				PlaceholderText = hint,
				PlaceholderColor3 = C.TextFaint,
				Text = "",
				TextColor3 = C.Text,
				FontFace = Theme.Fonts.Bold,
				TextSize = Theme.Text.H3,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 54),
				Position = UDim2.fromOffset(0, y + 24),
				ZIndex = Z,
				Parent = right,
			})
			Kit.corner(box, 12)
			Kit.border(box, C.Border, 2)
			Kit.padding(box, 16, 0)
			return box
		end
		local nameBox = field("Nom", `{Config.Clan.NameMinLength} à {Config.Clan.NameMaxLength} caractères`, 90)
		local tagBox = field("Tag", `{Config.Clan.TagMinLength} à {Config.Clan.TagMaxLength} lettres ou chiffres`, 186)
		Kit.label({
			Text = if meta.Credits > 0
				then "Tu as une création de clan disponible."
				else `La création d'un clan coûte {meta.Price} Robux.`,
			Font = Theme.Fonts.Semibold,
			TextSize = Theme.Text.Small,
			Color = C.TextMuted,
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 290),
			ZIndex = Z,
			Parent = right,
		})
		local create = Kit.button({
			Text = if meta.Credits > 0
				then "CRÉER LE CLAN"
				elseif meta.ProductEnabled then `CRÉER LE CLAN · {meta.Price} R$`
				else "BIENTÔT DISPONIBLE",
			Variant = "Primary",
			Color = accent,
			TextSize = Theme.Text.H3,
			Size = UDim2.new(1, 0, 0, 58),
			Position = UDim2.fromOffset(0, 326),
			ZIndex = Z,
			Parent = right,
			OnClick = function()
				local ok, result = State.request("ClanAction", "Create", nameBox.Text, tagBox.Text)
				if ok and result and result.Pending then
					State.Notify:Fire("Valide l'achat pour créer ton clan.", "Info")
				end
			end,
		})
		create.SetEnabled(meta.Credits > 0 or meta.ProductEnabled)
	end

	local function renderClan(clan: any)
		local myRole = "Membre"
		for _, member in clan.Members do
			if member.UserId == LocalPlayer.UserId then
				myRole = member.Role
			end
		end
		local canManage = myRole == "Chef" or myRole == "Officier"

		-- Colonne gauche : blason, nom, statistiques, personnalisation.
		local left = Kit.surface({
			Color = C.Surface2,
			Border = false,
			Radius = 18,
			Size = UDim2.new(0, 400, 1, 0),
			ZIndex = Z,
			Parent = content,
		})
		local crest = ClanScreen.crest(left, clan, Vector2.new(96, 112), Z + 1)
		crest.Position = UDim2.fromOffset(20, 20)
		Kit.label({
			Text = clan.Name,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H2,
			Color = C.Text,
			Size = UDim2.new(1, -150, 0, 32),
			Position = UDim2.fromOffset(132, 28),
			ZIndex = Z + 1,
			Parent = left,
		})
		local tag = Kit.pill(left, `[{clan.Tag}]`, ClanStyle.color(clan.BannerColor))
		tag.Position = UDim2.fromOffset(132, 64)
		tag.ZIndex = Z + 1
		for _, object in tag:GetDescendants() do
			if object:IsA("GuiObject") then
				object.ZIndex = Z + 2
			end
		end
		Kit.label({
			Text = `{#clan.Members} / {clan.MaxMembers or Config.Clan.MaxMembers} membres  ·  {clan.Wins} victoires`,
			Font = Theme.Fonts.Semibold,
			TextSize = Theme.Text.Small,
			Color = C.TextMuted,
			Size = UDim2.new(1, -150, 0, 20),
			Position = UDim2.fromOffset(132, 96),
			ZIndex = Z + 1,
			Parent = left,
		})
		local custom = Kit.box({
			Size = UDim2.new(1, -40, 1, -230),
			Position = UDim2.fromOffset(20, 156),
			ZIndex = Z + 1,
			Parent = left,
		})
		if canManage then
			heading(custom, "Emblème", UDim2.fromOffset(0, 0), Z + 1)
			local emblems = Kit.box({
				Size = UDim2.new(1, 0, 0, 72),
				Position = UDim2.fromOffset(0, 22),
				ZIndex = Z + 1,
				Parent = custom,
			})
			Kit.grid(emblems, Vector2.new(34, 34), 6)
			for index, emblem in ClanStyle.Emblems do
				local on = clan.Emblem == emblem.Id
				local button = Kit.new("TextButton", {
					AutoButtonColor = false,
					BackgroundColor3 = if on then accent else C.White,
					BorderSizePixel = 0,
					Text = emblem.Glyph,
					FontFace = Theme.Fonts.Bold,
					TextSize = 18,
					TextColor3 = if on then C.White else C.Text,
					LayoutOrder = index,
					ZIndex = Z + 2,
					Parent = emblems,
				})
				Kit.corner(button, 8)
				Kit.border(button, if on then Theme.darken(accent, 0.2) else C.Border, 1.5)
				button.Activated:Connect(function()
					State.request("ClanAction", "Customize", "Emblem", emblem.Id)
				end)
			end
			heading(custom, "Couleur de la bannière", UDim2.fromOffset(0, 104), Z + 1)
			swatches(custom, 126, clan.BannerColor, Z + 1, function(index)
				State.request("ClanAction", "Customize", "BannerColor", index)
			end)
			heading(custom, "Couleur de l'emblème", UDim2.fromOffset(0, 166), Z + 1)
			swatches(custom, 188, clan.EmblemColor, Z + 1, function(index)
				State.request("ClanAction", "Customize", "EmblemColor", index)
			end)
			heading(custom, "Accent des tenues", UDim2.fromOffset(0, 228), Z + 1)
			swatches(custom, 250, clan.KitAccent, Z + 1, function(index)
				State.request("ClanAction", "Customize", "KitAccent", index)
			end)
			local patternOptions = {}
			for _, pattern in ClanStyle.Patterns do
				table.insert(patternOptions, { Id = pattern.Id, Label = pattern.Name })
			end
			heading(custom, "Motif", UDim2.fromOffset(0, 290), Z + 1)
			Kit.segmented({
				Options = patternOptions,
				Value = clan.BannerPattern,
				TextSize = Theme.Text.Tiny,
				Color = accent,
				Size = UDim2.new(1, 0, 0, 40),
				Position = UDim2.fromOffset(0, 312),
				ZIndex = Z + 1,
				Parent = custom,
				OnChange = function(value: string)
					State.request("ClanAction", "Customize", "BannerPattern", value)
				end,
			})
		else
			Kit.label({
				Text = "Le chef et les officiers personnalisent le blason et l'accent de tenue du clan.",
				Font = Theme.Fonts.Semibold,
				TextSize = Theme.Text.Small,
				Color = C.TextMuted,
				Wrap = true,
				AlignY = Enum.TextYAlignment.Top,
				Size = UDim2.new(1, 0, 0, 60),
				ZIndex = Z + 1,
				Parent = custom,
			})
		end
		Kit.button({
			Text = "QUITTER LE CLAN",
			Variant = "Danger",
			Size = UDim2.new(1, -40, 0, 46),
			Position = UDim2.new(0, 20, 1, -62),
			ZIndex = Z + 1,
			Parent = left,
			OnClick = function()
				State.request("ClanAction", "Leave")
			end,
		})

		-- Colonne droite : membres ou invitations.
		local right = Kit.box({
			Size = UDim2.new(1, -428, 1, 0),
			Position = UDim2.fromOffset(428, 0),
			ZIndex = Z,
			Parent = content,
		})
		Kit.label({
			Text = if inviting then "Inviter des joueurs" else "Membres",
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H2,
			Color = C.Text,
			Size = UDim2.new(1, -200, 0, 44),
			ZIndex = Z,
			Parent = right,
		})
		if canManage then
			Kit.button({
				Text = if inviting then "RETOUR" else "INVITER",
				Variant = if inviting then "Light" else "Secondary",
				Size = UDim2.fromOffset(160, 44),
				Position = UDim2.new(1, 0, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				ZIndex = Z,
				Parent = right,
				OnClick = function()
					inviting = not inviting
					render()
				end,
			})
		end
		local list = Kit.scroll({
			Size = UDim2.new(1, 0, 1, -60),
			Position = UDim2.fromOffset(0, 60),
			ZIndex = Z,
			Parent = right,
		})
		Kit.list(list, 8)
		Kit.padding(list, 2, 2)
		local function row(order: number): Frame
			local frame = Kit.surface({
				Color = C.Surface2,
				Border = false,
				Radius = 14,
				Size = UDim2.new(1, -10, 0, 60),
				Order = order,
				ZIndex = Z + 1,
				Parent = list,
			})
			return frame
		end
		local function avatarDot(parent: Instance, name: string, color: Color3)
			local dot = Kit.new("Frame", {
				BackgroundColor3 = C.White,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(40, 40),
				Position = UDim2.fromOffset(12, 10),
				ZIndex = Z + 2,
				Parent = parent,
			})
			Kit.round(dot)
			Kit.gradient(dot, Theme.lighten(color, 0.25), color, 90)
			Kit.label({
				Text = string.upper(string.sub(name, 1, 1)),
				Font = Theme.Fonts.Display,
				TextSize = Theme.Text.H3,
				Color = Theme.onColor(color),
				AlignX = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				ZIndex = Z + 3,
				Parent = dot,
			})
		end
		if inviting then
			local order = 0
			local members: { [number]: boolean } = {}
			for _, member in clan.Members do
				members[member.UserId] = true
			end
			for _, other in Players:GetPlayers() do
				if not members[other.UserId] then
					order += 1
					local line = row(order)
					avatarDot(line, other.DisplayName, C.Sky)
					Kit.label({
						Text = other.DisplayName,
						Font = Theme.Fonts.Bold,
						Color = C.Text,
						Size = UDim2.new(1, -220, 1, 0),
						Position = UDim2.fromOffset(64, 0),
						ZIndex = Z + 2,
						Parent = line,
					})
					Kit.button({
						Text = "INVITER",
						Variant = "Secondary",
						TextSize = Theme.Text.Small,
						Size = UDim2.fromOffset(120, 40),
						Position = UDim2.new(1, -12, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						ZIndex = Z + 2,
						Parent = line,
						OnClick = function()
							if State.request("ClanAction", "Invite", other.UserId) then
								State.Notify:Fire(`Invitation envoyée à {other.DisplayName}`, "Success")
							end
						end,
					})
				end
			end
			if order == 0 then
				Kit.label({
					Text = "Aucun autre joueur sur ce serveur.",
					Font = Theme.Fonts.Semibold,
					Color = C.TextMuted,
					Size = UDim2.new(1, 0, 0, 40),
					ZIndex = Z + 1,
					Parent = list,
				})
			end
			return
		end
		local members = table.clone(clan.Members)
		local roleRank = { Chef = 1, Officier = 2, Membre = 3 }
		table.sort(members, function(a: any, b: any)
			if roleRank[a.Role] ~= roleRank[b.Role] then
				return (roleRank[a.Role] or 9) < (roleRank[b.Role] or 9)
			end
			return a.Name < b.Name
		end)
		for index, member in members do
			local line = row(index)
			local roleColor = ROLE_COLORS[member.Role] or C.TextFaint
			avatarDot(line, member.Name, roleColor)
			Kit.label({
				Text = member.Name,
				Font = Theme.Fonts.Bold,
				Color = C.Text,
				Size = UDim2.new(1, -420, 0, 22),
				Position = UDim2.fromOffset(64, 9),
				ZIndex = Z + 2,
				Parent = line,
			})
			Kit.label({
				Text = member.Role,
				Font = Theme.Fonts.Semibold,
				TextSize = Theme.Text.Small,
				Color = if member.Role == "Membre" then C.TextMuted else Theme.darken(roleColor, 0.15),
				Size = UDim2.new(1, -420, 0, 18),
				Position = UDim2.fromOffset(64, 31),
				ZIndex = Z + 2,
				Parent = line,
			})
			local actions = Kit.box({
				Size = UDim2.fromOffset(320, 40),
				Position = UDim2.new(1, -12, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				ZIndex = Z + 2,
				Parent = line,
			})
			Kit.list(actions, 8, true, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
			if member.UserId ~= LocalPlayer.UserId and member.Role ~= "Chef" and canManage then
				if myRole == "Chef" then
					Kit.button({
						Text = if member.Role == "Officier" then "RÉTROGRADER" else "PROMOUVOIR",
						Variant = "Light",
						TextSize = Theme.Text.Tiny + 1,
						Size = UDim2.fromOffset(140, 38),
						Order = 1,
						ZIndex = Z + 2,
						Parent = actions,
						OnClick = function()
							State.request(
								"ClanAction",
								"SetRole",
								member.UserId,
								if member.Role == "Officier" then "Membre" else "Officier"
							)
						end,
					})
				end
				if myRole == "Chef" or member.Role == "Membre" then
					Kit.button({
						Text = "EXCLURE",
						Variant = "Danger",
						TextSize = Theme.Text.Tiny + 1,
						Size = UDim2.fromOffset(110, 38),
						Order = 2,
						ZIndex = Z + 2,
						Parent = actions,
						OnClick = function()
							State.request("ClanAction", "Kick", member.UserId)
						end,
					})
				end
			end
		end
	end

	render = function()
		Kit.clear(content)
		local clan = State.Clan
		if clan then
			renderClan(clan)
		else
			renderCreate()
		end
	end

	local function fetch()
		local ok, result = State.request("ClanAction", "Get")
		if ok and result then
			meta.Credits = result.Credits or 0
			meta.ProductEnabled = result.ProductEnabled == true
			meta.Price = result.Price or meta.Price
			State.Clan = result.Clan
		end
		if page.IsOpen() then
			render()
		end
	end
	State.ClanChanged:Connect(function()
		if page.IsOpen() then
			render()
		end
	end)
	local baseOpen = page.Open
	page.Open = function()
		inviting = false
		baseOpen()
		render()
		task.spawn(fetch)
	end
	return page
end

return ClanScreen
