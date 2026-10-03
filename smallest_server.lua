--[[
SETUP (in Roblox Studio):
1. Put PART 1 in a Script inside ServerScriptService.
2. Put PART 2 in a LocalScript inside StarterGui.
3. Publish the game. Teleporting only works in a published game,
   not in Studio's play test.
]]

------------------------------------------------------------
-- PART 1: Script (ServerScriptService)
------------------------------------------------------------
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local serverMap = MemoryStoreService:GetSortedMap("ActiveServers")

local remote = Instance.new("RemoteEvent")
remote.Name = "JoinSmallestEvent"
remote.Parent = ReplicatedStorage

local TTL = 45        -- entry expires if the server stops reporting
local lastUse = {}

-- Every 20s, this server reports its player count
task.spawn(function()
    while true do
        pcall(function()
            serverMap:SetAsync(game.JobId, {
                players = #Players:GetPlayers(),
                max = Players.MaxPlayers,
            }, TTL)
        end)
        task.wait(20)
    end
end)

-- Remove this server from the list when it shuts down
game:BindToClose(function()
    pcall(function()
        serverMap:RemoveAsync(game.JobId)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    lastUse[player] = nil
end)

remote.OnServerEvent:Connect(function(player)
    -- 5 second cooldown per player
    if lastUse[player] and os.clock() - lastUse[player] < 5 then
        return
    end
    lastUse[player] = os.clock()

    local ok, items = pcall(function()
        return serverMap:GetRangeAsync(Enum.SortDirection.Ascending, 200)
    end)
    if not ok then
        remote:FireClient(player, "Error, try again")
        return
    end

    local best
    for _, item in ipairs(items) do
        local v = item.value
        if item.key ~= game.JobId and v.players < v.max then
            if not best or v.players < best.players then
                best = { id = item.key, players = v.players }
            end
        end
    end

    if not best then
        remote:FireClient(player, "No other server found")
        return
    end

    remote:FireClient(player, ("Joining server (%d players)..."):format(best.players))

    local options = Instance.new("TeleportOptions")
    options.ServerInstanceId = best.id
    pcall(function()
        TeleportService:TeleportAsync(game.PlaceId, { player }, options)
    end)
end)

------------------------------------------------------------
-- PART 2: LocalScript (StarterGui)
------------------------------------------------------------
--[[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remote = ReplicatedStorage:WaitForChild("JoinSmallestEvent")

local gui = Instance.new("ScreenGui")
gui.Name = "SmallestServerJoiner"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 220, 0, 50)
button.Position = UDim2.new(0.5, -110, 0, 20)
button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBold
button.TextSize = 16
button.Text = "Join Smallest Server"
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)

button.MouseButton1Click:Connect(function()
    button.Text = "Searching..."
    remote:FireServer()
end)

remote.OnClientEvent:Connect(function(message)
    button.Text = message
    task.wait(3)
    button.Text = "Join Smallest Server"
end)
]]
