-- esp.lua — returns function(Misc) -> ESP module
return function(Misc)
    local RunService = game:GetService("RunService")
    local Workspace  = game:GetService("Workspace")

    local ESP         = {}
    local enabled     = true
    local connections = {}

    local function removeDrawing(d)
        if d then
            pcall(function()
                d.Visible = false
                d:Remove()
            end)
        end
    end

    local function hideESP(record)
        record.Box.Visible      = false
        record.Distance.Visible = false
    end

    local function createESP(model)
        if Misc.ActiveModels[model] then return Misc.ActiveModels[model] end

        local box = Drawing.new("Square")
        box.Visible = false
        box.Filled  = false

        local dist = Drawing.new("Text")
        dist.Visible = false
        dist.Size    = 13
        dist.Center  = true
        dist.Outline = true
        dist.Text    = ""

        local record = { Box = box, Distance = dist }
        Misc.ActiveModels[model] = record
        return record
    end

    local function cleanupESP(model)
        local record = Misc.ActiveModels[model]
        if not record then return end
        removeDrawing(record.Box)
        removeDrawing(record.Distance)
        Misc.ActiveModels[model] = nil
    end

    local function cleanupWatcher(model)
        local w = Misc.WatchedModels[model]
        if not w then return end
        for _, c in ipairs(w) do c:Disconnect() end
        Misc.WatchedModels[model] = nil
        cleanupESP(model)
    end

    local function refreshModel(model)
        if not model.Parent or not model:IsDescendantOf(Workspace) then return end
        if Misc.isValidModel(model) then createESP(model) else cleanupESP(model) end
    end

    local function watchModel(model)
        if not model:IsA("Model") then return end
        if Misc.WatchedModels[model] then return end
        local conns = {}
        Misc.WatchedModels[model] = conns
        local function refresh() refreshModel(model) end
        table.insert(conns, model:GetPropertyChangedSignal("Name"):Connect(refresh))
        table.insert(conns, model.ChildAdded:Connect(refresh))
        table.insert(conns, model.ChildRemoved:Connect(refresh))
        table.insert(conns, model.AncestryChanged:Connect(function()
            if not model:IsDescendantOf(Workspace) then cleanupWatcher(model) end
        end))
        refreshModel(model)
    end

    function ESP:SetEnabled(v) enabled = v end

    function ESP:Init()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") then watchModel(obj) end
        end

        table.insert(connections, Workspace.DescendantAdded:Connect(function(obj)
            if obj:IsA("Model") then watchModel(obj) end
        end))

        table.insert(connections, RunService.RenderStepped:Connect(function()
            if not enabled then
                for _, record in pairs(Misc.ActiveModels) do hideESP(record) end
                return
            end

            local cam = Workspace.CurrentCamera
            if not cam then return end

            for model, record in pairs(Misc.ActiveModels) do
                if not model.Parent or not model:IsDescendantOf(Workspace) then
                    cleanupWatcher(model)
                    continue
                end
                if not Misc.isValidModel(model) then
                    hideESP(record)
                    continue
                end
                local root, head = Misc.getParts(model)
                if not root or not head then hideESP(record) continue end

                record.Box.Color        = Misc.Config.BoxColor
                record.Box.Thickness    = Misc.Config.BoxThickness
                record.Box.Transparency = Misc.Config.BoxTransparency
                record.Distance.Color   = Misc.Config.DistanceColor

                local topWorld    = head.Position + Vector3.new(0, 0.6, 0)
                local bottomWorld = root.Position - Vector3.new(0, 2.5, 0)
                local top    = cam:WorldToViewportPoint(topWorld)
                local bottom = cam:WorldToViewportPoint(bottomWorld)

                if top.Z > 0 and bottom.Z > 0 then
                    local height = math.abs(bottom.Y - top.Y)
                    local width  = height / 2
                    record.Box.Size     = Vector2.new(width, height)
                    record.Box.Position = Vector2.new(top.X - width / 2, top.Y)
                    record.Box.Visible  = true

                    local studs = Misc.getDistance(root)
                    record.Distance.Text     = string.format("[%d studs]", math.floor(studs))
                    record.Distance.Position = Vector2.new(top.X, bottom.Y + 4)
                    record.Distance.Visible  = true
                else
                    hideESP(record)
                end
            end
        end))
    end

    function ESP:Unload()
        for _, c in ipairs(connections) do c:Disconnect() end
        connections = {}
        for m in pairs(Misc.WatchedModels) do cleanupWatcher(m) end
        for m in pairs(Misc.ActiveModels)  do cleanupESP(m)     end
    end

    return ESP
end
