-- Xenrax hub | LEGIONES | Lunex.lol UI
-- made by t.me/rockscript for Xenrax
local Env = getgenv()
local PreviousSettings = Env.XenraxHub and table.clone(Env.XenraxHub.Settings)
if Env.XenraxHub then Env.XenraxHub:Unload() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Me = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Hub = { Active = true, Connections = {}, Visuals = {}, Originals = {}, Controls = {} }
Env.XenraxHub = Hub
local S = {
    ESP = false, Enemies = true, Teammates = false, Boxes = true, Names = true,
    Health = true, Distance = true, Class = true, Weapon = true, Status = true, Armor = true, Chams = true, ThroughWalls = true,
    MaxDistance = 2500, TextSize = 13, FillTransparency = 75,
    EnemyColor = Color3.fromRGB(255, 80, 105), TeamColor = Color3.fromRGB(80, 180, 255),
    Silent = false, Radius = 150, Circle = true, AimPart = "Head", WallCheck = true,
    AimDistance = 2000, HitChance = 100, Prediction = 0, AutoPrediction = true,
    PingCompensation = true, PredictAcceleration = true, PredictionStrength = 100, MaxPrediction = 2500,
    CircleColor = Color3.fromRGB(170, 120, 255),
    FOVEnabled = false, FOV = 90, Speed = false, ExtraSpeed = 24,
    SpeedKey = Enum.KeyCode.V, MenuKey = Enum.KeyCode.RightShift,
    AutoReload = false, ReloadPercent = 10, AutoRestock = false, ReturnFromCache = true,
    AutoSprint = false, AutoBlock = false, BlockRange = 18, FaceBlock = true,
    AutoCloak = false, CloakDelay = 1600,
    Hitbox = false, HitboxPart = "Head", HitboxSize = 6, HitboxTransparency = 70,
    Wallbang = false, AutoExecute = false, AutoRevive = false, FinishRange = 8, FinishDelay = 750, FinishWallCheck = true,
}
if PreviousSettings then
    for key, value in pairs(PreviousSettings) do if S[key] ~= nil then S[key] = value end end
end
Hub.Settings = S
function Hub:RestoreMenuCursor()
    local saved = self.MenuCursorState
    if not saved then return end
    self.MenuCursorState = nil
    Input.MouseBehavior = saved.Behavior
    Input.MouseIconEnabled = saved.IconEnabled
end
function Hub:UpdateMenuCursor()
    local main = self.Window and self.Window.MainFrame
    if self.Active and main and main.Visible and self.UI and self.UI.Enabled then
        if not self.MenuCursorState then
            self.MenuCursorState = { Behavior = Input.MouseBehavior, IconEnabled = Input.MouseIconEnabled }
        end
        Input.MouseBehavior = Enum.MouseBehavior.Default
        Input.MouseIconEnabled = true
    else
        self:RestoreMenuCursor()
    end
end
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(Hub.Connections, c)
    return c
end
local function create(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local Parent = gethui and gethui() or Me:WaitForChild("PlayerGui")
local Overlay = create("ScreenGui", {
    Name = "XenraxOverlay", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, Parent)
Hub.Overlay = Overlay
local Ring = create("Frame", {
    Name = "AimFOV", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5), Visible = false,
}, Overlay)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, Ring)
local RingStroke = create("UIStroke", { Thickness = 1.5, Color = S.CircleColor }, Ring)
local Highlights = create("Folder", { Name = "XenraxHighlights" }, workspace)
Hub.Highlights = Highlights

local function friendly(player)
    return Me.Team ~= nil and player.Team == Me.Team and not Me.Neutral and not player.Neutral
end
local function character(player)
    local char = player.Character
    if not char or not char:IsDescendantOf(workspace) then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if hum and hum.Health > 0 and root then return char, hum, root end
end

function Hub:SetRootCFrame(root, value)
    root.CFrame = value
end

-- Use the game's registered input actions and ranged-weapon state.
local Modules = ReplicatedStorage:WaitForChild("Modules")
local function module(path)
    local obj = Modules
    for name in string.gmatch(path, "[^/]+") do obj = obj:FindFirstChild(name); if not obj then return end end
    local ok, result = pcall(require, obj)
    if ok then return result end
end
local GameInput = module("Client/Managers/InputManager")
local Ranged = module("Classes/RangedClass")
local Cloak = module("Client/Movesets/Marksman/Cloak")
local SharedRanged = module("Client/Effects/Ranged")
local ProjectileManager = module("Client/Managers/ProjectileManager")
local SharedUtils = module("Shared/Utils")
local Interaction = module("Client/Controllers/InteractionController")
local SkillNetwork = module("Client/Networking/SkillNetwork")
local CombatState = module("Shared/Combat/CombatState")
local CombatController
do
    local router = Me:WaitForChild("PlayerScripts"):FindFirstChild("InputRouter")
    local controller = router and router:FindFirstChild("CombatController")
    if controller then local success, result = pcall(require, controller); if success then CombatController = result end end
end
local Registry
if Ranged and debug.getupvalue then
    local ok, result = pcall(debug.getupvalue, Ranged.NeedsAmmoCache, 1)
    if ok and type(result) == "table" then Registry = result end
end
Hub.Capabilities = { Input = GameInput ~= nil, Ranged = Registry ~= nil, Cloak = Cloak ~= nil }
Hub.HitboxOriginals = {}
Hub.HitboxVisuals = {}
Hub.HeldActions = {}
Hub.BlockState = { Held = false, Manual = false, PauseUntil = 0, ReleasedAt = 0 }
function Hub:ObserveManualBlock(down)
    local state = self.BlockState
    state.Held = false
    state.Manual = down == true
    state.PauseUntil = os.clock() + (down and 0 or 0.8)
    state.WaitForClear = not down
end
function Hub:SetAutoBlock(down)
    local state, now = self.BlockState, os.clock()
    local char = Me.Character
    if down and (state.Manual or now < state.PauseUntil or now - state.ReleasedAt < 0.18) then down = false end
    if down and state.Held and now - state.StartedAt >= 0.65 then down = false end
    if state.Held == down then return end
    state.Held = down
    if down then state.StartedAt, state.Character = now, char else state.ReleasedAt = now end
    if not CombatController or not char or not char.Parent then return end
    self.AutoBlockDispatch = true
    local success, reason = pcall(CombatController.Block, down)
    self.AutoBlockDispatch = false
    if not success then state.Held = false; warn("Xenrax block:", reason) end
end
if CombatController and hookfunction and not Env.XenraxBlockHookV2 then
    local original
    original = hookfunction(CombatController.Block, function(down, ...)
        local current = Env.XenraxHub
        if current and current.Active and current.ObserveManualBlock and not current.AutoBlockDispatch then
            current:ObserveManualBlock(down)
        end
        return original(down, ...)
    end)
    Env.XenraxBlockHookV2 = true
end
local function action(name, down)
    if name == "Block" then Hub:SetAutoBlock(down == true); return end
    if not GameInput then return end
    local source = "Xenrax:" .. name
    if down then
        if not Hub.HeldActions[name] or not GameInput:IsActionDown(name) then
            Hub.HeldActions[name] = GameInput:BeginAction(name, source) == true
        end
    elseif Hub.HeldActions[name] then
        GameInput:EndAction(name, source)
        Hub.HeldActions[name] = nil
    end
end
local function gunState(char)
    local tool = char and char:FindFirstChildOfClass("Tool")
    local gun = Registry and tool and Registry[tool]
    if gun and not gun._Destroyed then return gun end
end
local function restoreHitboxes()
    for part, props in pairs(Hub.HitboxOriginals) do
        if part.Parent then pcall(function() for key, value in pairs(props) do part[key] = value end end) end
    end
    table.clear(Hub.HitboxOriginals)
    for _, visual in pairs(Hub.HitboxVisuals) do visual:Destroy() end
    table.clear(Hub.HitboxVisuals)
end
local function updateHitboxes()
    local wanted = {}
    if S.Hitbox then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= Me and not friendly(player) then
                local char = character(player)
                local part = char and char:FindFirstChild(S.HitboxPart)
                if part and part:IsA("BasePart") then
                    wanted[part] = true
                    local visual = Hub.HitboxVisuals[part]
                    if not visual then
                        visual = create("BoxHandleAdornment", { Name = "XenraxHitbox", Adornee = part,
                            AlwaysOnTop = false, ZIndex = 1, Color3 = S.EnemyColor }, Highlights)
                        Hub.HitboxVisuals[part] = visual
                    end
                    visual.Size = Vector3.one * S.HitboxSize
                    visual.Transparency = S.HitboxTransparency / 100
                    visual.Color3 = S.EnemyColor
                end
            end
        end
    end
    for part, visual in pairs(Hub.HitboxVisuals) do
        if not wanted[part] then
            visual:Destroy()
            Hub.HitboxVisuals[part] = nil
        end
    end
end

local AttackAnimations = {}
local function registerAnimation(anim)
    if not anim:IsA("Animation") then return end
    local name = string.lower(anim.Name)
    if name:match("^m1") or name:match("^attack%d*$") or name:match("^swing") or name == "heavy" or name == "critical" then
        local id = anim.AnimationId:match("%d+")
        if id then AttackAnimations[id] = true end
    end
end
local resources = ReplicatedStorage:FindFirstChild("Resources")
if resources then
    for _, obj in ipairs(resources:GetDescendants()) do registerAnimation(obj) end
    connect(resources.DescendantAdded, registerAnimation)
end
local function incomingAttack(root)
    local closest, best = nil, S.BlockRange
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Me and not friendly(player) then
            local char, hum, enemyRoot = character(player)
            if char and not char:GetAttribute("Downed") and not char:GetAttribute("Ragdoll") then
                local delta = root.Position - enemyRoot.Position
                local distance = delta.Magnitude
                if distance < best and distance > 0.01 and math.abs(delta.Y) < 9 and enemyRoot.CFrame.LookVector:Dot(delta.Unit) > -0.2 then
                    local animator = hum:FindFirstChildOfClass("Animator")
                    local attacking = char:GetAttribute("Attacking") == true
                    if animator then
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                            local anim = track.Animation
                            local progressing = not track.Looped and track.Speed > 0 and (track.Length <= 0 or track.TimePosition < track.Length * 0.85)
                            if anim and progressing and track.IsPlaying and track.WeightCurrent > 0.02 and AttackAnimations[anim.AnimationId:match("%d+")] then attacking = true; break end
                        end
                    end
                    if attacking then
                        local params = RaycastParams.new()
                        params.FilterDescendantsInstances = { Me.Character, Highlights }
                        local hit = workspace:Raycast(root.Position, enemyRoot.Position - root.Position, params)
                        if not hit or hit.Instance:IsDescendantOf(char) then closest, best = enemyRoot, distance end
                    end
                end
            end
        end
    end
    return closest
end

local function pointPart(obj)
    if obj:IsA("BasePart") then return obj end
    return obj:FindFirstChild("Hitbox", true) or (obj:IsA("Model") and obj.PrimaryPart) or obj:FindFirstChildWhichIsA("BasePart", true)
end
function Hub:GetPoints()
    local result = {}
    local world = workspace:FindFirstChild("World")
    local effects = world and world:FindFirstChild("Effects")
    local points = effects and effects:FindFirstChild("Points")
    local mode = workspace:GetAttribute("GameMode")
    local folder = points and (points:FindFirstChild(tostring(mode)) or (mode == "HardPoint" and points:FindFirstChild("Hardpoint")))
    if folder then
        for _, obj in ipairs(folder:GetChildren()) do
            local part = pointPart(obj)
            if part and not obj:GetAttribute("IsSpawn") then result[obj.Name] = part end
        end
    end
    for _, tag in ipairs({ "ShipAssaultShipPoint", "ShipAssaultReactor" }) do
        for _, obj in ipairs(CollectionService:GetTagged(tag)) do
            if obj:IsDescendantOf(workspace) and not obj:GetAttribute("IsSpawn") then
                local part = pointPart(obj)
                if part then result[obj.Name .. " [" .. tag .. "]"] = part end
            end
        end
    end
    return result
end
local function landing(part, root)
    local position = part.Position
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { Me.Character, part.Parent, Highlights }
    local hit = workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -120, 0), params)
    local y = hit and hit.Position.Y + root.Size.Y / 2 + 3 or position.Y + 4
    return CFrame.new(position.X, y, position.Z) * root.CFrame.Rotation
end
function Hub:TeleportPoint(name)
    if self.Restocking then return false, "Restocking in progress" end
    local _, _, root = character(Me)
    if not root then return false, "Spawn your character first" end
    local part = self:GetPoints()[name]
    if not part or not part.Parent then return false, "Point unavailable; refresh the list" end
    self.LastTeleport = root.CFrame
    self:SetRootCFrame(root, landing(part, root))
    root.AssemblyLinearVelocity = Vector3.zero
    return true
end
local function nearestCache(root)
    local best, distance
    for _, obj in ipairs(CollectionService:GetTagged("AmmoCache")) do
        if obj:IsDescendantOf(workspace) then
            local prompt = obj:FindFirstChild("RefillPrompt", true)
            if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled then
                local parent = prompt.Parent
                local part = parent:IsA("BasePart") and parent or parent:IsA("Attachment") and parent.Parent
                if part and part:IsA("BasePart") then
                    local d = (part.Position - root.Position).Magnitude
                    if not distance or d < distance then best, distance = { Prompt = prompt, Part = part }, d end
                end
            end
        end
    end
    return best
end
function Hub:Restock()
    if self.Restocking or not self.Active then return false, "Already restocking" end
    local char, _, root = character(Me)
    if not root then return false, "Spawn your character first" end
    local cache = nearestCache(root)
    if not cache then return false, "No loaded ammo cache found" end
    self.Restocking = true
    local previous = root.CFrame
    self.RestockReturn = { Character = char, Root = root, CFrame = previous }
    local gun = gunState(char)
    local oldAmmo = gun and gun.Ammo
    task.spawn(function()
        local ok, err = xpcall(function()
            action("Sprint", false); action("Block", false)
            self:SetRootCFrame(root, CFrame.new(cache.Part.Position + Vector3.new(0, 3, 3)) * root.CFrame.Rotation)
            root.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.4)
            if not self.Active or Me.Character ~= char or not cache.Prompt.Parent then return end
            if fireproximityprompt then
                fireproximityprompt(cache.Prompt, cache.Prompt.HoldDuration)
            else
                cache.Prompt:InputHoldBegin()
                task.wait(cache.Prompt.HoldDuration + 0.1)
                if cache.Prompt.Parent then cache.Prompt:InputHoldEnd() end
            end
            local deadline = os.clock() + math.max(5, cache.Prompt.HoldDuration + 2)
            repeat
                task.wait(0.15)
                if not self.Active or Me.Character ~= char then break end
                if gun and not gun._Destroyed and gun.Ammo > (oldAmmo or 0) then break end
            until os.clock() >= deadline
        end, debug.traceback)
        -- Never move a newly spawned character back to the previous life.
        if self.Active and S.ReturnFromCache and Me.Character == char and root.Parent then
            self:SetRootCFrame(root, previous); root.AssemblyLinearVelocity = Vector3.zero
        end
        self.Restocking = false
        self.RestockReturn = nil
        self.NextRestock = os.clock() + 8
        if not ok then warn("Xenrax restock:", err) end
    end)
    return true
end

if Ranged and hookfunction and not Env.XenraxFireHook then
    local original
    original = hookfunction(Ranged.Fire, function(gun, ...)
        local current = Env.XenraxHub
        local char = gun.Character
        local cloaked = current and current.Active and current.Settings.AutoCloak and char
            and (char:GetAttribute("Class") == "Marksman" or char:GetAttribute("BaseClass") == "Marksman")
            and char:GetAttribute("Cloaked") == true
        local ammo = gun.Ammo
        local result = table.pack(original(gun, ...))
        if cloaked and type(ammo) == "number" and gun.Ammo < ammo and current.Active then
            current.PendingCloak = { Character = char, ReadyAt = os.clock() + current.Settings.CloakDelay / 1000, ExpiresAt = os.clock() + 12 }
        end
        return table.unpack(result, 1, result.n)
    end)
    Env.XenraxFireHook = true
end
Hub.Capabilities.ShotObserver = Env.XenraxFireHook == true
local function visibleFrom(origin, char, pos)
    local params = RaycastParams.new()
    params.IgnoreWater = true
    local world = workspace:FindFirstChild("World")
    local hit
    if world and SharedUtils and SharedUtils.General then
        local include = { workspace.Terrain }
        for _, name in ipairs({ "Map", "Living", "Gameplay" }) do
            local obj = world:FindFirstChild(name)
            if obj then table.insert(include, obj) end
        end
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = include
        hit = SharedUtils.General.RaycastIgnoringCharacter(origin, pos - origin, params, Me.Character)
    else
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignore = { Highlights }
        if workspace.CurrentCamera then table.insert(ignore, workspace.CurrentCamera) end
        if Me.Character then table.insert(ignore, Me.Character) end
        if world and world:FindFirstChild("Effects") then table.insert(ignore, world.Effects) end
        params.FilterDescendantsInstances = ignore
        hit = workspace:Raycast(origin, pos - origin, params)
    end
    return not hit or hit.Instance:IsDescendantOf(char)
end
local function visible(cam, char, pos) return visibleFrom(cam.CFrame.Position, char, pos) end
Hub.MotionSamples = {}
Hub.PredictionPing = 0
local function finiteVector(value)
    return value.X == value.X and value.Y == value.Y and value.Z == value.Z
        and math.abs(value.X) < 1e6 and math.abs(value.Y) < 1e6 and math.abs(value.Z) < 1e6
end
local function limitVector(value, maximum)
    if not finiteVector(value) then return Vector3.zero end
    return value.Magnitude > maximum and value.Unit * maximum or value
end
function Hub:SampleTargetMotion(now)
    local alive = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player == Me then continue end
        local char, _, root = character(player)
        if not root then continue end
        alive[root] = true
        local state = self.MotionSamples[root]
        local position, raw = root.Position, limitVector(root.AssemblyLinearVelocity, 180)
        local dt = state and now - state.Time or 0
        -- Reset after a respawn, a stalled sample stream, or a teleport/correction.
        if not state or dt > 0.4 or (position - state.Position).Magnitude > math.max(18, dt * 220) then
            self.MotionSamples[root] = { Time = now, Position = position, Velocity = raw, Acceleration = Vector3.zero,
                History = { { Time = now, Position = position } } }
            continue
        end
        if dt < 0.015 then continue end
        local history = state.History
        table.insert(history, { Time = now, Position = position })
        while #history > 2 and history[2].Time < now - 0.12 do table.remove(history, 1) end
        local oldest = history[1]
        local observed = limitVector((position - oldest.Position) / math.max(0.015, now - oldest.Time), 180)
        -- Replicated roots may move through CFrame while reporting zero physics velocity.
        local measured = raw.Magnitude > 0.75 and raw * 0.8 + observed * 0.2 or observed
        local turning = measured:Dot(state.Velocity) < 0
        local alpha = 1 - math.exp(-dt * (turning and 35 or 22))
        local velocity = state.Velocity:Lerp(measured, alpha)
        if measured.Magnitude < 0.5 and observed.Magnitude < 0.5 then velocity = Vector3.zero end
        local acceleration = limitVector((velocity - state.Velocity) / dt, 160)
        state.Acceleration = turning and Vector3.zero or state.Acceleration:Lerp(acceleration, 1 - math.exp(-dt * 10))
        state.Velocity, state.Position, state.Time = velocity, position, now
    end
    for root in pairs(self.MotionSamples) do if not alive[root] then self.MotionSamples[root] = nil end end
end
function Hub:GetTargetMotion(part)
    local model = part:FindFirstAncestorOfClass("Model")
    local root = model and model:FindFirstChild("HumanoidRootPart") or part.AssemblyRootPart or part
    local state = self.MotionSamples[root]
    if state and os.clock() - state.Time <= 0.3 then return state.Velocity, state.Acceleration end
    return limitVector(root.AssemblyLinearVelocity, 180), Vector3.zero
end
local sampleClock, pingClock = 0, 0
connect(RunService.Heartbeat, function(dt)
    sampleClock, pingClock = sampleClock + dt, pingClock + dt
    if sampleClock >= 0.035 then
        sampleClock = 0
        if S.AutoPrediction and (S.Silent or S.Hitbox) then Hub:SampleTargetMotion(os.clock())
        elseif next(Hub.MotionSamples) then table.clear(Hub.MotionSamples) end
    end
    if pingClock >= 0.5 then
        pingClock = 0
        local success, ping = pcall(Me.GetNetworkPing, Me)
        if success and type(ping) == "number" and ping == ping then
            -- Follow the game's own half-ping convention, with a bounded estimate.
            local estimate = math.clamp(ping * 0.5, 0, 0.15)
            Hub.PredictionPing = Hub.PredictionPing * 0.65 + estimate * 0.35
        end
    end
end)
local BallisticsCache = {}
local function ballistics(gunType)
    if BallisticsCache[gunType] then return BallisticsCache[gunType] end
    local definition = module("Client/Managers/ProjectileManager/Simulation/" .. gunType)
    local info = {
        Speed = definition and tonumber(definition.Velocity) or 1500,
        Gravity = definition and tonumber(definition.Gravity) or 0,
        Lifetime = definition and tonumber(definition.Lifetime) or 3,
    }
    BallisticsCache[gunType] = info
    return info
end
local function intercept(origin, part, info)
    local pos = part.Position
    local velocity, acceleration = Hub:GetTargetMotion(part)
    if not S.AutoPrediction then return pos + velocity * (S.Prediction / 1000) end
    if not info.Speed or info.Speed <= 0 then return pos end
    local strength = S.PredictionStrength / 100
    velocity = velocity * strength
    acceleration = S.PredictAcceleration and acceleration * strength or Vector3.zero
    local delay = S.Prediction / 1000 + (S.PingCompensation and Hub.PredictionPing or 0)
    local offset = pos + velocity * delay - origin
    local a, b, c = velocity:Dot(velocity) - info.Speed * info.Speed, 2 * offset:Dot(velocity), offset:Dot(offset)
    local time
    if math.abs(a) < 0.0001 then
        if math.abs(b) > 0.0001 then time = -c / b end
    else
        local discriminant = b * b - 4 * a * c
        if discriminant < 0 then return end
        local sqrt = math.sqrt(discriminant)
        local first, second = (-b - sqrt) / (2 * a), (-b + sqrt) / (2 * a)
        if first > 0 and second > 0 then time = math.min(first, second) else time = math.max(first, second) end
    end
    if not time or time < 0 then return end
    local maximum = math.min(info.Lifetime, S.MaxPrediction / 1000)
    local point
    for _ = 1, 6 do
        if time > maximum then return end
        -- Acceleration is reliable only over a short horizon; do not extrapolate a strafe for seconds.
        local horizon = math.min(time + delay, 0.25)
        point = pos + velocity * (time + delay) + acceleration * (0.5 * horizon * horizon)
            - Vector3.new(0, 0.5 * info.Gravity * time * time, 0)
        local nextTime = (point - origin).Magnitude / info.Speed
        if math.abs(nextTime - time) < 0.00001 then break end
        time = nextTime
    end
    if time > maximum or not finiteVector(point) then return end
    return point
end

local BeginInteraction, RefreshInteractions, CancelInteraction, InteractionRows
if Interaction and debug.getupvalues and debug.getupvalue then
    local success, values = pcall(debug.getupvalues, Interaction.Drop)
    if success then
        for _, value in pairs(values) do
            if type(value) == "function" then
                local name = debug.info(value, "n")
                if name == "Begin" then BeginInteraction = value elseif name == "Refresh" then RefreshInteractions = value end
            end
        end
        local rowsOK, rows = pcall(debug.getupvalue, Interaction.Drop, 3)
        if rowsOK and type(rows) == "table" then InteractionRows = rows end
    end
    local cancelOK, cancelValues = pcall(debug.getupvalues, Interaction.Initialize)
    if cancelOK then
        for _, value in pairs(cancelValues) do
            if type(value) == "function" and debug.info(value, "n") == "Cancel" then CancelInteraction = value; break end
        end
    end
end
Hub.Capabilities.AutoInteract = GameInput ~= nil and BeginInteraction ~= nil and RefreshInteractions ~= nil and InteractionRows ~= nil and CancelInteraction ~= nil
Hub.InteractionCooldowns = setmetatable({}, { __mode = "k" })
Hub.InteractionDisconnects = {}
function Hub:SetInteractionStatus(text, force)
    if not force and os.clock() < (self.StatusHoldUntil or 0) then return end
    self.InteractionStatus = text
end
function Hub:GetInteractionSession()
    if not BeginInteraction then return end
    local success, session = pcall(debug.getupvalue, BeginInteraction, 1)
    if success then return session end
end
function Hub:IsAutoInteracting()
    local owned = self.AutoInteraction
    if not owned then return false end
    if self:GetInteractionSession() == owned.Session then return true end
    self.AutoInteraction = nil
    return false
end
function Hub:CancelAutoInteraction(kind)
    local owned = self.AutoInteraction
    if not owned or (kind and owned.Action ~= kind) then return end
    if self:GetInteractionSession() == owned.Session and CancelInteraction then CancelInteraction() end
    self.AutoInteraction = nil
end
function Hub:GetAutoInteractionRows()
    local rows = {}
    -- Revive keeps the native progress row. Execute is a tap interaction and needs no progress widget.
    if S.AutoRevive then
        for _, row in pairs(InteractionRows or {}) do
            if row.Action == "Revive" then table.insert(rows, row) end
        end
    end
    if S.AutoExecute then
        for _, player in ipairs(Players:GetPlayers()) do
            local target = player.Character
            if player ~= Me and not friendly(player) and target and target:IsDescendantOf(workspace)
                and target:GetAttribute("Downed") and target:GetAttribute("Interaction.Execute") then
                table.insert(rows, { Action = "Execute", Target = target })
            end
        end
    end
    return rows
end
function Hub:GetAutoInteractionCandidate(rows, own, root)
    local selected, best = nil, math.min(S.FinishRange, 10)
    local nearest, blockedByWall, coolingDown
    for _, row in pairs(rows) do
        local target = row.Target
        if not target or not target.Parent or target == own or not target:GetAttribute("Downed") then continue end
        local blocked = false
        for _, attr in ipairs({ "Dead", "Executed", "Executing", "Carried", "BeingRevived" }) do
            if target:GetAttribute(attr) then blocked = true; break end
        end
        if blocked then continue end
        local targetPlayer = Players:GetPlayerFromCharacter(target)
        local team
        if targetPlayer then team = friendly(targetPlayer)
        else team = own:GetAttribute("Side") ~= nil and own:GetAttribute("Side") == target:GetAttribute("Side") end
        local medic = own:GetAttribute("Class") == "Medic" or own:GetAttribute("BaseClass") == "Medic"
        local allowed = row.Action == "Execute" and S.AutoExecute and not team and target:GetAttribute("Interaction.Execute")
            or row.Action == "Revive" and S.AutoRevive and team and medic and target:GetAttribute("Interaction.Revive")
        local targetRoot = target:FindFirstChild("HumanoidRootPart")
        if not allowed or not targetRoot then continue end
        local distance = (root.Position - targetRoot.Position).Magnitude
        nearest = math.min(nearest or math.huge, distance)
        if distance <= best then
            if os.clock() < (self.InteractionCooldowns[target] or 0) then coolingDown = true
            elseif S.FinishWallCheck and not visibleFrom(root.Position, target, targetRoot.Position) then blockedByWall = true
            else selected, best = row, distance end
        end
    end
    self.NearestFinishDistance = nearest
    if not selected then
        if blockedByWall then self:SetInteractionStatus("Waiting: target behind an obstacle")
        elseif coolingDown then self:SetInteractionStatus("Waiting: target retry cooldown")
        elseif nearest then self:SetInteractionStatus(string.format("Nearest target: %.1f / %d studs", nearest, S.FinishRange))
        else self:SetInteractionStatus("Waiting for a downed enemy nearby") end
    end
    return selected
end
function Hub:UpdateAutoInteract()
    if not self.Capabilities.AutoInteract then self:SetInteractionStatus("Native interaction API unavailable"); return end
    if self:IsAutoInteracting() then
        local enabled = self.AutoInteraction.Action == "Execute" and S.AutoExecute or self.AutoInteraction.Action == "Revive" and S.AutoRevive
        if not enabled then self:CancelAutoInteraction() end
        if enabled then
            local session = self.AutoInteraction.Session
            self:SetInteractionStatus(self.AutoInteraction.Action .. ": " .. tostring(session.Phase) .. " (" .. self.AutoInteraction.Target.Name .. ")")
        end
        return
    end
    if not (S.AutoExecute or S.AutoRevive) then self:SetInteractionStatus("Auto interactions disabled"); return end
    if self:GetInteractionSession() then self:SetInteractionStatus("Waiting: another interaction is active"); return end
    if os.clock() < (self.NextAutoInteraction or 0) then return end
    local own, _, root = character(Me)
    if not root then self:SetInteractionStatus("Waiting for character"); return end
    if self.Restocking or Input:GetFocusedTextBox() or not GameInput:IsGameplayInputEnabled() then
        self:SetInteractionStatus("Waiting: gameplay input unavailable"); return
    end
    for _, attr in ipairs({ "Downed", "Dead", "Stunned", "SoftStunned", "Attacking", "Blocking", "Parrying", "Parried",
        "MovementLocked", "Ragdoll", "Executing", "Executed", "Carried", "Reviving", "BeingRevived" }) do
        local value = CombatState and CombatState.GetValue(own, attr) or own:GetAttribute(attr)
        if value then
            if (attr == "Blocking" or attr == "Parrying") and self.BlockState.Held then
                self:SetAutoBlock(false)
                self.BlockState.PauseUntil = os.clock() + 0.4
            end
            self:SetInteractionStatus("Waiting: " .. attr)
            return
        end
    end
    if S.AutoRevive then RefreshInteractions() end
    local row = self:GetAutoInteractionCandidate(self:GetAutoInteractionRows(), own, root)
    if not row then return end
    self.NextAutoInteraction = os.clock() + S.FinishDelay / 1000
    self.InteractionCooldowns[row.Target] = os.clock() + 2
    action("Sprint", false)
    self:SetAutoBlock(false)
    -- The native controller owns request/session IDs, progress and server acknowledgements.
    BeginInteraction(row, nil, row.Action == "Execute")
    local session = self:GetInteractionSession()
    if session and session.Row == row then
        self.AutoInteraction = { Session = session, Action = row.Action, Target = row.Target, StartedAt = os.clock() }
        self.LastAutoInteraction = row.Action .. ": " .. row.Target.Name
        self:SetInteractionStatus("Requesting " .. row.Action .. ": " .. row.Target.Name)
    else
        self:SetInteractionStatus("Native controller did not start interaction")
    end
end
if SkillNetwork then
    for _, eventName in ipairs({ "Accepted", "Rejected", "Ended" }) do
        local event = eventName
        local disconnect = SkillNetwork.On("Interaction", event, function(data)
            local owned = Hub.AutoInteraction
            if not Hub.Active or not owned or type(data) ~= "table" or data.RequestId ~= owned.Session.RequestId then return end
            local reason = tostring(data.Reason or data.Message or data.Error or data.Code or event)
            Hub.LastInteractionReply = { Event = event, Reason = reason, Target = owned.Target.Name }
            if event ~= "Accepted" then
                Hub.LastInteractionResult = owned.Action .. ": " .. reason
                Hub:SetInteractionStatus(Hub.LastInteractionResult, true)
                Hub.StatusHoldUntil = os.clock() + 2
                if event == "Rejected" then Hub.InteractionCooldowns[owned.Target] = os.clock() + 1 end
            end
        end)
        if type(disconnect) == "function" then table.insert(Hub.InteractionDisconnects, disconnect) end
    end
end
local function rayBoxDistance(origin, direction, part, size, maximum)
    local p = part.CFrame:PointToObjectSpace(origin)
    local d = part.CFrame:VectorToObjectSpace(direction)
    local half, near, far = size / 2, 0, maximum
    for _, axis in ipairs({ "X", "Y", "Z" }) do
        if math.abs(d[axis]) < 0.00001 then
            if math.abs(p[axis]) > half[axis] then return end
        else
            local a, b = (-half[axis] - p[axis]) / d[axis], (half[axis] - p[axis]) / d[axis]
            if a > b then a, b = b, a end
            near, far = math.max(near, a), math.min(far, b)
            if near > far then return end
        end
    end
    if far > 0 then return near end
end
function Hub:ResolveShotDirection(origin, direction, gunType)
    if not self.Active or not (S.Silent or S.Hitbox) or direction.Magnitude < 0.001 then return end
    local cam = workspace.CurrentCamera
    local own = character(Me)
    if not cam or not own or not own:FindFirstChildOfClass("Tool") then return end
    local useSilent = S.Silent and math.random(1, 100) <= S.HitChance
    local info = ballistics(gunType or "Breacher")
    local center = cam.ViewportSize / 2
    local best, bestBox, point, selected = S.Radius, S.AimDistance, nil, nil
    local fallback, fallbackPart
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= Me and not friendly(player) and (not player.Team or player.Team.Name ~= "Spectator") then
            local char = character(player)
            if not char or char:FindFirstChildOfClass("ForceField") or char:GetAttribute("Downed") then continue end
            if useSilent then
                local part = char:FindFirstChild(S.AimPart) or char:FindFirstChild("HumanoidRootPart")
                if part and part:IsA("BasePart") then
                    local screen, onScreen = cam:WorldToViewportPoint(part.Position)
                    local distance = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                    if onScreen and distance < best and (part.Position - origin).Magnitude <= S.AimDistance then
                        local predicted = intercept(origin, part, info)
                        if predicted and (S.Wallbang or not S.WallCheck or (visible(cam, char, part.Position) and visibleFrom(origin, char, predicted))) then
                            best, point, selected = distance, predicted, part
                        end
                    end
                end
            end
            if S.Hitbox then
                local part = char:FindFirstChild(S.HitboxPart)
                if part and part:IsA("BasePart") then
                    local distance = rayBoxDistance(origin, direction.Unit, part, Vector3.one * S.HitboxSize, S.AimDistance)
                    if distance and distance < bestBox then
                        local predicted = intercept(origin, part, info)
                        if predicted and (S.Wallbang or visibleFrom(origin, char, predicted)) then
                            bestBox, fallback, fallbackPart = distance, predicted, part
                        end
                    end
                end
            end
        end
    end
    point, selected = point or fallback, selected or fallbackPart
    if point and (point - origin).Magnitude > 0.001 then return (point - origin).Unit, selected end
end
-- Older injected versions may still have a muzzle hook; it must not redirect twice.
function Hub:GetAimPoint() return nil end
local function installSilent()
    if Env.XenraxProjectileHookV2 then return true end
    if not (SharedRanged and hookfunction) then return false end
    local original
    original = hookfunction(SharedRanged.Shoot, function(data, replicated, ...)
        local current = Env.XenraxHub
        local char = Me.Character
        local localShot = type(data) == "table" and (data.Player == Me or data.Player == char
            or (char and data.FirePoint and data.FirePoint:IsDescendantOf(char)))
        if current and current.Active and not replicated and localShot
            and typeof(data.InitialPosition) == "Vector3" and typeof(data.Direction) == "Vector3" then
            local success, direction, part = pcall(current.ResolveShotDirection, current, data.InitialPosition, data.Direction, data.GunType)
            if success and direction then
                data = table.clone(data)
                data.Direction = direction
                current.LastShot = { GunType = data.GunType, Target = part, Origin = data.InitialPosition, Direction = direction }
            elseif not success then
                current.LastShotError = direction
            end
        end
        -- One direction feeds both server registration and local projectile simulation.
        return original(data, replicated, ...)
    end)
    Env.XenraxProjectileHookV2 = true
    return true
end
Hub.SilentReady = installSilent()

function Hub:GetWallbangOptions(player, gunType, options)
    if not self.Active or not S.Wallbang or gunType == "Grenade" then return end
    local own = player == Me or (Me.Character ~= nil and player == Me.Character)
    if not own or (options and options.SuppressCallbacks) then return end
    local world = workspace:FindFirstChild("World")
    local living = world and world:FindFirstChild("Living")
    if not living then return end
    local filter = RaycastParams.new()
    filter.FilterType = Enum.RaycastFilterType.Include
    filter.FilterDescendantsInstances = { living }
    filter.IgnoreWater = true
    local result = table.clone(options or {})
    result.RaycastFilter = filter
    return result
end
if ProjectileManager and hookfunction and not Env.XenraxWallbangHookV1 then
    for _, name in ipairs({ "Cast", "CastBatch" }) do
        local original
        original = hookfunction(ProjectileManager[name], function(player, gunType, origin, direction, time, visual, options, filter, castId)
            local current = Env.XenraxHub
            if current and current.Active and current.GetWallbangOptions then
                local replacement = current:GetWallbangOptions(player, gunType, options)
                if replacement then options, filter = replacement, replacement.RaycastFilter end
            end
            return original(player, gunType, origin, direction, time, visual, options, filter, castId)
        end)
    end
    Env.XenraxWallbangHookV1 = true
end
Hub.Capabilities.Wallbang = Env.XenraxWallbangHookV1 == true

local function addVisual(player)
    if player == Me or Hub.Visuals[player] then return end
    local box = create("Frame", { BackgroundTransparency = 1, Visible = false }, Overlay)
    local stroke = create("UIStroke", { Thickness = 1.5 }, box)
    local label = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, 200, 0, 90),
        Position = UDim2.new(0.5, 0, 0, -92), AnchorPoint = Vector2.new(0.5, 0),
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
        TextStrokeTransparency = 0.25, TextYAlignment = Enum.TextYAlignment.Bottom,
    }, box)
    local healthBG = create("Frame", {
        BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        Size = UDim2.new(0, 4, 1, 2), Position = UDim2.fromOffset(-7, -1),
    }, box)
    local health = create("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1) }, healthBG)
    local armorBG = create("Frame", {
        Name = "ArmorBar", BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        Size = UDim2.new(0, 4, 1, 2), Position = UDim2.new(1, 3, 0, -1), Visible = false,
    }, box)
    local armor = create("Frame", {
        BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
        BackgroundColor3 = Color3.fromRGB(70, 165, 255), Size = UDim2.fromScale(1, 0),
    }, armorBG)
    local highlight = create("Highlight", { Enabled = false }, Highlights)
    Hub.Visuals[player] = { Box = box, Stroke = stroke, Label = label, HealthBG = healthBG, Health = health,
        ArmorBG = armorBG, Armor = armor, Highlight = highlight }
end
local function removeVisual(player)
    local v = Hub.Visuals[player]
    if v then v.Box:Destroy(); v.Highlight:Destroy(); Hub.Visuals[player] = nil end
end
for _, p in ipairs(Players:GetPlayers()) do addVisual(p) end
connect(Players.PlayerAdded, addVisual)
connect(Players.PlayerRemoving, removeVisual)

local function updateESP(cam)
    for player, v in pairs(Hub.Visuals) do
        v.Box.Visible = false
        v.Highlight.Enabled = false
        local team = friendly(player)
        if not S.ESP or not (team and S.Teammates or not team and S.Enemies) then continue end
        local char, hum, root = character(player)
        if not char then continue end
        local distance = (root.Position - cam.CFrame.Position).Magnitude
        if distance > S.MaxDistance then continue end
        if not S.ThroughWalls and not visible(cam, char, root.Position) then continue end
        local color = team and S.TeamColor or S.EnemyColor
        v.Highlight.Adornee = char
        v.Highlight.Enabled = S.Chams
        v.Highlight.FillColor = color
        v.Highlight.OutlineColor = color
        v.Highlight.FillTransparency = S.FillTransparency / 100
        v.Highlight.OutlineTransparency = 0
        v.Highlight.DepthMode = S.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
        -- Use body extents, excluding oversized weapon/armor models.
        local head = char:FindFirstChild("Head")
        local headSize = head and (Hub.HitboxOriginals[head] and Hub.HitboxOriginals[head].Size or head.Size)
        local top = head and head.Position + Vector3.new(0, headSize.Y / 2 + 0.3, 0) or root.Position + Vector3.new(0, 3, 0)
        local rootSize = Hub.HitboxOriginals[root] and Hub.HitboxOriginals[root].Size or root.Size
        local bottom = root.Position - Vector3.new(0, hum.HipHeight + rootSize.Y / 2 + 0.2, 0)
        local a, aVisible = cam:WorldToViewportPoint(top)
        local b = cam:WorldToViewportPoint(bottom)
        if not aVisible or b.Z <= 0 then continue end
        local height = math.max(8, math.abs(b.Y - a.Y))
        local width = height * 0.55
        v.Box.Position = UDim2.fromOffset((a.X + b.X) / 2 - width / 2, math.min(a.Y, b.Y))
        v.Box.Size = UDim2.fromOffset(width, height)
        v.Box.Visible = true
        v.Stroke.Enabled = S.Boxes
        v.Stroke.Color = color
        local text = {}
        if S.Names then table.insert(text, player.DisplayName) end
        if S.Class then
            local class = char:GetAttribute("Class") or char:GetAttribute("BaseClass") or player:GetAttribute("CurrentProgressionClass")
            table.insert(text, "Class: " .. tostring(class or "Unknown"))
        end
        if S.Weapon then
            local tool = char:FindFirstChildOfClass("Tool")
            local weapon = tool and (tool:GetAttribute("MergedWith") or tool:GetAttribute("WeaponId") or tool.Name)
                or char:GetAttribute("Weapon") or "None"
            table.insert(text, "Weapon: " .. tostring(weapon))
        end
        if S.Status then
            if char:GetAttribute("Downed") then table.insert(text, "DOWNED")
            elseif char:GetAttribute("Executing") then table.insert(text, "EXECUTING")
            elseif char:GetAttribute("Reviving") then table.insert(text, "REVIVING") end
        end
        if S.Distance then table.insert(text, string.format("%d studs", distance)) end
        v.Label.Text = table.concat(text, "\n")
        local labelHeight = math.max(24, #text * (S.TextSize + 3))
        v.Label.Size = UDim2.new(1, 200, 0, labelHeight)
        v.Label.Position = UDim2.new(0.5, 0, 0, -labelHeight - 3)
        v.Label.TextColor3 = color
        v.Label.TextSize = S.TextSize
        v.HealthBG.Visible = S.Health
        local ratio = math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1)
        v.Health.Size = UDim2.fromScale(1, ratio)
        v.Health.BackgroundColor3 = Color3.fromHSV(ratio / 3, 0.85, 1)
        local armor = tonumber(char:GetAttribute("Armor"))
        local maxArmor = tonumber(char:GetAttribute("MAX_ARMOR"))
        v.ArmorBG.Visible = S.Armor and armor ~= nil and maxArmor ~= nil and maxArmor > 0
        v.Armor.Size = UDim2.fromScale(1, armor and maxArmor and maxArmor > 0 and math.clamp(armor / maxArmor, 0, 1) or 0)
    end
end
local function restoreFOV()
    for cam, value in pairs(Hub.Originals) do
        pcall(function() cam.FieldOfView = value end)
    end
    table.clear(Hub.Originals)
end
function Hub:Unload()
    if not self.Active then return end
    self.Active = false
    self:RestoreMenuCursor()
    self:CancelAutoInteraction()
    for _, disconnect in ipairs(self.InteractionDisconnects) do pcall(disconnect) end
    for _, c in ipairs(self.Connections) do c:Disconnect() end
    action("Sprint", false)
    action("Block", false)
    restoreHitboxes()
    if self.RestockReturn and S.ReturnFromCache then
        local back = self.RestockReturn
        if Me.Character == back.Character and back.Root.Parent then self:SetRootCFrame(back.Root, back.CFrame) end
    end
    RunService:UnbindFromRenderStep("XenraxRender")
    restoreFOV()
    self.Overlay:Destroy()
    self.Highlights:Destroy()
    if self.UI then self.UI:Destroy() end
    if Env.XenraxHub == self then Env.XenraxHub = nil end
end

local ok, Lunex = pcall(function()
    local source = game:HttpGet("https://raw.githubusercontent.com/1svxz/Lunex.lol-Ui-lib/main/Test")
    -- Keep slider/touch gestures independent from window dragging.
    source = source:gsub("enableDrag%(MainFrame, MainFrame%)", "-- Drag the window using its title bar only.", 1)
    source = source:gsub("enableDrag%(TopTitle, MainFrame%)", "TopTitle.Active = true\nenableDrag(TopTitle, MainFrame)", 1)
    -- Compact mobile layout: leave the game visible and never upscale the window.
    source = source:gsub("local scaleX = %(vp.X %- 16%) / WIN_WIDTH", "local scaleX = math.min(vp.X - 16, vp.X * (UserInputService.TouchEnabled and 0.72 or 0.9)) / WIN_WIDTH", 1)
    source = source:gsub("local scaleY = %(vp.Y %- 16%) / WIN_HEIGHT", "local scaleY = math.min(vp.Y - 16, vp.Y * 0.88) / WIN_HEIGHT", 1)
    source = source:gsub("math.clamp%(math.min%(scaleX, scaleY, 1.25%), 0.50, 1.35%)", "math.clamp(math.min(scaleX, scaleY), 0.30, 1)", 1)
    -- Neutral black surfaces with colored accents, matching the compact reference.
    local neutralTheme = {
        WindowBgTop = 12, WindowBgBottom = 3, CardBgTop = 14, CardBgBottom = 6,
        ElementBgTop = 19, ElementBgBottom = 7, DropListTop = 20, DropListMid = 12,
        DropListBottom = 6, BorderMain = 55, BorderCard = 40, BorderElement = 48,
    }
    for key, shade in pairs(neutralTheme) do
        source = source:gsub("THEME%." .. key .. "%s*=%s*Color3%.fromHSV%b()",
            "THEME." .. key .. " = Color3.fromRGB(" .. shade .. ", " .. shade .. ", " .. shade .. ")")
    end
    source = source:gsub("TopTitle.TextXAlignment = Enum.TextXAlignment.Left", "TopTitle.TextXAlignment = Enum.TextXAlignment.Center", 1)
    -- Expose the library's existing navigation for initial page selection.
    source = source:gsub("return windowObj", "windowObj.SelectTab = function(_, name) switchTab(name) end\nwindowObj.SelectSubTab = function(_, index) switchSubTab(index) end\nreturn windowObj", 1)
    return loadstring(source)()
end)
if not ok then Hub:Unload(); error("Xenrax: Lunex UI load failed: " .. tostring(Lunex)) end
local windowOK, NativeWindow = pcall(function()
    return Lunex:CreateWindow({ Name = "Xenrax hub", ConfigFolder = "XenraxConfigs_LEGIONES", Width = 560, Height = 440,
        TabHeight = 26, SubHeaderHeight = 28, TabTextSize = 13, Accent = Color3.fromRGB(170, 85, 255) })
end)
if not windowOK then Hub:Unload(); error("Xenrax: Lunex window failed: " .. tostring(NativeWindow)) end
Hub.UI = NativeWindow.ScreenGui
Hub.UI.Name = "XenraxHubUI"
Hub.Window = NativeWindow
Hub.UIFramework = "Lunex.lol"
NativeWindow.MainFrame.Position = UDim2.fromScale(0.5, 0.5)
NativeWindow.ConfigFeatureEntries.__theme_font.Set("Gotham")
local Library = {}
function Library.Notify(config)
    local toast = create("TextLabel", {
        Name = "XenraxNotification", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20),
        Size = UDim2.fromOffset(360, 74), BackgroundColor3 = Color3.fromRGB(24, 12, 32), BorderSizePixel = 0,
        TextColor3 = Color3.fromRGB(240, 235, 245), TextSize = 15, Font = Enum.Font.SourceSans,
        TextWrapped = true, Text = (config.Title or "Xenrax hub") .. "\n" .. (config.Text or ""), ZIndex = 200,
    }, Hub.UI)
    create("UIStroke", { Color = Color3.fromRGB(170, 85, 255), Thickness = 1 }, toast)
    task.delay(config.Duration or 4, function() toast:Destroy() end)
end
function Hub:ToggleMenu()
    NativeWindow.MainFrame.Visible = not NativeWindow.MainFrame.Visible
    local button = self.UI:FindFirstChild("MobileToggleBtn")
    if button then button.Text = NativeWindow.MainFrame.Visible and "Close" or "Open" end
    self:UpdateMenuCursor()
end
local menuButton = create("TextButton", {
    Name = "MobileToggleBtn", Text = "Close", Font = Enum.Font.SourceSansBold, TextSize = 15,
    Size = UDim2.fromOffset(68, 30), Position = UDim2.new(0, 12, 0.5, -15),
    BackgroundColor3 = Color3.fromRGB(28, 14, 36), TextColor3 = Color3.fromRGB(235, 220, 255),
    BorderSizePixel = 0, ZIndex = 100,
}, Hub.UI)
create("UIStroke", { Color = Color3.fromRGB(170, 85, 255), Thickness = 1 }, menuButton)
connect(menuButton.Activated, function() Hub:ToggleMenu() end)

-- Four main tabs with two subpages each, plus Lunex Settings.
local tabRoutes = {
    ["Silent aim"] = { "Combat", "Aim" }, ["Combat automation"] = { "Combat", "Defense" },
    ["ESP"] = { "Visuals", "ESP" }, ["Hitboxes"] = { "Visuals", "Hitboxes" },
    ["Movement & Camera"] = { "Player", "Movement" }, ["Ammo & Reload"] = { "Player", "Ammo" },
    ["Teleports"] = { "World", "Teleports" }, ["Settings"] = { "World", "Hub" },
}
local mainTabs, subTabs = {}, {}
for _, name in ipairs({ "Combat", "Visuals", "Player", "World" }) do mainTabs[name] = NativeWindow:CreateTab(name) end
for _, name in ipairs({ "Silent aim", "Combat automation", "ESP", "Hitboxes", "Movement & Camera", "Ammo & Reload", "Teleports", "Settings" }) do
    local route = tabRoutes[name]
    subTabs[name] = mainTabs[route[1]]:CreateSubTab({ IconText = route[2] })
end
NativeWindow:SelectTab("Combat")
local Window = {}
function Window:CreateTab(config) return subTabs[config.Name] end
local function section(tab, name, side)
    local card = tab:CreateCard(side or "Left", name)
    local sec = { _content = card.Container }
    for _, method in ipairs({ "AddToggle", "AddSlider", "AddDropdown", "AddColorPicker", "AddButton" }) do
        local methodName = method
        sec[methodName] = function(_, config)
            config.Flag = config.ConfigKey or config.Flag
            local result = card[methodName](card, config)
            if config.ConfigKey then
                if methodName == "AddColorPicker" then
                    local entry = NativeWindow.ConfigFeatureEntries[config.ConfigKey]
                    Hub.Controls[config.ConfigKey] = {
                        Get = function() local c = entry.Get(); return Color3.new(c.R, c.G, c.B) end,
                        Set = function(c) entry.Set(typeof(c) == "Color3" and { R = c.R, G = c.G, B = c.B } or c) end,
                    }
                elseif type(result) == "table" then Hub.Controls[config.ConfigKey] = result end
            end
            return result
        end
    end
    function sec:AddLabel(text)
        return create("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Text = text,
            TextSize = 14, Font = Enum.Font.SourceSans, TextColor3 = Color3.fromRGB(180, 165, 195),
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
        }, card.Container)
    end
    function sec:AddKeybind(config)
        local key = config.Default
        local button, label
        local function caption() return config.Name .. ": [" .. key.Name .. "]" end
        local function setKey(value)
            if type(value) == "string" then value = Enum.KeyCode[value:match("([^%.]+)$")] end
            if typeof(value) ~= "EnumItem" or value.EnumType ~= Enum.KeyCode or value == Enum.KeyCode.Unknown then return end
            key = value
            label.Text = caption()
            if config.Callback then config.Callback(key) end
        end
        button = card:AddButton({ Name = caption(), Callback = function()
            if Hub.CapturingKey then return end
            Hub.CapturingKey = config.ConfigKey
            label.Text = config.Name .. ": press a key (Esc cancels)"
        end })
        label = button:FindFirstChildOfClass("TextLabel")
        connect(Input.InputBegan, function(input)
            if Hub.CapturingKey ~= config.ConfigKey or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            Hub.CapturedInput = input
            Hub.CapturingKey = nil
            if input.KeyCode ~= Enum.KeyCode.Escape then setKey(input.KeyCode) else label.Text = caption() end
        end)
        local control = { Set = setKey, Get = function() return key end }
        Hub.Controls[config.ConfigKey] = control
        NativeWindow.ConfigFeatureEntries[config.ConfigKey] = { Get = function() return key.Name end, Set = setKey }
        return control
    end
    return sec
end
local function toggle(sec, name, key, callback)
    local control = sec:AddToggle({ Name = name, Default = S[key], ConfigKey = key, Callback = function(v)
        S[key] = v
        if callback then callback(v) end
    end })
    Hub.Controls[key] = control
    return control
end
local function slider(sec, name, key, min, max)
    local control = sec:AddSlider({ Name = name, Min = min, Max = max, Default = S[key], ConfigKey = key, Callback = function(v) S[key] = v end })
    Hub.Controls[key] = control
    return control
end
local function color(sec, name, key)
    sec:AddColorPicker({ Name = name, Default = S[key], ConfigKey = key, Callback = function(v) S[key] = v end })
end
local aim = Window:CreateTab({ Name = "Silent aim", Icon = "crosshair" })
local targeting = section(aim, "Targeting")
toggle(targeting, "Silent aim", "Silent", function(v)
    if v then
        Hub.SilentReady = installSilent()
        if not Hub.SilentReady then
            Library.Notify({ Title = "Xenrax hub", Text = "Shot function unavailable. Equip a ranged weapon and retry.", Duration = 5 })
            task.defer(function() if Hub.Active then Hub.Controls.Silent.Set(false) end end)
        end
    end
end)
targeting:AddLabel("LEGIONES ranged weapons / enemies only")
toggle(targeting, "Wall check", "WallCheck")
targeting:AddDropdown({ Name = "Target part", Options = { "Head", "UpperTorso", "HumanoidRootPart" }, Default = S.AimPart, ConfigKey = "AimPart", Callback = function(v) S.AimPart = v end })
slider(targeting, "Hit chance %", "HitChance", 0, 100)
slider(targeting, "Max distance", "AimDistance", 100, 5000)
local aimView = section(aim, "Aim FOV", "Right")
toggle(aimView, "Show aim circle", "Circle")
toggle(aimView, "Wallbang", "Wallbang")
aimView:AddLabel("Client projectiles ignore map collisions")
aimView:AddLabel("Server damage validation still applies")
slider(aimView, "Radius (pixels)", "Radius", 20, 600)
color(aimView, "Circle color", "CircleColor")
aimView:AddLabel("Circle is centered on the crosshair")
local predictionSection = section(aim, "Prediction", "Right")
toggle(predictionSection, "Automatic projectile lead", "AutoPrediction")
toggle(predictionSection, "Ping compensation", "PingCompensation")
toggle(predictionSection, "Short-term acceleration", "PredictAcceleration")
slider(predictionSection, "Prediction strength %", "PredictionStrength", 0, 150)
slider(predictionSection, "Max lead time (ms)", "MaxPrediction", 100, 3000)
slider(predictionSection, "Additional lead (ms)", "Prediction", 0, 300)
predictionSection:AddLabel("Tracks movement; resets after teleports")

local esp = Window:CreateTab({ Name = "ESP", Icon = "eye" })
local filters = section(esp, "Players")
toggle(filters, "Enable ESP", "ESP")
toggle(filters, "Enemies", "Enemies")
toggle(filters, "Teammates", "Teammates")
toggle(filters, "Through walls", "ThroughWalls")
slider(filters, "Max distance", "MaxDistance", 100, 5000)
color(filters, "Enemy color", "EnemyColor")
color(filters, "Teammate color", "TeamColor")
local style = section(esp, "Customization", "Right")
toggle(style, "Boxes", "Boxes")
toggle(style, "Names", "Names")
toggle(style, "Class", "Class")
toggle(style, "Weapon", "Weapon")
toggle(style, "Player status", "Status")
toggle(style, "Armor bar", "Armor")
toggle(style, "Health bars", "Health")
toggle(style, "Distance", "Distance")
toggle(style, "Chams", "Chams")
slider(style, "Chams transparency %", "FillTransparency", 0, 100)
slider(style, "Text size", "TextSize", 10, 22)

local misc = Window:CreateTab({ Name = "Movement & Camera", Icon = "zap" })
local movement = section(misc, "CFrame speed")
local speedToggle = toggle(movement, "Enable CFrame speed", "Speed")
slider(movement, "Additional studs / second", "ExtraSpeed", 0, 150)
movement:AddKeybind({ Name = "Speed toggle key", Default = S.SpeedKey, ConfigKey = "SpeedKey", Callback = function(v) S.SpeedKey = v end })
movement:AddLabel("Uses movement direction; keeps vertical physics")
toggle(movement, "Auto sprint", "AutoSprint", function(v) if not v then action("Sprint", false) end end)
local cameraSection = section(misc, "Screen FOV", "Right")
toggle(cameraSection, "Override camera FOV", "FOVEnabled", function(v) if not v then restoreFOV() end end)
slider(cameraSection, "Camera FOV (degrees)", "FOV", 40, 120)
cameraSection:AddLabel("RightShift: show / hide menu")

local combat = Window:CreateTab({ Name = "Combat automation", Icon = "shield" })
local defense = section(combat, "Auto block")
toggle(defense, "Auto block melee attacks", "AutoBlock", function(v)
    Hub.BlockState.WaitForClear = false
    if not v then action("Block", false) end
end)
slider(defense, "Block range (studs)", "BlockRange", 5, 35)
toggle(defense, "Face incoming attack", "FaceBlock")
defense:AddLabel("Detects enemy melee attack animations")
defense:AddLabel("Equip a melee weapon to block")
defense:AddButton({ Name = "Release auto block now", Callback = function()
    Hub.BlockState.PauseUntil = os.clock() + 1.5
    Hub.BlockState.ThreatUntil = 0
    Hub.BlockState.WaitForClear = true
    Hub:SetAutoBlock(false)
end })
local cloakSection = section(combat, "Marksman cloak", "Right")
toggle(cloakSection, "Re-cloak after cloaked shot", "AutoCloak", function(v) if not v then Hub.PendingCloak = nil end end)
slider(cloakSection, "Re-cloak delay (ms)", "CloakDelay", 1500, 5000)
cloakSection:AddLabel("Only after firing while already invisible")
cloakSection:AddLabel("Waits for cloak cooldown / energy")
local finishSection = section(combat, "Finish & revive")
toggle(finishSection, "Auto execute downed enemies", "AutoExecute", function(v) if not v then Hub:CancelAutoInteraction("Execute") end end)
toggle(finishSection, "Auto revive teammates (Medic)", "AutoRevive", function(v) if not v then Hub:CancelAutoInteraction("Revive") end end)
slider(finishSection, "Interaction range", "FinishRange", 2, 10)
slider(finishSection, "Attempt interval (ms)", "FinishDelay", 400, 2000)
toggle(finishSection, "Interaction wall check", "FinishWallCheck")
finishSection:AddLabel("Execute: nearest downed enemy in any direction")
finishSection:AddLabel("Revive: native on-screen target (Medic)")
finishSection:AddLabel("Manual interactions keep priority")
Hub.InteractionStatusLabel = finishSection:AddLabel("Waiting for a downed enemy nearby")
finishSection:AddButton({ Name = "Retry auto interaction now", Callback = function()
    Hub.NextAutoInteraction = 0
    Hub.StatusHoldUntil = 0
    table.clear(Hub.InteractionCooldowns)
end })
if not Hub.Capabilities.AutoInteract then finishSection:AddLabel("Native interaction API unavailable") end

local hitboxTab = Window:CreateTab({ Name = "Hitboxes", Icon = "box" })
local hitboxes = section(hitboxTab, "Enemy hitbox expander")
toggle(hitboxes, "Enable hitbox expander", "Hitbox", function(v) if not v then restoreHitboxes() end end)
hitboxes:AddDropdown({ Name = "Body part", Options = { "Head", "UpperTorso", "HumanoidRootPart" }, Default = S.HitboxPart, ConfigKey = "HitboxPart", Callback = function(v) S.HitboxPart = v; restoreHitboxes() end })
slider(hitboxes, "Size (studs)", "HitboxSize", 2, 20)
slider(hitboxes, "Transparency %", "HitboxTransparency", 0, 100)
local hitboxInfo = section(hitboxTab, "Information", "Right")
hitboxInfo:AddLabel("Enemies only; updates after respawn")
hitboxInfo:AddLabel("Shots inside the box aim at the real body")
hitboxInfo:AddLabel("Does not resize replicated body parts")

local supplyTab = Window:CreateTab({ Name = "Ammo & Reload", Icon = "refresh-cw" })
local reloadSection = section(supplyTab, "Automatic reload")
toggle(reloadSection, "Auto reload", "AutoReload")
slider(reloadSection, "Reload at magazine %", "ReloadPercent", 0, 75)
reloadSection:AddLabel("0%: reload only when empty")
local supply = section(supplyTab, "Ammo caches", "Right")
toggle(supply, "Auto restock at cache", "AutoRestock")
toggle(supply, "Return after restocking", "ReturnFromCache")
supply:AddLabel("Supports Marksman / Suppressor weapons")
supply:AddLabel("Teleports to a loaded cache when empty")
local function notify(text)
    Library.Notify({ Title = "Xenrax hub", Text = text, Duration = 4 })
end
supply:AddButton({ Name = "Restock at nearest cache now", Callback = function()
    local success, reason = Hub:Restock()
    if not success then notify(reason) end
end })

local teleportTab = Window:CreateTab({ Name = "Teleports", Icon = "map-pin" })
local pointSection = section(teleportTab, "Capture points")
local selectedPoint
local function pointNames()
    local names = {}
    for name in pairs(Hub:GetPoints()) do table.insert(names, name) end
    table.sort(names)
    if #names == 0 then names[1] = "No points loaded" end
    return names
end
local pointContainer
local function refreshPoints()
    if not Hub.Active then return end
    if pointContainer then pointContainer:Destroy() end
    local names = pointNames()
    if not table.find(names, selectedPoint) then selectedPoint = names[1] end
    local before = {}
    for _, obj in ipairs(pointSection._content:GetChildren()) do before[obj] = true end
    Hub.PointDropdown = pointSection:AddDropdown({ Name = "Point", Options = names, Default = selectedPoint, Callback = function(v) selectedPoint = v end })
    for _, obj in ipairs(pointSection._content:GetChildren()) do
        if not before[obj] and obj:IsA("GuiObject") then pointContainer = obj; obj.LayoutOrder = -1 end
    end
end
refreshPoints()
pointSection:AddButton({ Name = "Refresh point list", Callback = refreshPoints })
connect(workspace:GetAttributeChangedSignal("GameMode"), function() task.defer(refreshPoints) end)
pointSection:AddButton({ Name = "Teleport to selected point", Callback = function()
    local success, reason = Hub:TeleportPoint(selectedPoint)
    if not success then notify(reason) end
end })
pointSection:AddButton({ Name = "Teleport to active point", Callback = function()
    local name = workspace:GetAttribute("ActivePoint")
    if not name then notify("No active point in this mode"); return end
    local success, reason = Hub:TeleportPoint(name)
    if not success then notify(reason) end
end })
local travel = section(teleportTab, "Return & positions", "Right")
travel:AddButton({ Name = "Return to previous position", Callback = function()
    local _, _, root = character(Me)
    if root and Hub.LastTeleport and not Hub.Restocking then
        local previous = root.CFrame
        Hub:SetRootCFrame(root, Hub.LastTeleport)
        root.AssemblyLinearVelocity = Vector3.zero
        Hub.LastTeleport = previous
    end
end })
travel:AddButton({ Name = "Save current position", Callback = function()
    local _, _, root = character(Me)
    if root then Hub.SavedPosition = root.CFrame; notify("Position saved") else notify("Spawn your character first") end
end })
travel:AddButton({ Name = "Teleport to saved position", Callback = function()
    local _, _, root = character(Me)
    if root and Hub.SavedPosition and not Hub.Restocking then
        Hub.LastTeleport = root.CFrame
        Hub:SetRootCFrame(root, Hub.SavedPosition)
        root.AssemblyLinearVelocity = Vector3.zero
    end
end })

local settings = Window:CreateTab({ Name = "Settings", Icon = "settings" })
local configHelp = section(settings, "Configurations")
configHelp:AddLabel("Use the Settings tab to save / load configs")
configHelp:AddLabel("Settings also contains accent color and fonts")
local credits = section(settings, "Credits", "Right")
credits:AddKeybind({ Name = "Open / close GUI", Default = S.MenuKey, ConfigKey = "MenuKey", Callback = function(v) S.MenuKey = v end })
credits:AddLabel("made by t.me/rockscript for Xenrax")
credits:AddLabel("Interface: Lunex.lol / 1svxz")
credits:AddLabel("Game: LEGIONES")
credits:AddButton({ Name = "Copy credits", Callback = function()
    if setclipboard then setclipboard("made by t.me/rockscript for Xenrax") end
end })
credits:AddButton({ Name = "Unload Xenrax hub", Callback = function() Hub:Unload() end })

connect(Input.InputBegan, function(input, processed)
    if Hub.CapturingKey or Hub.CapturedInput == input then return end
    if not processed and not Input:GetFocusedTextBox() and input.KeyCode == S.MenuKey then
        Hub:ToggleMenu()
    end
    if not processed and not Input:GetFocusedTextBox() and input.KeyCode == S.SpeedKey then speedToggle.Set(not S.Speed) end
end)
connect(RunService.Heartbeat, function(dt)
    if not S.Speed or Hub.Restocking or Hub:IsAutoInteracting() or Input:GetFocusedTextBox() then return end
    local _, hum, root = character(Me)
    if not root or root.Anchored or hum.Sit then return end
    local direction = hum.MoveDirection * Vector3.new(1, 0, 1)
    if direction.Magnitude > 0.01 then
        Hub:SetRootCFrame(root, root.CFrame + direction * S.ExtraSpeed * math.min(dt, 0.1))
    end
end)
local nextReload, nextCloak, accumulator = 0, 0, 0
connect(Me.CharacterAdded, function()
    Hub.PendingCloak = nil
    Hub.LastTeleport = nil
    action("Sprint", false); action("Block", false)
    Hub.BlockState.Manual = false
    Hub.BlockState.ThreatUntil = 0
end)
connect(Me.CharacterRemoving, function()
    Hub:CancelAutoInteraction()
    Hub:SetAutoBlock(false)
    Hub.BlockState.Manual = false
    Hub.BlockState.ThreatUntil = 0
end)
function Hub:UpdateAutoBlock()
    local char, hum, root = character(Me)
    local state, now = self.BlockState, os.clock()
    if not self.Active or not S.AutoBlock or not root or self.Restocking or self:IsAutoInteracting() or Input:GetFocusedTextBox()
        or char:GetAttribute("Mode") ~= "Melee" or not char:FindFirstChildOfClass("Tool")
        or char:GetAttribute("Downed") or char:GetAttribute("Ragdoll") or state.Manual or now < state.PauseUntil then
        state.ThreatUntil = 0
        self:SetAutoBlock(false)
        return
    end
    local enemy = incomingAttack(root)
    if state.WaitForClear then
        self:SetAutoBlock(false)
        if not enemy then state.WaitForClear = false end
        return
    end
    if enemy then
        state.ThreatUntil = now + 0.12
        if S.FaceBlock then
            local target = Vector3.new(enemy.Position.X, root.Position.Y, enemy.Position.Z)
            if (target - root.Position).Magnitude > 0.01 then Hub:SetRootCFrame(root, CFrame.lookAt(root.Position, target)) end
        end
    end
    self:SetAutoBlock(now < (state.ThreatUntil or 0))
end
local defenseAccumulator = 0
connect(RunService.Heartbeat, function(dt)
    defenseAccumulator = defenseAccumulator + dt
    if defenseAccumulator < 0.025 then return end
    defenseAccumulator = 0
    local success, reason = pcall(Hub.UpdateAutoBlock, Hub)
    if not success then
        Hub:SetAutoBlock(false)
        Hub.LastBlockError = reason
    end
end)
local function gameplayCall(fn, ...)
    local identity = getthreadidentity and getthreadidentity()
    if identity and setthreadidentity then setthreadidentity(2) end
    local result = table.pack(pcall(fn, ...))
    if identity and setthreadidentity then setthreadidentity(identity) end
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
end
local function automate()
    updateHitboxes()
    gameplayCall(Hub.UpdateAutoInteract, Hub)
    local char, hum, root = character(Me)
    if not char or Hub.Restocking or Hub:IsAutoInteracting() or Input:GetFocusedTextBox() or char:GetAttribute("Downed") or char:GetAttribute("Ragdoll") then
        action("Sprint", false); action("Block", false)
        return
    end
    local now = os.clock()
    local blocking = Hub.BlockState.Held or Hub.BlockState.Manual
    action("Sprint", S.AutoSprint and not blocking and hum.MoveDirection.Magnitude > 0.1 and not hum.Sit
        and not char:GetAttribute("Aiming") and not char:GetAttribute("Downed") and not char:GetAttribute("Ragdoll"))
    local gun = gunState(char)
    if gun and char:GetAttribute("Mode") == "Ranged" and not gun.Reloading and (gun.MagSize or 0) > 0 then
        local needsCache = gun.Config.RequiresResupply == true or (gun.MaxReserveMagazines ~= nil and (gun.ReserveMagazines or 0) <= 0)
        if gun.Ammo <= 0 and needsCache and S.AutoRestock and now >= (Hub.NextRestock or 0) then
            Hub.NextRestock = now + 8
            Hub:Restock()
        elseif S.AutoReload and not needsCache and not gun.Config.NoReload and gun.Ammo < gun.MagSize
            and gun.Ammo / gun.MagSize * 100 <= S.ReloadPercent and now >= nextReload then
            nextReload = now + 1
            task.spawn(function()
                if Hub.Active and Me.Character == char and not gun._Destroyed then gun:Reload(true) end
            end)
        end
    end
    local pending = Hub.PendingCloak
    if pending then
        if not S.AutoCloak or pending.Character ~= char or now > pending.ExpiresAt or char:GetAttribute("Cloaked") == true then
            Hub.PendingCloak = nil
        elseif Cloak and now >= pending.ReadyAt and now >= nextCloak then
            nextCloak = now + 0.5
            Cloak:OnPressed()
        end
    end
end
connect(RunService.Heartbeat, function(dt)
    accumulator = accumulator + dt
    if accumulator < 0.1 then return end
    accumulator = 0
    local success, reason = xpcall(automate, debug.traceback)
    if not success then Hub:SetAutoBlock(false) end
    if not success and os.clock() >= (Hub.NextError or 0) then
        Hub.NextError = os.clock() + 5
        warn("Xenrax automation:", reason)
    end
end)
RunService:BindToRenderStep("XenraxRender", Enum.RenderPriority.Last.Value + 100, function()
    Hub:UpdateMenuCursor()
    if Hub.InteractionStatusLabel and Hub.InteractionStatusLabel.Parent then
        Hub.InteractionStatusLabel.Text = Hub.InteractionStatus or "Waiting for a downed enemy nearby"
    end
    local cam = workspace.CurrentCamera
    if not cam then return end
    if S.FOVEnabled then
        if not Hub.Originals[cam] then Hub.Originals[cam] = cam.FieldOfView end
        cam.FieldOfView = S.FOV
    end
    Ring.Visible = S.Silent and S.Circle
    Ring.Size = UDim2.fromOffset(S.Radius * 2, S.Radius * 2)
    RingStroke.Color = S.CircleColor
    updateESP(cam)
end)
Library.Notify({ Title = "Xenrax hub", Text = "Loaded. RightShift — menu. made by t.me/rockscript for Xenrax", Duration = 5 })
print("XENRAX_READY", game.PlaceId, "silent hook:", Hub.SilentReady)
