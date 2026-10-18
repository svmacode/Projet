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

local function sentenceCase(text: string): string
	local lower = string.lower(text)
	return string.upper(string.sub(lower, 1, 1)) .. string.sub(lower, 2)
end

function TutorialScreen.create(parent: Instance, onClose: () -> ()): Page.Page
	local page = Page.modal(parent, "Tutoriel", Vector2.new(880, 600), onClose)
	local content = page.Content
	local index = 1

	local body = Kit.box({ Size = UDim2.new(1, 0, 1, -72), ZIndex = 33, Parent = content })
	local footer =
		Kit.box({ Size = UDim2.new(1, 0, 0, 48), Position = UDim2.new(0, 0, 1, -48), ZIndex = 33, Parent = content })
	local steps = Kit.box({
		Size = UDim2.fromOffset(400, 6),
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
		Kit.label({
			Text = `ÉTAPE {index} SUR {#Tutorial}`,
			Font = Theme.Fonts.Bold,
			TextSize = Theme.Text.Tiny,
			Color = C.Accent,
			Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 34,
			Parent = body,
		})
		Kit.label({
			Text = sentenceCase(step.Title),
			Font = Theme.Fonts.Display,
			TextSize = Theme.Text.H1,
			Size = UDim2.new(1, 0, 0, 44),
			Position = UDim2.fromOffset(0, 22),
			ZIndex = 34,
			Parent = body,
		})
		Kit.label({
			Text = step.Body,
			TextSize = Theme.Text.H3,
			Color = C.TextMuted,
			Wrap = true,
			AlignY = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 110),
			Position = UDim2.fromOffset(0, 80),
			ZIndex = 34,
			Parent = body,
		})
		local keys =
			Kit.box({ Size = UDim2.new(1, 0, 0, 200), Position = UDim2.fromOffset(0, 200), ZIndex = 34, Parent = body })
		Kit.list(keys, 8)
		for order, key in step.Keys do
			local parts = string.split(key, " : ")
			local row = Kit.surface({
				Color = C.Surface2,
				Size = UDim2.new(1, 0, 0, 40),
				Order = order,
				ZIndex = 35,
				Parent = keys,
			})
			Kit.label({
				Text = parts[1],
				Font = Theme.Fonts.Bold,
				Position = UDim2.fromOffset(16, 0),
				Size = UDim2.new(0.45, 0, 1, 0),
				ZIndex = 36,
				Parent = row,
			})
			Kit.label({
				Text = parts[2] or "",
				Color = C.TextMuted,
				Position = UDim2.new(0.45, 0, 0, 0),
				Size = UDim2.new(0.55, -16, 1, 0),
				ZIndex = 36,
				Parent = row,
			})
		end
		for i = 1, #Tutorial do
			local bar = Kit.new("Frame", {
				BackgroundColor3 = if i <= index then C.Accent else C.Surface3,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(36, 6),
				LayoutOrder = i,
				ZIndex = 35,
				Parent = steps,
			})
			Kit.corner(bar, 3)
		end
		previous.SetEnabled(index > 1)
		nextButton.SetText(if index == #Tutorial then "Terminer" else "Suivant")
	end

	previous = Kit.button({
		Text = "Précédent",
		Variant = "Ghost",
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
		Text = "Suivant",
		Variant = "Primary",
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
