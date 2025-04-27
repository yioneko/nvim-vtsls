local o = require("vtsls.config")
local async = require("vtsls.async")
local compat = require("vtsls.compat")

local path_sep = package.config:sub(1, 1)

local function path_normalize(name)
	return vim.fn.fnamemodify(name, ":p")
end

local function trim_sep(path)
	return path:gsub(path_sep .. "$", "")
end

local function uri_from_path(path)
	return vim.uri_from_fname(trim_sep(path))
end

local function is_sub_path(path, folder)
	path = trim_sep(path)
	folder = trim_sep(folder)
	if path == folder then
		return true
	else
		return path:sub(1, #folder + 1) == folder .. path_sep
	end
end

local function get_clients_by_path(path)
	local clients = {}
	for _, client in pairs(compat.lsp_get_clients({ name = o.get().name })) do
		for _, folder in pairs(client.workspace_folders) do
			if is_sub_path(path, vim.uri_to_fname(folder.uri)) then
				table.insert(clients, client)
			end
		end
	end
	return clients
end

local function do_rename(client, old_path, new_path)
	async.schedule()
	-- try to create dir
	local new_dir = vim.fn.fnamemodify(new_path, ":h")
	if #new_dir > 0 then
		vim.fn.mkdir(new_dir, "p")
	end

	local old_exists = not async.call(vim.loop.fs_stat, old_path)
	-- only rename if the file exists
	if old_exists then
		local err = async.call(vim.loop.fs_rename, old_path, new_path)
		if err then
			error("uv rename failed " .. tostring(err))
		end
	end

	local old_path_with_sep = trim_sep(old_path) .. path_sep
	local new_path_with_sep = trim_sep(new_path) .. path_sep
	local force_write = function(bufnr)
		if vim.bo[bufnr].buftype == "" then
			vim.api.nvim_buf_call(bufnr, function()
				vim.cmd("silent write!")
			end)
		end
	end

	async.schedule()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
			local buf_name = vim.api.nvim_buf_get_name(buf)
			-- old_path is file
			if old_path == buf_name then
				vim.api.nvim_buf_set_name(buf, new_path)
				force_write(buf)
			elseif is_sub_path(buf_name, old_path) then
				-- new_path is dir
				vim.api.nvim_buf_set_name(buf, new_path_with_sep .. buf_name:sub(#old_path_with_sep + 1))
				force_write(buf)
			end
		end
	end

	if client:is_stopped() then
		error("client not active")
	end

	client:notify("workspace/didRenameFiles", {
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

	local clients = get_clients_by_path(old_path)
	if #clients == 0 then
		return rej("No client found")
	end

	async.exec(function()
		-- new path exists
		local _, stat = async.call(vim.loop.fs_stat, new_path)
		if stat then
			async.schedule()
			local yn =
				async.call(vim.ui.input, { prompt = "Overwrite '" .. vim.fn.fnamemodify(new_name, ":.") .. "'? y/n" })
			if yn == "y" then
				for _, client in pairs(clients) do
					do_rename(client, old_path, new_path)
				end
			end
		else
			for _, client in pairs(clients) do
				do_rename(client, old_path, new_path)
			end
		end
	end, res, rej)
end

return rename
