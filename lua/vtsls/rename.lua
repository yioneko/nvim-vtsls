local o = require("vtsls.config")
local async = require("vtsls.async")

local function get_client_by_path(path)
	local clients = vim.lsp.get_active_clients({ name = o.get().name })
	if #clients == 0 then
		return
	end

	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) then
			local name = vim.api.nvim_buf_get_name(buf)
			if vim.startswith(name, path) then
				for _, client in ipairs(clients) do
					if vim.lsp.buf_is_attached(buf, client.id) then
						return client
					end
				end
			end
		end
	end
end

local function path_normalize(name)
	return vim.fn.fnamemodify(name, ":p")
end

local path_sep = package.config:sub(1, 1)

local function uri_from_path(path)
	-- TODO: better trimming
	local fname = path:sub(#path) == path_sep and path:sub(1, #path - 1) or path
	return vim.uri_from_fname(fname)
end

local function do_rename(client, old_path, new_path)
	async.schedule()
	-- try to create dir
	local new_dir = vim.fn.fnamemodify(new_path, ":h")
	if #new_dir > 0 then
		vim.fn.mkdir(new_dir, "p")
	end

	local old_exists = not async.async_call(vim.loop.fs_stat, old_path)
	-- only rename if the file exists
	if old_exists then
		local err = async.async_call(vim.loop.fs_rename, old_path, new_path)
		if err then
			error("uv rename failed " .. tostring(err))
		end
	end

	local old_path_with_sep = vim.endswith(old_path, path_sep) and old_path or old_path .. path_sep
	local new_path_with_sep = vim.endswith(new_path, path_sep) and new_path or new_path .. path_sep
	local force_write = function(bufnr)
		vim.api.nvim_buf_call(bufnr, function()
			vim.cmd("silent write!")
		end)
	end

	async.schedule()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
			local buf_name = vim.api.nvim_buf_get_name(buf)
			-- old_path is file
			if old_path == buf_name then
				vim.api.nvim_buf_set_name(buf, new_path)
				force_write(buf)
			elseif vim.startswith(buf_name, old_path_with_sep) then
				-- new_path is dir
				vim.api.nvim_buf_set_name(buf, new_path_with_sep .. buf_name:sub(#old_path_with_sep + 1))
				force_write(buf)
			end
		end
	end

	if client.is_stopped() then
		error("client not active")
	end

	client.notify("workspace/didRenameFiles", {
		files = {
			{
				oldUri = uri_from_path(old_path),
				newUri = uri_from_path(new_path),
			},
		},
	})
end

local function rename(old_name, new_name, res, rej)
	res = res or o.get().default_resolve
	rej = rej or o.get().default_reject

	local old_path = path_normalize(old_name)
	local new_path = path_normalize(new_name)

	local client = get_client_by_path(old_path)
	if not client then
		return rej("No client found")
	end

	async.wrap(function()
		-- new path exists
		local _, stat = async.async_call(vim.loop.fs_stat, new_path)
		if stat then
			async.schedule()
			local yn = async.async_call(
				vim.ui.input,
				{ prompt = "Overwrite '" .. vim.fn.fnamemodify(new_name, ":.") .. "'? y/n" }
			)
			if yn == "y" then
				do_rename(client, old_path, new_path)
			end
		else
			do_rename(client, old_path, new_path)
		end
	end, res, rej)
end

return rename
