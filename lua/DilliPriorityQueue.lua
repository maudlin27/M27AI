--With thanks to Softles for letting me use the DilliDalli profiler
PriorityQueue = Class({
    Init = function(self)
        self.items = {}
        self.size = 0
        -- true => largest first, false => smallest first
        self.rev = false
    end,

    Queue = function(self,item)
        self.size = self.size + 1
        table.insert(self.items,self.size,item)
        self:HeapUp()
        return self.size
    end,

    Dequeue = function(self)
        if self.size == 0 then
            return nil
        end
        local item = self.items[1]
        self.items[1] = self.items[self.size]
        self.size = self.size - 1
        -- Removes last item
        table.remove(self.items)
        self:HeapDown()
        return item
    end,

    HeapUp = function(self)
        -- item at self.size needs to be shuffled into the correct place
        local index = self.size
        while index > 1 do
            local parentIndex = math.floor(index/2)
            -- Support smallest first or largest first
            if ((not self.rev) and self.items[index].priority < self.items[parentIndex].priority)
                    or (self.rev and self.items[index].priority > self.items[parentIndex].priority) then
                local t = self.items[index]
                self.items[index] = self.items[parentIndex]
                self.items[parentIndex] = t
                index = parentIndex
            else
                index = 1
            end
        end
    end,

    HeapDown = function(self)
        -- item at 1 needs to be shuffled into the correct place
        local index = 1
        while (2*index) <= self.size do
            local child1Index = 2*index
            local child2Index = 2*index+1
            local c1Swap = ((not self.rev) and self.items[index].priority > self.items[child1Index].priority)
                    or (self.rev and self.items[index].priority < self.items[child1Index].priority)
            local c2Swap = false
            if child2Index <= self.size then
                c2Swap = ((not self.rev) and (self.items[index].priority > self.items[child2Index].priority))
                        or (self.rev and (self.items[index].priority < self.items[child2Index].priority))
            end
            if c1Swap and c2Swap then
                c1Swap = ((not self.rev) and (self.items[child1Index].priority <= self.items[child2Index].priority))
                        or (self.rev and (self.items[child1Index].priority >= self.items[child2Index].priority))
            end
            if c1Swap then
                local t = self.items[child1Index]
                self.items[child1Index] = self.items[index]
                self.items[index] = t
                index = child1Index
            elseif c2Swap then
                local t = self.items[child2Index]
                self.items[child2Index] = self.items[index]
                self.items[index] = t
                index = child2Index
            else
                index = self.size
            end
        end
    end,

    Size = function(self)
        return self.size
    end,

    Remove = function(self)
        self.size = self.size - 1
        table.remove(self.items)
        return self.size
    end
})

function CreatePriorityQueue()
    local pq = PriorityQueue()
    pq:Init()
    return pq
end

function SortTable(tbl)
    -- sort a table smallest to largest.  Do this by abusing my knowledge of the PriorityQueue class internals.
    local pq = PriorityQueue()
    local n = table.getn(tbl)
    pq.items = tbl
    pq.rev = true
    for i=1,n do
        pq.size = i
        pq:HeapUp()
    end
    -- Usually comments provide helpful context to code, but here I just wanted to express my deep satisfaction with the heapsort algorithm.
    for i=n,1,-1 do
        local t = pq.items[1]
        pq.items[1] = pq.items[n]
        pq.items[n] = t
        pq.size = n-1
        pq:HeapDown()
    end
end
