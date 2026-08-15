--- Console command authorisation and validation, shared with the realm
--- bridge (see sv_realm.lua/cl_realm.lua). The actual cross-realm net
--- relay isn't covered here - these integration tests run serverside with
--- no real connected client to round-trip against - so this covers only
--- the pieces reachable without one; the relay itself needs a manual check
--- with a real dedicated server and client (see the README).

return {
	groupName = "Internet's Benchmark Suite: Commands",

	cases = {
		{
			name = "CanRunHere allows the dedicated console (no player)",
			func = function()
				expect(INTERNET_BENCHMARK:CanRunHere(nil)).to.beTrue()
			end
		},

		{
			name = "CanRunHere allows a superadmin player",
			func = function()
				local ply = {IsValid = function() return true end, IsSuperAdmin = function() return true end}
				expect(INTERNET_BENCHMARK:CanRunHere(ply)).to.beTrue()
			end
		},

		{
			name = "CanRunHere refuses a non-superadmin player",
			func = function()
				local ply = {IsValid = function() return true end, IsSuperAdmin = function() return false end}
				expect(INTERNET_BENCHMARK:CanRunHere(ply)).to.beFalse()
			end
		},

		{
			name = "ConflictingFlags rejects --dynamic and --test together",
			func = function()
				local warned = stub(INTERNET_BENCHMARK.Logging, "ForceWarning")
				local conflict = INTERNET_BENCHMARK:ConflictingFlags(true, true)
				warned:Restore()

				expect(conflict).to.beTrue()
				expect(warned).was.called()
			end
		},

		{
			name = "ConflictingFlags allows either flag alone, or neither",
			func = function()
				expect(INTERNET_BENCHMARK:ConflictingFlags(true, false)).to.beFalse()
				expect(INTERNET_BENCHMARK:ConflictingFlags(false, true)).to.beFalse()
				expect(INTERNET_BENCHMARK:ConflictingFlags(false, false)).to.beFalse()
			end
		},

		{
			name = "ConsoleReport returns the same lines it prints",
			func = function()
				local lines = INTERNET_BENCHMARK:ConsoleReport("local_vs_global", false, true)

				expect(lines).to.beA("table")
				expect(#lines).to.equal(3)

				local hasHeader = string.find(lines[1], "Results for 'Local vs Global'", 1, true)
				expect(hasHeader).to.exist()
			end
		},

		{
			name = "ConsoleReport returns nil for a trial that did not run",
			func = function()
				local lines = INTERNET_BENCHMARK:ConsoleReport("no_such_trial_exists", false, true)
				expect(lines).to.beNil()
			end
		},

		{
			name = "ResolvePlayer requires a --target value",
			func = function()
				local target, err = INTERNET_BENCHMARK:ResolvePlayer(nil)

				expect(target).to.beNil()
				expect(err).to.beA("string")
			end
		},

		{
			name = "ResolvePlayer rejects a bare --target flag with no value",
			func = function()
				local target, err = INTERNET_BENCHMARK:ResolvePlayer(true)

				expect(target).to.beNil()
				expect(err).to.beA("string")
			end
		}
	}
}
