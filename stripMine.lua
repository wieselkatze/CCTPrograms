-- Variables --
local tProgram		=	{
    availableSlots		=	16,
    fuelLevel			=	512,
    invCheckInterval	=	10,

    placeChests			=	false,

    platformWhitelist	=	{
        [ "minecraft:cobblestone" ] = true,
        [ "minecraft:stone" ]       = true,
        [ "minecraft:dirt" ]        = true,
        [ "minecraft:granite" ]     = true,
        [ "minecraft:diorite" ]     = true,
        [ "minecraft:andesite" ]    = true,
    }
}

local tChestStrings = {
    "minecraft:chest",
    "minecraft:trapped_chest",
    "minecraft:barrel",
    "ironchest:.-_chest"
}

local tDrawerStrings = {
    "_drawers_[124]"
}

local tShulkerStrings = {
    "shulker_box",
    "immersiveengineering:.*crate",
    "dimstorage:dimensional_chest"
}

local tTorchStrings = {
    "minecraft:torch"
}

local sDrawerName
local sShulkerName

local tSlot			=	{
    chest		=	15,
    torch		=	16,
    drawer		=	15,
    shulker		=	14
}

local tSlotStringMapping = {
    chest       =   tChestStrings,
    torch       =   tTorchStrings,
    drawer      =   tDrawerStrings,
    shulker     =   tShulkerStrings
}

local tDrawerContent	=	{
    [ "minecraft:cobblestone" ] =	true,
    [ "minecraft:diorite" ]     =	true,
    [ "minecraft:andesite" ]    =	true,
    [ "minecraft:gravel" ]      =	true,
    --[ "minecraft:granite" ]       =	true
}

-- Restocking drawers or shulker boxes does not make sense as they will not stack
local tValidRestocks = {
    chest   =   true,
    torch   =   true
}

local tArgs			=	{ ... }

local xSize, ySize = term.getSize()
local nXSpace = xSize - 7
local nInitialCursorX, nInitialCursorY = term.getCursorPos()

local tInspectMapping = {
    up      = "inspectUp",
    down    = "inspectDown",
    forward = "inspect"
}
-- Variables --


-- Functions --
local function containsName( sName, tMatchList )
    for k, v in pairs(tMatchList) do
        if sName:match(v) then
            return true
        end
    end

    return false
end

local function dig( sDirection )
    --[[
    sDirection	-	Direction in which to dig, possible directions:
    forward, up, down
    ]]

    local bIsBlock, tBlock = turtle[ tInspectMapping[ sDirection ] ]()

    if not bIsBlock then
        return false
    end

    while sDirection == "up" and turtle.detectUp() or
        sDirection == "down" and turtle.detectDown() or
        sDirection == "forward" and turtle.detect() do

        if sDirection == "up" then
            turtle.digUp()
        elseif sDirection == "down" then
            turtle.digDown()
        elseif sDirection == "forward" then
            turtle.dig()
        end

        if tBlock.name == "minecraft:gravel" or tBlock.name == "minecraft:sand" then
            sleep( 0.25 )
        end
    end

    return true
end

local function userInput( sMessage )
    local nXSize, nYSize = term.getSize()
    local tEvent

    term.setCursorPos( 1, nYSize )
    term.write( sMessage .. " - RSHIFT to continue " )

    while true do
        tEvent = { os.pullEvent() }

        if tEvent[1] == "key" and tEvent[2] == 344 then
            break
        end
    end

    term.clearLine()
end

local function printProgress( nCurrentBlock )
    term.setCursorPos( 1, ySize )

    local str = "Block " .. nCurrentBlock .. " out of " .. tArgs.length

    term.write( str )
end

local function refuel( nFuelLevel )
    local nSelectedSlot = turtle.getSelectedSlot()
    nFuelLevel = nFuelLevel or 1

    while turtle.getFuelLevel() < nFuelLevel do
        for i = 1, 16 do
            local bSlotForbidden = false

            for _, v in pairs( tSlot ) do
                if i == v then
                    bSlotForbidden = true
                    break
                end
            end

            if not bSlotForbidden then
                turtle.select( i )

                while turtle.refuel( 1 ) and turtle.getFuelLevel() < nFuelLevel do
                    sleep( 0 ) -- Yield
                end
            end
        end

        if turtle.getFuelLevel() < nFuelLevel then
            userInput( "No fuel" )
        else
            break
        end
    end

    turtle.select( nSelectedSlot )
end

local function move( sDirection )
    --[[
    Move in direction <sDirection> and destroy blocks in the way.
    If there is any other obstruction, the turtle will wait until it goes away.

    sDirection - Direction in which to move, possible directions:
                 forward, up, down, back
    ]]

    if sDirection == "left" then
        turtle.turnLeft()
        return
    elseif sDirection == "right" then
        turtle.turnRight()
        return
    end

    if turtle.getFuelLevel() < 1 then
        refuel( tProgram.fuelLevel )
    end

    while not turtle[ sDirection ]() do
        if sDirection == "back" or not dig( sDirection ) then
            if sDirection == "forward" and not turtle.attack() or
               sDirection == "down" and not turtle.attackDown() or
               sDirection == "up" and not turtle.attackUp() then
                sleep( 1 )
            end
        end
    end
end

local function placePlatform()
    if turtle.detectDown() then
        return
    end

    local tCurrentItem

    for i = 1, 16 do
        tCurrentItem = turtle.getItemDetail( i )

        if tCurrentItem and tProgram.platformWhitelist[ tCurrentItem.name ] then
            if i ~= turtle.getSelectedSlot() then
                turtle.select( i )
            end

            break
        end
    end

    turtle.placeDown()
end

local function compressStacks()
    local bSlotForbidden -- True if the slot is otherwise used (chest, torch, etc.)
    local bSlotSelected -- True if slot from which items are transferred away is selected
    local nTransferToIndex = 1
    local vItemDetailFrom, vItemDetailTo

    for i = 2, 16 do
        for k, v in pairs( tSlot ) do
            if i == v then
                bSlotForbidden = true
                break
            end
        end

        if not bSlotForbidden then
            vItemDetailFrom = turtle.getItemDetail( i )

            while turtle.getItemCount( i ) > 0 do
                -- We've reached the slot from which we're trying to transfer from
                if nTransferToIndex == i then
                    break
                end

                vItemDetailTo = turtle.getItemDetail( nTransferToIndex )

                -- Only if the slot is empty or the item type is the same, bother checking
                if not vItemDetailTo or vItemDetailFrom.name == vItemDetailTo.name then
                    -- Only select the slot we're transferring *from* if we can actually transfer
                    if not bSlotSelected then
                        turtle.select( i )
                        bSlotSelected = true
                    end

                    turtle.transferTo( nTransferToIndex )
                end

                nTransferToIndex = nTransferToIndex + 1
            end

            bSlotSelected = false
            nTransferToIndex = 1
        end
    end
end

--[[
    Restocks valid items for given slot with given name patterns
]]
local function stock( nSlot, tNames )
    local tItem = turtle.getItemDetail(nSlot)
    local sTargetName = tItem and tItem.name
    local nSelectedSlot = turtle.getSelectedSlot()
    local bRestockedItems = false -- Keeps track if items were actually restocked

    -- A junk item landed in this slot
    if tItem and not containsName(tItem.name, tNames) then
        return false
    end

    for i = 1, 16 do
        if turtle.getItemSpace(nSlot) == 0 then
            break
        end

        if i ~= nSlot then
            tItem = turtle.getItemDetail(i)

            if tItem and containsName(tItem.name, tNames) then
                sTargetName = sTargetName or tItem.name

                if tItem.name == sTargetName then
                    bRestockedItems = true
                    turtle.select(i)
                    turtle.transferTo(nSlot)
                end
            end
        end
    end

    turtle.select(nSelectedSlot)
    return bRestockedItems
end

--[[
    Returns a table of all the items that are in the reserved slots,
    but only if they already correspond to the list of correct items.

    This way placeChest can only keep items that will fit in the slots later and throw
    out other suitable items which would not fit now due to being a different kind
]]
local function getRestockNames()
    local tNames = {}
    local tItem

    for k, v in pairs(tSlot) do
        tItem = turtle.getItemDetail(v)

        if tItem and containsName(tItem.name, tSlotStringMapping[k]) and tValidRestocks[k] then
            tNames[tItem.name] = true
        end
    end

    return tNames
end

--[[
    Finds the item name for restocking slots with the maximum count in the turtle's inventory
]]
local function getMaximumFittingRestock( tNames )
    local tCounts = {}
    local tItem

    for i = 1, 16 do
        tItem = turtle.getItemDetail(i)

        if tItem and containsName(tItem.name, tNames) then
            if tCounts[tItem.name] then
                tCounts[tItem.name] = tCounts[tItem.name] + tItem.count
            else
                tCounts[tItem.name] = tItem.count
            end
        end
    end

    local sMaxItemName = next(tCounts)

    for k, v in pairs(tCounts) do
        if v > tCounts[sMaxItemName] then
            sMaxItemName = k
        end
    end

    return sMaxItemName
end

local function placeChest()
    local bPlaceChest = tArgs.chest and turtle.getItemCount( tSlot.chest ) > 0 and containsName(turtle.getItemDetail(tSlot.chest)["name"], tChestStrings)
    local bPlaceDrawer = tArgs.drawer and turtle.getItemCount( tSlot.drawer ) > 0 and containsName(turtle.getItemDetail(tSlot.drawer)["name"], tDrawerStrings)
    local bPlaceShulker = tArgs.shulker and turtle.getItemCount( tSlot.shulker ) > 0 and containsName(turtle.getItemDetail(tSlot.shulker)["name"], tShulkerStrings)

    if not ( bPlaceChest or bPlaceDrawer or bPlaceShulker ) then
    return false
    end

    local bSlotAvailable = true
    local bSavedJunkItem = false
    local nSelectedSlot = turtle.getSelectedSlot()

    local nItemCount = 0
    local nTargetCount = 0

    if bPlaceChest then
        dig( "down" )
        turtle.select( tSlot.chest )
        turtle.placeDown()
    end

    if bPlaceDrawer then
        turtle.select( tSlot.drawer )
        turtle.placeUp()
    end

    if bPlaceShulker then
        if bPlaceChest or bPlaceDrawer then
            -- Otherwise the item dug out would go in the chest slot
            turtle.select( nSelectedSlot )
        end

        dig( "forward" )
        turtle.select( tSlot.shulker )
        turtle.place()
    end

    local tReservedItems = getRestockNames()

    for i = 1, 16 do
        for k, v in pairs( tSlot ) do
            -- No items are left at all for this restock slot
            if turtle.getItemCount(v) == 0 and tValidRestocks[k] then
                local sMaxItemName = getMaximumFittingRestock(tSlotStringMapping[k])

                if sMaxItemName then
                    tReservedItems[sMaxItemName] = true
                end
            end

            if tArgs.keepRestocks or i == v then
                local tItem = turtle.getItemDetail(i)

                bSlotAvailable = not (tItem and tReservedItems[tItem.name])

                if not bSlotAvailable then
                    break
                end
            end
        end

        if bSlotAvailable then
            nItemCount = turtle.getItemCount( i )

            -- Save some items for building bridges in lava lakes etc.
            if not bSavedJunkItem then
                if nItemCount > 0 and tProgram.platformWhitelist[ turtle.getItemDetail( i )["name"] ] then
                    nTargetCount = math.min( 16, nItemCount )
                    bSavedJunkItem = true
                end

            else
                nTargetCount = 0
            end

            -- Only bother selecting slots when there are items (selecting is slow)
            if nItemCount > 0 then
                turtle.select( i )
            end

            if nItemCount > nTargetCount and bPlaceDrawer and tDrawerContent[ turtle.getItemDetail( i )["name"] ] then
                turtle.dropUp( nItemCount - nTargetCount )

                nItemCount = turtle.getItemCount() -- Maybe not all items could fit
            end

            if nItemCount > nTargetCount and bPlaceChest then
                turtle.dropDown( nItemCount - nTargetCount )

                nItemCount = turtle.getItemCount() -- Maybe still some items left
            end

            if nItemCount > nTargetCount and bPlaceShulker then
                turtle.drop( nItemCount - nTargetCount )
            end

            if turtle.getItemCount() > nTargetCount then
                -- If we couldn't get rid of this stack at all, try and compress it,
                -- as it may be in a random slot
                bCompressStacks = true
            end
        end

        bSlotAvailable = true
    end

    if bPlaceShulker then
        turtle.select( tSlot.shulker )

        if turtle.getItemCount() > 0 then
            -- Maybe inventory was full and an item landed here anyway
            turtle.dropDown()
        end

        turtle.dig()
    end

    if bPlaceDrawer then
        turtle.select( tSlot.drawer )

        if turtle.getItemCount() > 0 then
            -- Maybe inventory was full and an item landed here anyway
            turtle.dropDown()
        end

        turtle.digUp()
    end

    compressStacks()

    turtle.select( nSelectedSlot )
end

local function checkInventory( bPlacedChest )
    local function getBlockedSlots()
        local nBlockedSlots = 0
        local bSlotIgnore = false

        for i = 1, 16 do
            for k, v in pairs( tSlot ) do
                if i == v then
                    bSlotIgnore = true
                    break
                end
            end

            if not bSlotIgnore and turtle.getItemCount( i ) > 0 then
                nBlockedSlots = nBlockedSlots + 1
            end

            bSlotIgnore = false
        end

        return nBlockedSlots
    end

    -- Only bother restocking if inventory is completely full
    -- as restocking is slow
    if getBlockedSlots() == tProgram.availableSlots then
        for k, v in pairs(tSlot) do
            stock(v, tSlotStringMapping[k])
        end
    else
        return
    end

    if getBlockedSlots() == tProgram.availableSlots then
        if ( not tArgs.chest and not tArgs.drawer and not tArgs.shulker ) or bPlacedChest then
            userInput( "Inventory full" )
            return
        end

        placeChest()
        checkInventory( true )
    end
end

local function placeTorch()
	local item = turtle.getItemDetail(tSlot.torch)

	while not item and not stock(tSlot.torch, tTorchStrings) do
        if tArgs.stopNoTorches then
            userInput("No torches left")
            item = turtle.getItemDetail(tSlot.torch)
        else
            return false
        end
	end

    local nSelectedSlot

    nSelectedSlot = turtle.getSelectedSlot()
    turtle.select( tSlot.torch )
    move( "up" )
    turtle.placeDown()
    turtle.select( nSelectedSlot )
    move( "forward" )
    move( "down" )

    return true
end

local function parseArgs( tArgs )
    local tParsedArgs = {}
    local sArgName
    local vArgValue

    for i = 1, #tArgs do
        sArgName = tArgs[i]:match( "[%w_]+" )
        vArgValue = tArgs[i]:match( "[%w_]+%s*=%s*([%w_]+)" )

        if vArgValue then
            if vArgValue == "true" then
                vArgValue = true
            elseif vArgValue == "false" then
                vArgValue = false
            elseif tonumber( vArgValue ) then
                vArgValue = tonumber( vArgValue )
            end

            tParsedArgs[ sArgName ] = vArgValue
        else
            tParsedArgs[ sArgName ] = true
        end
    end

    return tParsedArgs
end

local function printUsage()
    print("Usage: " .. shell.getRunningProgram() .. " length=<length> [options]")
    print("Type: \"" .. shell.getRunningProgram() .. " help\" for a list of options")
end

local function printHelp()
    textutils.pagedPrint( [=[
Valid arguments:

[placeTorches[=false]]:
Place torches or not, default is true

[torchSpacing=<spacing>]
Sets the torch spacing to <spacing> being > 0

[stopNoTorches[=false]]:
Lets the turtle stop if no torches are present, default is true

[keepRestocks[=false]]:
Keeps items that can restock reserved slots, default is true

[emptyAtEnd[=false]]:
Empty the inventory at end of mining, default is true

[chest[=true]]:
Places chest in floor whenever the inventory is full

[drawer[=true]]:
Places a drawer and empties junk items into it

[shulker[=true]]:
Places a shulker and empties items into it whenever inventory is full. Shulker box is picked up again afterwards

[placePlatform[=false]]:
Places blocks whenever there is no solid block below, default is true]=] )
end
-- Functions --


-- Initialisation --
tArgs = parseArgs(tArgs)

if tArgs.help == true then
    printHelp()
    return
end

if type(tArgs.length) ~= "number" then
    printUsage()
    error( "No length given" )
end

if tArgs.chest and tArgs.shulker then
    error( "Chest and Shulker options are mutually exclusive!" )
end

-- Only false if specified to be false
tArgs.placeTorches = tArgs.placeTorches ~= false

tArgs.stopNoTorches = tArgs.stopNoTorches ~= false

tArgs.placePlatform = tArgs.placePlatform ~= false

tArgs.emptyAtEnd = tArgs.emptyAtEnd ~= false

tArgs.keepRestocks = tArgs.keepRestocks ~= false

if tArgs.chest ~= true then
    tSlot.chest = nil
end

if tArgs.drawer ~= true then
    tSlot.drawer = nil
end

if tArgs.shulker ~= true then
    tSlot.shulker = nil
end

if type( tArgs.torchSpacing ) == "number" then
    tArgs.torchSpacing = tArgs.torchSpacing > 0 and tArgs.torchSpacing or 12
else
    tArgs.torchSpacing = 12 -- 12 is the optimal spacing so the light level is at least 8
end

for k, v in pairs( tSlot ) do
    tProgram.availableSlots = tProgram.availableSlots - 1
end

term.setCursorPos( 1, ySize )
term.clearLine()
-- Initialisation --


-- Main Program --
local bTravelledBlock = false

for i = 1, tArgs.length do
    printProgress( i )

    if tArgs.placeTorches == true and ( i-2 ) % ( tArgs.torchSpacing+1 ) == 0 then
        bTravelledBlock = placeTorch()
    end

    if ( i-2 ) % ( tProgram.invCheckInterval+1 ) == 0 then
        checkInventory()
    end

    if not bTravelledBlock then
        move( "forward" )
        dig( "up" )
    end

    if tArgs.placePlatform == true then
        placePlatform()
    end

    bTravelledBlock = false
end

if tArgs.drawer and tArgs.emptyAtEnd then
    placeChest()
end

-- Clear up the "Block x of y" and make the cursor not be off-screen
term.clearLine()
term.setCursorPos( nInitialCursorX, nInitialCursorY )
-- Main Program --
