-- global definitions

dinnerTableCount = 4
maxCustomerCount = dinnerTableCount + 4
plateCount = dinnerTableCount + maxCustomerCount

require "menu"
require "dinnerTable"
require "kitchen"
require "customer"
require "utils"
require "plate"
require "seatingQueue"
require "server"

kitchenTable = {}
dish = {}
trash = {}
bussStation = {}
selectedCustomer = nil
serverQueue = nil
kitchenQueue = nil
servingCounter = nil
plateQueue = nil
revenue = 0
openDuration = 90
numTablesWithPlates = 0

timer = 10 -- 120
wallTime = 0.0

-- patience functions (tweakable by restaurant modifications, later on)
waitInLineImpatience = 1
waitToOrderImpatience = 2
waitForFoodImpatience = 3

-- game modes: 
-- 1: top-level menu
-- 2: instructions
-- 3: options?
-- 4: store
-- 5: gameplay

mode = 1

-- ------------------
-- menu functions
-- ------------------

menuItems = {
    [1] = { color = {20, 250, 40,255}, name = "Spinach souffle", cost = 5, time = 5},
    [2] = { color = {200, 250, 40,255}, name = "Mac & cheese", cost = 2, time = 2},
    [3] = { color = {20, 40, 255,255}, name = "Salmon sashimi", cost = 10, time = 7},
    [4] = { color = {80, 250, 250,255}, name = "Edamami", cost = 1, time = 2}   
}

-- if chefs become objects, we'll need to do things much closer to how servers work here...
function yellOrderToKitchen(menuItem,x,y)
    kitchenQueue:enqueue(menuItem)
    createEvent(menuItem.time, "done cooking", orderUp, menuItem)
end


function timePasses()
    print(".")
    createEvent(1, "time passes", timePasses, nil)
    print("#outside: " .. outsideQueue:size() .. ", tables with plates " .. numTablesWithPlates)

    if timer > 0 then
        if math.random() > 0.75 then
            enterCustomer()
        end
    else -- check to see whether this round is over
        if outsideQueue:size() == maxCustomerCount then
            if numTablesWithPlates == 0 then
                mode = 1 -- TODO
            end
        end
    end
end

-- ------------------
-- outside queue functions
-- ------------------

function enterCustomer()
    print("ding, ding")
    newCust = outsideQueue:dequeue()
    if newCust ~= nil then
        newCust.happiness = 100
        newCust.state = "line"
        addToSeatingQueue(newCust, seatingQueue)
    end
end

-- ------------------
-- initialization
-- ------------------

function love.load()
    customers = { }
    tables = { }
    drawables = { }
    updatables = { server }
    clickables = { }
    timedEvents = { }
    seatingQueue = newQueue()
    outsideQueue = newQueue()
    serverQueue = newQueue()
    kitchenQueue = newQueue()
    servingCounter = newQueue()
    plateQueue = newQueue()
    
    timer = 10 -- 120
    wallTime = 0.0
    revenue = 0

    local i = 0
    local newCust = nil

    table.insert(drawables, kitchen)

    for i = 1, dinnerTableCount do 
        newTable = newDinnerTable(i)
        table.insert(tables, newTable)
        table.insert(drawables, newTable)
        table.insert(clickables, newTable)
    end
    for i = 1, maxCustomerCount do 
        newCust = newCustomer(i) 
        table.insert(customers, newCust)
        table.insert(drawables, newCust)
        table.insert(clickables, newCust)
        table.insert(updatables, newCust)
        outsideQueue:enqueue(newCust)
        print("customer " .. i .. " has entered the game")
    end
    
    for i = 0, plateCount do
        newPlate = table.copy(plate)
        table.insert(drawables, newPlate)
        table.insert(clickables, newPlate)
        -- table.insert(updatables, newPlate)
        plateQueue:enqueue(newPlate)
    end
    enterCustomer()
    createEvent(2, "bootstrap time", timePasses, nil)
    table.insert(drawables, server)
    table.insert(drawables, seatingQueueClickBox) -- for debugging
    table.insert(clickables, seatingQueueClickBox)
    table.insert(updatables, kitchen) -- used to update plate positions (conveyer belt?)
    
    menu:initialize()
    print("done loading ")
end

function love.update(dt)
    if mode == 1 then
        menu:update(dt)
    else 
        if mode == 5 then
            wallTime = wallTime + dt
            while (peekEventTime() < wallTime) do
                event = table.remove(timedEvents, 1)
                print("processing " .. event.event)
                event.eventFunc(event.eventArg)
            end
            local i = 0
            for i in values(updatables) do 
                i:update(dt)
            end
            timer = timer - dt
        end
    end
end

function values(t)
    local i = 0
    return function() i = i + 1; return t[i] end
end

function love.draw()
    if mode == 1 then
        menu:draw()
    else 
        if mode == 5 then
            love.graphics.setColor(255,255,255)
            rev = string.format("%.2f", revenue)
            love.graphics.print("Earnings: $" .. rev .. "    Time left: " .. math.floor(timer), 500, 0)
            for i in values(drawables) do 
                i:draw()
            end
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        mode = 1
        print ("mode ".. mode)
    else
        print (key)
    end
end

function love.mousepressed(x, y, button)
   if button == 'lshift' then
        print ("x: ".. x .. ", y:" .. y)
   end
   if mode == 5 then
       if button == 'l' then
           for i in values(clickables) do 
               i:checkClick(x,y)
           end
       end
    else
        if mode == 1 then
            menu:mousePressed(x,y,button)
        end
    end
end

