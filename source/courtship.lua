-- Harmonic-convergence courtship minigame (see DESIGN.md). Crank shifts your
-- wingbeat pitch toward the male's drifting target; hold inside tolerance to
-- converge. Lock quality sets the fertility multiplier. A sub-mode of the
-- adult stage (G.adult.mode == "court"), not a separate lifecycle state.
--
-- The feel lives in the SOUND: two wing oscillators (yours + his) beat against
-- each other, and the wah slows to a dead-still unison as you lock (see
-- Sfx.courtSet). c.beat (Hz) is that beat rate, surfaced for the HUD + smoke.
-- TODO: an actively evasive male.

Courtship = {}

function Courtship.begin()
    G.court = {
        pitch = 0.2,
        target = 0.5,
        lock = 0,
        phase = 0,
        diff = 1,
        beat = 0,
        beatPhase = 0,
    }
    G.adult.mode = "court"
    Sfx.courtSet(Sfx.courtFreq(0.2), Sfx.courtFreq(0.5)) -- start both wings sounding
end

-- leave courtship and silence both wings (shared by lock + bail + safety)
function Courtship.stop(mode)
    Sfx.courtStop()
    if G.adult then G.adult.mode = mode or "fly" end
end

function Courtship.update(dt, inp)
    local c = G.court
    c.pitch = Util.clamp(c.pitch + (inp.crank / 360) * C.PITCH_SENS, 0, 1)
    c.phase = c.phase + dt

    -- the male's wingbeat: an organic wander he keeps roving toward, PLUS an
    -- evasion that edges his pitch away from yours as you close in. The evasion
    -- fades as your lock builds (flee), so he plays hard to get at first but
    -- gives in if you stay glued to him - persistence wins, like the real thing.
    local base = 0.5 + math.sin(c.phase * 0.7) * 0.18 + math.sin(c.phase * 1.9 + 1.3) * 0.08
    local gap = c.target - c.pitch
    local flee = math.max(0, 1 - c.lock / C.LOCK_T)
    local evade = 0
    if math.abs(gap) < C.EVADE_R then
        evade = (gap >= 0 and 1 or -1) * C.EVADE_SPD * flee * dt
    end
    c.target = Util.clamp(c.target + (base - c.target) * 0.06 + evade, 0.08, 0.92)
    c.diff = math.abs(c.pitch - c.target)

    if c.diff < C.LOCK_TOL then
        c.lock = c.lock + dt
    else
        c.lock = math.max(0, c.lock - dt * 0.6)
    end

    -- drive the two wing oscillators; their |difference| is the audible beat
    local fYou = Sfx.courtFreq(c.pitch)
    local fMale = Sfx.courtFreq(c.target)
    c.beat = math.abs(fYou - fMale)
    c.beatPhase = (c.beatPhase + c.beat * dt * 0.06) % 1 -- visual pulse tracks the wah
    Sfx.courtSet(fYou, fMale)

    if c.lock >= C.LOCK_T then
        G.mated = true
        local q = Util.clamp(1 - c.diff / C.LOCK_TOL, 0, 1)
        local fert = 1.0 + 0.5 * q
        G.fertility = math.max(G.fertility, fert)
        G.lockBeat = c.beat -- how tight the unison was at lock (Hz; ~0 = perfect)
        G.male = nil
        Courtship.stop("fly")
        Sfx.chime()
        Harness.count("matings")
        if G.adult.sex == "male" then
            -- bonus run: bank the eggs he sired, then seek the next female (or end)
            G.maleBonus = (G.maleBonus or 0) + math.floor(C.MALE_BONUS * fert)
            G.maleBroods = (G.maleBroods or 0) + 1
            if G.maleBroods >= C.MALE_TARGET then Game.maleReturn()
            else G.maleT = C.MALE_EVERY * 0.6 end
        end
        return
    end

    if inp.btap then Courtship.stop("fly") end -- bail out
end
