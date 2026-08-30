--- Realm bridge reply delivery: a target that leaves partway through a
--- multi-chunk payload. The net transport itself still needs a manual check
--- (see the README).

--- Captures a chunk per net.Start, so a case can count what left the realm.
--- stub is passed in because GLuaTest injects it into a case function's own
--- environment, which a helper defined out here does not share.
local function captureNet(state, stub)
	state.sent = {}

	stub(net, "Start").with(function()
		table.insert(state.sent, {})
	end)
	stub(net, "WriteUInt")
	stub(net, "WriteString")
	stub(net, "WriteData")
	stub(net, "Send")
	stub(net, "SendToServer")
end

--- A stand-in player, reporting itself valid for its first validFor checks.
--- A nil validFor stays valid throughout.
local function fakePlayer(validFor)
	local ply = {checks = 0}
	ply.IsValid = function()
		ply.checks = ply.checks + 1
		return validFor == nil or ply.checks <= validFor
	end

	return ply
end

return {
	groupName = "Internet's Benchmark Suite: Realm Bridge",

	beforeEach = function(state)
		state.chunkSize = INTERNET_BENCHMARK.RealmChunkSize
		INTERNET_BENCHMARK.RealmChunkSize = 8
	end,

	afterEach = function(state)
		INTERNET_BENCHMARK.RealmChunkSize = state.chunkSize
	end,

	cases = {
		{
			name = "Sends every chunk of a payload to a player who stays connected",
			func = function(state)
				captureNet(state, stub)

				local sent = INTERNET_BENCHMARK:SendChunkedString(fakePlayer(), 1, "text", string.rep("a", 24))

				expect(sent).to.beTrue()
				expect(#state.sent).to.equal(3)
			end
		},

		{
			name = "Stops sending once the target player disconnects mid-payload",
			func = function(state)
				captureNet(state, stub)

				local sent = INTERNET_BENCHMARK:SendChunkedString(fakePlayer(1), 2, "html", string.rep("a", 24))

				expect(sent).to.beFalse()
				expect(#state.sent).to.equal(1)
			end
		},

		{
			name = "Sends nothing at all when the target player has already left",
			func = function(state)
				captureNet(state, stub)

				local sent = INTERNET_BENCHMARK:SendChunkedString(fakePlayer(0), 3, "text", "short")

				expect(sent).to.beFalse()
				expect(#state.sent).to.equal(0)
			end
		},

		{
			name = "Sends to the server without needing a player",
			func = function(state)
				captureNet(state, stub)

				local sent = INTERNET_BENCHMARK:SendChunkedString(nil, 4, "text", string.rep("a", 16))

				expect(sent).to.beTrue()
				expect(#state.sent).to.equal(2)
			end
		}
	}
}
