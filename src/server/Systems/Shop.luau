--!strict
-- Boutique : Balles (archétypes), Packs Cosmétiques, achats Robux.
-- Prix, taux et tirages sont calculés UNIQUEMENT ici, côté serveur.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Archetypes = require(ReplicatedStorage.Shared.Data.Archetypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Packs = require(ReplicatedStorage.Shared.Data.Packs)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Types = require(ReplicatedStorage.Shared.Types)
local Guard = require(script.Parent.Parent.Lib.Guard)
local PlayerData = require(script.Parent.PlayerData)
local Remote = require(script.Parent.Parent.Lib.Remote)

type Profile = Types.Profile

export type ProductHandler = {
	Grant: (Profile, Player) -> (),
	After: ((Player) -> ())?,
}

local Shop = {}

local rng = Random.new()
local productHandlers: { [number]: ProductHandler } = {}

-- Permet à d'autres systèmes (Clan…) d'ajouter un produit Robux.
function Shop.registerProduct(productKey: string, handler: ProductHandler)
	local productId = (Config.Products :: any)[productKey]
	if typeof(productId) == "number" and productId > 0 then
		productHandlers[productId] = handler
	end
end

function Shop.isProductEnabled(productKey: string): boolean
	local productId = (Config.Products :: any)[productKey]
	return typeof(productId) == "number" and productId > 0
end

function Shop.promptProduct(player: Player, productKey: string): boolean
	local productId = (Config.Products :: any)[productKey]
	if typeof(productId) ~= "number" or productId <= 0 then
		return false
	end
	MarketplaceService:PromptProductPurchase(player, productId)
	return true
end

-- Tirages ---------------------------------------------------------------------------

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function openBall(profile: Profile, ballId: string): (boolean, any)
	local pack = Packs.getBall(ballId)
	if not pack then
		return false, "Balle inconnue."
	end
	if (profile.Balls[ballId] or 0) < 1 then
		return false, "Tu n'as pas cette balle."
	end
	profile.Balls[ballId] -= 1
	profile.Pity += 1

	local rarity = Packs.rollRarity(pack.Odds, rng:NextNumber())
	local info = Rarities.Info[rarity]
	local pityTriggered = false
	if info.Rank < Rarities.Info.Legendaire.Rank and profile.Pity >= Packs.PityThreshold then
		-- Garantie : Légendaire, avec une petite chance de Mythique.
		rarity = if rng:NextNumber() < 0.2 then "Mythique" else "Legendaire"
		pityTriggered = true
	end
	if Rarities.Info[rarity].Rank >= Rarities.Info.Legendaire.Rank then
		profile.Pity = 0
	end

	local archetype = pick(Archetypes.byRarity(rarity))
	local duplicate = profile.Archetypes[archetype.Id] == true
	local refund = 0
	if duplicate then
		refund = Rarities.Info[rarity].DuplicateRefund
		profile.Coins += refund
	else
		profile.Archetypes[archetype.Id] = true
	end
	return true,
		{
			Kind = "Archetype",
			Id = archetype.Id,
			Rarity = rarity,
			Duplicate = duplicate,
			Refund = refund,
			Pity = pityTriggered,
		}
end

local function openCosmetic(profile: Profile): (boolean, any)
	if profile.CosmeticPacks < 1 then
		return false, "Tu n'as pas de Pack Cosmétique."
	end
	profile.CosmeticPacks -= 1
	local rarity = Packs.rollRarity(Packs.Cosmetic.Odds, rng:NextNumber())
	local item = pick(Cosmetics.byRarity(rarity))
	local duplicate = (profile.Cosmetics[item.Id] or 0) > 0
	local refund = 0
	if duplicate then
		refund = math.floor(Rarities.Info[rarity].DuplicateRefund / 2)
		profile.Coins += refund
	else
		profile.Cosmetics[item.Id] = 1
	end
	return true, { Kind = "Cosmetic", Id = item.Id, Rarity = rarity, Duplicate = duplicate, Refund = refund }
end

-- Actions ------------------------------------------------------------------------------

local ACTIONS: { [string]: (Player, any, any) -> Remote.Result } = {}

ACTIONS.BuyBall = function(player, ballIdArg, quantityArg)
	local ballId = Guard.string(ballIdArg, 32)
	local quantity = Guard.integer(quantityArg, 1, 10)
	local pack = ballId and Packs.getBall(ballId)
	if not ballId or not pack or not quantity then
		return Remote.fail("Requête invalide.")
	end
	local cost = pack.Price * quantity
	local bought = false
	PlayerData.update(player, function(profile)
		if profile.Coins >= cost then
			profile.Coins -= cost
			profile.Balls[ballId] = (profile.Balls[ballId] or 0) + quantity
			bought = true
		end
	end)
	if not bought then
		return Remote.fail("Pas assez de Hand Coins.")
	end
	return Remote.ok()
end

ACTIONS.OpenBall = function(player, ballIdArg)
	local ballId = Guard.string(ballIdArg, 32)
	if not ballId then
		return Remote.fail("Requête invalide.")
	end
	local ok, result = false, "Profil indisponible." :: any
	PlayerData.update(player, function(profile)
		ok, result = openBall(profile, ballId)
	end)
	if not ok then
		return Remote.fail(result)
	end
	return Remote.ok({ Result = result })
end

ACTIONS.BuyCosmeticPack = function(player, quantityArg)
	local quantity = Guard.integer(quantityArg, 1, 10)
	if not quantity then
		return Remote.fail("Requête invalide.")
	end
	local cost = Packs.Cosmetic.Price * quantity
	local bought = false
	PlayerData.update(player, function(profile)
		if profile.Coins >= cost then
			profile.Coins -= cost
			profile.CosmeticPacks += quantity
			bought = true
		end
	end)
	if not bought then
		return Remote.fail("Pas assez de Hand Coins.")
	end
	return Remote.ok()
end

ACTIONS.OpenCosmeticPack = function(player)
	local ok, result = false, "Profil indisponible." :: any
	PlayerData.update(player, function(profile)
		ok, result = openCosmetic(profile)
	end)
	if not ok then
		return Remote.fail(result)
	end
	return Remote.ok({ Result = result })
end

local PURCHASABLE = { "CosmeticPack", "CosmeticPack5", "Coins1000", "Coins5000" }

ACTIONS.BuyProduct = function(player, productKeyArg)
	local productKey = Guard.oneOf(productKeyArg, PURCHASABLE)
	if not productKey then
		return Remote.fail("Produit inconnu.")
	end
	if not Shop.promptProduct(player, productKey) then
		return Remote.fail("Bientôt disponible !")
	end
	return Remote.ok()
end

ACTIONS.Catalog = function()
	local enabled = {}
	for key in Config.Products :: any do
		enabled[key] = Shop.isProductEnabled(key)
	end
	return Remote.ok({ Products = enabled })
end

-- Achats Robux -----------------------------------------------------------------------

local function processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = PlayerData.waitFor(player, 15)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(receiptInfo.PurchaseId)
	if PlayerData.hasReceipt(player, receiptId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local handler = productHandlers[receiptInfo.ProductId]
	if not handler then
		warn(`[Shop] produit sans handler : {receiptInfo.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	PlayerData.update(player, function(p)
		handler.Grant(p, player)
		PlayerData.recordReceipt(p, receiptId)
	end)
	if PlayerData.isPersistent(player) and not PlayerData.save(player, false) then
		-- Le reçu est noté en mémoire : la prochaine tentative le validera
		-- sans redonner l'objet.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local after = handler.After
	if after then
		task.spawn(after, player)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Shop.init()
	Shop.registerProduct("CosmeticPack", {
		Grant = function(profile)
			profile.CosmeticPacks += 1
		end,
		After = function(player)
			Remote.notify(player, "Pack Cosmétique ajouté ! Merci pour ton soutien.", "Gold")
		end,
	})
	Shop.registerProduct("CosmeticPack5", {
		Grant = function(profile)
			profile.CosmeticPacks += 5
		end,
		After = function(player)
			Remote.notify(player, "5 Packs Cosmétiques ajoutés ! Merci pour ton soutien.", "Gold")
		end,
	})
	Shop.registerProduct("Coins1000", {
		Grant = function(profile)
			profile.Coins += 1000
		end,
	})
	Shop.registerProduct("Coins5000", {
		Grant = function(profile)
			profile.Coins += 5500
		end,
	})

	Remote.onInvoke("ShopAction", 6, 10, function(player, action, a, b)
		local handler = if typeof(action) == "string" then ACTIONS[action] else nil
		if not handler then
			return Remote.fail("Action inconnue.")
		end
		if not PlayerData.get(player) then
			return Remote.fail("Profil en cours de chargement…")
		end
		return handler(player, a, b)
	end)
end

function Shop.start()
	MarketplaceService.ProcessReceipt = processReceipt
end

return Shop
