# 🧑‍💻 pm-agent.nvim

**pm-agent.nvim** é um plugin nativo para Neovim desenvolvido em Lua que traz um **Tech Lead e Gerente de Projetos (PM) local** direto para o seu terminal.

Em vez de atuar como um mero gerador de código, este assistente possui uma *Persona* focada em **design de software, arquitetura, Clean Code e Test-Driven Development (TDD)**. Ele se comunica de forma totalmente local e privada com o [Ollama](https://ollama.ai/), permitindo que você envie múltiplos arquivos de contexto para receber planos de ação estruturados e revisões de integração.

![Neovim Version](https://img.shields.io/badge/Neovim-0.9.0+-blueviolet.svg)
![Lua](https://img.shields.io/badge/Lua-5.1-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## ✨ Principais Funcionalidades

*   **🔒 100% Local e Privado:** Comunicação direta com a API REST do Ollama (`http://localhost:11434/api/chat`). Nenhum dado do seu código sai da sua máquina (ideal para ambientes Linux locais ou WSL).
*   **⚡ Streaming Assíncrono:** Utiliza `plenary.curl` em *background* para garantir que o Neovim continue fluido e responsivo enquanto o modelo gera as respostas.
*   **🎨 UI Moderna:** Construído sobre o `nui.nvim`, oferecendo janelas flutuantes com bordas customizadas, divisão de painéis (split layouts) e auto-scroll inteligente.
*   **🗂️ Cesta de Contexto (Context Basket):** Selecione arquivos específicos do seu projeto (ex: as rotas da API e os modelos do Banco de Dados) e envie-os em lote para o agente analisar como eles se integram.
* **🧠 Memória de Projeto Persistente:** O agente lembra das suas decisões de arquitetura. O histórico da conversa é salvo automaticamente no arquivo `.pm-agent-history.json` e possui auto-compressão para não estourar a janela de tokens.
* **🔎 Busca Semântica (RAG Local):** O comando `:PMProject` agora vetoriza seus arquivos localmente usando similaridade de cossenos. Faça perguntas sobre a arquitetura inteira do repositório, e o Neovim injetará apenas os blocos de código matematicamente relevantes para o Ollama analisar.

## 📦 Dependências

Antes de instalar, certifique-se de ter as seguintes ferramentas configuradas:

1.  **Neovim** >= `0.9.0`
2.  **Ollama** rodando localmente na sua máquina.
3.  Modelos recomendados (baixe usando `ollama run <modelo>`):
    *   `qwen2.5-coder:3b` (Para o raciocínio/chat)
    *   `codegemma` (Obrigatório para Busca Semântica/RAG)

## 🚀 Instalação

O plugin foi desenhado para integração perfeita com o lazy.nvim. Adicione o seguinte bloco à sua configuração:

```lua
{
    "ymtec90/pm-agent.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
    },
    cmd = { "PMAgent", "PMReview", "PMAdd", "PMBasket" },
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

## 🛠️ Comandos e Fluxo de Trabalho

O plugin expõe quatro comandos principais para adaptar-se ao seu fluxo de desenvolvimento:

* `:PMAgent` - Abre o assistente para um chat livre, ideal para dúvidas gerais de arquitetura ou planejamento de projeto.
  
  **Caixa de Texto Inferior (Input)**: Digite o seu requisito arquitetural (ex: "Crie o planejamento e o esqueleto de testes para uma API de integração RAG local usando Python.").

  **Painel Superior (Output)**: O painel renderizará o plano de ação gerado pelo Ollama com sintaxe Markdown em tempo real.

  Atalhos Padrão (dentro da janela do plugin)
  `<CR>` (Enter): Envia o prompt para análise.

  `<Esc>` (Modo Normal) ou `<C-c>` (Modo Inserção): Fecha a interface do assistente.

* `:PMReview` - Captura imediatamente o texto do buffer aberto e abre o chat para você pedir uma revisão ou refatoração do arquivo atual.

## 🧺 Trabalhando com a Cesta de Contexto

Para problemas complexos (ex: separar responsabilidades entre a UI do Tkinter e o Banco SQLite), você pode enviar múltiplos arquivos de uma vez:

1. Abra o primeiro arquivo e digite `:PMAdd`.

2. Abra o segundo arquivo e digite `:PMAdd`.

3. Digite `:PMBasket`. Um gerenciador visual abrirá listando os arquivos e suas métricas (linhas e KB).

4. (Opcional) Use `dd` no gerenciador para remover arquivos indesejados.

5. Pressione `<Enter>` para confirmar a cesta, descreva o que você deseja analisar e receba o feedback arquitetural do Tech Lead!

## 🏗️ Estrutura do Código e Contribuição

O código adere a um design pattern rigoroso de separação de responsabilidades:

* `ui.lua`: Gerencia as instâncias visuais (`nui.popup`, `nui.input`).

* `backend.lua`: Isola as chamadas HTTP e o parsing do streaming JSON da API do Ollama.

* `basket.lua`: Módulo de estado para o gerenciamento de contexto de arquivos.

* `init.lua`: Orquestração e injeção de dependências.

Sinta-se livre para abrir Issues ou enviar Pull Requests!

## 📜 Licença

Distribuído sob a licença MIT.
