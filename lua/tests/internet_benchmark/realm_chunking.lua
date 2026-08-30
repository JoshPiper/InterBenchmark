--- The realm bridge's chunking and reassembly, driven end to end with the
--- net writes captured rather than sent. The transport itself still needs a
--- manual check (see the README).

--- Captures each net message SendChunkedString produces, in order.
--- Field order follows the writes in SendChunkedString. stub is passed in
--- because GLuaTest injects it into a case function's own environment,
--- which a helper defined out here does not share.
local function captureNet(state, stub)
	state.sent = {}

	local current
	stub(net, "Start").with(function()
		current = {uints = {}}
		table.insert(state.sent, current)
	end)
	stub(net, "WriteUInt").with(function(value)
		table.insert(current.uints, value)
	end)
	stub(net, "WriteString").with(function(value)
		current.kind = value
	end)
	stub(net, "WriteData").with(function(data)
		current.data = data
	end)
	stub(net, "Send")
	stub(net, "SendToServer")
end

--- Feed captured messages back through reassembly, as the receiver would.
--- @return string? # The payload, once the reply completes.
local function reassemble(sent)
	local payload
	for _, message in ipairs(sent) do
		payload = INTERNET_BENCHMARK:TakeChunk(message.uints[1], message.uints[2], message.uints[3], message.data)
	end

	return payload
end

--- Send a payload and reassemble it, returning both ends of the round trip.
local function roundTrip(state, requestId, payload)
	INTERNET_BENCHMARK:SendChunkedString(nil, requestId, "text", payload)
	return reassemble(state.sent), #state.sent
end

return {
	groupName = "Internet's Benchmark Suite: Realm Chunking",

	beforeEach = function(state)
		state.chunkSize = INTERNET_BENCHMARK.RealmChunkSize
		INTERNET_BENCHMARK.RealmChunkSize = 8
	end,

	afterEach = function(state)
		INTERNET_BENCHMARK.RealmChunkSize = state.chunkSize
	end,

	cases = {
		{
			name = "Round-trips a payload shorter than one chunk",
			func = function(state)
				captureNet(state, stub)

				local payload, count = roundTrip(state, 1, "short")

				expect(count).to.equal(1)
				expect(payload).to.equal("short")
			end
		},

		{
			name = "Round-trips a payload that fills its chunks exactly",
			func = function(state)
				captureNet(state, stub)

				local original = string.rep("ab", 12)
				local payload, count = roundTrip(state, 2, original)

				expect(count).to.equal(3)
				expect(payload).to.equal(original)
			end
		},

		{
			name = "Round-trips a payload whose last chunk is a remainder",
			func = function(state)
				captureNet(state, stub)

				local original = string.rep("c", 19)
				local payload, count = roundTrip(state, 3, original)

				expect(count).to.equal(3)
				expect(#state.sent[3].data).to.equal(3)
				expect(payload).to.equal(original)
			end
		},

		{
			name = "Sends one empty chunk for an empty payload",
			func = function(state)
				captureNet(state, stub)

				local payload, count = roundTrip(state, 4, "")

				expect(count).to.equal(1)
				expect(payload).to.equal("")
			end
		},

		{
			name = "Round-trips binary content byte for byte",
			func = function(state)
				captureNet(state, stub)

				local original = string.char(0, 255, 10, 13, 0, 128) .. "tail" .. string.char(0)
				local payload = roundTrip(state, 5, original)

				expect(payload).to.equal(original)
			end
		},

		{
			name = "Reports each chunk's position and the reply's total",
			func = function(state)
				captureNet(state, stub)

				INTERNET_BENCHMARK:SendChunkedString(nil, 6, "html", string.rep("d", 20))

				expect(#state.sent).to.equal(3)
				for index, message in ipairs(state.sent) do
					expect(message.uints[1]).to.equal(6)
					expect(message.uints[2]).to.equal(index)
					expect(message.uints[3]).to.equal(3)
					expect(message.uints[4]).to.equal(#message.data)
					expect(message.kind).to.equal("html")
				end
			end
		},

		{
			name = "Keeps two replies apart while their chunks interleave",
			func = function(state)
				captureNet(state, stub)

				INTERNET_BENCHMARK:SendChunkedString(nil, 7, "text", string.rep("a", 16))
				local first = state.sent

				state.sent = {}
				INTERNET_BENCHMARK:SendChunkedString(nil, 8, "text", string.rep("b", 16))
				local second = state.sent

				-- Interleaved: first[1], second[1], first[2], second[2].
				local function take(message)
					return INTERNET_BENCHMARK:TakeChunk(message.uints[1], message.uints[2], message.uints[3], message.data)
				end

				expect(take(first[1])).to.beNil()
				expect(take(second[1])).to.beNil()
				expect(take(first[2])).to.equal(string.rep("a", 16))
				expect(take(second[2])).to.equal(string.rep("b", 16))
			end
		},

		{
			name = "Releases a reply's buffer once it completes, so the id can be reused",
			func = function(state)
				captureNet(state, stub)

				local first = roundTrip(state, 9, string.rep("a", 16))
				expect(first).to.equal(string.rep("a", 16))

				state.sent = {}
				local second = roundTrip(state, 9, "reused")
				expect(second).to.equal("reused")
			end
		},

		{
			name = "Reports a reply that outgrows the reassembly limit",
			func = function()
				INTERNET_BENCHMARK.RealmMaxReplyBytes = 12

				local payload, failure = INTERNET_BENCHMARK:TakeChunk(10, 1, 3, string.rep("a", 8))
				expect(payload).to.beNil()
				expect(failure).to.beNil()

				payload, failure = INTERNET_BENCHMARK:TakeChunk(10, 2, 3, string.rep("b", 8))
				expect(payload).to.beNil()
				expect(failure.reason).to.equal("oversize")
			end
		},

		{
			name = "Reports the missing chunk when a reply's last one arrives without it",
			func = function()
				local payload, failure = INTERNET_BENCHMARK:TakeChunk(11, 2, 2, "second")

				expect(payload).to.beNil()
				expect(failure.reason).to.equal("incomplete")
				expect(failure.position).to.equal(1)
			end
		},

		{
			name = "Drops the buffer of a reply that outgrew the limit, so the id starts clean",
			func = function()
				INTERNET_BENCHMARK.RealmMaxReplyBytes = 12

				INTERNET_BENCHMARK:TakeChunk(12, 1, 2, string.rep("a", 8))
				local _, failure = INTERNET_BENCHMARK:TakeChunk(12, 2, 2, string.rep("b", 8))
				expect(failure.reason).to.equal("oversize")

				INTERNET_BENCHMARK.RealmMaxReplyBytes = 12000
				local payload = INTERNET_BENCHMARK:TakeChunk(12, 1, 1, "fresh")
				expect(payload).to.equal("fresh")
			end
		},

		{
			name = "Counts a resent chunk once, not twice, against the limit",
			func = function()
				INTERNET_BENCHMARK.RealmMaxReplyBytes = 12

				INTERNET_BENCHMARK:TakeChunk(13, 1, 2, string.rep("a", 8))
				INTERNET_BENCHMARK:TakeChunk(13, 1, 2, string.rep("c", 8))

				local payload, failure = INTERNET_BENCHMARK:TakeChunk(13, 2, 2, "dd")
				expect(failure).to.beNil()
				expect(payload).to.equal(string.rep("c", 8) .. "dd")
			end
		}
	}
}
