# 0itocore-gates-googlegateway

Gateway determinístico em **Go nativo** (Plano 2 — Zero IA) do ecossistema `0ito` para integração autenticada com **Google Workspace** via **OAuth2 de Usuário** (`access_type=offline`, `refresh_token` persistente).

---

## 1. Arquitetura
- **Linguagem**: Go 1.22+ (zero dependências externas, apenas biblioteca padrão `net/http`, `embed`, `encoding/json`).
- **Isolamento de Segredos**: Credenciais OAuth2 (`oauth_client.json` e `oauth_token.json`) ficam armazenadas exclusivamente em `data/` da instância (permissão `0600`), nunca no `config.json`.
- **Comunicação Híbrida**:
  - **REST Síncrono**: Endpoints HTTP diretos para Google Sheets, Google Calendar e Gmail.
  - **Event-Driven (`0itonexus` SSE)**: Conecta em `{nexus_url}/api/v1/events` ouvindo `sheets.append`, `calendar.list`, `calendar.create` e publicando resultados em `sheets.result` / `calendar.result`.

---

## 2. Configuração (`config.json`)
Campos suportados (atualizados aditivamente pelo `0itocore-supervisor`):
```json
{
  "version": "0.1.1",
  "instance_id": "defaultgateway",
  "http_port": 8001,
  "port": 8001,
  "nexus_url": "http://127.0.0.1:8004",
  "data_dir": "data"
}
```

### Escopos OAuth2 Solicitados
- `https://www.googleapis.com/auth/spreadsheets` (Google Sheets)
- `https://www.googleapis.com/auth/calendar` (Google Calendar)
- `https://www.googleapis.com/auth/gmail.readonly` (Gmail — leitura)
- `https://www.googleapis.com/auth/youtube.readonly` (YouTube — leitura)
- `https://www.googleapis.com/auth/youtube.upload` (YouTube — upload)

---

## 3. Endpoints HTTP Principais
- `GET /`: Interface Web (compatível com Reverse Proxy do supervisor)
- `GET /health`: Health check JSON
- `GET /docs`: Documentação embutida (usada pelo botão **Help** do Workbench)
- `GET /auth/status`, `POST /auth/credentials`, `GET /auth/login`, `GET /auth/callback`
- `POST /api/v1/sheets/append`, `POST /api/v1/sheets/read`
- `POST /api/v1/calendar/events`, `POST /api/v1/calendar/create`
- `POST /api/v1/gmail/messages`, `POST /api/v1/gmail/read`
