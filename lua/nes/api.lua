local nvim_version = vim.version()

local M = {}

local _oauth_token
local _api_token

---@class nes.util.Curl
local Curl = {}

function Curl.request(method, url, opts)
	opts = opts or {}
	local bin = opts.binary or "curl"
	local args = { bin, "-sSL", url, "-X", method }
	for key, value in pairs(opts.headers or {}) do
		table.insert(args, "-H")
		table.insert(args, key .. ": " .. value)
	end
	if opts.body then
		table.insert(args, "-d")
		table.insert(args, "@-")
	end
	return vim.system(args, {
		stdin = opts.body,
		text = true,
		stdout = opts.stdout,
		stderr = opts.stderr,
	}, opts.on_exit)
end

function Curl.get(url, opts)
	return Curl.request("GET", url, opts)
end

function Curl.post(url, opts)
	return Curl.request("POST", url, opts)
end

local function get_oauth_token()
	if _oauth_token then
		return _oauth_token
	end

	local config_dir = vim.env.XDG_CONFIG_HOME or vim.fs.joinpath(vim.env.HOME, "/.config")

	local config_paths = {
		"github-copilot/apps.json",
		"github-copilot/hosts.json",
	}

	for _, path in pairs(config_paths) do
		local config_path = vim.fs.joinpath(config_dir, path)
		if vim.uv.fs_stat(config_path) then
			local data = vim.fn.readfile(config_path, "")
			if vim.islist(data) then
				data = table.concat(data, "\n")
			end
			local apps = vim.json.decode(data)
			for key, value in pairs(apps) do
				if vim.startswith(key, "github.com") then
					_oauth_token = value.oauth_token
					return _oauth_token
				end
			end
		end
	end
end

local function with_token(cb)
	if _api_token and _api_token.expires_at > os.time() + 60 then
		cb(_api_token)
	end

	local oauth_token = get_oauth_token()
	if not oauth_token then
		error("OAuth token not found")
	end

	return Curl.get("https://api.github.com/copilot_internal/v2/token", {
		headers = {
			Authorization = "Bearer " .. oauth_token,
			["Accept"] = "application/json",
			["User-Agent"] = "vscode-chat/dev",
		},
		on_exit = function(out)
			if out.code ~= 0 then
				error(out.stderr or out.stdout or ("code: " .. out.code))
				return
			end
			_api_token = vim.json.decode(out.stdout)
			cb(_api_token)
		end,
	})
end

function M._call(base_url, api_key, payload, callback)
	local _request = Curl.post(base_url .. "/chat/completions", {
		headers = {
			Authorization = "Bearer " .. api_key,
			["User-Agent"] = "vscode-chat/dev",
			["Content-Type"] = "application/json",
			["Copilot-Integration-Id"] = "vscode-chat",
			["editor-version"] = ("Neovim/%d.%d.%d"):format(nvim_version.major, nvim_version.minor, nvim_version.patch),
			["editor-plugin-version"] = "nes/0.1.0",
		},
		body = vim.json.encode(payload),
		on_exit = function(out)
			if out.code ~= 0 then
				callback("")
				error(out.stderr or ("code: " .. out.code))
				return
			end
			local stdout = out.stdout
			local lines = vim.split(stdout, "\n", { plain = true })
			local chunks = {}
			for _, line in ipairs(lines) do
				line = vim.trim(line)
				if line ~= "" then
					if vim.startswith(line, "data: ") then
						line = line:sub(7)
					end
					if line ~= "[DONE]" then
						table.insert(chunks, line)
					end
				end
			end

			local json_chunks = string.format("[%s]", table.concat(chunks, ","))
			local ok, events = pcall(vim.json.decode, json_chunks)
			if not ok then
				callback("")
				return
			end

			local output = ""
			for _, event in ipairs(events) do
				if event.choices and event.choices[1] then
					local choice = event.choices[1]
					if choice.delta and choice.delta.content then
						output = output .. choice.delta.content
					end
				end
			end
			callback(output)
		end,
	})
end

function M.call(payload, callback)
	with_token(vim.schedule_wrap(function(api_token)
		local base_url = api_token.endpoints.proxy or api_token.endpoints.api
		M._call(base_url, api_token.token, payload, callback)
	end))
end

function M.debug()
	vim.print(_api_token)
end

return M
