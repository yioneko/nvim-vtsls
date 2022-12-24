local co = coroutine

local M = {}

function M.wrap(func, res, rej)
	local thread = co.create(func)
	local step
	step = function(...)
		local args = { ... }
		local ok, nxt = co.resume(thread, unpack(args))
		if co.status(thread) ~= "dead" then
			local _, err = pcall(nxt, step)
			if err then
				rej(err)
			end
		elseif ok then
			res(unpack(args))
		else
			rej(nxt)
		end
	end

	step()
end

function M.async_call(func, ...)
	local args = { ... }
	return co.yield(function(cb)
		table.insert(args, cb)
		func(unpack(args))
	end)
end

function M.schedule()
	return co.yield(function(cb)
		vim.schedule(cb)
	end)
end

function M.request(client, method, params, bufnr)
	return co.yield(function(cb)
		client.request(method, params, cb, bufnr)
	end)
end

return M
