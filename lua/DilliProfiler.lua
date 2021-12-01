--Thanks to Softles for letting me use the DilliDalli profiler to help with optimisation
local CreatePriorityQueue = import('/mods/M27AI/lua/DilliPriorityQueue.lua').CreatePriorityQueue

Profiler = Class({
    Init = function(self)
        self.Trash = TrashBag()
        self.last = 0
        self.times = {}
        self.period = 5 -- How many seconds to wait before logging again
        self.adjust = 1/self.period
    end,

    Now = function(self)
        return GetSystemTimeSecondsOnlyForProfileUse()
    end,

    Add = function(self,key,amount)
        LOG('PROFILER ADD FUNCTION')
        if self.times[key] then
            self.times[key] = self.times[key] + amount
        else
            self.times[key] = amount
        end
    end,

    LogOut = function(self)
        local pq = CreatePriorityQueue()
        for k, v in self.times do
            pq:Queue({k = k, priority = -v})
        end
        local s = ""
        if self.last then
            local timePerGameSecond = self.adjust*(GetSystemTimeSecondsOnlyForProfileUse()-self.last)
            s = "Time per game second:"..string.format("%.2f",timePerGameSecond).."s, Top Costs: "
            local i = 0
            while (i < 5) and (pq:Size() > 0) do
                i = i+1
                local item = pq:Dequeue()
                -- Logs Percent Total Time
                s = s..item.k.."-"..string.format("%.2f",100*self.adjust*(-item.priority)/timePerGameSecond).."%, "
            end
            LOG(s)
        end
        self.last = GetSystemTimeSecondsOnlyForProfileUse()
        self.times = {}
    end,

    MonitorThread = function(self)
        while true do
            self:LogOut()
            WaitSeconds(self.period)
        end
    end,

    Run = function(self)
        self:ForkThread(self.MonitorThread)
    end,

    ForkThread = function(self, fn, ...)
        if fn then
            local thread = ForkThread(fn, self, unpack(arg))
            self.Trash:Add(thread)
            return thread
        else
            return nil
        end
    end,
})

ProdProfiler = Class({
    Now = function(self)
        return 0
    end,
    Add = function(self,k,v)
    end,
})

function CreateProfiler()
    local dev = false
    if dev then
        local p = Profiler()
        p:Init()
        p:Run()
        return p
    else
        return ProdProfiler()
    end
end

local profiler = CreateProfiler()

function GetProfiler()
    LOG('GetProfiler called')
    return profiler
end