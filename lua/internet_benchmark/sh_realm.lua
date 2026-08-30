--- Cross-realm benchmark requests: relays a '--realm' command run to the other realm and back over a small JSON request plus a chunked, binary-safe reply (see sh_commands.lua, sv_realm.lua, cl_realm.lua).

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

if SERVER then
	util.AddNetworkString("ib_realm_request")
	util.AddNetworkString("ib_realm_result")
end

--- Chunk size for realm result payloads, comfortably under a net message's ~64KB limit.
BENCH.RealmChunkSize = 60000

local nextRequestId = 0

--- A fresh, per-realm request identifier, so replies match their own request.
--- @return integer
function BENCH:NextRealmRequestId()
	nextRequestId = (nextRequestId + 1) % 2 ^ 32
	return nextRequestId
end

--- How long a request this realm issued stays answerable, in seconds.
--- A run's length is bounded by the pump rather than by wall clock, so this
--- is deliberately generous: it exists only so an unanswered request cannot
--- sit in the table forever.
BENCH.RealmRequestTimeout = 30 * 60

--- Requests this realm issued and is still willing to accept a reply to.
local outstanding = {}

--- Record a request this realm just issued, so its reply can be recognised.
--- @param requestId integer
function BENCH:TrackRealmRequest(requestId)
	local now = SysTime()
	for id, expiry in pairs(outstanding) do
		if now > expiry then
			outstanding[id] = nil
		end
	end

	outstanding[requestId] = now + self.RealmRequestTimeout
end

--- Consume a request this realm issued, so each one is answerable once.
--- @param requestId integer
--- @return boolean # False for a reply nothing here asked for.
function BENCH:ClaimRealmRequest(requestId)
	local expiry = outstanding[requestId]
	outstanding[requestId] = nil

	return expiry ~= nil and SysTime() <= expiry
end

--- Send a small JSON request to the other realm, or to one specific client.
--- @param ply Player? The target client, or nil to send to the server.
--- @param requestId integer
--- @param params table Plain request data (kind, name, flags, ...).
function BENCH:SendRealmRequest(ply, requestId, params)
	net.Start("ib_realm_request")
	net.WriteUInt(requestId, 32)
	net.WriteString(util.TableToJSON(params))

	if ply then
		net.Send(ply)
	else
		net.SendToServer()
	end
end

--- Send a string to the other realm, or to one specific client, in fixed-size, binary-safe chunks.
--- @param ply Player? The target client, or nil to send to the server.
--- @param requestId integer The request this is a reply to.
--- @param kind string A short tag for the payload ("html", "text", "summary", "reject").
--- @param payload string
function BENCH:SendChunkedString(ply, requestId, kind, payload)
	local size = self.RealmChunkSize
	local count = math.max(1, math.ceil(#payload / size))

	for index = 1, count do
		local from = (index - 1) * size + 1
		local chunk = string.sub(payload, from, from + size - 1)

		net.Start("ib_realm_result")
		net.WriteUInt(requestId, 32)
		net.WriteUInt(index, 16)
		net.WriteUInt(count, 16)
		net.WriteString(kind)
		net.WriteUInt(#chunk, 32)
		net.WriteData(chunk, #chunk)

		if ply then
			net.Send(ply)
		else
			net.SendToServer()
		end
	end
end

--- Reassembly buffers for in-flight replies, keyed by request ID.
local pending = {}

net.Receive("ib_realm_result", function()
	local requestId = net.ReadUInt(32)
	local index = net.ReadUInt(16)
	local count = net.ReadUInt(16)
	local kind = net.ReadString()
	local len = net.ReadUInt(32)
	local chunk = net.ReadData(len)

	local buffer = pending[requestId]
	if not buffer then
		buffer = {}
		pending[requestId] = buffer
	end
	buffer[index] = chunk

	if index < count then
		return
	end

	pending[requestId] = nil
	local payload = table.concat(buffer, "", 1, count)

	-- Set by whichever of sv_realm.lua/cl_realm.lua loaded for this realm.
	if BENCH.OnRealmResult then
		BENCH:OnRealmResult(requestId, kind, payload)
	end
end)
