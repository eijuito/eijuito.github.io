# Guia e Regras para Agentes de IA (AI Rules & Guidelines)

Este documento orienta assistentes de Inteligência Artificial sobre a arquitetura, convenções e regras de manipulação deste repositório (`eijuito.github.io`).

---

## 1. Princípios Arquiteturais

1. **GitHub Pages de Usuário**:
   - Este repositório é servido diretamente no domínio `https://eijuito.github.io/`.
   - Utiliza deploy via **GitHub Actions** a partir da branch `main`.
   - O arquivo `.nojekyll` na raiz é fundamental e **nunca deve ser removido**, pois desativa o processamento Jekyll, garantindo que arquivos estáticos e artefatos em `/repo` não sejam filtrados ou corrompidos.

2. **Organização da pasta `/repo`**:
   - Cada repositório privado com artefatos públicos deve possuir um subdiretório correspondente com **exatamente o mesmo nome do repositório** (ex: `repo/meu-app-privado/`).
   - Cada pasta de repositório **deve conter um arquivo `index.html`** explicativo, contendo:
     - Nome do repositório e descrição sumária da sua finalidade.
     - Tabela/lista de artefatos disponíveis, suas versões, formatos, checksums (se aplicável) e links de download.
     - Instruções de uso ou requisitos para consumo dos artefatos.
   - O diretório `repo/` possui um `index.html` mestre que lista todos os repositórios disponíveis.

3. **Governança de Tamanho e Segurança**:
   - Nenhum artefato público deve conter credenciais, segredos, chaves de API, variáveis de ambiente ou dados confidenciais do repositório privado de origem.
   - Respeitar limites do Git: arquivos não devem ultrapassar 50 MB no histórico git. Para arquivos maiores, deve-se gerar o release no GitHub Releases do repo de origem e incluir o link no `index.html` correspondente.

---

## 2. Habilidades Esperadas da IA (Skills)

Ao atuar neste projeto, a IA deve desempenhar as seguintes capacidades:

- **Especialista em GitHub Pages & Actions**: Configurar e manter os workflows de CI/CD em `.github/workflows/deploy-pages.yml` com as actions oficiais (`actions/upload-pages-artifact`, `actions/deploy-pages`).
- **Gerador de Catálogo de Artefatos**: Criar e manter páginas `index.html` com design limpo, acessível, responsivo e sem dependências externas pesadas (HTML5 semântico, CSS moderno).
- **Guardião de Integridade**: Validar links relativos e garantir que novas pastas adicionadas em `repo/` sejam indexadas no catálogo central.
- **Mantenedor de Documentação e Diagramas**: Manter o diretório `docs/` atualizado a cada nova funcionalidade ou alteração estrutural.

