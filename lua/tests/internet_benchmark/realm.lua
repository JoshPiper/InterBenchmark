--- The realm bridge's reply-acceptance gate, its rejection reporting, and the delivery of a reply to a target that may leave mid-payload. The net relay around it still needs a manual check (see the README).

local function fakePlayer(steamId, nick)
	return {
		IsValid = function() return true end,
		SteamID = function() return steamId or "STEAM_0:0:1" end,
		Nick = function() return nick or "Test Player" end
	}
end

--- Collect what a logging function is called with, untangled from the rejection throttle.
local function captureLog(name, fn)
	local messages = {}
	local originalLog = INTERNET_BENCHMARK.Logging[name]
	local originalInterval = INTERNET_BENCHMARK.RealmRejectLogInterval

	INTERNET_BENCHMARK.Logging[name] = function(message)
		table.insert(messages, message)
	end
	INTERNET_BENCHMARK.RealmRejectLogInterval = 0

	local ok, err = pcall(fn)

	INTERNET_BENCHMARK.Logging[name] = originalLog
	INTERNET_BENCHMARK.RealmRejectLogInterval = originalInterval

	if not ok then
		error(err)
	end

	return messages
end

--- A stand-in target, valid for its first validFor checks, or throughout when that is nil.
local function leavingPlayer(validFor)
	local ply = {checks = 0}
	ply.IsValid = function()
		ply.checks = ply.checks + 1
		return validFor == nil or ply.checks <= validFor
	end

	return ply
end

--- Captures a chunk per net.Start; stub is passed in because GLuaTest scopes it to a case function's own environment.
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

--- Run fn with the chunk size shrunk, so a short payload spans several messages.
local function withChunkSize(size, fn)
	local original = INTERNET_BENCHMARK.RealmChunkSize
	INTERNET_BENCHMARK.RealmChunkSize = size

	local ok, err = pcall(fn)
	INTERNET_BENCHMARK.RealmChunkSize = original

	if not ok then
		error(err)
	end
end

return {
	groupName = "Internet's Benchmark Suite: Realm",

	cases = {
		{
			name = "Rejects a reply for a request this realm never sent, loudly",
			func = function()
				local accepted
				local messages = captureLog("Error", function()
					accepted = INTERNET_BENCHMARK:AcceptRealmReply(910001, fakePlayer())
				end)

				expect(accepted).to.beFalse()
				expect(#messages).to.equal(1)
			end
		},

		{
			name = "Rejects a reply from a player other than the one asked, loudly",
			func = function()
				local asked, forger = fakePlayer("STEAM_0:0:11"), fakePlayer("STEAM_0:0:22")
				INTERNET_BENCHMARK:TrackRealmRequest(910002, asked)

				local accepted
				local messages = captureLog("Error", function()
					accepted = INTERNET_BENCHMARK:AcceptRealmReply(910002, forger)
				end)
				INTERNET_BENCHMARK:ForgetRealmRequest(910002)

				expect(accepted).to.beFalse()
				expect(#messages).to.equal(1)
			end
		},

		{
			name = "Accepts a reply from the player the request was sent to",
			func = function()
				local asked = fakePlayer()
				INTERNET_BENCHMARK:TrackRealmRequest(910003, asked)

				local messages = captureLog("Error", function()
					expect(INTERNET_BENCHMARK:AcceptRealmReply(910003, asked)).to.beTrue()
				end)
				INTERNET_BENCHMARK:ForgetRealmRequest(910003)

				expect(#messages).to.equal(0)
			end
		},

		{
			name = "Warns when a request expires before a reply arrives",
			func = function()
				local asked = fakePlayer()
				local timeout = INTERNET_BENCHMARK.RealmRequestTimeout

				INTERNET_BENCHMARK.RealmRequestTimeout = -1
				INTERNET_BENCHMARK:TrackRealmRequest(910004, asked)
				INTERNET_BENCHMARK.RealmRequestTimeout = timeout

				local accepted
				local messages = captureLog("Warning", function()
					accepted = INTERNET_BENCHMARK:AcceptRealmReply(910004, asked)
				end)

				expect(accepted).to.beFalse()
				expect(#messages).to.equal(1)
			end
		},

		{
			name = "Rejects a second reply to an already-answered request",
			func = function()
				local asked = fakePlayer()
				INTERNET_BENCHMARK:TrackRealmRequest(910005, asked)
				INTERNET_BENCHMARK:ForgetRealmRequest(910005)

				local accepted
				captureLog("Error", function()
					accepted = INTERNET_BENCHMARK:AcceptRealmReply(910005, asked)
				end)

				expect(accepted).to.beFalse()
			end
		},

		{
			name = "Drops a disconnecting player's outstanding requests",
			func = function()
				local leaving, staying = fakePlayer("STEAM_0:0:33"), fakePlayer("STEAM_0:0:44")
				INTERNET_BENCHMARK:TrackRealmRequest(910006, leaving)
				INTERNET_BENCHMARK:TrackRealmRequest(910007, staying)

				hook.GetTable().PlayerDisconnected.InternetBenchmarkRealmCleanup(leaving)

				local dropped, kept
				captureLog("Error", function()
					dropped = INTERNET_BENCHMARK:AcceptRealmReply(910006, leaving)
					kept = INTERNET_BENCHMARK:AcceptRealmReply(910007, staying)
				end)
				INTERNET_BENCHMARK:ForgetRealmRequest(910007)

				expect(dropped).to.beFalse()
				expect(kept).to.beTrue()
			end
		},

		{
			name = "Names a rejected sender by SteamID, never by their nickname",
			func = function()
				local ply = fakePlayer("STEAM_0:1:9999999", "Suite] a forged console line [")

				local messages = captureLog("Error", function()
					INTERNET_BENCHMARK:AcceptRealmReply(910008, ply)
				end)

				expect(#messages).to.equal(1)
				expect(string.find(messages[1], "STEAM_0:1:9999999", 1, true) ~= nil).to.beTrue()
				expect(string.find(messages[1], "a forged console line", 1, true) == nil).to.beTrue()
			end
		},

		{
			name = "Coalesces a burst of rejections into one report carrying the count",
			func = function()
				local messages = {}
				local originalLog = INTERNET_BENCHMARK.Logging.Error
				local originalInterval = INTERNET_BENCHMARK.RealmRejectLogInterval

				INTERNET_BENCHMARK.Logging.Error = function(message)
					table.insert(messages, message)
				end

				INTERNET_BENCHMARK.RealmRejectLogInterval = 0
				INTERNET_BENCHMARK:AcceptRealmReply(910010, fakePlayer())

				INTERNET_BENCHMARK.RealmRejectLogInterval = 3600
				INTERNET_BENCHMARK:AcceptRealmReply(910011, fakePlayer())
				INTERNET_BENCHMARK:AcceptRealmReply(910012, fakePlayer())

				INTERNET_BENCHMARK.RealmRejectLogInterval = 0
				INTERNET_BENCHMARK:AcceptRealmReply(910013, fakePlayer())

				INTERNET_BENCHMARK.Logging.Error = originalLog
				INTERNET_BENCHMARK.RealmRejectLogInterval = originalInterval

				expect(#messages).to.equal(2)
				expect(string.find(messages[2], "2 further rejection(s) suppressed", 1, true) ~= nil).to.beTrue()
			end
		},

		{
			name = "Sends every chunk of a payload to a target that stays connected",
			func = function(state)
				captureNet(state, stub)

				withChunkSize(8, function()
					local sent = INTERNET_BENCHMARK:SendChunkedString(leavingPlayer(), 920001, "text", string.rep("a", 24))

					expect(sent).to.beTrue()
					expect(#state.sent).to.equal(3)
				end)
			end
		},

		{
			name = "Stops sending once the target leaves mid-payload",
			func = function(state)
				captureNet(state, stub)

				withChunkSize(8, function()
					local sent = INTERNET_BENCHMARK:SendChunkedString(leavingPlayer(1), 920002, "html", string.rep("a", 24))

					expect(sent).to.beFalse()
					expect(#state.sent).to.equal(1)
				end)
			end
		},

		{
			name = "Sends nothing at all when the target has already left",
			func = function(state)
				captureNet(state, stub)

				withChunkSize(8, function()
					local sent = INTERNET_BENCHMARK:SendChunkedString(leavingPlayer(0), 920003, "text", "short")

					expect(sent).to.beFalse()
					expect(#state.sent).to.equal(0)
				end)
			end
		},

		{
			name = "Sends to the server without needing a player",
			func = function(state)
				captureNet(state, stub)

				withChunkSize(8, function()
					local sent = INTERNET_BENCHMARK:SendChunkedString(nil, 920004, "text", string.rep("a", 16))

					expect(sent).to.beTrue()
					expect(#state.sent).to.equal(2)
				end)
			end
		}
	}
}
