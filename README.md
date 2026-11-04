# eijuito.github.io

Repositório do site de usuário do GitHub Pages (`https://eijuito.github.io/`) com suporte a distribuição de artefatos públicos gerados por repositórios privados na pasta `/repo`.

## 📁 Estrutura do Projeto

Consulte a documentação completa em `docs/`:
- [Plano do Projeto & Boas Práticas](docs/plano-projeto.md)
- [Diagrama Gráfico de Estrutura de Diretórios](docs/estrutura-diretorios.md)
- [Regras e Skills para IAs](docs/ai-rules-and-skills.md)

## 📦 Como adicionar artefatos de um repositório

1. Crie uma pasta dentro de `repo/` com o **mesmo nome do repositório** (ex: `repo/meu-repo/`).
2. Utilize o modelo disponível em `repo/template-repo/index.html` para criar a página `repo/meu-repo/index.html`.
3. Adicione a entrada na tabela em `repo/index.html`.
4. Faça o commit e push para a branch `main`. O workflow do GitHub Actions publicará as alterações automaticamente.

