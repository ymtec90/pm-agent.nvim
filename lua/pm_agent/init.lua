local config = require("pm_agent.config")

local M = {}

--- Inicializa o plugin e faz o merge das configurações do usuário
function M.setup(user_opts)
        config.setup(user_opts)

        -- Criação de um comando Neovim para invocar o PM Agent
        vim.api.nvim_create_user_command("PMAgent", function()
                M.open_agent()
        end, {})
end

--- Função principal que orquestrará a abertura da UI e a chamada ao Backend
function M.open_agent()
        -- Em breve, faremos a chamada para o módulo UI aqui:
        -- local ui = require("pm_agent.ui")
        -- ui.mount_layout()

        print("PM Agent Iniciado! O modelo alvo é: " .. config.options.model)
end

return M
