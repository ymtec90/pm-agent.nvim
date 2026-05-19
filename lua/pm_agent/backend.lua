-- lua/pm_agent/backend.lua
local curl = require("plenary.curl")

local M = {}

---@class ChatMessage
---@field role string 'system' | 'user' | 'assistant'
---@field content string

---@class BackendConfig
---@field url string Endpoint do Ollama (ex: "http://localhost:11434/api/chat")
---@field model string Nome do modelo (ex: "qwen2.5-coder:3b")

--- Executa a requisição assíncrona com streaming para o Ollama
---@param messages ChatMessage[] Lista de mensagens (contexto + prompt atual)
---@param config BackendConfig Configurações do endpoint e modelo
---@param on_chunk function(string) Callback disparado a cada fragmento de texto recebido
---@param on_complete function() Callback disparado ao finalizar o streaming
---@param on_error function(string) Callback disparado em caso de falha HTTP/Rede
function M.chat_stream(messages, config, on_chunk, on_complete, on_error)
	-- Montagem do payload conforme a documentação do Ollama
	local body = {
		model = config.model,
		messages = messages,
		stream = true, -- Essencial para não bloquear o editor
	}

	local json_body = vim.fn.json_encode(body)

	-- Inicia a requisição POST assíncrona
	curl.post(config.url, {
		body = json_body,
		headers = {
			["Content-Type"] = "application/json",
		},
		-- O callback 'stream' é engatilhado repetidamente à medida que os dados chegam
		stream = function(err, data)
			-- 1. Tratamento de falhas na camada TCP/Rede
			if err then
				vim.schedule(function()
					if on_error then
						on_error("Falha de conexão: " .. tostring(err))
					end
				end)
				return
			end

			-- 2. Ignora pacotes vazios (comum em conexões keep-alive)
			if not data or data == "" then
				return
			end

			-- 3. Injeção segura na Thread Principal do Neovim
			vim.schedule(function()
				-- Tenta decodificar o fragmento JSON enviado pelo Ollama
				local ok, parsed = pcall(vim.fn.json_decode, data)

				-- Previne falhas se o chunk for um JSON quebrado (exceção rara em streams TCP)
				if not ok or type(parsed) ~= "table" then
					return
				end

				-- 4. Extrai o conteúdo e repassa para a UI (on_chunk)
				if parsed.message and parsed.message.content then
					-- Se o conteúdo não for vazio, disparamos a atualização
					if parsed.message.content ~= "" then
						on_chunk(parsed.message.content)
					end
				end

				-- 5. Sinaliza que o Ollama terminou a geração
				if parsed.done then
					if on_complete then
						on_complete()
					end
				end
			end)
		end,
		-- O callback principal lida com o encerramento da conexão e status HTTP
		callback = function(response)
			if response.status >= 400 then
				vim.schedule(function()
					if on_error then
						on_error(
							"Erro HTTP "
								.. tostring(response.status)
								.. ": Verifique se o Ollama está rodando e o modelo existe."
						)
					end
				end)
			end
		end,
	})
end

return M
