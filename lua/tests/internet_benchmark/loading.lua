--- Trial discovery, loading and realm gating.

local function countOccurrences(list, value)
	local count = 0
	for _, item in ipairs(list) do
		if item == value then
			count = count + 1
		end
	end

	return count
end

return {
	groupName = "Internet's Benchmark Suite: Trial Loading",

	beforeAll = function(state)
		state.logLevel = INTERNET_BENCHMARK.Logging.Level
		INTERNET_BENCHMARK.Logging.Level = INTERNET_BENCHMARK.Logging.Levels.NONE
	end,

	afterAll = function(state)
		INTERNET_BENCHMARK.Logging.Level = state.logLevel
	end,

	cases = {
		{
			name = "Exposes the suite on the global table",
			func = function()
				expect(INTERNET_BENCHMARK).to.beA("table")
				expect(INTERNET_BENCHMARK.Version).to.beA("string")
				expect(INTERNET_BENCHMARK.Build).to.beA("string")
				expect(INTERNET_BENCHMARK.Classes.Trial).to.beA("table")
			end
		},

		{
			name = "Discovers the trials shipped with the suite",
			func = function()
				local names = INTERNET_BENCHMARK:TrialNames()

				expect(names).to.beA("table")
				expect(#names).to.beGreaterThan(0)

				local hasKnownTrial = table.HasValue(names, "local_vs_global")
				expect(hasKnownTrial).to.beTrue()
			end
		},

		{
			name = "Lists a trial once even when it has a meta file",
			func = function()
				local names = INTERNET_BENCHMARK:TrialNames()

				local drawRectCount = countOccurrences(names, "draw_rect")
				expect(drawRectCount).to.equal(1)

				local hasMetaEntry = table.HasValue(names, "draw_rect.meta")
				expect(hasMetaEntry).to.beFalse()
			end
		},

		{
			name = "Returns the discovered trials in sorted order",
			func = function()
				local names = INTERNET_BENCHMARK:TrialNames()
				expect(names[1]).to.equal("array_insertion")
			end
		},

		{
			name = "Loads a trial with its functions, labels and identifier",
			func = function()
				local trial = INTERNET_BENCHMARK:LoadTrial("local_vs_global")

				expect(trial).to.beA("table")
				expect(trial.id).to.equal("local_vs_global")
				expect(trial.name).to.equal("Local vs Global")
				expect(#trial.functions).to.equal(2)
				expect(trial.labels[1]).to.equal("type(3)")
				expect(trial.labels[2]).to.equal("t(3)")
			end
		},

		{
			name = "Applies the default run and iteration counts",
			func = function()
				local trial = INTERNET_BENCHMARK:LoadTrial("local_vs_global")

				expect(trial.runs).to.equal(100)
				expect(trial.iterations).to.equal(100000)
			end
		},

		{
			name = "Skips trials gated to the client realm",
			func = function()
				local trial = INTERNET_BENCHMARK:LoadTrial("draw_rect")
				expect(trial).to.beNil()
			end
		},

		{
			name = "Skips trials whose environment probe fails",
			func = function()
				local trial = INTERNET_BENCHMARK:LoadTrial("ns_accessors")
				expect(trial).to.beNil()
			end
		},

		{
			name = "Returns nil for a trial that does not exist",
			func = function()
				local trial = INTERNET_BENCHMARK:LoadTrial("no_such_trial_exists")
				expect(trial).to.beNil()
			end
		},

		{
			name = "Clears the TRIAL global once loading finishes",
			func = function()
				INTERNET_BENCHMARK:LoadTrial("local_vs_global")
				expect(TRIAL).to.beNil()
			end
		},

		{
			name = "A fresh trial has no tags, and Tag() appends to the list",
			func = function()
				local trial = INTERNET_BENCHMARK.Classes.Trial()
				expect(trial.tags).to.beA("table")
				expect(#trial.tags).to.equal(0)

				trial:Tag("default", "slow")

				expect(#trial.tags).to.equal(2)
				expect(trial.tags[1]).to.equal("default")
				expect(trial.tags[2]).to.equal("slow")
			end
		},

		{
			name = "Every trial shipped with the suite is tagged 'default'",
			func = function()
				local names = INTERNET_BENCHMARK:TrialNames()

				for _, name in ipairs(names) do
					local trial = INTERNET_BENCHMARK:LoadTrial(name)
					if trial then
						local hasDefault = table.HasValue(trial.tags, "default")
						expect(hasDefault).to.beTrue()
					end
				end
			end
		}
	}
}
