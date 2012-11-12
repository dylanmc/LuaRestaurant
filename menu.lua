-- menu functions

menu_initialized = false

menu = {	
	drawables = {},
	clickables = {},
	updatables = {}
}

function menu:initialize()
	if menu_initialized ~= true then
		createButtons()
		menu_initialized = true
	end
end

function menu:update(dt)
	local i = 0
	for i in values(menu.updatables) do 
		i:update(dt)
	end
end

function menu:draw()
	local i = 0
	for i in values(menu.drawables) do 
		i:draw()
	end
end

function menu:mousePressed(x,y,button)
	if button == 'l' then
		for i in values(menu.clickables) do 
			i:checkClick(x,y)
		end
	end
end

function newGameAction()
	-- todo: re-init everything
	love.load()
	mode = 5
end

function resumeAction()
	mode = 5
end

function quitAction ()
	os.exit()
end

function createButtons ()
	newButton("New Game",newGameAction)
	newButton("Resume", resumeAction)
	newButton("Instructions", instructionsAction)
	newButton("Quit", quitAction)
end

buttonYPos = 200
buttonHeight = 30
buttonXPos = 200

function newButton(label, action)
	nb = table.copy(button)
	nb.text = label
	nb.y = buttonYPos
	buttonYPos = buttonYPos + buttonHeight
	nb.x = buttonXPos
	nb.action = action
	table.insert(menu.drawables, nb)
	table.insert(menu.clickables, nb)
end

button = {
	x = 0,
	y = 0,
	width = 0,
	height = 0,
	text = "",
	action = nil
}

function button:draw ()
	love.graphics.print(self.text,self.x, self.y)
end

function button:checkClick(x,y)
	if checkClick(x,y,self.x, self.y, 200, buttonHeight) then
		print("button " .. self.text)
		if self.action ~= nil then
			self.action()
		end
	end
end
