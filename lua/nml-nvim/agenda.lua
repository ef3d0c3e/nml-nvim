-- The agenda of the workspace: its tasks, from the server's `nml/agenda`, grouped by date in a
-- buffer of their own. <CR> goes to a task, `t` toggles it, `r` refreshes, `q` closes.
local M = {}

local ns = vim.api.nvim_create_namespace("nml-agenda")

--- The NML language server of a buffer.
---@param bufnr integer
---@return vim.lsp.Client?
local function nml_client(bufnr)
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		local provider = client.server_capabilities.executeCommandProvider
		if provider and vim.tbl_contains(provider.commands or {}, "nml.toggleTask") then
			return client
		end
	end
end

--- `YYYY-MM-DD` of a time.
local function day(time)
	return os.date("%Y-%m-%d", time)
end

--- The weekday of `YYYY-MM-DD`.
local function weekday(date)
	local year, month, d = date:match("^(%d+)-(%d+)-(%d+)")
	return os.date("%a", os.time({ year = tonumber(year), month = tonumber(month), day = tonumber(d), hour = 12 }))
end

--- When a task is due: the earliest of its deadline, scheduled date and date, and which.
local function when(task)
	local best, kind
	for _, key in ipairs({ "deadline", "scheduled", "date" }) do
		local value = task[key]
		if type(value) == "string" and (not best or value < best) then
			best, kind = value, key
		end
	end
	return best, kind
end

--- The groups of tasks, in order, and the tasks of each.
---@param tasks table[]
---@param all boolean Whether done tasks are listed.
local function groups(tasks, all)
	local today = day(os.time())
	local week = day(os.time() + 7 * 24 * 3600)
	local order = { "Overdue", "Today", "Next 7 days", "Later", "Undated", "Done" }
	local by = {}
	for _, name in ipairs(order) do
		by[name] = {}
	end
	for _, task in ipairs(tasks) do
		local date = when(task)
		date = date and date:sub(1, 10)
		local group
		if task.done then
			group = all and "Done" or nil
		elseif not date then
			group = "Undated"
		elseif date < today then
			group = "Overdue"
		elseif date == today then
			group = "Today"
		elseif date <= week then
			group = "Next 7 days"
		else
			group = "Later"
		end
		if group then
			table.insert(by[group], task)
		end
	end
	for _, name in ipairs(order) do
		table.sort(by[name], function(a, b)
			local wa, wb = when(a) or "~", when(b) or "~"
			if wa ~= wb then
				return wa < wb
			end
			return a.unit .. a.title < b.unit .. b.title
		end)
	end
	return order, by
end

--- The state shown for a task: a heading's keyword, or an item's checkbox.
local function state(task)
	if task.heading then
		return task.state
	end
	return ({ todo = "[ ]", partial = "[-]", done = "[x]" })[task.state] or task.state
end

local state_by_buffer = {}

--- Writes the agenda in its buffer.
local function render(buf, tasks, all)
	local lines = { "NML agenda, " .. os.date("%a %Y-%m-%d"), "" }
	local marks = { { 0, "Title" } }
	local at = {}
	local order, by = groups(tasks, all)
	for _, name in ipairs(order) do
		local list = by[name]
		if #list > 0 then
			table.insert(lines, string.format("%s (%d)", name, #list))
			table.insert(marks, { #lines - 1, name == "Overdue" and "ErrorMsg" or "Title" })
			for _, task in ipairs(list) do
				local date, kind = when(task)
				local label = ""
				if date then
					local time = date:sub(12)
					label = string.format("%s %s%s", date:sub(1, 10), weekday(date), time ~= "" and " " .. time or "")
				end
				local kinds = { deadline = "deadline", scheduled = "scheduled", date = "" }
				table.insert(lines, string.format(
					"  %-20s %-9s %-5s %s  (%s)",
					label,
					kind and kinds[kind] or "",
					state(task),
					task.title,
					task.unit
				))
				at[#lines] = task
				if kind == "deadline" then
					table.insert(marks, { #lines - 1, "WarningMsg" })
				end
			end
			table.insert(lines, "")
		end
	end
	if #lines == 2 then
		table.insert(lines, "Nothing to do.")
	end
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for _, mark in ipairs(marks) do
		vim.api.nvim_buf_set_extmark(buf, ns, mark[1], 0, { line_hl_group = mark[2] })
	end
	state_by_buffer[buf].at = at
end

--- Asks the server for the tasks, and writes them.
local function refresh(buf)
	local view = state_by_buffer[buf]
	local client = vim.lsp.get_client_by_id(view.client)
	if not client then
		return
	end
	client:request("nml/agenda", {}, function(err, tasks)
		if err then
			vim.notify(err.message, vim.log.levels.ERROR)
			return
		end
		if vim.api.nvim_buf_is_valid(buf) then
			render(buf, tasks or {}, view.all)
		end
	end)
end

--- Goes to a task, in the window the agenda was opened from.
local function jump(buf, task)
	local view = state_by_buffer[buf]
	local win = vim.api.nvim_win_is_valid(view.origin) and view.origin or nil
	if win then
		vim.api.nvim_set_current_win(win)
	else
		vim.cmd("wincmd p")
	end
	vim.cmd.edit(vim.fn.fnameescape(vim.uri_to_fname(task.uri)))
	local line = task.range.start.line
	vim.api.nvim_win_set_cursor(0, { line + 1, task.range.start.character })
end

--- Toggles a task: from its buffer, then the agenda is written again.
local function toggle(buf, task)
	jump(buf, task)
	local file_buf = vim.api.nvim_get_current_buf()
	local client
	vim.wait(3000, function()
		client = nml_client(file_buf)
		return client ~= nil
	end, 20)
	if not client then
		vim.notify("No NML language server for this file", vim.log.levels.WARN)
		return
	end
	local command = {
		title = "Toggle",
		command = "nml.toggleTask",
		arguments = { task.uri, task.range.start.line },
	}
	client:exec_cmd(command, { bufnr = file_buf }, function(err)
		if err then
			vim.notify(err.message, vim.log.levels.WARN)
			return
		end
		if vim.api.nvim_buf_is_valid(buf) then
			vim.defer_fn(function()
				refresh(buf)
			end, 100)
		end
	end)
end

--- Opens the agenda of the workspace of the current buffer.
---@param all? boolean Whether done tasks are listed too.
function M.open(all)
	local origin = vim.api.nvim_get_current_win()
	local client = nml_client(vim.api.nvim_get_current_buf())
	if not client then
		vim.notify("No NML language server for this buffer", vim.log.levels.WARN)
		return
	end
	local name = "nml://agenda"
	local old = vim.fn.bufnr(name)
	if old ~= -1 then
		vim.api.nvim_buf_delete(old, { force = true })
	end
	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "nml-agenda"
	vim.api.nvim_buf_set_name(buf, name)
	state_by_buffer[buf] = { client = client.id, origin = origin, all = all or false, at = {} }
	local function on_task(action)
		return function()
			local task = state_by_buffer[buf].at[vim.api.nvim_win_get_cursor(0)[1]]
			if task then
				action(buf, task)
			end
		end
	end
	local map = function(key, action, desc)
		vim.keymap.set("n", key, action, { buffer = buf, desc = desc, nowait = true })
	end
	map("<CR>", on_task(jump), "Go to the task")
	map("t", on_task(toggle), "Toggle the task")
	map("r", function()
		refresh(buf)
	end, "Refresh the agenda")
	map("q", "<cmd>close<cr>", "Close the agenda")
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		callback = function()
			state_by_buffer[buf] = nil
		end,
	})
	refresh(buf)
end

return M
