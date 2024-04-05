-- [[
--     **ATTENTION:**

--     I LEFT A BUNCH OF COMMENTS FOR DEVELOPERS WHO MAY WANT TO MODIFY THIS SCRIPT
--     OR CONVERT IT TO WORK WITH A DIFFERENT FRAMEWORK ETC.

--     THIS IS NOT WHERE YOU CONFIG ANYTHING, THESE COMMENTS ARE LEFT FOR THOSE
--     WHO KNOW HOW TO CODE SCRIPTS.
-- ]]

local QBCore = exports['qb-core']:GetCoreObject() -- initialize qbcore

local monitor = { storedClockins = {} } -- create table for monitoring clockins etc
local hooks = config.webhooks -- webhooks but shorter

-- [[
--     a list of time zones used when logging
--     so that way users who view the log in discord
--     can calculate the time relative to their irl time zone.
--     (thats if they are keeping track of it, usually supervisors do this)
-- ]]

local Zones = { 
    ['-1200'] = 'AoE',  
    ['-1100'] = 'NUT',  
    ['-1000'] = 'CKT',  
    ['-0930'] = 'MIT', 
    ['-0900'] = 'HST',  
    ['-0800'] = 'AKST', 
    ['-0700'] = 'PST',  
    ['-0600'] = 'MST',  
    ['-0500'] = 'CST',  
    ['-0430'] = 'VET',  
    ['-0400'] = 'EST', 
    ['-0330'] = 'NST',  
    ['-0300'] = 'ART',  
    ['-0200'] = 'BRT',  
    ['-0100'] = 'CVT',  
    ['+0000'] = 'GMT',  
    ['+0100'] = 'CET',  
    ['+0200'] = 'EET',  
    ['+0300'] = 'MSK',  
    ['+0330'] = 'IRST', 
    ['+0400'] = 'GST',  
    ['+0430'] = 'IRST', 
    ['+0500'] = 'PKT',  
    ['+0530'] = 'IST',  
    ['+0545'] = 'NPT',  
    ['+0600'] = 'BST',  
    ['+0630'] = 'MMT',  
    ['+0700'] = 'ICT', 
    ['+0800'] = 'CST', 
    ['+0900'] = 'JST', 
    ['+0930'] = 'ACST', 
    ['+1000'] = 'AEST', 
    ['+1030'] = 'ACDT', 
    ['+1100'] = 'AEDT', 
    ['+1200'] = 'NZST', 
    ['+1245'] = 'CHAST',
    ['+1300'] = 'NZDT', 
    ['+1400'] = 'LINT', 
}

---@param time -- time in format of military time 
-- (00:00:00)
-- [[
--     this function basically makes military time
--     easier to read by turning it to a regular
--     time format
-- ]]
local function formatTimeRegular(time) 

    -- [[
    --     this is basically a table that makes it easy
    --     to convert military time numbers to regular time numbers
    -- ]]
    local militaryToRegular = {
        ['00'] = "12",
        ['01'] = "1",
        ['02'] = "2",
        ['03'] = "3",
        ['04'] = "4",
        ['05'] = "5",
        ['06'] = "6",
        ['07'] = "7",
        ['08'] = "8",
        ['09'] = "9",
        ['10'] = "10",
        ['11'] = "11",
        ['12'] = "12",
        ['13'] = "1",
        ['14'] = "2",
        ['15'] = "3",
        ['16'] = "4",
        ['17'] = "5",
        ['18'] = "6",
        ['19'] = "7",
        ['20'] = "8",
        ['21'] = "9",
        ['22'] = "10",
        ['23'] = "11"
    }

    local hour, minute, type = (time:sub(1, 2)), (time:sub(4, 5)), nil 

    if tonumber (hour) > 11 then type = 'PM' end

    if not type then type = 'AM' end  

    hour = militaryToRegular[hour]

    local formatted = ('%s:%s %s'):format (hour, minute, type)

    return formatted
end

---@param source = the players source 
-- returns the players job name
local function getPlayerJob (source) 
    local xPlayer = QBCore.Functions.GetPlayer(source)
    return xPlayer.PlayerData.job.name  
end

---@param source = the players source 
-- returns the players full name
local function getPlayerName (source) 
    local xPlayer = QBCore.Functions.GetPlayer(source)
    return ('%s %s'):format (xPlayer.PlayerData.charinfo.firstname, xPlayer.PlayerData.charinfo.lastname)
end  

---@param date = the date (os.date())
-- this function filters out all date related text from the date leaving us with just the time text
-- example: [[
--     Sun Jan  1 21:10:10 2024 => 21:10:10
-- ]]
-- side note: there are 2 spaces between the month and the day incase you missed it
local function filterTimeFromDate (date) 
    time = date:sub(12, 19)
    return time  
end

---@param clockin = the time the player clocked in (or loaded in if defaultduty = true)
---@param clockout = the time the player clocked out
-- [[
--     this function basically breaks down the clockin and clockout times 
--     and does the math to get the time between clockin and clockout 
--     which tells us how long you were on duty
-- ]]
local function calculateDutyTime (clockin, clockout) 

    -- removing the ":" from the clockin and clockout times
    clockin = clockin:gsub(':', '') 
    clockout = clockout:gsub(':', '') 


    -- basically sepperating hour, minute, and second into their own variables for both clockin and clockout times
    local clockin_hr, clockin_min, clockin_sec = tonumber(clockin:sub(1, 2)), tonumber(clockin:sub(3, 4)), tonumber(clockin:sub(5, 6))
    local clockout_hr, clockout_min, clockout_sec = tonumber(clockout:sub(1, 2)), tonumber(clockout:sub(3, 4)), tonumber(clockout:sub(5, 6))

    -- calculating the time difference
    local hour, minute, second = (clockin_hr - clockout_hr), (clockin_min - clockout_min), (clockin_sec - clockout_sec)

    -- store each calculated number in a table so we can loop through it and make changes
    local calculatedTime = { hour, minute, second }

--    [[
--     converting each number to a string and making sure that 
--     the size of each string is atleast 2 number characters so output can look like: 00:00:00
--     not 00:00:0 and removing any minus "-" symbols incase the number was a negative
--     before being converted to a string.
--    ]]
    for i = 1, #calculatedTime do  
        calculatedTime[i] = tostring(calculatedTime[i])

        if calculatedTime[i]:find('-') then  
            calculatedTime[i] = calculatedTime[i]:gsub('-', "")
        end

        if calculatedTime[i]:len() < 2 then 
            calculatedTime[i] = ('0%s'):format(calculatedTime[i])
        end

    end

    -- format the strings together with the ":" so it looks like: 00:00:00 or similar
    local dutyTime = ('%s:%s:%s'):format (calculatedTime[1], calculatedTime[2], calculatedTime[3])

    return dutyTime 
end


---@param source = the players source
-- [[
--     function used to start monitoring the player
--     by storing them into the storedClockins table 
--     with their source as the key in string format and
--     the value being the date/time that they clocked in
--     with os.date()
-- ]]
function monitor:new (source) 

    -- [[
    --     check to see if we already have the players clockin date/time
    --     stored, just incase something goes wrong we dont want to
    --     overwrite their clockin time which will lead to 
    --     miscalculated duty time later.
    -- ]]
    if self.storedClockins [tostring(source)] then return end  

    -- [[
    --     store the players source in the storedClocks table
    --     as the key in string format with their date/time of clockin
    --     being the value
    -- ]]
    self.storedClockins [tostring(source)] = os.date()

end

---@param source = the players source
---@param job = the players job name
-- [[
--     this is where we log players clockin, clockout,
--     and duty times via discord.
-- ]]
function monitor:log (source, job) 

    -- get the stored date/time of their clockin
    local clockin_time = self.storedClockins [tostring(source)]

    -- instantly clear their storedClockin data so we can began storing newer clockin dater later (if prompted to do so)
    self.storedClockins [tostring(source)] = nil 

    -- get the current date/time (the time they clocked out)
    local clockout_time = os.date()

    -- get the players name 
    local name = getPlayerName(source)

    -- calculate the time they were on duty
    local dutyTime = calculateDutyTime ( filterTimeFromDate (clockin_time), filterTimeFromDate (clockout_time) )

    -- make the time easier to read by converting it to regular time instead of it being in military time 
    local format_clockin, format_clockout = formatTimeRegular (filterTimeFromDate (clockin_time)), formatTimeRegular (filterTimeFromDate (clockout_time))
    format_clockin = ('%s at %s'):format (clockin_time:sub(1, 10), format_clockin) 
    format_clockout = ('%s at %s'):format (clockout_time:sub(1, 10), format_clockout) 

    -- customize the look of the discord log and pass the data as a message

    local discordLogData = {

        ---@param username = then name of the bot
        ---@param avatar_url = link to image for the bots profile picture
        ---@param embeds = basically data for the design of the message container and the content itself 
        -- embeds ref: https://discord.com/developers/docs/resources/channel#embed-object

        username = 'Auto Clockin Timer', 
        avatar_url = 'https://avatars.githubusercontent.com/u/130308145?v=4',
        embeds = {
            {
                ["title"] = name, 
                ["color"] = 38656, 
                ["footer"] = {
                    ["text"] = 'This message was auto-generated by the system', 
                },

                ["description"] = ('**Clock In Time:** %s (%s)'..'\n'..'**Clock Out Time:** %s (%s)'..'\n'..'**Time on Duty:** %s'):format (
                    format_clockin, 
                    (Zones[os.date("%z")] or 'UTC'), 
                    format_clockout, 
                    (Zones[os.date("%z")] or 'UTC'), 
                    dutyTime
                )
            }
        }
    }

    -- send the log to the discord, Done!
    PerformHttpRequest(hooks[job], function () end , 'POST', json.encode(discordLogData), { ['Content-Type'] = 'application/json' })
end

---@param source = the players source 
---@param duty = boolean value if the player is toggling on or off duty
-- [[
--     listen for when you change duty, 
--     if your duty is set to false then we log it with the clock times etc. 
--     if set to true then we start monitoring your time on duty
-- ]]
RegisterNetEvent('QBCore:Server:SetDuty', function(source, duty) 

    -- get the players job
    local job = getPlayerJob (source)


    -- [[
    --     check to see if their job is in the config for logging to webhook
    --     if not then stop execution
    -- ]]
    if not hooks[job] then return end   

    -- if they are going on duty then begin monitoring their duty time
    if duty then monitor:new (source) return end  

    -- if they are going off duty then log it and their duty time
    monitor:log (source, job)
end)

---@param player = basically the player object itself.
-- [[
--     listen for when player loads to check to see if they are on defaultduty 
--     and if so we start monitoring their duty time
-- ]]
RegisterNetEvent('QBCore:Server:PlayerLoaded', function(player) 
    -- wait a little to make sure the players data is initiliazed
    Citizen.Wait(2500)
    
    -- [[
    --     check to see if their job is in the config for logging to webhook
    --     if not then stop execution
    -- ]]
    if not hooks[player.PlayerData.job.name] then return end 

    -- [[
    --     check to see if they have default duty for their job 
    --     if not then stop execution
    -- ]]
    if not player.PlayerData.job.onduty then return end  

    -- if they have default duty then start monitoring their duty time
    monitor:new (player.PlayerData.source)
end)


-- [[
--     listen for when a player disconnects,
--     if they were being monitored then we log
--     their duty time as they are no longer in the server
-- ]]
AddEventHandler('playerDropped', function()
    if monitor.storedClockins [tostring(source)] then  
        monitor:log(source, getPlayerJob (source))
    end
end)