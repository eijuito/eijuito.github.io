# Plano de Implementação: GitHub Pages de Usuário (`eijuito.github.io`)

Este documento consolida o planejamento, as melhores práticas de acordo com [https://docs.github.com/pt/pages](https://docs.github.com/pt/pages) e a governança de publicação de artefatos públicos a partir de repositórios privados.

---

## 1. Fundamentos & Requisitos Oficiais

1. **Repositório de Usuário (`eijuito.github.io`)**:
   - É publicado diretamente na raiz do domínio (`https://eijuito.github.io/`).
   - A publicação ocorre a partir da branch principal (`main`), gerenciada preferencialmente por **GitHub Actions** (*Settings > Pages > Build and deployment > Source: GitHub Actions*).

2. **Arquivo `.nojekyll`**:
   - O GitHub Pages utiliza o motor Jekyll por padrão. O Jekyll ignora arquivos e diretórios que começam com `_` ou `.`, e pode desconsiderar determinados formatos binários.
   - A inclusão do `.nojekyll` na raiz do repositório garante que qualquer tipo de arquivo estático dentro de `repo/` seja servido integralmente sem filtragem.

3. **Governança de Limites**:
   - Limite por arquivo individual no Git: **100 MB** (recomendado manter abaixo de 50 MB no Git padrão).
   - Para pacotes maiores que 50 MB, utilizar os Releases do GitHub e disponibilizar os links no `index.html` correspondente em `repo/<nome-do-repo>/`.

---

## 2. Padrão da Pasta `/repo`

- **Nomenclatura**: Cada subpasta em `/repo/` deve possuir **exatamente o mesmo nome do repositório de origem** (ex: `repo/meu-projeto/`).
- **Arquivo `index.html` obrigatório**: Cada pasta de repositório deve conter um `index.html` que oriente o usuário ou consumidor sobre:
  - Objetivo do projeto.
  - Tabela de artefatos disponíveis (releases, binários, firmwares `.bin` / `.hex`, instaladores), suas versões, datas e links diretos de download.
  - Sumário de alterações (Changelog) ou notas de release.
- **Catálogo Central**: A pasta `/repo/index.html` atua como agregadora, listando e facilitando a busca entre todos os repositórios cadastrados.

---

## 3. Matriz Tecnológica Documentada
- **Quality Assurance & Performance Engineering**: Quality Assurance (QA), Performance Engineering, testes de carga/stress (JMeter, k6), profiling de JVM/GC, observabilidade e tuning de latência/throughput.
- **Inteligência Artificial & Agentes**: Gemini, Claude, Hermes MCP, Model Context Protocol, LangChain/LangGraph, RAG, Multi-Agentes.
- **Linguagens & Runtime**: JAVA (destaque principal), Python, TypeScript, JavaScript, C/C++ (Embedded), SQL, Shell Scripting.
- **Engenharia, Cloud & Trading**: MQL5 (MetaTrader 5), GitHub Actions CI/CD, Docker, REST/gRPC APIs, Microservices, Linux DevOps.
- **Eletrônica, IoT & Automação Residencial**: Eletrônica, Arduino, ESP32, ESP8266, Raspberry Pi, Home Assistant, Alexa, Google Assistant, Mijia (Xiaomi), SonOff, MQTT e Zigbee.

---

## 3. Automação de CI/CD

O deploy deste repositório é automatizado via GitHub Actions através do arquivo `.github/workflows/deploy-pages.yml`, utilizando as actions padrão do GitHub:
- `actions/checkout@v4`
- `actions/configure-pages@v5`
- `actions/upload-pages-artifact@v3`
- `actions/deploy-pages@v4`

---

## 4. Integração com Repositórios Privados

Nos repositórios privados que geram artefatos públicos, pode ser configurada uma GitHub Action que:
1. Realize o build ou empacotamento do artefato.
2. Utilize um token seguro com escopo para enviar o artefato para `eijuito.github.io/repo/<nome-do-repo>/` e atualizar seu respectivo `index.html`.
3. Dispare o workflow de deploy do GitHub Pages.

