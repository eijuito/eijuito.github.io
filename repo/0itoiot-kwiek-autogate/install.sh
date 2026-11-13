#!/bin/bash
# -----------------------------------------------------------------------------
# install.sh - Instalador Oficial do Kwiek Autogate (Rust Native)
# Destino: /opt/kwiek-autogate (Zero sujeira na pasta do usuario)
# Execucao em 1 comando:
#   curl -fsSL https://eijuito.github.io/repo/kwiek-autogate/install.sh | sudo bash
# -----------------------------------------------------------------------------

set -e

TARGET_DIR="/opt/kwiek-autogate"
SERVICE_NAME="kwiek-supervisor"
VAULT_URL="https://raw.githubusercontent.com/eijuito/eijuito.github.io/main/repo/kwiek-autogate"

# Permite especificar versao customizada (ex: sudo VERSION=2.0.4 bash install.sh)
INSTALL_VERSION="${VERSION:-2.0.4}"
PACKAGE_NAME="kwiek-autogate_v${INSTALL_VERSION}_linux_arm64.tar.gz"

echo "=== Instalando Kwiek Autogate (Rust ARM64 v$INSTALL_VERSION) em $TARGET_DIR ==="

# 1. Parar servicos anteriores caso estejam rodando
systemctl stop ${SERVICE_NAME}.service 2>/dev/null || true
systemctl stop kwiek-autogate.service 2>/dev/null || true
killall -9 kwiek-supervisor kwiek-worker 2>/dev/null || true

# 2. Criar diretorio limpo em /opt e fazer backup preventivo do config.json e license.key existentes
mkdir -p "$TARGET_DIR"
if [ -f "$TARGET_DIR/config.json" ]; then
    echo "Preservando configuracoes existentes em $TARGET_DIR/config.json..."
    cp -f "$TARGET_DIR/config.json" "$TARGET_DIR/config.json.bak"
fi
if [ -f "$TARGET_DIR/license.key" ]; then
    echo "Preservando licenca isolada existente em $TARGET_DIR/license.key..."
    cp -f "$TARGET_DIR/license.key" "$TARGET_DIR/license.key.bak"
fi

# 3. Baixar o pacote diretamente para /opt/kwiek-autogate e descompactar
echo "Baixando pacote oficial $PACKAGE_NAME..."
curl -fsSL "$VAULT_URL/$PACKAGE_NAME" -o "$TARGET_DIR/$PACKAGE_NAME"

echo "Extraindo arquivos em $TARGET_DIR..."
tar -xzf "$TARGET_DIR/$PACKAGE_NAME" -C "$TARGET_DIR"
rm -f "$TARGET_DIR/$PACKAGE_NAME"

# Restaura o backup do config.json e license.key caso tenham sido afetados
if [ -f "$TARGET_DIR/config.json.bak" ]; then
    echo "Restaurando config.json preservado..."
    mv -f "$TARGET_DIR/config.json.bak" "$TARGET_DIR/config.json"
fi
if [ -f "$TARGET_DIR/license.key.bak" ]; then
    echo "Restaurando license.key preservado..."
    mv -f "$TARGET_DIR/license.key.bak" "$TARGET_DIR/license.key"
fi

# 4. Garantir permissoes de execucao nos binarios
chmod +x "$TARGET_DIR/kwiek-supervisor"
chmod +x "$TARGET_DIR/kwiek-worker"

# 5. Se nao existir config.json, inicializa a partir de config-template.json
if [ ! -f "$TARGET_DIR/config.json" ]; then
    if [ -f "$TARGET_DIR/config-template.json" ]; then
        echo "Inicializando config.json a partir do config-template.json..."
        cp -f "$TARGET_DIR/config-template.json" "$TARGET_DIR/config.json"
    fi
fi

# 6. Registrar e ativar o servico permanente no systemd
echo "Registrando ${SERVICE_NAME}.service no systemd..."
cat <<EOF > /etc/systemd/system/${SERVICE_NAME}.service
[Unit]
Description=Kwiek Autogate Supervisor & Watchdog (Rust Native)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$TARGET_DIR
ExecStart=$TARGET_DIR/kwiek-supervisor
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}.service
systemctl restart ${SERVICE_NAME}.service

echo ""
echo "=== Kwiek Autogate Instalado com Sucesso! ==="
echo "Servico ativo na porta 80 (ou 8000 fallback)."
systemctl status ${SERVICE_NAME}.service --no-pager
