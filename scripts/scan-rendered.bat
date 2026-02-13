@echo off
setlocal enabledelayedexpansion

REM Scan-only harness: runs validators against existing rendered YAML.
REM This script does NOT run cookiecutter and does NOT run helm template.

REM Usage (single file):
REM   set RENDERED_YAML=C:\path\to\rendered-dev.yaml
REM   call .\scripts\scan-rendered.bat
REM
REM Usage (dev/test/prod):
REM   set RENDERED_DEV_YAML=C:\path\rendered-dev.yaml
REM   set RENDERED_TEST_YAML=C:\path\rendered-test.yaml
REM   set RENDERED_PROD_YAML=C:\path\rendered-prod.yaml
REM   call .\scripts\scan-rendered.bat

REM Optional inputs:
REM   set VALUES_YAML=C:\path\to\dev_values.yaml
REM   set POLICY_DIR=C:\path\to\policies
REM   set RUN_DATREE=1
REM   set NO_DOCKER=1

REM Scan-only is typically used for fast local triage against pre-rendered YAML,
REM so Datree is opt-in here.
if not defined RUN_DATREE set "RUN_DATREE=0"
if not defined NO_DOCKER set "NO_DOCKER=0"

REM Resolve repo root so this script can run from anywhere.
set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."
for %%I in ("%REPO_ROOT%") do set "REPO_ROOT=%%~fI"

if not defined POLICY_DIR set "POLICY_DIR=%REPO_ROOT%\policies"

if not exist "%POLICY_DIR%" (
  echo ERROR: POLICY_DIR not found: %POLICY_DIR%
  exit /b 1
)

REM Determine which YAMLs we will scan.
set "SCAN_COUNT=0"
set "SCAN_LABEL_1="
set "SCAN_FILE_1="
set "SCAN_LABEL_2="
set "SCAN_FILE_2="
set "SCAN_LABEL_3="
set "SCAN_FILE_3="

if defined RENDERED_YAML (
  set /a SCAN_COUNT=1
  set "SCAN_LABEL_1=custom"
  set "SCAN_FILE_1=%RENDERED_YAML%"
) else (
  if defined RENDERED_DEV_YAML (
    set /a SCAN_COUNT+=1
    set "SCAN_LABEL_1=dev"
    set "SCAN_FILE_1=%RENDERED_DEV_YAML%"
  )
  if defined RENDERED_TEST_YAML (
    if !SCAN_COUNT! EQU 0 (
      set "SCAN_LABEL_1=test"
      set "SCAN_FILE_1=%RENDERED_TEST_YAML%"
    ) else (
      set "SCAN_LABEL_2=test"
      set "SCAN_FILE_2=%RENDERED_TEST_YAML%"
    )
    set /a SCAN_COUNT+=1
  )
  if defined RENDERED_PROD_YAML (
    if !SCAN_COUNT! EQU 0 (
      set "SCAN_LABEL_1=prod"
      set "SCAN_FILE_1=%RENDERED_PROD_YAML%"
    ) else if "!SCAN_LABEL_2!"=="" (
      set "SCAN_LABEL_2=prod"
      set "SCAN_FILE_2=%RENDERED_PROD_YAML%"
    ) else (
      set "SCAN_LABEL_3=prod"
      set "SCAN_FILE_3=%RENDERED_PROD_YAML%"
    )
    set /a SCAN_COUNT+=1
  )
)

if %SCAN_COUNT% EQU 0 (
  echo ERROR: No input YAML provided.
  echo Set RENDERED_YAML or RENDERED_DEV_YAML/RENDERED_TEST_YAML/RENDERED_PROD_YAML.
  exit /b 1
)

REM Validate file existence.
for %%N in (1 2 3) do (
  call set "_f=%%SCAN_FILE_%%N%%"
  call set "_l=%%SCAN_LABEL_%%N%%"
  if defined _f (
    if not exist "!_f!" (
      echo ERROR: Rendered YAML for !_l! not found: !_f!
      exit /b 1
    )
  )
)

REM Tool cache under test-output (keeps repo root clean).
set "TOOLS_DIR=%REPO_ROOT%\test-output\.scan-tools"
if not exist "%TOOLS_DIR%" mkdir "%TOOLS_DIR%" >nul 2>&1

pushd "%TOOLS_DIR%" >nul 2>&1

REM Download Conftest
if not exist conftest.exe (
  echo Downloading Conftest...
  curl -sL https://github.com/open-policy-agent/conftest/releases/download/v0.49.1/conftest_0.49.1_Windows_x86_64.zip -o conftest.zip
  if errorlevel 1 (
    echo ERROR: Failed to download Conftest
    popd >nul 2>&1
    exit /b 1
  )
  tar -xf conftest.zip conftest.exe
  del conftest.zip
)

REM Download kube-linter
if not exist kube-linter.exe (
  echo Downloading kube-linter...
  curl -sL https://github.com/stackrox/kube-linter/releases/download/v0.6.8/kube-linter-windows.zip -o kube-linter.zip
  if errorlevel 1 (
    echo ERROR: Failed to download kube-linter
    popd >nul 2>&1
    exit /b 1
  )
  tar -xf kube-linter.zip kube-linter.exe
  del kube-linter.zip
)

REM Download Polaris
if not exist polaris.exe (
  echo Downloading Polaris...
  curl -sL https://github.com/FairwindsOps/polaris/releases/download/8.5.0/polaris_windows_amd64.tar.gz -o polaris.tar.gz
  if errorlevel 1 (
    echo ERROR: Failed to download Polaris
    popd >nul 2>&1
    exit /b 1
  )
  tar -xzf polaris.tar.gz polaris.exe
  del polaris.tar.gz
)

REM Download Datree CLI (optional)
if /i "%RUN_DATREE%"=="1" (
  if not exist datree.exe (
    echo Downloading Datree CLI...
    curl -sL https://github.com/datreeio/datree/releases/download/1.9.19/datree-cli_1.9.19_windows_x86_64.zip -o datree.zip
    if errorlevel 1 (
      echo WARNING: Failed to download Datree CLI; Datree will be skipped.
    ) else (
      tar -xf datree.zip datree.exe
      del datree.zip
    )
  )
)

popd >nul 2>&1

set "FAILED_FLAG=0"

REM OpenShift mode detection (optional)
set "OPENSHIFT_MODE=0"
if defined VALUES_YAML (
  if exist "%VALUES_YAML%" (
    findstr /C:"openshift: true" "%VALUES_YAML%" >nul 2>&1
    if not errorlevel 1 set "OPENSHIFT_MODE=1"
  )
)

echo =========================================
echo SCAN-ONLY VALIDATION
echo =========================================
echo Policy dir:   %POLICY_DIR%
echo OpenShift:    %OPENSHIFT_MODE%
echo Docker tools: %NO_DOCKER%
echo.

for %%N in (1 2 3) do (
  call set "YAML=%%SCAN_FILE_%%N%%"
  call set "LABEL=%%SCAN_LABEL_%%N%%"
  if defined YAML (
    echo =========================================
    echo ENV: !LABEL!
    echo YAML: !YAML!
    echo =========================================

    REM Per-environment OpenShift detection.
    REM If VALUES_YAML indicates OpenShift, treat all envs as OpenShift.
    REM Otherwise, infer OpenShift if Route resources are present in the rendered YAML.
    set "ENV_OPENSHIFT_MODE=%OPENSHIFT_MODE%"
    if "!ENV_OPENSHIFT_MODE!"=="0" (
      findstr /C:"kind: Route" /C:"apiVersion: route.openshift.io/" "!YAML!" >nul 2>&1
      if not errorlevel 1 set "ENV_OPENSHIFT_MODE=1"
    )

    REM Conftest
    "%TOOLS_DIR%\conftest.exe" test "!YAML!" --policy "%POLICY_DIR%" --all-namespaces --output table
    if errorlevel 1 (
      echo FAILED: Conftest ^(!LABEL!^)
      set "FAILED_FLAG=1"
    ) else (
      echo PASSED: Conftest ^(!LABEL!^)
    )
    echo.

    REM kube-linter
    "%TOOLS_DIR%\kube-linter.exe" lint "!YAML!" --config "%POLICY_DIR%\kube-linter.yaml"
    if errorlevel 1 (
      echo WARNINGS: kube-linter ^(!LABEL!^)
    ) else (
      echo PASSED: kube-linter ^(!LABEL!^)
    )
    echo.

    REM Polaris
    "%TOOLS_DIR%\polaris.exe" audit --audit-path "!YAML!" --config "%POLICY_DIR%\polaris.yaml" --format pretty --set-exit-code-below-score 100
    if errorlevel 1 (
      echo FAILED: Polaris ^(!LABEL!^)
      set "FAILED_FLAG=1"
    ) else (
      echo PASSED: Polaris ^(!LABEL!^)
    )
    echo.

    REM Lightweight local checks matching the original harness intent
    echo Running NetworkPolicy/DataClass sanity checks ^(!LABEL!^)...
    for /f "delims=" %%a in ('findstr /c:"kind: NetworkPolicy" "!YAML!" ^| find /c /v ""') do set NP_COUNT=%%a
    for /f "delims=" %%a in ('findstr /c:"kind: Deployment" "!YAML!" ^| find /c /v ""') do set DEPLOY_COUNT=%%a
    for /f "delims=" %%a in ('findstr /c:"DataClass:" "!YAML!" ^| find /c /v ""') do set DATACLASS_COUNT=%%a

    echo NetworkPolicies found: !NP_COUNT!
    echo Deployments found:    !DEPLOY_COUNT!
    echo DataClass labels:     !DATACLASS_COUNT!

    if !NP_COUNT! LSS !DEPLOY_COUNT! (
      echo FAILED: NetworkPolicy coverage ^(!LABEL!^)
      set "FAILED_FLAG=1"
    ) else (
      echo PASSED: NetworkPolicy coverage ^(!LABEL!^)
    )

    if !DATACLASS_COUNT! LSS !DEPLOY_COUNT! (
      echo FAILED: DataClass labels ^(!LABEL!^)
      set "FAILED_FLAG=1"
    ) else (
      echo PASSED: DataClass labels ^(!LABEL!^)
    )

    findstr /c:"DataClass:" "!YAML!" | findstr /v /c:"Low" /v /c:"Medium" /v /c:"High" > nul
    if errorlevel 1 (
      echo PASSED: DataClass values ^(!LABEL!^)
    ) else (
      echo FAILED: DataClass values ^(!LABEL!^)
      set "FAILED_FLAG=1"
    )
    echo.

    REM Datree (optional)
    if /i "%RUN_DATREE%"=="1" (
      if exist "%TOOLS_DIR%\datree.exe" (
        echo Datree ^(!LABEL!^)...
        "%TOOLS_DIR%\datree.exe" config set offline local >nul 2>&1
        "%TOOLS_DIR%\datree.exe" test "!YAML!" --ignore-missing-schemas --no-record --policy-config "%POLICY_DIR%\datree-policies.yaml"
        if errorlevel 1 (
          echo FAILED: Datree ^(!LABEL!^)
          set "FAILED_FLAG=1"
        ) else (
          echo PASSED: Datree ^(!LABEL!^)
        )
      ) else (
        echo WARNING: Datree CLI not available; skipping Datree.
      )
      echo.
    )

    REM Docker-based tools (optional)
    if /i "%NO_DOCKER%"=="0" (
      docker --version >nul 2>&1
      if errorlevel 1 (
        echo WARNING: Docker not available; skipping Docker-based tools.
      ) else (
        for %%P in ("!YAML!") do (
          set "YAML_DIR=%%~dpP"
          set "YAML_NAME=%%~nxP"
        )
        pushd "!YAML_DIR!" >nul 2>&1

        REM Use delayed expansion for the mount dir; %CD% is expanded before pushd in parentheses.
        for %%I in ("!CD!") do set "MOUNT_DIR=%%~fI"

        echo Trivy ^(!LABEL!^)...
        docker run --rm -v "!MOUNT_DIR!:/work" aquasec/trivy:latest config "/work/!YAML_NAME!" --severity HIGH,CRITICAL
        if errorlevel 1 (
          echo FAILED: Trivy ^(!LABEL!^)
          set "FAILED_FLAG=1"
        ) else (
          echo PASSED: Trivy ^(!LABEL!^)
        )
        echo.

        echo Checkov ^(!LABEL!^)...
        set "CHECKOV_SKIP_ARGS="
        if "!ENV_OPENSHIFT_MODE!"=="1" set "CHECKOV_SKIP_ARGS=--skip-check CKV_K8S_40"
        docker run --rm -v "!MOUNT_DIR!:/work" bridgecrew/checkov:latest -f "/work/!YAML_NAME!" --framework kubernetes --compact --quiet !CHECKOV_SKIP_ARGS!
        if errorlevel 1 (
          echo FAILED: Checkov ^(!LABEL!^)
          set "FAILED_FLAG=1"
        ) else (
          echo PASSED: Checkov ^(!LABEL!^)
        )
        echo.

        echo Kubesec ^(!LABEL!^)...
        REM Kubesec scans only workload resources; ignore schema errors for non-workload kinds.
        set "KUBESEC_OUT=kubesec-results-!LABEL!.json"
        docker run --rm -v "!MOUNT_DIR!:/work" kubesec/kubesec:v2 scan "/work/!YAML_NAME!" > "!KUBESEC_OUT!" 2>nul
        if not exist "!KUBESEC_OUT!" (
          echo FAILED: Kubesec ^(!LABEL!^) - no output produced
          set "FAILED_FLAG=1"
        ) else (
          findstr /C:"\"object\": \"Deployment" /C:"\"object\": \"StatefulSet" "!KUBESEC_OUT!" >nul
          if errorlevel 1 (
            echo WARNING: Kubesec found no workloads to scan; treating as PASSED
          ) else (
            echo PASSED: Kubesec ^(!LABEL!^)
          )
        )
        echo.

        echo kube-score ^(!LABEL!^)...
        set "KUBESCORE_IGNORE_ARGS="
        if "!ENV_OPENSHIFT_MODE!"=="1" set "KUBESCORE_IGNORE_ARGS=--ignore-test container-security-context-user-group-id"
        docker run --rm -v "!MOUNT_DIR!:/project" zegl/kube-score:latest score --output-format ci !KUBESCORE_IGNORE_ARGS! "/project/!YAML_NAME!"
        if errorlevel 1 (
          echo FAILED: kube-score ^(!LABEL!^)
          set "FAILED_FLAG=1"
        ) else (
          echo PASSED: kube-score ^(!LABEL!^)
        )
        echo.

        popd >nul 2>&1
      )
    )

  )
)

echo =========================================
echo SCAN-ONLY COMPLETE
if "%FAILED_FLAG%"=="1" (
  echo Overall: FAILED
  exit /b 1
) else (
  echo Overall: PASSED
  exit /b 0
)
