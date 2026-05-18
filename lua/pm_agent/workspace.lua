-- lua/pm_agent/workspace.lua
local scandir = require("plenary.scandir")
local path = require("plenary.path")

local M = {}

-- Pastas e extensões que o nosso Agente DEVE ignorar para não estourar o limite de tokens
local IGNORED_DIRS = { ".git", "__pycache__", "venv", ".venv", "node_modules", "build", "dist" }
local ALLOWED_EXTS = { "py", "lua", "md", "json", "toml", "sql" }

--- Verifica se a extensão do arquivo é permitida
local function is_allowed_file(filename)
    local ext = filename:match("^.+(%..+)$")
    if not ext then return false end
    ext = ext:sub(2) -- remove o ponto
    for _, allowed in ipairs(ALLOWED_EXTS) do
        if ext == allowed then return true end
    end
    return false
end

--- Verifica se o caminho contém diretórios ignorados
local function is_ignored_path(filepath)
    for _, dir in ipairs(IGNORED_DIRS) do
        if filepath:match("/" .. dir .. "/") or filepath:match("^" .. dir .. "/") then
            return true
        end
    end
    return false
end

--- Escaneia o diretório atual e monta um dossiê do projeto
function M.build_project_context()
    local cwd = vim.fn.getcwd()
    local project_name = vim.fn.fnamemodify(cwd, ":t")
    
    -- Busca todos os arquivos no diretório atual
    local files = scandir.scan_dir(cwd, {
        hidden = false,
        add_dirs = false,
    })

    local tree_structure = {}
    local files_content = {}

    for _, file_path in ipairs(files) do
        -- Transforma em caminho relativo para facilitar a leitura
        local relative_path = path:new(file_path):make_relative(cwd)
        
        if not is_ignored_path(relative_path) and is_allowed_file(relative_path) then
            -- Adiciona à árvore de arquivos
            table.insert(tree_structure, "- " .. relative_path)
            
            -- Lê o conteúdo do arquivo
            local p = path:new(file_path)
            if p:exists() and p:is_file() then
                local content = p:read()
                local ext = relative_path:match("^.+(%..+)$") and relative_path:match("^.+(%..+)$"):sub(2) or ""
                
                -- Formata o bloco de código
                local file_block = string.format("### Arquivo: `%s`\n```%s\n%s\n```", relative_path, ext, content)
                table.insert(files_content, file_block)
            end
        end
    end

    -- Junta tudo em um grande prompt de contexto
    local context = string.format(
        "Eu estou trabalhando no projeto `%s`.\n\n" ..
        "**Árvore do Projeto:**\n%s\n\n" ..
        "**Código Fonte:**\n\n%s\n\n",
        project_name,
        table.concat(tree_structure, "\n"),
        table.concat(files_content, "\n\n")
    )

    return context
end

return M
