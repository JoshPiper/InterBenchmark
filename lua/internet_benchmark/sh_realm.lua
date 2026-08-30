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

--- How long repeated rejections stay quiet after one is logged, since an unthrottled report would recreate the console flood this gate exists to stop.
BENCH.RealmRejectLogInterval = 10

local lastRejectAt, suppressedRejects = 0, 0

--- Identify a reply's sender for the log by SteamID only; a nickname is player-controlled text.
--- @param ply Player?
--- @return string
local function senderName(ply)
	if not IsValid(ply) then
		return "the server"
	end

	return ply:SteamID() or "an unidentified player"
end

--- Report a dropped reply, immediately for the first in a burst and then at most once per RealmRejectLogInterval.
--- @param message string
local function reportRejection(message)
	local now = SysTime()
	if now - lastRejectAt < BENCH.RealmRejectLogInterval then
		suppressedRejects = suppressedRejects + 1
		return
	end

	if suppressedRejects > 0 then
		message = string.format("%s (%d further rejection(s) suppressed)", message, suppressedRejects)
	end

	lastRejectAt, suppressedRejects = now, 0
	BENCH.Logging.Error(message)
end

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

--- Whether a reply may be acted on: net receivers are open to every connected player, so it must answer a request this realm sent, from the party it went to.
--- @param requestId integer
--- @param ply Player? The sender, as passed to the net receiver (nil serverside means the server itself).
--- @return boolean
function BENCH:AcceptRealmReply(requestId, ply)
	local request = outstanding[requestId]
	if not request then
		reportRejection(string.format("Dropped an unsolicited realm reply for request #%d from %s.", requestId, senderName(ply)))
		return false
	end

	if SysTime() > request.expiry then
		self:ExpireRealmRequest(requestId)
		return false
	end

	if SERVER and not (IsValid(ply) and request.ply == ply) then
		reportRejection(string.format("Dropped a realm reply for request #%d from %s, which was not the player it was sent to.", requestId, senderName(ply)))
		return false
	end

	return true
end

--- Drop a request that ran out of time, warning so a run that never reported back is visible rather than silent.
--- @param requestId integer
function BENCH:ExpireRealmRequest(requestId)
	if not outstanding[requestId] then
		return
	end

	self.Logging.Warning(string.format("Realm request #%d timed out after %d seconds without a complete reply.", requestId, self.RealmRequestTimeout))
	self:ForgetRealmRequest(requestId)
end

--- Sweep timed-out requests, so a reply that never arrives is reported rather than sitting outstanding.
timer.Create("InternetBenchmarkRealmSweep", 60, 0, function()
	local now = SysTime()
	for requestId, request in pairs(outstanding) do
		if now > request.expiry then
			BENCH:ExpireRealmRequest(requestId)
		end
	end
end)

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

--- Take one chunk of a reply into its buffer, reassembling as they arrive.
--- @param requestId integer The request the chunk belongs to.
--- @param index integer The chunk's position within the reply, from 1.
--- @param count integer How many chunks the reply is split into.
--- @param chunk string
--- @return string? # The whole payload, once its last chunk has arrived.
--- @return table? # {reason = "oversize"}, or {reason = "incomplete", position = n}, when the reply was dropped.
function BENCH:TakeChunk(requestId, index, count, chunk)
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

	if buffer.size > self.RealmMaxReplyBytes then
		self:ForgetRealmRequest(requestId)
		return nil, {reason = "oversize"}
	end

	if index < count then
		return nil
	end

	for position = 1, count do
		if not buffer[position] then
			self:ForgetRealmRequest(requestId)
			return nil, {reason = "incomplete", position = position}
		end
	end

	local payload = table.concat(buffer, "", 1, count)
	self:ForgetRealmRequest(requestId)

	return payload
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
		reportRejection(string.format("Dropped a malformed realm reply for request #%d from %s: chunk %d of %d, %d bytes.", requestId, senderName(ply), index, count, len))
		BENCH:ForgetRealmRequest(requestId)
		return
	end

	local chunk = net.ReadData(len)

	local payload, failure = BENCH:TakeChunk(requestId, index, count, chunk)
	if failure then
		if failure.reason == "oversize" then
			reportRejection(string.format("Realm reply for request #%d from %s exceeded the %d byte reassembly limit; dropped.", requestId, senderName(ply), BENCH.RealmMaxReplyBytes))
		else
			reportRejection(string.format("Dropped an incomplete realm reply for request #%d from %s: chunk %d of %d never arrived.", requestId, senderName(ply), failure.position, count))
		end

		return
	end

	if not payload then
		return
	end

	-- Set by whichever of sv_realm.lua/cl_realm.lua loaded for this realm.
	if BENCH.OnRealmResult then
		BENCH:OnRealmResult(requestId, kind, payload)
	end
end)
