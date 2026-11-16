# ==============================================================================
# 0itocore-supervisor - Instalador / Atualizador Oficial para Windows (PowerShell)
# Repositório: https://eijuito.github.io/repo/0itocore-supervisor/
# ==============================================================================
# Uso Rápido (Comando Único no PowerShell como Administrador):
#   powershell -ExecutionPolicy Bypass -Command "irm https://eijuito.github.io/repo/0itocore-supervisor/install.ps1 | iex"
#
# Uso Local:
#   .\install.ps1               # Instala ou atualiza para a versão mais recente
#   .\install.ps1 -Status       # Exibe status atual do daemon e versão instalada
#   .\install.ps1 -Uninstall    # Remove a tarefa agendada e binários (preserva dados)
#   .\install.ps1 -Purge        # Remove completamente pastas, dados e configurações
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$Status,
    [switch]$Uninstall,
    [switch]$Purge,
    [string]$Port = "8000"
)

$ErrorActionPreference = "Stop"

# Constantes e Definições de Caminhos
$RepoBaseUrl     = "https://eijuito.github.io/repo"
$FallbackBaseUrl = "https://raw.githubusercontent.com/eijuito/eijuito.github.io/main/repo"
$ProjectName     = "0itocore-supervisor"
$ProjectUrl      = "$RepoBaseUrl/$ProjectName"
$FallbackUrl     = "$FallbackBaseUrl/$ProjectName"
$global:DownloadBaseUrl = $ProjectUrl

$InstallDir     = "C:\0itocore-supervisor"
$BinDir         = Join-Path $InstallDir "bin"
$ConfigDir      = Join-Path $InstallDir "config"
$DataDir        = Join-Path $InstallDir "data"
$PluginsDir     = Join-Path $InstallDir "plugins"
$InstancesDir   = Join-Path $InstallDir "instances"
$LogsDir        = Join-Path $InstallDir "logs"

$BinPath        = Join-Path $BinDir "0itocore-supervisor.exe"
$OldBinPath     = Join-Path $BinDir "0itocore-supervisor.exe.old"
$ConfigPath     = Join-Path $ConfigDir "config.json"
$TaskName       = "0itocore-supervisor"

function Write-Banner {
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "      0ITOCORE-SUPERVISOR - INSTALADOR & GERENCIADOR WINDOWS      " -ForegroundColor Cyan
    Write-Host "                 Ecossistema 0ito Sovereign Tech                  " -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Check-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "Este instalador requer privilégios de Administrador."
        Write-Host "Por favor, abra o PowerShell como Administrador ('Executar como Administrador') e repita o comando:" -ForegroundColor Yellow
        Write-Host "  powershell -ExecutionPolicy Bypass -Command `"irm $ProjectUrl/install.ps1 | iex`"" -ForegroundColor Green
        exit 1
    }
}

function Check-Connectivity {
    Write-Host "[INFO] Verificando conectividade com o repositório público..." -ForegroundColor DarkCyan
    $tested = $false

    # 1. Tentar Public Vault oficial via GitHub Pages
    try {
        $req = [System.Net.WebRequest]::Create("$ProjectUrl/0itocore-supervisor.exe")
        $req.Timeout = 5000
        $req.Method = "HEAD"
        $resp = $req.GetResponse()
        if ($resp.StatusCode -eq 200) {
            $global:DownloadBaseUrl = $ProjectUrl
            $tested = $true
            Write-Host "[SUCESSO] Repositório oficial (GitHub Pages) acessível com sucesso." -ForegroundColor Green
        }
        $resp.Close()
    }
    catch {
        # Fallback para checagem rápida
    }

    # 2. Se Pages ainda não propagou ou deu 404, usar fallback resiliente (GitHub Raw)
    if (-not $tested) {
        try {
            $req2 = [System.Net.WebRequest]::Create("$FallbackUrl/0itocore-supervisor.exe")
            $req2.Timeout = 5000
            $req2.Method = "HEAD"
            $resp2 = $req2.GetResponse()
            if ($resp2.StatusCode -eq 200) {
                $global:DownloadBaseUrl = $FallbackUrl
                $tested = $true
                Write-Host "[SUCESSO] Repositório público conectado via espelho seguro (GitHub Raw CDN)." -ForegroundColor Green
            }
            $resp2.Close()
        }
        catch {
            # Se ambos falharem
        }
    }

    if (-not $tested) {
        Write-Error "Falha ao conectar com $ProjectUrl e $FallbackUrl. Verifique sua conexão à internet e DNS."
        exit 1
    }
}

function Detect-System {
    Write-Host "[INFO] Detectando sistema operacional e arquitetura..." -ForegroundColor DarkCyan
    if (-not [Environment]::Is64BitOperatingSystem) {
        Write-Error "O 0itocore-supervisor requer uma versão de 64 bits do Windows (x64)."
        exit 1
    }
    $osName = (Get-CimInstance Win32_OperatingSystem).Caption
    Write-Host "[INFO] Sistema Hospedeiro: $osName (64-bit)" -ForegroundColor Gray
}

function Check-ExistingInstallation {
    if (Test-Path $BinPath) {
        try {
            $ver = & $BinPath --version
            Write-Host "[INFO] Instalação anterior detectada em $InstallDir (Versão: $ver)" -ForegroundColor Yellow
        }
        catch {
            Write-Host "[INFO] Instalação anterior detectada em $InstallDir (Versão não identificada)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "[INFO] Nenhuma instalação anterior detectada. Nova instalação." -ForegroundColor Gray
    }
}

function Download-Artifacts {
    $global:TmpDir = Join-Path $env:TEMP ("0itocore-supervisor-install-" + [System.Guid]::NewGuid().ToString().Substring(0,8))
    New-Item -ItemType Directory -Path $global:TmpDir -Force | Out-Null

    Write-Host "[INFO] Consultando artefatos e integridade criptográfica no Public Vault ($global:DownloadBaseUrl)..." -ForegroundColor DarkCyan
    $sumsUrl = "$global:DownloadBaseUrl/SHA256SUMS"
    $sumsFile = Join-Path $global:TmpDir "SHA256SUMS"
    $binUrl = "$global:DownloadBaseUrl/0itocore-supervisor.exe"
    $targetDownloadedBin = Join-Path $global:TmpDir "0itocore-supervisor.exe"

    try {
        Invoke-WebRequest -Uri $sumsUrl -OutFile $sumsFile -UseBasicParsing
    }
    catch {
        Write-Warning "Arquivo SHA256SUMS não pôde ser baixado diretamente ($sumsUrl). Prosseguindo com download do binário."
    }

    Write-Host "[INFO] Baixando binário oficial: $binUrl..." -ForegroundColor DarkCyan
    try {
        Invoke-WebRequest -Uri $binUrl -OutFile $targetDownloadedBin -UseBasicParsing
    }
    catch {
        # Tentar download via fallback caso a URL original falhe
        if ($global:DownloadBaseUrl -ne $FallbackUrl) {
            Write-Warning "Tentando espelho de contingência em $FallbackUrl..."
            $fallbackBin = "$FallbackUrl/0itocore-supervisor.exe"
            Invoke-WebRequest -Uri $fallbackBin -OutFile $targetDownloadedBin -UseBasicParsing
        }
        else {
            Write-Error "Falha ao baixar $binUrl. Verifique se a release para Windows está disponível no vault."
            exit 1
        }
    }

    if (Test-Path $sumsFile) {
        Write-Host "[INFO] Verificando integridade SHA256..." -ForegroundColor DarkCyan
        $calcHash = (Get-FileHash -Path $targetDownloadedBin -Algorithm SHA256).Hash.ToLower()
        $sumsContent = Get-Content $sumsFile
        $expectedLine = $sumsContent | Where-Object { $_ -match "0itocore-supervisor\.exe" }

        if ($expectedLine) {
            $expectedHash = ($expectedLine -split "\s+")[0].ToLower()
            if ($calcHash -ne $expectedHash) {
                Write-Error "Divergência de Checksum SHA256!`nEsperado:  $expectedHash`nCalculado: $calcHash"
                exit 1
            }
            Write-Host "[SUCESSO] Checksum SHA256 verificado com sucesso ($($calcHash.Substring(0,16))...)." -ForegroundColor Green
        }
        else {
            Write-Host "[INFO] Hash SHA256 calculado: $calcHash" -ForegroundColor Gray
        }
    }
}

function Stop-ExistingService {
    Write-Host "[INFO] Parando instâncias anteriores do processo ou tarefa agendada..." -ForegroundColor DarkCyan

    # Parar tarefa agendada se existir
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        if ($task.State -eq "Running") {
            Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }
    }

    # Encerrar processos remanescentes com o nome supervisor ou 0itocore-supervisor
    Get-Process -Name "supervisor", "0itocore-supervisor" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "[INFO] Encerrando processo ativo PID $($_.Id)..." -ForegroundColor Yellow
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 1
}

function Install-Files {
    Write-Host "[INFO] Garantindo estrutura de diretórios em $InstallDir..." -ForegroundColor DarkCyan
    @($BinDir, $ConfigDir, $DataDir, $PluginsDir, $InstancesDir, $LogsDir) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }

    $downloadedBin = Join-Path $global:TmpDir "0itocore-supervisor.exe"

    if (Test-Path $BinPath) {
        Write-Host "[INFO] Criando cópia de segurança em $OldBinPath..." -ForegroundColor Gray
        Copy-Item -Path $BinPath -Destination $OldBinPath -Force
    }

    Write-Host "[INFO] Instalando novo binário em $BinPath..." -ForegroundColor DarkCyan
    Copy-Item -Path $downloadedBin -Destination $BinPath -Force

    # Criar config.json inicial se não existir
    if (-not (Test-Path $ConfigPath)) {
        Write-Host "[INFO] Criando arquivo de configuração padrão em $ConfigPath..." -ForegroundColor DarkCyan
        $defaultConfig = @"
{
  "version": "0.1.0",
  "http_port": $Port,
  "vault_enabled": false,
  "processes": []
}
"@
        Set-Content -Path $ConfigPath -Value $defaultConfig -Encoding UTF8
        Write-Host "[SUCESSO] Configuração padrão criada (Modo Nó, Porta $Port)." -ForegroundColor Green
    }
    else {
        Write-Host "[INFO] Configuração existente preservada em $ConfigPath." -ForegroundColor Green
    }

    # Adicionar bin ao PATH da máquina para uso direto via CLI
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($machinePath -notlike "*$BinDir*") {
        Write-Host "[INFO] Adicionando $BinDir ao PATH do sistema para comando '0itocore-supervisor'..." -ForegroundColor DarkCyan
        [Environment]::SetEnvironmentVariable("Path", "$machinePath;$BinDir", "Machine")
    }
}

function Configure-ScheduledTask {
    Write-Host "[INFO] Configurando inicialização persistente como Tarefa Agendada ($TaskName)..." -ForegroundColor DarkCyan

    $action = New-ScheduledTaskAction -Execute $BinPath -Argument "--config `"$ConfigPath`"" -WorkingDirectory $InstallDir
    $triggerBoot = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit 0

    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggerBoot -Principal $principal -Settings $settings | Out-Null
    Write-Host "[SUCESSO] Tarefa Agendada '$TaskName' registrada no Windows com gatilho AtStartup e RunLevel Highest." -ForegroundColor Green

    Write-Host "[INFO] Iniciando tarefa agendada do daemon..." -ForegroundColor DarkCyan
    Start-ScheduledTask -TaskName $TaskName
}

function Verify-Health {
    Write-Host "[INFO] Aguardando inicialização do serviço e verificando health check na porta $Port..." -ForegroundColor DarkCyan
    $retries = 10
    $healthy = $false

    while ($retries -gt 0) {
        try {
            $response = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 -ErrorAction Stop
            if ($response.status -eq "ok") {
                $healthy = $true
                break
            }
        }
        catch {
            Start-Sleep -Seconds 1
            $retries--
        }
    }

    if ($healthy) {
        Write-Host "[SUCESSO] Health check aprovado! O 0itocore-supervisor está ativo e operando." -ForegroundColor Green
    }
    else {
        Write-Warning "O endpoint http://127.0.0.1:$Port/health ainda não respondeu."
        Write-Warning "Inspecione o status da tarefa com: Get-ScheduledTask -TaskName $TaskName"
    }
}

function Show-Status {
    Write-Banner
    Write-Host "--- STATUS DO 0ITOCORE-SUPERVISOR (WINDOWS) ---" -ForegroundColor Cyan

    if (Test-Path $BinPath) {
        Write-Host "Binário Instalado: $BinPath" -ForegroundColor Green
        try {
            $ver = & $BinPath --version
            Write-Host "Versão:            $ver" -ForegroundColor DarkCyan
        }
        catch {
            Write-Host "Versão:            Desconhecida" -ForegroundColor DarkGray
        }
    }
    else {
        Write-Host "Binário Instalado: Não instalado" -ForegroundColor Red
    }

    if (Test-Path $ConfigPath) {
        Write-Host "Configuração:      $ConfigPath" -ForegroundColor Green
    }

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "Tarefa Agendada:   $($task.TaskName) (Estado: $($task.State))" -ForegroundColor Green
    }
    else {
        Write-Host "Tarefa Agendada:   Não registrada" -ForegroundColor Yellow
    }

    try {
        $res = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2 -ErrorAction Stop
        Write-Host "Healthcheck HTTP:  OK (http://127.0.0.1:$Port/health) - Status: $($res.status)" -ForegroundColor Green
    }
    catch {
        Write-Host "Healthcheck HTTP:  Inacessível ou Desligado" -ForegroundColor Red
    }
    Write-Host ""
}

function Uninstall-Supervisor {
    Write-Banner
    Check-Administrator
    Write-Host "[INFO] Iniciando desinstalação de $ProjectName no Windows..." -ForegroundColor Yellow

    Stop-ExistingService

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "[SUCESSO] Tarefa Agendada '$TaskName' removida." -ForegroundColor Green
    }

    if (Test-Path $BinDir) {
        Remove-Item -Path $BinDir -Recurse -Force
        Write-Host "[SUCESSO] Diretório de binários removido." -ForegroundColor Green
    }

    if ($Purge) {
        Write-Warning "Parâmetro -Purge informado. Removendo todo o diretório $InstallDir..."
        if (Test-Path $InstallDir) {
            Remove-Item -Path $InstallDir -Recurse -Force
        }
        Write-Host "[SUCESSO] Todos os dados, plugins e configurações foram removidos." -ForegroundColor Green
    }
    else {
        Write-Host "[SUCESSO] Binários e serviço removidos com sucesso." -ForegroundColor Green
        Write-Host "[INFO] Dados, plugins e configurações foram preservados em $InstallDir." -ForegroundColor Yellow
        Write-Host "[INFO] Para remover tudo permanentemente, utilize: .\install.ps1 -Purge" -ForegroundColor Gray
    }
}

# Tratamento dos Parâmetros Principais
if ($Status) {
    Show-Status
    exit 0
}

if ($Uninstall -or $Purge) {
    Uninstall-Supervisor
    exit 0
}

# Fluxo de Instalação / Atualização
Write-Banner
Check-Administrator
Check-Connectivity
Detect-System
Check-ExistingInstallation
Download-Artifacts
Stop-ExistingService
Install-Files
Configure-ScheduledTask
Verify-Health

Write-Host ""
Write-Host "[SUCESSO] Instalação e configuração de 0itocore-supervisor concluídas!" -ForegroundColor Green
Write-Host "  Diretório de Operação: $InstallDir" -ForegroundColor Cyan
Write-Host "  Arquivo de Config:     $ConfigPath" -ForegroundColor Cyan
Write-Host "  Gerenciamento Daemon:  Get-ScheduledTask -TaskName $TaskName" -ForegroundColor Yellow
Write-Host "  Healthcheck Local:     http://127.0.0.1:$Port/health" -ForegroundColor Yellow
Write-Host "  Comando CLI Direto:    0itocore-supervisor.exe --help" -ForegroundColor Yellow
Write-Host ""
