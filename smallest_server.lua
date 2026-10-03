-- Smallest Server Joiner
-- Client-side script (run via an executor). Works in most public Roblox games.
-- Finds the public server with the fewest players and teleports you into it.

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local placeId = game.PlaceId
local currentJob = game.JobId
local player = Players.LocalPlayer

local MAX_PAGES = 5
local RETRIES = 3

-- Fetch a URL, falling back to the executor's request function if HttpGet fails
local function fetch(url)
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)

    if ok and body then
        return body
    end

    local req = request or http_request or (syn and syn.request)
    if req then
        local ok2, res = pcall(req, { Url = url, Method = "GET" })
        if ok2 and res and res.StatusCode == 200 then
            return res.Body
        end
    end

    return nil
end

-- Returns the open server with the fewest players (excluding the current one)
local function findSmallestServer()
    local best
    local cursor = ""

    for _ = 1, MAX_PAGES do
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(placeId)

        if cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end

        local data

        for attempt = 1, RETRIES do
            local body = fetch(url)

            if body then
                local ok, decoded = pcall(function()
                    return HttpService:JSONDecode(body)
                end)

                if ok and decoded and decoded.data then
                    data = decoded
                    break
                end
            end

            task.wait(2 * attempt)
        end

        if not data then
            break
        end

        for _, s in ipairs(data.data) do
            if s.id ~= currentJob and s.playing < s.maxPlayers then
                if not best or s.playing < best.playing then
                    best = s
                end
            end
        end

        -- Results are sorted ascending, so a valid result on this page is the smallest
        if best then
            break
        end

        cursor = data.nextPageCursor

        if not cursor then
            break
        end

        task.wait(0.5)
    end

    return best
end

-- Remove any previous copy of the GUI if the script is run again
local function getGuiParent()
    local ok, ui = pcall(function()
        return gethui()
    end)

    if ok and ui then
        return ui
    end

    return game:GetService("CoreGui")
end

local parent = getGuiParent()
local old = parent:FindFirstChild("SmallestServer
