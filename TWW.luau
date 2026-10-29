local environment = (type(getgenv) == "function" and getgenv()) or _G
if environment.TWWESP and type(environment.TWWESP.Destroy) == "function" then
    pcall(function() environment.TWWESP:Destroy() end)
end

-- ====== SMUGLIB V2 LOADER ======
local SMUGLIB_URLS = {
    "https://raw.githubusercontent.com/Xa3ro5/LifeIsRoblox/refs/heads/main/SmugLibCoreV2.lua",
    "https://pastebin.com/raw/CkVW0eJZ"
}
local Library
do
    for _, url in ipairs(SMUGLIB_URLS) do
        local ok, source = pcall(game.HttpGet, game, url, true)
        if ok and type(source) == "string" and source ~= "" then
            local compile = loadstring(source)
            if compile then
                local ran, lib = pcall(compile)
                if ran and type(lib) == "table" then Library = lib break end
            end
        end
    end
    if not Library then warn("[TWW] Failed to load SmugLibV2") return end
end

-- ====== SERVICES ======
local S = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    Workspace = game:GetService("Workspace"),
    CollectionService = game:GetService("CollectionService"),
    Lighting = game:GetService("Lighting"),
    TeleportService = game:GetService("TeleportService"),
    StarterGui = game:GetService("StarterGui"),
    HttpService = game:GetService("HttpService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    TweenService = game:GetService("TweenService"),
}
S.LocalPlayer = S.Players.LocalPlayer
S.Camera = S.Workspace.CurrentCamera

local Global
do
    local ok, result = pcall(function() return require(S.ReplicatedStorage.SharedModules.Global) end)
    if ok and type(result) == "table" then Global = result
    else warn("[TWW] Failed to load Global module") end
end

-- ====== STATE ======
local state = {
    active=true, generation=0, destroyed=false, espEnabled=false,
    infiniteStamina=false,
    antiRagdoll=false,
    antiFallDamage=false,
    infiniteHorseStamina=false,
    showPlayers=false, showNPCs=false, showAnimals=false, showHorses=false,
    animalFilter={},
    showOres=false, showItems=false, showChests=false, showTrains=false,
    showTerritories=false, showFish=false, showDeadAnimals=false,
    showThunderstruck=false,
    showLegendaryOnly=false, legendaryGoldenMode=false,
    showNames=false, showDistance=false, showHealth=false, showTracers=false,
    showOreCount=false, showOreTier=false,
    highlightGoldBars=false,
    alwaysDay=false,
    playerColor="Green", npcColor="Purple", animalColor="White", horseColor="Cyan",
    oreColor="Orange", itemColor="Cyan", chestColor="Magenta", trainColor="Red",
    territoryColor="Purple", fishColor="Blue", deadAnimalColor="Red",
    legendaryColor="Yellow", tracerColor="Cyan", thunderstruckColor="Yellow",
    tracerThickness=1, tracerTransparency=0.15, labelSize=13,
    maxDistance=0, updateInterval=0.1, maxLabels=50,
    chamsEnabled=false, fullBrightLevel=0,
    espBodyHighlight={},
    silentAim=false, targetPlayers=false, targetAnimals=false, targetNPCs=false,
    silentAimPrediction=true,          -- NEW
    silentAimPredictionStrength=1.0,   -- NEW
    targetPart="Head", fov=90, visibilityCheck=false,
    noRecoil=false, noSpread=false, infiniteAmmo=false, instantReload=false,
    gravityEnabled=false, gravityValue=196.2,
    hipHeightEnabled=false, hipHeightValue=2,
    speedEnabled=false, speedValue=16,
    walkUnderWater=false,
    allowGunsUnderWater=false,
    debugPrints=false, currentConfig="Default", showFOVRing=false,
    chamsResetInProgress=false,
    suppressErrors=false,
}

local DEFAULT_STATE = {}
for k, v in pairs(state) do
    if type(v) ~= "function" and type(v) ~= "userdata"
        and k ~= "active" and k ~= "generation" and k ~= "destroyed" and k ~= "chamsResetInProgress" then
        if type(v) == "table" then
            DEFAULT_STATE[k] = {}
            for kk, vv in pairs(v) do DEFAULT_STATE[k][kk] = vv end
        else
            DEFAULT_STATE[k] = v
        end
    end
end

-- ====== ERROR / WARN SUPPRESS HOOK ======
do
    local _origWarn  = warn
    local _origPrint = print
    local function looksLikeError(s)
        if type(s) ~= "string" then return false end
        local l = s:lower()
        return l:find("error", 1, true) ~= nil
            or l:find("failed", 1, true) ~= nil
            or l:find("warn", 1, true) ~= nil
            or l:find("traceback", 1, true) ~= nil
            or l:find("attempt to", 1, true) ~= nil
    end
    local newWarn = function(...)
        if state and state.suppressErrors then return end
        return _origWarn(...)
    end
    local newPrint = function(...)
        if state and state.suppressErrors then
            local a = ...
            if looksLikeError(a) then return end
        end
        return _origPrint(...)
    end

    local env = environment or _G

    pcall(function()
        if type(isreadonly) == "function" and isreadonly(env) then
            if type(setreadonly) == "function" then setreadonly(env, false)
            elseif type(makewritable) == "function" then makewritable(env) end
        end
    end)

    pcall(function() rawset(env, "warn", newWarn) end)
    pcall(function() rawset(env, "print", newPrint) end)
    pcall(function() warn = newWarn end)
    pcall(function() print = newPrint end)

    pcall(function()
        if type(coroutine) == "table" and type(coroutine.wrap) == "function" then
            local _origWrap = coroutine.wrap
            pcall(function()
                coroutine.wrap = function(f)
                    return _origWrap(function(...)
                        local ok, err = pcall(f, ...)
                        if not ok and not (state and state.suppressErrors) then
                            _origWarn("[TWW] Coroutine error: "..tostring(err))
                        end
                    end)
                end
            end)
        end
    end)
end

local COLOR_PRESETS = {
    Red=Color3.fromRGB(255,60,60), Green=Color3.fromRGB(60,255,60),
    Blue=Color3.fromRGB(60,150,255), Yellow=Color3.fromRGB(255,255,60),
    White=Color3.fromRGB(255,255,255), Cyan=Color3.fromRGB(0,255,255),
    Magenta=Color3.fromRGB(255,0,255), Orange=Color3.fromRGB(255,165,0),
    Gold=Color3.fromRGB(255,215,0), Purple=Color3.fromRGB(180,100,255),
    Pink=Color3.fromRGB(255,105,180),
}
local COLOR_OPTIONS = {}
for name in pairs(COLOR_PRESETS) do table.insert(COLOR_OPTIONS, name) end
table.sort(COLOR_OPTIONS)

local BODY_HIGHLIGHT_OPTIONS = {"Head", "Arms", "Torso", "Legs", "All"}

local PLAYER_BODY_GROUPS = {
    Head  = {"Head"},
    Arms  = {"RightUpperArm","RightLowerArm","RightHand","RightFist",
             "LeftUpperArm","LeftLowerArm","LeftHand","LeftFist",
             "Right Arm","Left Arm","RightHand","LeftHand"},
    Torso = {"LowerTorso","UpperTorso","Torso"},
    Legs  = {"RightUpperLeg","RightLowerLeg","RightFoot",
             "LeftUpperLeg","LeftLowerLeg","LeftFoot",
             "Right Leg","Left Leg","RightFoot","LeftFoot"},
}

local uiHandles = { checkboxes={}, dropdowns={}, sliders={}, textboxes={}, checklists={} }

local ESP, CHAR, COMBAT, HOOKS, AMMO, FB, CFG, INV, Physics, Water = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}

-- ====== SAVE/LOAD ======
local _loadingConfig = false
local function updateUIFromState()
    for key, h in pairs(uiHandles.checkboxes) do
        if state[key] ~= nil then pcall(function() h:Set(state[key]) end) end
    end
    for key, h in pairs(uiHandles.dropdowns) do
        if state[key] ~= nil then pcall(function() h:Set(state[key]) end) end
    end
    for key, h in pairs(uiHandles.sliders) do
        if state[key] ~= nil then pcall(function() h:Set(state[key]) end) end
    end
    for key, h in pairs(uiHandles.checklists) do
        if state[key] ~= nil then pcall(function() h:Set(state[key]) end) end
    end
    if uiHandles.textboxes.configName then
        pcall(function() uiHandles.textboxes.configName:Set(state.currentConfig) end)
    end
end

local function SaveStateToConfig(name)
    if not CFG.ready or not CFG.save then return false end
    local data = {}
    for k, v in pairs(state) do
        if type(v) ~= "function" and type(v) ~= "userdata" and k ~= "window" and k ~= "toggle" and k ~= "chamsResetInProgress" then
            data[k] = v
        end
    end
    return CFG.save(name, data)
end

local function LoadStateFromConfig(name)
    if not CFG.load then return false end
    local data = CFG.load(name)
    if not data then return false end
    _loadingConfig = true
    local prevEsp = state.espEnabled
    for k, v in pairs(data) do
        if state[k] ~= nil then
            if type(state[k]) == "table" and type(v) == "table" then
                state[k] = {}
                for kk, vv in pairs(v) do state[k][kk] = vv end
            else
                state[k] = v
            end
        end
    end
    if state.espEnabled and not prevEsp then ESP.lastUpdate = 0
    elseif not state.espEnabled and prevEsp then if ESP.cleanup then ESP.cleanup() end end
    if HOOKS.applyNoRecoil then HOOKS.applyNoRecoil(state.noRecoil) end
    if FB.setLevel then FB.setLevel(state.fullBrightLevel) end
    if FB.applyTime then FB.applyTime() end
    _loadingConfig = false
    return true
end

local function ResetStateToDefault()
    for k, v in pairs(DEFAULT_STATE) do
        if type(v) == "table" then
            state[k] = {}
            for kk, vv in pairs(v) do state[k][kk] = vv end
        else
            state[k] = v
        end
    end
    if state.espEnabled then state.espEnabled = false; if ESP.cleanup then ESP.cleanup() end end
    if HOOKS.applyNoRecoil then HOOKS.applyNoRecoil(state.noRecoil) end
    if FB.setLevel then FB.setLevel(state.fullBrightLevel) end
    if FB.applyTime then FB.applyTime() end
    updateUIFromState()
end

-- ====== CFG ======
local function initCFG()
    local FOLDER = "TWW_Configs/"
    local canWrite = type(writefile) == "function"
    local canRead = type(readfile) == "function"
    local canList = type(listfiles) == "function"
    local canDel = type(delfile) == "function"
    local canMake = type(makefolder) == "function"
    local ready = false
    if canWrite and canRead then
        if canMake then pcall(function() makefolder(FOLDER) end) end
        local ok = pcall(function() writefile(FOLDER .. ".probe", "ok") end)
        if ok then pcall(function() delfile(FOLDER .. ".probe") end); ready = true end
    end
    CFG.ready = ready
    CFG.getFiles = function()
        local files = {}
        if not ready or not canList then return files end
        local ok, result = pcall(function() return listfiles(FOLDER) end)
        if not ok or type(result) ~= "table" then return files end
        for _, file in ipairs(result) do
            local name = file:match("([^/\\]+)%.json$")
            if name and name ~= "" then table.insert(files, name) end
        end
        table.sort(files)
        return files
    end
    CFG.save = function(name, data)
        if not ready then return false end
        local ok, json = pcall(S.HttpService.JSONEncode, S.HttpService, data)
        if not ok then return false end
        return pcall(function() writefile(FOLDER .. name .. ".json", json) end)
    end
    CFG.load = function(name)
        if not ready then return nil end
        local content
        local ok = pcall(function() content = readfile(FOLDER .. name .. ".json") end)
        if not ok or not content or content == "" then return nil end
        local ok2, decoded = pcall(function() return S.HttpService:JSONDecode(content) end)
        if not ok2 or type(decoded) ~= "table" then return nil end
        return decoded
    end
    CFG.delete = function(name)
        if not ready or not canDel then return false end
        pcall(function() delfile(FOLDER .. name .. ".json") end)
        return true
    end
end

-- ====== FULL BRIGHT + DAY ======
local function initFB()
    local brightConn = nil
    local function startBright()
        if brightConn then return end
        brightConn = S.RunService.Heartbeat:Connect(function()
            if state.destroyed then return end
            if S.Lighting.ExposureCompensation ~= state.fullBrightLevel then
                S.Lighting.ExposureCompensation = state.fullBrightLevel
            end
        end)
    end
    local function stopBright()
        if brightConn then pcall(function() brightConn:Disconnect() end); brightConn = nil end
    end
    FB.setLevel = function(level)
        state.fullBrightLevel = level
        if type(level) ~= "number" or level <= 0 then
            stopBright()
            pcall(function() S.Lighting.ExposureCompensation = 0 end)
        else
            S.Lighting.ExposureCompensation = level
            startBright()
        end
    end
    local LightingSettings = S.ReplicatedStorage:FindFirstChild("LightingSettings")
    local TimeBase  = LightingSettings and LightingSettings:FindFirstChild("TimeBase")
    local TimeSpeed = LightingSettings and LightingSettings:FindFirstChild("TimeSpeed")
    local dayConn = nil
    local function startDay()
        if dayConn then return end
        if not (TimeBase and TimeSpeed) then return end
        dayConn = S.RunService.Heartbeat:Connect(function()
            if state.destroyed or not state.alwaysDay then return end
            local ok, speed = pcall(function() return TimeSpeed.Value end)
            if not ok or type(speed) ~= "number" or speed <= 0 then return end
            local synced = Global and Global.SyncedTime
            if not synced or not synced.GetTime then return end
            local ok2, t = pcall(function() return synced:GetTime() end)
            if not ok2 or type(t) ~= "number" then return end
            pcall(function() TimeBase.Value = t - 360 / speed end)
        end)
    end
    local function stopDay()
        if dayConn then pcall(function() dayConn:Disconnect() end); dayConn = nil end
    end
    FB.stop = function() stopBright(); stopDay() end
    FB.applyTime = function() if state.alwaysDay then startDay() else stopDay() end end
    FB.setLevel(state.fullBrightLevel or 0)
end

-- ====== FOV RING ======
local function initFOV()
    local ring = nil
    local function create()
        if ring then return end
        ring = Drawing.new("Circle")
        ring.Visible = false
        ring.Color = Color3.fromRGB(255,255,255)
        ring.Thickness = 1
        ring.Filled = false
        ring.NumSides = 64
        ring.Transparency = 0.5
    end
    local function update()
        if not ring then return end
        local vp = S.Camera.ViewportSize
        ring.Position = Vector2.new(vp.X/2, vp.Y/2)
        ring.Radius = (state.fov / 90) * 200
        ring.Visible = state.showFOVRing and state.silentAim
    end
    ESP.createFOV = create
    ESP.updateFOV = update
    ESP.getFOVRing = function() return ring end
    ESP.clearFOVRing = function() if ring then pcall(function() ring:Remove() end); ring = nil end end
end

-- =================================================================
--  PHYSICS
-- =================================================================
local function initPhysics()
    local gravityConn = nil
    local origGravity = S.Workspace.Gravity
    local function startGravity()
        if gravityConn then return end
        gravityConn = S.RunService.Heartbeat:Connect(function()
            if state.destroyed then return end
            if state.gravityEnabled then
                if S.Workspace.Gravity ~= state.gravityValue then
                    S.Workspace.Gravity = state.gravityValue
                end
            elseif S.Workspace.Gravity ~= origGravity then
                S.Workspace.Gravity = origGravity
            end
        end)
    end
    local function stopGravity()
        if gravityConn then pcall(function() gravityConn:Disconnect() end); gravityConn = nil end
        pcall(function() S.Workspace.Gravity = origGravity end)
    end
    Physics.setGravity = function(enabled, value)
        state.gravityEnabled = enabled
        if value then state.gravityValue = value end
        if enabled then startGravity() else stopGravity() end
    end

    local function getLocalHumanoid()
        local we = S.Workspace:FindFirstChild("WORKSPACE_Entities")
        local pf = we and we:FindFirstChild("Players")
        local lp = pf and pf:FindFirstChild(S.LocalPlayer.Name)
        if lp then
            local h = lp:FindFirstChild("Humanoid") or lp:FindFirstChild("Human")
            if h and h:IsA("Humanoid") then return h end
        end
        local char = S.LocalPlayer.Character
        if char then
            local h = char:FindFirstChildOfClass("Humanoid")
            if h then return h end
        end
        return nil
    end

    local hipConn = nil
    local origHipHeight = nil
    local function startHip()
        if hipConn then return end
        if origHipHeight == nil then
            local hum = getLocalHumanoid()
            if hum then origHipHeight = hum.HipHeight end
        end
        hipConn = S.RunService.Heartbeat:Connect(function()
            if state.destroyed or not state.hipHeightEnabled then return end
            local hum = getLocalHumanoid()
            if hum then
                if origHipHeight == nil then origHipHeight = hum.HipHeight end
                if hum.HipHeight ~= state.hipHeightValue then
                    pcall(function() hum.HipHeight = state.hipHeightValue end)
                end
            end
        end)
    end
    local function stopHip()
        if hipConn then pcall(function() hipConn:Disconnect() end); hipConn = nil end
        local hum = getLocalHumanoid()
        if hum and origHipHeight ~= nil then
            pcall(function() hum.HipHeight = origHipHeight end)
        end
        origHipHeight = nil
    end
    Physics.setHipHeight = function(enabled, value)
        state.hipHeightEnabled = enabled
        if value then state.hipHeightValue = value end
        if enabled then startHip() else stopHip() end
    end
    Physics.reapplyHip = function()
        if state.hipHeightEnabled then
            origHipHeight = nil
            if hipConn then pcall(function() hipConn:Disconnect() end); hipConn = nil end
            startHip()
        end
    end

    local spdConn = nil
    local origWalkSpeed = nil
    local function startSpeed()
        if spdConn then return end
        if origWalkSpeed == nil then
            local hum = getLocalHumanoid()
            if hum then origWalkSpeed = hum.WalkSpeed end
        end
        spdConn = S.RunService.Heartbeat:Connect(function()
            if state.destroyed or not state.speedEnabled then return end
            local hum = getLocalHumanoid()
            if hum then
                if origWalkSpeed == nil then origWalkSpeed = hum.WalkSpeed end
                if hum.WalkSpeed ~= state.speedValue then
                    pcall(function() hum.WalkSpeed = state.speedValue end)
                end
            end
        end)
    end
    local function stopSpeed()
        if spdConn then pcall(function() spdConn:Disconnect() end); spdConn = nil end
        local hum = getLocalHumanoid()
        if hum and origWalkSpeed ~= nil then
            pcall(function() hum.WalkSpeed = origWalkSpeed end)
        end
        origWalkSpeed = nil
    end
    Physics.setSpeed = function(enabled, value)
        state.speedEnabled = enabled
        if value then state.speedValue = value end
        if enabled then startSpeed() else stopSpeed() end
    end
    Physics.reapplySpeed = function()
        if state.speedEnabled then
            origWalkSpeed = nil
            if spdConn then pcall(function() spdConn:Disconnect() end); spdConn = nil end
            startSpeed()
        end
    end

    Physics._stopGravity = stopGravity
    Physics._stopHip     = stopHip
    Physics._stopSpeed   = stopSpeed

    Physics.stop = function()
        if Physics._stopGravity then pcall(Physics._stopGravity) end
        if Physics._stopHip     then pcall(Physics._stopHip) end
        if Physics._stopSpeed   then pcall(Physics._stopSpeed) end
    end
end

-- =================================================================
--  WALK UNDER WATER + ALLOW GUNS UNDERWATER
-- =================================================================
local function initWater()
    local swimCtrl = nil
    local swimConn = nil
    local function getSwim()
        if swimCtrl then return swimCtrl end
        local ok, mod = pcall(function()
            return require(S.ReplicatedStorage.Modules.Character.SwimController)
        end)
        if ok and type(mod) == "table" then swimCtrl = mod end
        return swimCtrl
    end
    local function startWW()
        if swimConn then return end
        swimConn = S.RunService.Heartbeat:Connect(function()
            if state.destroyed or not state.walkUnderWater then return end
            local sw = getSwim()
            if sw then
                pcall(function()
                    sw.ClampSurfaceMovement = false
                    sw.MaxJumpDepth = 0
                    sw.SurfaceDepth = 0
                    sw.DragForceMultiplier = 0
                end)
            end
        end)
    end
    local function stopWW()
        if swimConn then pcall(function() swimConn:Disconnect() end); swimConn = nil end
        local sw = getSwim()
        if sw then
            pcall(function()
                sw.ClampSurfaceMovement = true
                sw.SurfaceDepth = 0.35
                sw.DragForceMultiplier = 9.85
            end)
        end
    end
    Water.setWalkUnderWater = function(enabled)
        state.walkUnderWater = enabled
        if enabled then startWW() else stopWW() end
    end
    local origCanSwitch = nil
    local function applyGunsUW()
        if not Global or not Global.PlayerCharacter then return end
        local pc = Global.PlayerCharacter
        if not origCanSwitch then origCanSwitch = pc.CanSwitchToItem end
        if type(origCanSwitch) ~= "function" then return end
        pc.CanSwitchToItem = function(self, itemData, silent, ...)
            local prevSwim = self.Swimming
            if state.allowGunsUnderWater then
                pcall(function() self.Swimming = false end)
            end
            local ok, a, b = pcall(origCanSwitch, self, itemData, silent, ...)
            if state.allowGunsUnderWater then
                pcall(function() self.Swimming = prevSwim end)
            end
            if ok then return a, b else return origCanSwitch(self, itemData, silent, ...) end
        end
    end
    local function removeGunsUW()
        if not Global or not Global.PlayerCharacter or not origCanSwitch then return end
        pcall(function() Global.PlayerCharacter.CanSwitchToItem = origCanSwitch end)
        origCanSwitch = nil
    end
    Water.setAllowGunsUnderWater = function(enabled)
        state.allowGunsUnderWater = enabled
        if enabled then applyGunsUW() else removeGunsUW() end
    end
    Water.reapply = function()
        if state.allowGunsUnderWater then applyGunsUW() end
    end
end

-- =================================================================
--  ESP
-- =================================================================
local function initESP()
    local folderCache, folderCacheTime = {}, {}
    local drawings, espObjects = {}, {}
    ESP.objects = espObjects
    ESP.lastUpdate = 0
    local goldBarHighlights = {}

    local CHAMS_TRACER_MAX_DIST = 500

    local REGIONS = {
        "REGION_Swamp","REGION_BearpawValley","REGION_Desert","REGION_Forest",
        "REGION_ForestOfBones","REGION_Highlands","REGION_Hills","REGION_Mountains",
        "REGION_Plains","REGION_Plantation","REGION_RaiderCanyons","REGION_Silverhills",
    }

    local function getFolder(path)
        local cached = folderCache[path]
        if cached ~= nil then
            if cached ~= false then return cached end
            if os.clock() - (folderCacheTime[path] or 0) < 3 then return nil end
        end
        folderCacheTime[path] = os.clock()
        local node = S.Workspace
        for segment in string.gmatch(path, "[^.]+") do
            if node then node = node:FindFirstChild(segment) end
        end
        folderCache[path] = node or false
        return node or nil
    end

    local function refreshCache()
        for k in pairs(folderCache) do folderCache[k] = nil end
        for k in pairs(folderCacheTime) do folderCacheTime[k] = nil end
        local paths = {
            "WORKSPACE_Entities","WORKSPACE_Entities.Animals","WORKSPACE_Entities.NPCs",
            "WORKSPACE_Entities.Players","WORKSPACE_Entities.Horses","WORKSPACE_Entities.Fish",
            "WORKSPACE_Entities.DeadAnimals","WORKSPACE_Entities.Event",
            "WORKSPACE_Interactables","WORKSPACE_Interactables.Mining",
            "WORKSPACE_Interactables.Mining.OreDeposits",
            "WORKSPACE_Interactables.DroppedItems","WORKSPACE_Interactables.LootChests",
            "WORKSPACE_Interactables.Territories",
            "WORKSPACE_Trains","WORKSPACE_Trains.RunningTrains",
            "WORKSPACE_Geometry",
        }
        for _, p in ipairs(paths) do getFolder(p) end
    end

    ESP.collectAnimalNames = function()
        local names, seen = {}, {}
        local af = getFolder("WORKSPACE_Entities.Animals")
        if not af then return names end
        local function addName(n)
            if n and n ~= "" and not seen[n] then
                seen[n] = true
                table.insert(names, n)
            end
        end
        for _, child in ipairs(af:GetChildren()) do
            if child:IsA("Model") then
                addName(child.Name)
            elseif child:IsA("Folder") then
                for _, sub in ipairs(child:GetChildren()) do
                    if sub:IsA("Model") then addName(sub.Name) end
                end
            end
        end
        table.sort(names)
        return names
    end

    local goldBarsCache = nil
    local function getBankGoldBars()
        if goldBarsCache and goldBarsCache.Parent then return goldBarsCache end
        local WS = S.Workspace
        local geo = WS:FindFirstChild("WORKSPACE_Geometry")
        local region = geo and geo:FindFirstChild("REGION_Plains")
        local city = region and region:FindFirstChild("BronzeCity")
        local buildings = city and city:FindFirstChild("Buildings")
        local bankNew = buildings and buildings:FindFirstChild("BronzeBankNew")
        local bank40 = bankNew and bankNew:FindFirstChild("Bank4.0")
        local bankGeo = bank40 and bank40:FindFirstChild("Geometry")
        local basement = bankGeo and bankGeo:FindFirstChild("BankBasement")
        goldBarsCache = basement and basement:FindFirstChild("BankGoldBars")
        return goldBarsCache
    end
    local function updateGoldBars()
        if not state.highlightGoldBars then
            for bar, hl in pairs(goldBarHighlights) do pcall(function() hl:Destroy() end) end
            table.clear(goldBarHighlights)
            return
        end
        local goldBarsFolder = getBankGoldBars()
        if not goldBarsFolder then return end
        local seen = {}
        for _, container in ipairs(goldBarsFolder:GetChildren()) do
            local bar = container:FindFirstChild("GoldBar")
            if bar and bar:IsA("BasePart") then
                seen[bar] = true
                if not goldBarHighlights[bar] then
                    local hl = Instance.new("Highlight")
                    hl.Name = "TWW_GoldBarHighlight"
                    hl.Adornee = bar
                    hl.FillColor = Color3.fromRGB(255, 215, 0)
                    hl.FillTransparency = 0.4
                    hl.OutlineColor = Color3.fromRGB(255, 255, 100)
                    hl.OutlineTransparency = 0
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = bar
                    goldBarHighlights[bar] = hl
                end
            end
        end
        for bar, hl in pairs(goldBarHighlights) do
            if not seen[bar] or not bar.Parent then
                pcall(function() hl:Destroy() end)
                goldBarHighlights[bar] = nil
            end
        end
    end
    ESP.updateGoldBars = updateGoldBars

    ESP.getGoldBarStatus = function()
        local folder = getBankGoldBars()
        if not folder then return false, 0 end
        local count = 0
        for _, container in ipairs(folder:GetChildren()) do
            local bar = container:FindFirstChild("GoldBar")
            if bar and bar:IsA("BasePart") then
                count = count + 1
            end
        end
        return true, count
    end

    local function isBasePart(i) return i and i:IsA("BasePart") end

    local function getCharacter(player)
        player = player or S.LocalPlayer
        local c = player.Character
        if c and c:IsA("Model") then return c end
        local pf = getFolder("WORKSPACE_Entities.Players")
        local rc = pf and pf:FindFirstChild(player.Name)
        if rc and rc:IsA("Model") then return rc end
        return nil
    end
    local function getController(c)
        if not c then return nil end
        return c:FindFirstChild("Human") or c:FindFirstChild("Humanoid") or c:FindFirstChildOfClass("Humanoid")
    end
    local function getRoot(c)
        if not c then return nil end
        local r = c:FindFirstChild("RootPart") or c:FindFirstChild("HumanoidRootPart")
        if isBasePart(r) then return r end
        if c.PrimaryPart and isBasePart(c.PrimaryPart) then return c.PrimaryPart end
        return c:FindFirstChildWhichIsA("BasePart", true)
    end
    local function getTargetPart(m)
        if not m or not m:IsA("Model") then return nil end
        if m.PrimaryPart and isBasePart(m.PrimaryPart) then return m.PrimaryPart end
        local hrp = m:FindFirstChild("HumanoidRootPart")
        if isBasePart(hrp) then return hrp end
        local r = m:FindFirstChild("RootPart") or m:FindFirstChild("Root")
        if isBasePart(r) then return r end
        local t = m:FindFirstChild("Torso") or m:FindFirstChild("UpperTorso") or m:FindFirstChild("LowerTorso")
        if isBasePart(t) then return t end
        return m:FindFirstChildWhichIsA("BasePart", true)
    end
    local function getHealth(c)
        if not c then return 100 end
        local h = getController(c)
        if h and h.Health then return math.floor(h.Health) end
        local hv = c:FindFirstChild("Health")
        if hv and hv:IsA("NumberValue") then return math.floor(hv.Value) end
        local a = c:GetAttribute("Health") or c:GetAttribute("HP")
        if a then return math.floor(tonumber(a) or 100) end
        return 100
    end
    local function getMaxHealth(c)
        if not c then return 100 end
        local h = getController(c)
        if h and h.MaxHealth then return math.floor(h.MaxHealth) end
        local hv = c:FindFirstChild("MaxHealth")
        if hv and hv:IsA("NumberValue") then return math.floor(hv.Value) end
        local a = c:GetAttribute("MaxHealth") or c:GetAttribute("MaxHP")
        if a then return math.floor(tonumber(a) or 100) end
        return 100
    end
    local function isAlive(c)
        if not c then return false end
        local h = getController(c)
        if h then
            if h.Health and h.Health <= 0 then return false end
            local ok, st = pcall(function() return h:GetState() end)
            if ok and st == Enum.HumanoidStateType.Dead then return false end
        end
        return true
    end
    local function worldToScreen(pos)
        local sp, on = S.Camera:WorldToViewportPoint(pos)
        return Vector2.new(sp.X, sp.Y), on
    end
    local function getDistance(part)
        if not part then return math.huge end
        return (part.Position - S.Camera.CFrame.Position).Magnitude
    end

    local HORSE_KW = {"horse","mule","donkey","reindeer","mustang","appaloosa","arabian","shire","clydesdale","pony","foal","colt","filly","gelding","mare","stallion","skeleton horse","tennessee","quarter","friesian","andalusian","paint","morgan","percheron","belgian","haflinger","pinto"}
    local function isHorse(m)
        if not m or not m.Name then return false end
        local n = m.Name:lower()
        for _, kw in ipairs(HORSE_KW) do if n:find(kw) then return true end end
        for _, tag in ipairs(S.CollectionService:GetTags(m)) do
            if tag:lower():find("horse") then return true end
        end
        return false
    end
    local function isLegendaryAnimal(m)
        if not m or not m.Name then return false end
        local n = m.Name:lower()
        if n:find("legendary") or n:find("mythical") then return true end
        if n == "wendigo" then return true end
        if m.Parent then
            local pn = m.Parent.Name:lower()
            if pn:find("legendary") or pn:find("mythical") or pn:find("rare") then return true end
        end
        for _, tag in ipairs(S.CollectionService:GetTags(m)) do
            local tl = tag:lower()
            if tl:find("legendary") or tl:find("mythical") or tl:find("boss") then return true end
        end
        if m:GetAttribute("Legendary") or m:GetAttribute("IsLegendary") then return true end
        if m:GetAttribute("Tier") then
            local t = tostring(m:GetAttribute("Tier")):lower()
            if t == "legendary" or t == "mythical" then return true end
        end
        return false
    end

    local ORE_TIER = {Coal="Tier 1",Copper="Tier 1",Zinc="Tier 2",Iron="Tier 3",Limestone="Tier 3",Silver="Tier 4",Gold="Tier 5",Quartz="Tier 3",Diamond="Tier 6",Emerald="Tier 6",Ruby="Tier 6",Sapphire="Tier 6",Uranium="Tier 7",["Frozen Quartz"]="Tier 6",["Mythril"]="Tier 6",["Tungsten"]="Tier 5",["Topaz"]="Tier 4"}
    local function getPickaxeTier(n)
        local t = ORE_TIER[n]
        if t then return t end
        for ore, ti in pairs(ORE_TIER) do if n:lower():find(ore:lower()) then return ti end end
        return "Tier ?"
    end
    local function getOreColor(oreName)
        local n = oreName:lower()
        if n:find("coal") then return Color3.fromRGB(50,50,50)
        elseif n:find("copper") then return Color3.fromRGB(184,115,51)
        elseif n:find("gold") then return Color3.fromRGB(255,215,0)
        elseif n:find("iron") then return Color3.fromRGB(180,180,180)
        elseif n:find("limestone") then return Color3.fromRGB(200,200,200)
        elseif n:find("quartz") then return Color3.fromRGB(255,255,255)
        elseif n:find("silver") then return Color3.fromRGB(192,192,192)
        elseif n:find("zinc") then return Color3.fromRGB(150,150,200)
        elseif n:find("diamond") then return Color3.fromRGB(185,242,255)
        elseif n:find("emerald") then return Color3.fromRGB(80,220,100)
        elseif n:find("ruby") then return Color3.fromRGB(224,17,95)
        elseif n:find("sapphire") then return Color3.fromRGB(15,82,186)
        elseif n:find("uranium") then return Color3.fromRGB(0,255,0)
        elseif n:find("mythril") then return Color3.fromRGB(100,200,255)
        elseif n:find("tungsten") then return Color3.fromRGB(100,100,120)
        elseif n:find("topaz") then return Color3.fromRGB(255,200,50)
        else return Color3.fromRGB(255,165,0) end
    end
    local function getOreRemaining(m)
        local di = m:FindFirstChild("DepositInfo")
        if di then
            local r = di:FindFirstChild("OreRemaining")
            if r and r:IsA("NumberValue") then return r.Value end
            local vi = di:FindFirstChild("VeinInfo")
            if vi then
                local vr = vi:FindFirstChild("OreRemaining")
                if vr and vr:IsA("NumberValue") then return vr.Value end
            end
        end
        return nil
    end

    local function createDrawing(t)
        local o = Drawing.new(t)
        table.insert(drawings, o)
        return o
    end
    local function cleanupDrawings()
        for _, o in ipairs(drawings) do
            pcall(function() o.Visible = false; o:Remove() end)
        end
        table.clear(drawings)
    end
    local function createHighlight(part, color, transp)
        if not isBasePart(part) then return nil end
        local h = Instance.new("Highlight")
        h.Adornee = part
        h.FillColor = color
        h.FillTransparency = transp or 0.5
        h.OutlineColor = color
        h.OutlineTransparency = math.max(0, (transp or 0.5) - 0.2)
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Enabled = true
        h.Parent = part
        return h
    end
    local function createLabel()
        local t = createDrawing("Text")
        t.Center = true
        t.Outline = true
        t.OutlineColor = Color3.fromRGB(0,0,0)
        t.Size = state.labelSize
        t.Color = Color3.fromRGB(255,255,255)
        t.Visible = false
        t.Font = 3
        return t
    end
    local function createTracer()
        local t = createDrawing("Line")
        t.From = Vector2.new(0, 0)
        t.To = Vector2.new(0, 0)
        t.Thickness = math.max(1, state.tracerThickness or 1)
        t.Transparency = state.tracerTransparency or 0.15
        t.Color = COLOR_PRESETS[state.tracerColor] or Color3.fromRGB(0,255,255)
        t.Visible = false
        pcall(function() t.ZIndex = 2 end)
        return t
    end
    local function getESP(instance)
        if not espObjects[instance] then
            espObjects[instance] = {highlight=nil, label=nil, tracer=nil, entityType=nil, chams={}}
        end
        return espObjects[instance]
    end
    local function cleanupOne(esp)
        if esp.highlight then pcall(function() esp.highlight:Destroy() end); esp.highlight = nil end
        if esp.label then esp.label.Visible = false end
        if esp.tracer then esp.tracer.Visible = false end
        if esp.chams then
            for _, hl in pairs(esp.chams) do pcall(function() hl:Destroy() end) end
            esp.chams = {}
        end
    end
    ESP.cleanup = function()
        for _, esp in pairs(espObjects) do cleanupOne(esp) end
        table.clear(espObjects)
        for bar, hl in pairs(goldBarHighlights) do pcall(function() hl:Destroy() end) end
        table.clear(goldBarHighlights)
    end

    local function clearAllChams(delay)
        delay = delay or 0.05
        local count = 0
        for _, esp in pairs(espObjects) do
            if esp.chams and next(esp.chams) then
                for _, hl in pairs(esp.chams) do
                    pcall(function() hl:Destroy() end)
                end
                esp.chams = {}
                count = count + 1
                if count % 3 == 0 then task.wait(delay) end
            end
        end
    end
    ESP.clearAllChams = function() task.spawn(function() clearAllChams(0.05) end) end

    ESP.resetHighlights = function()
        task.spawn(function()
            state.chamsResetInProgress = true
            local list = {}
            for _, esp in pairs(espObjects) do
                if esp.chams and next(esp.chams) then
                    table.insert(list, esp)
                end
            end
            for _, esp in ipairs(list) do
                for _, hl in pairs(esp.chams) do
                    pcall(function() hl:Destroy() end)
                end
                esp.chams = {}
                task.wait(1)
            end
            state.chamsResetInProgress = false
        end)
    end

    local function cleanupStale(active)
        for entity, esp in pairs(espObjects) do
            if not entity or not entity.Parent or not active[entity] then
                cleanupOne(esp)
                espObjects[entity] = nil
            end
        end
    end

    local function getHighlightPartsForModel(model, entityType, isLegendary)
        local parts = {}
        if not model then return parts end
        local seen = {}

        local function add(p)
            if p and p:IsA("BasePart") and not seen[p] then
                seen[p] = true
                table.insert(parts, p)
            elseif p and p:IsA("Accessory") then
                local handle = p:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") and not seen[handle] then
                    seen[handle] = true
                    table.insert(parts, handle)
                end
            end
        end

        if entityType == "player" or entityType == "npc" then
            local groups = state.espBodyHighlight or {}
            if #groups == 0 then return parts end
            for _, g in ipairs(groups) do
                if g == "All" then
                    for _, c in ipairs(model:GetDescendants()) do add(c) end
                    return parts
                end
            end
            for _, groupName in ipairs(groups) do
                local group = PLAYER_BODY_GROUPS[groupName]
                if group then
                    for _, name in ipairs(group) do
                        add(model:FindFirstChild(name))
                        local nested = model:FindFirstChild(name, true)
                        if nested and nested ~= model:FindFirstChild(name) then add(nested) end
                    end
                    if groupName == "Head" then
                        local head = model:FindFirstChild("Head")
                        if head then
                            for _, c in ipairs(head:GetChildren()) do add(c) end
                        end
                    end
                end
            end
        elseif entityType == "animal" or entityType == "horse" then
            if isLegendary then
                for _, c in ipairs(model:GetDescendants()) do add(c) end
            else
                local head = model:FindFirstChild("Head")
                if head then add(head) end
                local nestedHead = model:FindFirstChild("Head", true)
                if nestedHead and nestedHead ~= head then add(nestedHead) end
            end
        end
        return parts
    end

    local function renderChams(esp, m, color, entityType, isLegendary)
        esp.chams = esp.chams or {}
        if not state.chamsEnabled then
            for _, hl in pairs(esp.chams) do if hl then hl.Enabled = false end end
            return
        end
        if state.chamsResetInProgress then return end

        local parts = getHighlightPartsForModel(m, entityType or esp.entityType, isLegendary)
        if #parts == 0 then
            for _, hl in pairs(esp.chams) do if hl then hl.Enabled = false end end
            return
        end

        local isLegendaryMode = isLegendary and (entityType == "animal" or entityType == "horse")
        local fillColor = isLegendaryMode and Color3.fromRGB(255,215,0) or Color3.fromRGB(255,0,0)
        local outlineColor = isLegendaryMode and Color3.fromRGB(255,255,180) or Color3.fromRGB(255,255,255)

        local wanted = {}
        for _, part in ipairs(parts) do
            wanted[part] = true
            local hl = esp.chams[part]
            if not hl or not hl.Parent then
                hl = createHighlight(part, fillColor, 0.4)
                esp.chams[part] = hl
            end
            if hl then
                hl.FillColor = fillColor
                hl.OutlineColor = outlineColor
                hl.FillTransparency = 0.4
                hl.OutlineTransparency = 0.1
                hl.Enabled = true
            end
        end
        for part, hl in pairs(esp.chams) do
            if not wanted[part] then
                pcall(function() hl:Destroy() end)
                esp.chams[part] = nil
            end
        end
    end

    local function renderEntityESP(esp, part, params)
        local color = params.color
        local ho = params.heightOffset or 2
        local showHp = params.showHealthData
        local char = params.character
        local name = params.name
        local dist = params.distance
        local isLeg = params.isLegendary
        local hTrans = (isLeg and state.legendaryGoldenMode) and 0.3 or 0.5
        local isPlayer = (esp.entityType == "player")
        local showT = params.showTracers
        if showT == nil then showT = state.showTracers end

        if not esp.highlight or not esp.highlight.Parent then
            esp.highlight = createHighlight(part, color, hTrans)
        elseif esp.highlight then
            esp.highlight.Adornee = part
            esp.highlight.FillColor = color
            esp.highlight.OutlineColor = color
            esp.highlight.FillTransparency = hTrans
            esp.highlight.Enabled = true
        end

        if not esp.label then esp.label = createLabel() end
        local worldHead = part.Position + Vector3.new(0, ho, 0)
        local sp, on = worldToScreen(worldHead)
        if on then
            local tp = {}
            if state.showNames and name then
                tp[#tp+1] = (isLeg and state.legendaryGoldenMode) and ("⭐ "..name.." ⭐") or name
            end
            if state.showDistance and dist then tp[#tp+1] = string.format("%.0f studs", dist) end
            if state.showHealth and showHp and char then
                tp[#tp+1] = string.format("%.0f/%.0f HP", getHealth(char), getMaxHealth(char))
            end
            esp.label.Text = table.concat(tp, " | ")
            esp.label.Color = color
            esp.label.Position = Vector2.new(sp.X, sp.Y - 35)
            esp.label.Visible = true
        else
            esp.label.Visible = false
        end

        if esp.tracer then esp.tracer.Visible = false end
        local distOk = (dist and dist <= CHAMS_TRACER_MAX_DIST) or (dist == nil)
        if isPlayer and showT and distOk and part then
            local feetWorld = part.Position - Vector3.new(0, ho, 0)
            local feetSp3 = S.Camera:WorldToViewportPoint(feetWorld)
            if feetSp3.Z > 0 then
                if not esp.tracer then esp.tracer = createTracer() end
                local vp = S.Camera.ViewportSize
                esp.tracer.From         = Vector2.new(math.floor(vp.X * 0.5), math.floor(vp.Y))
                esp.tracer.To           = Vector2.new(feetSp3.X, feetSp3.Y)
                esp.tracer.Color        = COLOR_PRESETS[state.tracerColor] or Color3.fromRGB(0,255,255)
                esp.tracer.Thickness    = math.max(1, state.tracerThickness or 1)
                esp.tracer.Transparency = state.tracerTransparency or 0.15
                pcall(function() esp.tracer.ZIndex = 2 end)
                esp.tracer.Visible      = true
            end
        end
    end

    local function isThunderstruckName(name)
        if not name then return false end
        local n = name:lower()
        return n:find("thunderstruck", 1, true) ~= nil or n:find("thunder", 1, true) ~= nil
    end
    local function updateThunderstruck(active)
        if not state.showThunderstruck then return end
        local geo = getFolder("WORKSPACE_Geometry")
        if not geo then return end
        for _, regionName in ipairs(REGIONS) do
            local region = geo:FindFirstChild(regionName)
            if region then
                for _, obj in ipairs(region:GetDescendants()) do
                    if (obj:IsA("Model") or obj:IsA("Folder")) and isThunderstruckName(obj.Name) then
                        local p = (obj:IsA("Model") and getTargetPart(obj)) or obj:FindFirstChildWhichIsA("BasePart", true)
                        if p then
                            local d = getDistance(p)
                            if state.maxDistance == 0 or d <= state.maxDistance then
                                active[obj] = true
                                local esp = getESP(obj)
                                esp.entityType = "thunderstruck"
                                local c = COLOR_PRESETS[state.thunderstruckColor] or Color3.fromRGB(255,255,60)
                                renderEntityESP(esp, p, {color=c, heightOffset=4, showHealthData=false,
                                    name="⚡ "..obj.Name, distance=d, showTracers=false})
                            end
                        end
                    end
                end
            end
        end
    end

    local function updateESPInternal()
        if not state.espEnabled or state.destroyed then
            for _, esp in pairs(espObjects) do
                if esp.highlight then esp.highlight.Enabled = false end
                if esp.label then esp.label.Visible = false end
                if esp.tracer then esp.tracer.Visible = false end
                if esp.chams then
                    for _, hl in pairs(esp.chams) do if hl then hl.Enabled = false end end
                end
            end
            if not state.highlightGoldBars then updateGoldBars() end
            return
        end
        local now = os.clock()
        if now - ESP.lastUpdate < state.updateInterval then return end
        ESP.lastUpdate = now
        local active = {}

        if state.showPlayers then
            for _, player in ipairs(S.Players:GetPlayers()) do
                if player ~= S.LocalPlayer then
                    local char = getCharacter(player)
                    if char and isAlive(char) then
                        local root = getRoot(char)
                        if root then
                            local d = getDistance(root)
                            if state.maxDistance == 0 or d <= state.maxDistance then
                                local p = getTargetPart(char)
                                if p then
                                    active[char] = true
                                    local esp = getESP(char)
                                    esp.entityType = "player"
                                    local c = COLOR_PRESETS[state.playerColor] or Color3.fromRGB(60,255,60)
                                    local within500 = (d <= CHAMS_TRACER_MAX_DIST)
                                    renderEntityESP(esp, p, {color=c, heightOffset=2, showHealthData=false,
                                        character=char, name=player.Name, distance=d,
                                        showTracers=(state.showTracers and within500)})
                                    if within500 then
                                        renderChams(esp, char, c, "player", false)
                                    elseif esp.chams then
                                        for _, hl in pairs(esp.chams) do if hl then hl.Enabled = false end end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if state.showNPCs then
            local ef = S.Workspace:FindFirstChild("WORKSPACE_Entities")
            local nf = ef and ef:FindFirstChild("NPCs")
            if nf then
                for _, n in pairs(nf:GetChildren()) do
                    local char = n
                    local modelFolder = n:FindFirstChild("Model")
                    if modelFolder then
                        local nm = modelFolder:FindFirstChild("NPCTemplateNoHumanV4")
                        if nm and nm:IsA("Model") then char = nm end
                        if not char or not char:FindFirstChildOfClass("Humanoid") then
                            local alt = modelFolder:FindFirstChildWhichIsA("Model", true)
                            if alt and alt:FindFirstChildOfClass("Humanoid") then char = alt end
                        end
                    end
                    if not char:IsA("Model") or not char:FindFirstChildOfClass("Humanoid") then
                        local alt = n:FindFirstChildWhichIsA("Model", true)
                        if alt then char = alt end
                    end
                    if char and char:IsA("Model") and n.Name ~= S.LocalPlayer.Name and isAlive(char) then
                        local root = getRoot(char)
                        if root then
                            local d = getDistance(root)
                            if state.maxDistance == 0 or d <= state.maxDistance then
                                local p = getTargetPart(char)
                                if p then
                                    active[n] = true
                                    local esp = getESP(n)
                                    esp.entityType = "npc"
                                    local c = COLOR_PRESETS[state.npcColor] or Color3.fromRGB(255,255,0)
                                    renderEntityESP(esp, p, {color=c, heightOffset=2, showHealthData=true,
                                        character=char, name=n.Name, distance=d, showTracers=false})
                                    local within500 = (d <= CHAMS_TRACER_MAX_DIST)
                                    if within500 then
                                        renderChams(esp, char, c, "npc", false)
                                    elseif esp.chams then
                                        for _, hl in pairs(esp.chams) do if hl then hl.Enabled = false end end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if state.showAnimals or state.showHorses then
            local af = getFolder("WORKSPACE_Entities.Animals")
            if af then
                local animalFilterList = state.animalFilter or {}
                local hasAnimalFilter = #animalFilterList > 0
                local filterSet = nil
                if hasAnimalFilter then
                    filterSet = {}
                    for _, n in ipairs(animalFilterList) do filterSet[n] = true end
                end
                for _, animal in pairs(af:GetChildren()) do
                    if animal:IsA("Model") then
                        local isH = isHorse(animal)
                        local isLeg = (not isH) and isLegendaryAnimal(animal)
                        local skip = false
                        if isH and not state.showHorses then skip = true end
                        if (not isH) and not state.showAnimals then skip = true end
                        if (not isH) and (not isLeg) and state.showLegendaryOnly then skip = true end
                        if (not isH) and (not isLeg) and hasAnimalFilter then
                            if not filterSet[animal.Name] then skip = true end
                        end
                        if not skip then
                            local p = getTargetPart(animal)
                            if p then
                                local d = getDistance(p)
                                if state.maxDistance == 0 or d <= state.maxDistance then
                                    active[animal] = true
                                    local esp = getESP(animal)
                                    esp.entityType = isH and "horse" or "animal"
                                    local c
                                    if isH then c = COLOR_PRESETS[state.horseColor] or Color3.fromRGB(0,255,255)
                                    elseif isLeg then c = Color3.fromRGB(255,215,0)
                                    else c = COLOR_PRESETS[state.animalColor] or Color3.fromRGB(255,255,255) end
                                    renderEntityESP(esp, p, {color=c, heightOffset=2, showHealthData=true,
                                        character=animal, name=animal.Name, distance=d,
                                        isLegendary=isLeg, showTracers=false})
                                    local within500 = (d <= CHAMS_TRACER_MAX_DIST)
                                    if within500 then
                                        renderChams(esp, animal, c, esp.entityType, isLeg)
                                    elseif esp.chams then
                                        for _, hl in pairs(esp.chams) do if hl then hl.Enabled = false end end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if state.showOres then
            local i = S.Workspace:FindFirstChild("WORKSPACE_Interactables")
            local mf = i and i:FindFirstChild("Mining")
            local od = mf and mf:FindFirstChild("OreDeposits")
            if od then
                for _, oreF in pairs(od:GetChildren()) do
                    if oreF:IsA("Folder") then
                        local typeName = oreF.Name
                        local tier = getPickaxeTier(typeName)
                        local baseC = getOreColor(typeName)
                        for _, oreM in pairs(oreF:GetChildren()) do
                            if oreM:IsA("Model") then
                                local p = getTargetPart(oreM)
                                if p then
                                    local d = getDistance(p)
                                    if state.maxDistance == 0 or d <= state.maxDistance then
                                        active[oreM] = true
                                        local esp = getESP(oreM)
                                        esp.entityType = "ore"
                                        local rem = getOreRemaining(oreM)
                                        if not esp.highlight or not esp.highlight.Parent then
                                            esp.highlight = createHighlight(p, baseC, 0.5)
                                        elseif esp.highlight then
                                            esp.highlight.Adornee = p
                                            esp.highlight.FillColor = baseC
                                            esp.highlight.OutlineColor = baseC
                                            esp.highlight.Enabled = true
                                        end
                                        if not esp.label then esp.label = createLabel() end
                                        if esp.tracer then esp.tracer.Visible = false end
                                        local sp, on = worldToScreen(p.Position + Vector3.new(0, 2, 0))
                                        if on then
                                            local tp = {}
                                            if state.showOreCount and rem then tp[#tp+1] = "🔨 "..tostring(rem) end
                                            if state.showOreTier then tp[#tp+1] = tier end
                                            if state.showNames then tp[#tp+1] = typeName end
                                            if state.showDistance then tp[#tp+1] = string.format("%.0f studs", d) end
                                            esp.label.Text = table.concat(tp, " | ")
                                            esp.label.Color = baseC
                                            esp.label.Position = Vector2.new(sp.X, sp.Y - 30)
                                            esp.label.Visible = true
                                        else
                                            esp.label.Visible = false
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if state.showItems then
            local i = S.Workspace:FindFirstChild("WORKSPACE_Interactables")
            local di = i and i:FindFirstChild("DroppedItems")
            if di then
                for _, item in pairs(di:GetChildren()) do
                    local p
                    if item:IsA("Model") then p = getTargetPart(item)
                    elseif item:IsA("BasePart") then p = item end
                    if p then
                        local d = getDistance(p)
                        if state.maxDistance == 0 or d <= state.maxDistance then
                            active[item] = true
                            local esp = getESP(item)
                            esp.entityType = "item"
                            local c = COLOR_PRESETS[state.itemColor] or Color3.fromRGB(0,255,255)
                            if not esp.highlight or not esp.highlight.Parent then
                                esp.highlight = createHighlight(p, c, 0.5)
                            elseif esp.highlight then
                                esp.highlight.Adornee = p
                                esp.highlight.FillColor = c
                                esp.highlight.OutlineColor = c
                                esp.highlight.Enabled = true
                            end
                            if not esp.label then esp.label = createLabel() end
                            local sp, on = worldToScreen(p.Position + Vector3.new(0, 2, 0))
                            if on then
                                local tp = {}
                                if state.showNames then tp[#tp+1] = "📦 "..item.Name end
                                if state.showDistance then tp[#tp+1] = string.format("%.0f studs", d) end
                                esp.label.Text = table.concat(tp, " | ")
                                esp.label.Color = c
                                esp.label.Position = Vector2.new(sp.X, sp.Y - 30)
                                esp.label.Visible = true
                            else
                                esp.label.Visible = false
                            end
                        end
                    end
                end
            end
        end

        if state.showChests then
            local i = S.Workspace:FindFirstChild("WORKSPACE_Interactables")
            local lc = i and i:FindFirstChild("LootChests")
            if lc then
                for _, chest in ipairs(lc:GetChildren()) do
                    if chest:IsA("Model") then
                        local p = getTargetPart(chest)
                        if p then
                            local d = getDistance(p)
                            if state.maxDistance == 0 or d <= state.maxDistance then
                                active[chest] = true
                                local esp = getESP(chest)
                                esp.entityType = "chest"
                                local c = COLOR_PRESETS[state.chestColor] or Color3.fromRGB(255,0,255)
                                renderEntityESP(esp, p, {color=c, heightOffset=2, showHealthData=false,
                                    name="📦 "..chest.Name, distance=d, showTracers=false})
                            end
                        end
                    end
                end
            end
        end

        if state.showTrains then
            local rt = getFolder("WORKSPACE_Trains.RunningTrains")
            if rt then
                for _, train in ipairs(rt:GetChildren()) do
                    if train:IsA("Model") then
                        local p = getTargetPart(train)
                        if p then
                            local d = getDistance(p)
                            if state.maxDistance == 0 or d <= state.maxDistance then
                                active[train] = true
                                local esp = getESP(train)
                                esp.entityType = "train"
                                local c = COLOR_PRESETS[state.trainColor] or Color3.fromRGB(255,60,60)
                                renderEntityESP(esp, p, {color=c, heightOffset=5, showHealthData=false,
                                    name="🚂 "..train.Name, distance=d, showTracers=false})
                            end
                        end
                    end
                end
            end
        end

        if state.showTerritories then
            local t = getFolder("WORKSPACE_Interactables.Territories")
            if t then
                for _, terr in ipairs(t:GetChildren()) do
                    if terr:IsA("Folder") then
                        local p = terr:FindFirstChildWhichIsA("BasePart", true)
                        if p then
                            local d = getDistance(p)
                            if state.maxDistance == 0 or d <= state.maxDistance then
                                active[terr] = true
                                local esp = getESP(terr)
                                esp.entityType = "territory"
                                local c = COLOR_PRESETS[state.territoryColor] or COLOR_PRESETS.Purple
                                renderEntityESP(esp, p, {color=c, heightOffset=10, showHealthData=false,
                                    name="🏴 "..terr.Name, distance=d, showTracers=false})
                            end
                        end
                    end
                end
            end
        end

        if state.showFish then
            local f = getFolder("WORKSPACE_Entities.Fish")
            if f then
                for _, fish in ipairs(f:GetChildren()) do
                    if fish:IsA("Model") then
                        local p = getTargetPart(fish)
                        if p then
                            local d = getDistance(p)
                            if state.maxDistance == 0 or d <= state.maxDistance then
                                active[fish] = true
                                local esp = getESP(fish)
                                esp.entityType = "fish"
                                local c = COLOR_PRESETS[state.fishColor] or Color3.fromRGB(0,150,255)
                                renderEntityESP(esp, p, {color=c, heightOffset=1, showHealthData=false,
                                    name="🐟 "..fish.Name, distance=d, showTracers=false})
                            end
                        end
                    end
                end
            end
        end

        if state.showDeadAnimals then
            local df = getFolder("WORKSPACE_Entities.DeadAnimals")
            if df then
                for _, dead in ipairs(df:GetChildren()) do
                    if dead:IsA("Model") then
                        local p = getTargetPart(dead)
                        if p then
                            local d = getDistance(p)
                            if state.maxDistance == 0 or d <= state.maxDistance then
                                active[dead] = true
                                local esp = getESP(dead)
                                esp.entityType = "deadAnimal"
                                local c = COLOR_PRESETS[state.deadAnimalColor] or Color3.fromRGB(255,60,60)
                                renderEntityESP(esp, p, {color=c, heightOffset=1, showHealthData=false,
                                    name="💀 "..dead.Name, distance=d, showTracers=false})
                            end
                        end
                    end
                end
            end
        end

        updateThunderstruck(active)
        updateGoldBars()
        cleanupStale(active)
    end

    ESP.update = function()
        local ok, err = pcall(updateESPInternal)
        if not ok then
            warn("[TWW] ESP.update error: "..tostring(err))
        end
    end

    ESP.refresh = refreshCache
    ESP.cleanupDrawings = cleanupDrawings
    ESP.isAlive = isAlive
    ESP.isLegendaryAnimal = isLegendaryAnimal
    ESP.getHealth = getHealth
    ESP.getMaxHealth = getMaxHealth
    ESP.getTargetPart = getTargetPart
    ESP.getRoot = getRoot
    ESP.getDistance = getDistance
    ESP.worldToScreen = worldToScreen
    ESP.setLabelSize = function(size)
        for _, esp in pairs(espObjects) do
            if esp.label then esp.label.Size = size end
        end
    end
end

-- =================================================================
--  CHAR
-- =================================================================
local function initChar()
    local PC = nil
    local Orig = {}
    local NetHooked = false
    local PinnedHorse = nil
    local ready = false
    local PIN_MT = {
        __index = function(_, key) if key == "Stamina" then return 100 end return nil end,
        __newindex = function(t, key, value) if key == "Stamina" then return end rawset(t, key, value) end,
    }
    local function ensureWritable(t)
        if typeof(t) ~= "table" then return end
        if type(isreadonly) == "function" and isreadonly(t) then
            pcall(function()
                if type(setreadonly) == "function" then setreadonly(t, false)
                elseif type(makewritable) == "function" then makewritable(t) end
            end)
        end
    end
    local function looksLikeOriginal(f)
        if typeof(f) ~= "function" then return false end
        local info = debug.getinfo(f)
        return (info.nups or 0) > 0 or (info.numparams or info.nump or 0) > 0
    end
    local function refreshPC()
        local pc = Global.PlayerCharacter
        if typeof(pc) == "table" and pc ~= PC then
            PC = pc
            if looksLikeOriginal(pc.LowerStamina) then
                Orig.LowerStamina = pc.LowerStamina
                Orig.LocalLowerStamina = pc.LocalLowerStamina
            end
            if looksLikeOriginal(pc.Ragdoll) then
                Orig.Ragdoll = pc.Ragdoll
                Orig.RequestKnockback = pc.RequestKnockback
                Orig.ToggleSelfRagdoll = pc.ToggleSelfRagdoll
                Orig.OnControlLost = pc.OnControlLost
            end
        end
        return PC
    end

    local function hookFireServer()
        local Network = Global.Network
        ensureWritable(Network)
        if not Orig.FireServer then Orig.FireServer = Network.FireServer end
        if NetHooked then return end
        NetHooked = true
        Network.FireServer = function(self, eventName, ...)
            if state.antiRagdoll then
                if eventName == "EnterRagdoll" or eventName == "DamageSelf" then return end
            end
            if state.antiFallDamage and not state.antiRagdoll then
                if eventName == "DamageSelf" then return end
            end
            if state.infiniteStamina and eventName == "LowerStamina" then return end
            return Orig.FireServer(self, eventName, ...)
        end
    end
    local function unhookFireServer()
        if not NetHooked then return end
        NetHooked = false
        if Orig.FireServer then
            ensureWritable(Global.Network)
            Global.Network.FireServer = Orig.FireServer
        end
    end
    CHAR.hookFireServer = hookFireServer
    CHAR.unhookFireServer = unhookFireServer

    local function applyInfiniteStamina()
        if not ready then return false end
        local pc = refreshPC()
        if not pc then return false end
        ensureWritable(pc)
        pc.LowerStamina = function() end
        pc.LocalLowerStamina = function() end
        local ps = Global.ReplicatedState.State
        ensureWritable(ps)
        if getmetatable(ps) ~= PIN_MT then pcall(function() setmetatable(ps, PIN_MT) end) end
        rawset(ps, "Stamina", nil)
        pcall(function()
            local sig = Global.ReplicatedState:GetStateChangedSignal("Stamina")
            if sig and sig.Fire then sig:Fire() end
        end)
        return true
    end
    local function removeInfiniteStamina()
        if not ready then return end
        local pc = PC or Global.PlayerCharacter
        if typeof(pc) == "table" then
            ensureWritable(pc)
            if Orig.LowerStamina then pc.LowerStamina = Orig.LowerStamina end
            if Orig.LocalLowerStamina then pc.LocalLowerStamina = Orig.LocalLowerStamina end
        end
        local ps = Global.ReplicatedState and Global.ReplicatedState.State
        if typeof(ps) == "table" and getmetatable(ps) == PIN_MT then
            pcall(function() setmetatable(ps, nil) end)
            rawset(ps, "Stamina", 100)
        end
    end

    -- ============ ANTI RAGDOLL (only local player) ============
    local function applyAntiRagdoll()
        if not ready then return false end
        local pc = refreshPC()
        if not pc then return false end
        ensureWritable(pc)
        pc.Ragdoll = function() end
        pc.RequestKnockback = function() end
        pc.ToggleSelfRagdoll = function() end
        pc.OnControlLost = function() end

        local R = Global.Ragdolls
        ensureWritable(R)
        if not Orig.RagdollsEnterRagdoll then
            Orig.RagdollsEnterRagdoll = R.EnterRagdoll
        end

        -- Only block ragdoll for the LOCAL player's own character.
        -- Other players / NPCs / animals still ragdoll normally.
        R.EnterRagdoll = function(self, char, ...)
            local localChar = Global.PlayerCharacter and Global.PlayerCharacter.Character
            if char and localChar and char == localChar then
                return
            end
            return Orig.RagdollsEnterRagdoll(self, char, ...)
        end
        return true
    end
    local function removeAntiRagdoll()
        if not ready then return end
        local pc = PC or Global.PlayerCharacter
        if typeof(pc) == "table" then
            ensureWritable(pc)
            if Orig.Ragdoll then pc.Ragdoll = Orig.Ragdoll end
            if Orig.RequestKnockback then pc.RequestKnockback = Orig.RequestKnockback end
            if Orig.ToggleSelfRagdoll then pc.ToggleSelfRagdoll = Orig.ToggleSelfRagdoll end
            if Orig.OnControlLost then pc.OnControlLost = Orig.OnControlLost end
        end
        local R = Global.Ragdolls
        if typeof(R) == "table" and Orig.RagdollsEnterRagdoll then
            ensureWritable(R)
            R.EnterRagdoll = Orig.RagdollsEnterRagdoll
        end
    end

    local function applyAntiFallDamage() return true end
    local function removeAntiFallDamage() return end

    local function makeHorsePinMT(origMT)
        local origIndex = origMT and origMT.__index
        return {
            __TWW_PIN = true,
            __index = function(t, key)
                if key == "Boosts" then return rawget(t, "MaxBoosts") or rawget(t, "StaminaValue") or 5 end
                local own = rawget(t, key)
                if own ~= nil then return own end
                if origIndex ~= nil then
                    if type(origIndex) == "function" then return origIndex(t, key) end
                    return origIndex[key]
                end
                return nil
            end,
            __newindex = function(t, key, value)
                if key == "Boosts" then return end
                rawset(t, key, value)
            end,
        }
    end
    local function applyHorseStamina()
        if not ready then return false end
        local animal = Global.WildLife and Global.WildLife.RidingAnimal
        if typeof(animal) ~= "table" then return false end
        local mt = getmetatable(animal)
        if typeof(mt) == "table" and mt.__TWW_PIN then return true end
        ensureWritable(animal)
        PinnedHorse = {animal=animal, origMT=mt}
        pcall(function() setmetatable(animal, makeHorsePinMT(mt)) end)
        rawset(animal, "Boosts", nil)
        return true
    end
    local function removeHorseStamina()
        if not PinnedHorse then return end
        local animal = PinnedHorse.animal
        if typeof(animal) == "table" then
            ensureWritable(animal)
            pcall(function() setmetatable(animal, PinnedHorse.origMT) end)
            rawset(animal, "Boosts", rawget(animal, "MaxBoosts") or 3)
        end
        PinnedHorse = nil
    end

    CHAR.sync = function()
        if not ready or state.destroyed then return end
        if state.infiniteStamina then applyInfiniteStamina() else removeInfiniteStamina() end
        if state.antiRagdoll then
            applyAntiRagdoll()
        else
            removeAntiRagdoll()
            if state.antiFallDamage then applyAntiFallDamage() else removeAntiFallDamage() end
        end
        if state.infiniteHorseStamina then applyHorseStamina() else removeHorseStamina() end
        if state.infiniteStamina or state.antiRagdoll or state.antiFallDamage then hookFireServer() else unhookFireServer() end
    end
    CHAR.applyInfiniteStamina = applyInfiniteStamina
    CHAR.removeInfiniteStamina = removeInfiniteStamina
    CHAR.applyAntiRagdoll = applyAntiRagdoll
    CHAR.removeAntiRagdoll = removeAntiRagdoll
    CHAR.applyAntiFallDamage = applyAntiFallDamage
    CHAR.removeAntiFallDamage = removeAntiFallDamage
    CHAR.applyHorseStamina = applyHorseStamina
    CHAR.removeHorseStamina = removeHorseStamina
    CHAR.refreshPC = refreshPC

    task.spawn(function()
        local t0 = os.clock()
        while not ready and not state.destroyed do
            local shared = S.ReplicatedStorage:FindFirstChild("SharedModules")
            local gm = shared and shared:FindFirstChild("Global")
            if gm then
                local ok, result = pcall(require, gm)
                if ok and type(result) == "table" and result.PlayerCharacter
                    and result.ReplicatedState and result.Network and result.Ragdolls and result.WildLife then
                    Global = result
                    ready = true
                    break
                end
            end
            if os.clock() - t0 > 60 then return end
            task.wait(0.25)
        end
        CHAR.sync()
        if AMMO.install then AMMO.install() end
        if Water then Water.reapply() end
    end)

    task.spawn(function()
        while not state.destroyed do
            task.wait(2)
            if ready then
                pcall(function()
                    if Global.PlayerCharacter ~= PC then
                        refreshPC()
                    end
                    if state.infiniteStamina or state.antiRagdoll or state.antiFallDamage or state.infiniteHorseStamina then
                        CHAR.sync()
                    end
                    if not NetHooked and (state.infiniteStamina or state.antiRagdoll or state.antiFallDamage) then
                        hookFireServer()
                    end
                end)
            end
        end
    end)
end

-- =================================================================
--  COMBAT
-- =================================================================
local function initCombat()
    local COMBAT_MAX_DISTANCE = 1000
    local VALID_PLAYER_PARTS = {"Head","UpperTorso","LowerTorso","LeftUpperArm","LeftLowerArm","RightUpperArm","RightLowerArm","LeftUpperLeg","LeftLowerLeg","RightUpperLeg","RightLowerLeg","LeftHand","RightHand","LeftFoot","RightFoot"}
    local PLAYER_FB = {Head={"Head","UpperTorso","LowerTorso"}, UpperTorso={"UpperTorso","LowerTorso","Head"}, LowerTorso={"LowerTorso","UpperTorso","Head"}}
    local ANIMAL_FB = {Head={"Head","Body","Neck"}, UpperTorso={"Body","Head","Neck"}, LowerTorso={"Body","Head","LeftThigh","RightThigh"}}
    local ANIMAL_KW = {"head","body","neck","leg","thigh","hoof","foot","arm","shoulder","paw"}
    local ANIMAL_EXCL = {"humanoidrootpart","eye","nose","snout","ear","antler","collision","hitbox"}
    local visParams = RaycastParams.new()
    visParams.FilterType = Enum.RaycastFilterType.Exclude
    visParams.IgnoreWater = true
    local function nameMatches(name, kws)
        local l = name:lower()
        for _, k in ipairs(kws) do if l:find(k, 1, true) then return true end end
        return false
    end
    local function getOwnMount()
        local r = Global and Global.WildLife and Global.WildLife.RidingAnimal
        if type(r) == "table" and r.hrp and typeof(r.hrp) == "Instance" then return r.hrp.Parent end
        return nil
    end
    local function getOwnRep()
        local e = S.Workspace:FindFirstChild("WORKSPACE_Entities")
        if not e then return nil end
        local pf = e:FindFirstChild("Players")
        if pf then return pf:FindFirstChild(S.LocalPlayer.Name) end
        return nil
    end
    local function collectRigParts(rig, isAnimal)
        local parts = {}
        if not rig then return parts end
        if isAnimal then
            for _, c in ipairs(rig:GetChildren()) do
                if c:IsA("BasePart") and not nameMatches(c.Name, ANIMAL_EXCL) and nameMatches(c.Name, ANIMAL_KW) then
                    table.insert(parts, c)
                end
            end
        else
            for _, n in ipairs(VALID_PLAYER_PARTS) do
                local p = rig:FindFirstChild(n)
                if p and p:IsA("BasePart") then table.insert(parts, p) end
            end
        end
        return parts
    end
    local function getNpcRig(folder)
        local m = folder:FindFirstChild("Model")
        if not m then return nil end
        local h = m:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then return nil end
        local rp = m:FindFirstChild("HumanoidRootPart", true)
        if not rp or not rp.Parent then return nil end
        return rp.Parent
    end
    local function resolveAimPart(rig, isAnimal)
        if not rig then return nil end
        local choice = state.targetPart
        if choice == "Random" or choice == "Closest" then
            local parts = collectRigParts(rig, isAnimal)
            if #parts == 0 then return nil end
            if choice == "Random" then return parts[math.random(#parts)] end
            local camPos = S.Camera.CFrame.Position
            local camLook = S.Camera.CFrame.LookVector
            local best, bestPerp = nil, math.huge
            for _, p in ipairs(parts) do
                local rel = p.Position - camPos
                local along = rel:Dot(camLook)
                if along > 0 then
                    local perp = (rel - camLook * along).Magnitude
                    if perp < bestPerp then bestPerp = perp; best = p end
                end
            end
            return best or parts[1]
        end
        local fb = isAnimal and ANIMAL_FB or PLAYER_FB
        local chain = fb[choice]
        if not chain then return nil end
        for _, n in ipairs(chain) do
            local p = rig:FindFirstChild(n)
            if p and p:IsA("BasePart") then return p end
        end
        return nil
    end
    local function isVisible(origin, part, model)
        local filter = {}
        local char = S.LocalPlayer.Character
        if char then table.insert(filter, char) end
        local om = getOwnRep()
        if om and om ~= char then table.insert(filter, om) end
        visParams.FilterDescendantsInstances = filter
        local result = S.Workspace:Raycast(origin, part.Position - origin, visParams)
        if not result then return true end
        return result.Instance:IsDescendantOf(model)
    end
    COMBAT.getBestTarget = function(origin)
        local Entities = S.Workspace:FindFirstChild("WORKSPACE_Entities")
        if not Entities then return nil end
        local camCF = S.Camera.CFrame
        local camPos = camCF.Position
        local camLook = camCF.LookVector
        local halfFov = state.fov * 0.5
        local maxDist = COMBAT_MAX_DISTANCE
        local best = nil
        local function evaluate(model, part, kind, name)
            if not part or not part:IsA("BasePart") then return end
            local toPart = part.Position - camPos
            local dist = toPart.Magnitude
            if dist < 2 or dist > maxDist then return end
            local angle = math.deg(math.acos(math.clamp(camLook:Dot(toPart.Unit), -1, 1)))
            if angle > halfFov then return end
            if state.visibilityCheck and not isVisible(origin, part, model) then return end
            if not best or angle < best.angle or (angle == best.angle and dist < best.dist) then
                best = {model=model, part=part, kind=kind, name=name, dist=dist, angle=angle}
            end
        end
        local function preFilter(model)
            local r = model:FindFirstChild("HumanoidRootPart", true)
            if not r then return false end
            local toR = r.Position - camPos
            local d = toR.Magnitude
            if d < 2 or d > maxDist + 15 then return false end
            local a = math.deg(math.acos(math.clamp(camLook:Dot(toR.Unit), -1, 1)))
            if a > halfFov + 20 then return false end
            return true
        end
        if state.targetPlayers then
            local f = Entities:FindFirstChild("Players")
            if f then
                for _, m in ipairs(f:GetChildren()) do
                    if m.Name ~= S.LocalPlayer.Name and preFilter(m) then
                        local h = m:FindFirstChildOfClass("Humanoid")
                        if h and h.Health > 0 then
                            evaluate(m, resolveAimPart(m, false), "Player", m.Name)
                        end
                    end
                end
            end
        end
        if state.targetAnimals then
            local f = Entities:FindFirstChild("Animals")
            local om = getOwnMount()
            if f then
                for _, m in ipairs(f:GetChildren()) do
                    if m ~= om and preFilter(m) then
                        if state.showLegendaryOnly and not ESP.isLegendaryAnimal(m) then
                        else
                            evaluate(m, resolveAimPart(m, true), "Animal", m.Name)
                        end
                    end
                end
            end
        end
        if state.targetNPCs then
            local f = Entities:FindFirstChild("NPCs")
            if f then
                for _, n in ipairs(f:GetChildren()) do
                    if preFilter(n) then
                        local rig = getNpcRig(n)
                        if rig then evaluate(n, resolveAimPart(rig, false), "NPC", n.Name) end
                    end
                end
            end
        end
        return best
    end
end

-- =================================================================
--  HOOKS
-- =================================================================
local function initHooks()
    local installed = false
    local ProjectileHandler = Global and Global.ProjectileHandler
    local GameCamera = Global and Global.Camera
    local oldInitProjectiles = ProjectileHandler and ProjectileHandler.InitProjectiles
    local oldAddRecoil = GameCamera and GameCamera.AddRecoil
    local oldVibrate = GameCamera and GameCamera.Vibrate

    HOOKS.applyNoRecoil = function(enabled)
        if type(GameCamera) ~= "table" then return end
        if enabled then
            GameCamera.AddRecoil = function() end
            GameCamera.Vibrate = function() end
        else
            GameCamera.AddRecoil = oldAddRecoil
            GameCamera.Vibrate = oldVibrate
        end
    end

    local function initProjectilesHook(self, projType, sharedData, params, callback)
        if type(params) == "table"
            and typeof(params.origin) == "Vector3"
            and typeof(params.direction) == "Vector3" then
            local redirected = false
            if state.silentAim then
                local okT, target = pcall(COMBAT.getBestTarget, params.origin)
                if okT and target then
                    local aimPos = target.part.Position

                    -- ============ MOVEMENT PREDICTION ============
                    if state.silentAimPrediction and (state.silentAimPredictionStrength or 0) > 0 then
                        -- 1. Target velocity (part first, then root fallback)
                        local tVel = target.part.AssemblyLinearVelocity
                        if (not tVel) or tVel.Magnitude < 0.1 then
                            local root
                            if target.model then
                                root = target.model:FindFirstChild("HumanoidRootPart")
                                    or target.model:FindFirstChild("RootPart")
                            end
                            if root and root.AssemblyLinearVelocity then
                                tVel = root.AssemblyLinearVelocity
                            end
                        end

                        if tVel then
                            -- 2. Estimate projectile speed
                            local projSpeed = 1000
                            if type(sharedData) == "table" then
                                if projType == "ArrowProjectile" or projType == "ServerArrowProjectile"
                                    or projType == "DartProjectile" then
                                    local power = params.power or 0.5
                                    if params.ammoType == "ExplosiveArrow" then
                                        local minE = sharedData.MinPowerExplosive or sharedData.MinPower or 100
                                        local maxE = sharedData.MaxPowerExplosive or sharedData.MaxPower or 500
                                        projSpeed = minE + (maxE - minE) * power
                                    else
                                        local minP = sharedData.MinPower or 100
                                        local maxP = sharedData.MaxPower or 500
                                        projSpeed = minP + (maxP - minP) * power
                                    end
                                elseif projType == "TomahawkProjectile" then
                                    local power = params.power or 0.5
                                    projSpeed = 80 + (200 - 80) * power
                                elseif type(sharedData.ProjectilePower) == "number"
                                    and sharedData.ProjectilePower > 0 then
                                    projSpeed = sharedData.ProjectilePower
                                end
                            end
                            if projSpeed <= 0 then projSpeed = 1000 end

                            -- 3. Time-to-target and lead the shot
                            local dist = (aimPos - params.origin).Magnitude
                            local ttt  = dist / projSpeed
                            aimPos = aimPos + tVel * (ttt * state.silentAimPredictionStrength)
                        end
                    end
                    -- ==============================================

                    local delta = aimPos - params.origin
                    if delta.Magnitude > 0.01 then
                        params.direction = delta.Unit
                        redirected = true
                        if state.debugPrints then
                            print(string.format("[TWW] %s -> %s (%s) | %.1f° | %d studs | pred %.2fx",
                                tostring(projType), tostring(target.name), target.kind,
                                target.angle, math.floor(target.dist),
                                state.silentAimPrediction and state.silentAimPredictionStrength or 0))
                        end
                    end
                end
            end
            if state.noSpread then
                if not redirected then
                    params.direction = S.Camera.CFrame.LookVector
                end
                params.accuracy = 1
                if typeof(params.spread) == "number" then params.spread = 0 end
                if typeof(params.Spread) == "number" then params.Spread = 0 end
                if typeof(params.spreadAngle) == "number" then params.spreadAngle = 0 end
                if typeof(params.SpreadAngle) == "number" then params.SpreadAngle = 0 end
                if type(sharedData) == "table" then
                    if type(sharedData.ProjectileAccuracy) == "number" then
                        sharedData.ProjectileAccuracy = 1
                    end
                    if type(sharedData.ShotgunRoundAccuracy) == "number" then
                        sharedData.ShotgunRoundAccuracy = 1
                    end
                    if type(sharedData.SlugRoundAccuracy) == "number" then
                        sharedData.SlugRoundAccuracy = 1
                    end
                    if type(sharedData.CoinShotAccuracy) == "number" then
                        sharedData.CoinShotAccuracy = 1
                    end
                end
            end
        end
        return oldInitProjectiles(self, projType, sharedData, params, callback)
    end

    HOOKS.install = function()
        if installed then return end
        installed = true
        if not ProjectileHandler then
            ProjectileHandler = Global and Global.ProjectileHandler
            oldInitProjectiles = ProjectileHandler and ProjectileHandler.InitProjectiles
        end
        if ProjectileHandler then
            ProjectileHandler.InitProjectiles = initProjectilesHook
        end
        HOOKS.applyNoRecoil(state.noRecoil)
    end
    HOOKS.uninstall = function()
        if not installed then return end
        installed = false
        if ProjectileHandler then
            ProjectileHandler.InitProjectiles = oldInitProjectiles
        end
        HOOKS.applyNoRecoil(false)
    end
end

-- =================================================================
--  AMMO
-- =================================================================
local function initAmmo()
    local TYPES = {"GunItemType","SidearmItemType","SideArmType","WeaponItemType"}
    local ourHooks = setmetatable({}, {__mode="k"})
    local wrappedClasses = setmetatable({}, {__mode="k"})
    local wrappedInstances = setmetatable({}, {__mode="k"})
    local installed = false
    local function isWeapon(t)
        if type(t) ~= "table" then return false end
        if rawget(t, "Ammo") == nil and rawget(t, "MaxAmmo") == nil then
            local ok1, v1 = pcall(function() return t.Ammo end)
            if not ok1 or v1 == nil then return false end
            local ok2, v2 = pcall(function() return t.MaxAmmo end)
            if not ok2 or v2 == nil then return false end
        end
        return true
    end
    local function clearReloadFlags(self)
        for _, f in ipairs({"IsLoading","Reloading","IsReloading","NeedsReload","ReloadPending","ReloadRequested","ReloadNeeded","GlobalIsReloading"}) do
            if rawget(self, f) ~= nil then rawset(self, f, false) end
        end
    end
    local function fillChamber(self)
        local st = rawget(self, "State")
        if type(st) ~= "table" then return end
        local cd = rawget(st, "ChamberData")
        if type(cd) ~= "table" then return end
        local b = rawget(cd, "bullets")
        if type(b) ~= "table" then return end
        for i = 1, #b do b[i] = "unused" end
        if type(rawget(cd, "count")) == "number" and cd.count > 0 then rawset(cd, "index", 1) end
    end
    local function fillInstant(self)
        local max = rawget(self, "MaxAmmo")
        if type(max) ~= "number" or max <= 0 then return end
        rawset(self, "Ammo", max)
        local st = rawget(self, "State")
        if type(st) == "table" then rawset(st, "Ammo", max); rawset(st, "MaxAmmo", max) end
        fillChamber(self)
        clearReloadFlags(self)
    end
    local function forceFix(self)
        if type(self) ~= "table" then return end
        local max = rawget(self, "MaxAmmo")
        if type(max) ~= "number" or max <= 0 then return end
        if state.infiniteAmmo then
            rawset(self, "Ammo", max)
            local st = rawget(self, "State")
            if type(st) == "table" then rawset(st, "Ammo", max); rawset(st, "MaxAmmo", max) end
            fillChamber(self)
        end
        if state.infiniteAmmo or state.instantReload then clearReloadFlags(self) end
    end
    local function makeMT(origMT)
        local origIndex = origMT and origMT.__index
        return {
            __TWW_AMMO_PROXY = true,
            __index = function(t, key)
                if state.infiniteAmmo and key == "Ammo" then
                    local max = rawget(t, "MaxAmmo")
                    if type(max) == "number" and max > 0 then return max end
                end
                local own = rawget(t, key)
                if own ~= nil then return own end
                if origIndex ~= nil then
                    if type(origIndex) == "function" then return origIndex(t, key) end
                    return origIndex[key]
                end
                return nil
            end,
            __newindex = function(t, key, value)
                if state.infiniteAmmo and key == "Ammo" then
                    local max = rawget(t, "MaxAmmo")
                    if type(max) == "number" and max > 0 and type(value) == "number" and value < max then return end
                end
                rawset(t, key, value)
            end,
        }
    end
    local function wrapInstance(inst)
        if type(inst) ~= "table" or wrappedInstances[inst] then return end
        wrappedInstances[inst] = true
        local mt = getmetatable(inst)
        if type(mt) == "table" and mt.__TWW_AMMO_PROXY then return end
        pcall(function() setmetatable(inst, makeMT(mt)) end)
    end
    local function findExisting()
        if type(getgc) ~= "function" then return end
        local ok, gc = pcall(getgc, true)
        if not ok or type(gc) ~= "table" then return end
        for _, obj in ipairs(gc) do
            if isWeapon(obj) then wrapInstance(obj) end
        end
    end
    local function wrapClass(cls)
        if type(cls) ~= "table" or wrappedClasses[cls] then return end
        wrappedClasses[cls] = true
        local origNew = cls.new
        if type(origNew) == "function" and not ourHooks[origNew] then
            local newHook = function(self, ...)
                local inst = origNew(self, ...)
                if type(inst) == "table" then wrapInstance(inst) end
                return inst
            end
            ourHooks[newHook] = true
            cls.new = newHook
        end
        for _, mName in ipairs({"Update", "ReplicatedUpdate"}) do
            local orig = cls[mName]
            if type(orig) == "function" and not ourHooks[orig] then
                local hook = function(self, ...)
                    local r = orig(self, ...)
                    if isWeapon(self) then forceFix(self) end
                    return r
                end
                ourHooks[hook] = true
                cls[mName] = hook
            end
        end
        local origLoad = cls.Load
        if type(origLoad) == "function" and not ourHooks[origLoad] then
            local hook = function(self, ...)
                if state.instantReload and isWeapon(self) then fillInstant(self); return end
                return origLoad(self, ...)
            end
            ourHooks[hook] = true
            cls.Load = hook
        end
    end
    AMMO.install = function()
        if installed then return true end
        if not Global then return false end
        local ok = pcall(function()
            for _, name in ipairs(TYPES) do
                local ok2, cls = pcall(function() return Global:LoadModule(name) end)
                if ok2 then wrapClass(cls) end
            end
        end)
        pcall(findExisting)
        installed = ok
        return ok
    end
    AMMO.uninstall = function()
        wrappedClasses = setmetatable({}, {__mode="k"})
        installed = false
    end
    AMMO.wrapExisting = findExisting
end

-- =================================================================
--  INVENTORY
-- =================================================================
local function initInventory()
    local function findBankVault()
        local tagged = S.CollectionService:GetTagged("BankVault")
        if tagged and #tagged > 0 then return tagged[1] end
        local ok, found = pcall(function() return S.Workspace:FindFirstChild("BankVault", true) end)
        if ok and found then return found end
        for _, obj in ipairs(S.Workspace:GetDescendants()) do
            if obj.Name == "BankVault" or obj.Name == "Bank Vault" then return obj end
        end
        return nil
    end
    INV.openBankAnywhere = function()
        local v = findBankVault()
        if not v then return false, "No BankVault found" end
        local prompt = v:FindFirstChildWhichIsA("ProximityPrompt", true)
        if not prompt then return false, "No ProximityPrompt on BankVault" end
        pcall(function() prompt:InputHoldBegin() end)
        task.delay((prompt.HoldDuration or 0) + 0.15, function()
            pcall(function() prompt:InputHoldEnd() end)
        end)
        return true
    end
end

-- =================================================================
--  WENDIGO ANNOUNCER
-- =================================================================
local function initWendigoAnnouncer()
    local ANIMALS_PATH = "WORKSPACE_Entities.Animals"

    local function isWendigoExact(obj)
        return obj and obj.Name and obj.Name:lower() == "wendigo"
    end

    local function playAlertSound(parent)
        pcall(function()
            local snd = Instance.new("Sound")
            snd.Name = "TWW_WendigoAlert"
            snd.SoundId = "rbxassetid://6042053626"
            snd.Volume = 2
            snd.Parent = parent
            snd:Play()
            task.delay(6, function() pcall(function() snd:Destroy() end) end)
        end)
    end

    local function announce()
        local playerGui = S.LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not playerGui then return end

        local old = playerGui:FindFirstChild("TWW_WendigoAnnounce")
        if old then pcall(function() old:Destroy() end) end

        local gui = Instance.new("ScreenGui")
        gui.Name = "TWW_WendigoAnnounce"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 99999
        gui.Parent = playerGui

        local bg = Instance.new("Frame")
        bg.Size = UDim2.fromScale(1, 1)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 1
        bg.BorderSizePixel = 0
        bg.Parent = gui

        local banner = Instance.new("Frame")
        banner.Size = UDim2.new(1, 0, 0, 170)
        banner.Position = UDim2.new(0, 0, 0.5, -400)
        banner.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
        banner.BackgroundTransparency = 0.5
        banner.BorderSizePixel = 0
        banner.Parent = gui

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 60, 60)
        stroke.Thickness = 5
        stroke.Parent = banner

        local title = Instance.new("TextLabel")
        title.Size = UDim2.fromScale(1, 1)
        title.BackgroundTransparency = 1
        title.TextColor3 = Color3.fromRGB(255, 240, 240)
        title.Font = Enum.Font.GothamBlack
        title.TextScaled = true
        title.Text = "⚠ WENDIGO SE SPAWNUL ⚠"
        title.Parent = banner

        local sizeConst = Instance.new("UITextSizeConstraint")
        sizeConst.MaxTextSize = 100
        sizeConst.MinTextSize = 28
        sizeConst.Parent = title

        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, 0, 0, 28)
        sub.Position = UDim2.new(0, 0, 1, -30)
        sub.BackgroundTransparency = 1
        sub.TextColor3 = Color3.fromRGB(255, 200, 200)
        sub.Font = Enum.Font.GothamBold
        sub.TextSize = 20
        sub.Text = "Legendary Animal detekován v Animals"
        sub.Parent = banner

        playAlertSound(gui)

        S.TweenService:Create(bg, TweenInfo.new(0.3), {BackgroundTransparency = 0.35}):Play()
        S.TweenService:Create(banner, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0.5, -85),
            BackgroundTransparency = 0,
        }):Play()

        task.spawn(function()
            for _ = 1, 4 do
                S.TweenService:Create(title, TweenInfo.new(0.18), {TextColor3 = Color3.fromRGB(255, 90, 90)}):Play()
                task.wait(0.18)
                S.TweenService:Create(title, TweenInfo.new(0.18), {TextColor3 = Color3.fromRGB(255, 240, 240)}):Play()
                task.wait(0.18)
            end
        end)

        task.delay(6, function()
            S.TweenService:Create(banner, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Position = UDim2.new(0, 0, 0.5, -400),
                BackgroundTransparency = 1,
            }):Play()
            S.TweenService:Create(bg, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
            task.wait(0.6)
            if gui.Parent then pcall(function() gui:Destroy() end) end
        end)

        if state.window and state.window.Notify then
            pcall(function() state.window:Notify("WENDIGO SPAWN!", 5) end)
        end
    end

    local function watchFolder(folder)
        if not folder then return end
        folder.ChildAdded:Connect(function(child)
            if state.destroyed then return end
            if child:IsA("Model") and isWendigoExact(child) then
                announce()
            elseif child:IsA("Folder") then
                watchFolder(child)
            end
        end)
    end

    task.spawn(function()
        local node = S.Workspace
        for segment in string.gmatch(ANIMALS_PATH, "[^.]+") do
            node = node:WaitForChild(segment, 120)
            if not node then return end
        end
        watchFolder(node)
        for _, child in ipairs(node:GetChildren()) do
            if child:IsA("Folder") then watchFolder(child) end
        end
    end)
end

-- =================================================================
--  UI
-- =================================================================
local function initUI()
    local Window = Library:CreateWindow("TWW Ultimate ESP + Combat", {
        Width = 640, Height = 560,
        ToggleKey = Enum.KeyCode.RightShift,
        ConfigKey = "TWW_Ultimate_V3",
        ConfigAutoSave = false,
        OnClose = function()
            pcall(function()
                state.espEnabled = false
                if ESP.cleanup then ESP.cleanup() end
                state.silentAim = false
                state.noSpread = false
                if HOOKS.applyNoRecoil then HOOKS.applyNoRecoil(false) end
                if HOOKS.uninstall then HOOKS.uninstall() end
                if FB.stop then pcall(FB.stop) end
                if Physics and Physics.stop then pcall(Physics.stop) end
                pcall(function() S.Lighting.ExposureCompensation = 0 end)
                SaveStateToConfig(state.currentConfig)
            end)
        end,
    })
    state.window = Window
    local function toast(msg, dur) pcall(function() Window:Notify(msg, dur or 2) end) end

    local MainTab      = Window:Folder("Main")
    local VisualsTab   = Window:Folder("Visuals")
    local CombatTab    = Window:Folder("Combat")
    local UtilitiesTab = Window:Folder("Utilities")
    local ConfigTab    = Window:Folder("Config")

    -- ================== MAIN ==================
    local master = MainTab:Section("⚡ Master Controls")
    uiHandles.checkboxes.espEnabled = master:Checkbox("Enable ESP", function(enabled)
        if _loadingConfig then return end
        state.espEnabled = enabled
        ESP.lastUpdate = 0
        if not enabled then
            if ESP.cleanup then ESP.cleanup() end
        end
    end, state.espEnabled)

    uiHandles.checkboxes.suppressErrors = master:Checkbox("🚫 Suppress Errors / Warnings", function(e)
        if _loadingConfig then return end
        state.suppressErrors = e
    end, state.suppressErrors)

    local entSec = MainTab:Section("🧩 Entities")
    local function entToggle(label, key)
        uiHandles.checkboxes[key] = entSec:Checkbox(label, function(e)
            if _loadingConfig then return end
            state[key] = e
        end, state[key])
    end
    entToggle("Players", "showPlayers")
    entToggle("NPCs", "showNPCs")
    entToggle("Animals", "showAnimals")
    entToggle("Horses", "showHorses")
    entToggle("Fish", "showFish")
    entToggle("Dead Animals", "showDeadAnimals")
    entToggle("Ores", "showOres")
    entToggle("Items", "showItems")
    entToggle("Chests", "showChests")
    entToggle("Trains", "showTrains")
    entToggle("Territories", "showTerritories")
    entToggle("Thunderstruck Trees/Cacti ⚡", "showThunderstruck")

    uiHandles.checkboxes.highlightGoldBars = entSec:Checkbox("Bank Gold Bars (GoldBar)", function(e)
        if _loadingConfig then return end
        state.highlightGoldBars = e
    end, state.highlightGoldBars)

    local goldStatusLabel = entSec:Label("💰 Bank Gold Bars: ⏳ scanning...")
    task.spawn(function()
        local last = ""
        while not state.destroyed do
            task.wait(1)
            local exists, count = false, 0
            if ESP.getGoldBarStatus then
                local ok, e, c = pcall(ESP.getGoldBarStatus)
                if ok then exists, count = e or false, c or 0 end
            end
            local text
            if not exists then
                text = "💰 Bank Gold Bars: ❌ nenalezeny (bank neni nactena)"
            elseif count == 0 then
                text = "💰 Bank Gold Bars: ⚠️ nalezeny, ale 0 cihel"
            else
                text = "💰 Bank Gold Bars: ✅ " .. count .. " cihel"
            end
            if text ~= last and goldStatusLabel then
                last = text
                if type(goldStatusLabel.Set) == "function" then
                    pcall(function() goldStatusLabel:Set(text) end)
                elseif type(goldStatusLabel.SetText) == "function" then
                    pcall(function() goldStatusLabel:SetText(text) end)
                end
            end
        end
    end)

    local bankSec = MainTab:Section("💼 Bank")
    bankSec:Label("Open Bank Anywhere — triggers BankVault's ProximityPrompt.")
    bankSec:Button("🏦 Open Bank (Anywhere)", function()
        local ok, err = INV.openBankAnywhere()
        if ok then toast("Bank prompt triggered.", 2)
        else toast("Bank failed: "..tostring(err), 3) end
    end)

    local utilSec = MainTab:Section("🔧 Utilities")
    utilSec:Button("Server Hop", function()
        local placeId = game.PlaceId
        local currentJob = game.JobId
        local function fetch()
            local servers = {}
            local cursor = ""
            local attempts = 0
            repeat
                attempts = attempts + 1
                local url = "https://games.roblox.com/v1/games/"..placeId.."/servers/Public?limit=100"
                if cursor ~= "" then url = url.."&cursor="..cursor end
                local ok, data = pcall(function() return game:HttpGet(url, true) end)
                if not ok or type(data) ~= "string" or data == "" then break end
                local ok2, dec = pcall(S.HttpService.JSONDecode, S.HttpService, data)
                if not ok2 or type(dec) ~= "table" or type(dec.data) ~= "table" then break end
                for _, srv in ipairs(dec.data) do
                    if srv.id and srv.id ~= currentJob and (srv.playing or 0) < (srv.maxPlayers or 9999) then
                        table.insert(servers, srv.id)
                    end
                end
                cursor = dec.nextPageCursor or ""
            until cursor == "" or attempts >= 5 or #servers >= 50
            return servers
        end
        local servers = fetch()
        if #servers > 0 then
            local target = servers[math.random(1, #servers)]
            local ok = pcall(function() S.TeleportService:TeleportToPlaceInstance(placeId, target, S.LocalPlayer) end)
            if not ok then pcall(function() S.TeleportService:Teleport(placeId, S.LocalPlayer) end) end
        else
            pcall(function() S.TeleportService:Teleport(placeId, S.LocalPlayer) end)
        end
    end)

    -- ================== VISUALS ==================
    local infoSec = VisualsTab:Section("📊 Information Display")
    local function dispToggle(label, key)
        uiHandles.checkboxes[key] = infoSec:Checkbox(label, function(e)
            if _loadingConfig then return end
            state[key] = e
        end, state[key])
    end
    dispToggle("Show Names", "showNames")
    dispToggle("Show Distance", "showDistance")
    dispToggle("Show Health", "showHealth")
    dispToggle("Show Tracers", "showTracers")
    dispToggle("Show Ore Count", "showOreCount")
    dispToggle("Show Ore Tier", "showOreTier")
    dispToggle("Legendary Animals Only", "showLegendaryOnly")
    dispToggle("Golden Legendary Highlight", "legendaryGoldenMode")

    uiHandles.checkboxes.chamsEnabled = infoSec:Checkbox("Enable Chams", function(e)
        if _loadingConfig then return end
        state.chamsEnabled = e
        if e then
            if ESP.clearAllChams then ESP.clearAllChams() end
        end
    end, state.chamsEnabled)

    local bodySec = VisualsTab:Section("🎯 ESP Body Highlight")
    bodySec:Label("Which body part groups to highlight red.")
    bodySec:Label("Animals: only Head red. Legendary: every part gold.")
    uiHandles.checklists.espBodyHighlight = bodySec:Checklist("Body Parts",
        BODY_HIGHLIGHT_OPTIONS,
        function(list)
            if _loadingConfig then return end
            state.espBodyHighlight = list or {}
        end, state.espBodyHighlight or {})

    bodySec:Button("🔄 Reset Highlights", function()
        if ESP.resetHighlights then
            ESP.resetHighlights()
            toast("Rebuilding highlights one by one...", 2)
        end
    end)

    local colorSec = VisualsTab:Section("🎨 Colors")
    local function colorDD(label, key)
        uiHandles.dropdowns[key] = colorSec:Dropdown(label, COLOR_OPTIONS, function(v)
            if _loadingConfig then return end
            state[key] = v
        end, state[key])
    end
    for _, pair in ipairs({
        {"Player","playerColor"},{"NPC","npcColor"},{"Animal","animalColor"},{"Horse","horseColor"},
        {"Ore","oreColor"},{"Item","itemColor"},{"Chest","chestColor"},{"Train","trainColor"},
        {"Territory","territoryColor"},{"Fish","fishColor"},{"Dead Animal","deadAnimalColor"},
        {"Thunderstruck","thunderstruckColor"},
        {"Legendary Highlight","legendaryColor"},{"Tracer","tracerColor"},
    }) do colorDD(pair[1], pair[2]) end

    -- ================== ANIMAL FILTER ==================
    local animalSec = VisualsTab:Section("🦌 Animal Filter")
    animalSec:Label("Zaškrtni druhy zvířat, které chceš vidět v ESP.")
    animalSec:Label("Legendární zvířata (včetně Wendigo) se zobrazují VŽDY.")
    animalSec:Label("Prázdný seznam = zobrazit všechna zvířata.")

    local animalChecklist = nil
    local function rebuildAnimalChecklist()
        local names = (ESP.collectAnimalNames and ESP.collectAnimalNames()) or {}
        if #names == 0 then names = {"(žádná zvířata nenalezena)"} end
        if animalChecklist then
            pcall(function() animalChecklist:Destroy() end)
            animalChecklist = nil
        end
        animalChecklist = animalSec:Checklist("Animal Types", names,
            function(list)
                if _loadingConfig then return end
                state.animalFilter = list or {}
            end, state.animalFilter or {})
        uiHandles.checklists.animalFilter = animalChecklist
    end
    rebuildAnimalChecklist()

    animalSec:Button("🔄 Refresh Animal List", function()
        rebuildAnimalChecklist()
        toast("Seznam zvířat obnoven ("..#(state.animalFilter or {}).." vybráno)", 2)
    end)
    animalSec:Button("✔ Check All", function()
        local names = (ESP.collectAnimalNames and ESP.collectAnimalNames()) or {}
        state.animalFilter = names
        if animalChecklist then
            pcall(function() animalChecklist:Set(names) end)
        end
        toast("Všechna zvířata zapnuta.", 2)
    end)
    animalSec:Button("✖ Clear Filter (show all)", function()
        state.animalFilter = {}
        if animalChecklist then
            pcall(function() animalChecklist:Set({}) end)
        end
        toast("Filtr vymazán — zobrazí se vše.", 2)
    end)

    task.spawn(function()
        task.wait(4)
        pcall(function()
            if not state.destroyed then rebuildAnimalChecklist() end
        end)
    end)

    local perfSec = VisualsTab:Section("📏 Distance & Performance")
    uiHandles.sliders.maxDistance = perfSec:Slider("Max Distance (ESP, 0=unlimited)", 0, 5000, state.maxDistance,
        function(v) if _loadingConfig then return end state.maxDistance = v end, 10)
    uiHandles.sliders.updateInterval = perfSec:Slider("Update Interval (s)", 0.05, 1, state.updateInterval,
        function(v) if _loadingConfig then return end state.updateInterval = v end, 0.05)
    uiHandles.sliders.labelSize = perfSec:Slider("Label Size", 10, 20, state.labelSize, function(v)
        if _loadingConfig then return end
        state.labelSize = v
        ESP.setLabelSize(v)
    end, 1)
    uiHandles.sliders.tracerThickness = perfSec:Slider("Tracer Thickness", 1, 5, state.tracerThickness,
        function(v) if _loadingConfig then return end state.tracerThickness = v end, 1)
    uiHandles.sliders.tracerTransparency = perfSec:Slider("Tracer Transparency", 0, 1, state.tracerTransparency,
        function(v) if _loadingConfig then return end state.tracerTransparency = v end, 0.05)

    -- ================== COMBAT ==================
    local aimCombatSec = CombatTab:Section("🎯 Silent Aim")
    local silentAimBox = aimCombatSec:Checkbox("Enable Silent Aim", function(e)
        if _loadingConfig then return end
        state.silentAim = e
        ESP.updateFOV()
    end, state.silentAim)
    uiHandles.checkboxes.silentAim = silentAimBox
    pcall(function()
        aimCombatSec:Bind("Silent Aim Hotkey", Enum.KeyCode.J, function()
            state.silentAim = not state.silentAim
            pcall(function() silentAimBox:Set(state.silentAim) end)
            ESP.updateFOV()
            toast("Silent Aim "..(state.silentAim and "ON" or "OFF"), 2)
        end)
    end)

    uiHandles.dropdowns.targetPart = aimCombatSec:Dropdown("Target Part",
        {"Head","UpperTorso","LowerTorso","Random","Closest"},
        function(v) if _loadingConfig then return end state.targetPart = v end, state.targetPart)
    aimCombatSec:Label("Controls which body part Silent Aim locks onto.")

    local tgtSec = CombatTab:Section("── Targets ──")
    local function ctToggle(label, key)
        uiHandles.checkboxes[key] = tgtSec:Checkbox(label, function(e)
            if _loadingConfig then return end
            state[key] = e
        end, state[key])
    end
    ctToggle("Target Players", "targetPlayers")
    ctToggle("Target Animals 🦌", "targetAnimals")
    ctToggle("Target NPCs", "targetNPCs")

    local aimingSec = CombatTab:Section("── Aiming ──")
    uiHandles.sliders.fov = aimingSec:Slider("FOV (°)", 5, 180, state.fov, function(v)
        if _loadingConfig then return end
        state.fov = v
        ESP.updateFOV()
    end, 5)
    uiHandles.checkboxes.visibilityCheck = aimingSec:Checkbox("Visibility Check", function(e)
        if _loadingConfig then return end
        state.visibilityCheck = e
    end, state.visibilityCheck)
    uiHandles.checkboxes.showFOVRing = aimingSec:Checkbox("Show FOV Ring", function(e)
        if _loadingConfig then return end
        state.showFOVRing = e
        ESP.updateFOV()
    end, state.showFOVRing)

    -- ==== Movement Prediction (NEW) ====
    local predSec = CombatTab:Section("── Prediction ──")
    uiHandles.checkboxes.silentAimPrediction = predSec:Checkbox(
        "Enable Movement Prediction", function(e)
            if _loadingConfig then return end
            state.silentAimPrediction = e
        end, state.silentAimPrediction)

    uiHandles.sliders.silentAimPredictionStrength = predSec:Slider(
        "Prediction Strength (0–2)", 0, 2, state.silentAimPredictionStrength,
        function(v)
            if _loadingConfig then return end
            state.silentAimPredictionStrength = v
        end, 0.05)

    predSec:Label("0 = aim at current position, 1 = perfect lead, >1 = over-lead.")
    predSec:Label("Speed estimation: guns = ProjectilePower, arrows = Min/Max lerp.")

    local gunSec = CombatTab:Section("🔫 Gunplay")
    uiHandles.checkboxes.noRecoil = gunSec:Checkbox("No Recoil", function(e)
        if _loadingConfig then return end
        state.noRecoil = e
        HOOKS.applyNoRecoil(e)
    end, state.noRecoil)
    uiHandles.checkboxes.noSpread = gunSec:Checkbox("No Projectile Spread", function(e)
        if _loadingConfig then return end
        state.noSpread = e
    end, state.noSpread)

    local ammoSec = CombatTab:Section("🎯 Ammo")
    uiHandles.checkboxes.infiniteAmmo = ammoSec:Checkbox("Infinite Ammo", function(e)
        if _loadingConfig then return end
        state.infiniteAmmo = e
        if e then AMMO.install(); AMMO.wrapExisting() end
    end, state.infiniteAmmo)
    uiHandles.checkboxes.instantReload = ammoSec:Checkbox("Instant Reload", function(e)
        if _loadingConfig then return end
        state.instantReload = e
        if e then AMMO.install(); AMMO.wrapExisting() end
    end, state.instantReload)

    -- ================== UTILITIES ==================
    local charSec = UtilitiesTab:Section("🏃 Character")
    uiHandles.checkboxes.infiniteStamina = charSec:Checkbox("Infinite Stamina", function(e)
        if _loadingConfig then return end
        state.infiniteStamina = e
        if e then CHAR.applyInfiniteStamina() else CHAR.removeInfiniteStamina() end
        CHAR.sync()
    end, state.infiniteStamina)
    uiHandles.checkboxes.antiRagdoll = charSec:Checkbox("Anti Ragdoll (only me)", function(e)
        if _loadingConfig then return end
        state.antiRagdoll = e
        if e then CHAR.applyAntiRagdoll(); CHAR.removeAntiFallDamage() else CHAR.removeAntiRagdoll() end
        CHAR.sync()
    end, state.antiRagdoll)
    uiHandles.checkboxes.antiFallDamage = charSec:Checkbox("Anti Fall Damage (only fall)", function(e)
        if _loadingConfig then return end
        state.antiFallDamage = e
        if e and not state.antiRagdoll then CHAR.applyAntiFallDamage() else CHAR.removeAntiFallDamage() end
        CHAR.sync()
    end, state.antiFallDamage)
    uiHandles.checkboxes.infiniteHorseStamina = charSec:Checkbox("Infinite Horse Stamina", function(e)
        if _loadingConfig then return end
        state.infiniteHorseStamina = e
        if e then CHAR.applyHorseStamina() else CHAR.removeHorseStamina() end
    end, state.infiniteHorseStamina)

    local waterSec = UtilitiesTab:Section("🌊 Water")
    uiHandles.checkboxes.walkUnderWater = waterSec:Checkbox("Walk Under Water", function(e)
        if _loadingConfig then return end
        state.walkUnderWater = e
        Water.setWalkUnderWater(e)
    end, state.walkUnderWater)
    uiHandles.checkboxes.allowGunsUnderWater = waterSec:Checkbox("Allow Guns Underwater", function(e)
        if _loadingConfig then return end
        state.allowGunsUnderWater = e
        Water.setAllowGunsUnderWater(e)
    end, state.allowGunsUnderWater)

    local physSec = UtilitiesTab:Section("🧲 Physics")
    uiHandles.checkboxes.gravityEnabled = physSec:Checkbox("Enable Gravity Changer", function(e)
        if _loadingConfig then return end
        Physics.setGravity(e, state.gravityValue)
    end, state.gravityEnabled)
    uiHandles.sliders.gravityValue = physSec:Slider("Gravity (min 83, default 196.2)", 83, 500, state.gravityValue, function(v)
        if _loadingConfig then return end
        state.gravityValue = v
        if state.gravityEnabled then Physics.setGravity(true, v) end
    end, 1)
    uiHandles.checkboxes.hipHeightEnabled = physSec:Checkbox("Enable Hip Height", function(e)
        if _loadingConfig then return end
        Physics.setHipHeight(e, state.hipHeightValue)
    end, state.hipHeightEnabled)
    uiHandles.sliders.hipHeightValue = physSec:Slider("Hip Height (1-10)", 1, 10, state.hipHeightValue, function(v)
        if _loadingConfig then return end
        state.hipHeightValue = v
        if state.hipHeightEnabled then Physics.setHipHeight(true, v) end
    end, 0.5)
    uiHandles.checkboxes.speedEnabled = physSec:Checkbox("Enable Speed Changer", function(e)
        if _loadingConfig then return end
        Physics.setSpeed(e, state.speedValue)
    end, state.speedEnabled)
    uiHandles.sliders.speedValue = physSec:Slider("WalkSpeed (1-45)", 1, 45, state.speedValue, function(v)
        if _loadingConfig then return end
        state.speedValue = v
        if state.speedEnabled then Physics.setSpeed(true, v) end
    end, 1)

    local fbSec = UtilitiesTab:Section("☀️ Full Bright")
    fbSec:Label("0 = OFF (heartbeat disconnected). 1-5 = ExposureCompensation locked via Heartbeat.")
    uiHandles.sliders.fullBrightLevel = fbSec:Slider("Brightness Level (0=off, 1-5)", 0, 5, state.fullBrightLevel,
        function(v)
            if _loadingConfig then return end
            FB.setLevel(v)
        end, 1)

    local timeSec = UtilitiesTab:Section("🌅 World Time")
    uiHandles.checkboxes.alwaysDay = timeSec:Checkbox("Always Day (fix noon)", function(e)
        if _loadingConfig then return end
        state.alwaysDay = e
        if FB.applyTime then FB.applyTime() end
    end, state.alwaysDay)

    local dbgSec = UtilitiesTab:Section("🐞 Debug")
    uiHandles.checkboxes.debugPrints = dbgSec:Checkbox("Debug Prints (combat)",
        function(e) if _loadingConfig then return end state.debugPrints = e end, state.debugPrints)

    local sysSec = UtilitiesTab:Section("⚙️ System")
    sysSec:Button("Restore Defaults", function()
        ResetStateToDefault()
        ESP.updateFOV()
        toast("Settings restored to defaults", 2)
    end)
    sysSec:Button("Silence ON/OFF (toggle errors)", function()
        state.suppressErrors = not state.suppressErrors
        if uiHandles.checkboxes.suppressErrors then
            pcall(function() uiHandles.checkboxes.suppressErrors:Set(state.suppressErrors) end)
        end
        toast("Errors "..(state.suppressErrors and "SUPPRESSED" or "VISIBLE"), 2)
    end)
    sysSec:Button("Unhook Everything (panic)", function()
        state.silentAim = false
        state.silentAimPrediction = false
        state.noSpread = false
        state.noRecoil = false
        state.infiniteAmmo = false
        state.instantReload = false
        state.fullBrightLevel = 0
        state.highlightGoldBars = false
        state.gravityEnabled = false
        state.hipHeightEnabled = false
        state.speedEnabled = false
        state.walkUnderWater = false
        state.allowGunsUnderWater = false
        if HOOKS.uninstall then HOOKS.uninstall() end
        if AMMO.uninstall then AMMO.uninstall() end
        if FB.setLevel then FB.setLevel(0) end
        if FB.stop then pcall(FB.stop) end
        if Physics.stop then pcall(Physics.stop) end
        if Water then Water.setWalkUnderWater(false); Water.setAllowGunsUnderWater(false) end
        if ESP.updateGoldBars then ESP.updateGoldBars() end
        updateUIFromState()
        ESP.updateFOV()
        toast("All hooks removed — vanilla restored.", 3)
    end)

    -- ================== CONFIG ==================
    local profSec = ConfigTab:Section("📝 Profiles")
    uiHandles.textboxes.configName = profSec:Textbox("Profile name...",
        function(t, enter) if _loadingConfig then return end state.currentConfig = t end, state.currentConfig)

    local function refreshConfigDropdown()
        if uiHandles.dropdowns.configDropdown then
            pcall(function() uiHandles.dropdowns.configDropdown:Destroy() end)
            uiHandles.dropdowns.configDropdown = nil
        end
        local files = CFG.getFiles()
        if #files == 0 then files = {"(no saved profiles)"} end
        local current = state.currentConfig
        local found = false
        for _, n in ipairs(files) do if n == current then found = true break end end
        if not found and current ~= "" and current ~= "(no saved profiles)" then
            table.insert(files, current); table.sort(files)
        end
        uiHandles.dropdowns.configDropdown = profSec:Dropdown("📂 Saved Profiles", files, function(v)
            if _loadingConfig then return end
            state.currentConfig = v
            if uiHandles.textboxes.configName then
                pcall(function() uiHandles.textboxes.configName:Set(v) end)
            end
        end, state.currentConfig)
    end
    refreshConfigDropdown()

    profSec:Button("💾 Save Profile", function()
        local name = state.currentConfig
        if name == "" or name == "(no saved profiles)" then toast("Enter a valid profile name first.", 3); return end
        if SaveStateToConfig(name) then refreshConfigDropdown(); toast("Saved as \""..name.."\"", 2)
        else toast("Save failed. Check console.", 3) end
    end)
    profSec:Button("📂 Load Profile", function()
        local name = state.currentConfig
        if name == "" or name == "(no saved profiles)" then toast("Select a profile first.", 3); return end
        if LoadStateFromConfig(name) then
            updateUIFromState(); ESP.updateFOV()
            if uiHandles.checklists.animalFilter then
                pcall(function() uiHandles.checklists.animalFilter:Set(state.animalFilter or {}) end)
            end
            toast("Loaded \""..name.."\"", 2)
        else toast("Load failed.", 3) end
    end)
    profSec:Button("🗑️ Delete Profile", function()
        local name = state.currentConfig
        if name == "" or name == "(no saved profiles)" then toast("Select a profile to delete.", 3); return end
        if not CFG.delete(name) then toast("Delete failed.", 3); return end
        state.currentConfig = "Default"
        if uiHandles.textboxes.configName then
            pcall(function() uiHandles.textboxes.configName:Set("Default") end)
        end
        refreshConfigDropdown()
        toast("Deleted \""..name.."\"", 2)
    end)
    profSec:Button("🔄 Refresh List", function() refreshConfigDropdown() end)
    profSec:Button("♻️ Reset All to Default", function()
        ResetStateToDefault(); ESP.updateFOV()
        toast("All settings reset.", 2)
    end)
    profSec:Label(CFG.ready and "🟢 Auto-save: ON" or "🔴 Auto-save: OFF (no file access)")

    local aboutSec = ConfigTab:Section("ℹ️ About")
    aboutSec:Label("TWW Ultimate ESP + Combat (SmugLibV2)")
    aboutSec:Label("ESP + Silent Aim + No Recoil + No Spread + Infinite Ammo")
    aboutSec:Label("+ Gravity + Hip Height + Speed")
    aboutSec:Label("+ Walk Under Water + Guns Underwater + Thunderstruck ESP")
    aboutSec:Label("+ Animal Filter Checklist (legendary + Wendigo always shown)")
    aboutSec:Label("+ Wendigo spawn announcement")
    aboutSec:Label("+ Bank Gold Bars live counter")
    aboutSec:Label("+ Silent Aim movement prediction")
    aboutSec:Label("+ Anti Ragdoll now only affects local player")
    aboutSec:Label("+ Suppress Errors toggle (Main tab)")
    aboutSec:Label("Binds: J = Silent Aim, RightShift = UI")
end

-- =================================================================
--  MAIN
-- =================================================================
local function initMain()
    local renderConnection = nil

    local function startLoop()
        if renderConnection then return end
        local token = state.generation
        renderConnection = S.RunService.RenderStepped:Connect(function()
            if not state.active or state.destroyed or token ~= state.generation then return end
            local ok, err = pcall(function()
                if ESP.update then ESP.update() end
                if ESP.updateFOV then ESP.updateFOV() end
            end)
            if not ok then
                warn("[TWW] RenderStepped error: "..tostring(err))
            end
        end)
    end
    local function stopLoop()
        if renderConnection then pcall(function() renderConnection:Disconnect() end); renderConnection = nil end
    end
    local function startESP()
        if state.destroyed or state.active then return end
        state.active = true
        state.generation = state.generation + 1
        if ESP.refresh then ESP.refresh() end
        startLoop()
        ESP.lastUpdate = 0
        if ESP.createFOV then ESP.createFOV() end
        if ESP.updateFOV then ESP.updateFOV() end
    end
    local function stopESP()
        if not state.active then return end
        state.active = false
        state.generation = state.generation + 1
        stopLoop()
        if ESP.cleanup then ESP.cleanup() end
        local r = ESP.getFOVRing and ESP.getFOVRing()
        if r then r.Visible = false end
    end
    local function destroyESP()
        if state.destroyed then return end
        state.destroyed = true
        if HOOKS.uninstall then HOOKS.uninstall() end
        if AMMO.uninstall then AMMO.uninstall() end
        if FB.stop then pcall(FB.stop) end
        if Physics.stop then pcall(Physics.stop) end
        pcall(function() S.Lighting.ExposureCompensation = 0 end)
        if ESP.clearFOVRing then ESP.clearFOVRing() end
        stopESP()
        if ESP.cleanupDrawings then ESP.cleanupDrawings() end
        if state.window then pcall(function() state.window:Kill() end) end
    end
    local controller = {}
    function controller:Start() startESP() end
    function controller:Stop() stopESP() end
    function controller:Destroy() destroyESP() end
    environment.TWWESP = controller

    state.destroyed = false
    state.active = false

    startESP()

    task.delay(0.5, function()
        if not state.destroyed and not state.active then
            state.destroyed = false
            state.active = false
            startESP()
        end
    end)

    pcall(function()
        game:BindToClose(function()
            pcall(function() SaveStateToConfig(state.currentConfig) end)
            destroyESP()
        end)
    end)
    S.LocalPlayer.CharacterAdded:Connect(function()
        if ESP.cleanup then ESP.cleanup() end
        if ESP.refresh then ESP.refresh() end
        task.wait(0.5)
        if Water and Water.reapply then Water.reapply() end
        if CHAR and CHAR.sync then CHAR.sync() end
        if Physics and Physics.reapplyHip then Physics.reapplyHip() end
        if Physics and Physics.reapplySpeed then Physics.reapplySpeed() end
    end)
    S.Players.PlayerAdded:Connect(function(p)
        task.spawn(function()
            p.CharacterAdded:Wait()
            task.wait(0.3)
            if ESP.refresh then ESP.refresh() end
            p.CharacterAdded:Connect(function()
                if ESP.cleanup then ESP.cleanup() end
                task.wait(0.3)
                if ESP.refresh then ESP.refresh() end
            end)
        end)
    end)
end

-- ====== RUN ALL INIT ======
local function safeInit(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("[TWW] init "..name.." failed: "..tostring(err))
    end
end

safeInit("CFG", initCFG)
safeInit("FB", initFB)
safeInit("FOV", initFOV)
safeInit("Physics", initPhysics)
safeInit("Water", initWater)
safeInit("ESP", initESP)
safeInit("Char", initChar)
safeInit("Combat", initCombat)
safeInit("Hooks", initHooks)
safeInit("Ammo", initAmmo)
safeInit("Inventory", initInventory)
safeInit("WendigoAnnouncer", initWendigoAnnouncer)
safeInit("UI", initUI)
safeInit("Main", initMain)

local loaded = LoadStateFromConfig("Default")
if loaded then state.currentConfig = "Default" end
updateUIFromState()
if HOOKS.install then HOOKS.install() end
if AMMO.install then AMMO.install() end
if FB.applyTime then FB.applyTime() end

print("[TWW] Loaded. " .. #CFG.getFiles() .. " saved profile(s).")
