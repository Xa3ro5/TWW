-- TWW | SmugLibV2 | 2026-11-03
-- Edit src/TWW.luau, then run tools/build.py. UI and licensing belong to shared SmugLibV2.
if game.PlaceId ~= 2317712696 then
    warn("[TWW] This script supports The Wild West main place only.")
    return
end
local environment = (type(getgenv) == "function" and getgenv()) or _G
environment.TWWLoadGeneration = (tonumber(environment.TWWLoadGeneration) or 0) + 1
local loadGeneration = environment.TWWLoadGeneration
if environment.TWWESP and type(environment.TWWESP.Destroy) == "function" then
    pcall(function() environment.TWWESP:Destroy() end)
end
local SMUGLIB_URL = "https://raw.githubusercontent.com/Xa3ro5/LifeIsRoblox/refs/heads/main/SmugLibCoreV2.lua"
local ok, Library = pcall(function()
    local source = game:HttpGet(SMUGLIB_URL, true)
    local factory, compileError = loadstring(source)
    if not factory then error(compileError or "Failed to compile SmugLibV2", 0) end
    -- SmugLibV2 owns its key form, verification, cache and cancellation.
    return factory()
end)
if not ok then warn("[TWW] SmugLibV2: " .. tostring(Library)); return end
if loadGeneration ~= environment.TWWLoadGeneration then return end
if type(Library) ~= "table" or type(Library.CreateWindow) ~= "function" then
    warn("[TWW] SmugLibV2 did not return a UI library.")
    return
end
local run = (function()
return function(Library, environment)
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
    showPlants=false,
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

-- Suppression applies only to this script; never replace game globals or coroutine.wrap.
local originalWarn, originalPrint = warn, print
local function warn(...)
    if not state.suppressErrors then originalWarn(...) end
end
local function print(...)
    if not state.suppressErrors then originalPrint(...) end
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
local Adapter = { plants={}, npcByRig=setmetatable({}, {__mode="k"}) }
local ownedConnections, ownedInstances = {}, {}
local stopAll, destroyRuntime
local function connect(signal, callback)
    local c = signal:Connect(function(...)
        if not state.destroyed then return callback(...) end
    end)
    table.insert(ownedConnections, c)
    return c
end
local function own(instance)
    table.insert(ownedInstances, instance)
    return instance
end

-- ====== SAVE/LOAD ======
local _loadingConfig = false
local function updateUIFromState()
    local wasLoading = _loadingConfig
    _loadingConfig = true
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
        if state[key] ~= nil then pcall(function() h:SetSelected(state[key]) end) end
    end
    if uiHandles.textboxes.configName then
        pcall(function() uiHandles.textboxes.configName:Set(state.currentConfig) end)
    end
    _loadingConfig = wasLoading
end

local function validProfileName(name)
    return type(name) == "string" and #name > 0 and #name <= 64
        and name:match("^[%w_%- ]+$") ~= nil and name:match("%S") ~= nil
end
local NUMBER_LIMITS = {
    updateInterval={0.05,1}, maxDistance={0,5000}, maxLabels={1,500},
    tracerThickness={1,5}, tracerTransparency={0,1}, labelSize={10,20},
    fov={1,180}, silentAimPredictionStrength={0,3}, gravityValue={83,500},
    hipHeightValue={1,10}, speedValue={1,45}, fullBrightLevel={0,5},
}
local function savedValue(key, value)
    local default = DEFAULT_STATE[key]
    if default == nil or type(default) ~= type(value) then return nil end
    if type(value) == "number" then
        if value ~= value or math.abs(value) == math.huge then return nil end
        local range = NUMBER_LIMITS[key]
        return range and math.clamp(value, range[1], range[2]) or value
    elseif type(value) == "table" then
        local out = {}
        for _, item in ipairs(value) do
            if type(item) == "string" and #item <= 100 and #out < 200 then
                table.insert(out, item)
            end
        end
        return out
    elseif type(value) == "string" then
        if #value > 100 then return nil end
        if key:match("Color$") and not COLOR_PRESETS[value] then return nil end
        if key == "currentConfig" and not validProfileName(value) then return nil end
        if key == "targetPart" and not table.find({"Head","UpperTorso","LowerTorso","Random","Closest"}, value) then return nil end
    end
    return value
end

local function SaveStateToConfig(name)
    if not CFG.ready or not CFG.save or not validProfileName(name) then return false end
    local data = {}
    for key in pairs(DEFAULT_STATE) do data[key] = state[key] end
    return CFG.save(name, data)
end

local function LoadStateFromConfig(name)
    if not CFG.load or not validProfileName(name) then return false end
    local data = CFG.load(name)
    if type(data) ~= "table" then return false end
    if stopAll then stopAll() end
    for key, value in pairs(data) do
        local checked = savedValue(key, value)
        if checked ~= nil then state[key] = checked end
    end
    -- Profiles store preferences, never a running automation or player modifier.
    for _, key in ipairs({"espEnabled","silentAim","noRecoil","noSpread","infiniteAmmo","instantReload",
        "infiniteStamina","antiRagdoll","antiFallDamage","infiniteHorseStamina","alwaysDay",
        "gravityEnabled","hipHeightEnabled","speedEnabled","walkUnderWater","allowGunsUnderWater",
        "highlightGoldBars"}) do state[key] = false end
    state.fullBrightLevel = 0
    state.currentConfig = name
    ESP.lastUpdate = 0
    return true
end

local function ResetStateToDefault()
    if stopAll then stopAll() end
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
        if not ready or not validProfileName(name) then return false end
        local ok, json = pcall(S.HttpService.JSONEncode, S.HttpService, data)
        if not ok then return false end
        return pcall(function() writefile(FOLDER .. name .. ".json", json) end)
    end
    CFG.load = function(name)
        if not ready or not validProfileName(name) then return nil end
        local content
        local ok = pcall(function() content = readfile(FOLDER .. name .. ".json") end)
        if not ok or not content or content == "" then return nil end
        local ok2, decoded = pcall(function() return S.HttpService:JSONDecode(content) end)
        if not ok2 or type(decoded) ~= "table" then return nil end
        return decoded
    end
    CFG.delete = function(name)
        if not ready or not canDel or not validProfileName(name) then return false end
        return pcall(function() delfile(FOLDER .. name .. ".json") end)
    end
end

-- ====== FULL BRIGHT + DAY ======
local function initFB()
    local brightConn = nil
    local originalExposure, originalTimeBase
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
            if originalExposure ~= nil then
                pcall(function() S.Lighting.ExposureCompensation = originalExposure end)
                originalExposure = nil
            end
        else
            if originalExposure == nil then originalExposure = S.Lighting.ExposureCompensation end
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
        originalTimeBase = TimeBase.Value
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
        if originalTimeBase ~= nil and TimeBase then
            pcall(function() TimeBase.Value = originalTimeBase end)
            originalTimeBase = nil
        end
    end
    FB.stop = function() FB.setLevel(0); stopDay() end
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
        S.Camera = S.Workspace.CurrentCamera or S.Camera
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
    local connection
    local originalGravity
    local records = setmetatable({}, {__mode="k"})
    local function humanoid()
        local character = Global and Global.PlayerCharacter and Global.PlayerCharacter.Character or S.LocalPlayer.Character
        if not character then
            local entities = S.Workspace:FindFirstChild("WORKSPACE_Entities")
            local players = entities and entities:FindFirstChild("Players")
            character = players and players:FindFirstChild(S.LocalPlayer.Name)
        end
        return character and character:FindFirstChildOfClass("Humanoid")
    end
    local function restoreProperty(property)
        for hum, record in pairs(records) do
            if record[property] ~= nil then
                pcall(function() hum[property] = record[property] end)
                record[property] = nil
            end
        end
    end
    local function apply()
        if state.destroyed then return end
        if state.gravityEnabled then
            if originalGravity == nil then originalGravity = S.Workspace.Gravity end
            S.Workspace.Gravity = state.gravityValue
        end
        local hum = humanoid()
        if hum then
            local record = records[hum] or {}
            records[hum] = record
            for _, setting in ipairs({{"HipHeight","hipHeightEnabled","hipHeightValue"}, {"WalkSpeed","speedEnabled","speedValue"}}) do
                if state[setting[2]] then
                    local property = setting[1]
                    if record[property] == nil then record[property] = hum[property] end
                    hum[property] = state[setting[3]]
                end
            end
        end
    end
    local function updateConnection()
        if state.gravityEnabled or state.hipHeightEnabled or state.speedEnabled then
            if not connection then connection = S.RunService.Heartbeat:Connect(apply) end
            apply()
        elseif connection then connection:Disconnect(); connection = nil end
    end
    Physics.setGravity = function(enabled, value)
        state.gravityEnabled = enabled == true
        if type(value) == "number" and value == value then state.gravityValue = math.clamp(value,83,500) end
        if not enabled and originalGravity ~= nil then S.Workspace.Gravity = originalGravity; originalGravity = nil end
        updateConnection()
    end
    Physics.setHipHeight = function(enabled, value)
        state.hipHeightEnabled = enabled == true
        if type(value) == "number" and value == value then state.hipHeightValue = math.clamp(value,1,10) end
        if not enabled then restoreProperty("HipHeight") end
        updateConnection()
    end
    Physics.setSpeed = function(enabled, value)
        state.speedEnabled = enabled == true
        if type(value) == "number" and value == value then state.speedValue = math.clamp(value,1,45) end
        if not enabled then restoreProperty("WalkSpeed") end
        updateConnection()
    end
    Physics.reapplyHip = apply
    Physics.reapplySpeed = apply
    Physics.stop = function()
        if connection then connection:Disconnect(); connection = nil end
        if originalGravity ~= nil then pcall(function() S.Workspace.Gravity = originalGravity end); originalGravity = nil end
        restoreProperty("HipHeight")
        restoreProperty("WalkSpeed")
    end
end

-- =================================================================
--  WALK UNDER WATER + ALLOW GUNS UNDERWATER
-- =================================================================
local function initWater()
    local swimCtrl = nil
    local swimConn = nil
    local swimOriginal
    local gunOwner
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
                if not swimOriginal then
                    swimOriginal = {}
                    for _, key in ipairs({"ClampSurfaceMovement","MaxJumpDepth","SurfaceDepth","DragForceMultiplier"}) do
                        swimOriginal[key] = {value=sw[key]}
                    end
                end
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
        if swimCtrl and swimOriginal then
            for key, record in pairs(swimOriginal) do pcall(function() swimCtrl[key] = record.value end) end
            swimOriginal = nil
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
        if gunOwner == pc and origCanSwitch then return end
        if gunOwner and origCanSwitch then gunOwner.CanSwitchToItem = origCanSwitch end
        gunOwner = pc
        origCanSwitch = pc.CanSwitchToItem
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
        if gunOwner and origCanSwitch then pcall(function() gunOwner.CanSwitchToItem = origCanSwitch end) end
        origCanSwitch = nil
        gunOwner = nil
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
local EVENT_HOSTILES = {Zombie=true, ZombieSoldier=true, BossZombie=true, ColonelBoss=true}
local EVENT_GUIDES = {DemonHunterJane=true, BogWitch=true}
local function initAdapter()
    local npcModule = Global and Global.ClientNPCs
    Adapter.npcValues = function(container)
        local states = Global and Global.ClientNPCState
        local id = container and tonumber(container:GetAttribute("ID"))
        if states and type(states.FindValues) == "function" and id then
            local ok, values = pcall(states.FindValues, id)
            if ok and type(values) == "table" then return values end
        end
        return nil
    end
    Adapter.resolveNPC = function(container)
        if not container or not container.Parent then return nil end
        local values = Adapter.npcValues(container)
        if values and (values.Hidden == true or (type(values.Health) == "number" and values.Health <= 0)) then return nil end
        local native = npcModule and npcModule.NPC_Map and npcModule.NPC_Map[container]
        if native and (native.Unloaded or (native.Attributes and native.Attributes.Hidden)) then return nil end
        local rig = native and native.Character
        if typeof(rig) ~= "Instance" or not rig:IsA("Model") or not rig:IsDescendantOf(S.Workspace) then
            rig = nil
            -- Mounted NPCs also parent a SpectralHorse here. Prefer the rider's torso rig.
            local bestScore = 0
            local function consider(model)
                if not model:IsA("Model") then return end
                local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("RootPart")
                local head = model:FindFirstChild("Head")
                local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or model:FindFirstChild("LowerTorso")
                local score = (root and root:IsA("BasePart") and 1 or 0)
                    + (head and head:IsA("BasePart") and 2 or 0)
                    + (torso and torso:IsA("BasePart") and 8 or 0)
                if score > bestScore then rig = model; bestScore = score end
            end
            for _, child in ipairs(container:GetChildren()) do
                consider(child)
            end
            local legacy = container:FindFirstChild("Model")
            if legacy then
                consider(legacy)
                for _, child in ipairs(legacy:GetDescendants()) do consider(child) end
            end
        end
        if not rig or not rig:IsDescendantOf(S.Workspace) then return nil end
        Adapter.npcByRig[rig] = values or (native and native.Attributes)
        return rig
    end
    Adapter.actionPart = function(action)
        if not action or not action:IsDescendantOf(S.Workspace) then return nil end
        local part = action:IsA("BillboardGui") and action.Adornee or nil
        if part and part:IsA("Attachment") then part = part.Parent end
        if not part then part = action.Parent end
        if part and part:IsA("BasePart") then return part end
        return nil
    end
    local function addAction(action)
        if action.Name == "PickupForageable" then Adapter.plants[action] = true end
    end
    for _, action in ipairs(S.CollectionService:GetTagged("ObjectActionGroup")) do addAction(action) end
    connect(S.CollectionService:GetInstanceAddedSignal("ObjectActionGroup"), addAction)
    connect(S.CollectionService:GetInstanceRemovedSignal("ObjectActionGroup"), function(action) Adapter.plants[action] = nil end)
    Adapter.snapshot = function()
        local result = {hostiles=0, guides=0, loaded=0, plants=0, cauldrons=0, boss="Not present in replicated NPC metadata"}
        local entities = S.Workspace:FindFirstChild("WORKSPACE_Entities")
        local npcs = entities and entities:FindFirstChild("NPCs")
        if npcs then for _, container in ipairs(npcs:GetChildren()) do
            local kind = container:GetAttribute("Type")
            local values = Adapter.npcValues(container)
            local alive = not values or (values.Hidden ~= true and (type(values.Health) ~= "number" or values.Health > 0))
            if alive and (EVENT_HOSTILES[kind] or EVENT_GUIDES[kind]) then
                if EVENT_HOSTILES[kind] then result.hostiles += 1 else result.guides += 1 end
                if Adapter.resolveNPC(container) then result.loaded += 1 end
            end
            if kind == "ColonelBoss" and values then
                result.boss = string.format("%.0f / %.0f HP | %s", tonumber(values.Health) or 0,
                    tonumber(values.MaxHealth) or 0, tostring(values.BossState or "State unavailable"))
            end
        end end
        for action in pairs(Adapter.plants) do
            if action:GetAttribute("Disabled") ~= true and Adapter.actionPart(action) then result.plants += 1 end
        end
        for _, model in ipairs(S.CollectionService:GetTagged("HalloweenCauldron")) do
            if model:IsDescendantOf(S.Workspace) then result.cauldrons += 1 end
        end
        return result
    end
end

local function readEntityHealth(character)
    if not character then return nil, nil, false end
    local function finite(value, positive)
        if type(value) ~= "number" and type(value) ~= "string" then return nil end
        value = tonumber(value)
        if not value or value ~= value or math.abs(value) >= math.huge then return nil end
        if positive then return value > 0 and value or nil end
        return math.max(0, value)
    end
    local function valueChild(parent, name, positive)
        local value = parent and parent:FindFirstChild(name)
        if value and (value:IsA("NumberValue") or value:IsA("IntValue")) then return finite(value.Value, positive) end
        return nil
    end
    local function attribute(name, alternate, positive)
        local value = finite(character:GetAttribute(name), positive)
        if value == nil and alternate then value = finite(character:GetAttribute(alternate), positive) end
        return value
    end
    local npc = Adapter.npcByRig[character]
    local wildlife = Global and Global.WildLife
    local animal
    if wildlife and type(wildlife.GetWildLifeObject) == "function" then
        local ok, result = pcall(wildlife.GetWildLifeObject, wildlife, character)
        if ok and type(result) == "table" and result.character == character then animal = result end
    end
    local parent = character.Parent
    local inAnimals = parent and parent.Name == "Animals" and parent.Parent and parent.Parent.Name == "WORKSPACE_Entities"
    local horseStats = character:FindFirstChild("HorseStats")
    local isAnimal = not npc and (animal ~= nil or inAnimals or horseStats ~= nil
        or (character:FindFirstChild("RigType") ~= nil and character:FindFirstChild("Health") ~= nil))
    local healthValue = valueChild(character, "Health")
    local maxValue = valueChild(character, "MaxHealth", true)
    if isAnimal then
        -- Wildlife Humanoids are animation controllers, commonly fixed at 100/100.
        local health = healthValue or attribute("Health", "HP") or (animal and finite(animal.Health))
        -- Horse class MaxHealth is a breed range, not this individual horse's maximum.
        local maximum = maxValue or attribute("MaxHealth", "MaxHP", true)
            or valueChild(horseStats, "Health", true)
            or (animal and finite(rawget(animal, "MaxHealth"), true))
        return health, maximum, true
    end
    local controller = character:FindFirstChild("Human") or character:FindFirstChild("Humanoid")
        or character:FindFirstChildOfClass("Humanoid")
    return (npc and finite(npc.Health)) or (controller and finite(controller.Health)) or healthValue or attribute("Health", "HP"),
        (npc and finite(npc.MaxHealth, true)) or (controller and finite(controller.MaxHealth, true)) or maxValue or attribute("MaxHealth", "MaxHP", true), false
end

local function formatEntityHealth(character)
    local health, maximum = readEntityHealth(character)
    if health == nil then return "HP unavailable" end
    if maximum and maximum >= health then
        return string.format("%.0f/%.0f HP", math.ceil(health), math.ceil(maximum))
    end
    -- A missing replicated maximum is unknown; never invent 100 or assume current HP is full HP.
    return string.format("%.0f HP", math.ceil(health))
end

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
            if cached ~= false and cached.Parent then return cached end
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
        local health = readEntityHealth(c)
        return health
    end
    local function getMaxHealth(c)
        local _, maximum = readEntityHealth(c)
        return maximum
    end
    local function isAlive(c)
        if not c then return false end
        local values = Adapter.npcByRig[c]
        if values and (values.Hidden == true or (type(values.Health) == "number" and values.Health <= 0)) then return false end
        local health, _, animal = readEntityHealth(c)
        if health ~= nil and health <= 0 then return false end
        if animal then return true end
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
        h.Name = "TWW_EntityHighlight"
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
        for _, key in ipairs({"label", "tracer"}) do
            local drawing = esp[key]
            if drawing then
                pcall(function() drawing:Remove() end)
                local index = table.find(drawings, drawing)
                if index then table.remove(drawings, index) end
                esp[key] = nil
            end
        end
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
                tp[#tp+1] = formatEntityHealth(char)
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
                S.Camera = S.Workspace.CurrentCamera or S.Camera
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
            if nf then for _, container in ipairs(nf:GetChildren()) do
                do
                    local rig = Adapter.resolveNPC(container)
                    if rig and isAlive(rig) then
                        local part = getTargetPart(rig)
                        local distance = part and getDistance(part)
                        if distance and (state.maxDistance == 0 or distance <= state.maxDistance) then
                            active[container] = true
                            local esp = getESP(container)
                            esp.entityType = "npc"
                            local color = COLOR_PRESETS[state.npcColor] or COLOR_PRESETS.Purple
                            renderEntityESP(esp, part, {color=color, heightOffset=2, showHealthData=true,
                                character=rig, name=container.Name, distance=distance, showTracers=false})
                            if distance <= CHAMS_TRACER_MAX_DIST then renderChams(esp, rig, color, "npc", false) end
                        end
                    end
                end
            end end
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

        local function marker(key, part, name, color)
            if not part or not part:IsA("BasePart") or not part:IsDescendantOf(S.Workspace) then return end
            local distance = getDistance(part)
            if state.maxDistance > 0 and distance > state.maxDistance then return end
            active[key] = true
            local esp = getESP(key)
            esp.entityType = "event"
            renderEntityESP(esp, part, {color=color, heightOffset=2, showHealthData=false,
                name=name, distance=distance, showTracers=false})
        end
        if state.showPlants then
            for action in pairs(Adapter.plants) do
                if action:GetAttribute("Disabled") ~= true then
                    local item = action:GetAttribute("ItemType")
                    if type(item) == "string" then
                        marker(action, Adapter.actionPart(action), item, COLOR_PRESETS.Green)
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
local function resolveNativeRagdollMethods(global, storage, environment, session)
    if type(getfenv) ~= "function" or type(debug.getconstants) ~= "function" or type(debug.getupvalues) ~= "function" then
        return nil, "Native ragdoll inspection is unavailable; rejoin with a supported executor."
    end
    local modules = storage:FindFirstChild("Modules")
    local character = modules and modules:FindFirstChild("Character")
    local playerScript = character and character:FindFirstChild("PlayerCharacter")
    local ragdollsScript = character and character:FindFirstChild("Ragdolls")
    local sharedModules = storage:FindFirstChild("SharedModules")
    local globalModule = sharedModules and sharedModules:FindFirstChild("Global")
    local networkScript = globalModule and globalModule:FindFirstChild("Network")
    if not playerScript or not ragdollsScript or not networkScript then
        return nil, "Native ragdoll inspection is unavailable; rejoin with a supported executor."
    end
    local signatures = {
        Ragdoll={"StopFlight","ToggleSelfRagdoll","CreateRagdollForce","EnterRagdoll"},
        ToggleSelfRagdoll={"Disabled SelfRagdoll when dead","ControlRagdoll","UncontrolRagdoll"},
        OnControlLost={"StopSpectating","DropCrate","UnMount","FaceMouse","WalkSpeed"},
        RequestKnockback={"IsRagdolled","IsDead","IsTiedUp","FindFirstChild","Ragdoll","CFrame"},
        EnterRagdoll={"ToggleCollisionModel","ToggleWeldsActive","RagdollImpactListeners","VectorForce"},
        FireServer={"GetHandler","Event","Remote","FireServer","task","spawn"},
    }
    local function matches(fn, name)
        if type(fn) ~= "function" then return false end
        local ok, scope = pcall(getfenv, fn)
        local source = name == "EnterRagdoll" and ragdollsScript or name == "FireServer" and networkScript or playerScript
        if not ok or type(scope) ~= "table" or scope.script ~= source then return false end
        local got, constants = pcall(debug.getconstants, fn)
        if not got or type(constants) ~= "table" then return false end
        local strings = {}
        for _, value in pairs(constants) do if type(value) == "string" then strings[value] = true end end
        for _, value in ipairs(signatures[name]) do if not strings[value] then return false end end
        -- The same module also exports FireServerUnreliable with otherwise identical constants.
        if name == "FireServer" and strings.Unreliable then return false end
        if name ~= "RequestKnockback" and name ~= "FireServer" then
            local read, values = pcall(debug.getupvalues, fn)
            if not read or type(values) ~= "table" then return false end
            local ownsGlobal = false
            for _, value in pairs(values) do if value == global then ownsGlobal = true; break end end
            if not ownsGlobal then return false end
        end
        return true
    end
    local cache = environment.TWWNativeCharacterMethods
    local cached = type(cache) == "table" and cache.global == global
        and cache.jobId == session.jobId and cache.placeId == session.placeId and cache.methods
    local methods, missing = {}, {}
    local pc = global.PlayerCharacter
    local legacyNoop = false
    for name in pairs(signatures) do
        local owner = name == "EnterRagdoll" and global.Ragdolls or name == "FireServer" and global.Network or pc
        local current = owner[name]
        if matches(current, name) then methods[name] = current
        elseif type(cached) == "table" and matches(cached[name], name) then methods[name] = cached[name]
        else missing[name] = {} end
        if type(current) == "function" then
            local ok, constants = pcall(debug.getconstants, current)
            if ok and type(constants) == "table" and next(constants) == nil then legacyNoop = true end
        end
    end
    if next(missing) then
        if type(getgc) ~= "function" then return nil, "Native ragdoll callbacks were replaced; rejoin to restore them." end
        local ok, objects = pcall(getgc, false)
        if not ok or type(objects) ~= "table" then return nil, "Cannot locate native ragdoll callbacks; rejoin to restore them." end
        local checked = 0
        -- Executor GC arrays can have holes: ipairs silently misses the surviving original closures.
        for _, fn in pairs(objects) do
            if type(fn) == "function" then
                for name, candidates in pairs(missing) do
                    if matches(fn, name) then candidates[fn] = true end
                end
                checked += 1
                if checked % 10000 == 0 then task.wait() end
            end
        end
        for name, candidates in pairs(missing) do
            local original = next(candidates)
            if not original or next(candidates, original) ~= nil then
                return nil, "Cannot uniquely identify native " .. name .. "; rejoin before using Prevent Ragdoll."
            end
            methods[name] = original
        end
    end
    -- Keep the actual live closures: recompiling them would separate private ragdoll state.
    environment.TWWNativeCharacterMethods = {
        global=global,jobId=session.jobId,placeId=session.placeId,methods=methods,
    }
    return methods, nil, legacyNoop
end

local function initChar()
    local PC = nil
    local Orig = {}
    local NetHooked = false
    local PinnedHorse = nil
    local pinnedState
    local ready = false
    local PIN_MT
    local ragdollGuard
    local nativeOwner, nativeMethods, nativeAttemptedOwner
    local pendingLegacyRecovery = false
    local recoveryOwner, recoveryCharacter
    local lastGetUp = -math.huge
    local recoveryBusy = false
    local function ensureWritable(t)
        if typeof(t) ~= "table" then return end
        if type(isreadonly) == "function" and isreadonly(t) then
            pcall(function()
                if type(setreadonly) == "function" then setreadonly(t, false)
                elseif type(makewritable) == "function" then makewritable(t) end
            end)
        end
    end
    local function restoreNativeRagdollMethods(pc)
        if nativeOwner == pc then return true end
        if nativeAttemptedOwner == pc then return false end
        nativeAttemptedOwner = pc
        local methods, err, legacy = resolveNativeRagdollMethods(Global, S.ReplicatedStorage, environment,
            {placeId=game.PlaceId,jobId=game.JobId})
        if not methods or state.destroyed or Global.PlayerCharacter ~= pc then
            CHAR.lastRagdollRecoveryError = err or "Character changed during native callback recovery."
            warn("[TWW] " .. CHAR.lastRagdollRecoveryError)
            return false
        end
        for name, fn in pairs(methods) do
            local owner = name == "EnterRagdoll" and Global.Ragdolls or name == "FireServer" and Global.Network or pc
            ensureWritable(owner)
            if name == "FireServer" and NetHooked then Orig.FireServer = fn else owner[name] = fn end
        end
        nativeOwner, nativeMethods = pc, methods
        pendingLegacyRecovery = legacy
        return true
    end
    local function looksLikeOriginal(f)
        if typeof(f) ~= "function" then return false end
        return true
    end
    local function refreshPC()
        local pc = Global.PlayerCharacter
        if typeof(pc) == "table" and pc ~= PC then
            PC = pc
            if looksLikeOriginal(pc.LowerStamina) then
                Orig.LowerStamina = pc.LowerStamina
                Orig.LocalLowerStamina = pc.LocalLowerStamina
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
                if eventName == "DamageSelf" then return end
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
        if not pinnedState then
            local originalMT = getmetatable(ps)
            if originalMT ~= nil and type(originalMT) ~= "table" then return false end
            PIN_MT = originalMT and table.clone(originalMT) or {}
            local index = originalMT and originalMT.__index
            local newIndex = originalMT and originalMT.__newindex
            PIN_MT.__index = function(t, key)
                if key == "Stamina" then return 100 end
                if type(index) == "function" then return index(t, key) end
                if type(index) == "table" then return index[key] end
                return nil
            end
            PIN_MT.__newindex = function(t, key, value)
                if key == "Stamina" then return end
                if type(newIndex) == "function" then newIndex(t, key, value)
                elseif type(newIndex) == "table" then newIndex[key] = value
                else rawset(t, key, value) end
            end
            pinnedState = {state=ps,value=rawget(ps,"Stamina"),mt=originalMT}
            if not pcall(setmetatable, ps, PIN_MT) then pinnedState = nil; PIN_MT = nil; return false end
        end
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
        if pinnedState then
            local ps = pinnedState.state
            if getmetatable(ps) == PIN_MT then
                pcall(setmetatable, ps, pinnedState.mt)
                rawset(ps, "Stamina", pinnedState.value)
            end
            pinnedState = nil
            PIN_MT = nil
        end
    end

    -- Guard optional local starts, never the game's entry/exit or mount cleanup state machine.
    local function nativeFlag(method, owner, ...)
        if type(method) ~= "function" then return false end
        local ok, value = pcall(method, owner, ...)
        return ok and value == true
    end
    local function serverRagdolled(pc)
        local playerState = Global.ReplicatedState and Global.ReplicatedState.State
        return (type(pc.State) == "table" and pc.State.Ragdolled == true)
            or (type(playerState) == "table" and playerState.Ragdolled == true)
    end
    local function localRagdolled(character)
        local ragdolls = Global.Ragdolls
        return ragdolls and nativeFlag(ragdolls.IsRagdolledLocal, ragdolls, character)
    end
    local function restoreRagdollGuard()
        if ragdollGuard then
            local record = ragdollGuard
            ensureWritable(record.owner)
            if record.owner.Ragdoll == record.wrapper then record.owner.Ragdoll = record.original end
            ragdollGuard = nil
        end
    end
    local function recoverRagdoll()
        if not ready or state.destroyed or not state.antiRagdoll or recoveryBusy then return false end
        local pc = Global.PlayerCharacter
        if type(pc) ~= "table" or not pc.Character or pc.IsDead or pc.IsTiedUp then return false end
        if not restoreNativeRagdollMethods(pc) then return false end
        local character = pc.Character
        if typeof(character) == "Instance" and not character:IsDescendantOf(S.Workspace) then return false end
        if recoveryOwner ~= pc or recoveryCharacter ~= character then
            recoveryOwner, recoveryCharacter = pc, character
            lastGetUp = -math.huge
        end
        local function current()
            return not state.destroyed and state.antiRagdoll
                and Global.PlayerCharacter == pc and pc.Character == character
                and not pc.IsDead and not pc.IsTiedUp
        end
        recoveryBusy = true
        local ok, attempted = pcall(function()
            -- An older no-op can detach a horse without setting any ragdoll flag, leaving Physics forever.
            if pendingLegacyRecovery then
                local mount = Global.WildLife and Global.WildLife.RidingAnimal
                local root, human = pc.RootPart, pc.Human
                local weld = root and root:FindFirstChild("Animal_To_Player")
                if not mount and not (weld and weld.Part1) then
                    pendingLegacyRecovery = false
                    if human and human:GetState() == Enum.HumanoidStateType.Physics
                        and not serverRagdolled(pc) and not localRagdolled(character)
                        and nativeFlag(pc.HasFullControl, pc) then
                        nativeMethods.Ragdoll(pc, nil, true)
                        if not current() then return false end
                    end
                end
            end
            -- Repair a server-accepted / physical ragdoll whose local flag was blocked by an older hook.
            -- This is the same entry sequence as the native EnterRagdoll event handler.
            if (serverRagdolled(pc) or localRagdolled(character)) and nativeFlag(pc.HasFullControl, pc) then
                if type(pc.OnControlLost) ~= "function" or type(pc.ToggleSelfRagdoll) ~= "function" then return false end
                pc:OnControlLost()
                if not current() then return false end
                pc:ToggleSelfRagdoll(true)
            end
            if not current() or not nativeFlag(pc.CanGetUp, pc) or type(pc.GetUp) ~= "function" then return false end
            if os.clock() - lastGetUp < 1.5 then return false end
            lastGetUp = os.clock()
            -- GetUp performs the native AttemptGetUp RPC and preserves cooldowns, animation and acknowledgement.
            pc:GetUp()
            return true
        end)
        recoveryBusy = false
        if not ok then
            CHAR.lastRagdollRecoveryError = tostring(attempted)
            warn("[TWW] Ragdoll recovery: " .. tostring(attempted))
            return false
        end
        CHAR.lastRagdollRecoveryError = nil
        return attempted == true
    end
    local function applyAntiRagdoll()
        if not ready then return false end
        local pc = refreshPC()
        if not pc or type(pc.Ragdoll) ~= "function" then return false end
        if ragdollGuard and (ragdollGuard.owner ~= pc or pc.Ragdoll ~= ragdollGuard.wrapper) then restoreRagdollGuard() end
        if not restoreNativeRagdollMethods(pc) then return false end
        if not ragdollGuard then
            local original = nativeMethods.Ragdoll
            local function wrapper(self, ...)
                -- UnMount(true) already detached the rider and passes this flag; its transition must finish.
                local forcedTransition = select(2, ...) == true
                if self == pc and self == Global.PlayerCharacter and state.antiRagdoll and not state.destroyed
                    and not forcedTransition
                    and not self.IsDead and not self.IsTiedUp and not serverRagdolled(self)
                    and not localRagdolled(self.Character) and nativeFlag(self.HasFullControl, self) then
                    return
                end
                return original(self, ...)
            end
            ensureWritable(pc)
            pc.Ragdoll = wrapper
            ragdollGuard = {owner=pc,original=original,wrapper=wrapper}
        end
        return true
    end
    local function removeAntiRagdoll()
        restoreRagdollGuard()
        recoveryOwner, recoveryCharacter = nil, nil
        lastGetUp = -math.huge
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
    local removeHorseStamina
    local function applyHorseStamina()
        if not ready then return false end
        local animal = Global.WildLife and Global.WildLife.RidingAnimal
        if typeof(animal) ~= "table" then return false end
        local mt = getmetatable(animal)
        if typeof(mt) == "table" and mt.__TWW_PIN then return true end
        ensureWritable(animal)
        if PinnedHorse then removeHorseStamina() end
        PinnedHorse = {animal=animal, origMT=mt, boosts=rawget(animal,"Boosts")}
        pcall(function() setmetatable(animal, makeHorsePinMT(mt)) end)
        rawset(animal, "Boosts", nil)
        return true
    end
    removeHorseStamina = function()
        if not PinnedHorse then return end
        local animal = PinnedHorse.animal
        if typeof(animal) == "table" then
            ensureWritable(animal)
            pcall(function() setmetatable(animal, PinnedHorse.origMT) end)
            rawset(animal, "Boosts", PinnedHorse.boosts)
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
    CHAR.recoverRagdoll = recoverRagdoll
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
        if state.destroyed then return end
        restoreNativeRagdollMethods(Global.PlayerCharacter)
        CHAR.sync()
        if (state.infiniteAmmo or state.instantReload) and AMMO.install then AMMO.install() end
        if Water then Water.reapply() end
    end)

    task.spawn(function()
        local nextSync = 0
        while not state.destroyed do
            task.wait(0.25)
            if state.destroyed then return end
            if ready then
                pcall(function()
                    if os.clock() >= nextSync or Global.PlayerCharacter ~= PC then
                        nextSync = os.clock() + 2
                        if Global.PlayerCharacter ~= PC then refreshPC() end
                        if state.infiniteStamina or state.antiRagdoll or state.antiFallDamage or state.infiniteHorseStamina then CHAR.sync() end
                        if not NetHooked and (state.infiniteStamina or state.antiRagdoll or state.antiFallDamage) then hookFireServer() end
                    end
                    if state.antiRagdoll then recoverRagdoll() end
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
    local ANIMAL_FB = {Head={"Head","Skull","Body","Neck"}, UpperTorso={"Body","Head","Skull","Neck"}, LowerTorso={"Body","Head","Skull","LeftThigh","RightThigh"}}
    local ANIMAL_KW = {"head","skull","body","neck","leg","thigh","hoof","foot","arm","shoulder","paw"}
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
        local wildlife = Global and Global.WildLife
        local r = wildlife and wildlife.RidingAnimal
        if wildlife and type(wildlife.GetRidingAnimal) == "function" then
            local ok, riding = pcall(wildlife.GetRidingAnimal, wildlife)
            if ok and riding then r = riding end
        end
        if type(r) == "table" then
            if typeof(r.character) == "Instance" then return r.character end
            if typeof(r.hrp) == "Instance" then return r.hrp.Parent end
        end
        return nil
    end
    local function getOwnRep()
        local e = S.Workspace:FindFirstChild("WORKSPACE_Entities")
        if not e then return nil end
        local pf = e:FindFirstChild("Players")
        if pf then return pf:FindFirstChild(S.LocalPlayer.Name) end
        return nil
    end
    local function bodyPart(rig, name)
        local part = rig:FindFirstChild(name) or rig:FindFirstChild(name, true)
        if part and part:IsA("BasePart") and part:IsDescendantOf(S.Workspace) then return part end
        return nil
    end
    local function collectRigParts(rig, isAnimal)
        local parts = {}
        if not rig then return parts end
        if isAnimal then
            for _, c in ipairs(rig:GetDescendants()) do
                local parent = c.Parent
                local collisionPart = false
                while parent and parent ~= rig do
                    if nameMatches(parent.Name, {"collision", "hitbox"}) then collisionPart = true; break end
                    parent = parent.Parent
                end
                if c:IsA("BasePart") and c:IsDescendantOf(S.Workspace) and not collisionPart
                    and not nameMatches(c.Name, ANIMAL_EXCL) and nameMatches(c.Name, ANIMAL_KW) then
                    table.insert(parts, c)
                end
            end
        else
            for _, n in ipairs(VALID_PLAYER_PARTS) do
                local p = bodyPart(rig, n)
                if p then table.insert(parts, p) end
            end
        end
        return parts
    end
    local function getNpcRig(folder)
        local rig = Adapter.resolveNPC(folder)
        if rig and ESP.isAlive(rig) then return rig end
        return nil
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
            local p = bodyPart(rig, n)
            if p then return p end
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
    COMBAT.getTargetVelocity = function(target)
        local velocity = target.part.AssemblyLinearVelocity
        if velocity and velocity.Magnitude >= 0.1 then return velocity end
        local root = target.model and (target.model:FindFirstChild("HumanoidRootPart", true) or target.model:FindFirstChild("RootPart", true))
        local rootVelocity = root and root.AssemblyLinearVelocity
        if rootVelocity and rootVelocity.Magnitude >= 0.1 then return rootVelocity end
        -- Interpolated NPC roots can be anchored: physics velocity is then zero.
        local registry = Global and Global.ClientNPCs and Global.ClientNPCs.NPC_Map
        local npc = target.kind == "NPC" and registry and registry[target.model]
        if npc and npc.IsMoving == true and type(npc.ReplicatedMoveSpeed) == "number" then
            local direction = npc.DirectionVector
            local kind = typeof(direction)
            local speed = npc.ReplicatedMoveSpeed
            if (kind == "Vector3" or kind == "vector") and speed >= 0 and speed < math.huge then
                return Vector3.new(direction.X, direction.Y, direction.Z) * speed
            end
        end
        return rootVelocity or velocity
    end
    COMBAT.getBestTarget = function(origin)
        if state.destroyed then return nil end
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
        if state.targetPlayers then
            local f = Entities:FindFirstChild("Players")
            if f then
                for _, m in ipairs(f:GetChildren()) do
                    if m.Name ~= S.LocalPlayer.Name then
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
                    local available = m:IsA("Model") and m ~= om and ESP.isAlive(m)
                    local health = m:FindFirstChild("Health")
                    if health and (health:IsA("NumberValue") or health:IsA("IntValue")) and health.Value <= 0 then available = false end
                    local wildlife = Global and Global.WildLife
                    if available and wildlife and type(wildlife.GetWildLifeObject) == "function" then
                        local ok, animal = pcall(wildlife.GetWildLifeObject, wildlife, m)
                        if ok and type(animal) == "table" then
                            if animal.Unloaded == true or (type(animal.Health) == "number" and animal.Health <= 0) then available = false end
                        end
                    end
                    if available then
                        -- Target Animals includes horses and animal bosses; ESP filters are independent.
                        evaluate(m, resolveAimPart(m, true), "Animal", m.Name)
                    end
                end
            end
        end
        if state.targetNPCs then
            local f = Entities:FindFirstChild("NPCs")
            if f then
                for _, n in ipairs(f:GetChildren()) do
                    local rig = getNpcRig(n)
                    if rig then
                        evaluate(rig, resolveAimPart(rig, false), "NPC", n.Name)
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
                        local tVel = COMBAT.getTargetVelocity(target)

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
                if type(sharedData) == "table" then sharedData = table.clone(sharedData) end
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

    local wandClass, oldWandCast
    local Utils = Global and Global.Utils
    local oldMouseHit = Utils and Utils.GetMouseHit
    local wandContexts = setmetatable({}, {__mode="k"})
    local function wandMouseHitHook(...)
        local context = wandContexts[coroutine.running()]
        if not installed or not context or state.destroyed or not state.silentAim or context.item.Owner ~= true then
            return oldMouseHit(...)
        end
        local ok, aim = pcall(function()
            local pc = Global.PlayerCharacter
            local item = context.item
            local model = item.Model
            local primary = model and model.PrimaryPart
            local castFrom = primary and primary:FindFirstChild("CastFrom")
            local projectiles = Global.SharedProjectiles
            if not pc or not pc.RootPart or not castFrom or not projectiles
                or type(projectiles.ResolveProjectileOrigin) ~= "function" then return nil end
            local origin = projectiles.ResolveProjectileOrigin(pc.RootPart.Position, castFrom.WorldPosition)
            local target = COMBAT.getBestTarget(origin)
            if not target or not target.part or not target.part:IsDescendantOf(S.Workspace) then return nil end
            local spells = Global.WandUtils and Global.WandUtils.Spells
            local spell = spells and spells[context.spell]
            local settings = spell and spell.Settings
            if not settings or type(settings.Speed) ~= "number" or settings.Speed <= 0 or settings.Speed >= math.huge then return nil end
            local charge = type(item.GetChargeAlpha) == "function" and item:GetChargeAlpha() or 0
            if type(charge) ~= "number" or charge ~= charge then charge = 0 end
            local speed = settings.Speed * (1 + math.clamp(charge, 0, 1) * 0.5)
            local position = target.part.Position
            local aimPosition = position
            local velocity
            if state.silentAimPrediction and (state.silentAimPredictionStrength or 0) > 0 then
                velocity = COMBAT.getTargetVelocity(target)
                if typeof(velocity) ~= "Vector3" then velocity = nil end
            end
            local gravity = type(settings.Gravity) == "number" and settings.Gravity or 0
            if gravity ~= gravity or math.abs(gravity) >= math.huge then gravity = 0 end
            -- Match the native charge-dependent speed and positionAt gravity used by WandUtils.
            for _ = 1, 3 do
                local flightTime = (aimPosition - origin).Magnitude / speed
                aimPosition = position + Vector3.new(0, gravity * flightTime * flightTime * 0.5, 0)
                if velocity then aimPosition += velocity * (flightTime * state.silentAimPredictionStrength) end
            end
            if (aimPosition - origin).Magnitude <= 0.01 then return nil end
            return aimPosition
        end)
        if ok and aim then return aim end
        return oldMouseHit(...)
    end
    local function wandCastHook(self, spellName, ...)
        if not installed or state.destroyed or not state.silentAim then
            return oldWandCast(self, spellName, ...)
        end
        local thread = coroutine.running()
        local previous = wandContexts[thread]
        wandContexts[thread] = self.Owner == true and {item=self,spell=spellName} or nil
        local values = table.pack(pcall(oldWandCast, self, spellName, ...))
        wandContexts[thread] = installed and previous or nil
        if not values[1] then error(values[2], 0) end
        return table.unpack(values, 2, values.n)
    end
    local function installWandAim()
        if not Utils then Utils = Global and Global.Utils; oldMouseHit = Utils and Utils.GetMouseHit end
        if not wandClass then
            local ok, result = pcall(function() return Global:LoadModule("WandItem") end)
            if ok and type(result) == "table" then wandClass = result; oldWandCast = result.Cast end
        end
        if wandClass and type(oldWandCast) == "function" and Utils and type(oldMouseHit) == "function" then
            Utils.GetMouseHit = wandMouseHitHook
            wandClass.Cast = wandCastHook
        end
    end
    local function removeWandAim()
        if wandClass and wandClass.Cast == wandCastHook then wandClass.Cast = oldWandCast end
        if Utils and Utils.GetMouseHit == wandMouseHitHook then Utils.GetMouseHit = oldMouseHit end
        table.clear(wandContexts)
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
        installWandAim()
        HOOKS.applyNoRecoil(state.noRecoil)
    end
    HOOKS.uninstall = function()
        if not installed then return end
        installed = false
        removeWandAim()
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
    local classRestores, instanceRestores = {}, setmetatable({}, {__mode="k"})
    local function replaceMethod(class, key, original, hook)
        table.insert(classRestores, {class=class,key=key,original=original,hook=hook})
        class[key] = hook
    end
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
        local proxy = makeMT(mt)
        if pcall(function() setmetatable(inst, proxy) end) then instanceRestores[inst] = {original=mt,proxy=proxy} end
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
            replaceMethod(cls, "new", origNew, newHook)
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
                replaceMethod(cls, mName, orig, hook)
            end
        end
        local origLoad = cls.Load
        if type(origLoad) == "function" and not ourHooks[origLoad] then
            local hook = function(self, ...)
                if state.instantReload and isWeapon(self) then fillInstant(self); return end
                return origLoad(self, ...)
            end
            ourHooks[hook] = true
            replaceMethod(cls, "Load", origLoad, hook)
        end
    end
    local function wrapWandClass(cls)
        if type(cls) ~= "table" or wrappedClasses[cls] then return end
        wrappedClasses[cls] = true
        local canCast, chargeAlpha = cls.CanCast, cls.GetChargeAlpha
        if type(canCast) == "function" then
            replaceMethod(cls, "CanCast", canCast, function(self, spellName, ...)
                local values = table.pack(canCast(self, spellName, ...))
                if values[1] or not state.infiniteAmmo or state.destroyed or self.Owner ~= true then
                    return table.unpack(values, 1, values.n)
                end
                local spells = Global.WandUtils and Global.WandUtils.Spells
                local spell = spells and spells[spellName]
                local settings = spell and spell.Settings
                local replicated = Global.ReplicatedState and Global.ReplicatedState.State
                local mana = replicated and replicated.Mana
                -- Only remove the verified mana denial; keep aim, action and cooldown eligibility.
                if type(settings) == "table" and type(settings.ManaCost) == "number"
                    and type(mana) == "number" and mana < settings.ManaCost
                    and self.IsAiming and not self.ActionRunning
                    and not (self.CastEnd and os.clock() < self.CastEnd) then
                    return true
                end
                return table.unpack(values, 1, values.n)
            end)
        end
        if type(chargeAlpha) == "function" then
            replaceMethod(cls, "GetChargeAlpha", chargeAlpha, function(self, ...)
                if state.infiniteAmmo and not state.destroyed and self.Owner == true and self.ChargingNow then
                    local spells = Global.WandUtils and Global.WandUtils.Spells
                    local spell = spells and spells[self.SpellName]
                    local settings = spell and spell.Settings
                    local replicated = Global.ReplicatedState and Global.ReplicatedState.State
                    local mana = replicated and replicated.Mana
                    if type(settings) == "table" and type(settings.ManaCost) == "number"
                        and type(mana) == "number" and mana <= settings.ManaCost * 2 then
                        return math.min((os.clock() - self.ChargingNow) / 0.75, 1)
                    end
                end
                return chargeAlpha(self, ...)
            end)
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
            local wandOk, wand = pcall(function() return Global:LoadModule("WandItem") end)
            if wandOk then wrapWandClass(wand) end
        end)
        pcall(findExisting)
        installed = ok
        return ok
    end
    AMMO.uninstall = function()
        for i = #classRestores, 1, -1 do
            local record = classRestores[i]
            if record.class[record.key] == record.hook then record.class[record.key] = record.original end
        end
        table.clear(classRestores)
        for instance, record in pairs(instanceRestores) do
            if getmetatable(instance) == record.proxy then pcall(setmetatable, instance, record.original) end
        end
        table.clear(instanceRestores)
        wrappedInstances = setmetatable({}, {__mode="k"})
        wrappedClasses = setmetatable({}, {__mode="k"})
        installed = false
    end
    AMMO.wrapExisting = findExisting
end

-- =================================================================
--  INVENTORY
-- =================================================================
local function initInventory()
    local activePrompt
    INV.stop = function()
        if activePrompt then pcall(function() activePrompt:InputHoldEnd() end); activePrompt = nil end
    end
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
        if not prompt.Enabled then return false, "The nearby vault prompt is disabled" end
        local attachment = prompt.Parent
        local point = attachment and attachment:IsA("Attachment") and attachment.WorldPosition
            or (attachment and attachment:IsA("BasePart") and attachment.Position)
        local character = Global and Global.PlayerCharacter and Global.PlayerCharacter.Character or S.LocalPlayer.Character
        local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
        if not point or not root or (root.Position - point).Magnitude > prompt.MaxActivationDistance then
            return false, "Move within the vault prompt's activation distance first"
        end
        INV.stop()
        local ok, err = pcall(function() prompt:InputHoldBegin() end)
        if not ok then return false, tostring(err) end
        activePrompt = prompt
        task.delay((prompt.HoldDuration or 0) + 0.15, function()
            if activePrompt == prompt then INV.stop() end
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

    local lastAlert = -math.huge
    local function announce()
        if state.destroyed or os.clock() - lastAlert < 3 then return end
        lastAlert = os.clock()
        if state.window then
            pcall(function() state.window:Notify("🦌 WENDIGO SPAWNED — check animal ESP for its location.", 6) end)
        end
    end

    local function watchFolder(folder)
        if not folder then return end
        connect(folder.ChildAdded, function(child)
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
            local deadline = os.clock() + 15
            local child = node:FindFirstChild(segment)
            while not child and not state.destroyed and os.clock() < deadline do
                task.wait(0.1)
                child = node:FindFirstChild(segment)
            end
            if state.destroyed or not child then return end
            node = child
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
    local viewport = S.Camera and S.Camera.ViewportSize or Vector2.new(1280,720)
    local Window = Library:CreateWindow("🤠 TWW | SmugLibV2", {
        Width = math.max(240, math.min(720, viewport.X - 40)),
        Height = math.max(220, math.min(640, viewport.Y - 40)),
        ToggleKey = Enum.KeyCode.RightShift,
        ConfigKey = "TWW_Ultimate_V3",
        ConfigAutoSave = false,
        OnClose = function()
            if not state.destroyed then
                SaveStateToConfig(state.currentConfig)
                if destroyRuntime then destroyRuntime() end
            end
        end,
    })
    state.window = Window
    local function toast(msg, dur) pcall(function() Window:Notify(msg, dur or 2) end) end

    local MainTab      = Window:Folder("🏠 Main")
    local VisualsTab   = Window:Folder("🎨 Visuals")
    local CombatTab    = Window:Folder("🎯 Combat")
    local UtilitiesTab = Window:Folder("🧍 Player")
    local ConfigTab    = Window:Folder("⚙️ Config")

    -- ================== MAIN ==================
    local master = MainTab:Section("⚡ Quick Controls")
    master:Label("Choose your ESP targets below. RightShift toggles this menu; J toggles Silent Aim.")
    uiHandles.checkboxes.espEnabled = master:Checkbox("👁️ Enable ESP", function(enabled)
        if _loadingConfig then return end
        state.espEnabled = enabled
        ESP.lastUpdate = 0
        if not enabled then
            if ESP.cleanup then ESP.cleanup() end
        end
    end, state.espEnabled)

    master:Button("🔄 Refresh Targets", function()
        if ESP.refresh then ESP.refresh() end
        ESP.lastUpdate = 0
        toast("Loaded targets refreshed.", 2)
    end)
    master:Button("🛑 Stop All Features", function()
        if stopAll then stopAll() end
        toast("All features stopped.", 2)
    end)

    local function entToggle(section, label, key)
        uiHandles.checkboxes[key] = section:Checkbox(label, function(enabled)
            if _loadingConfig then return end
            state[key] = enabled
            ESP.lastUpdate = 0
        end, state[key])
    end
    local people = MainTab:Section("👥 People")
    entToggle(people, "👤 Players", "showPlayers")
    entToggle(people, "🤖 NPCs & Bosses", "showNPCs")

    local resources = MainTab:Section("💎 Resources & Loot")
    entToggle(resources, "⛏️ Ore Deposits", "showOres")
    entToggle(resources, "📦 Dropped Items", "showItems")
    entToggle(resources, "🧰 Treasure Chests", "showChests")
    entToggle(resources, "🌿 Available Plants", "showPlants")

    local wildlife = MainTab:Section("🦌 Wildlife")
    entToggle(wildlife, "🐾 Animals", "showAnimals")
    entToggle(wildlife, "🐎 Horses", "showHorses")
    entToggle(wildlife, "🐟 Fish", "showFish")
    entToggle(wildlife, "🦴 Animal Remains", "showDeadAnimals")

    local world = MainTab:Section("🧭 World")
    entToggle(world, "🚂 Trains", "showTrains")
    entToggle(world, "🚩 Territories", "showTerritories")
    entToggle(world, "⚡ Thunderstruck Trees & Cacti", "showThunderstruck")

    local bankSec = MainTab:Section("🏦 Bank")
    entToggle(bankSec, "💰 Gold Bars", "highlightGoldBars")
    local goldStatusLabel = bankSec:Label("💰 Bank Gold Bars: ⏳ scanning...")
    task.spawn(function()
        local last = ""
        while not state.destroyed do
            task.wait(1)
            if state.destroyed then return end
            local exists, count = false, 0
            if ESP.getGoldBarStatus then
                local ok, e, c = pcall(ESP.getGoldBarStatus)
                if ok then exists, count = e or false, c or 0 end
            end
            local text
            if not exists then
                text = "💰 Bank Gold Bars: ❌ not found in the loaded area"
            elseif count == 0 then
                text = "💰 Bank Gold Bars: ⚠️ loaded, but no gold bars available"
            else
                text = "💰 Bank Gold Bars: ✅ " .. count .. " gold bars"
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

    bankSec:Label("Move near a vault to use its interaction.")
    bankSec:Button("🏦 Open Nearby Bank Vault", function()
        local ok, err = INV.openBankAnywhere()
        if ok then toast("Vault interaction started. Check the bank UI for confirmation.", 3)
        else toast("Bank failed: "..tostring(err), 3) end
    end)

    -- ================== VISUALS ==================
    local infoSec = VisualsTab:Section("🏷️ Labels & Tracers")
    local function dispToggle(label, key)
        uiHandles.checkboxes[key] = infoSec:Checkbox(label, function(e)
            if _loadingConfig then return end
            state[key] = e
        end, state[key])
    end
    dispToggle("🏷️ Names", "showNames")
    dispToggle("📏 Distance", "showDistance")
    dispToggle("❤️ Health", "showHealth")
    dispToggle("〰️ Tracers", "showTracers")
    local bodySec = VisualsTab:Section("✨ Body Highlights")
    bodySec:Label("Choose the body groups to emphasize. Legendary animals keep their gold highlight.")
    uiHandles.checkboxes.chamsEnabled = bodySec:Checkbox("✨ Enable Body Highlights", function(e)
        if _loadingConfig then return end
        state.chamsEnabled = e
        if e then
            if ESP.clearAllChams then ESP.clearAllChams() end
        end
    end, state.chamsEnabled)

    uiHandles.checklists.espBodyHighlight = bodySec:Checklist("🎯 Body Parts",
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

    -- ================== ANIMAL FILTER ==================
    local animalSec = VisualsTab:Section("🦌 Animal Filters")
    uiHandles.checkboxes.showLegendaryOnly = animalSec:Checkbox("⭐ Legendary Animals Only", function(enabled)
        if not _loadingConfig then state.showLegendaryOnly = enabled end
    end, state.showLegendaryOnly)
    uiHandles.checkboxes.legendaryGoldenMode = animalSec:Checkbox("✨ Gold Legendary Highlight", function(enabled)
        if not _loadingConfig then state.legendaryGoldenMode = enabled end
    end, state.legendaryGoldenMode)
    animalSec:Label("Empty selection shows all species. Legendary animals bypass this species list.")

    local animalChecklist = nil
    local function rebuildAnimalChecklist()
        local names = (ESP.collectAnimalNames and ESP.collectAnimalNames()) or {}
        if #names == 0 then names = {"(no animals found in the loaded area)"} end
        if animalChecklist then
            animalChecklist:SetOptions(names)
            animalChecklist:SetSelected(state.animalFilter or {})
            return
        end
        animalChecklist = animalSec:Checklist("🐾 Visible Species", names,
            function(list)
                if _loadingConfig then return end
                state.animalFilter = list or {}
            end, state.animalFilter or {})
        uiHandles.checklists.animalFilter = animalChecklist
    end
    rebuildAnimalChecklist()

    animalSec:Button("🔄 Refresh Animal List", function()
        rebuildAnimalChecklist()
        toast("Animal list refreshed ("..#(state.animalFilter or {}).." selected)", 2)
    end)
    animalSec:Button("✅ Select All Species", function()
        local names = (ESP.collectAnimalNames and ESP.collectAnimalNames()) or {}
        state.animalFilter = names
        if animalChecklist then
            pcall(function() animalChecklist:SetSelected(names) end)
        end
        toast("All animal species selected.", 2)
    end)
    animalSec:Button("🧹 Clear Species Filter", function()
        state.animalFilter = {}
        if animalChecklist then
            pcall(function() animalChecklist:SetSelected({}) end)
        end
        toast("Filter cleared — showing all animal species.", 2)
    end)

    task.spawn(function()
        task.wait(4)
        pcall(function()
            if not state.destroyed then rebuildAnimalChecklist() end
        end)
    end)

    local colorSec = VisualsTab:Section("🎨 Category Colors")
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

    local oreSec = VisualsTab:Section("⛏️ Ore Details")
    uiHandles.checkboxes.showOreCount = oreSec:Checkbox("🔢 Remaining Ore", function(enabled)
        if not _loadingConfig then state.showOreCount = enabled end
    end, state.showOreCount)
    uiHandles.checkboxes.showOreTier = oreSec:Checkbox("💎 Ore Tier", function(enabled)
        if not _loadingConfig then state.showOreTier = enabled end
    end, state.showOreTier)

    local perfSec = VisualsTab:Section("📐 Range & Display")
    uiHandles.sliders.maxDistance = perfSec:Slider("📏 ESP Range (0 = Unlimited)", 0, 5000, state.maxDistance,
        function(v) if _loadingConfig then return end state.maxDistance = v end, 10)
    uiHandles.sliders.updateInterval = perfSec:Slider("⏱️ Refresh Interval (seconds)", 0.05, 1, state.updateInterval,
        function(v) if _loadingConfig then return end state.updateInterval = v end, 0.05)
    uiHandles.sliders.labelSize = perfSec:Slider("🔠 Label Size", 10, 20, state.labelSize, function(v)
        if _loadingConfig then return end
        state.labelSize = v
        ESP.setLabelSize(v)
    end, 1)
    uiHandles.sliders.tracerThickness = perfSec:Slider("〰️ Tracer Width", 1, 5, state.tracerThickness,
        function(v) if _loadingConfig then return end state.tracerThickness = v end, 1)
    uiHandles.sliders.tracerTransparency = perfSec:Slider("👻 Tracer Transparency", 0, 1, state.tracerTransparency,
        function(v) if _loadingConfig then return end state.tracerTransparency = v end, 0.05)

    -- ================== COMBAT ==================
    local aimCombatSec = CombatTab:Section("🎯 Silent Aim")
    local silentAimBox = aimCombatSec:Checkbox("🎯 Enable Silent Aim", function(e)
        if _loadingConfig then return end
        state.silentAim = e
        if e and HOOKS.install then HOOKS.install() end
        ESP.updateFOV()
    end, state.silentAim)
    uiHandles.checkboxes.silentAim = silentAimBox
    pcall(function()
        aimCombatSec:Bind("⌨️ Silent Aim Key", Enum.KeyCode.J, function()
            state.silentAim = not state.silentAim
            if state.silentAim and HOOKS.install then HOOKS.install() end
            pcall(function() silentAimBox:Set(state.silentAim) end)
            ESP.updateFOV()
            toast("Silent Aim "..(state.silentAim and "ON" or "OFF"), 2)
        end)
    end)

    uiHandles.dropdowns.targetPart = aimCombatSec:Dropdown("🎯 Aim Point",
        {"Head","UpperTorso","LowerTorso","Random","Closest"},
        function(v) if _loadingConfig then return end state.targetPart = v end, state.targetPart)
    aimCombatSec:Label("Choose an aim point and enable the target groups you want below.")

    local tgtSec = CombatTab:Section("🎯 Target Groups")
    local function ctToggle(label, key)
        uiHandles.checkboxes[key] = tgtSec:Checkbox(label, function(e)
            if _loadingConfig then return end
            state[key] = e
        end, state[key])
    end
    ctToggle("👤 Target Players", "targetPlayers")
    ctToggle("🐎 Target Animals & Horses", "targetAnimals")
    ctToggle("🤖 Target NPCs & Bosses", "targetNPCs")
    tgtSec:Label("Horses and bosses are included. Your ridden mount is always excluded.")
    tgtSec:Label("Visual filters do not restrict combat targets.")

    local aimingSec = CombatTab:Section("📐 Aim & Visibility")
    uiHandles.sliders.fov = aimingSec:Slider("📐 Aim Cone (degrees)", 5, 180, state.fov, function(v)
        if _loadingConfig then return end
        state.fov = v
        ESP.updateFOV()
    end, 5)
    uiHandles.checkboxes.visibilityCheck = aimingSec:Checkbox("🧱 Require Line of Sight", function(e)
        if _loadingConfig then return end
        state.visibilityCheck = e
    end, state.visibilityCheck)
    uiHandles.checkboxes.showFOVRing = aimingSec:Checkbox("⭕ Show Aim Circle", function(e)
        if _loadingConfig then return end
        state.showFOVRing = e
        ESP.updateFOV()
    end, state.showFOVRing)

    -- ==== Movement Prediction (NEW) ====
    local predSec = CombatTab:Section("🏹 Movement Prediction")
    uiHandles.checkboxes.silentAimPrediction = predSec:Checkbox(
        "🏹 Lead Moving Targets", function(e)
            if _loadingConfig then return end
            state.silentAimPrediction = e
        end, state.silentAimPrediction)

    uiHandles.sliders.silentAimPredictionStrength = predSec:Slider(
        "📈 Lead Strength (0–2)", 0, 2, state.silentAimPredictionStrength,
        function(v)
            if _loadingConfig then return end
            state.silentAimPredictionStrength = v
        end, 0.05)

    predSec:Label("0 = no lead · 1 = standard lead · above 1 = extra lead.")

    local gunSec = CombatTab:Section("🔫 Weapon Controls")
    uiHandles.checkboxes.noRecoil = gunSec:Checkbox("🎯 No Recoil", function(e)
        if _loadingConfig then return end
        state.noRecoil = e
        if e and HOOKS.install then HOOKS.install() end
        HOOKS.applyNoRecoil(e)
    end, state.noRecoil)
    uiHandles.checkboxes.noSpread = gunSec:Checkbox("✨ No Spread", function(e)
        if _loadingConfig then return end
        state.noSpread = e
        if e and HOOKS.install then HOOKS.install() end
    end, state.noSpread)

    local ammoSec = gunSec
    uiHandles.checkboxes.infiniteAmmo = ammoSec:Checkbox("♾️ Infinite Ammo / Wand Mana", function(e)
        if _loadingConfig then return end
        state.infiniteAmmo = e
        if e then AMMO.install(); AMMO.wrapExisting()
        elseif not state.instantReload then AMMO.uninstall() end
    end, state.infiniteAmmo)
    ammoSec:Label("Wand: bypasses local mana checks. Server validation still applies.")
    uiHandles.checkboxes.instantReload = ammoSec:Checkbox("⚡ Instant Reload", function(e)
        if _loadingConfig then return end
        state.instantReload = e
        if e then AMMO.install(); AMMO.wrapExisting()
        elseif not state.infiniteAmmo then AMMO.uninstall() end
    end, state.instantReload)

    -- ================== UTILITIES ==================
    local charSec = UtilitiesTab:Section("🛡️ Stamina & Protection")
    uiHandles.checkboxes.infiniteStamina = charSec:Checkbox("⚡ Infinite Stamina", function(e)
        if _loadingConfig then return end
        state.infiniteStamina = e
        if e then CHAR.applyInfiniteStamina() else CHAR.removeInfiniteStamina() end
        CHAR.sync()
    end, state.infiniteStamina)
    uiHandles.checkboxes.antiRagdoll = charSec:Checkbox("🛡️ Prevent Ragdoll", function(e)
        if _loadingConfig then return end
        state.antiRagdoll = e
        if e then CHAR.applyAntiRagdoll(); CHAR.removeAntiFallDamage() else CHAR.removeAntiRagdoll() end
        CHAR.sync()
    end, state.antiRagdoll)
    uiHandles.checkboxes.antiFallDamage = charSec:Checkbox("🪂 Prevent Fall Damage", function(e)
        if _loadingConfig then return end
        state.antiFallDamage = e
        if e and not state.antiRagdoll then CHAR.applyAntiFallDamage() else CHAR.removeAntiFallDamage() end
        CHAR.sync()
    end, state.antiFallDamage)
    uiHandles.checkboxes.infiniteHorseStamina = charSec:Checkbox("🐎 Infinite Horse Stamina", function(e)
        if _loadingConfig then return end
        state.infiniteHorseStamina = e
        if e then CHAR.applyHorseStamina() else CHAR.removeHorseStamina() end
    end, state.infiniteHorseStamina)

    local waterSec = UtilitiesTab:Section("🌊 Water")
    uiHandles.checkboxes.walkUnderWater = waterSec:Checkbox("🚶 Walk Underwater", function(e)
        if _loadingConfig then return end
        state.walkUnderWater = e
        Water.setWalkUnderWater(e)
    end, state.walkUnderWater)
    uiHandles.checkboxes.allowGunsUnderWater = waterSec:Checkbox("🔫 Use Guns Underwater", function(e)
        if _loadingConfig then return end
        state.allowGunsUnderWater = e
        Water.setAllowGunsUnderWater(e)
    end, state.allowGunsUnderWater)

    local physSec = UtilitiesTab:Section("🏃 Movement & Physics")
    uiHandles.checkboxes.gravityEnabled = physSec:Checkbox("🌍 Custom Gravity", function(e)
        if _loadingConfig then return end
        Physics.setGravity(e, state.gravityValue)
    end, state.gravityEnabled)
    uiHandles.sliders.gravityValue = physSec:Slider("🌍 Gravity", 83, 500, state.gravityValue, function(v)
        if _loadingConfig then return end
        state.gravityValue = v
        if state.gravityEnabled then Physics.setGravity(true, v) end
    end, 1)
    uiHandles.checkboxes.hipHeightEnabled = physSec:Checkbox("↕️ Custom Hip Height", function(e)
        if _loadingConfig then return end
        Physics.setHipHeight(e, state.hipHeightValue)
    end, state.hipHeightEnabled)
    uiHandles.sliders.hipHeightValue = physSec:Slider("↕️ Hip Height", 1, 10, state.hipHeightValue, function(v)
        if _loadingConfig then return end
        state.hipHeightValue = v
        if state.hipHeightEnabled then Physics.setHipHeight(true, v) end
    end, 0.5)
    uiHandles.checkboxes.speedEnabled = physSec:Checkbox("💨 Custom Movement Speed", function(e)
        if _loadingConfig then return end
        Physics.setSpeed(e, state.speedValue)
    end, state.speedEnabled)
    uiHandles.sliders.speedValue = physSec:Slider("💨 Movement Speed", 1, 45, state.speedValue, function(v)
        if _loadingConfig then return end
        state.speedValue = v
        if state.speedEnabled then Physics.setSpeed(true, v) end
    end, 1)

    local fbSec = UtilitiesTab:Section("☀️ Full Bright")
    fbSec:Label("Set brightness to 0 to restore the game's lighting.")
    uiHandles.sliders.fullBrightLevel = fbSec:Slider("☀️ Brightness (0 = Off)", 0, 5, state.fullBrightLevel,
        function(v)
            if _loadingConfig then return end
            FB.setLevel(v)
        end, 1)

    local timeSec = UtilitiesTab:Section("🌅 World Time")
    uiHandles.checkboxes.alwaysDay = timeSec:Checkbox("🌤️ Always Daytime", function(e)
        if _loadingConfig then return end
        state.alwaysDay = e
        if FB.applyTime then FB.applyTime() end
    end, state.alwaysDay)

    -- ================== CONFIG ==================
    local profSec = ConfigTab:Section("💾 Saved Profiles")
    profSec:Label("✏️ Profile Name")
    uiHandles.textboxes.configName = profSec:Textbox("Profile name...",
        function(t, enter) if _loadingConfig then return end state.currentConfig = t end, state.currentConfig)

    local function refreshConfigDropdown()
        local files = CFG.getFiles()
        if #files == 0 then files = {"(no saved profiles)"} end
        local current = state.currentConfig
        local found = false
        for _, n in ipairs(files) do if n == current then found = true break end end
        if not found and current ~= "" and current ~= "(no saved profiles)" then
            table.insert(files, current); table.sort(files)
        end
        if uiHandles.dropdowns.configDropdown then
            uiHandles.dropdowns.configDropdown:SetOptions(files)
            uiHandles.dropdowns.configDropdown:Set(state.currentConfig)
            return
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
                pcall(function() uiHandles.checklists.animalFilter:SetSelected(state.animalFilter or {}) end)
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
    profSec:Button("🔄 Refresh Profiles", function() refreshConfigDropdown() end)
    profSec:Button("♻️ Restore Default Settings", function()
        ResetStateToDefault(); ESP.updateFOV()
        toast("All settings reset.", 2)
    end)
    profSec:Label(CFG.ready and "Preferences save on close. Active effects always load OFF." or "Profile storage is unavailable in this executor.")

    local sysSec = ConfigTab:Section("🚪 Session & Cleanup")
    sysSec:Button("🛑 Stop All Features", function()
        if stopAll then stopAll() end
        toast("All features stopped and owned changes restored.", 2)
    end)
    sysSec:Button("✖️ Unload Script", function() if destroyRuntime then destroyRuntime() end end)
    sysSec:Button("🚪 Join Another Server", function()
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


    local dbgSec = ConfigTab:Section("🔧 Diagnostics")
    uiHandles.checkboxes.debugPrints = dbgSec:Checkbox("🐞 Combat Debug Logs", function(enabled)
        if not _loadingConfig then state.debugPrints = enabled end
    end, state.debugPrints)
    uiHandles.checkboxes.suppressErrors = dbgSec:Checkbox("🔇 Hide Script Warnings", function(enabled)
        if not _loadingConfig then state.suppressErrors = enabled end
    end, state.suppressErrors)

end

-- =================================================================
--  MAIN
-- =================================================================
local function initMain()
    local controller = {}
    local renderConnection
    local function restore(fn)
        if type(fn) == "function" then
            local ok, err = pcall(fn)
            if not ok then originalWarn("[TWW] Cleanup: " .. tostring(err)) end
        end
    end
    stopAll = function()
        if state.destroyed then return end
        for _, key in ipairs({"espEnabled","silentAim","noSpread","noRecoil","infiniteAmmo","instantReload",
            "infiniteStamina","antiRagdoll","antiFallDamage","infiniteHorseStamina","alwaysDay",
            "gravityEnabled","hipHeightEnabled","speedEnabled","walkUnderWater","allowGunsUnderWater","highlightGoldBars"}) do
            state[key] = false
        end
        state.fullBrightLevel = 0
        restore(CHAR.removeInfiniteStamina)
        restore(CHAR.removeAntiRagdoll)
        restore(CHAR.removeAntiFallDamage)
        restore(CHAR.removeHorseStamina)
        restore(CHAR.unhookFireServer)
        restore(HOOKS.uninstall)
        restore(AMMO.uninstall)
        restore(FB.stop)
        restore(Physics.stop)
        restore(INV.stop)
        restore(function() Water.setWalkUnderWater(false); Water.setAllowGunsUnderWater(false) end)
        restore(ESP.cleanup)
        restore(ESP.updateFOV)
        updateUIFromState()
    end
    destroyRuntime = function()
        if state.destroyed then return end
        stopAll()
        state.destroyed = true
        state.active = false
        state.generation += 1
        if renderConnection then renderConnection:Disconnect(); renderConnection = nil end
        for _, connection in ipairs(ownedConnections) do restore(function() connection:Disconnect() end) end
        table.clear(ownedConnections)
        for _, instance in ipairs(ownedInstances) do restore(function() instance:Destroy() end) end
        table.clear(ownedInstances)
        restore(ESP.clearFOVRing)
        restore(ESP.cleanupDrawings)
        if state.window then restore(function() state.window:Kill() end) end
        if environment.TWWESP == controller then environment.TWWESP = nil end
    end
    function controller:StopAll() stopAll() end
    function controller:Stop() stopAll() end
    function controller:Destroy() destroyRuntime() end
    function controller:Start()
        if not state.destroyed and not state.active then state.active = true end
    end
    function controller:SetFeature(key, enabled)
        assert(not state.destroyed, "TWW is unloaded")
        assert(type(enabled) == "boolean" and uiHandles.checkboxes[key], "Unknown feature")
        local handle = uiHandles.checkboxes[key]
        if handle:Get() ~= enabled then handle:Toggle() end
    end
    function controller:GetStatus()
        local features = {}
        for key in pairs(uiHandles.checkboxes) do features[key] = state[key] end
        local objects, objectsByType = 0, {}
        for _, object in pairs(ESP.objects or {}) do
            objects += 1
            local kind = object.entityType or "unknown"
            objectsByType[kind] = (objectsByType[kind] or 0) + 1
        end
        return {active=state.active,destroyed=state.destroyed,features=features,objects=objects,
            objectsByType=objectsByType,event=Adapter.snapshot and Adapter.snapshot() or {},profile=state.currentConfig}
    end
    function controller:LoadProfile(name)
        local loaded = LoadStateFromConfig(name)
        if loaded then updateUIFromState() end
        return loaded
    end
    environment.TWWESP = controller
    state.active = true
    renderConnection = connect(S.RunService.RenderStepped, function()
        if not state.active then return end
        S.Camera = S.Workspace.CurrentCamera or S.Camera
        if ESP.update then ESP.update() end
        if ESP.updateFOV then ESP.updateFOV() end
    end)
    if ESP.createFOV then ESP.createFOV() end
    local function refreshCharacter()
        if ESP.cleanup then ESP.cleanup() end
        if ESP.refresh then ESP.refresh() end
        task.delay(0.5, function()
            if state.destroyed then return end
            if Water.reapply then Water.reapply() end
            if CHAR.sync then CHAR.sync() end
            if Physics.reapplyHip then Physics.reapplyHip() end
        end)
    end
    connect(S.LocalPlayer.CharacterAdded, refreshCharacter)
    local function watchPlayer(player)
        if player ~= S.LocalPlayer then
            connect(player.CharacterAdded, function()
                if ESP.refresh then ESP.refresh() end
            end)
        end
    end
    connect(S.Players.PlayerAdded, watchPlayer)
    for _, player in ipairs(S.Players:GetPlayers()) do watchPlayer(player) end
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
safeInit("Adapter", initAdapter)
safeInit("ESP", initESP)
safeInit("Char", initChar)
safeInit("Combat", initCombat)
safeInit("Hooks", initHooks)
safeInit("Ammo", initAmmo)
safeInit("Inventory", initInventory)
safeInit("WendigoAnnouncer", initWendigoAnnouncer)
_loadingConfig = true
safeInit("UI", initUI)
_loadingConfig = false
if not state.window then
    state.destroyed = true
    originalWarn("[TWW] UI initialization failed; runtime was not started.")
    return nil
end
safeInit("Main", initMain)

local loaded = LoadStateFromConfig("Default")
if loaded then state.currentConfig = "Default" end
updateUIFromState()
if HOOKS.install then HOOKS.install() end
if (state.infiniteAmmo or state.instantReload) and AMMO.install then AMMO.install() end
if FB.applyTime then FB.applyTime() end

print("[TWW] Loaded. " .. #CFG.getFiles() .. " saved profile(s).")
return environment.TWWESP
end

end)()
return run(Library, environment)
