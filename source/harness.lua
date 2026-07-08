-- Smoke-test harness. The Makefile stages smokeflag.lua: SMOKE_BUILD false
-- for release (no-op), true for `make smoke` (pcall-wrapped update writing
-- errors to "err", a 90-frame heartbeat to "smoke", periodic screenshots,
-- and an autopilot the input module consults).

import "smokeflag"

Harness = {
    enabled = SMOKE_BUILD,
    counters = {},
    autopilot = nil,
    extra = nil,
    shotPath = nil,
}

function Harness.count(key, n)
    if not Harness.enabled then return end
    Harness.counters[key] = (Harness.counters[key] or 0) + (n or 1)
end

function Harness.frame(frame, updateFn)
    if not Harness.enabled then
        updateFn()
        return
    end
    local ok, err = pcall(updateFn)
    if not ok then
        playdate.datastore.write({ err = tostring(err) }, "err")
    end
    if frame % 90 == 0 then
        local t = {}
        for k, v in pairs(Harness.counters) do t[k] = v end
        t.frame = frame
        if Harness.extra then pcall(Harness.extra, t) end
        playdate.datastore.write(t, "smoke")
    end
    if Harness.shotPath and playdate.simulator then
        if frame % 300 == 0 then
            playdate.simulator.writeToFile(playdate.graphics.getDisplayImage(), Harness.shotPath)
        end
        -- art sweep: keep the latest frame of each distinct scene, tagged by state
        -- (frame 10 grabs the title before the autopilot dismisses it)
        if frame % 40 == 0 or frame == 10 then
            local tag = G.state
            if tag == "adult" then
                if G.adult and G.adult.mode == "court" then tag = "court"
                else tag = "adult-" .. tostring(G.place) end
            end
            local p = Harness.shotPath:gsub("whine%-shot%.png$", "art-" .. tostring(tag) .. ".png")
            playdate.simulator.writeToFile(playdate.graphics.getDisplayImage(), p)
        end
    end
end
