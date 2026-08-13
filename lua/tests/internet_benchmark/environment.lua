--- The environment statement and the suite's console commands.

--- Find a row's value in a Collect() result, by label.
local function rowValue(details, label)
	for _, pair in ipairs(details) do
		if pair[1] == label then
			return pair[2]
		end
	end

	return nil
end

--- Install a fake gm_sysinfo table for a case; cleanup must call the return.
local function fakeSysInfo(fake)
	local original = sysinfo
	sysinfo = fake

	return function()
		sysinfo = original
	end
end

return {
	groupName = "Internet's Benchmark Suite: Environment",

	cases = {
		{
			name = "Collects environment details as label and value pairs",
			func = function()
				local details = INTERNET_BENCHMARK.Environment:Collect()

				expect(details).to.beA("table")
				expect(#details).to.beGreaterThan(9)
				expect(details[1][1]).to.equal("Suite Version")
				expect(details[1][2]).to.equal(INTERNET_BENCHMARK.Version)
			end
		},

		{
			name = "Reports the server realm when collected on the server",
			func = function()
				local details = INTERNET_BENCHMARK.Environment:Collect()

				expect(details[3][1]).to.equal("Realm")
				expect(details[3][2]).to.equal("Server")
			end
		},

		{
			name = "States the hardware details plain GLua cannot provide",
			func = function()
				local statement = INTERNET_BENCHMARK.Environment:Format()

				local hasHeading = string.find(statement, "Environment Statement", 1, true)
				expect(hasHeading).to.exist()

				local hasCaveat = string.find(statement, "binary module", 1, true)
				expect(hasCaveat).to.exist()
			end
		},

		{
			name = "Records the Lua runtime the game is using",
			func = function()
				local statement = INTERNET_BENCHMARK.Environment:Format()

				local hasRuntime = string.find(statement, "Lua Runtime: LuaJIT", 1, true)
				expect(hasRuntime).to.exist()
			end
		},

		{
			name = "Writes the environment statement into the data directory",
			func = function()
				INTERNET_BENCHMARK.Environment:Write()

				local written = file.Read("internet_benchmarks/environment.txt", "DATA")
				expect(written).to.exist()

				local hasHeading = string.find(written, "Environment Statement", 1, true)
				expect(hasHeading).to.exist()
			end,

			cleanup = function()
				file.Delete("internet_benchmarks/environment.txt")
			end
		},

		{
			name = "Omits host detail rows when gm_sysinfo is not installed",
			when = function() return sysinfo == nil end,
			func = function()
				local details = INTERNET_BENCHMARK.Environment:Collect()

				expect(rowValue(details, "Physical Cores")).to.beNil()
				expect(rowValue(details, "Total Memory")).to.beNil()

				local statement = INTERNET_BENCHMARK.Environment:Format()
				local hasHint = string.find(statement, "gm_sysinfo", 1, true)
				expect(hasHint).to.exist()
			end
		},

		{
			name = "Extends the statement when gm_sysinfo is present",
			func = function(state)
				state.restore = fakeSysInfo({
					get_version = function() return "2.0.0" end,
					get_system_long_version = function() return "Ubuntu 24.04.3 LTS" end,
					get_kernel_version = function() return "6.8.0-79-generic" end,
					get_distro_id = function() return "ubuntu" end,
					get_cpu_arch = function() return "x86_64" end,
					get_core_count = function() return 8 end,
					get_memory = function() return 16 * 1024 ^ 3 end,
					get_available_memory = function() return 512 * 1024 ^ 2 end,
					get_swap = function() return 0 end,
					get_load_average = function() return {one = 0.5, five = 0.25, fifteen = 0.1} end,
					get_uptime = function() return 90061 end,
				})

				local details = INTERNET_BENCHMARK.Environment:Collect()

				expect(rowValue(details, "System Info Module")).to.equal("gm_sysinfo 2.0.0")
				expect(rowValue(details, "OS Version")).to.equal("Ubuntu 24.04.3 LTS")
				expect(rowValue(details, "Physical Cores")).to.equal(8)
				expect(rowValue(details, "Total Memory")).to.equal("16.00 GiB")
				expect(rowValue(details, "Available Memory")).to.equal("512 MiB")
				expect(rowValue(details, "Load Average")).to.equal("0.50 / 0.25 / 0.10 (1/5/15 min)")
				expect(rowValue(details, "Host Uptime")).to.equal("1d 1h 1m")
			end,

			cleanup = function(state)
				state.restore()
			end
		},

		{
			name = "Keeps the fixed rows first when gm_sysinfo is present",
			func = function(state)
				state.restore = fakeSysInfo({
					get_core_count = function() return 8 end,
				})

				local details = INTERNET_BENCHMARK.Environment:Collect()

				expect(details[1][1]).to.equal("Suite Version")
				expect(details[3][1]).to.equal("Realm")
				expect(details[13][1]).to.equal("Players")
			end,

			cleanup = function(state)
				state.restore()
			end
		},

		{
			name = "Omits rows whose getters raise or are missing",
			func = function(state)
				state.restore = fakeSysInfo({
					get_kernel_version = function() error("no kernel version available") end,
					get_core_count = function() return 8 end,
					get_load_average = function() return {} end,
				})

				local details = INTERNET_BENCHMARK.Environment:Collect()

				expect(rowValue(details, "Kernel")).to.beNil()
				expect(rowValue(details, "Total Memory")).to.beNil()
				expect(rowValue(details, "Load Average")).to.beNil()
				expect(rowValue(details, "Physical Cores")).to.equal(8)
			end,

			cleanup = function(state)
				state.restore()
			end
		},

		{
			name = "Registers the suite console commands",
			func = function()
				local commands = concommand.GetTable()

				expect(commands["internet_benchmark_run"]).to.beA("function")
				expect(commands["internet_benchmark_trial"]).to.beA("function")
				expect(commands["internet_benchmark_environment"]).to.beA("function")
				expect(commands["internet_benchmark_logging_report"]).to.beA("function")
			end
		}
	}
}
