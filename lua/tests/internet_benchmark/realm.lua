--- The realm bridge's outstanding-request registry. The net relay around it needs a manual check (see the README).

return {
	groupName = "Internet's Benchmark Suite: Realm Bridge",

	beforeEach = function(state)
		state.timeout = INTERNET_BENCHMARK.RealmRequestTimeout
	end,

	afterEach = function(state)
		INTERNET_BENCHMARK.RealmRequestTimeout = state.timeout
	end,

	cases = {
		{
			name = "NextRealmRequestId hands out a fresh identifier each time",
			func = function()
				local first = INTERNET_BENCHMARK:NextRealmRequestId()
				local second = INTERNET_BENCHMARK:NextRealmRequestId()

				expect(first).to.beA("number")
				expect(second == first).to.beFalse()
			end
		},

		{
			name = "ClaimRealmRequest refuses a result nothing asked for",
			func = function()
				local requestId = INTERNET_BENCHMARK:NextRealmRequestId()

				expect(INTERNET_BENCHMARK:ClaimRealmRequest(requestId)).to.beFalse()
			end
		},

		{
			name = "ClaimRealmRequest accepts a result for a tracked request",
			func = function()
				local requestId = INTERNET_BENCHMARK:NextRealmRequestId()
				INTERNET_BENCHMARK:TrackRealmRequest(requestId)

				expect(INTERNET_BENCHMARK:ClaimRealmRequest(requestId)).to.beTrue()
			end
		},

		{
			name = "ClaimRealmRequest answers a tracked request only once",
			func = function()
				local requestId = INTERNET_BENCHMARK:NextRealmRequestId()
				INTERNET_BENCHMARK:TrackRealmRequest(requestId)

				expect(INTERNET_BENCHMARK:ClaimRealmRequest(requestId)).to.beTrue()
				expect(INTERNET_BENCHMARK:ClaimRealmRequest(requestId)).to.beFalse()
			end
		},

		{
			name = "ClaimRealmRequest refuses a request that has timed out",
			func = function()
				INTERNET_BENCHMARK.RealmRequestTimeout = -1

				local requestId = INTERNET_BENCHMARK:NextRealmRequestId()
				INTERNET_BENCHMARK:TrackRealmRequest(requestId)

				expect(INTERNET_BENCHMARK:ClaimRealmRequest(requestId)).to.beFalse()
			end
		},

		{
			name = "Tracking a request does not make another request claimable",
			func = function()
				local tracked = INTERNET_BENCHMARK:NextRealmRequestId()
				local untracked = INTERNET_BENCHMARK:NextRealmRequestId()
				INTERNET_BENCHMARK:TrackRealmRequest(tracked)

				expect(INTERNET_BENCHMARK:ClaimRealmRequest(untracked)).to.beFalse()
				expect(INTERNET_BENCHMARK:ClaimRealmRequest(tracked)).to.beTrue()
			end
		}
	}
}
