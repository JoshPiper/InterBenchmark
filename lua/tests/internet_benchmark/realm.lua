--- The realm bridge's reply-acceptance gate. The net relay around it still needs a manual check (see the README).

local function fakePlayer()
	return {IsValid = function() return true end}
end

return {
	groupName = "Internet's Benchmark Suite: Realm",

	cases = {
		{
			name = "Rejects a reply for a request this realm never sent",
			func = function()
				expect(INTERNET_BENCHMARK:AcceptRealmReply(910001, fakePlayer())).to.beFalse()
			end
		},

		{
			name = "Rejects a reply from a player other than the one asked",
			func = function()
				local asked, forger = fakePlayer(), fakePlayer()
				INTERNET_BENCHMARK:TrackRealmRequest(910002, asked)

				local accepted = INTERNET_BENCHMARK:AcceptRealmReply(910002, forger)
				INTERNET_BENCHMARK:ForgetRealmRequest(910002)

				expect(accepted).to.beFalse()
			end
		},

		{
			name = "Accepts a reply from the player the request was sent to",
			func = function()
				local asked = fakePlayer()
				INTERNET_BENCHMARK:TrackRealmRequest(910003, asked)

				local accepted = INTERNET_BENCHMARK:AcceptRealmReply(910003, asked)
				INTERNET_BENCHMARK:ForgetRealmRequest(910003)

				expect(accepted).to.beTrue()
			end
		},

		{
			name = "Rejects a reply once the request has expired",
			func = function()
				local asked = fakePlayer()
				local timeout = INTERNET_BENCHMARK.RealmRequestTimeout

				INTERNET_BENCHMARK.RealmRequestTimeout = -1
				INTERNET_BENCHMARK:TrackRealmRequest(910004, asked)
				INTERNET_BENCHMARK.RealmRequestTimeout = timeout

				expect(INTERNET_BENCHMARK:AcceptRealmReply(910004, asked)).to.beFalse()
			end
		},

		{
			name = "Rejects a second reply to an already-answered request",
			func = function()
				local asked = fakePlayer()
				INTERNET_BENCHMARK:TrackRealmRequest(910005, asked)
				INTERNET_BENCHMARK:ForgetRealmRequest(910005)

				expect(INTERNET_BENCHMARK:AcceptRealmReply(910005, asked)).to.beFalse()
			end
		},

		{
			name = "Drops a disconnecting player's outstanding requests",
			func = function()
				local leaving, staying = fakePlayer(), fakePlayer()
				INTERNET_BENCHMARK:TrackRealmRequest(910006, leaving)
				INTERNET_BENCHMARK:TrackRealmRequest(910007, staying)

				hook.Run("PlayerDisconnected", leaving)

				local dropped = INTERNET_BENCHMARK:AcceptRealmReply(910006, leaving)
				local kept = INTERNET_BENCHMARK:AcceptRealmReply(910007, staying)
				INTERNET_BENCHMARK:ForgetRealmRequest(910007)

				expect(dropped).to.beFalse()
				expect(kept).to.beTrue()
			end
		}
	}
}
