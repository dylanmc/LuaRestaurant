-- utility functions (Lua's a very "roll your own" language)
function checkClick(x,y,objX,objY,objWidth,objHeight)
	if x >= objX then
		if y >= objY then
			if x <= objX + objWidth then
				if y <= objY + objHeight then
					return true
				end
			end
		end
	end
	return false
end

--  rolling my own prototype-based object system
function table.copy(t, deep, seen)
	seen = seen or {}
	if t == nil then return nil end
	if seen[t] then return seen[t] end

	local nt = {}
	for k, v in pairs(t) do
		if deep and type(v) == 'table' then
			nt[k] = table.copy(v, deep, seen)
		else
			nt[k] = v
		end
	end
	setmetatable(nt, table.copy(getmetatable(t), deep, seen))
	seen[t] = nt
	return nt
end

-- queue functions
queue = {
	myCount = 0,
	elements = {}
}

function newQueue()
	nq = table.copy(queue, true)
	return nq
end

function queue:enqueue(obj)
	table.insert(self.elements, obj)
	self.myCount = self.myCount + 1
	-- print ("enqueue - count " .. self.myCount)
end

function queue:dequeue()
	ret = table.remove(self.elements,1)
	self.myCount = self.myCount - 1
	-- print ("dequeue - count " .. self.myCount)
	return ret
end

function queue:peekAtFirst()
	return self.elements[1]
end

function queue:find(elt)
	posn = 1
	for val in values(self.elements) do
		if val == elt then 
			return posn
		end
	end
	return -1
end

function queue:size()
	return self.myCount
end

function queue:removeElement(elt)
	posn = self:find(elt)
	if posn >= 0 then
		table.remove(self.elements, posn)
		self.myCount = self.myCount - 1
		return true
	end
	return false
end
-- event queue functions - these are the time-based events
timedEvents = {}

timeEvent = {
	time = nil, -- the time to do the event
	event = nil, -- a string describing the event
	eventFunc = nil, -- the function to call in order to perform the event
	eventArg = nil -- the argument to the event function    
}

function createEvent(fromNow, name, func, arg) 
	if func == nil then
		print ("BLURG")
		error ("blug")
	end
	ret = table.copy(timeEvent)
	ret.time = wallTime + fromNow
	ret.event = name
	ret.eventFunc = func
	ret.eventArg = arg
	table.insert(timedEvents,ret)
	table.sort(timedEvents,
		function (A,B)
			return A.time < B.time
		end)
end

function peekEventTime()
	if timedEvents[1] ~= nil then
		return timedEvents[1].time
	else
		return math.huge
	end
end
