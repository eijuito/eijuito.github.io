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
VAULT_URL="https://eijuito.github.io/repo/kwiek-autogate"
PACKAGE_NAME="kwiek-autogate_v2.0.0_linux_arm64.tar.gz"

echo "=== Instalando Kwiek Autogate (Rust ARM64) em $TARGET_DIR ==="

# 1. Parar servicos anteriores caso estejam rodando
systemctl stop ${SERVICE_NAME}.service 2>/dev/null || true
systemctl stop kwiek-autogate.service 2>/dev/null || true
killall -9 kwiek-supervisor kwiek-worker 2>/dev/null || true

# 2. Criar diretorio limpo em /opt sem sujar a home do usuario
mkdir -p "$TARGET_DIR"

# 3. Baixar o pacote diretamente para /opt/kwiek-autogate e descompactar
echo "Baixando pacote oficial $PACKAGE_NAME..."
curl -fsSL "$VAULT_URL/$PACKAGE_NAME" -o "$TARGET_DIR/$PACKAGE_NAME"

echo "Extraindo arquivos em $TARGET_DIR..."
tar -xzf "$TARGET_DIR/$PACKAGE_NAME" -C "$TARGET_DIR"
rm -f "$TARGET_DIR/$PACKAGE_NAME"

# 4. Garantir permissoes de execucao nos binarios
chmod +x "$TARGET_DIR/kwiek-supervisor"
chmod +x "$TARGET_DIR/kwiek-worker"

# 5. Criar config.json padrao com os pinos corretos se nao existir
if [ ! -f "$TARGET_DIR/config.json" ]; then
    echo "Gerando config.json de producao..."
    cat <<EOF > "$TARGET_DIR/config.json"
{
  "relays": {
    "1": { "name": "Relay 1 (Gate)", "gpio": 26, "active_high": false },
    "2": { "name": "Relay 2 (Light)", "gpio": 20, "active_high": false },
    "3": { "name": "Relay 3", "gpio": 21, "active_high": false }
  },
  "buttons": {
    "1": { "gpio": 5, "pull_up": true, "relay_id": 1, "mode": "pulse" },
    "2": { "gpio": 6, "pull_up": true, "relay_id": 2, "mode": "pulse" },
    "3": { "gpio": 12, "pull_up": true, "relay_id": 3, "mode": "pulse" },
    "4": { "gpio": 13, "pull_up": true, "relay_id": 1, "mode": "pulse" }
  },
  "default_pulse_duration": 3.0,
  "debounce_time_s": 0.1,
  "enable_startup_self_test": false,
  "auth_username": "porta",
  "auth_password": "127952",
  "version": "2.0.0",
  "github_repo": "eijuito/kwiek-autogate",
  "license_key": ""
}
EOF
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
echo "Servico ativo na porta 8000."
systemctl status ${SERVICE_NAME}.service --no-pager
