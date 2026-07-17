
local _CFG_OPT = not getgenv().Config or getgenv().Config.OptimizeGraphics ~= false

if _CFG_OPT then
    pcall(function()
        if setfpscap then setfpscap(getgenv().Config and getgenv().Config.FPSCap or 5) end
    end)

    pcall(function()
        game:GetService("RunService"):Set3dRenderingEnabled(false)
    end)

    pcall(function()
        game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
    end)

    pcall(function()
        local lighting = game:GetService("Lighting")
        lighting.GlobalShadows = false
        lighting.FogStart = 0
        lighting.FogEnd = 0
        lighting:ClearAllChildren()
    end)

    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)

    pcall(function()
        game:GetService("SoundService").Volume = 0
    end)

    pcall(function()
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterDetailLevel = Enum.WaterDetailLevel.Low
        end
    end)
end

local defaults = {
    AntiAFK = true,
    OptimizeGraphics = true,
    Disable3DRendering = true,
    FPSCap = 5,
    AutoUpgrade = true,
    AutoHatch = true,
    AutoRebirth = true,
    ["Rebirth Cap"] = 10,
    ["Level Cap After Rebirth"] = 120,
    AutoFusion = true,
    BossFailureLogic = false,
    AutoEquipEnchants = true,
    Enchants = {"Tap Power", "Tap Power", "Tap Power", "Tap Power", "Lucky Eggs"},
    AutoClaimMail = true,
    AutoSendMail = false,
    MailUser = {},
    MailConfig = {},
    DisablePlayerGui = true,
    DisableOrbsVisuals = true,
    Webhook = {
        ["Webhook URL"] = "",
        ["ID"] = { "" },
        ["Alert Pets"] = true,
    }
}

getgenv().Config = getgenv().Config or {}
for k, v in pairs(defaults) do
    if getgenv().Config[k] == nil then
        if type(v) == "table" then
            getgenv().Config[k] = {}
            for subK, subV in pairs(v) do
                getgenv().Config[k][subK] = subV
            end
        else
            getgenv().Config[k] = v
        end
    end
end

local CFG = getgenv().Config

local mainWorlds = {
    [8737899170] = true,  [16498369169] = true, [17503543197] = true,
    [140403681187145] = true, [15502302041] = true, [16170461708] = true,
    [17473989780] = true,
}

if not mainWorlds[game.PlaceId] then
    pcall(function()
        local net = game:GetService("ReplicatedStorage"):FindFirstChild("Network")
        local travel = net and net:FindFirstChild("Travel to Main World")
        if travel and travel:IsA("RemoteFunction") then travel:InvokeServer() end
    end)
    return
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Network = require(RS.Library.Client.Network)
local Save = require(RS.Library.Client.Save)
local InstancingCmds = require(RS.Library.Client.InstancingCmds)
local PetCmds = require(RS.Library.Client.PetCmds)
local EggCmds = require(RS.Library.Client.EggCmds)
local EventUpgradeCmds = require(RS.Library.Client.EventUpgradeCmds)
local EventUpgrades = require(RS.Library.Directory.EventUpgrades)
local EnchantCmds = require(RS.Library.Client.EnchantCmds)
local Types = require(RS.Library.Items.Types)
local ZoneCmds = require(RS.Library.Client.ZoneCmds)

local _InventoryCmds, _CurrencyItem, _Inventory
pcall(function() _InventoryCmds = require(RS.Library.Client.InventoryCmds) end)
pcall(function() _CurrencyItem = require(RS.Library.Items.CurrencyItem) end)
pcall(function() _Inventory = require(RS.Library.Universal.Inventory) end)

local eventPetIds = {
    ["Caveman Bear"] = true, ["Mammoth Elephant"] = true,
    ["Bastet Cat"] = true, ["Horus Falcon"] = true,
    ["Triumphant Eagle"] = true, ["Legionary Bear"] = true,
    ["Fenrir Wolf"] = true, ["Druid Owl"] = true,
    ["Knight Corgi"] = true, ["Crusader Dragon"] = true,
    ["Steppe Wolf"] = true, ["Samurai Kitsune"] = true,
}

local _state = { Level = 1, IsBoss = false, Kills = 0, MaxKills = 10, Rebirths = 0, TimeLeft = nil }

local _cachedHudText = nil
local _hudCacheTime = 0

pcall(function()
    local VirtualUser = game:GetService("VirtualUser")
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.5)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end)
end)

pcall(function()
    if EggCmds then
        if EggCmds.Play then EggCmds.Play = function() return end end
        if EggCmds.PlayEggHatch then EggCmds.PlayEggHatch = function() return end end
        if EggCmds.PlayHatch then EggCmds.PlayHatch = function() return end end
        if EggCmds.HatchAnimation then EggCmds.HatchAnimation = function() return end end
    end
end)

pcall(function()
    local playerScripts = LocalPlayer:WaitForChild("PlayerScripts", 5)
    if not playerScripts then return end
    local eggScript = playerScripts:FindFirstChild("Scripts")
    eggScript = eggScript and eggScript:FindFirstChild("Game")
    eggScript = eggScript and eggScript:FindFirstChild("Egg Opening Frontend")
    local getsenv = getsenv or get_script_env or getscriptenv
    if eggScript and getsenv then
        local env = getsenv(eggScript)
        if env then
            if env.PlayNormalEggAnimation then env.PlayNormalEggAnimation = function() end end
            if env.PlayEggAnimation then env.PlayEggAnimation = function() end end
        end
    end
end)

pcall(function()
    local LootMessage = require(RS.Library.Client.LootMessage)
    if LootMessage and LootMessage.Create then LootMessage.Create = function() end end
end)

pcall(function()
    local ItemNotice = require(RS.Library.Client.ItemNotice)
    if ItemNotice and ItemNotice.Add then ItemNotice.Add = function() return function() end end end
end)

pcall(function()
    for _, sound in ipairs(game:GetDescendants()) do
        if sound:IsA("Sound") then sound:Stop() end
    end
end)

if _CFG_OPT then

pcall(function()
    local function killChar(char)
        task.defer(function()
            pcall(function()
                if char and char.Parent and char ~= LocalPlayer.Character then
                    char:Destroy()
                end
            end)
        end)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            killChar(player.Character)
        end
        if player ~= LocalPlayer then
            player.CharacterAdded:Connect(killChar)
        end
    end
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(killChar)
    end)
end)

pcall(function()
    local cleanTypes = {
        ParticleEmitter = true, Trail = true, Beam = true, Fire = true,
        Smoke = true, Sparkles = true, Decal = true, Texture = true,
        Shirt = true, Pants = true, ShirtGraphic = true, Accessory = true,
    }
    for _, obj in ipairs(workspace:GetDescendants()) do
        local className = obj.ClassName
        if cleanTypes[className] then
            if className == "Decal" or className == "Texture" then
                pcall(function() obj.Texture = "" end)
            elseif className == "Shirt" or className == "Pants" or className == "ShirtGraphic" or className == "Accessory" then
                pcall(function() obj:Destroy() end)
            else
                pcall(function() obj.Enabled = false end)
            end
        elseif obj:IsA("MeshPart") then
            pcall(function()
                obj.TextureID = ""
                obj.Material = Enum.Material.SmoothPlastic
            end)
        elseif obj:IsA("BasePart") then
            pcall(function()
                obj.Material = Enum.Material.SmoothPlastic
                obj.Reflectance = 0
                obj.CastShadow = false
            end)
        end
    end
end)

pcall(function()
    local _lastCleanBatch = 0
    workspace.DescendantAdded:Connect(function(child)
        local cn = child.ClassName
        if cn == "ParticleEmitter" or cn == "Trail" or cn == "Beam" or cn == "Fire" or cn == "Smoke" or cn == "Sparkles" then
            task.defer(function() pcall(function() child.Enabled = false end) end)
        elseif cn == "Sound" then
            task.defer(function() pcall(function() child:Stop() end) end)
        end
    end)
end)

pcall(function()
    local map = workspace:FindFirstChild("Map")
    if map then
        for _, name in ipairs({"Decorations", "Decoration", "Decor", "Debris"}) do
            local d = map:FindFirstChild(name)
            if d then d:Destroy() end
        end
    end
    local things = workspace:FindFirstChild("__THINGS")
    if things then
        for _, name in ipairs({"Decorations", "Decoration", "Decor", "Debris"}) do
            local d = things:FindFirstChild(name)
            if d then d:Destroy() end
        end
        local orbs = things:FindFirstChild("Orbs")
        if orbs then
            orbs:ClearAllChildren()
            orbs.ChildAdded:Connect(function(o) task.defer(function() pcall(function() o:Destroy() end) end) end)
        end
        local lootbags = things:FindFirstChild("Lootbags")
        if lootbags then
            lootbags:ClearAllChildren()
            lootbags.ChildAdded:Connect(function(o) task.defer(function() pcall(function() o:Destroy() end) end) end)
        end
    end
end)

pcall(function()
    if CFG.DisablePlayerGui ~= false then
        local function cleanGui(gui)
            if not gui:IsA("ScreenGui") or gui.Name == "RobloxGui" then return end
            if gui.Name == "TapperHud" then
                for _, childName in ipairs({"HUD", "Pets"}) do
                    local inner = gui:FindFirstChild(childName)
                    if inner then
                        inner.Visible = false
                        inner:GetPropertyChangedSignal("Visible"):Connect(function()
                            if inner.Visible then inner.Visible = false end
                        end)
                    end
                end
                return
            end
            gui.Enabled = false
            gui:GetPropertyChangedSignal("Enabled"):Connect(function()
                if gui.Enabled then gui.Enabled = false end
            end)
            local name = gui.Name:lower()
            if name:find("freegifts") or name:find("playtime") or name:find("reward") or name:find("daily") or name:find("gift") then
                pcall(function() gui:Destroy() end)
            end
        end
        for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            cleanGui(gui)
        end
        LocalPlayer.PlayerGui.ChildAdded:Connect(function(gui)
            task.defer(function() pcall(cleanGui, gui) end)
        end)
    end
end)

pcall(function()
    local function killAnimator(char)
        if char == LocalPlayer.Character then return end
        task.defer(function()
            pcall(function()
                local hum = char:FindFirstChildOfClass("Humanoid")
                local animator = hum and hum:FindFirstChildOfClass("Animator")
                if animator then animator:Destroy() end
            end)
        end)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then killAnimator(player.Character) end
    end
    Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(killAnimator) end)
end)

end

local function safeGetItemId(item)
    if not item then return nil end
    local ok, id = pcall(function() return item:GetId() end)
    if ok and id then return tostring(id) end
    if item._data then
        if item._data.id then return tostring(item._data.id) end
        if item._data.Id then return tostring(item._data.Id) end
        if item._data.tn then return "Tier " .. tostring(item._data.tn) end
        if item._data.Tier then return "Tier " .. tostring(item._data.Tier) end
    end
    return nil
end

local function getTHState()
    _state.Level = 1
    _state.IsBoss = false
    _state.Kills = 0
    _state.MaxKills = 10
    _state.Rebirths = 0
    _state.TimeLeft = nil

    local now = tick()
    if not _cachedHudText or now - _hudCacheTime > 60 then
        _cachedHudText = nil
        pcall(function()
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            local hud = playerGui and playerGui:FindFirstChild("TapperHud")
            if hud and hud:FindFirstChild("HUD") then
                _cachedHudText = hud.HUD:FindFirstChild("Text")
            end
        end)
        _hudCacheTime = now
    end

    local txt = _cachedHudText
    if not txt then return _state end

    pcall(function()
        local function getLabelText(rowName)
            local row = txt:FindFirstChild(rowName)
            if not row then return "" end
            if row:IsA("TextLabel") then return row.Text end
            local lbl = row:FindFirstChild(rowName)
            if lbl and lbl:IsA("TextLabel") then return lbl.Text end
            local childLabel = row:FindFirstChildOfClass("TextLabel")
            return childLabel and childLabel.Text or ""
        end

        local zoneText = getLabelText("Zone")
        if zoneText ~= "" then
            _state.Level = tonumber(zoneText:match("Level (%d+)") or "1") or 1
        end

        local killsText = getLabelText("Kills")
        if killsText ~= "" then
            if killsText == "BOSS!" then
                _state.IsBoss = true
            else
                local k, mk = killsText:match("(%d+)/(%d+)")
                _state.Kills = tonumber(k or "0") or 0
                _state.MaxKills = tonumber(mk or "10") or 10
            end
        end

        local timerText = getLabelText("Timer")
        if timerText ~= "" then
            local m, s = timerText:match("(%d+):(%d+)")
            if m and s then
                _state.TimeLeft = tonumber(m) * 60 + tonumber(s)
            else
                _state.TimeLeft = tonumber(timerText:match("(%d+)"))
            end
        end

        local rebirthText = getLabelText("Rebirth")
        if rebirthText == "" then rebirthText = getLabelText("RebirthCount") end
        if rebirthText ~= "" then
            _state.Rebirths = tonumber(rebirthText:match("(%d+)") or "0") or 0
        end
    end)

    return _state
end

local function ensureInFarmStage()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if hrp.Position.Z <= 60300 then
        local activeFolder = workspace:FindFirstChild("__THINGS")
        activeFolder = activeFolder and activeFolder:FindFirstChild("__INSTANCE_CONTAINER")
        activeFolder = activeFolder and activeFolder:FindFirstChild("Active")
        activeFolder = activeFolder and activeFolder:FindFirstChild("TapHeroes")

        local portal = activeFolder and activeFolder:FindFirstChild("PORTALS")
        portal = portal and portal:FindFirstChild("ToStage")
        if portal then
            local startTime = tick()
            while hrp and hrp.Parent and hrp.Position.Z <= 60300 and tick() - startTime < 8 do
                hrp.CFrame = portal.CFrame + Vector3.new(0, 2, 0)
                if firetouchinterest then
                    pcall(function()
                        firetouchinterest(hrp, portal, 0)
                        task.wait(0.15)
                        firetouchinterest(hrp, portal, 1)
                    end)
                else
                    task.wait(0.5)
                end
                task.wait(0.3)
            end
        end
    end
end

local _lastEnterTP = 0
local _lastJoinTime = tick()

local function ensureInEvent()
    local activeInstance = InstancingCmds.Get()
    if not activeInstance or activeInstance.instanceID ~= "TapHeroes" then
        _lastJoinTime = tick()
        pcall(function()
            local enterPart = InstancingCmds.GetEnterPart("TapHeroes")
            if enterPart then
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = (hrp.Position - enterPart.Position).Magnitude
                    if dist > 10 and tick() - _lastEnterTP > 15 then
                        _lastEnterTP = tick()
                        local startTime = tick()
                        while hrp and hrp.Parent and tick() - startTime < 8 do
                            local active = InstancingCmds.Get()
                            if active and active.instanceID == "TapHeroes" then break end
                            hrp.CFrame = enterPart.CFrame + Vector3.new(0, 2, 0)
                            if firetouchinterest then
                                pcall(function()
                                    firetouchinterest(hrp, enterPart, 0)
                                    task.wait(0.15)
                                    firetouchinterest(hrp, enterPart, 1)
                                end)
                            else
                                task.wait(0.5)
                            end
                            task.wait(0.3)
                        end
                    end
                end
            else
                if tick() - _lastEnterTP > 15 then
                    _lastEnterTP = tick()
                    InstancingCmds.Enter("TapHeroes", nil, true, "You are joining the minigame!")
                end
            end
        end)
        task.wait(2)
        return false
    end

    if tick() - _lastJoinTime < 10 then
        task.wait(1)
        return false
    end

    ensureInFarmStage()
    return true
end

local function ensureAutoTapper()
    local saveStat = Save.Get()
    if saveStat and not saveStat.AutoTapper then
        pcall(function() RS.Network.AutoTapper_Toggle:InvokeServer() end)
    end
end

local _currencyCache = {}
local _currencyCacheTimes = {}

local function getEventCurrencyBalance(currencyName)
    local now = tick()
    local lastTime = _currencyCacheTimes[currencyName] or 0
    if now - lastTime < 10 and _currencyCache[currencyName] ~= nil then
        return _currencyCache[currencyName]
    end
    local balance = 0
    pcall(function()
        if not _InventoryCmds or not _CurrencyItem then return end
        local container = _InventoryCmds.Container()
        if container then
            local itemObj = _CurrencyItem(currencyName)
            if itemObj then
                local found = container:FindExact(itemObj)
                if found and found[1] then
                    balance = found[1]:GetAmount() or 0
                end
            end
        end
    end)
    _currencyCache[currencyName] = balance
    _currencyCacheTimes[currencyName] = now
    return balance
end

local _upgradeKeys = { "TapHeroesEggUpgrade", "TapHeroesClickDamage", "TapHeroesPetDamage", "TapHeroesCoinBonus" }

local function autoBuyUpgrades()
    for _, key in ipairs(_upgradeKeys) do
        local upgrade = EventUpgrades[key]
        if upgrade then
            local currentTier = EventUpgradeCmds.GetTier(upgrade)
            if currentTier < #upgrade.TierPowers then
                local cost = upgrade.TierCosts[currentTier + 1]
                if cost and cost:CountAny() >= cost:GetAmount() then
                    pcall(function() EventUpgradeCmds.Purchase(upgrade) end)
                    task.wait(0.2)
                end
            end
        end
    end
end

local function autoHatch()
    local activeInstance = InstancingCmds.Get()
    if not activeInstance or activeInstance.instanceID ~= "TapHeroes" then return end
    if tick() - _lastJoinTime < 10 then return end

    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local closestEggModel = nil
    local minDistance = 200

    local customEggsFolder = workspace:FindFirstChild("__THINGS")
    customEggsFolder = customEggsFolder and customEggsFolder:FindFirstChild("CustomEggs")
    if customEggsFolder then
        for _, child in ipairs(customEggsFolder:GetChildren()) do
            local ok, eggPos = pcall(function() return child:GetPivot().Position end)
            if ok and eggPos then
                local dist = (root.Position - eggPos).Magnitude
                if dist < minDistance then
                    minDistance = dist
                    closestEggModel = child
                end
            end
        end
    end

    if not closestEggModel then return end

    local uid = closestEggModel.Name
    local eggPos = closestEggModel:GetPivot().Position
    local dist = (root.Position - eggPos).Magnitude

    if dist > 15 and dist <= 200 then
        char:PivotTo(CFrame.new(eggPos + Vector3.new(0, 3, 5)))
        task.wait(0.3)
    end

    local price = nil
    pcall(function()
        local priceHUD = closestEggModel:FindFirstChild("PriceHUD")
        local priceHUDInner = priceHUD and priceHUD:FindFirstChild("PriceHUD")
        local priceText = nil

        if priceHUDInner then
            for _, child in ipairs(priceHUDInner:GetChildren()) do
                local amountLabel = child:FindFirstChild("Amount")
                if amountLabel and amountLabel:IsA("TextLabel") then
                    priceText = amountLabel.Text
                    break
                end
            end
        end

        if not priceText and priceHUD then
            for _, desc in ipairs(priceHUD:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Name == "Amount" then
                    priceText = desc.Text
                    break
                end
            end
        end

        if priceText then
            local txt = priceText:lower():gsub("%s+", ""):gsub(",", "")
            local numStr = txt:match("([%d%.]+)")
            if numStr then
                local val = tonumber(numStr)
                if val then
                    if txt:find("k") then val = val * 1000
                    elseif txt:find("m") then val = val * 1000000
                    elseif txt:find("b") then val = val * 1000000000
                    elseif txt:find("t") then val = val * 1000000000000
                    elseif txt:find("q") then val = val * 1000000000000000
                    end
                    price = math.floor(val)
                end
            end
        end
    end)

    local maxHatch = EggCmds.GetMaxHatch() or 1

    if price then
        local balance = getEventCurrencyBalance("MarbleCoins")
        if balance >= price then
            local hatchAmount = math.min(maxHatch, math.floor(balance / price))
            if hatchAmount > 0 then
                getgenv().SessionHatched = (getgenv().SessionHatched or 0) + hatchAmount
                pcall(function()
                    RS.Network.CustomEggs_Hatch:InvokeServer(uid, hatchAmount)
                end)
            end
        end
    else
        getgenv().SessionHatched = (getgenv().SessionHatched or 0) + maxHatch
        pcall(function()
            RS.Network.CustomEggs_Hatch:InvokeServer(uid, maxHatch)
        end)
    end
end

local function autoRebirth(currentLevel)
    local cap = CFG["Level Cap After Rebirth"] or 115
    if currentLevel < cap then return end

    local save = Save.Get()
    local currentRebirths = (save and save.TapHeroes and save.TapHeroes.Rebirths) or 0
    local rebirthCap = CFG["Rebirth Cap"]
    if rebirthCap and currentRebirths >= rebirthCap then return end

    local activeInstance = InstancingCmds.Get()
    if activeInstance and activeInstance.instanceID == "TapHeroes" then
        pcall(function() activeInstance:FireCustom("GC_Reset") end)
        task.wait(3)
    end
end

local _lastBossFailTime = 0
local _farmingDueToFailure = false
local _failedBossLevel = nil
local _farmLevel = nil
local _lastLevel = nil
local _levelStartTime = tick()

local function handleBossLogic(activeInstance)
    local now = tick()

    if _state.Level ~= _lastLevel then
        _lastLevel = _state.Level
        _levelStartTime = now
    end

    if _farmingDueToFailure then
        local remaining = 300 - (now - _lastBossFailTime)
        if remaining > 0 then
            pcall(function() activeInstance:FireCustom("ZN_Auto", false) end)
            if _state.Level ~= _farmLevel then
                pcall(function() activeInstance:FireCustom("ZN_Warp", _farmLevel) end)
            end
            return
        else
            _farmingDueToFailure = false
            pcall(function()
                activeInstance:FireCustom("ZN_Auto", true)
                activeInstance:FireCustom("ZN_Warp", _failedBossLevel)
            end)
            return
        end
    end

    pcall(function() activeInstance:FireCustom("ZN_Auto", true) end)

    local isBossLevel = (_state.Level % 5 == 0)
    if isBossLevel then
        local timeSpent = now - _levelStartTime
        if timeSpent > 35 then
            _lastBossFailTime = now
            _farmingDueToFailure = true
            _failedBossLevel = _state.Level
            _farmLevel = _state.Level > 5 and (_state.Level - 5) or 4

            pcall(function()
                activeInstance:FireCustom("ZN_Auto", false)
                task.wait(0.2)
                activeInstance:FireCustom("ZN_Warp", _farmLevel)
            end)
        end
    end
end

local function autoFuseEventPets()
    local saveStat = Save.Get()
    local petInventory = saveStat and saveStat.Inventory and saveStat.Inventory.Pet
    if not petInventory then return end

    local PetItem = require(RS.Library.Items.PetItem)

    local equippedUIDs = {}
    pcall(function()
        for _, pet in ipairs(PetCmds.GetEquippedItems()) do
            equippedUIDs[pet:GetUID()] = true
        end
    end)

    local normalGroups = {}
    local goldenGroups = {}

    for uid, petData in pairs(petInventory) do
        local petInstance = nil
        pcall(function() petInstance = PetItem:Get(uid) or PetItem:Find(uid) end)

        if petInstance then
            local petId = petInstance:GetId()
            if eventPetIds[petId] then
                local isEquipped = equippedUIDs[uid] ~= nil
                local isLocked = false
                pcall(function() isLocked = petInstance:IsLocked() end)
                local isHugeOrRare = false
                pcall(function()
                    if petInstance:GetExclusiveLevel() > 0 then isHugeOrRare = true end
                end)

                if not isEquipped and not isLocked and not isHugeOrRare and not petInstance:IsShiny() then
                    local qty = 1
                    pcall(function() qty = petInstance:GetAmount() or 1 end)

                    if petInstance:IsNormal() then
                        normalGroups[petId] = normalGroups[petId] or {}
                        table.insert(normalGroups[petId], { uid = uid, qty = qty })
                    elseif petInstance:IsGolden() then
                        goldenGroups[petId] = goldenGroups[petId] or {}
                        table.insert(goldenGroups[petId], { uid = uid, qty = qty })
                    end
                end
            end
        end
    end

    local hasCraft = false

    for petId, stacks in pairs(normalGroups) do
        local best = nil
        for _, s in ipairs(stacks) do
            if not best or s.qty > best.qty then best = s end
        end
        if best and best.qty >= 10 then
            hasCraft = true
            local qty = math.floor(best.qty / 10)
            pcall(function() RS.Network.GoldMachine_Activate:InvokeServer(best.uid, qty) end)
            task.wait(0.3)
        end
    end

    for petId, stacks in pairs(goldenGroups) do
        local best = nil
        for _, s in ipairs(stacks) do
            if not best or s.qty > best.qty then best = s end
        end
        if best and best.qty >= 10 then
            hasCraft = true
            local qty = math.floor(best.qty / 10)
            pcall(function() RS.Network.RainbowMachine_Activate:InvokeServer(best.uid, qty) end)
            task.wait(0.3)
        end
    end

    if hasCraft then
        task.wait(0.5)
        pcall(function() PetCmds.EquipBest() end)
    end
end

local _lastEnchantEquipTime = 0

local function equipEnchants()
    if not CFG.AutoEquipEnchants then return end
    local targetList = CFG.Enchants
    if type(targetList) == "table" and not targetList[1] then
        targetList = targetList.Farm or {}
    end
    if not targetList or #targetList == 0 then return end

    pcall(function()
        local save = Save.Get()
        if not save then return end

        local instantiatedItems = Types.DecodeUnpacked(save.Inventory or {})
        local allEnchants = {}

        for _, item in ipairs(instantiatedItems) do
            if item.Class and item.Class.Name == "Enchant" then
                local id = item:GetId() or ""
                local tier = item:GetTier() or 1
                local qty = item:GetAmount() or 1
                local uid = item:GetUID()
                if uid then
                    table.insert(allEnchants, { uid = uid, id = id, tier = tier, qty = qty, used = 0 })
                end
            end
        end

        table.sort(allEnchants, function(a, b) return a.tier > b.tier end)

        local slotsNeeded = EnchantCmds.GetMaxEquippedEnchants() or 5
        local targetUids = {}

        for _, targetName in ipairs(targetList) do
            if #targetUids >= slotsNeeded then break end
            local lowerTarget = string.lower(targetName)

            for _, entry in ipairs(allEnchants) do
                if entry.used < entry.qty then
                    local entryIdLower = string.lower(entry.id)
                    if entryIdLower == lowerTarget or entryIdLower:find(lowerTarget, 1, true) then
                        entry.used = entry.used + 1
                        table.insert(targetUids, entry.uid)
                        break
                    end
                end
            end
        end

        if #targetUids == 0 then return end

        local maxSlots = EnchantCmds.GetMaxEquippedEnchants() or 5
        for i = 1, maxSlots do
            pcall(function() Network.Fire("Enchants_ClearSlot", i) end)
            task.wait(0.1)
        end
        task.wait(1.5)

        for idx, uid in ipairs(targetUids) do
            pcall(function() Network.Fire("Enchants_Equip", uid) end)
            task.wait(0.5)
        end

        task.wait(1)
        local save2 = Save.Get()
        local equipped2 = save2 and save2.EquippedEnchants or {}
        local filledSlots = 0
        for i = 1, maxSlots do
            if equipped2[i] or equipped2[tostring(i)] then
                filledSlots = filledSlots + 1
            end
        end
        if filledSlots < #targetUids then
            for idx, uid in ipairs(targetUids) do
                if idx > filledSlots then
                    pcall(function() Network.Fire("Enchants_Equip", uid) end)
                    task.wait(0.5)
                end
            end
        end
    end)
end

local _lastClaimMailTime = 0

local function autoClaimMail()
    if not CFG.AutoClaimMail then return end
    local now = tick()
    if now - _lastClaimMailTime < 180 then return end
    _lastClaimMailTime = now

    local ok = pcall(function() Network.Invoke("Mailbox: Claim All") end)
    if not ok then
        ok = pcall(function() Network.Invoke("Mailbox: ClaimAll") end)
    end
    if not ok then
        pcall(function()
            RS:WaitForChild("Network"):WaitForChild("ZN_Acquire"):InvokeServer({"4924f4ce9d9b4119a1c5339faed12148"})
        end)
    end
    task.wait(0.5)
    pcall(function() Network.Fire("LD_BestFit") end)
end

local _lastSendMailTime = 0

local function autoSendMail()
    if not CFG.AutoSendMail then return end
    local now = tick()
    if now - _lastSendMailTime < 180 then return end
    _lastSendMailTime = now

    if not CFG.MailConfig or not CFG.MailUser or #CFG.MailUser == 0 then return end
    if not ZoneCmds.Owns("Castle") then return end
    if not _Inventory then return end

    local container = _Inventory.Container(LocalPlayer)
    if not container then return end
    local store = container._store
    if not store then return end

    local recipient = CFG.MailUser[1]
    pcall(function()
        for uid, item in pairs(store._byUID) do
            if item.Class and item._data then
                local itemId = safeGetItemId(item)
                if itemId then
                    local className = item.Class.Name
                    local configItem = CFG.MailConfig[itemId]
                    local isMatch = false

                    if CFG.MailConfig["All Huges"] and className == "Pet" and string.find(itemId, "Huge", 1, true) then
                        isMatch = true
                        configItem = CFG.MailConfig["All Huges"]
                    end

                    if (configItem and className == configItem.Class) or isMatch then
                        local currentAmount = item:GetAmount() or 1
                        local minAmount = (configItem and configItem.MinAmount) or 1
                        if currentAmount >= minAmount then
                            pcall(function()
                                Network.Invoke("Mailbox: Send", recipient, "", item:GetUID(), currentAmount)
                            end)
                            task.wait(0.5)
                        end
                    end
                end
            end
        end
    end)
end

local _seenPets = {}
local _lastWebhookTime = 0
local _lastPetCount = 0

pcall(function()
    local currentSave = Save.Get()
    if currentSave and currentSave.Inventory and currentSave.Inventory.Pet then
        for uid, _ in pairs(currentSave.Inventory.Pet) do
            _seenPets[uid] = true
        end
        local c = 0
        for _ in pairs(currentSave.Inventory.Pet) do c = c + 1 end
        _lastPetCount = c
    end
end)

local function sendWebhook(url, data)
    if not url or url == "" then return end
    pcall(function()
        local headers = {["Content-Type"] = "application/json"}
        local body = HttpService:JSONEncode(data)
        if request then
            request({Url = url, Method = "POST", Headers = headers, Body = body})
        elseif syn and syn.request then
            syn.request({Url = url, Method = "POST", Headers = headers, Body = body})
        elseif http_request then
            http_request({Url = url, Method = "POST", Headers = headers, Body = body})
        end
    end)
end

local function handleWebhookAlerts()
    local webhookConfig = CFG.Webhook
    if not webhookConfig or not webhookConfig["Alert Pets"] then return end
    local url = webhookConfig["Webhook URL"]
    if not url or url == "" then return end

    local now = tick()
    if now - _lastWebhookTime < 120 then return end
    _lastWebhookTime = now

    pcall(function()
        local currentSave = Save.Get()
        if not currentSave or not currentSave.Inventory or not currentSave.Inventory.Pet then return end

        local petCount = 0
        for _ in pairs(currentSave.Inventory.Pet) do petCount = petCount + 1 end
        if petCount == _lastPetCount then return end
        _lastPetCount = petCount

        local PetItem = require(RS.Library.Items.PetItem)

        for uid, petData in pairs(currentSave.Inventory.Pet) do
            if not _seenPets[uid] then
                _seenPets[uid] = true

                local petInstance = PetItem:Get(uid) or PetItem:Find(uid)
                local petId = (petInstance and petInstance:GetId()) or petData.id or ""
                local isHuge = petInstance and petInstance:IsHuge() or false
                local isTitanic = petInstance and petInstance:IsTitanic() or false
                local isGargantuan = petInstance and petInstance:IsGargantuan() or false

                if not isHuge and not isTitanic and not isGargantuan then
                    local nameLower = string.lower(petId)
                    if nameLower:find("huge") then isHuge = true
                    elseif nameLower:find("titanic") then isTitanic = true
                    elseif nameLower:find("gargantuan") then isGargantuan = true end
                end

                if isHuge or isTitanic or isGargantuan then
                    local petType = isTitanic and "TITANIC" or (isGargantuan and "GARGANTUAN" or "HUGE")
                    local displayName = petId:gsub("Huge ", ""):gsub("Titanic ", ""):gsub("Gargantuan ", "")
                    local isShiny = petData.sh or petData.Shiny or false
                    local isGold = petData.pt == 1 or false
                    local isRainbow = petData.pt == 2 or false
                    local detail = "Normal"
                    if isShiny and isGold then detail = "Shiny Gold"
                    elseif isShiny and isRainbow then detail = "Shiny Rainbow"
                    elseif isShiny then detail = "Shiny"
                    elseif isGold then detail = "Gold"
                    elseif isRainbow then detail = "Rainbow" end

                    local pingContent = ""
                    if webhookConfig["ID"] then
                        for _, id in ipairs(webhookConfig["ID"]) do
                            if id and id ~= "" then pingContent = pingContent .. "<@" .. id .. "> " end
                        end
                    end

                    sendWebhook(url, {
                        content = pingContent,
                        embeds = {{
                            title = "🎉 Pet Simulator 99 - Rare Pet! 🎉",
                            color = isTitanic and 16711680 or (isGargantuan and 16776960 or 65280),
                            fields = {
                                {name = "Pet Name", value = displayName, inline = true},
                                {name = "Rarity", value = petType, inline = true},
                                {name = "Type", value = detail, inline = true},
                                {name = "Account", value = LocalPlayer.Name, inline = true},
                            },
                            timestamp = DateTime.now():ToISO8601Value()
                        }}
                    })
                end
            end
        end
    end)
end

task.wait(math.random() * 30)

local INTERVALS = {
    hatch       = 2,
    rebirth     = 60,
    upgrades    = 60,
    equipBest   = 120,
    fusion      = 300,
    enchants    = 240,
    claimMail   = 180,
    sendMail    = 180,
    webhook     = 120,
}

local _lastRun = {}
for k, _ in pairs(INTERVALS) do _lastRun[k] = 0 end

local function shouldRun(taskName)
    local now = tick()
    local interval = INTERVALS[taskName]
    local jitter = interval * 0.2 * (math.random() * 2 - 1)
    if now - _lastRun[taskName] >= interval + jitter then
        _lastRun[taskName] = now
        return true
    end
    return false
end

while true do

    local inEvent = ensureInEvent()
    if not inEvent then
        task.wait(10)
        continue
    end

    local activeInstance = InstancingCmds.Get()
    if not activeInstance then
        task.wait(5)
        continue
    end

    getTHState()

    pcall(ensureAutoTapper)

    if CFG.BossFailureLogic ~= false then
        pcall(function() handleBossLogic(activeInstance) end)
    end

    if CFG.AutoRebirth and shouldRun("rebirth") then
        pcall(function() autoRebirth(_state.Level) end)
    end

    if CFG.AutoUpgrade ~= false and shouldRun("upgrades") then
        pcall(autoBuyUpgrades)
    end

    if shouldRun("equipBest") then
        pcall(function() PetCmds.EquipBest() end)
    end

    if CFG.AutoFusion ~= false and shouldRun("fusion") then
        pcall(autoFuseEventPets)
    end

    if CFG.AutoEquipEnchants and shouldRun("enchants") then
        pcall(equipEnchants)
    end

    if CFG.AutoClaimMail and shouldRun("claimMail") then
        pcall(autoClaimMail)
    end

    if CFG.AutoSendMail and shouldRun("sendMail") then
        pcall(autoSendMail)
    end

    if shouldRun("webhook") then
        pcall(handleWebhookAlerts)
    end

    if CFG.AutoHatch ~= false then
        for _hatchRound = 1, 6 do
            pcall(autoHatch)
            task.wait(3)
        end
    else
        task.wait(20)
    end
end
