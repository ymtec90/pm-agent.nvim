-- lua/pm_agent/init.lua
local config = require("pm_agent.config")
local ui = require("pm_agent.ui")
local backend = require("pm_agent.backend")

local M = {}

--- Inicializa o plugin e faz o merge das configurações do usuário
function M.setup(user_opts)
    config.setup(user_opts)

    -- Criação do comando Neovim para invocar o PM Agent
    vim.api.nvim_create_user_command("PMAgent", function()
        M.open_agent()
    end, {})
end

--- Orquestra a abertura da UI e o fluxo de dados para o Ollama
function M.open_agent()
    -- Monta a UI e injeta a função que será executada ao pressionar <Enter>
    ui.mount_chat_ui(function(prompt)
        
        -- 1. Feedback visual imediato na janela de chat
        ui.append_to_chat("## 🧑‍💻 Requisito\n" .. prompt .. "\n\n")
        ui.append_to_chat("---\n*Analisando arquitetura e gerando plano de ação...*\n\n")
        
        -- 2. Construção do payload de mensagens (Contexto do Tech Lead + Prompt do Usuário)
        local messages = {
            { role = "system", content = config.options.system_prompt },
            { role = "user", content = prompt }
        }
        
        -- 3. Chamada assíncrona para o Ollama
        backend.chat_stream(
            messages,
            { url = config.options.ollama_url, model = config.options.model },
            
            -- Callback 1: on_chunk (Executado a cada pedaço de texto recebido)
            function(chunk)
                ui.append_to_chat(chunk)
            end,
            
            -- Callback 2: on_complete (Executado ao final do streaming)
            function()
                ui.append_separator()
            end,
            
            -- Callback 3: on_error (Tratamento de falhas de rede)
            function(err_msg)
                ui.append_to_chat("\n\n**[ERRO DE CONEXÃO]** " .. err_msg .. "\n")
                ui.append_separator()
            end
        )
    end)
end

return M
