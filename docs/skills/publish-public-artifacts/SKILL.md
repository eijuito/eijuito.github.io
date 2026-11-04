---
name: publish-public-artifacts
description: Orienta agentes autônomos de IA a preparar, validar, nomear e publicar artefatos públicos gerados por repositórios privados no hub central eijuito.github.io/repo via GitHub Actions com integridade criptográfica SHA-256 e conformidade com as políticas do repositório.
---

# Skill: Publicação Automatizada de Artefatos Públicos no Vault (`eijuito.github.io/repo`)

Esta skill estabelece o protocolo operacional padrão para qualquer agente de IA que atue em repositórios privados ou esteiras de CI/CD que precisem distribuir artefatos, binários, firmwares ou documentações para o hub público em `https://eijuito.github.io/repo/`.

---

## 1. Regras Mandatórias de Nomenclatura (Naming Conventions)

Toda IA deve garantir que os arquivos gerados sigam rigorosamente a estrutura semântica:

```text
<nome-do-projeto>_<versao>_<sistema-ou-plataforma>_<arquitetura>.<extensao>
```

### Exemplos Válidos por Stack:
* **Microcontroladores & IoT (ESP / Arduino / Pi)**:
  - `smart-switch_v1.0.3_esp32_qio-40mhz.bin`
  - `telemetry-node_v2.0.1_esp8266_flash4m.bin`
  - `sensor-hub_v1.2.0_arduino-nano_atmega328p.hex`
* **Java Enterprise & Backends**:
  - `payment-service_v2.1.0_all.jar`
  - `financial-core_v1.4.2_dist.zip`
* **MetaTrader / Trading Algorítmico**:
  - `scalper-engine_v3.2.0_mt5_x64.ex5`
  - `risk-manager_v1.0.1_mt5.mq5`

---

## 2. Checklist de Segurança e Sanitização (Zero Leaks Policy)

Antes de autorizar ou disparar a cópia de qualquer artefato para o repositório público, a IA **DEVE** inspecionar e garantir:
1. **Sem Segredos Compilados**: Firmwares e binários não devem conter credenciais Wi-Fi hardcoded, tokens de bot (Telegram/Discord), chaves privadas `.pem`/`.pfx` ou senhas de banco.
2. **Imutabilidade**: Se uma tag/versão já existir no repositório de destino, **nunca sobrescreva**. Sempre incremente a versão (`v1.0.0` $\to$ `v1.0.1`).
3. **Controle de Tamanho**:
   - Arquivo $\le$ 50 MB: Comitado na pasta `repo/<nome-do-repositorio>/`.
   - Arquivo $>$ 50 MB: Fazer upload no **GitHub Releases** do projeto de origem e incluir o link de download direto no `index.html` da subpasta.

---

## 3. Estrutura de Destino no Hub Público

No repositório central `eijuito.github.io`:
```text
repo/
└── <nome-exato-do-repositorio-origem>/
    ├── index.html                           # Guia explicativo (baseado no template-repo)
    ├── SHA256SUMS                           # Lista de hashes dos artefatos
    └── <artefato-padronizado>.<ext>         # Arquivo binário/compilado
```

---

## 4. Template de Workflow GitHub Action para Repositórios Privados

Quando uma IA for configurar o GitHub Actions de um repositório privado para enviar artefatos para `eijuito.github.io`, deve utilizar este modelo:

```yaml
name: Build and Publish Artifacts to Public Vault

on:
  release:
    types: [published]
  workflow_dispatch:

jobs:
  publish-artifact:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repositório Privado
        uses: actions/checkout@v4

      # [Passo de Build do Projeto: Java Maven/Gradle, Arduino-CLI, PlatformIO, etc.]
      - name: Build do Artefato
        run: |
          echo "Compilando artefato..."
          # Exemplo: mvn clean package / pio run / etc.

      - name: Gerar SHA-256 Checksum Local
        run: |
          cd build/
          sha256sum meu-artefato_v1.0.0_all.zip > SHA256SUMS

      - name: Checkout do Repositório Publico (Pages)
        uses: actions/checkout@v4
        with:
          repository: 'eijuito/eijuito.github.io'
          token: ${{ secrets.VAULT_DEPLOY_TOKEN }} # Fine-grained Personal Access Token com permissão Contents: Write
          path: 'public-vault'

      - name: Sincronizar Artefato na Pasta do Repositório
        run: |
          REPO_NAME="${{ github.event.repository.name }}"
          TARGET_DIR="public-vault/repo/$REPO_NAME"
          mkdir -p "$TARGET_DIR"

          # Copiar artefatos e checksums
          cp build/meu-artefato_v1.0.0_all.zip "$TARGET_DIR/"
          cp build/SHA256SUMS "$TARGET_DIR/"

          # Criar index.html local se não existir
          if [ ! -f "$TARGET_DIR/index.html" ]; then
            cp public-vault/repo/template-repo/index.html "$TARGET_DIR/index.html"
            sed -i "s/\[NOME_DO_REPOSITORIO\]/$REPO_NAME/g" "$TARGET_DIR/index.html"
          fi

      - name: Commit e Push para o Public Vault
        run: |
          cd public-vault
          git config user.name "AI Vault Bot"
          git config user.email "bot@eijuito.github.io"
          git add "repo/${{ github.event.repository.name }}"
          git commit -m "chore(vault): publicar artefatos de ${{ github.event.repository.name }} [skip ci]" || echo "Sem mudanças"
          git push origin main
```

---

## 5. Gatilho do Crawler Automático

Ao enviar o commit para `eijuito.github.io`, o workflow oficial de build do Pages detectará o novo diretório e executará automaticamente:
`python scripts/generate_manifest.py`

Esse script recalcula o `manifest.json`, disponibiliza o novo repositório na interface web `/repo/index.html` com o respectivo hash SHA-256 e botões de cópia e download.
