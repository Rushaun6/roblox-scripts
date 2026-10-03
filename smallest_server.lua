local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local placeId = game.PlaceId
local currentJob = game.JobId
local player = Players.LocalPlayer

-- Scans public servers (sorted by player count, ascending) and returns the smallest one
local function findSmallestServer()
    local best
    local cursor = ""

    for _ = 1, 5 do -- scan up to 5 pages (500 servers)
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(placeId)
        if cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end

        local ok, res = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        if not ok or not res or not res.data then
            break
        end

        for _, s in ipairs(res.data) do
            if s.id ~= currentJob and s.playing < s.maxPlayers then
                if not best or s.playing < best.playing then
                    best = s
                end
            end
        end

        -- results are sorted ascending, so the first valid page already has the smallest
        if best then break end

        cursor = res.nextPageCursor
        if not cursor then break end
        task.wait(0.5)
    end

    return best
end

local function joinSmallest(button)
    button.Text = "Scanning..."
    local server = findSmallestServer()
    if server then
        button.Text = ("Joining (%d players)..."):format(server.playing)
        TeleportService:TeleportToPlaceInstance(placeId, server.id, player)
    else
        button.Text = "No server found - retry"
    end
end

-- Simple button GUI
local gui = Instance.new("ScreenGui")
gui.Name = "SmallestServerJoiner"
gui.ResetOnSpawn = false
local okParent = pcall(function() gui.Parent = gethui() end)
if not okParent then
    gui.Parent = game:GetService("CoreGui")
end

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 200, 0, 50)
button.Position = UDim2.new(0.5, -100, 0, 20)
button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBold
button.TextSize = 16
button.Text = "Join Smallest Server"
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)

button.MouseButton1Click:Connect(function()
    joinSmallest(button)
end)
