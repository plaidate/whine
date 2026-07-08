-- The rain clock and the Garden pond. Weather cycles sun -> clouds -> rain;
-- rain fills the pond (standing water), which then evaporates over PUDDLE_LIFE.
-- The adult can only lay a clutch in the Garden while the pond is wet.

Weather = {}

local function dur(p)
    if p == "sun" then return C.SUN_T
    elseif p == "clouds" then return C.CLOUD_T
    else return C.RAIN_T end
end

function Weather.reset()
    G.weather = { phase = "sun", t = 0 }
    G.pond = { wet = 0 } -- seconds of standing water remaining
end

function Weather.wet() return (G.pond and G.pond.wet or 0) > 0 end

function Weather.update(dt)
    local w = G.weather
    w.t = w.t + dt
    if w.phase == "rain" then
        G.pond.wet = C.PUDDLE_LIFE -- kept topped up while it rains
    else
        G.pond.wet = math.max(0, G.pond.wet - dt)
    end
    if w.t >= dur(w.phase) then
        w.t = 0
        if w.phase == "sun" then
            w.phase = "clouds"
        elseif w.phase == "clouds" then
            w.phase = "rain"
            Sfx.rain()
        else
            w.phase = "sun"
        end
    end
end
