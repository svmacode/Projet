--!strict
-- TUTORIEL (facultatif) : règles et commandes, étape par étape.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tutorial = require(ReplicatedStorage.Shared.Data.Tutorial)
local Kit = require(script.Parent.Parent.UI.Kit)
local Page = require(script.Parent.Parent.UI.Page)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Colors

local TutorialScreen = {}

function TutorialScreen.create(parent: Instance, onClose: () -> ()): Page.Page
	local accent = Theme.Section.Tutorial
	local page = Page.modal(parent, "Tutoriel", Vector2.new(880, 600), onClose, accent)
	local content = page.Content
	local index = 1

	local body = Kit.box({ Size = UDim2.new(1, 0, 1, -72), ZIndex = 33, Parent = content })
	local footer =
		Kit.box({ Size = UDim2.new(1, 0, 0, 48), Position = UDim2.new(0, 0, 1, -48), ZIndex = 33, Parent = content })
	local steps = Kit.box({
		Size = UDim2.fromOffset(460, 14),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 34,
		Parent = footer,
	})
	Kit.list(steps, 6, true)
	local previous: Kit.Button
	local nextButton: Kit.Button

	local function render()
		Kit.clear(body)
		Kit.clear(steps)
		local step = Tutorial[index]
		-- Gros numéro d'étape incliné.
		local number = Kit.plate({
			Color = accent,
			Size = UDim2.fromOffset(92, 92),
			Position = UDim2.fromOffset(6, 6),
			Rotation = -6,
			Shadow = false,
			ZIndex = 34,
			Parent = body,
		})
		Kit.label({
			Text = string.format("%02d", index),
			Font = Theme.Fonts.Number,
			TextSize = 58,
			Color = Theme.onColor(accent),
			AlignX = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 35,
			Parent = number,
		})
		Kit.slam(number, 1.6)
		Kit.label({
			Text = `ÉTAPE {index} SUR {#Tutorial}`,
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.Small,
			Color = accent,
			Size = UDim2.new(1, -130, 0, 18),
			Position = UDim2.fromOffset(124, 6),
			ZIndex = 34,
			Parent = body,
		})
		local heading = Kit.title({
			Text = string.upper(step.Title),
			TextSize = 46,
			ShadowColor = accent,
			Size = UDim2.new(1, -130, 0, 54),
			Position = UDim2.fromOffset(124, 28),
			Rotation = -1,
			ZIndex = 34,
			Parent = body,
		})
		heading.Label.TextScaled = true
		heading.Shadow.TextScaled = true
		Kit.reveal(heading.Instance, 0.05)
		Kit.label({
			Text = step.Body,
			Font = Theme.Fonts.Semibold,
			TextSize = Theme.Text.H3,
			Color = C.TextMuted,
			Wrap = true,
			AlignY = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 90),
			Position = UDim2.fromOffset(0, 112),
			ZIndex = 34,
			Parent = body,
		})
		local keys =
			Kit.box({ Size = UDim2.new(1, 0, 0, 200), Position = UDim2.fromOffset(0, 206), ZIndex = 34, Parent = body })
		Kit.list(keys, 8)
		for order, key in step.Keys do
			local parts = string.split(key, " : ")
			local row = Kit.surface({
				Color = C.Surface2,
				Size = UDim2.new(1, -6, 0, 40),
				Order = order,
				ZIndex = 35,
				Parent = keys,
			})
			-- Touche façon capuchon de clavier.
			local keycap = Kit.new("Frame", {
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				Size = UDim2.new(0.4, 0, 1, -10),
				Position = UDim2.fromOffset(6, 5),
				ZIndex = 36,
				Parent = row,
			})
			Kit.corner(keycap, 4)
			Kit.border(keycap, C.Ink, 2)
			Kit.shade(keycap, 0.2)
			Kit.label({
				Text = string.upper(parts[1]),
				Font = Theme.Fonts.Display,
				Color = Theme.onColor(accent),
				AlignX = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 37,
				Parent = keycap,
			})
			Kit.label({
				Text = parts[2] or "",
				Font = Theme.Fonts.Semibold,
				Color = C.Text,
				Position = UDim2.new(0.45, 0, 0, 0),
				Size = UDim2.new(0.55, -16, 1, 0),
				ZIndex = 36,
				Parent = row,
			})
		end
		for i = 1, #Tutorial do
			local bar = Kit.new("Frame", {
				BackgroundColor3 = if i <= index then accent else C.Surface3,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(if i == index then 52 else 30, 10),
				Rotation = Theme.Tilt,
				LayoutOrder = i,
				ZIndex = 35,
				Parent = steps,
			})
			Kit.border(bar, C.Ink, 2)
		end
		previous.SetEnabled(index > 1)
		nextButton.SetText(if index == #Tutorial then "TERMINER" else "SUIVANT")
	end

	previous = Kit.button({
		Text = "PRÉCÉDENT",
		Variant = "Ghost",
		Font = Theme.Fonts.Display,
		Size = UDim2.fromOffset(140, 48),
		Position = UDim2.new(1, -164, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 34,
		Parent = footer,
		OnClick = function()
			index = math.max(1, index - 1)
			render()
		end,
	})
	nextButton = Kit.button({
		Text = "SUIVANT",
		Variant = "Primary",
		Color = accent,
		Font = Theme.Fonts.Display,
		Size = UDim2.fromOffset(150, 48),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		ZIndex = 34,
		Parent = footer,
		OnClick = function()
			if index == #Tutorial then
				State.request("ProfileAction", "CompleteTutorial")
				index = 1
				render()
				onClose()
				return
			end
			index += 1
			render()
		end,
	})
	render()
	return page
end

return TutorialScreen
