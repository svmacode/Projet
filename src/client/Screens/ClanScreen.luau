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

-- Blason du clan (bannière + emblème).
function ClanScreen.crest(parent: Instance, clan: any, size: Vector2, z: number): Frame
	local color = ClanStyle.color(clan.BannerColor)
	local accent = ClanStyle.color(clan.EmblemColor)
	local banner = Kit.new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(size.X, size.Y),
		ClipsDescendants = true,
		ZIndex = z,
		Parent = parent,
	})
	Kit.corner(banner, Theme.RadiusLarge)
	local pattern = clan.BannerPattern
	if pattern == "Bande" then
		Kit.new("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0.2, 0),
			Position = UDim2.fromScale(0, 0.4),
			ZIndex = z,
			Parent = banner,
		})
	elseif pattern == "Diagonale" then
		Kit.new("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Size = UDim2.new(1.6, 0, 0.22, 0),
			Position = UDim2.fromScale(-0.3, 0.4),
			Rotation = -30,
			ZIndex = z,
			Parent = banner,
		})
	elseif pattern == "Soleil" then
		local sun = Kit.new("Frame", {
			BackgroundColor3 = accent,
			Size = UDim2.fromScale(1.2, 1.2),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = z,
			Parent = banner,
		})
		Kit.corner(sun, 1000)
	elseif pattern == "Chevron" then
		for _, rotation in { 35, -35 } do
			Kit.new("Frame", {
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				Size = UDim2.new(0.7, 0, 0.14, 0),
				Position = UDim2.fromScale(if rotation > 0 then 0.02 else 0.32, 0.6),
				Rotation = rotation,
				ZIndex = z,
				Parent = banner,
			})
		end
	end
	local disc = Kit.new("Frame", {
		BackgroundColor3 = C.Background,
		Size = UDim2.fromScale(0.62, 0.62),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = z + 1,
		Parent = banner,
	})
	Kit.corner(disc, 1000)
	Kit.label({
		Text = ClanStyle.emblem(clan.Emblem).Glyph,
		Font = Theme.Fonts.Display,
		TextSize = math.floor(size.Y * 0.32),
		Color = accent,
		AlignX = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 2,
		Parent = disc,
	})
	return banner
end

local function swatches(parent: Instance, label: string, y: number, selected: number, onPick: (number) -> (), z: number)
	Kit.label({
		Text = label,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.Text.Tiny,
		Color = C.TextFaint,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 16),
		ZIndex = z,
		Parent = parent,
	})
	local row =
		Kit.box({ Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, y + 20), ZIndex = z, Parent = parent })
	Kit.list(row, 8, true)
	for index, color in ClanStyle.Palette do
		local swatch = Kit.new("TextButton", {
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = color,
			Size = UDim2.fromOffset(28, 28),
			LayoutOrder = index,
			ZIndex = z,
			Parent = row,
		})
		Kit.corner(swatch, 6)
		if index == selected then
			Kit.border(swatch, C.White, 2)
		end
		swatch.Activated:Connect(function()
			onPick(index)
		end)
	end
end

function ClanScreen.create(parent: Instance): Page.Page
	local page = Page.full(parent, "Clan", "Fonde ton clan, recrute et porte vos couleurs sur le terrain.")
	local content = page.Content
	local meta = { Credits = 0, ProductEnabled = false, Price = Config.ProductRobuxPrice.ClanCreation }
	local inviting = false

	local function render()
		Kit.clear(content)
		local clan = State.Clan
		if not clan then
			local card = Kit.surface({
				Color = C.Surface,
				Size = UDim2.fromOffset(520, 420),
				Radius = Theme.RadiusLarge,
				ZIndex = 12,
				Parent = content,
			})
			local inner = Kit.box({
				Size = UDim2.new(1, -64, 1, -64),
				Position = UDim2.fromOffset(32, 32),
				ZIndex = 13,
				Parent = card,
			})
			Kit.label({
				Text = "Créer un clan",
				Font = Theme.Fonts.Display,
				TextSize = Theme.Text.H2,
				Size = UDim2.new(1, 0, 0, 32),
				ZIndex = 14,
				Parent = inner,
			})
			Kit.label({
				Text = `Jusqu'à {Config.Clan.MaxMembers} membres, un blason personnalisé, des rôles et un classement des victoires.`,
				TextSize = Theme.Text.Small,
				Color = C.TextMuted,
				Wrap = true,
				AlignY = Enum.TextYAlignment.Top,
				Size = UDim2.new(1, 0, 0, 40),
				Position = UDim2.fromOffset(0, 40),
				ZIndex = 14,
				Parent = inner,
			})
			local function field(label: string, placeholder: string, y: number): TextBox
				Kit.label({
					Text = label,
					Font = Theme.Fonts.Bold,
					TextSize = Theme.Text.Tiny,
					Color = C.TextFaint,
					Position = UDim2.fromOffset(0, y),
					Size = UDim2.new(1, 0, 0, 16),
					ZIndex = 14,
					Parent = inner,
				})
				local box = Kit.new("TextBox", {
					Text = "",
					PlaceholderText = placeholder,
					PlaceholderColor3 = C.TextFaint,
					FontFace = Theme.Fonts.Semibold,
					TextSize = Theme.Text.Body,
					TextColor3 = C.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					BackgroundColor3 = C.Surface2,
					ClearTextOnFocus = false,
					Size = UDim2.new(1, 0, 0, 46),
					Position = UDim2.fromOffset(0, y + 20),
					ZIndex = 14,
					Parent = inner,
				})
				Kit.corner(box)
				Kit.border(box)
				Kit.padding(box, 14, 0)
				return box
			end
			local nameBox = field("NOM", `{Config.Clan.NameMinLength} à {Config.Clan.NameMaxLength} caractères`, 100)
			local tagBox =
				field("TAG", `{Config.Clan.TagMinLength} à {Config.Clan.TagMaxLength} lettres ou chiffres`, 176)
			local create = Kit.button({
				Text = if meta.Credits > 0
					then "Créer le clan"
					elseif meta.ProductEnabled then `Créer le clan · {meta.Price} R$`
					else "Bientôt disponible",
				Variant = "Primary",
				Size = UDim2.new(1, 0, 0, 52),
				Position = UDim2.new(0, 0, 1, -52),
				ZIndex = 14,
				Parent = inner,
				OnClick = function()
					local ok, result = State.request("ClanAction", "Create", nameBox.Text, tagBox.Text)
					if ok and result and result.Pending then
						State.Notify:Fire("Valide l'achat pour créer ton clan.", "Info")
					end
				end,
			})
			create.SetEnabled(meta.Credits > 0 or meta.ProductEnabled)
			return
		end

		local myRole = "Membre"
		for _, member in clan.Members do
			if member.UserId == LocalPlayer.UserId then
				myRole = member.Role
			end
		end
		local canManage = myRole == "Chef" or myRole == "Officier"

		-- En-tête.
		ClanScreen.crest(content, clan, Vector2.new(220, 132), 12)
		Kit.label({
			Text = `[{clan.Tag}] {clan.Name}`,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H1,
			Position = UDim2.fromOffset(248, 16),
			Size = UDim2.new(1, -560, 0, 44),
			ZIndex = 12,
			Parent = content,
		})
		Kit.label({
			Text = `{#clan.Members} / {clan.MaxMembers} membres  ·  {clan.Wins} victoires  ·  rôle : {myRole}`,
			Color = C.TextMuted,
			Position = UDim2.fromOffset(248, 64),
			Size = UDim2.new(1, -560, 0, 22),
			ZIndex = 12,
			Parent = content,
		})
		local actions = Kit.box({
			Size = UDim2.fromOffset(300, 44),
			Position = UDim2.new(1, 0, 0, 16),
			AnchorPoint = Vector2.new(1, 0),
			ZIndex = 12,
			Parent = content,
		})
		Kit.list(actions, 10, true, Enum.HorizontalAlignment.Right)
		if canManage then
			Kit.button({
				Text = "Inviter",
				Variant = "Primary",
				Size = UDim2.fromOffset(120, 44),
				Order = 1,
				ZIndex = 13,
				Parent = actions,
				OnClick = function()
					inviting = not inviting
					render()
				end,
			})
		end
		Kit.button({
			Text = "Quitter",
			Variant = "Danger",
			Size = UDim2.fromOffset(120, 44),
			Order = 2,
			ZIndex = 13,
			Parent = actions,
			OnClick = function()
				State.request("ClanAction", "Leave")
			end,
		})

		-- Membres.
		local membersCard = Kit.surface({
			Color = C.Surface,
			Size = UDim2.new(0.55, -12, 1, -160),
			Position = UDim2.fromOffset(0, 160),
			Radius = Theme.RadiusLarge,
			ZIndex = 12,
			Parent = content,
		})
		Kit.label({
			Text = "Membres",
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.H3,
			Position = UDim2.fromOffset(24, 18),
			Size = UDim2.new(1, -48, 0, 26),
			ZIndex = 13,
			Parent = membersCard,
		})
		local list = Kit.scroll({
			Size = UDim2.new(1, -32, 1, -70),
			Position = UDim2.fromOffset(16, 58),
			ZIndex = 13,
			Parent = membersCard,
		})
		Kit.list(list, 6)
		for index, member in clan.Members do
			local row = Kit.surface({
				Color = C.Surface2,
				Size = UDim2.new(1, -8, 0, 52),
				Order = index,
				ZIndex = 14,
				Parent = list,
			})
			Kit.label({
				Text = member.Name,
				Font = Theme.Fonts.Semibold,
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(1, -300, 1, 0),
				ZIndex = 15,
				Parent = row,
			})
			Kit.label({
				Text = member.Role,
				Font = Theme.Fonts.Bold,
				TextSize = Theme.Text.Small,
				Color = if member.Role == "Chef"
					then C.Accent
					elseif member.Role == "Officier" then C.Info
					else C.TextMuted,
				Position = UDim2.new(1, -280, 0, 0),
				Size = UDim2.fromOffset(90, 52),
				ZIndex = 15,
				Parent = row,
			})
			if member.UserId ~= LocalPlayer.UserId and member.Role ~= "Chef" and canManage then
				if myRole == "Chef" then
					Kit.button({
						Text = if member.Role == "Officier" then "Rétrograder" else "Promouvoir",
						Variant = "Ghost",
						TextSize = Theme.Text.Small,
						Size = UDim2.fromOffset(104, 34),
						Position = UDim2.new(1, -96, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						ZIndex = 15,
						Parent = row,
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
						Text = "Exclure",
						Variant = "Danger",
						TextSize = Theme.Text.Small,
						Size = UDim2.fromOffset(80, 34),
						Position = UDim2.new(1, -9, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						ZIndex = 15,
						Parent = row,
						OnClick = function()
							State.request("ClanAction", "Kick", member.UserId)
						end,
					})
				end
			end
		end

		-- Personnalisation ou invitations.
		local side = Kit.surface({
			Color = C.Surface,
			Size = UDim2.new(0.45, -12, 1, -160),
			Position = UDim2.new(1, 0, 0, 160),
			AnchorPoint = Vector2.new(1, 0),
			Radius = Theme.RadiusLarge,
			ZIndex = 12,
			Parent = content,
		})
		local inner = Kit.box({
			Size = UDim2.new(1, -48, 1, -40),
			Position = UDim2.fromOffset(24, 20),
			ZIndex = 13,
			Parent = side,
		})
		if inviting then
			Kit.label({
				Text = "Inviter un joueur du serveur",
				Font = Theme.Fonts.Bold,
				TextSize = Theme.Text.H3,
				Size = UDim2.new(1, 0, 0, 26),
				ZIndex = 14,
				Parent = inner,
			})
			local invites = Kit.scroll({
				Size = UDim2.new(1, 0, 1, -40),
				Position = UDim2.fromOffset(0, 40),
				ZIndex = 14,
				Parent = inner,
			})
			Kit.list(invites, 6)
			local count = 0
			for _, other in Players:GetPlayers() do
				if other ~= LocalPlayer and (other:GetAttribute("ClanId") or "") == "" then
					count += 1
					local row = Kit.surface({
						Color = C.Surface2,
						Size = UDim2.new(1, -8, 0, 52),
						Order = count,
						ZIndex = 15,
						Parent = invites,
					})
					Kit.label({
						Text = other.DisplayName,
						Font = Theme.Fonts.Semibold,
						Position = UDim2.fromOffset(16, 0),
						Size = UDim2.new(1, -130, 1, 0),
						ZIndex = 16,
						Parent = row,
					})
					Kit.button({
						Text = "Inviter",
						Variant = "Primary",
						TextSize = Theme.Text.Small,
						Size = UDim2.fromOffset(90, 34),
						Position = UDim2.new(1, -9, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						ZIndex = 16,
						Parent = row,
						OnClick = function()
							if State.request("ClanAction", "Invite", other.UserId) then
								State.Notify:Fire(`Invitation envoyée à {other.DisplayName}`, "Success")
							end
						end,
					})
				end
			end
			if count == 0 then
				Kit.label({
					Text = "Aucun joueur sans clan sur ce serveur.",
					Color = C.TextMuted,
					TextSize = Theme.Text.Small,
					Size = UDim2.new(1, 0, 0, 30),
					ZIndex = 15,
					Parent = invites,
				})
			end
		elseif canManage then
			Kit.label({
				Text = "Personnalisation",
				Font = Theme.Fonts.Bold,
				TextSize = Theme.Text.H3,
				Size = UDim2.new(1, 0, 0, 26),
				ZIndex = 14,
				Parent = inner,
			})
			Kit.label({
				Text = "EMBLÈME",
				Font = Theme.Fonts.Bold,
				TextSize = Theme.Text.Tiny,
				Color = C.TextFaint,
				Position = UDim2.fromOffset(0, 40),
				Size = UDim2.new(1, 0, 0, 16),
				ZIndex = 14,
				Parent = inner,
			})
			local emblems = Kit.box({
				Size = UDim2.new(1, 0, 0, 80),
				Position = UDim2.fromOffset(0, 60),
				ZIndex = 14,
				Parent = inner,
			})
			Kit.grid(emblems, Vector2.new(36, 36), 6)
			for index, emblem in ClanStyle.Emblems do
				local button = Kit.new("TextButton", {
					AutoButtonColor = false,
					Text = emblem.Glyph,
					FontFace = Theme.Fonts.Display,
					TextSize = 18,
					TextColor3 = if clan.Emblem == emblem.Id then C.Background else C.Text,
					BackgroundColor3 = if clan.Emblem == emblem.Id then C.Text else C.Surface2,
					LayoutOrder = index,
					ZIndex = 15,
					Parent = emblems,
				})
				Kit.corner(button, 6)
				button.Activated:Connect(function()
					State.request("ClanAction", "Customize", "Emblem", emblem.Id)
				end)
			end
			swatches(inner, "COULEUR DE L'EMBLÈME", 150, clan.EmblemColor, function(index)
				State.request("ClanAction", "Customize", "EmblemColor", index)
			end, 14)
			swatches(inner, "COULEUR DE LA BANNIÈRE", 206, clan.BannerColor, function(index)
				State.request("ClanAction", "Customize", "BannerColor", index)
			end, 14)
			swatches(inner, "ACCENT DE TENUE", 262, clan.KitAccent, function(index)
				State.request("ClanAction", "Customize", "KitAccent", index)
			end, 14)
			local patternOptions = {}
			for _, pattern in ClanStyle.Patterns do
				table.insert(patternOptions, { Id = pattern.Id, Label = pattern.Name })
			end
			Kit.label({
				Text = "MOTIF",
				Font = Theme.Fonts.Bold,
				TextSize = Theme.Text.Tiny,
				Color = C.TextFaint,
				Position = UDim2.fromOffset(0, 318),
				Size = UDim2.new(1, 0, 0, 16),
				ZIndex = 14,
				Parent = inner,
			})
			Kit.segmented({
				Options = patternOptions,
				Value = clan.BannerPattern,
				TextSize = Theme.Text.Tiny,
				Size = UDim2.new(1, 0, 0, 40),
				Position = UDim2.fromOffset(0, 338),
				ZIndex = 14,
				Parent = inner,
				OnChange = function(value: string)
					State.request("ClanAction", "Customize", "BannerPattern", value)
				end,
			})
		else
			Kit.label({
				Text = "Le chef et les officiers personnalisent le blason et l'accent de tenue du clan.",
				Color = C.TextMuted,
				TextSize = Theme.Text.Small,
				Wrap = true,
				Size = UDim2.new(1, 0, 0, 60),
				ZIndex = 14,
				Parent = inner,
			})
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
		render()
	end
	State.ClanChanged:Connect(function()
		if page.IsOpen() then
			render()
		end
	end)
	local baseOpen = page.Open
	page.Open = function()
		inviting = false
		render()
		task.spawn(fetch)
		baseOpen()
	end
	return page
end

return ClanScreen
