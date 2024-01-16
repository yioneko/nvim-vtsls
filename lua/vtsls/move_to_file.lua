local async = require("vtsls.async")
local o = require("vtsls.config")

local path_sep = package.config:sub(1, 1)

local function exec_command(bufnr, client, command, args)
	return async.request(client, "workspace/executeCommand", {
		command = command,
		arguments = args,
	}, bufnr)
end

local function to_file_range_request_args(file, range)
	return {
		file = file,
		startLine = range.start.line + 1,
		startOffset = range.start.character + 1,
		endLine = range["end"].line + 1,
		endOffset = range["end"].character + 1,
	}
end

local path_display_strategies = {
	default = function(path)
		return vim.fn.fnamemodify(path, ":.")
	end,
	vscode = function(path)
		return vim.fn.fnamemodify(path, ":t") .. " ▏" .. vim.fn.fnamemodify(path, ":.")
	end,
}

return function(client)
	local function get_target_file(uri, range)
		local bufnr = vim.uri_to_bufnr(uri)
		local fname = vim.uri_to_fname(uri)
		local err, response = exec_command(
			bufnr,
			client,
			"typescript.tsserverRequest",
			{ "getMoveToRefactoringFileSuggestions", to_file_range_request_args(fname, range) }
		)
		if err or response.type ~= "response" or not response.body then
			error("get candidate target files failed: " .. vim.inspect(response))
		end

		local files = response.body.files
		local items = { { "", "Enter new file path..." } }

		local path_display = o.get().refactor_move_to_file.path_display
		if type(path_display) == "string" then
			path_display = path_display_strategies[path_display]
		end

		async.schedule()
		for i = 1, #files do
			local path = files[i]
			table.insert(items, { path, path_display(path) })
		end

		local item, idx = async.call(vim.ui.select, items, {
			prompt = "Select move destination:",
			format_item = function(item)
				return item[2]
			end,
		})

		if not item then -- selection cancelled
			return
		end

		if idx == 1 then
			return async.call(vim.ui.input, {
				prompt = "Enter move destination:",
				default = vim.fn.fnamemodify(fname, ":h") .. path_sep,
				completion = "file",
			})
		else
			return item[1]
		end
	end

	local function move_to_file_handler(command)
		async.exec(function()
			local args = command.arguments
			local action = args[1]
			local uri = args[2]
			local range = args[3]

			local bufnr = vim.uri_to_bufnr(uri)
			local target_file = get_target_file(uri, range)

			if target_file then
				exec_command(bufnr, client, command.command, { action, uri, range, target_file })
			end
		end, o.get().default_resolve, o.get().default_reject)
	end

	return move_to_file_handler
end
