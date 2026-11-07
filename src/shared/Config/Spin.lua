-- Spin (ModuleScript, ReplicatedStorage.Shared.Config.Spin)
-- The daily spin wheel (owner, Nov 6 2026: "spin a wheel once a day and you can get cash, double XP, double
-- money, maybe a free gun, maybe a free car. The car would be really hard to get... make it like a 1 in 18
-- odds for the car"; then: "this spin... should be somewhere on the map that's an actual wheel that
-- everyone will go to and can spin. People can watch them spin"). SpinService builds the Lucky Wheel in
-- the downtown plaza and runs the spins, SpinClient draws the wheel's face and turns it for everyone,
-- PhoneUI's SPIN app shows the day's spin and sets the GPS to the wheel.
--   * One free spin per UTC day (the same day line as DailyService's login streak). Nothing to buy: it
--     is never sold for Robux, so Roblox's paid random item rules don't apply.
--   * 18 slices of the same size, and the server picks one of the 18 at random. So every slice is exactly
--     1 in 18, the car included, and what the wheel shows is the real odds.
--   * Boosts (2X CASH, 2X XP) last Spin.BoostMinutes of PLAY time: the clock only runs while you're in
--     the game, and a second win adds the time on.
--     2X CASH doubles money earned by playing (the reasons in Spin.DoubleCash below), and a bag banked at
--     the Hideout (heists, carjacks, wallets, chop-shop cars all go into the bag first). The bonus is paid
--     as its own "spinboost:<reason>" cash so analytics can see what the boost cost. Never doubled: cash
--     packs, refunds, the daily streak, goal and tutorial rewards, money from other players.
--     2X XP doubles every XP gain (ProgressService), challenge XP too.

local Spin = {}

local Config = script.Parent -- (Vehicles is looked up when a label is asked for, not at load)

Spin.BoostMinutes = 30
Spin.Seconds = 6 -- how long the wheel turns before it stops (the prize is paid when it stops)
Spin.Turns = 5 -- whole turns before it settles
Spin.Jitter = 6 -- degrees either side of a slice's middle where it may stop

-- The Lucky Wheel itself: a big upright wheel on a stage in the open plaza east of the downtown citizen spawn
-- (spawn at -125, 40; this lot was clear from x -77 to -21, z -4 to 52 in the Nov 6 map probe). It faces the
-- spawn. One player spins at a time, at the podium in front; everyone around watches it turn.
Spin.Wheel = {
	Name = "Lucky Wheel",
	Kind = "Free spin every day",
	Pos = Vector3.new(-49, 0, 24), -- the stage's middle (the ground's height is found when it's built)
	Face = Vector3.new(-125, 0, 40), -- it turns to face this point
	Size = 18, -- the wheel's diameter, studs
	Hub = 13, -- the wheel's middle, studs above the stage
	Range = 18, -- studs from the podium a spin may be started from (the prompt itself reaches 10)
	Lead = 0.4, -- seconds between the server starting a spin and the wheel moving (so every client starts together)
	ShowResult = 4, -- seconds "<NAME> WON <PRIZE>!" stays on the sign before the next player can spin
	BigWin = 10000, -- cash prizes this big (and the car) are posted on the city feed
}

-- Where a spin that starts at angle `from` should end so that slice `index` sits under the pointer
-- (straight up), `jitter` degrees off its middle, after at least `turns` whole turns. Angles are the wheel's
-- clockwise turn in degrees; a slice i sits at (i - 1) * 360 / #Slices clockwise from the top when it's 0.
function Spin.Target(from, index, jitter, turns)
	local step = 360 / #Spin.Slices
	local base = -(index - 1) * step + (jitter or 0)
	return base + 360 * math.ceil((from + 360 * (turns or Spin.Turns) - base) / 360)
end

-- The slice under the pointer when the wheel stands at `angle`.
function Spin.SliceAt(angle)
	local step = 360 / #Spin.Slices
	return math.floor(((-angle) % 360 + step / 2) / step) % #Spin.Slices + 1
end

-- The wheel's turn `t` seconds into a spin from `from` to `to` lasting `seconds` (slows to a stop: quartic out).
function Spin.AngleAt(from, to, seconds, t)
	local a = math.clamp(t / math.max(seconds, 0.01), 0, 1)
	return from + (to - from) * (1 - (1 - a) ^ 4)
end
Spin.CarFallback = 25000 -- the car slice when you already own the car
Spin.GunFallback = 5000 -- the gun slice when you own every gun your rank can buy

-- The car slice's car: a real dealer car (not a Robux pass car), the dream car of the early game.
Spin.Car = "SolanaGT"

-- The free gun: the first of these you don't own yet and your free-roam rank can buy (Combat.RankOk).
Spin.GunOrder = { "Pistol", "SMG", "Shotgun", "Rifle" }

-- Clockwise from the top. Kind: Cash (Cash = dollars) | Car | Gun | Boost (Boost = "Cash" | "XP").
-- Mixed up so the same prize is never side by side. Counts: car 1, $10,000 1, $5,000 2, $2,500 3,
-- $1,000 4, gun 2, 2X CASH 2, 2X XP 3 = 18.
Spin.Slices = {
	{ Kind = "Car" },
	{ Kind = "Cash", Cash = 1000 },
	{ Kind = "Boost", Boost = "XP" },
	{ Kind = "Cash", Cash = 2500 },
	{ Kind = "Gun" },
	{ Kind = "Cash", Cash = 1000 },
	{ Kind = "Boost", Boost = "Cash" },
	{ Kind = "Cash", Cash = 5000 },
	{ Kind = "Boost", Boost = "XP" },
	{ Kind = "Cash", Cash = 1000 },
	{ Kind = "Cash", Cash = 2500 },
	{ Kind = "Gun" },
	{ Kind = "Cash", Cash = 10000 },
	{ Kind = "Boost", Boost = "XP" },
	{ Kind = "Cash", Cash = 1000 },
	{ Kind = "Cash", Cash = 2500 },
	{ Kind = "Boost", Boost = "Cash" },
	{ Kind = "Cash", Cash = 5000 },
}

-- Cash reasons (the part before any ":") that 2X CASH doubles: money earned by playing. A bag banked at
-- the Hideout is doubled when it's banked (EconomyService.BankCarried), so bag reasons aren't here.
Spin.DoubleCash = {
	bounty = true, patrol = true, ko_bounty = true, vigilante = true, evidence = true, -- police work
	bigscore = true, mission = true, crewprep = true, event = true, -- heists and missions paid in cash
	race = true, drift = true, stunt = true, carmeet = true, -- driving
	taxi = true, courier = true, -- jobs
	bizjob = true, bizraid = true, bizbreakin = true, -- Empire business jobs (when Empire is live)
}

-- What a slice says on the wheel (two short lines) and in the result card.
function Spin.Label(slice)
	if slice.Kind == "Cash" then
		local s = tostring(slice.Cash)
		s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		return "$" .. s, "CASH"
	elseif slice.Kind == "Car" then
		local Vehicles = require(Config.Vehicles)
		local def = Vehicles.ById[Spin.Car]
		return string.upper(def and (def.DisplayName or def.Id) or Spin.Car), "1 IN 18"
	elseif slice.Kind == "Gun" then
		return "FREE GUN", "GUN"
	elseif slice.Kind == "Boost" then
		return "2X " .. string.upper(slice.Boost), Spin.BoostMinutes .. " MIN"
	end
	return "?", ""
end

-- How many of the 18 slices pay this kind (for the odds list): Spin.Count("Cash", 1000) -> 4.
function Spin.Count(kind, value)
	local n = 0
	for _, s in ipairs(Spin.Slices) do
		if s.Kind == kind and (value == nil or s.Cash == value or s.Boost == value) then
			n += 1
		end
	end
	return n
end

-- The UTC day number (DailyService uses the same), and the server time the next one starts.
function Spin.Day(t)
	return math.floor(t / 86400)
end
function Spin.NextAt(t)
	return (Spin.Day(t) + 1) * 86400
end

return Spin
