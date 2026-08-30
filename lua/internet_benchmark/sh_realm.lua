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

--- How long a sent request stays willing to accept a reply. Generous, since a full suite run takes minutes.
BENCH.RealmRequestTimeout = 1800

--- Largest reply this realm will reassemble, well above a full HTML report.
BENCH.RealmMaxReplyBytes = 32 * 1024 * 1024

--- Requests this realm has sent and is still expecting a reply to, keyed by request ID.
local outstanding = {}

--- Reassembly buffers for in-flight replies, keyed by request ID.
local pending = {}

--- Record that this realm sent a request, so its reply can be told apart from an unsolicited one.
--- @param requestId integer
--- @param ply Player? The client the request went to, or nil when it went to the server.
function BENCH:TrackRealmRequest(requestId, ply)
	outstanding[requestId] = {ply = ply, expiry = SysTime() + self.RealmRequestTimeout}
end

--- Stop expecting a reply, and drop any partial reassembly for it.
--- @param requestId integer
function BENCH:ForgetRealmRequest(requestId)
	outstanding[requestId] = nil
	pending[requestId] = nil
end

--- Whether a reply may be acted on: it must answer a request this realm actually sent, and come from the party it was sent to.
--- Without this the server would act on any client's unsolicited "reply", since net receivers are open to every connected player.
--- @param requestId integer
--- @param ply Player? The sender, as passed to the net receiver (nil serverside means the server itself).
--- @return boolean
function BENCH:AcceptRealmReply(requestId, ply)
	local request = outstanding[requestId]
	if not request then
		return false
	end

	if SysTime() > request.expiry then
		self:ForgetRealmRequest(requestId)
		return false
	end

	if SERVER then
		return IsValid(ply) and request.ply == ply
	end

	return true
end

if SERVER then
	hook.Add("PlayerDisconnected", "InternetBenchmarkRealmCleanup", function(ply)
		for requestId, request in pairs(outstanding) do
			if request.ply == ply then
				BENCH:ForgetRealmRequest(requestId)
			end
		end
	end)
end

--- Send a small JSON request to the other realm, or to one specific client.
--- @param ply Player? The target client, or nil to send to the server.
--- @param requestId integer
--- @param params table Plain request data (kind, name, flags, ...).
function BENCH:SendRealmRequest(ply, requestId, params)
	self:TrackRealmRequest(requestId, ply)

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

net.Receive("ib_realm_result", function(_, ply)
	local requestId = net.ReadUInt(32)
	local index = net.ReadUInt(16)
	local count = net.ReadUInt(16)
	local kind = net.ReadString()
	local len = net.ReadUInt(32)

	-- Checked before the payload is read, so a forged reply costs no allocation.
	if not BENCH:AcceptRealmReply(requestId, ply) then
		return
	end

	if index < 1 or index > count or len > BENCH.RealmChunkSize then
		BENCH:ForgetRealmRequest(requestId)
		return
	end

	local chunk = net.ReadData(len)

	local buffer = pending[requestId]
	if not buffer then
		buffer = {size = 0}
		pending[requestId] = buffer
	end

	if buffer[index] then
		buffer.size = buffer.size - #buffer[index]
	end
	buffer[index] = chunk
	buffer.size = buffer.size + #chunk

	if buffer.size > BENCH.RealmMaxReplyBytes then
		BENCH:ForgetRealmRequest(requestId)
		return
	end

	if index < count then
		return
	end

	for position = 1, count do
		if not buffer[position] then
			BENCH:ForgetRealmRequest(requestId)
			return
		end
	end

	local payload = table.concat(buffer, "", 1, count)
	BENCH:ForgetRealmRequest(requestId)

	-- Set by whichever of sv_realm.lua/cl_realm.lua loaded for this realm.
	if BENCH.OnRealmResult then
		BENCH:OnRealmResult(requestId, kind, payload)
	end
end)
