@echo off
setlocal EnableExtensions DisableDelayedExpansion
title OTIMIZADOR JARU v25 - Arquivo Unico (.bat)
color 0A

:: Resolve caminhos UNC para unidade temporaria mapeada pelo pushd
pushd "%~dp0" >nul 2>&1
if errorlevel 1 (
    set "BASE_DIR=%~dp0"
    set "BAT_SELF=%~f0"
) else (
    set "BASE_DIR=%CD%"
    if "%CD:~-1%"=="\" (
        set "BAT_SELF=%CD%%~nx0"
    ) else (
        set "BAT_SELF=%CD%\%~nx0"
    )
)
if "%BASE_DIR:~-1%"=="\" set "BASE_DIR=%BASE_DIR:~0,-1%"
set "EXIT_CODE=0"

:: Verifica privilegio de Administrador (com protecao anti-loop e caracteres especiais)
call :FN_REQUIRE_ADMIN "%~f0" "%~1"
if errorlevel 5 (
    set "EXIT_CODE=5"
    goto :EXIT_CLEAN
)
if errorlevel 2 (
    set "EXIT_CODE=0"
    goto :EXIT_CLEAN
)

if not exist "%BAT_SELF%" (
    echo [!] ERRO: Nao foi possivel localizar o proprio script apos elevacao.
    echo     Se executou de uma unidade de rede mapeada, copie para uma pasta local ou USB.
    echo.
    pause
    set "EXIT_CODE=2"
    goto :EXIT_CLEAN
)

:: Carrega em memoria o motor v25 embutido abaixo do marcador (sem arquivo temporario e sem limite de 8191 chars)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$m='###_JARU_'+'V25_PS1_START_###'; $c=[IO.File]::ReadAllText($env:BAT_SELF,[Text.Encoding]::UTF8); $i=$c.IndexOf($m); if($i -lt 0){ Write-Host '[!] Erro interno: bloco principal nao encontrado.' -ForegroundColor Red; Read-Host 'Pressione ENTER para sair'; exit 2 }; & ([ScriptBlock]::Create($c.Substring($i+$m.Length))) -BaseDir $env:BASE_DIR"
set "EXIT_CODE=%ERRORLEVEL%"

:EXIT_CLEAN
popd >nul 2>&1
endlocal & exit /b %EXIT_CODE%


:: ====================================================================================
:: FUNCOES AUXILIARES DO INICIALIZADOR (.BAT)
:: ====================================================================================

:: Retorna 0 apenas se o usuario pressionar S (Ctrl+C, N ou erro retornam 1)
:FN_CONFIRM
setlocal EnableExtensions DisableDelayedExpansion
choice /c SN /n /m "%~1"
set "RC=%ERRORLEVEL%"
if "%RC%"=="1" (
    endlocal & exit /b 0
)
endlocal & exit /b 1


:: Eleva via cmd.exe /s /c (imune a &, @, = e espacos no caminho)
:FN_REQUIRE_ADMIN
setlocal EnableExtensions DisableDelayedExpansion
fltmc >nul 2>&1
if not errorlevel 1 (
    endlocal & exit /b 0
)
if /i "%~2"=="--elevated" (
    echo [!] ERRO: Nao foi possivel obter privilegios de Administrador.
    pause
    endlocal & exit /b 5
)
echo [!] Este utilitario precisa ser executado como Administrador.
call :FN_CONFIRM "Deseja abrir automaticamente como Administrador agora? [S/N]: "
if errorlevel 1 (
    endlocal & exit /b 5
)
set "SELF_PATH=%~f1"
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "try { $q=[char]34; $arg='/s /c '+$q+$q+$env:SELF_PATH+$q+' --elevated'+$q; Start-Process -FilePath $env:ComSpec -ArgumentList $arg -Verb RunAs -ErrorAction Stop; exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo [!] Elevacao UAC cancelada pelo usuario.
    pause
    endlocal & exit /b 5
)
endlocal & exit /b 2


###_JARU_V25_PS1_START_###
param(
    [string]$BaseDir = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host '[!] Este utilitario requer Windows PowerShell 5.1 ou superior.' -ForegroundColor Red
    Read-Host 'Pressione ENTER para sair'
    exit 1
}

# ====================================================================================
# INICIALIZACAO E VERIFICACAO DE PRIVILEGIOS
# ====================================================================================

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host '[!] Execute o Otimizador_Jaru_v25.bat como Administrador.' -ForegroundColor Red
    Read-Host 'Pressione ENTER para sair'
    exit 5
}

if ([string]::IsNullOrWhiteSpace($BaseDir)) {
    $BaseDir = (Get-Location).Path
}

$Script:BaseDir = $BaseDir.Trim().TrimEnd('\')
if ($Script:BaseDir -match '^[A-Za-z]:$') { $Script:BaseDir += '\' }

$Script:LogFile         = Join-Path $Script:BaseDir 'otimizador_jaru_log.txt'
$Script:SnapAntesFile   = Join-Path $Script:BaseDir 'otim_antes.json'
$Script:BackupDir       = Join-Path $Script:BaseDir 'backups_jaru'
$Script:MasterRegFile   = Join-Path $Script:BackupDir 'master_reg.json'
$Script:SvcBackupFile   = Join-Path $Script:BackupDir 'servicos_original.json'
$Script:PowerBackupFile = Join-Path $Script:BackupDir 'power_original.txt'
$Script:UltimateFile    = Join-Path $Script:BackupDir 'ultimate_guid.txt'

try { $Host.UI.RawUI.WindowTitle = 'OTIMIZADOR JARU v25 - Modular, Defensivo, Debloat e Reversivel' } catch {}

# ====================================================================================
# FUNCOES UTILITARIAS E DEFENSIVAS
# ====================================================================================

function Write-Log {
    param([string]$Message)
    try {
        $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Add-Content -LiteralPath $Script:LogFile -Value "[$ts] $Message" -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Pause-Menu {
    Write-Host ''
    Read-Host 'Pressione ENTER para voltar ao menu' | Out-Null
}

function Confirm-Action {
    param([string]$Prompt = 'Deseja continuar? [S/N]:')
    Write-Host -NoNewline "$Prompt " -ForegroundColor Yellow
    try {
        $prevCtrl = [Console]::TreatControlCAsInput
        [Console]::TreatControlCAsInput = $true
        try {
            while ($true) {
                $key = [Console]::ReadKey($true)
                if (($key.Modifiers -band [ConsoleModifiers]::Control) -and $key.Key -eq [ConsoleKey]::C) {
                    Write-Host 'Cancelado (Ctrl+C)' -ForegroundColor DarkYellow
                    return $false
                }
                if ($key.Key -eq [ConsoleKey]::Escape) {
                    Write-Host 'N' -ForegroundColor DarkYellow
                    return $false
                }
                $ch = $key.KeyChar.ToString().ToUpperInvariant()
                if ($ch -eq 'S') {
                    Write-Host 'S' -ForegroundColor Green
                    return $true
                }
                if ($ch -eq 'N') {
                    Write-Host 'N' -ForegroundColor DarkYellow
                    return $false
                }
            }
        } finally {
            [Console]::TreatControlCAsInput = $prevCtrl
        }
    } catch {
        $ans = Read-Host
        return ($null -ne $ans -and $ans.Trim().ToUpperInvariant() -eq 'S')
    }
}

function New-SafeRestorePoint {
    param([string]$Description)
    $srReg = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    $freqName = 'SystemRestorePointCreationFrequency'
    $hadFreq = $false
    $oldFreq = $null

    try {
        Enable-ComputerRestore -Drive ($env:SystemDrive + '\') -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $srReg) {
            $k = Get-Item -LiteralPath $srReg -ErrorAction SilentlyContinue
            if ($k) {
                $oldFreq = $k.GetValue($freqName, $null)
                if ($null -ne $oldFreq) { $hadFreq = $true }
            }
            Set-ItemProperty -LiteralPath $srReg -Name $freqName -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        }

        Checkpoint-Computer -Description $Description -RestorePointType 'MODIFY_SETTINGS' -WarningAction Stop -ErrorAction Stop
        Write-Host "      [OK] Ponto de restauracao criado ($Description)." -ForegroundColor Green
        return $true
    } catch {
        Write-Host "      [AVISO] Ponto de restauracao pulado: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    } finally {
        try {
            if (Test-Path -LiteralPath $srReg) {
                if ($hadFreq) {
                    Set-ItemProperty -LiteralPath $srReg -Name $freqName -Value ([int]$oldFreq) -Type DWord -Force -ErrorAction SilentlyContinue
                } else {
                    Remove-ItemProperty -LiteralPath $srReg -Name $freqName -Force -ErrorAction SilentlyContinue
                }
            }
        } catch {}
    }
}

function Backup-RegistryTargets {
    param([array]$Targets)
    New-Item -ItemType Directory -Path $Script:BackupDir -Force | Out-Null

    $existing = @{}
    if (Test-Path -LiteralPath $Script:MasterRegFile) {
        try {
            $rawJson = Get-Content -LiteralPath $Script:MasterRegFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($item in @($rawJson)) {
                if ($item -and $item.p -and $item.n) {
                    $existing[($item.p + '|' + $item.n).ToLowerInvariant()] = $item
                }
            }
        } catch {}
    }

    $added = 0
    foreach ($t in $Targets) {
        $id = ($t.p + '|' + $t.n).ToLowerInvariant()
        if (-not $existing.ContainsKey($id)) {
            $keyEx = Test-Path -LiteralPath $t.p
            $valEx = $false
            $val   = $null
            $kind  = 'DWord'
            if ($keyEx) {
                try {
                    $k = Get-Item -LiteralPath $t.p -ErrorAction Stop
                    $raw = $k.GetValue($t.n, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                    if ($null -ne $raw) {
                        $valEx = $true
                        $val   = $raw
                        $kind  = $k.GetValueKind($t.n).ToString()
                    }
                } catch {}
            }
            $existing[$id] = [PSCustomObject]@{
                p     = $t.p
                n     = $t.n
                keyEx = $keyEx
                valEx = $valEx
                val   = $val
                kind  = $kind
            }
            $added++
        }
    }

    @($existing.Values) | ConvertTo-Json -Depth 4 -Compress | Set-Content -LiteralPath $Script:MasterRegFile -Encoding UTF8
    if ($added -gt 0) {
        Write-Host "      [OK] Backup mestre de Registro atualizado (+$added entradas protegidas)." -ForegroundColor Green
    } else {
        Write-Host '      [INFO] Backup mestre de Registro anterior preservado (sem sobrescrita).' -ForegroundColor Cyan
    }
}

function Set-RegistryDWord {
    param(
        [string]$Path,
        [string]$Name,
        [int]$Value
    )
    try {
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
        return $true
    } catch {
        Write-Host "      [AVISO] Falha ao gravar $Path\$Name : $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

function Restore-RegistryFromFile {
    param([string]$FilePath)
    if (-not (Test-Path -LiteralPath $FilePath)) { return $false }

    $rawJson = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($t in @($rawJson)) {
        if (-not $t -or -not $t.p -or -not $t.n) { continue }
        try {
            if ($t.valEx) {
                if (-not (Test-Path -LiteralPath $t.p)) {
                    New-Item -Path $t.p -Force -ErrorAction Stop | Out-Null
                }
                $v = $t.val
                if ($t.kind -eq 'DWord')           { $v = [int]$t.val }
                elseif ($t.kind -eq 'QWord')       { $v = [long]$t.val }
                elseif ($t.kind -eq 'Binary')      { $v = [byte[]]$t.val }
                elseif ($t.kind -eq 'MultiString') { $v = [string[]]$t.val }
                Set-ItemProperty -LiteralPath $t.p -Name $t.n -Value $v -Type $t.kind -Force -ErrorAction Stop
            } else {
                if (Test-Path -LiteralPath $t.p) {
                    Remove-ItemProperty -LiteralPath $t.p -Name $t.n -Force -ErrorAction SilentlyContinue
                    if (-not $t.keyEx) {
                        $k = Get-Item -LiteralPath $t.p -ErrorAction SilentlyContinue
                        if ($k -and $k.ValueCount -eq 0 -and $k.SubKeyCount -eq 0) {
                            Remove-Item -LiteralPath $t.p -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
        } catch {}
    }
    return $true
}

function Remove-ChildrenSafe {
    param(
        [System.IO.DirectoryInfo]$DirInfo,
        [bool]$RemoveSelf = $false
    )
    try {
        foreach ($file in $DirInfo.EnumerateFiles()) {
            try {
                if ($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
                if ($file.IsReadOnly) { $file.IsReadOnly = $false }
                $file.Delete()
            } catch {}
        }
        foreach ($sub in $DirInfo.EnumerateDirectories()) {
            try {
                if ($sub.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
                Remove-ChildrenSafe -DirInfo $sub -RemoveSelf $true
            } catch {}
        }
        if ($RemoveSelf) {
            try {
                if ($DirInfo.Attributes -band [System.IO.FileAttributes]::ReadOnly) {
                    $DirInfo.Attributes = $DirInfo.Attributes -band (-bnot [System.IO.FileAttributes]::ReadOnly)
                }
                $DirInfo.Delete($false)
            } catch {}
        }
    } catch {}
}

function Clear-DirectorySafe {
    param([string]$TargetPath)
    if ([string]::IsNullOrWhiteSpace($TargetPath)) { return $false }

    # Remove multiplas barras finais
    $clean = $TargetPath.Trim().TrimEnd('\')
    if ([string]::IsNullOrWhiteSpace($clean)) { return $false }

    # Exige caminho absoluto local (X:\...) e rejeita '/' ou traversal '..'
    if ($clean -notmatch '^[A-Za-z]:\\.+') { return $false }
    if ($clean.Contains('/')) { return $false }
    if ($clean -match '(^|\\)\.\.(\\|$)') { return $false }

    try {
        $full = [System.IO.Path]::GetFullPath($clean).TrimEnd('\')
    } catch { return $false }

    # Lista expandida de diretorios criticos protegidos
    $blocked = @(
        $env:SystemRoot,
        (Join-Path $env:SystemRoot 'System32'),
        (Join-Path $env:SystemRoot 'SysWOW64'),
        $env:UserProfile,
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        $env:ProgramData,
        $env:LocalAppData,
        $env:AppData,
        (Join-Path ($env:SystemDrive + '\') 'Users'),
        $Script:BaseDir
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.TrimEnd('\') }

    foreach ($b in $blocked) {
        if ($full.Equals($b, [StringComparison]::OrdinalIgnoreCase)) { return $false }
    }

    # Protege contra autoexclusao caso o script rode de dentro do alvo (ex.: %TEMP%)
    $baseSlash = $Script:BaseDir.TrimEnd('\') + '\'
    $fullSlash = $full + '\'
    if ($baseSlash.StartsWith($fullSlash, [StringComparison]::OrdinalIgnoreCase)) { return $false }

    if (-not (Test-Path -LiteralPath $full -PathType Container)) { return $true }

    # Recusa caso o proprio diretorio-alvo seja um symlink ou junction
    try {
        $rootInfo = Get-Item -LiteralPath $full -Force -ErrorAction Stop
        if ($rootInfo.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { return $false }
    } catch { return $false }

    $dirObj = New-Object System.IO.DirectoryInfo($full)
    Remove-ChildrenSafe -DirInfo $dirObj -RemoveSelf $false
    return $true
}

function Invoke-CheckBrowsers {
    $names = @('chrome', 'msedge', 'brave', 'opera', 'vivaldi', 'firefox')
    $running = @(Get-Process -Name $names -ErrorAction SilentlyContinue)
    if ($running.Count -eq 0) { return }

    Write-Host '[AVISO] Navegadores em execucao detectados (Chrome/Edge/Brave/Opera/Vivaldi/Firefox).' -ForegroundColor Yellow
    Write-Host '        Arquivos bloqueados em uso nao podem ser removidos.' -ForegroundColor Yellow
    if (-not (Confirm-Action 'Deseja fechar os navegadores agora para limpeza completa? [S/N]:')) {
        Write-Host '      [INFO] Continuando sem fechar navegadores.' -ForegroundColor Cyan
        Write-Host ''
        return
    }

    foreach ($p in $running) {
        try { $null = $p.CloseMainWindow() } catch {}
    }
    Start-Sleep -Seconds 2

    $still = @(Get-Process -Name $names -ErrorAction SilentlyContinue)
    if ($still.Count -gt 0) {
        $still | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }
    Write-Host '      [OK] Navegadores encerrados com seguranca.' -ForegroundColor Green
    Write-Host ''
}

function Get-SystemMetrics {
    $drv = $env:SystemDrive.Substring(0, 1)
    $os  = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $ram = if ($os) { [math]::Round($os.FreePhysicalMemory / 1024, 0) } else { 0 }
    $procs = @(Get-Process -ErrorAction SilentlyContinue).Count
    $disk  = (Get-PSDrive -Name $drv -ErrorAction SilentlyContinue).Free

    # Latencia ICMP 1.1.1.1
    $pingMs = 'N/A'
    try {
        $po = New-Object System.Net.NetworkInformation.Ping
        $ts = @()
        for ($i = 0; $i -lt 2; $i++) {
            try {
                $r = $po.Send('1.1.1.1', 800)
                if ($r.Status -eq 'Success') { $ts += $r.RoundtripTime }
            } catch {}
        }
        if ($ts.Count -gt 0) {
            $pingMs = [math]::Round(($ts | Measure-Object -Average).Average, 0)
        }
    } catch {}

    # Tempo de resolucao DNS
    $dnsMs = 'N/A'
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $null = [System.Net.Dns]::GetHostAddresses('one.one.one.one')
        $sw.Stop()
        $dnsMs = [math]::Round($sw.Elapsed.TotalMilliseconds, 0)
    } catch {}

    return [PSCustomObject]@{
        ram   = $ram
        procs = $procs
        disk  = $disk
        ping  = $pingMs
        dns   = $dnsMs
    }
}

function Save-Baseline {
    $snap = Get-SystemMetrics
    $snap | ConvertTo-Json -Compress | Set-Content -LiteralPath $Script:SnapAntesFile -Encoding UTF8
    return $snap
}

function Restart-ExplorerSafe {
    $currUser = $env:USERNAME
    try {
        $exps = @(Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue)
        foreach ($p in $exps) {
            try {
                $owner = Invoke-CimMethod -InputObject $p -MethodName GetOwner -ErrorAction SilentlyContinue
                if ($owner -and $owner.User -and $owner.User.Equals($currUser, [StringComparison]::OrdinalIgnoreCase)) {
                    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
                }
            } catch {}
        }
    } catch {}

    # Aguarda o AutoRestartShell do Winlogon antes de abrir novo explorer.exe
    Start-Sleep -Seconds 2
    $alive = $false
    $after = @(Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue)
    foreach ($p in $after) {
        try {
            $owner = Invoke-CimMethod -InputObject $p -MethodName GetOwner -ErrorAction SilentlyContinue
            if ($owner -and $owner.User -and $owner.User.Equals($currUser, [StringComparison]::OrdinalIgnoreCase)) {
                $alive = $true
                break
            }
        } catch {}
    }
    if (-not $alive) {
        Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe')
    }
}

# ====================================================================================
# ACOES PRINCIPAIS (WORKFLOWS)
# ====================================================================================

function Invoke-OtimizacaoSegura {
    Clear-Host
    Write-Host '=====================================================================================' -ForegroundColor Cyan
    Write-Host '                       INICIANDO OTIMIZACAO SEGURA - JARU v25                        ' -ForegroundColor White
    Write-Host '=====================================================================================' -ForegroundColor Cyan
    Write-Host ''

    Invoke-CheckBrowsers

    Write-Host '[1/5] Backup Protegido, Ponto de Restauracao, Baseline e Plano de Energia...' -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $Script:BackupDir -Force | Out-Null

    # Backup do plano de energia original (protegido contra sobrescrita)
    if (-not (Test-Path -LiteralPath $Script:PowerBackupFile)) {
        $pm = powercfg /getactivescheme | Select-String '([0-9a-fA-F-]{36})' | Select-Object -First 1
        if ($pm) {
            Set-Content -LiteralPath $Script:PowerBackupFile -Value $pm.Matches[0].Groups[1].Value -Encoding UTF8
            Write-Host '      [OK] Plano de energia original salvo.' -ForegroundColor Green
        }
    } else {
        Write-Host '      [INFO] Backup do plano de energia anterior preservado.' -ForegroundColor Cyan
    }

    # Backup mestre incremental do Registro
    $optTargets = @(
        @{ p = 'HKCU:\Software\Microsoft\GameBar';                                  n = 'AllowAutoGameMode' },
        @{ p = 'HKCU:\Software\Microsoft\GameBar';                                  n = 'AutoGameModeEnabled' },
        @{ p = 'HKCU:\System\GameConfigStore';                                      n = 'GameDVR_Enabled' },
        @{ p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR';           n = 'AppCaptureEnabled' },
        @{ p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization';    n = 'DODownloadMode' }
    )
    Backup-RegistryTargets -Targets $optTargets

    # Ponto de restauracao ANTES do baseline (evita delta negativo de espaco em disco)
    New-SafeRestorePoint -Description 'Otimizador Jaru v25' | Out-Null

    # Captura baseline limpo apos VSS
    Save-Baseline | Out-Null
    Write-Host '      [OK] Baseline registrado.' -ForegroundColor Green

    # Plano de energia (verifica bateria em notebooks antes de alterar)
    $applyPower = $true
    $batteries = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
    if ($batteries.Count -gt 0) {
        Write-Host '      [AVISO] Notebook/bateria detectado. Desempenho Maximo aumenta consumo e calor.' -ForegroundColor Yellow
        $applyPower = Confirm-Action '      Deseja ativar Desempenho Maximo mesmo assim? [S/N]:'
    }

    if ($applyPower) {
        $listOut = (powercfg -l) -join [Environment]::NewLine
        $guid = $null
        if (Test-Path -LiteralPath $Script:UltimateFile) {
            $sv = (Get-Content -LiteralPath $Script:UltimateFile -Raw -Encoding UTF8).Trim()
            if ($sv -and $listOut -match [regex]::Escape($sv)) { $guid = $sv }
        }
        if (-not $guid) {
            $m = [regex]::Match($listOut, '(?i)([0-9a-fA-F-]{36})[^\r\n]*(Ultimate Performance|Desempenho M.ximo|M.ximo rendimiento|Performances optimales|Ultimative Leistung)')
            if ($m.Success) { $guid = $m.Groups[1].Value }
        }
        if (-not $guid) {
            $dupOut = (powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61) -join [Environment]::NewLine
            $m = [regex]::Match($dupOut, '([0-9a-fA-F-]{36})')
            if ($m.Success) { $guid = $m.Groups[1].Value }
        }
        if ($guid) {
            Set-Content -LiteralPath $Script:UltimateFile -Value $guid -Encoding UTF8
            powercfg /setactive $guid | Out-Null
        }
        if ($guid -and $LASTEXITCODE -eq 0) {
            Write-Host '      [OK] Plano Desempenho Maximo ativado.' -ForegroundColor Green
        } else {
            powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host '      [OK] Plano Alto Desempenho ativado (fallback).' -ForegroundColor Green
            } else {
                Write-Host '      [AVISO] Planos avancados bloqueados (ex.: notebook Modern Standby S0).' -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host '      [INFO] Plano de energia atual mantido.' -ForegroundColor Cyan
    }
    Write-Host ''

    Write-Host '[2/5] Aplicando ajustes seguros de Registro (Game Mode ON, GameDVR OFF, P2P OFF)...' -ForegroundColor Cyan
    Set-RegistryDWord 'HKCU:\Software\Microsoft\GameBar'                               'AllowAutoGameMode'   1 | Out-Null
    Set-RegistryDWord 'HKCU:\Software\Microsoft\GameBar'                               'AutoGameModeEnabled' 1 | Out-Null
    Set-RegistryDWord 'HKCU:\System\GameConfigStore'                                   'GameDVR_Enabled'     0 | Out-Null
    Set-RegistryDWord 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'        'AppCaptureEnabled'   0 | Out-Null
    Set-RegistryDWord 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode'      0 | Out-Null
    Write-Host '      [OK] Registro atualizado com seguranca.' -ForegroundColor Green
    Write-Host ''

    Write-Host '[3/5] Limpando Temporarios, CrashDumps e Relatorios WER (preserva Prefetch/Shaders)...' -ForegroundColor Cyan
    $tempDirs = @(
        $env:TEMP,
        (Join-Path $env:SystemRoot 'Temp'),
        (Join-Path $env:LocalAppData 'CrashDumps'),
        (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportQueue'),
        (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive')
    )
    foreach ($d in $tempDirs) { Clear-DirectorySafe -TargetPath $d | Out-Null }
    Write-Host '      [OK] Temporarios e dumps de erro limpos sem seguir links simbolicos.' -ForegroundColor Green
    Write-Host ''

    Write-Host '[4/5] Limpando Cache de Navegadores em todos os perfis (preserva senhas e historico)...' -ForegroundColor Cyan
    $chromiumBases = @(
        (Join-Path $env:LocalAppData 'Google\Chrome\User Data'),
        (Join-Path $env:LocalAppData 'Microsoft\Edge\User Data'),
        (Join-Path $env:LocalAppData 'BraveSoftware\Brave-Browser\User Data'),
        (Join-Path $env:LocalAppData 'Vivaldi\User Data')
    )
    foreach ($base in $chromiumBases) {
        if (Test-Path -LiteralPath $base -PathType Container) {
            $profiles = @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -eq 'Default' -or $_.Name -like 'Profile *'
            })
            foreach ($p in $profiles) {
                Clear-DirectorySafe -TargetPath (Join-Path $p.FullName 'Cache\Cache_Data') | Out-Null
                Clear-DirectorySafe -TargetPath (Join-Path $p.FullName 'Code Cache') | Out-Null
            }
        }
    }

    # Opera moderno e Opera GX
    $operaBases = @(
        (Join-Path $env:LocalAppData 'Opera Software\Opera Stable'),
        (Join-Path $env:LocalAppData 'Opera Software\Opera GX Stable')
    )
    foreach ($op in $operaBases) {
        if (Test-Path -LiteralPath $op -PathType Container) {
            Clear-DirectorySafe -TargetPath (Join-Path $op 'Cache\Cache_Data') | Out-Null
            Clear-DirectorySafe -TargetPath (Join-Path $op 'Default\Cache\Cache_Data') | Out-Null
            Clear-DirectorySafe -TargetPath (Join-Path $op 'Default\Code Cache') | Out-Null
        }
    }

    # Firefox
    $ffRoot = Join-Path $env:LocalAppData 'Mozilla\Firefox\Profiles'
    if (Test-Path -LiteralPath $ffRoot -PathType Container) {
        foreach ($fp in @(Get-ChildItem -LiteralPath $ffRoot -Directory -ErrorAction SilentlyContinue)) {
            Clear-DirectorySafe -TargetPath (Join-Path $fp.FullName 'cache2\entries') | Out-Null
        }
    }
    Write-Host '      [OK] Caches de navegadores limpos (incluindo Opera e Opera GX).' -ForegroundColor Green
    Write-Host ''

    Write-Host '[5/5] Limpando Cache DNS (preserva IP fixo e DNS configurado)...' -ForegroundColor Cyan
    try {
        Clear-DnsClientCache -ErrorAction Stop
    } catch {
        ipconfig /flushdns | Out-Null
    }
    Write-Host '      [OK] Cache DNS limpo.' -ForegroundColor Green

    Show-Relatorio -WriteToLog $true
}

function Invoke-LimpezaAvancada {
    Clear-Host
    Write-Host '=====================================================================================' -ForegroundColor Cyan
    Write-Host '                         LIMPEZA AVANCADA OPCIONAL - JARU v25                        ' -ForegroundColor White
    Write-Host '=====================================================================================' -ForegroundColor Cyan
    Write-Host ' ATENCAO: Esta opcao vai:'
    Write-Host '  1. Esvaziar permanentemente a Lixeira.'
    Write-Host '  2. Limpar o cache do Delivery Optimization (residuos de atualizacao).'
    Write-Host '  3. Apagar downloads pendentes do Windows Update (SoftwareDistribution\Download).'
    Write-Host '=====================================================================================' -ForegroundColor Cyan
    if (-not (Confirm-Action 'Deseja continuar? [S/N]:')) { return }

    if (-not (Test-Path -LiteralPath $Script:SnapAntesFile)) { Save-Baseline | Out-Null }

    Write-Host ''
    Write-Host '[1/2] Esvaziando Lixeira e Cache do Delivery Optimization...' -ForegroundColor Cyan
    try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch {}
    if (Get-Command -Name 'Delete-DeliveryOptimizationCache' -ErrorAction SilentlyContinue) {
        try { Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue | Out-Null } catch {}
    }
    Write-Host '      [OK] Lixeira e cache de Delivery Optimization limpos.' -ForegroundColor Green

    Write-Host '[2/2] Limpando downloads do Windows Update (preservando estado dos servicos)...' -ForegroundColor Cyan
    $wuSvcs = @('wuauserv', 'bits')
    $wasRunning = @()
    foreach ($s in $wuSvcs) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Running') {
            $wasRunning += $s
            try { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue } catch {}
        }
    }

    Clear-DirectorySafe -TargetPath (Join-Path $env:SystemRoot 'SoftwareDistribution\Download') | Out-Null

    [array]::Reverse($wasRunning)
    foreach ($s in $wasRunning) {
        try { Start-Service -Name $s -ErrorAction SilentlyContinue } catch {}
    }

    Write-Host '      [OK] Cache do Windows Update limpo e servicos restaurados ao estado original.' -ForegroundColor Green
    Write-Log 'Jaru v25 LIMPEZA AVANCADA executada.'
    Pause-Menu
}

function Invoke-Debloat {
    Clear-Host
    Write-Host '=====================================================================================' -ForegroundColor Cyan
    Write-Host '              MODULO DEBLOAT + PRIVACIDADE E INTERFACE (OFFLINE)                     ' -ForegroundColor White
    Write-Host '=====================================================================================' -ForegroundColor Cyan
    Write-Host ' Esta opcao vai:'
    Write-Host '  1. Salvar backup no Registro mestre + criar Ponto de Restauracao.'
    Write-Host '  2. Remover Bloatware (preserva Store, Media Player, Solucionadores/GetHelp,'
    Write-Host '     Fotos, Calc, Paint, Defender e efeitos visuais).'
    Write-Host '  3. ATENCAO: Remove Teams, Spotify, Vincular Celular, Clipchamp e Assistencia Rapida.'
    Write-Host '     Pacotes removidos e desprovisionados exigem a Microsoft Store para reinstalar.'
    Write-Host '  4. Desativar Bing no Iniciar, Destaques da Pesquisa, Copilot, Widgets (Pro+),'
    Write-Host '     Anuncios, GameDVR e reduzir Telemetria ao nivel minimo efetivo (1).'
    Write-Host '=====================================================================================' -ForegroundColor Cyan
    if (-not (Confirm-Action 'Deseja continuar? [S/N]:')) { return }

    Write-Host ''
    Write-Host '[1/4] Backup mestre do Registro e Ponto de Restauracao...' -ForegroundColor Cyan
    $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    $debloatTargets = @(
        @{ p = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer';            n = 'DisableSearchBoxSuggestions' },
        @{ p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search';      n = 'EnableDynamicContentInWSB' },
        @{ p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search';        n = 'BingSearchEnabled' },
        @{ p = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot';      n = 'TurnOffWindowsCopilot' },
        @{ p = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh';                         n = 'AllowNewsAndInterests' },
        @{ p = $cdm; n = 'SubscribedContent-338388Enabled' },
        @{ p = $cdm; n = 'SubscribedContent-338389Enabled' },
        @{ p = $cdm; n = 'SubscribedContent-338393Enabled' },
        @{ p = $cdm; n = 'SubscribedContent-353694Enabled' },
        @{ p = $cdm; n = 'SubscribedContent-353696Enabled' },
        @{ p = $cdm; n = 'SystemPaneSuggestionsEnabled' },
        @{ p = $cdm; n = 'SoftLandingEnabled' },
        @{ p = $cdm; n = 'RotatingLockScreenOverlayEnabled' },
        @{ p = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; n = 'Enabled' },
        @{ p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection';        n = 'AllowTelemetry' },
        @{ p = 'HKCU:\System\GameConfigStore';                                    n = 'GameDVR_Enabled' },
        @{ p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR';               n = 'AllowGameDVR' }
    )
    Backup-RegistryTargets -Targets $debloatTargets
    New-SafeRestorePoint -Description 'Jaru v25 Antes Debloat' | Out-Null

    if (-not (Test-Path -LiteralPath $Script:SnapAntesFile)) { Save-Baseline | Out-Null }
    Write-Host ''

    Write-Host '[2/4] Removendo Bloatware Seguro (correspondencia exata de pacotes)...' -ForegroundColor Cyan
    $bloatApps = @(
        'Microsoft.BingNews',
        'Microsoft.BingWeather',
        'Microsoft.BingSearch',
        'Clipchamp.Clipchamp',
        'Microsoft.Copilot',
        'Microsoft.Getstarted',
        'Microsoft.MicrosoftOfficeHub',
        'Microsoft.MicrosoftSolitaireCollection',
        'Microsoft.People',
        'Microsoft.PowerAutomateDesktop',
        'Microsoft.Todos',
        'Microsoft.WindowsFeedbackHub',
        'Microsoft.WindowsMaps',
        'Microsoft.YourPhone',
        'Microsoft.ZuneVideo',
        'MicrosoftCorporationII.QuickAssist',
        'MicrosoftTeams',
        'MSTeams',
        'SpotifyAB.SpotifyMusic',
        'Disney.37853FC22B2CE',
        'BytedancePte.Ltd.TikTok'
    )

    $remOk = 0
    $remFail = 0
    $provAll = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)

    foreach ($app in $bloatApps) {
        $pkgs = @(Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue)
        foreach ($pkg in $pkgs) {
            try {
                Write-Host "      -> Removendo: $($pkg.Name)" -ForegroundColor Yellow
                Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                $remOk++
            } catch {
                Write-Host "      [AVISO] Nao foi possivel remover $($pkg.Name): $($_.Exception.Message)" -ForegroundColor DarkYellow
                $remFail++
            }
        }
        $provs = @($provAll | Where-Object { $_.DisplayName -eq $app })
        foreach ($pr in $provs) {
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $pr.PackageName -ErrorAction Stop | Out-Null
            } catch {}
        }
    }
    Write-Host "      [OK] Limpeza de apps concluida ($remOk removidos, $remFail protegidos/falhas)." -ForegroundColor Green
    Write-Host ''

    Write-Host '[3/4] Aplicando ajustes de Interface, Privacidade e Telemetria...' -ForegroundColor Cyan
    Set-RegistryDWord 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'       'DisableSearchBoxSuggestions' 1 | Out-Null
    Set-RegistryDWord 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'EnableDynamicContentInWSB'   0 | Out-Null
    Set-RegistryDWord 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'   'BingSearchEnabled'           0 | Out-Null

    Set-RegistryDWord 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1 | Out-Null
    Set-RegistryDWord 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'                    'AllowNewsAndInterests' 0 | Out-Null

    foreach ($v in @(
        'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled',
        'SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled',
        'SubscribedContent-353696Enabled', 'SystemPaneSuggestionsEnabled',
        'SoftLandingEnabled', 'RotatingLockScreenOverlayEnabled'
    )) {
        Set-RegistryDWord $cdm $v 0 | Out-Null
    }
    Set-RegistryDWord 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0 | Out-Null

    Set-RegistryDWord 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'  1 | Out-Null
    Set-RegistryDWord 'HKCU:\System\GameConfigStore'                             'GameDVR_Enabled' 0 | Out-Null
    Set-RegistryDWord 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'        'AllowGameDVR'    0 | Out-Null
    Write-Host '      [OK] Chaves de registro aplicadas.' -ForegroundColor Green
    Write-Host ''

    Write-Host '[4/4] Reiniciando Windows Explorer da sessao atual e registrando log...' -ForegroundColor Cyan
    Restart-ExplorerSafe
    Write-Log "Jaru v25 DEBLOAT executado | Apps removidos: $remOk | Falhas: $remFail"
    Write-Host '      [OK] Modulo Debloat concluido! Reinicie o PC para efeito total.' -ForegroundColor Green
    Pause-Menu
}

function Invoke-OtimizarServicos {
    Clear-Host
    Write-Host '=====================================================================================' -ForegroundColor Cyan
    Write-Host '             MODULO SERVICOS EM SEGUNDO PLANO (REVERSIVEL COM DELAYED START)         ' -ForegroundColor White
    Write-Host '=====================================================================================' -ForegroundColor Cyan
    Write-Host ' Esta opcao vai:'
    Write-Host '  1. Criar Ponto de Restauracao e backup completo (StartMode + DelayedAutoStart).'
    Write-Host '  2. Desativar 5 servicos de telemetria/demo (DiagTrack, MapsBroker, etc.).'
    Write-Host '  3. Definir servicos nao essenciais em Automatico para MANUAL (preserva WpnService,'
    Write-Host '     Bluetooth, Windows Hello/Biometria, BitLocker, Impressao e AppIDSvc).'
    Write-Host '=====================================================================================' -ForegroundColor Cyan
    if (-not (Confirm-Action 'Deseja continuar? [S/N]:')) { return }

    if (-not (Test-Path -LiteralPath $Script:SnapAntesFile)) { Save-Baseline | Out-Null }

    Write-Host ''
    Write-Host '[1/2] Criando Ponto de Restauracao e backup completo dos servicos...' -ForegroundColor Cyan
    New-SafeRestorePoint -Description 'Jaru v25 Antes Servicos' | Out-Null
    New-Item -ItemType Directory -Path $Script:BackupDir -Force | Out-Null

    $disableServices = @(
        'DiagTrack', 'dmwappushservice', 'MapsBroker', 'RetailDemo', 'RemoteRegistry'
    )

    $manualServices = @(
        'AJRouter', 'ALG', 'AppMgmt', 'AxInstSV', 'CertPropSvc', 'DcpSvc',
        'DevQueryBroker', 'diagnosticshub.standardcollector.service',
        'DisplayEnhancementService', 'EFS', 'Fax', 'fhsvc', 'icssvc', 'lfsvc',
        'lmhosts', 'MSiSCSI', 'NetTcpPortSharing', 'PcaSvc', 'PhoneSvc',
        'RasAuto', 'RasMan', 'SCardSvr', 'ScDeviceEnum', 'SCPolicySvc',
        'SDRSVC', 'SEMgrSvc', 'SensorDataService', 'SensorService', 'SensrSvc',
        'SharedAccess', 'SmsRouter', 'TapiSrv', 'TrkWks', 'WerSvc',
        'WMPNetworkSvc', 'WpcMonSvc', 'XblAuthManager', 'XblGameSave',
        'XboxGipSvc', 'XboxNetApiSvc'
    )

    $allSvcs = @{}
    Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | ForEach-Object {
        $allSvcs[$_.Name.ToLowerInvariant()] = $_
    }

    $existingBk = @{}
    if (Test-Path -LiteralPath $Script:SvcBackupFile) {
        try {
            $rawBk = Get-Content -LiteralPath $Script:SvcBackupFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($item in @($rawBk)) {
                if ($item -and $item.name) {
                    $existingBk[$item.name.ToLowerInvariant()] = $item
                }
            }
        } catch {}
    }

    $addedBk = 0
    foreach ($s in ($disableServices + $manualServices)) {
        $key = $s.ToLowerInvariant()
        if ($allSvcs.ContainsKey($key) -and -not $existingBk.ContainsKey($key)) {
            $info = $allSvcs[$key]
            $existingBk[$key] = [PSCustomObject]@{
                name    = $info.Name
                start   = $info.StartMode
                delayed = [bool]$info.DelayedAutoStart
            }
            $addedBk++
        }
    }
    @($existingBk.Values) | ConvertTo-Json -Depth 3 -Compress | Set-Content -LiteralPath $Script:SvcBackupFile -Encoding UTF8
    if ($addedBk -gt 0) {
        Write-Host "      [OK] Backup salvo para $addedBk servicos (com atributo DelayedAutoStart)." -ForegroundColor Green
    } else {
        Write-Host '      [INFO] Backup anterior de servicos preservado.' -ForegroundColor Cyan
    }

    Write-Host '[2/2] Aplicando otimizacao nos servicos...' -ForegroundColor Cyan
    $cDis = 0; $cMan = 0; $cSkip = 0; $cFail = 0

    foreach ($s in $disableServices) {
        $key = $s.ToLowerInvariant()
        if (-not $allSvcs.ContainsKey($key)) { continue }
        $info = $allSvcs[$key]
        if ($info.StartMode -eq 'Disabled') { $cSkip++; continue }
        try {
            Stop-Service -Name $info.Name -Force -ErrorAction SilentlyContinue
            & sc.exe config $info.Name 'start=' 'disabled' | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      -> Desativado: $($info.Name)" -ForegroundColor DarkYellow
                $cDis++
            } else {
                Write-Host "      [AVISO] Falha ao desativar $($info.Name) (codigo $LASTEXITCODE)." -ForegroundColor Yellow
                $cFail++
            }
        } catch {
            Write-Host "      [AVISO] Erro em $($info.Name): $($_.Exception.Message)" -ForegroundColor Yellow
            $cFail++
        }
    }

    foreach ($s in $manualServices) {
        $key = $s.ToLowerInvariant()
        if (-not $allSvcs.ContainsKey($key)) { continue }
        $info = $allSvcs[$key]
        if ($info.StartMode -eq 'Manual' -or $info.StartMode -eq 'Disabled') {
            $cSkip++
            continue
        }
        try {
            & sc.exe config $info.Name 'start=' 'demand' | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      -> Manual: $($info.Name)" -ForegroundColor Yellow
                $cMan++
            } else {
                Write-Host "      [AVISO] Falha ao alterar $($info.Name) (codigo $LASTEXITCODE)." -ForegroundColor Yellow
                $cFail++
            }
        } catch {
            Write-Host "      [AVISO] Erro em $($info.Name): $($_.Exception.Message)" -ForegroundColor Yellow
            $cFail++
        }
    }

    Write-Host "      [OK] Resultado: $cDis desativados, $cMan alterados para Manual, $cSkip ja estavam otimizados, $cFail falhas." -ForegroundColor Green
    Write-Host '      [INFO] Reinicie o PC para observar a reducao completa nos processos.' -ForegroundColor Cyan
    Write-Log "Jaru v25 SERVICOS executado | Desativados: $cDis | Manual: $cMan | Ja otimizados: $cSkip | Falhas: $cFail"
    Pause-Menu
}

function Show-Relatorio {
    param([bool]$WriteToLog = $false)
    Write-Host ''

    $antes = $null
    if (Test-Path -LiteralPath $Script:SnapAntesFile) {
        try {
            $antes = Get-Content -LiteralPath $Script:SnapAntesFile -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {}
    }

    $depois = Get-SystemMetrics
    $ramA   = if ($antes) { $antes.ram } else { 'N/A' }
    $procsA = if ($antes) { $antes.procs } else { 'N/A' }
    $diskA  = if ($antes) { [math]::Round($antes.disk / 1GB, 2) } else { 'N/A' }
    $diskD  = [math]::Round($depois.disk / 1GB, 2)
    $pingA  = if ($antes) { $antes.ping } else { 'N/A' }
    $dnsA   = if ($antes -and $null -ne $antes.PSObject.Properties['dns']) { $antes.dns } else { 'N/A' }

    $libMB   = if ($antes) { [math]::Round(($depois.disk - $antes.disk) / 1MB, 2) } else { 'N/A' }
    $ramDiff = if ($antes) { $depois.ram - $antes.ram } else { 'N/A' }

    Write-Host '================================================================================' -ForegroundColor Cyan
    Write-Host '                   RELATORIO JARU v25 (ANTES vs DEPOIS)                         ' -ForegroundColor White
    Write-Host '================================================================================' -ForegroundColor Cyan
    Write-Host ("RAM Livre (MB)       : $ramA -> $($depois.ram) (Delta: $ramDiff MB)") -ForegroundColor Green
    Write-Host ("Processos Ativos     : $procsA -> $($depois.procs)") -ForegroundColor Green
    Write-Host ("Espaco $($env:SystemDrive) (GB)       : $diskA -> $diskD (Liberado: $libMB MB)") -ForegroundColor Green
    Write-Host ("Ping 1.1.1.1 (ms)    : $pingA -> $($depois.ping)") -ForegroundColor Green
    Write-Host ("Resolucao DNS (ms)   : $dnsA -> $($depois.dns)") -ForegroundColor Green
    Write-Host '================================================================================' -ForegroundColor Cyan
    Write-Host 'NOTA: Alteracoes de Registro e Servicos aplicam completamente apos reiniciar.' -ForegroundColor Yellow

    if ($WriteToLog) {
        Write-Log "Jaru v25 OTIMIZACAO SEGURA executada | Espaco liberado: $libMB MB | RAM delta: $ramDiff MB"
    }
    Pause-Menu
}

function Invoke-Desfazer {
    Clear-Host
    Write-Host '=====================================================================================' -ForegroundColor Cyan
    Write-Host '             RESTAURANDO ESTADO ORIGINAL (REGISTRO + ENERGIA + SERVICOS)             ' -ForegroundColor White
    Write-Host '=====================================================================================' -ForegroundColor Cyan

    $legacyReg1 = Join-Path $Script:BackupDir 'reg_original.json'
    $legacyReg2 = Join-Path $Script:BackupDir 'debloat_reg_original.json'

    $hasAny = (Test-Path -LiteralPath $Script:MasterRegFile) -or
              (Test-Path -LiteralPath $Script:SvcBackupFile) -or
              (Test-Path -LiteralPath $Script:PowerBackupFile) -or
              (Test-Path -LiteralPath $legacyReg1) -or
              (Test-Path -LiteralPath $legacyReg2)

    if (-not $hasAny) {
        Write-Host "[!] Nenhum backup ativo encontrado em: $($Script:BackupDir)" -ForegroundColor Yellow
        Write-Host '    Execute as Opcoes [1], [3] ou [4] ao menos uma vez antes.' -ForegroundColor Yellow
        Pause-Menu
        return
    }

    if (-not (Confirm-Action 'Deseja restaurar todas as configuracoes originais salvas? [S/N]:')) { return }
    Write-Host ''

    $restoredItems = @()

    if (Restore-RegistryFromFile -FilePath $Script:MasterRegFile) {
        Write-Host '[OK] Registro mestre restaurado exatamente ao estado original.' -ForegroundColor Green
        $restoredItems += $Script:MasterRegFile
    }
    if (Restore-RegistryFromFile -FilePath $legacyReg2) {
        Write-Host '[OK] Registro legado de Debloat (v24) restaurado.' -ForegroundColor Green
        $restoredItems += $legacyReg2
    }
    if (Restore-RegistryFromFile -FilePath $legacyReg1) {
        Write-Host '[OK] Registro legado de Otimizacao (v24) restaurado.' -ForegroundColor Green
        $restoredItems += $legacyReg1
    }

    if (Test-Path -LiteralPath $Script:PowerBackupFile) {
        $guid = (Get-Content -LiteralPath $Script:PowerBackupFile -Raw -Encoding UTF8).Trim()
        if ($guid) {
            powercfg /setactive $guid | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] Plano de energia original restaurado ($guid)." -ForegroundColor Green
            } else {
                Write-Host '[AVISO] Nao foi possivel restaurar o plano de energia anterior.' -ForegroundColor Yellow
            }
        }
        $restoredItems += $Script:PowerBackupFile
    }

    if (Test-Path -LiteralPath $Script:SvcBackupFile) {
        $svcOk = 0; $svcFail = 0
        try {
            $svcs = Get-Content -LiteralPath $Script:SvcBackupFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($s in @($svcs)) {
                if (-not $s -or -not $s.name) { continue }
                $isDelayed = ($null -ne $s.PSObject.Properties['delayed']) -and ([bool]$s.delayed)
                $scMode = $null
                if (($s.start -eq 'Auto' -or $s.start -eq 'Automatic') -and $isDelayed) { $scMode = 'delayed-auto' }
                elseif ($s.start -eq 'Auto' -or $s.start -eq 'Automatic')               { $scMode = 'auto' }
                elseif ($s.start -eq 'Manual')                                         { $scMode = 'demand' }
                elseif ($s.start -eq 'Disabled')                                       { $scMode = 'disabled' }

                if ($scMode) {
                    & sc.exe config $s.name 'start=' $scMode | Out-Null
                    if ($LASTEXITCODE -eq 0) { $svcOk++ } else { $svcFail++ }
                }
            }
            Write-Host "[OK] Servicos restaurados: $svcOk com sucesso, $svcFail falhas/protegidos." -ForegroundColor Green
        } catch {
            Write-Host "[AVISO] Erro ao ler backup de servicos: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        $restoredItems += $Script:SvcBackupFile
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $archiveDir = Join-Path $Script:BackupDir "restored_$stamp"
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null

    foreach ($f in $restoredItems) {
        if (Test-Path -LiteralPath $f) {
            Move-Item -LiteralPath $f -Destination $archiveDir -Force -ErrorAction SilentlyContinue
        }
    }
    foreach ($lock in @(Get-ChildItem -LiteralPath $Script:BackupDir -Filter '*.lock' -File -ErrorAction SilentlyContinue)) {
        Move-Item -LiteralPath $lock.FullName -Destination $archiveDir -Force -ErrorAction SilentlyContinue
    }

    Write-Host "[OK] Backups restaurados arquivados em: $archiveDir" -ForegroundColor Cyan
    Write-Host ''
    Write-Host '[INFO] Apps Appx removidos podem ser reinstalados pela Microsoft Store ou via Ponto de Restauracao.' -ForegroundColor Yellow
    Write-Host '[INFO] Reinicie o PC para todas as configuracoes originais entrarem em vigor.' -ForegroundColor Yellow
    Write-Log "Jaru v25 DESFAZER executado | Arquivado em restored_$stamp"
    Pause-Menu
}

# ====================================================================================
# MENU PRINCIPAL
# ====================================================================================

$running = $true
while ($running) {
    Clear-Host
    Write-Host '=====================================================================================' -ForegroundColor Green
    Write-Host '          OTIMIZADOR JARU v25 - LIMPEZA + DESEMPENHO + DEBLOAT + SERVICOS            ' -ForegroundColor White
    Write-Host '=====================================================================================' -ForegroundColor Green
    Write-Host '  [1] Executar Otimizacao Segura (Backup + Energia + Limpeza + Rede)'
    Write-Host '  [2] Limpeza Avancada Opcional (Lixeira + Windows Update + Delivery Opt)'
    Write-Host '  [3] Debloat + Interface/Privacidade (Apps + Bing/Copilot/Widgets/Anuncios)'
    Write-Host '  [4] Otimizar Servicos em Segundo Plano (Telemetria OFF + Servicos em Manual)'
    Write-Host '  [5] Ver Relatorio Comparativo (ANTES vs DEPOIS com Delta Real)'
    Write-Host '  [6] DESFAZER - Restaurar Estado Original (Registro + Energia + Servicos)'
    Write-Host '  [0] Sair'
    Write-Host '=====================================================================================' -ForegroundColor Green

    $opt = Read-Host 'Selecione uma opcao [1-6 ou 0]'
    switch ($opt.Trim()) {
        '1' { Invoke-OtimizacaoSegura }
        '2' { Invoke-LimpezaAvancada }
        '3' { Invoke-Debloat }
        '4' { Invoke-OtimizarServicos }
        '5' { Show-Relatorio -WriteToLog $false }
        '6' { Invoke-Desfazer }
        '0' { $running = $false }
        default {
            Write-Host '[!] Opcao invalida.' -ForegroundColor Yellow
            Start-Sleep -Milliseconds 800
        }
    }
}