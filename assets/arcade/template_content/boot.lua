--REDIRECTION ARCADE GAME by MICHAL MARŠÁLEK

require "system"
gpu = system.getDevice("gpu")
display = system.getDevice("display")
speaker = system.getDevice("speaker")
gamepad = system.getDevice("gamepad")
math.randomseed(os.time())

states = {a=false, b=false, x=0, y=0, xlen=0, ylen=0, alen=0, blen=0}
menuSel = 0
menuValues = {[0]=10, [1]=9, [2]=20, [3]=0}
sizeX, sizeY = 2, 2
cursorX, cursorY = 0, 0
mapShiftX, mapShiftY = 0, 0
renderSizeX, renderSizeY = 10, 9
minesLeft = 0
cellsLeft = 0
startTime =0
endTime = 0
map = {}
uncovered = {}
marked = {}
levelGenerated = false
menuImage =  gpu.loadTGA( io.open( "menu.tga", "rb" ) )
winnerImage =  gpu.loadTGA( io.open( "winner.tga", "rb" ) )
gameOver = false
win = false

sound2 = {waveform = "square", frequency = 500, duration = 0.1}
sound3 = {waveform = "square", frequency = 800, duration = 0.4}
sound4 = {waveform = "square", frequency = 800, duration = 0.1}
sound5 = {waveform = "square", frequency = 680, duration = 0.1}
sound6 = {waveform = "square", frequency = 540, duration = 0.1}
sound7 = {waveform = "square", frequency = 420, duration = 0.4}
quite = {volume = 0, duration = 0.03, frequency = 15}
		
function setupLevel()
	minesLeft = menuValues[2]
	cursorX, cursorY = 0, 0
	sizeX, sizeY = menuValues[0], menuValues[1]
	cellsLeft = sizeX * sizeY - minesLeft
	startTime = os.time()
	map = {}
    for x = -1, sizeX do
        map[x] = {}
        for y = -1, sizeY do
            map[x][y] = 0
        end
    end
	uncovered = {}
    for x = -1, sizeX do
        uncovered[x] = {}
        for y = -1, sizeY do
            uncovered[x][y] = x == -1 or x == sizeX or y == -1 or y == sizeY
        end
    end	
	marked = {}
    for x = 0, sizeX-1 do
        marked[x] = {}
        for y = 0, sizeY-1 do
            marked[x][y] = false
        end
    end	
	levelGenerated = false
	gameOver = false
	win = false
	mapShiftX, mapShiftY = 0, 0
	cellsUncovered = 0
end

function generateLevel()
	minesToPlace = minesLeft
	cellsToDecide = sizeX*sizeY-9
	for dx = -1, 1 do
		for dy = -1, 1 do
			if uncovered[cursorX+dx][cursorY+dy] then
				cellsToDecide = cellsToDecide+1
			end
		end
	end
	for  x = 0, sizeX-1 do
		for y = 0, sizeY-1 do
			if math.abs(x - cursorX) > 1 or math.abs(y - cursorY) > 1 then
				if math.random(cellsToDecide) <=  minesToPlace then
					map[x][y] = -1
					minesToPlace = minesToPlace - 1
				end
				cellsToDecide = cellsToDecide - 1
			end
		end
	end
	for  x = 0, sizeX-1 do
		for y = 0, sizeY-1 do
			if map[x][y] ~= -1 then
				for sx = x-1, x+1 do
					for sy = y-1, y+1 do
						if (sx ~= x or sy ~= y) and map[sx][sy] == -1 then
							map[x][y] = map[x][y] + 1
						end
					end
				end
			end
		end
	end
	levelGenerated = true
end

function drawLevel()
    gpu.setOffset(0,0)
	gpu.drawBox(0,0,64,9,0)
	gpu.drawText(1, 0, tostring(math.floor(minesLeft)))
	if gameOver then
		if win then
			gpu.drawImage(15, 0, winnerImage)
		else
			gpu.drawText(15, 0, "LOSER")
		end
	end
	gpu.drawText(50, 0, tostring(math.floor(endTime-startTime)))
	
	renderSizeX = math.min(10, sizeX)
	renderSizeY = math.min(9, sizeY)
	drawCells()
	drawEdges()
	
end

function drawEdges()
	gpu.setOffset(0,6)
	if mapShiftY == 0 then
		gpu.drawBox(0, 0, renderSizeX*6+4, 2, 1)
	end
	if mapShiftX == 0 then
		gpu.drawBox(0, 0, 2, renderSizeY*6+4, 1)
	end
	if renderSizeY + mapShiftY == sizeY then
		gpu.drawBox(0, 2+renderSizeY*6, renderSizeX*6+4, 2, 1)
	end
	if renderSizeX + mapShiftX == sizeX then
		gpu.drawBox(2+renderSizeX*6, 0, 2, renderSizeY*6+4, 1)
	end	
end

function drawCells()	
	gpu.setOffset(2,8)
	for x = 0, renderSizeX-1 do
		for y = 0, renderSizeY-1 do
			mx = x+mapShiftX
			my = y+mapShiftY
			t = map[mx][my] ~= 0 and tostring(map[mx][my]) or "-"
			if (mx == cursorX and my == cursorY) and not gameOver then
				gpu.mapColor( 1, 0 )
				gpu.mapColor( 0, 1 )					
			end
			gpu.drawBox(x*6, y*6, 6, 6, 0)
			if marked[mx][my] and not gameOver then
				gpu.drawEllipse(x*6+1, y*6+1, 4, 4, 1)
			end
			if uncovered[mx][my] or gameOver then
				if map[mx][my] == -1 then
					gpu.drawLine(x*6+1, y*6+1, x*6+5, y*6+5, 1)
					gpu.drawLine(x*6+5, y*6+1, x*6+1, y*6+5, 1)
				else
					gpu.drawText(x*6+2, y*6+(map[mx][my] ~= 0 and 1 or 0), t)
				end
			end
			gpu.mapColor( 1, 1 )			
			gpu.mapColor( 0, 0 )
		end
	end
end

function cellClick()
	uncover(cursorX, cursorY)
	if map[cursorX][cursorY] == -1 then
		gameOver = true
		win = false
		speaker.play(sound4, 1)
		speaker.queue(quite, 1)
		speaker.queue(sound5, 1)
		speaker.queue(quite, 1)
		speaker.queue(sound6, 1)
		speaker.queue(quite, 1)
		speaker.queue(sound7, 1)
		return
	end
	if cellsLeft == 0 then
		gameOver = true
		win = true
        speaker.play(sound2, 1)
        speaker.queue(sound3, 1)		
	end
end

function uncover(x, y)
	if not uncovered[x][y] then	
		cellsLeft = cellsLeft - 1		
	end
	if not uncovered[x][y] and map[x][y] == 0 then
		uncovered[x][y] = true
		for dx = -1, 1 do
			for dy = -1, 1 do
				uncover(x+dx, y+dy)
			end
		end
	end
	uncovered[x][y] = true
end

function drawMenu()    
    gpu.setOffset(0,0)
	gpu.drawImage( 0, 0, menuImage )
	for s = 0,2 do
		str = tostring(math.floor(menuValues[s]))
		gpu.drawText(43 - 2*#str, 23 + s*6, str)
		if menuSel ~= s then
			gpu.drawBox(32, 23 + s*6, 3, 5, 0)
			gpu.drawBox(50, 23 + s*6, 3, 5, 0)
		end
	end
	if menuSel ~= 3 then
		gpu.drawBox(19, 51, 3, 5, 0)
		gpu.drawBox(43, 51, 3, 5, 0)
	end
end

function setStates()
	function calcMod(x)
		if x > 250 then return 2 end
		if x > 80 then return 5 end
		if x > 40 then return 10 end
		return 20
	end
	states.xlen = gamepad.getAxis(0) ~= 0 and states.xlen + 1 or 0
	states.ylen = gamepad.getAxis(1) ~= 0 and states.ylen + 1 or 0
	states.x = (states.xlen % calcMod(states.xlen) == 1) and gamepad.getAxis(0) or 0
	states.y = (states.ylen % calcMod(states.ylen) == 1) and gamepad.getAxis(1) or 0
	states.alen = gamepad.getButton(0) and states.alen + 1 or 0
	states.blen = gamepad.getButton(1) and states.blen + 1 or 0
	states.a = states.alen == 1
	states.b = states.blen == 1
end

function main()
    screen = menu
    while true do
        setStates()
        gpu.clear()
        screen()
        system.sleep(0)
    end
end

function menu()
	menuSel = math.fmod(menuSel + states.y+4, 4)
	menuValues[menuSel] = math.max(4, menuValues[menuSel] + states.x)
	if states.a and menuSel == 3 then
		screen = level
		setupLevel()
	end
	menuValues[0] = math.min(menuValues[0], 40)
    menuValues[1] = math.min(menuValues[1], 40)
    menuValues[2] = math.min(menuValues[2], menuValues[0]*menuValues[1]-9)
    drawMenu()
end

function level()
	if not gameOver then
		endTime = os.time()
		cursorX = math.min(math.max(0, cursorX+states.x), sizeX-1)
		cursorY = math.min(math.max(0, cursorY+states.y), sizeY-1)
		if cursorX - mapShiftX < 0 or cursorX - mapShiftX >= renderSizeX then
			mapShiftX = mapShiftX + states.x
		end
		if cursorY - mapShiftY < 0 or cursorY - mapShiftY >= renderSizeY then
			mapShiftY = mapShiftY + states.y
		end
		if states.a then
			if not levelGenerated then
				generateLevel()
			end
			if not marked[cursorX][cursorY] then
				cellClick()
			end
		end
		if states.b and levelGenerated then
			if marked[cursorX][cursorY] then
				marked[cursorX][cursorY] = false
				minesLeft = minesLeft + 1
			elseif not uncovered[cursorX][cursorY] then
				marked[cursorX][cursorY] = true
				minesLeft = minesLeft - 1
			end
		end
		if states.blen >= 50 then
			screen = menu
		end
	else
		if states.b then
			screen = menu
		end
		newShiftX = mapShiftX + states.x
		newShiftY = mapShiftY + states.y
		if newShiftX >= 0 and newShiftY >= 0 and newShiftX + renderSizeX <= sizeX and newShiftY + renderSizeY <= sizeY then
			mapShiftX = newShiftX
			mapShiftY = newShiftY
		end
	end
    drawLevel()
end

main()