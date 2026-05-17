# 🧑‍💻 pm-agent.nvim

**pm-agent.nvim** é um plugin nativo para Neovim desenvolvido em Lua que traz um **Tech Lead e Gerente de Projetos (PM) local** direto para o seu terminal.

Ao invés de simplesmente cuspir código, este plugin foca em **design de software, arquitetura e qualidade**. Ele se comunica de forma totalmente local e privada com o [Ollama](https://ollama.ai/), aproveitando modelos otimizados (como `qwen2.5-coder:3b` ou `codegemma`) para gerar planos de ação em Markdown, checklists de implementação e esqueletos de testes (TDD).

![Neovim Version](https://img.shields.io/badge/Neovim-0.9.0+-blueviolet.svg)
![Lua](https://img.shields.io/badge/Lua-5.1-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## ✨ Principais Funcionalidades

*   **🔒 100% Local e Privado:** Comunicação direta com a API REST do Ollama (`http://localhost:11434/api/chat`). Nenhum dado do seu código sai da sua máquina (ideal para ambientes Linux locais ou WSL).
*   **⚡ Streaming Assíncrono:** Utiliza `plenary.curl` em *background* para garantir que o Neovim continue fluido e responsivo enquanto o modelo gera as respostas.
*   **🎨 UI Moderna e Arrojada:** Construído sobre o `nui.nvim`, oferecendo janelas flutuantes com bordas customizadas, divisão de painéis (split layouts) e auto-scroll inteligente.
*   **🧠 Persona "Tech Lead":** O *system prompt* embutido é otimizado para planejamento. Peça uma feature e receba um arquivo `.md` contendo a arquitetura proposta, separação de responsabilidades e casos de teste automatizados (ex: `pytest`).

## 📦 Dependências

Antes de instalar, certifique-se de ter as seguintes ferramentas configuradas:

1.  **Neovim** >= `0.9.0`
2.  **Ollama** rodando localmente.
3.  Modelos recomendados baixados no Ollama:
    ```bash
    ollama run qwen2.5-coder:3b
    # ou
    ollama run codegemma
    ```

## 🚀 Instalação

O plugin foi desenhado para integração perfeita com o lazy.nvim. Adicione o seguinte bloco à sua configuração:

```lua
{
    "ymtec90/pm-agent.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
    },
    cmd = { "PMAgent" },
    config = function()
        require("pm_agent").setup({
            -- URL local do seu Ollama
            ollama_url = "http://localhost:11434/api/chat",
            -- Defina seu modelo preferido
            model = "qwen2.5-coder:3b",
        })
    end,
}
```

## 🛠️ Como Usar

Para abrir a interface do seu Tech Lead, basta executar o comando dentro do Neovim:

```vimscript
:PMAgent
```

Uma janela dividida se abrirá no centro do seu editor.

**Caixa de Texto Inferior (Input)**: Digite o seu requisito arquitetural (ex: "Crie o planejamento e o esqueleto de testes para uma API de integração RAG local usando Python.").

**Painel Superior (Output)**: O painel renderizará o plano de ação gerado pelo Ollama com sintaxe Markdown em tempo real.

Atalhos Padrão (dentro da janela do plugin)
`<CR>` (Enter): Envia o prompt para análise.

`<Esc>` (Modo Normal) ou `<C-c>` (Modo Inserção): Fecha a interface do assistente.

## 🏗️ Estrutura do Código e Contribuição

O código adere a um design pattern rigoroso de separação de responsabilidades:

`lua/pm_agent/ui.lua`: Gerencia as instâncias visuais (`nui.popup`, `nui.input`).

`lua/pm_agent/backend.lua`: Isola as chamadas HTTP e o parsing do streaming JSON da API do Ollama.

`lua/pm_agent/init.lua` e `config.lua`: Gerenciam a injeção de dependências e a configuração da Persona do modelo.

Sinta-se livre para abrir Issues ou enviar Pull Requests!

## 📜 Licença

Distribuído sob a licença MIT.
