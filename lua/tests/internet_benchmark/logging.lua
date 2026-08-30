--- Level parsing, gating and the branded console output.

local LEVELS = {"Fatal", "Error", "Warning", "Info", "Debug"}

--- Swap in a fake printer for a case; cleanup must call the return.
--- Each level's function captures the printer when it is built, so both
--- installing and removing the fake have to rebuild them.
local function fakePrinter(fake)
	local logging = INTERNET_BENCHMARK.Logging
	local original = logging._print

	logging._print = fake
	for _, level in ipairs(LEVELS) do
		logging:Build(level)
	end

	return function()
		logging._print = original
		for _, level in ipairs(LEVELS) do
			logging:Build(level)
		end
	end
end

return {
	groupName = "Internet's Benchmark Suite: Logging",

	beforeEach = function(state)
		state.logLevel = INTERNET_BENCHMARK.Logging.Level
	end,

	afterEach = function(state)
		INTERNET_BENCHMARK.Logging.Level = state.logLevel
	end,

	cases = {
		{
			name = "Parse resolves a level name to its value",
			func = function()
				local logging = INTERNET_BENCHMARK.Logging
				expect(logging.Parse("DEBUG")).to.equal(logging.Levels.DEBUG)
				expect(logging.Parse("NONE")).to.equal(logging.Levels.NONE)
			end
		},

		{
			name = "Parse resolves a level name regardless of case",
			func = function()
				local logging = INTERNET_BENCHMARK.Logging
				expect(logging.Parse("debug")).to.equal(logging.Levels.DEBUG)
				expect(logging.Parse("Debug")).to.equal(logging.Levels.DEBUG)
			end
		},

		{
			name = "Parse resolves a numeric string to that number",
			func = function()
				expect(INTERNET_BENCHMARK.Logging.Parse("30")).to.equal(30)
			end
		},

		{
			name = "Parse passes a number through unchanged",
			func = function()
				expect(INTERNET_BENCHMARK.Logging.Parse(40)).to.equal(40)
			end
		},

		{
			name = "Parse clamps a number to the level bounds",
			func = function()
				local logging = INTERNET_BENCHMARK.Logging
				expect(logging.Parse(9999)).to.equal(logging.Levels._MAX)
				expect(logging.Parse(-9999)).to.equal(logging.Levels._MIN)
			end
		},

		{
			name = "Parse falls back to the default for an unrecognised value",
			func = function()
				local logging = INTERNET_BENCHMARK.Logging
				expect(logging.Parse("not_a_level")).to.equal(logging.Levels.DEFAULT)
			end
		},

		{
			name = "EnumDescription lists every selectable level name",
			func = function()
				local desc = INTERNET_BENCHMARK.Logging:EnumDescription()

				expect(desc).to.beA("string")
				for _, name in ipairs({"NONE", "FATAL", "ERROR", "WARNING", "INFO", "DEBUG", "ANY"}) do
					expect(string.find(desc, name, 1, true)).to.exist()
				end
			end
		},

		{
			name = "EnumDescription hides the aliases that are not levels of their own",
			func = function()
				local desc = INTERNET_BENCHMARK.Logging:EnumDescription()

				expect(string.find(desc, "DEFAULT", 1, true)).to.beNil()
				expect(string.find(desc, "_MAX", 1, true)).to.beNil()
				expect(string.find(desc, "_MIN", 1, true)).to.beNil()
			end
		},

		{
			name = "The logging level convar is registered with the parsed level",
			func = function()
				local convar = GetConVar("internet_benchmark_logging_level")

				expect(convar).to.exist()
				expect(INTERNET_BENCHMARK.Logging.Level).to.equal(INTERNET_BENCHMARK.Logging.Parse(convar:GetString()))
			end
		},

		{
			name = "Changing the logging level convar re-parses the active level",
			async = true,
			timeout = 2,
			func = function(state)
				local convar = GetConVar("internet_benchmark_logging_level")
				state.originalConvar = convar:GetString()

				-- Set numerically: the convar carries numeric bounds, so a level
				-- name would be coerced before the change callback ever sees it.
				convar:SetString(tostring(INTERNET_BENCHMARK.Logging.Levels.DEBUG))

				timer.Simple(0, function()
					expect(INTERNET_BENCHMARK.Logging.Level).to.equal(INTERNET_BENCHMARK.Logging.Levels.DEBUG)

					done()
				end)
			end,

			cleanup = function(state)
				if state.originalConvar then
					GetConVar("internet_benchmark_logging_level"):SetString(state.originalConvar)
				end
			end
		},

		{
			name = "Brand returns the branded phrase followed by the text colour",
			func = function()
				local logging = INTERNET_BENCHMARK.Logging
				local brand = logging:Brand(false, "")

				expect(brand).to.beA("table")
				expect(brand[1]).to.equal(logging.Phrases.Brand)
				expect(brand[2]).to.equal(logging.Colours.Text)
			end
		},

		{
			name = "Brand wraps the phrase in brackets when asked",
			func = function()
				local brand = INTERNET_BENCHMARK.Logging:Brand(true, "")

				expect(brand[2]).to.equal("[")
				expect(brand[3]).to.equal(INTERNET_BENCHMARK.Logging.Phrases.Brand)
				expect(brand[5]).to.equal("]")
			end
		},

		{
			name = "Brand uses the phrase matching the requested event",
			func = function()
				local logging = INTERNET_BENCHMARK.Logging
				local brand = logging:Brand(false, "Pride")

				expect(brand[1]).to.equal(logging.Phrases.BrandPride)
			end
		},

		{
			name = "Brand falls back to the plain phrase for an unknown event",
			func = function()
				local logging = INTERNET_BENCHMARK.Logging
				local brand = logging:Brand(false, "NoSuchEvent")

				expect(brand[1]).to.equal(logging.Phrases.Brand)
			end
		},

		{
			name = "A log below the active level is suppressed",
			func = function(state)
				local calls = 0
				state.restore = fakePrinter(function() calls = calls + 1 end)

				INTERNET_BENCHMARK.Logging.Level = INTERNET_BENCHMARK.Logging.Levels.WARNING
				INTERNET_BENCHMARK.Logging.Debug("hidden")

				expect(calls).to.equal(0)
			end,

			cleanup = function(state)
				state.restore()
			end
		},

		{
			name = "A log at or above the active level is printed",
			func = function(state)
				local calls = 0
				state.restore = fakePrinter(function() calls = calls + 1 end)

				INTERNET_BENCHMARK.Logging.Level = INTERNET_BENCHMARK.Logging.Levels.DEBUG
				INTERNET_BENCHMARK.Logging.Warning("shown")

				expect(calls).to.equal(1)
			end,

			cleanup = function(state)
				state.restore()
			end
		},

		{
			name = "A Force log prints even when its level is suppressed",
			func = function(state)
				local calls = 0
				state.restore = fakePrinter(function() calls = calls + 1 end)

				INTERNET_BENCHMARK.Logging.Level = INTERNET_BENCHMARK.Logging.Levels.NONE
				INTERNET_BENCHMARK.Logging.Fatal("hidden")
				expect(calls).to.equal(0)

				INTERNET_BENCHMARK.Logging.ForceFatal("shown")
				expect(calls).to.equal(1)
			end,

			cleanup = function(state)
				state.restore()
			end
		},

		{
			name = "A log carries the branded prefix ahead of its message",
			func = function(state)
				local received
				state.restore = fakePrinter(function(...) received = {...} end)

				INTERNET_BENCHMARK.Logging.Level = INTERNET_BENCHMARK.Logging.Levels.ANY
				INTERNET_BENCHMARK.Logging.Info("the message")

				expect(received).to.beA("table")
				expect(received[#received]).to.equal("the message")

				local hasLevel = false
				for _, value in ipairs(received) do
					if value == "Info" then
						hasLevel = true
					end
				end
				expect(hasLevel).to.beTrue()
			end,

			cleanup = function(state)
				state.restore()
			end
		},

		{
			name = "Build installs both the plain and Force variants of a level",
			func = function()
				local logging = INTERNET_BENCHMARK.Logging

				expect(logging.Warning).to.beA("function")
				expect(logging.ForceWarning).to.beA("function")
			end
		},

		{
			name = "internet_benchmark_logging_report describes the configured levels",
			func = function(state)
				INTERNET_BENCHMARK.Logging.Level = INTERNET_BENCHMARK.Logging.Levels.NONE

				local printed = stub(_G, "MsgC")
				state.printed = printed

				local callback = concommand.GetTable()["internet_benchmark_logging_report"]
				callback(nil, "internet_benchmark_logging_report", {}, "")

				printed:Restore()

				expect(printed).was.called()
			end
		},

		{
			name = "internet_benchmark_logging_report refuses a non-superadmin player",
			func = function(state)
				-- The refusal warning is level-gated; the report body is not,
				-- so silencing the logger leaves MsgC as a clean signal.
				INTERNET_BENCHMARK.Logging.Level = INTERNET_BENCHMARK.Logging.Levels.NONE

				local ply = {IsValid = function() return true end, IsSuperAdmin = function() return false end}

				local printed = stub(_G, "MsgC")
				state.printed = printed

				local callback = concommand.GetTable()["internet_benchmark_logging_report"]
				callback(ply, "internet_benchmark_logging_report", {}, "")

				printed:Restore()

				expect(printed).wasNot.called()
			end
		}
	}
}
