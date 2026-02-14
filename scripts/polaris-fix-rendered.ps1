param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = "",

    [Parameter(Mandatory = $false)]
    [string]$TestOutputDir = "",

    [Parameter(Mandatory = $false)]
    [string]$AppName = "test-app",

    [Parameter(Mandatory = $false)]
    [string]$LicencePlate = "abc123",

    [Parameter(Mandatory = $false)]
    [string]$PolarisConfigPath = "policies\\polaris.yaml"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

Set-Location $RepoRoot

function Resolve-LatestTestOutputDir {
    $dirs = Get-ChildItem -Directory -Name -Filter 'test-output-*' | Sort-Object
    if (-not $dirs -or $dirs.Count -eq 0) {
        throw "No test-output-* folders found under $RepoRoot"
    }
    return $dirs[-1]
}

if ([string]::IsNullOrWhiteSpace($TestOutputDir)) {
    if (Test-Path 'test-output') {
        $TestOutputDir = 'test-output'
    } else {
        $TestOutputDir = Resolve-LatestTestOutputDir
    }
} elseif (-not (Test-Path $TestOutputDir)) {
    throw "Test output dir not found: $TestOutputDir"
}

$polarisExe = Join-Path $TestOutputDir 'polaris.exe'
if (-not (Test-Path $polarisExe)) {
    throw "polaris.exe not found at $polarisExe. Run scripts/test-all-validations.bat first (it downloads tools into the test-output folder)."
}

$configFullPath = Join-Path $RepoRoot $PolarisConfigPath
if (-not (Test-Path $configFullPath)) {
    throw "Polaris config not found: $configFullPath"
}

$fixDir = Join-Path $TestOutputDir 'polaris-fix'
New-Item -ItemType Directory -Force -Path $fixDir | Out-Null

$helm = Get-Command helm -ErrorAction SilentlyContinue
if (-not $helm) {
    throw "helm not found on PATH. Install Helm and re-run. (polaris fix needs fresh manifests; this script re-renders via 'helm template'.)"
}

$generatedRepoDir = Join-Path $TestOutputDir ("{0}-gitops" -f $AppName)
$chartDir = Join-Path $generatedRepoDir 'charts\\gitops'
$valuesDir = Join-Path $generatedRepoDir 'deploy'

if (-not (Test-Path $chartDir)) {
    throw "Chart dir not found: $chartDir"
}
if (-not (Test-Path $valuesDir)) {
    throw "Values dir not found: $valuesDir"
}

# Ensure chart dependencies exist (helm dependency update is idempotent).
$chartsCacheDir = Join-Path $chartDir 'charts'
if (-not (Test-Path $chartsCacheDir)) {
    New-Item -ItemType Directory -Force -Path $chartsCacheDir | Out-Null
}

$needDepUpdate = $true
try {
    $tgzCount = (Get-ChildItem -Path $chartsCacheDir -Filter '*.tgz' -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($tgzCount -gt 0) { $needDepUpdate = $false }
} catch {
    $needDepUpdate = $true
}

if ($needDepUpdate) {
    Push-Location $chartDir
    try {
        & helm dependency update | Out-Null
    } finally {
        Pop-Location
    }
}

# Render fresh manifests into the fix folder to avoid any previously-modified/invalid YAML.
foreach ($env in @('dev', 'test', 'prod')) {
    $valuesFile = Join-Path $valuesDir ("{0}_values.yaml" -f $env)
    if (-not (Test-Path $valuesFile)) {
        throw "Values file missing: $valuesFile"
    }

    $renderPath = Join-Path $fixDir ("rendered-{0}.yaml" -f $env)
    $stderrPath = Join-Path $TestOutputDir ("polaris-fix.helm.{0}.stderr.log" -f $env)
    Remove-Item -Force $stderrPath -ErrorAction SilentlyContinue

    $helmArgs = @(
        'template',
        $AppName,
        $chartDir,
        '--values', $valuesFile,
        '--namespace', ("{0}-{1}" -f $LicencePlate, $env)
    )

    $proc = Start-Process -FilePath $helm.Source -ArgumentList $helmArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput $renderPath -RedirectStandardError $stderrPath
    if ($proc.ExitCode -ne 0) {
        $details = ''
        if (Test-Path $stderrPath) {
            $details = (Get-Content $stderrPath -Raw)
        }
        throw "helm template failed for env '$env' (ExitCode=$($proc.ExitCode)). $details"
    }
}

$logPath = Join-Path $TestOutputDir 'polaris-fix.log'
Remove-Item -Force $logPath -ErrorAction SilentlyContinue

Add-Content -Path $logPath -Value "RepoRoot: $RepoRoot"
Add-Content -Path $logPath -Value "TestOutputDir: $TestOutputDir"
Add-Content -Path $logPath -Value "GeneratedRepoDir: $generatedRepoDir"
Add-Content -Path $logPath -Value "ChartDir: $chartDir"
Add-Content -Path $logPath -Value "ValuesDir: $valuesDir"
Add-Content -Path $logPath -Value "FixDir: $fixDir"
Add-Content -Path $logPath -Value "Config: $configFullPath"
Add-Content -Path $logPath -Value ''

Add-Content -Path $logPath -Value 'Polaris version:'
& $polarisExe version 2>&1 | ForEach-Object { Add-Content -Path $logPath -Value $_ }
Add-Content -Path $logPath -Value ''

Add-Content -Path $logPath -Value 'Running: polaris fix'
 $stdoutPath = Join-Path $TestOutputDir 'polaris-fix.stdout.log'
 $stderrPath = Join-Path $TestOutputDir 'polaris-fix.stderr.log'
 Remove-Item -Force $stdoutPath, $stderrPath -ErrorAction SilentlyContinue

 $args = @(
     'fix',
     '--files-path', $fixDir,
     '--checks=all',
     '--config', $configFullPath
 )

 $proc = Start-Process -FilePath $polarisExe -ArgumentList $args -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
 $exitCode = $proc.ExitCode
 if (Test-Path $stdoutPath) {
     Get-Content $stdoutPath | ForEach-Object { Add-Content -Path $logPath -Value $_ }
 }
 if (Test-Path $stderrPath) {
     Get-Content $stderrPath | ForEach-Object { Add-Content -Path $logPath -Value $_ }
 }
Add-Content -Path $logPath -Value ''
Add-Content -Path $logPath -Value "ExitCode=$exitCode"

function Remove-PolarisProbeStub {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return
    }

    $lines = Get-Content -Path $Path
    if (-not $lines -or $lines.Count -eq 0) {
        return
    }

    $out = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $out.Add($line)

        if ($line -match '^(\s*)(livenessProbe|readinessProbe):\s*$') {
            # Polaris `fix` sometimes prepends an exec probe stub (with TODO + /tmp/healthy)
            # even when the manifest already has an httpGet probe, which creates duplicate keys.
            # If we detect that pattern, drop everything between the probe key and the httpGet:
            # leaving the original httpGet probe intact.
            $maxLookahead = 60
            $foundTmpHealthy = $false
            $httpGetIndex = -1

            for ($j = $i + 1; $j -lt $lines.Count -and $j -le ($i + $maxLookahead); $j++) {
                $peek = $lines[$j]
                if ($peek -match '/tmp/healthy') { $foundTmpHealthy = $true }
                if ($peek -match '^\s*httpGet:\s*$') { $httpGetIndex = $j; break }

                # If we hit the next probe or another top-level container key before httpGet,
                # stop looking; we don't want to remove legitimate exec probes.
                if ($peek -match '^\s*(livenessProbe|readinessProbe):\s*$') { break }
                if ($peek -match '^\s*(volumeMounts|resources|securityContext|ports|env):\s*$') { break }
            }

            if ($foundTmpHealthy -and $httpGetIndex -gt 0) {
                # Skip stub lines; next iteration should process httpGet
                $i = $httpGetIndex - 1
            }
        }
    }

    Set-Content -Path $Path -Value $out
}

Add-Content -Path $logPath -Value ''
Add-Content -Path $logPath -Value 'Post-processing: removing invalid probe stubs (if any)'
foreach ($env in @('dev', 'test', 'prod')) {
    $renderPath = Join-Path $fixDir ("rendered-{0}.yaml" -f $env)
    Remove-PolarisProbeStub -Path $renderPath
}

Write-Host "Wrote log: $logPath"
Write-Host "ExitCode: $exitCode"
exit $exitCode
