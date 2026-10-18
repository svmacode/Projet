--!strict
-- Écran CLAN : création (1000 R$), bannière personnalisable (emblème,
-- couleurs, motif), accent de tenue, membres et rôles, invitations.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClanStyle = require(ReplicatedStorage.Shared.Data.ClanStyle)
local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(script.Parent.Parent.UI.Kit)
local ScreenFrame = require(script.Parent.Parent.UI.ScreenFrame)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local ClanScreen = {}

local ROLE_COLORS = { Chef = C.Yellow, Officier = C.Blue, Membre = C.PaperDark }

-- Bannière dessinée (réutilisée dans le profil).
function ClanScreen.banner(parent: Instance, clan: any, size: UDim2, z: number): Frame
	local color = ClanStyle.color(clan.BannerColor)
	local face, container = Kit.panel({
		Size = size,
		Color = color,
		ZIndex = z,
		Clip = true,
		Parent = parent,
	})
	local accent = ClanStyle.color(clan.EmblemColor)
	local pattern = clan.BannerPattern
	if pattern == "Bande" then
		Kit.new("Frame", {
			BackgroundColor3 = accent,
			Size = UDim2.new(1, 0, 0.22, 0),
			Position = UDim2.fromScale(0, 0.39),
			ZIndex = z + 1,
			Parent = face,
		})
	elseif pattern == "Diagonale" then
		Kit.new("Frame", {
			BackgroundColor3 = accent,
			Size = UDim2.new(1.6, 0, 0.25, 0),
			Position = UDim2.fromScale(-0.3, 0.4),
			Rotation = -25,
			ZIndex = z + 1,
			Parent = face,
		})
	elseif pattern == "Soleil" then
		local rays = Kit.sunburst(face, color, accent, 10, false)
		rays.ZIndex = z + 1
		for _, child in rays:GetDescendants() do
			if child:IsA("GuiObject") then
				child.ZIndex = z + 1
			end
		end
	elseif pattern == "Chevron" then
		for _, rotation in { 35, -35 } do
			Kit.new("Frame", {
				BackgroundColor3 = accent,
				Size = UDim2.new(0.7, 0, 0.16, 0),
				Position = UDim2.fromScale(if rotation > 0 then 0.02 else 0.33, 0.55),
				Rotation = rotation,
				ZIndex = z + 1,
				Parent = face,
			})
		end
	end
	local emblem = ClanStyle.emblem(clan.Emblem)
	local disc = Kit.new("Frame", {
		BackgroundColor3 = C.Paper,
		Size = UDim2.fromScale(0.3, 0.3),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = z + 2,
		Parent = face,
	})
	disc.Size = UDim2.fromScale(0.7, 0.7)
	Kit.corner(disc, 400)
	Kit.stroke(disc, 4)
	Kit.text({
		Text = emblem.Glyph,
		Font = Theme.Fonts.Heavy,
		Color = accent,
		Stroke = C.Ink,
		StrokeThickness = 2,
		ZIndex = z + 3,
		Parent = disc,
	})
	return container
end

local function swatchRow(
	parent: Instance,
	label: string,
	position: UDim2,
	selected: number,
	onPick: (number) -> (),
	z: number
)
	Kit.text({
		Text = label,
		Size = UDim2.fromOffset(160, 30),
		Position = position,
		AlignX = Enum.TextXAlignment.Left,
		ZIndex = z,
		Parent = parent,
	})
	for index, color in ClanStyle.Palette do
		local swatch = Kit.new("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = color,
			Text = "",
			Size = UDim2.fromOffset(30, 30),
			Position = position + UDim2.fromOffset(160 + (index - 1) * 36, 0),
			ZIndex = z,
			Parent = parent,
		})
		Kit.stroke(swatch, if index == selected then 5 else 2, if index == selected then C.Yellow else C.Ink)
		swatch.Activated:Connect(function()
			onPick(index)
		end)
	end
end

function ClanScreen.create(parent: Instance, close: () -> ()): ScreenFrame.Screen
	local screen = ScreenFrame.new(parent, "CLAN", "クラン", C.Green, close)
	local content = screen.Content
	local meta = { Credits = 0, ProductEnabled = false, Price = Config.ProductRobuxPrice.ClanCreation }
	local showInvite = false

	local function render()
		Kit.clear(content)
		local clan = State.Clan
		if not clan then
			-- Création ----------------------------------------------------------------------------
			Kit.sunburst(content, C.Paper, C.PaperDark, 14, false).ZIndex = 21
			Kit.text({
				Text = "FONDE TON CLAN",
				Color = C.Green,
				Stroke = C.Ink,
				StrokeThickness = 4,
				Size = UDim2.new(1, 0, 0, 80),
				Position = UDim2.fromOffset(0, 10),
				ZIndex = 23,
				Parent = content,
			})
			Kit.text({
				Text = `Invite jusqu'à {Config.Clan.MaxMembers} membres, crée ton emblème, ta bannière et l'accent de tenue de ton équipe.`,
				Font = Theme.Fonts.Body,
				Size = UDim2.new(0.8, 0, 0, 50),
				Position = UDim2.new(0.1, 0, 0, 96),
				ZIndex = 23,
				Parent = content,
			})
			local nameBox = Kit.new("TextBox", {
				PlaceholderText = "Nom du clan (3 à 20 caractères)",
				Text = "",
				Font = Theme.Fonts.Body,
				TextScaled = true,
				TextColor3 = C.Ink,
				PlaceholderColor3 = C.Steel,
				BackgroundColor3 = C.White,
				Size = UDim2.fromOffset(520, 56),
				Position = UDim2.new(0.5, 0, 0, 190),
				AnchorPoint = Vector2.new(0.5, 0),
				ClearTextOnFocus = false,
				ZIndex = 24,
				Parent = content,
			})
			Kit.stroke(nameBox, 4)
			Kit.padding(nameBox, 8)
			local tagBox = Kit.new("TextBox", {
				PlaceholderText = "TAG (2 à 4)",
				Text = "",
				Font = Theme.Fonts.Title,
				TextScaled = true,
				TextColor3 = C.Ink,
				PlaceholderColor3 = C.Steel,
				BackgroundColor3 = C.White,
				Size = UDim2.fromOffset(240, 56),
				Position = UDim2.new(0.5, 0, 0, 266),
				AnchorPoint = Vector2.new(0.5, 0),
				ClearTextOnFocus = false,
				ZIndex = 24,
				Parent = content,
			})
			Kit.stroke(tagBox, 4)
			Kit.padding(tagBox, 8)
			local label = if meta.Credits > 0
				then "CRÉER (CRÉDIT DISPONIBLE)"
				elseif meta.ProductEnabled then `CRÉER · {meta.Price} R$`
				else "BIENTÔT DISPONIBLE"
			local create = Kit.button({
				Text = label,
				Color = C.Green,
				Size = UDim2.fromOffset(460, 80),
				Position = UDim2.new(0.5, 0, 0, 370),
				AnchorPoint = Vector2.new(0.5, 0),
				Rotation = -2,
				ShadowOffset = 8,
				ZIndex = 24,
				Parent = content,
				OnClick = function()
					local ok, result = State.request("ClanAction", "Create", nameBox.Text, tagBox.Text)
					if ok and result and result.Pending then
						State.Notify:Fire("Valide l'achat pour fonder ton clan !", "Gold")
					end
				end,
			})
			create.SetEnabled(meta.Credits > 0 or meta.ProductEnabled)
			return
		end

		-- Clan existant -----------------------------------------------------------------------------
		local me = Players.LocalPlayer.UserId
		local myRole = "Membre"
		for _, member in clan.Members do
			if member.UserId == me then
				myRole = member.Role
			end
		end
		local canManage = myRole == "Chef" or myRole == "Officier"

		ClanScreen.banner(content, clan, UDim2.fromOffset(300, 180), 23)
		Kit.text({
			Text = `[{clan.Tag}] {string.upper(clan.Name)}`,
			Size = UDim2.new(1, -340, 0, 60),
			Position = UDim2.fromOffset(330, 0),
			AlignX = Enum.TextXAlignment.Left,
			ZIndex = 23,
			Parent = content,
		})
		Kit.text({
			Text = `{#clan.Members}/{clan.MaxMembers} membres  ·  {clan.Wins} victoires  ·  ton rôle : {myRole}`,
			Font = Theme.Fonts.Body,
			Size = UDim2.new(1, -340, 0, 30),
			Position = UDim2.fromOffset(330, 62),
			AlignX = Enum.TextXAlignment.Left,
			ZIndex = 23,
			Parent = content,
		})

		-- Membres.
		local members =
			Kit.scroll(content, { Size = UDim2.fromOffset(480, 360), Position = UDim2.fromOffset(0, 210), ZIndex = 23 })
		Kit.list(members, 8)
		Kit.padding(members, 4)
		for index, member in clan.Members do
			local face, _ = Kit.panel({
				Size = UDim2.new(1, -14, 0, 54),
				Color = C.Paper,
				Order = index,
				ZIndex = 24,
				Parent = members,
			})
			local roleChip = Kit.new("Frame", {
				BackgroundColor3 = ROLE_COLORS[member.Role] or C.PaperDark,
				Size = UDim2.fromOffset(110, 34),
				Position = UDim2.fromOffset(10, 10),
				ZIndex = 25,
				Parent = face,
			})
			Kit.stroke(roleChip, 2)
			Kit.text({ Text = string.upper(member.Role), ZIndex = 26, Parent = roleChip })
			Kit.text({
				Text = member.Name,
				Font = Theme.Fonts.Body,
				Size = UDim2.new(1, -260, 1, -10),
				Position = UDim2.fromOffset(130, 5),
				AlignX = Enum.TextXAlignment.Left,
				ZIndex = 25,
				Parent = face,
			})
			if member.UserId ~= me and canManage and member.Role ~= "Chef" then
				Kit.button({
					Text = "EXCLURE",
					Color = C.Red,
					TextColor = C.Paper,
					Size = UDim2.fromOffset(100, 36),
					Position = UDim2.new(1, -110, 0, 9),
					ZIndex = 26,
					Parent = face,
					OnClick = function()
						State.request("ClanAction", "Kick", member.UserId)
					end,
				})
				if myRole == "Chef" then
					Kit.button({
						Text = if member.Role == "Officier" then "▼" else "▲",
						Color = C.Blue,
						TextColor = C.Paper,
						Size = UDim2.fromOffset(40, 36),
						Position = UDim2.new(1, -160, 0, 9),
						ZIndex = 26,
						Parent = face,
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
			end
		end

		-- Personnalisation (chef et officiers).
		local custom = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -510, 0, 360),
			Position = UDim2.fromOffset(510, 110),
			ZIndex = 23,
			Parent = content,
		})
		if canManage then
			Kit.text({
				Text = "EMBLÈME",
				Size = UDim2.fromOffset(160, 30),
				AlignX = Enum.TextXAlignment.Left,
				ZIndex = 24,
				Parent = custom,
			})
			for index, emblem in ClanStyle.Emblems do
				local button = Kit.new("TextButton", {
					AutoButtonColor = false,
					BackgroundColor3 = if clan.Emblem == emblem.Id then C.Yellow else C.Paper,
					Text = emblem.Glyph,
					Font = Theme.Fonts.Heavy,
					TextScaled = true,
					TextColor3 = C.Ink,
					Size = UDim2.fromOffset(40, 40),
					Position = UDim2.fromOffset(160 + ((index - 1) % 6) * 46, if index > 6 then 46 else 0),
					ZIndex = 24,
					Parent = custom,
				})
				Kit.stroke(button, 3)
				button.Activated:Connect(function()
					State.request("ClanAction", "Customize", "Emblem", emblem.Id)
				end)
			end
			swatchRow(custom, "COULEUR EMBLÈME", UDim2.fromOffset(0, 100), clan.EmblemColor, function(index)
				State.request("ClanAction", "Customize", "EmblemColor", index)
			end, 24)
			swatchRow(custom, "COULEUR BANNIÈRE", UDim2.fromOffset(0, 142), clan.BannerColor, function(index)
				State.request("ClanAction", "Customize", "BannerColor", index)
			end, 24)
			swatchRow(custom, "ACCENT TENUE", UDim2.fromOffset(0, 184), clan.KitAccent, function(index)
				State.request("ClanAction", "Customize", "KitAccent", index)
			end, 24)
			Kit.text({
				Text = "MOTIF",
				Size = UDim2.fromOffset(160, 30),
				Position = UDim2.fromOffset(0, 230),
				AlignX = Enum.TextXAlignment.Left,
				ZIndex = 24,
				Parent = custom,
			})
			for index, pattern in ClanStyle.Patterns do
				Kit.button({
					Text = string.upper(pattern.Name),
					Color = if clan.BannerPattern == pattern.Id then C.Yellow else C.Paper,
					Size = UDim2.fromOffset(110, 36),
					Position = UDim2.fromOffset(160 + ((index - 1) % 3) * 118, 226 + math.floor((index - 1) / 3) * 44),
					ZIndex = 24,
					Parent = custom,
					OnClick = function()
						State.request("ClanAction", "Customize", "BannerPattern", pattern.Id)
					end,
				})
			end
		else
			Kit.text({
				Text = "Le chef et les officiers personnalisent l'emblème, la bannière et l'accent de tenue du clan.",
				Font = Theme.Fonts.Body,
				Size = UDim2.new(1, 0, 0, 80),
				AlignX = Enum.TextXAlignment.Left,
				ZIndex = 24,
				Parent = custom,
			})
		end

		-- Actions.
		local actions = Kit.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 60),
			Position = UDim2.new(0, 0, 1, -60),
			ZIndex = 23,
			Parent = content,
		})
		Kit.list(actions, 16, true)
		if canManage then
			Kit.button({
				Text = "INVITER",
				Color = C.Green,
				Size = UDim2.fromOffset(200, 54),
				Order = 1,
				ZIndex = 24,
				Parent = actions,
				OnClick = function()
					showInvite = not showInvite
					render()
				end,
			})
		end
		Kit.button({
			Text = "QUITTER LE CLAN",
			Color = C.Red,
			TextColor = C.Paper,
			Size = UDim2.fromOffset(260, 54),
			Order = 2,
			ZIndex = 24,
			Parent = actions,
			OnClick = function()
				State.request("ClanAction", "Leave")
			end,
		})

		if showInvite then
			local face, _ = Kit.panel({
				Size = UDim2.fromOffset(380, 330),
				Position = UDim2.new(1, -390, 0, 120),
				Color = C.Paper,
				ZIndex = 40,
				Parent = content,
			})
			Kit.text({
				Text = "JOUEURS DU SERVEUR",
				Size = UDim2.new(1, -20, 0, 34),
				Position = UDim2.fromOffset(10, 8),
				ZIndex = 41,
				Parent = face,
			})
			local list =
				Kit.scroll(face, { Size = UDim2.new(1, -20, 1, -60), Position = UDim2.fromOffset(10, 50), ZIndex = 41 })
			Kit.list(list, 6)
			local count = 0
			for _, other in Players:GetPlayers() do
				if other ~= Players.LocalPlayer and (other:GetAttribute("ClanId") or "") == "" then
					count += 1
					Kit.button({
						Text = other.DisplayName,
						Color = C.PaperDark,
						Size = UDim2.new(1, -14, 0, 42),
						Order = count,
						ZIndex = 42,
						Parent = list,
						OnClick = function()
							local ok = State.request("ClanAction", "Invite", other.UserId)
							if ok then
								State.Notify:Fire(`Invitation envoyée à {other.DisplayName}`, "Success")
							end
						end,
					})
				end
			end
			if count == 0 then
				Kit.text({
					Text = "Aucun joueur sans clan sur ce serveur.",
					Font = Theme.Fonts.Body,
					Size = UDim2.new(1, 0, 0, 40),
					ZIndex = 42,
					Parent = list,
				})
			end
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
		if screen.Container.Visible then
			render()
		end
	end)
	local open = screen.Open
	screen.Open = function()
		showInvite = false
		task.spawn(fetch)
		render()
		open()
	end
	return screen
end

return ClanScreen
