-- Synth sound kit: the wing whine, the feeding pump, the courtship beat, and
-- assorted stings.

local snd <const> = playdate.sound

Sfx = {}

local tri = snd.synth.new(snd.kWaveTriangle)
local sq = snd.synth.new(snd.kWaveSquare)
local saw = snd.synth.new(snd.kWaveSawtooth)
local noise = snd.synth.new(snd.kWaveNoise)

-- Courtship = TWO free-running wing oscillators whose acoustic sum BEATS.
-- Your wing (crank-tuned) and the male's wing (drifting target) each sound
-- continuously; where their pitches differ you hear an amplitude wah at their
-- |f_you - f_male| difference. As you converge the wah slows; at unison it goes
-- dead still - the audible "lock". This is a genuine two-oscillator beat, not a
-- retrigger: setLegato(true) lets each per-frame playNote glide the pitch
-- WITHOUT re-attacking the envelope or restarting the oscillator, so the two
-- waves keep running and beat against each other. Sine keeps the beat legible.
local wingYou <const> = snd.synth.new(snd.kWaveSine)
local wingMale <const> = snd.synth.new(snd.kWaveSine)
for _, w in ipairs({ wingYou, wingMale }) do
    w:setADSR(0.02, 0, 1, 0.08) -- steady sustain: it's a held tone, not a pluck
    w:setLegato(true)           -- retune without re-triggering (phase-continuous)
end

-- courtship pitch 0..1 -> Hz. The two wings meet in this band; at the lock
-- tolerance (~0.06) they're ~20 Hz apart (a fast shimmer) and slow to 0 at unison.
local COURT_FLO <const>, COURT_FHI <const> = 340, 700
function Sfx.courtFreq(p) return COURT_FLO + (COURT_FHI - COURT_FLO) * p end

function Sfx.courtSet(fYou, fMale)
    wingYou:playNote(fYou, 0.34)  -- first call starts it; later calls glide (legato)
    wingMale:playNote(fMale, 0.30)
end

function Sfx.courtStop()
    wingYou:noteOff()
    wingMale:noteOff()
end

function Sfx.wing(f) tri:playNote(f or 360, 0.05, 0.03) end
function Sfx.pump() sq:playNote(140, 0.18, 0.04) end
function Sfx.tone(f) saw:playNote(f or 400, 0.12, 0.05) end
function Sfx.pop() tri:playNote(1200, 0.2, 0.03) end
function Sfx.rain() noise:playNote(400, 0.15, 0.4) end
function Sfx.lay() tri:playNote(700, 0.25, 0.06); Util.after(0.06, function() tri:playNote(900, 0.25, 0.06) end) end
function Sfx.splat() noise:playNote(200, 0.4, 0.18); sq:playNote(90, 0.4, 0.12) end

function Sfx.fanfare(notes, step)
    notes = notes or { 523, 659, 784, 1047 }
    for i, n in ipairs(notes) do
        Util.after((i - 1) * (step or 0.1), function() tri:playNote(n, 0.3, (step or 0.1) * 1.4) end)
    end
end

function Sfx.chime() Sfx.fanfare({ 659, 880, 1047 }, 0.08) end

function Sfx.gulp() sq:playNote(210, 0.14, 0.05); Util.after(0.04, function() sq:playNote(320, 0.14, 0.05) end) end
function Sfx.emerge() Sfx.fanfare({ 392, 523, 659, 784, 1047 }, 0.06) end
function Sfx.bubble() tri:playNote(900, 0.05, 0.02) end

-- ---- per-stage ambience: a beat-clocked motif over a sustained drone --------
-- Beyond the one-shot kit: each lifecycle stage gets its own palette (tempo,
-- key, scale, motif, timbre), the pupa drone climbs an octave as it forms, and
-- the adult bed darkens + quickens at dusk. A drift-free accumulator steps the
-- melody so it never slides off the beat. Additive to the SFX above.
local mDrone <const> = snd.synth.new(snd.kWaveSine)
mDrone:setADSR(0.4, 0, 1, 0.6); mDrone:setLegato(true)
local mLead <const> = snd.synth.new(snd.kWaveTriangle)
mLead:setADSR(0.005, 0.09, 0, 0.12)
local mPad <const> = snd.synth.new(snd.kWaveSquare)
mPad:setADSR(0.02, 0.1, 0, 0.22)

local function hz(root, semis) return root * 2 ^ (semis / 12) end

-- bps beats/sec, root Hz, scale semitone steps, motif scale-degrees (-1 = rest),
-- drone semitone offset (nil = none), wave timbre for the lead
local PAL = {
    title = { bps = 3.4, root = 262, scale = { 0, 4, 7, 12 }, motif = { 0, 1, 2, 3, 2, 1, 3, 2 }, drone = -12, wave = snd.kWaveTriangle },
    raft  = { bps = 1.4, root = 392, scale = { 0, 2, 4, 7, 9 }, motif = { 2, -1, 4, -1, 1, -1, 3, -1 }, drone = -12, wave = snd.kWaveSine },
    larva = { bps = 1.8, root = 196, scale = { 0, 3, 5, 7, 10 }, motif = { 0, -1, -1, 2, -1, -1, 1, -1 }, drone = -12, wave = snd.kWaveSine },
    pupa  = { bps = 2.4, root = 220, scale = { 0, 2, 3, 5, 7 }, motif = { 0, 1, 2, 3, 4, 3, 2, 1 }, drone = 0, wave = snd.kWaveSine },
    adult = { bps = 2.6, root = 294, scale = { 0, 2, 4, 7, 9 }, motif = { 0, 2, 4, 2, 3, 1, 4, 2 }, drone = -12, wave = snd.kWaveTriangle },
    dusk  = { bps = 3.0, root = 233, scale = { 0, 2, 3, 5, 7, 8 }, motif = { 0, 3, 2, 5, 3, 2, 4, 1 }, drone = -12, wave = snd.kWaveSquare },
}

local mCur, mStep, mAcc = nil, 0, 0

function Sfx.musicStop() mDrone:noteOff(); mLead:noteOff(); mPad:noteOff() end

local function palFor(state)
    if state == "adult" and Threats.dusk() then return "dusk", PAL.dusk end
    return state, PAL[state]
end

function Sfx.music(dt)
    local key, p = palFor(G.state)
    if key ~= mCur then -- stage changed: swap palette, restart the bar
        mCur, mStep, mAcc = key, 0, 0
        if not p then Sfx.musicStop()
        else
            mLead:setWaveform(p.wave)
            if p.drone then mDrone:playNote(hz(p.root, p.drone), 0.15) else mDrone:noteOff() end
        end
    end
    if not p then return end
    if G.state == "pupa" and p.drone and G.pupa then -- drone rises as it forms
        local prog = math.min(1, (G.pupa.meta or 0) / C.PUPA_T)
        mDrone:playNote(hz(p.root, p.drone + prog * 12), 0.15)
    end
    mAcc = mAcc + dt
    local spb = 1 / p.bps
    while mAcc >= spb do
        mAcc = mAcc - spb
        local m = p.motif[(mStep % #p.motif) + 1]
        mStep = mStep + 1
        if m and m >= 0 then
            local n = #p.scale
            local deg = p.scale[(m % n) + 1] + 12 * math.floor(m / n)
            mLead:playNote(hz(p.root, deg), 0.13, spb * 0.9)
            if mStep % 4 == 1 then mPad:playNote(hz(p.root, deg - 12), 0.07, spb * 1.6) end
        end
    end
end
