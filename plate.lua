-- ------------------
-- plate functions
-- ------------------

plate = {
	menuItem = nil,
	trash = false,
	onServingCounter = false,
	act_x = 0, 
	act_y = 0,
	grid_x = 0,
	grid_y = 0,
	color = {50,50,50,255},
	width = 35,
	height = 35,
	speed = 1,
	percentLeft = 100   
}

function plate:visible()
	return menuItem ~= nil or trash
end

function plate:checkClick(x,y)
	if self.onServingCounter then
		if checkClick(x,y,self.act_x,self.act_y,self.width, self.height) then
			print("cooked food clicked on")
			if self.onServingCounter then
				newServerAction(self.act_x - 20, self.act_y + 20, takePlate, self, "pick up order")
			end    
		end
	end
end

function plate:draw(x,y)
	if x ~= nil then
		self.act_x = x 
		self.act_y = y
	end
	if self.menuItem ~= nil then
		love.graphics.setColor(self.color)
		love.graphics.rectangle("fill",self.act_x,self.act_y,self.width,self.height)
		love.graphics.setColor(self.menuItem.color)
		love.graphics.rectangle("fill",self.act_x+5,self.act_y+5,self.width-10,(self.height-10) * (self.percentLeft / 100))        
	else 
		if self.trash then
			love.graphics.setColor(self.color)
			love.graphics.rectangle("fill",self.act_x,self.act_y,self.width,self.height)
			love.graphics.setColor({0,0,0,255})
			love.graphics.line(self.act_x,self.act_y,self.act_x + self.width,self.act_y + self.height)
		end
	end
end

function plate:updateOnCounter(dt)
	self.act_y = self.act_y - ((self.act_y - self.grid_y) * self.speed * dt)
	self.act_x = self.act_x - ((self.act_x - self.grid_x) * self.speed * dt)
end

function plate:drawOnCounter()
	if self.menuItem ~= nil then
		love.graphics.setColor(self.color)
		love.graphics.rectangle("fill",self.act_x,self.act_y,self.width,self.height)
		love.graphics.setColor(self.menuItem.color)
		love.graphics.rectangle("fill",self.act_x+5,self.act_y+5,self.width-10,(self.height-10) * (self.percentLeft / 100))        
	end
end


