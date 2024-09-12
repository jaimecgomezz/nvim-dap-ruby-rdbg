---@class Options
---@field nonstop? boolean Globally indicate if the `nonstop` flag should be provided to `rdbg`
---@field rdbg_path? string The path to the `rdbg` executable, default 'rdbg'
---@field configurations? Configuration[] The list of user-provided configurations, default {}
---@field should_include_default_configurations? boolean Indicates if the default configurations should be included

---@class Configuration
---@field name string The config name
---@field type? string The debugger to use, default 'ruby'
---@field args? string[] The arguments provided to `rdbg`
---@field nonstop? boolean Should the `nonstop` flag be provided to `rdbg`?
---@field request? 'launch'|'attach' Indicates whether the debug adapter should launch a debbugee or attach to one. It default to 'launch' if any `args` or `target` is provided, false otherwise
---@field target? 'line'|'file'|'workspace'|string The target that `rdbg` should execute
---      - "line": The line at cursor position
---      - "file":  The file currently opened
---      - "workspace": The current working directory

---@class Plugin
---@field setup fun(opts: Options): Options
---@field default_configurations Configuration[]
local M = {}

M.default_configurations = {
	{
		name = "run file",
		args = { "ruby" },
		target = "file",
		nonstop = false,
	},
	{
		name = "rspec line",
		args = { "rspec" },
		target = "line",
	},
	{
		name = "rspec file",
		args = { "rspec" },
		target = "file",
	},
	{
		name = "rspec project",
		args = { "rspec" },
	},
	{
		name = "run file (bundle)",
		args = { "bundle", "exec", "ruby" },
		target = "file",
	},
	{
		name = "rspec line (bundle)",
		args = { "bundle", "exec", "rspec" },
		target = "line",
	},
	{
		name = "rspec file (bundle)",
		args = { "bundle", "exec", "rspec" },
		target = "file",
	},
	{
		name = "rspec project (bundle)",
		args = { "bundle", "exec", "rspec" },
	},
	{
		name = "rails server",
		args = { "rails", "server" },
	},
	{
		name = "rails server (bin)",
		args = { "bin/rails", "server" },
	},
	{
		name = "rails server (bundle)",
		args = { "bundle", "exec", "rails", "server" },
	},
	{
		name = "attach to debugger",
	},
}

local function append(table, element)
	table[#table + 1] = element

	return table
end

local function concat(t1, t2)
	for _, item in ipairs(t2) do
		t1 = append(t1, item)
	end

	return t1
end

local function safe_require(name)
	local ok, package = pcall(require, name)
	assert(ok, "Missing dependency: " .. name)
	return package
end

local function get_port(should_request_user)
	local port

	if should_request_user then
		vim.ui.input({ prompt = "Select port to connect to: " }, function(input)
			port = input
		end)
	else
		local tcp = assert(vim.uv.new_tcp(), "Must be able to create tcp client")
		tcp:bind("127.0.0.1", 0)
		port = tcp:getsockname().port
		tcp:shutdown()
		tcp:close()
	end

	return port
end

local function has_valid_target(target)
	return type(target) == "string"
end

local function has_valid_args(args)
	if type(args) ~= "table" then
		return false
	end

	if vim.tbl_isempty(args) then
		return false
	end

	for _, arg in ipairs(args) do
		if type(arg) ~= "string" then
			return false
		end
	end

	return true
end

local function spawns_debbugger(config)
	if has_valid_args(config.args) then
		return true
	end

	if has_valid_target(config.target) then
		return true
	end

	return false
end

local function handle_args(config)
	local args = {}

	-- The `nonstop` flag indicates to `rdbg` that it SHOULD NOT stop at the
	-- beggining of the program being debbugged. If not specified, it is set to
	-- `false`.
	--
	-- I've tested the behavior of this flag on Linux and MacOS, and I've seen
	-- weird results; on Linux the flag being set to `false` allows `nvim-dap`
	-- to correctly handle breakpoints, while on MacOS, setting it to `true`
	-- grants the same output. That's why I've enabled the `nonstop` option as a
	-- global config, so anyone can test both options and use the one that fits
	-- their system.
	--
	-- I'm sure that there's a valid explanation for this, but for now this is
	-- good enough.
	--
	-- Please see:
	--      - https://github.com/ruby/debug?tab=readme-ov-file#use-rdbg-with-commands-written-in-ruby
	--      - https://github.com/ruby/debug?tab=readme-ov-file#invoke-as-a-remote-debuggee
	if config.nonstop then
		args = append(args, "--nonstop")
	end

    -- Handle connectivity arguments needed for `nvim-dap` and `rdbg` to
    -- communicate via TCP/IP
    -- stylua: ignore
    args = concat(args, {
        "--open",
        "--host", config.host,
        "--port", config.port,
    })

	-- Handle user-provided arguments, like `rspec ...`, `bundle ...`, etc
	if has_valid_args(config.args) then
		args = concat(args, { "--command", "--", unpack(config.args) })
	end

	-- Handle dynamic target:
	--      - line: line at cursor position
	--      - file: currently opened file
	--      - workspace: cwd
	if has_valid_target(config.target) then
		if config.target == "workspace" then
			args = append(args, vim.fn.getcwd())
		elseif config.target == "file" then
			args = append(args, vim.fn.expand("%:p"))
		elseif config.target == "line" then
			args = append(args, vim.fn.expand("%:p") .. ":" .. vim.fn.line("."))
		else
			args = append(args, config.target)
		end
	end

	return args
end

local function generate_adapter(opts)
	return function(callback, config)
		local will_spawn_debbugger = spawns_debbugger(config)

		config.cwd = config.cwd or vim.fn.getcwd()
		config.host = config.host or "127.0.0.1"
		config.port = config.port or (will_spawn_debbugger and get_port(false) or get_port(true))

		assert(config.port, "A port is required in order to run debugger")

		local configured = {
			type = "server",
			host = config.host,
			port = config.port,
		}

		if will_spawn_debbugger then
			configured.executable = {
				cwd = config.cwd,
				command = opts.rdbg_path,
				args = handle_args(config),
			}
		end

		callback(configured)
	end
end

local function generate_configurations(opts)
	local configurations = {}

	-- Conditionally include default configurations
	if opts.should_include_default_configurations then
		configurations = concat(configurations, M.default_configurations)
	end

	-- Include user-provided configurations, if any
	configurations = concat(configurations, opts.configurations)

	for index, config in ipairs(configurations) do
		configurations[index] = vim.tbl_extend("keep", config, {
			type = "ruby",
			localfs = true, -- Why the hell is this needed? Not sure
			nonstop = opts.nonstop == nil and false or opts.nonstop,
			request = spawns_debbugger(config) and "launch" or "attach",
		})
	end

	return configurations
end

M.setup = function(opts)
	local dap = safe_require("dap")

	-- Handle default config values
	opts = vim.tbl_extend("keep", opts or {}, {
		nonstop = false,
		rdbg_path = "rdbg",
		configurations = {},
		should_include_default_configurations = true,
	})

	dap.adapters.ruby = generate_adapter(opts)
	dap.configurations.ruby = generate_configurations(opts)

	return opts
end

return M
