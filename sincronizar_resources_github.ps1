$ErrorActionPreference = "Stop"

$BaseRoot = "D:\meu-server-gta\Base"
$RepoRoot = "D:\meu-server-gta\Base\GitHub\ouro-fino-rp-code"
$DestinationResources = Join-Path $RepoRoot "resources"

$SelectedResources = @(
    "resources\vrp",
    "resources\[scripts]\crafting",
    "resources\[scripts]\inventory",
    "resources\[scripts]\target",
    "resources\[scripts]\painel",
    "resources\[scripts]\sao_judas_operations",
    "resources\[scripts]\sao_judas_street_sales",
    "resources\[scripts]\plants",
    "resources\[scripts]\of_aviao_sao_judas",
    "resources\[scripts]\notify",
    "resources\[scripts]\keyboard"
)

function Get-FullPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
}

$BaseRoot = Get-FullPath $BaseRoot
$RepoRoot = Get-FullPath $RepoRoot
$DestinationResources = Get-FullPath $DestinationResources

if (-not (Test-Path -LiteralPath $BaseRoot -PathType Container)) {
    throw "A Base não foi encontrada: $BaseRoot"
}

if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) {
    throw "O repositório não foi encontrado: $RepoRoot"
}

$ExpectedRepoSuffix = "\GitHub\ouro-fino-rp-code"
if (-not $RepoRoot.EndsWith($ExpectedRepoSuffix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Proteção de segurança: RepoRoot não termina em '$ExpectedRepoSuffix'. Nada foi apagado."
}

if ($DestinationResources -eq (Join-Path $BaseRoot "resources")) {
    throw "Proteção de segurança: o destino não pode ser a pasta resources da Base ativa."
}

$GitDirectory = Join-Path $RepoRoot ".git"
if (Test-Path -LiteralPath $GitDirectory -PathType Container) {
    Push-Location $RepoRoot
    try {
        $GitChanges = @(git status --porcelain --untracked-files=no 2>$null)
        if ($LASTEXITCODE -ne 0) {
            throw "Não foi possível consultar o status do Git."
        }

        if ($GitChanges.Count -gt 0) {
            Write-Host ""
            Write-Host "Existem alterações rastreadas no repositório:" -ForegroundColor Yellow
            $GitChanges | ForEach-Object { Write-Host $_ }
            throw "Faça commit ou guarde essas alterações rastreadas antes de sincronizar novamente."
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "Base ativa: $BaseRoot"
Write-Host "Destino Git: $RepoRoot"
Write-Host ""

if (Test-Path -LiteralPath $DestinationResources) {
    Write-Host "Removendo a cópia antiga de resources do repositório..." -ForegroundColor Cyan
    Remove-Item -LiteralPath $DestinationResources -Recurse -Force
}

New-Item -ItemType Directory -Path $DestinationResources -Force | Out-Null

$Copied = @()
$Missing = @()

foreach ($RelativePath in $SelectedResources) {
    $Source = Join-Path $BaseRoot $RelativePath
    $Destination = Join-Path $RepoRoot $RelativePath

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        Write-Warning "Não encontrado: $Source"
        $Missing += $RelativePath
        continue
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null

    Write-Host "Copiando: $RelativePath" -ForegroundColor Green

    & robocopy `
        $Source `
        $Destination `
        /E `
        /COPY:DAT `
        /DCOPY:DAT `
        /R:1 `
        /W:1 `
        /NFL `
        /NDL `
        /NJH `
        /NJS `
        /NP `
        /XD `
            "stream" `
            "node_modules" `
            ".git" `
            "cache" `
            "server-cache" `
            "server-cache-priv" `
            "logs" `
            "tmp" `
            "temp" `
        /XF `
            "*.log" `
            "*.tmp" `
            "*.cache" `
            "*.zip" `
            "*.7z" `
            "*.rar" `
            "*.mp4" `
            "*.webm" `
            "*.avi" `
            "*.mov" `
            "*.mkv"

    $RoboCode = $LASTEXITCODE
    if ($RoboCode -gt 7) {
        throw "Falha no Robocopy para '$RelativePath'. Código: $RoboCode"
    }

    $Copied += $RelativePath
}

$DocsSource = Join-Path $BaseRoot "docs"
$DocsDestination = Join-Path $RepoRoot "docs"

if (Test-Path -LiteralPath $DocsSource -PathType Container) {
    if (Test-Path -LiteralPath $DocsDestination) {
        Remove-Item -LiteralPath $DocsDestination -Recurse -Force
    }

    Write-Host "Copiando: docs" -ForegroundColor Green
    & robocopy `
        $DocsSource `
        $DocsDestination `
        /E `
        /COPY:DAT `
        /DCOPY:DAT `
        /R:1 `
        /W:1 `
        /NFL `
        /NDL `
        /NJH `
        /NJS `
        /NP `
        /XD ".git" "cache" "logs" "tmp" "temp" `
        /XF "*.log" "*.tmp" "*.zip" "*.7z" "*.rar"

    if ($LASTEXITCODE -gt 7) {
        throw "Falha ao copiar docs. Código: $LASTEXITCODE"
    }
}

Write-Host ""
Write-Host "Sincronização concluída." -ForegroundColor Green
Write-Host "Resources copiados: $($Copied.Count)"

if ($Missing.Count -gt 0) {
    Write-Host "Resources não encontrados: $($Missing.Count)" -ForegroundColor Yellow
    $Missing | ForEach-Object { Write-Host "  - $_" }
}

Write-Host ""
Write-Host "Próximos comandos:" -ForegroundColor Cyan
Write-Host "  cd `"$RepoRoot`""
Write-Host "  git status"
Write-Host "  git add ."
Write-Host "  git status"
