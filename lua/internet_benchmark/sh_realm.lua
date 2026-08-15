--- Cross-realm benchmark requests.
--- Lets a command typed on one realm ask the other realm to run, relaying
--- the result back to whoever typed it (see the '--realm' flag in
--- sh_commands.lua, and the realm-specific handlers in sv_realm.lua /
--- cl_realm.lua). The wire format is intentionally minimal: a small JSON
--- request, and a chunked, binary-safe string reply - used for the full
--- HTML report as well as the small text/rejection payloads, so there is
--- one reassembly path to get right instead of several.

INTERNET_BENCHMARK = INTERNET_BENCHMARK or {}
local BENCH = INTERNET_BENCHMARK

if SERVER then
	util.AddNetworkString("ib_realm_request")
	util.AddNetworkString("ib_realm_result")
end

--- Chunk size for realm result payloads, comfortably under the ~64KB a
--- single net message can carry.
BENCH.RealmChunkSize = 60000

local nextRequestId = 0

--- A fresh, per-realm request identifier, so a reply is only ever matched
--- to the request it belongs to.
--- @return integer
function BENCH:NextRealmRequestId()
	nextRequestId = (nextRequestId + 1) % 2 ^ 32
	return nextRequestId
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

--- Send a string to the other realm, or to one specific client, in
--- fixed-size, binary-safe chunks.
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

	-- Set by sv_realm.lua / cl_realm.lua, whichever of the two loaded for
	-- this realm - each realm only ever receives replies to requests it
	-- sent itself, so there is exactly one handler to dispatch to.
	if BENCH.OnRealmResult then
		BENCH:OnRealmResult(requestId, kind, payload)
	end
end)
