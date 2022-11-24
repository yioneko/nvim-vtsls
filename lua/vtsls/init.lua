local o = require("vtsls.config")

local M = {
	commands = require("vtsls.commands"),
	config = o.override,
}

return M
