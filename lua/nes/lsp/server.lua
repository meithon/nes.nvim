local Methods = vim.lsp.protocol.Methods

local function notify(text, opts)
	opts = opts or {}
	opts.title = "[NES] " .. (opts.title or "")
	opts.level = opts.level or vim.log.levels.INFO
	vim.notify(text, opts.level, { title = opts.title })
end

---@class nes.DocumentContext
---@field original lsp.TextDocumentItem
---@field current lsp.TextDocumentItem
---@field pending_edits? nes.InlineEdit[]
---@field last_applied? integer

---@alias nes.Workspace table<string, nes.DocumentContext>

---@alias nes.MethodHandler fun(server:nes.Server, params: any, callback?: fun(lsp.ResponseError?, any))

---@class nes.Server
---@field dispatchers vim.lsp.rpc.Dispatchers
---@field private _workspace nes.Workspace
---@field private _initialized boolean
---@field private _client_initialized boolean
---@field private _running boolean
---@field private _next_message_id integer
---@field private _handlers table<string, nes.MethodHandler>
local Server = {}
Server.__index = Server

---@type lsp.ServerCapabilities
local capabilities = {
	textDocumentSync = 1,
	workspace = {
		workspaceFolders = {
			supported = true,
			changeNotifications = true,
		},
	},
}

---@param dispatchers vim.lsp.rpc.Dispatchers
---@return nes.Server
function Server.new(dispatchers)
	local self = setmetatable({
		dispatchers = dispatchers,
		_workspace = {},
		_next_message_id = 1,
		_initialized = false,
		_running = true,
		_handlers = {
			[Methods.initialize] = Server.on_initialize,
			[Methods.initialized] = Server.on_initialized,
			[Methods.textDocument_didOpen] = Server.on_did_open,
			[Methods.textDocument_didSave] = Server.on_did_save,
			[Methods.textDocument_didChange] = Server.on_did_change,
			[Methods.textDocument_didClose] = Server.on_did_close,
			["textDocument/copilotInlineEdit"] = Server.on_inline_edit,
		},
	}, Server)
	return self
end

---@return vim.lsp.rpc.PublicClient
function Server:new_public_client()
	return {
		request = function(...)
			return self:request(...)
		end,
		notify = function(...)
			return self:notify(...)
		end,
		is_closing = function()
			return self:is_closing()
		end,
		terminate = function()
			self:terminate()
		end,
	}
end

--- Receives a request from the LSP client
---
---@param method vim.lsp.protocol.Method | string The invoked LSP method
---@param params table? Parameters for the invoked LSP method
---@param callback fun(err: lsp.ResponseError?, result: any) Callback to invoke
---@param notify_reply_callback? fun(message_id: integer) Callback to invoke as soon as a request is no longer pending
---@return boolean success `true` if request could be sent, `false` if not
---@return integer? message_id if request could be sent, `nil` if not
function Server:request(method, params, callback, notify_reply_callback)
	notify_reply_callback = notify_reply_callback or function() end

	local handler = self._handlers[method]
	if not handler then
		vim.notify("No handler for method: " .. method, vim.log.levels.WARN)
		return false, nil
	end
	local message_id = self:new_message_id()

	vim.schedule(function()
		handler(
			self,
			params,
			vim.schedule_wrap(function(err, result)
				callback(err, result)
				if not err then
					notify_reply_callback(message_id)
				end
			end)
		)
	end)
	return true, message_id
end

--- Receives a notification from the LSP client.
---@param method string The invoked LSP method
---@param params table? Parameters for the invoked LSP method
---@return boolean
function Server:notify(method, params)
	method = method
	params = params
	local handler = self._handlers[method]
	if not handler then
		vim.notify("No handler for method: " .. method, vim.log.levels.WARN)
		return false
	end
	vim.schedule(function()
		handler(self, params, function() end)
	end)
	return true
end

---@return boolean
function Server:is_closing()
	return false
end

function Server:terminate()
	self._running = false
	self._workspace = nil
end

function Server:new_message_id()
	local id = self._next_message_id
	self._next_message_id = self._next_message_id + 1
	return id
end

---@param params lsp.InitializeParams
function Server:on_initialize(params, callback)
	params = params
	---@type lsp.InitializeResult
	local result = {
		capabilities = capabilities,
		serverInfo = {
			name = "nes",
			version = "0.1.0",
		},
	}
	self._initialized = true
	vim.schedule(function()
		self.dispatchers.server_request(Methods.window_logMessage, { type = 3, message = "NES initialized" })
	end)
	callback(nil, result)
end

---@param params lsp.InitializedParams
function Server:on_initialized(params, callback)
	params = params
	self._client_initialized = true
	callback()
end

---@param params lsp.DidOpenTextDocumentParams
function Server:on_did_open(params, callback)
	self._workspace[params.textDocument.uri] = {
		original = params.textDocument,
		current = vim.deepcopy(params.textDocument),
	}
	callback()
end

---@param params lsp.DidSaveTextDocumentParams
function Server:on_did_save(params, callback)
	local ctx = self._workspace[params.textDocument.uri]
	if not ctx then
		callback({ code = 1, message = "no context" })
		return
	end
	ctx.original = vim.deepcopy(ctx.current)
	self._workspace[params.textDocument.uri] = ctx
	callback()
end

---@param params lsp.DidChangeTextDocumentParams
function Server:on_did_change(params, callback)
	local ctx = self._workspace[params.textDocument.uri]
	if not ctx then
		callback({ code = 1, message = "no context" })
		return
	end
	ctx.current.version = params.textDocument.version
	ctx.current.text = params.contentChanges[1].text

	ctx.pending_edits = nil
	ctx.last_applied = nil

	self._workspace[params.textDocument.uri] = ctx
	callback()
end

---@param params lsp.DidCloseTextDocumentParams
function Server:on_did_close(params, callback)
	params = params
	self._workspace[params.textDocument.uri] = nil
	callback()
end

---@class nes.InlineEditParams : lsp.TextDocumentPositionParams
---@field version integer

---@class nes.InlineEdit
---@field command? lsp.Command
---@field range lsp.Range
---@field text string
---@field textDocument lsp.VersionedTextDocumentIdentifier

---@param params nes.InlineEditParams
function Server:on_inline_edit(params, callback)
	params = params
	local ctx = self._workspace[params.textDocument.uri]
	if not ctx then
		callback({ code = 1, message = "no context" })
		return
	end

	local version = ctx.current.version

	local pending = ctx.pending_edits or {}
	local last_applied = ctx.last_applied or 0
	local next_edit = pending[last_applied + 1]

	if next_edit then
		callback(nil, { edits = { next_edit } })
		ctx.last_applied = last_applied + 1
		return
	end

	ctx.pending_edits = nil
	ctx.last_applied = nil

	local cursor = { params.position.line + 1, params.position.character }
	local filename = vim.fn.fnamemodify(vim.uri_to_fname(ctx.original.uri), ":")
	require("nes.core").fetch_suggestions(
		filename,
		ctx.original.text,
		ctx.current.text,
		cursor,
		ctx.original.languageId,
		---@param edits lsp.TextEdit[]
		function(edits)
			if version ~= ctx.current.version then
				-- drop outdated suggestions
				callback(nil, { edits = {} })
				return
			end
			---@type nes.InlineEdit[]
			local inline_edits = {}
			for _, edit in ipairs(edits) do
				table.insert(inline_edits, {
					range = edit.range,
					text = edit.newText,
					textDocument = {
						uri = ctx.current.uri,
						version = ctx.current.version,
					},
				} --[[@as nes.InlineEdit]])
			end
			ctx.pending_edits = inline_edits
			ctx.last_applied = 0
			callback(nil, { edits = { inline_edits[1] } })
		end
	)
end

return Server
