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

--- Captura o buffer atual e abre o PM Agent com o código injetado como contexto
function M.review_current_buffer()
    -- 1. Coleta metadados e o texto do buffer ativo (seu arquivo Python)
    local bufnr = vim.api.nvim_get_current_buf()
    local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
    local filename = vim.fn.expand("%:t")
    
    -- Se for um buffer vazio ou sem nome, avisa o usuário
    if filename == "" then
        print("Erro: Salve o arquivo primeiro ou abra um arquivo válido para revisão.")
        return
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local code_content = table.concat(lines, "\n")

    -- 2. Formata o contexto em Markdown para o Tech Lead entender facilmente
    local context_prompt = string.format(
        "Estou trabalhando no arquivo `%s`.\nAqui está o código atual:\n```%s\n%s\n
```\n\n",
        filename, filetype, code_content
    )

    -- 3. Abre a UI reutilizando a mesma lógica, mas com o contexto anexado
    ui.mount_chat_ui(function(user_prompt)
        
        -- Combina o código do arquivo com o requisito que você digitou
        local full_prompt = context_prompt .. "Meu requisito/dúvida: " .. user_prompt
        
        -- Feedback visual focado (não mostramos o código inteiro na UI para não poluir)
        ui.append_to_chat("## 🧑‍💻 Revisando: `" .. filename .. "`\n**Sua demanda:** " .. user_prompt .. "\n\n")
        ui.append_to_chat("---\n*Lendo o arquivo e gerando plano de ação arquitetural...*\n\n")
        
        local messages = {
            { role = "system", content = config.options.system_prompt },
            { role = "user", content = full_prompt }
        }
        
        -- Chamada de rede inalterada
        backend.chat_stream(
            messages,
            { url = config.options.ollama_url, model = config.options.model },
            function(chunk) ui.append_to_chat(chunk) end,
            function() ui.append_separator() end,
            function(err_msg)
                ui.append_to_chat("\n\n**[ERRO]** " .. err_msg .. "\n")
                ui.append_separator()
            end
        )
    end)
end

-- Registre o novo comando no setup()
-- Coloque isso dentro da sua function M.setup(user_opts)
vim.api.nvim_create_user_command("PMReview", function()
    M.review_current_buffer()
end, {})

local workspace = require("pm_agent.workspace")

-- Adicione a função abaixo de M.open_agent e M.review_current_buffer
function M.review_entire_project()
    -- 1. Feedback rápido para o usuário enquanto o plugin lê a pasta
    print("Escaneando a pasta do projeto... Aguarde.")
    
    -- 2. Constrói o contexto maciço com a árvore e os arquivos
    local project_context = workspace.build_project_context()

    -- 3. Abre a UI com o contexto anexado
    ui.mount_chat_ui(function(user_prompt)
        local full_prompt = project_context .. "Meu requisito/dúvida sobre o projeto: " .. user_prompt
        
        -- Confirmação visual na UI
        ui.append_to_chat("## 🗂️ Revisão de Arquitetura do Projeto\n**Sua demanda:** " .. user_prompt .. "\n\n")
        ui.append_to_chat("---\n*Analisando a estrutura do projeto e interações entre arquivos...*\n\n")
        
        local messages = {
            { role = "system", content = config.options.system_prompt },
            { role = "user", content = full_prompt }
        }
        
        backend.chat_stream(
            messages,
            { url = config.options.ollama_url, model = config.options.model },
            function(chunk) ui.append_to_chat(chunk) end,
            function() ui.append_separator() end,
            function(err_msg)
                ui.append_to_chat("\n\n**[ERRO]** Falha ao processar o projeto: " .. err_msg .. "\n")
                ui.append_separator()
            end
        )
    end)
end

-- Dentro da sua function M.setup(user_opts), registre o novo comando:
vim.api.nvim_create_user_command("PMProject", function()
    M.review_entire_project()
end, {})

return M
