--- The realm bridge's reply-acceptance gate and its rejection reporting. The net relay around it still needs a manual check (see the README).

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

return {
	groupName = "Internet's Benchmark Suite: Realm",

	cases = {
		{
			name = "Rejects a reply for a request this realm never sent, loudly",
			func = function()
				local accepted
				local messages = captureLog("ForceError", function()
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
				local messages = captureLog("ForceError", function()
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

				local messages = captureLog("ForceError", function()
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
				local messages = captureLog("ForceWarning", function()
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
				captureLog("ForceError", function()
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
				captureLog("ForceError", function()
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

				local messages = captureLog("ForceError", function()
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
				local originalLog = INTERNET_BENCHMARK.Logging.ForceError
				local originalInterval = INTERNET_BENCHMARK.RealmRejectLogInterval

				INTERNET_BENCHMARK.Logging.ForceError = function(message)
					table.insert(messages, message)
				end

				INTERNET_BENCHMARK.RealmRejectLogInterval = 0
				INTERNET_BENCHMARK:AcceptRealmReply(910010, fakePlayer())

				INTERNET_BENCHMARK.RealmRejectLogInterval = 3600
				INTERNET_BENCHMARK:AcceptRealmReply(910011, fakePlayer())
				INTERNET_BENCHMARK:AcceptRealmReply(910012, fakePlayer())

				INTERNET_BENCHMARK.RealmRejectLogInterval = 0
				INTERNET_BENCHMARK:AcceptRealmReply(910013, fakePlayer())

				INTERNET_BENCHMARK.Logging.ForceError = originalLog
				INTERNET_BENCHMARK.RealmRejectLogInterval = originalInterval

				expect(#messages).to.equal(2)
				expect(string.find(messages[2], "2 further rejection(s) suppressed", 1, true) ~= nil).to.beTrue()
			end
		}
	}
}
