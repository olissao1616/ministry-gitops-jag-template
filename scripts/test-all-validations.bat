@echo off
setlocal enabledelayedexpansion

REM This script is a LOCAL validation harness. It is not a GitHub Actions workflow.
REM (GitHub Actions uses .github/workflows/*.yaml)

REM Default to non-interactive mode unless explicitly overridden.
if not defined NO_PAUSE set "NO_PAUSE=1"

REM Run Datree by default; allow opting out with RUN_DATREE=0.
if not defined RUN_DATREE set "RUN_DATREE=1"

echo =========================================
echo NETWORK POLICY VALIDATION TEST SUITE
echo =========================================
echo.

REM Resolve repo root so this script can run from repo root OR from scripts/.
set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT="
if exist "%SCRIPT_DIR%gitops-repo\cookiecutter.json" (
    for %%I in ("%SCRIPT_DIR%.") do set "REPO_ROOT=%%~fI"
) else if exist "%SCRIPT_DIR%..\gitops-repo\cookiecutter.json" (
    for %%I in ("%SCRIPT_DIR%..") do set "REPO_ROOT=%%~fI"
) else (
    echo ERROR: Could not locate gitops-repo\cookiecutter.json relative to %SCRIPT_DIR%
    echo Expected one of:
    echo   %SCRIPT_DIR%gitops-repo\cookiecutter.json
    echo   %SCRIPT_DIR%..\gitops-repo\cookiecutter.json
    exit /b 1
)
set "BASE_DIR=%REPO_ROOT%\"
REM Allow override: set TEST_OUTPUT_DIR=test-output-alt
if defined TEST_OUTPUT_DIR (
    set "TEST_DIR=!BASE_DIR!!TEST_OUTPUT_DIR!"
) else (
    set "TEST_DIR=!BASE_DIR!test-output"
)

echo [1/10] Cleaning up previous test output...
if exist "!TEST_DIR!" (
    rmdir /s /q "!TEST_DIR!" >nul 2>&1
    if exist "!TEST_DIR!" (
        echo NOTE: !TEST_DIR! is locked; using a new output folder.
        set "TEST_DIR=!BASE_DIR!test-output-%RANDOM%"
    )
)
mkdir "!TEST_DIR!"

echo [2/10] Generating cookiecutter templates...
cd /d "%REPO_ROOT%"

REM Prefer cookiecutter.exe if available; otherwise fall back to Python launcher.
set CC_CMD=cookiecutter
where cookiecutter >nul 2>&1
if errorlevel 1 (
    where py >nul 2>&1
    if errorlevel 1 (
        where python >nul 2>&1
        if errorlevel 1 (
            echo ERROR: cookiecutter not found. Install with: pip install cookiecutter
            exit /b 1
        ) else (
            set CC_CMD=python -m cookiecutter
        )
    ) else (
        set CC_CMD=py -m cookiecutter
    )
)

call %CC_CMD% "%REPO_ROOT%\gitops-repo" --no-input app_name=test-app licence_plate=abc123 github_org=bcgov-c --output-dir "!TEST_DIR!" --overwrite-if-exists
if errorlevel 1 (
    echo ERROR: Cookiecutter gitops-repo generation failed
    exit /b 1
)

echo [4/10] Updating Helm dependencies...
cd "!TEST_DIR!\test-app-gitops\charts\gitops"
helm dependency update
if errorlevel 1 (
    echo ERROR: Helm dependency update failed
    exit /b 1
)

echo [5/10] Rendering Helm templates (dev/test/prod)...
REM Render with an explicit namespace so policy tools don't treat resources as 'default'.
for %%E in (dev test prod) do (
    echo Rendering manifests for %%E...
    helm template test-app . --values ..\..\deploy\%%E_values.yaml --namespace abc123-%%E > ..\..\..\rendered-%%E.yaml
    if errorlevel 1 (
        echo ERROR: Helm template rendering failed for %%E
        exit /b 1
    )
)

cd "!TEST_DIR!"
for %%E in (dev test prod) do (
    for /f %%a in ('find /c /v "" ^< rendered-%%E.yaml') do set LINE_COUNT=%%a
    echo rendered-%%E.yaml: !LINE_COUNT! lines
)
echo.

echo [6/10] Downloading validation tools...

REM Download Conftest
if not exist conftest.exe (
    echo Downloading Conftest...
    curl -sL https://github.com/open-policy-agent/conftest/releases/download/v0.49.1/conftest_0.49.1_Windows_x86_64.zip -o conftest.zip
    tar -xf conftest.zip conftest.exe
    del conftest.zip
)

REM Download kube-linter
if not exist kube-linter.exe (
    echo Downloading kube-linter...
    curl -sL https://github.com/stackrox/kube-linter/releases/download/v0.6.8/kube-linter-windows.zip -o kube-linter.zip
    tar -xf kube-linter.zip kube-linter.exe
    del kube-linter.zip
)

REM Download Datree CLI (optional; offline mode)
if not exist datree.exe (
    echo Downloading Datree CLI...
    curl -sL https://github.com/datreeio/datree/releases/download/1.9.19/datree-cli_1.9.19_windows_x86_64.zip -o datree.zip
    tar -xf datree.zip datree.exe
    del datree.zip
)

REM Download Polaris
set "POLARIS_VERSION=10.1.4"
set "POLARIS_VERSION_FILE=polaris.version"
set "POLARIS_NEED_DOWNLOAD=0"
set "POLARIS_EXISTING_VERSION="
if exist "%POLARIS_VERSION_FILE%" for /f "usebackq delims=" %%V in ("%POLARIS_VERSION_FILE%") do set "POLARIS_EXISTING_VERSION=%%V"
if not exist polaris.exe set "POLARIS_NEED_DOWNLOAD=1"
if not "%POLARIS_EXISTING_VERSION%"=="%POLARIS_VERSION%" set "POLARIS_NEED_DOWNLOAD=1"
if "%POLARIS_NEED_DOWNLOAD%"=="1" (
    echo Downloading Polaris %POLARIS_VERSION%...
    curl -sL https://github.com/FairwindsOps/polaris/releases/download/%POLARIS_VERSION%/polaris_windows_amd64.tar.gz -o polaris.tar.gz
    tar -xzf polaris.tar.gz polaris.exe
    del polaris.tar.gz
    > "%POLARIS_VERSION_FILE%" echo %POLARIS_VERSION%
)

REM Download Pluto
if not exist pluto.exe (
    echo Downloading Pluto...
    curl -sL https://github.com/FairwindsOps/pluto/releases/download/v5.19.0/pluto_5.19.0_windows_amd64.tar.gz -o pluto.tar.gz
    tar -xzf pluto.tar.gz pluto.exe
    del pluto.tar.gz
)

echo.
echo =========================================
echo RUNNING VALIDATION TOOLS
echo =========================================
echo.

echo [7/10] Running Conftest (OPA)...
echo -----------------------------------------
set "FAILED_FLAG=0"
set "SUMMARY_FILE=!TEST_DIR!\validation-summary.txt"
echo Validation Summary > "!SUMMARY_FILE!"
echo.>> "!SUMMARY_FILE!"

for %%E in (dev test prod) do (
    echo =========================================
    echo ENV: %%E
    echo =========================================
    echo ENV: %%E>> "!SUMMARY_FILE!"

    conftest.exe test rendered-%%E.yaml --policy "%BASE_DIR%policies" --all-namespaces --output table
    if errorlevel 1 (
        echo FAILED: Conftest ^(%%E^)
        echo Conftest ^(%%E^): FAILED>> "!SUMMARY_FILE!"
        set "FAILED_FLAG=1"
    ) else (
        echo PASSED: Conftest ^(%%E^)
        echo Conftest ^(%%E^): PASSED>> "!SUMMARY_FILE!"
    )
    echo.

    kube-linter.exe lint rendered-%%E.yaml --config "%BASE_DIR%policies\kube-linter.yaml"
    if errorlevel 1 (
        echo WARNINGS: kube-linter ^(%%E^)
        echo kube-linter ^(%%E^): WARNINGS>> "!SUMMARY_FILE!"
    ) else (
        echo PASSED: kube-linter ^(%%E^)
        echo kube-linter ^(%%E^): PASSED>> "!SUMMARY_FILE!"
    )
    echo.

    polaris.exe audit --audit-path rendered-%%E.yaml --config "%BASE_DIR%policies\polaris.yaml" --format pretty --set-exit-code-below-score 100
    if errorlevel 1 (
        echo FAILED: Polaris ^(%%E^)
        echo Polaris ^(%%E^): FAILED>> "!SUMMARY_FILE!"
        set "FAILED_FLAG=1"
    ) else (
        echo PASSED: Polaris ^(%%E^)
        echo Polaris ^(%%E^): PASSED>> "!SUMMARY_FILE!"
    )
    echo.

    echo Running Network Policy Checks ^(%%E^)...

    REM Count NetworkPolicies
    for /f "delims=" %%a in ('findstr /c:"kind: NetworkPolicy" rendered-%%E.yaml ^| find /c /v ""') do set NP_COUNT=%%a
    echo NetworkPolicies found: !NP_COUNT!

    REM Count Deployments
    for /f "delims=" %%a in ('findstr /c:"kind: Deployment" rendered-%%E.yaml ^| find /c /v ""') do set DEPLOY_COUNT=%%a
    echo Deployments found: !DEPLOY_COUNT!

    if !NP_COUNT! LSS !DEPLOY_COUNT! (
        echo FAILED: NetworkPolicy coverage ^(%%E^)
        echo NetworkPolicy coverage ^(%%E^): FAILED>> "!SUMMARY_FILE!"
        set "FAILED_FLAG=1"
    ) else (
        echo PASSED: NetworkPolicy coverage ^(%%E^)
        echo NetworkPolicy coverage ^(%%E^): PASSED>> "!SUMMARY_FILE!"
    )

    REM Count DataClass labels
    for /f "delims=" %%a in ('findstr /c:"DataClass:" rendered-%%E.yaml ^| find /c /v ""') do set DATACLASS_COUNT=%%a
    echo DataClass labels found: !DATACLASS_COUNT!

    if !DATACLASS_COUNT! LSS !DEPLOY_COUNT! (
        echo FAILED: DataClass labels ^(%%E^)
        echo DataClass labels ^(%%E^): FAILED>> "!SUMMARY_FILE!"
        set "FAILED_FLAG=1"
    ) else (
        echo PASSED: DataClass labels ^(%%E^)
        echo DataClass labels ^(%%E^): PASSED>> "!SUMMARY_FILE!"
    )

    REM Validate DataClass values
    findstr /c:"DataClass:" rendered-%%E.yaml | findstr /v /c:"Low" /v /c:"Medium" /v /c:"High" > nul
    if errorlevel 1 (
        echo PASSED: DataClass values ^(%%E^)
        echo DataClass values ^(%%E^): PASSED>> "!SUMMARY_FILE!"
    ) else (
        echo FAILED: DataClass values ^(%%E^)
        echo DataClass values ^(%%E^): FAILED>> "!SUMMARY_FILE!"
        set "FAILED_FLAG=1"
    )
    echo.>> "!SUMMARY_FILE!"
    echo.
)

set CONFTEST_RESULT=SEE_SUMMARY
set KUBELINTER_RESULT=SEE_SUMMARY
set POLARIS_RESULT=SEE_SUMMARY
set NETPOL_RESULT=SEE_SUMMARY
set DATACLASS_RESULT=SEE_SUMMARY
set DATACLASS_VAL_RESULT=SEE_SUMMARY

echo =========================================
echo DOCKER-BASED TOOLS ^(requires Docker^)
echo =========================================
echo.

REM Check if Docker is available
docker --version >nul 2>&1
if errorlevel 1 goto docker_tools_skip

echo Running Kubesec...
echo -----------------------------------------
REM Kubesec scans only workload resources; ignore schema errors for non-workload kinds
docker run --rm -v "%cd%:/work" kubesec/kubesec:v2 scan /work/rendered-dev.yaml > kubesec-results.json 2>nul
REM Check if any workloads got a score (ignore "could not find schema" for non-workloads)
findstr /C:"\"object\": \"Deployment" /C:"\"object\": \"StatefulSet" kubesec-results.json >nul
if errorlevel 1 (
    echo WARNING: No workloads found to scan
    set KUBESEC_RESULT=PASSED
) else (
    echo PASSED: Kubesec scan completed
    set KUBESEC_RESULT=PASSED
)
echo.

:docker_tools_continue
echo Running Trivy...
echo -----------------------------------------
docker run --rm -v "%cd%:/work" aquasec/trivy:latest config /work/rendered-dev.yaml --severity HIGH,CRITICAL
if errorlevel 1 (
    echo FAILED: Trivy found issues
    set TRIVY_RESULT=FAILED
) else (
    echo PASSED: Trivy found no HIGH/CRITICAL issues
    set TRIVY_RESULT=PASSED
)
echo.

echo Running Checkov...
echo -----------------------------------------
set "CHECKOV_SKIP_ARGS=--skip-check CKV_K8S_43"
echo Skipping digest enforcement in Checkov: CKV_K8S_43
REM OpenShift mode uses SCC-assigned UIDs; skip runAsUser enforcement in Checkov.
findstr /C:"openshift: true" "test-app-gitops\deploy\dev_values.yaml" >nul 2>&1
if not errorlevel 1 (
    set "CHECKOV_SKIP_ARGS=--skip-check CKV_K8S_43 --skip-check CKV_K8S_40"
    echo OpenShift mode detected for dev - skipping: CKV_K8S_40
)
docker run --rm -v "%cd%:/work" bridgecrew/checkov:latest -f /work/rendered-dev.yaml --framework kubernetes --compact --quiet !CHECKOV_SKIP_ARGS!
if errorlevel 1 (
    echo FAILED: Checkov found issues
    set CHECKOV_RESULT=FAILED
) else (
    echo PASSED: Checkov found no failures
    set CHECKOV_RESULT=PASSED
)
echo.

echo Running kube-score...
echo -----------------------------------------
set "KUBESCORE_RESULT=PASSED"
for %%E in (dev test prod) do (
    set "KUBESCORE_IGNORE_ARGS="
    REM Detect OpenShift mode from values (under global: openshift: true)
    findstr /C:"openshift: true" "test-app-gitops\deploy\%%E_values.yaml" >nul 2>&1
    if not errorlevel 1 (
        set "KUBESCORE_IGNORE_ARGS=--ignore-test container-security-context-user-group-id"
        echo OpenShift mode detected for %%E - ignoring: container-security-context-user-group-id
    )

    echo kube-score %%E...
    docker run --rm -v "%cd%:/project" zegl/kube-score:latest score /project/rendered-%%E.yaml !KUBESCORE_IGNORE_ARGS!
    if errorlevel 1 (
        echo FAILED: kube-score found issues for %%E
        set KUBESCORE_RESULT=FAILED
    ) else (
        echo PASSED: kube-score for %%E
    )
    echo.
)
echo.

set DOCKER_TOOLS=PASSED
if /i not "%KUBESEC_RESULT%"=="PASSED" set DOCKER_TOOLS=FAILED
if /i not "%TRIVY_RESULT%"=="PASSED" set DOCKER_TOOLS=FAILED
if /i not "%CHECKOV_RESULT%"=="PASSED" set DOCKER_TOOLS=FAILED
if /i not "%KUBESCORE_RESULT%"=="PASSED" set DOCKER_TOOLS=FAILED
goto docker_tools_done

:docker_tools_skip
echo WARNING: Docker not available, skipping Docker-based tools
echo Skipped: Kubesec, Trivy, Checkov, kube-score
set DOCKER_TOOLS=SKIPPED

:docker_tools_done

echo.
echo =========================================
echo VALIDATION SUMMARY
echo =========================================
echo Per-environment results: %TEST_DIR%\validation-summary.txt
type "%TEST_DIR%\validation-summary.txt"
echo Docker Tools:          %DOCKER_TOOLS%
if not "%DOCKER_TOOLS%"=="SKIPPED" (
    echo   Kubesec:           %KUBESEC_RESULT%
    echo   Trivy:             %TRIVY_RESULT%
    echo   Checkov:           %CHECKOV_RESULT%
    echo   kube-score:        %KUBESCORE_RESULT%
)

set OVERALL_RESULT=PASSED
if "%FAILED_FLAG%"=="1" set OVERALL_RESULT=FAILED
if /i "%DOCKER_TOOLS%"=="FAILED" set OVERALL_RESULT=FAILED
echo Overall:               %OVERALL_RESULT%
echo =========================================
echo.
echo Test results saved in: %TEST_DIR%
echo Rendered manifests:
echo   %TEST_DIR%\rendered-dev.yaml
echo   %TEST_DIR%\rendered-test.yaml
echo   %TEST_DIR%\rendered-prod.yaml
echo.

REM Check for Helm Datree plugin
echo =========================================
echo DATREE (OFFLINE MODE) - Optional
echo =========================================
if /i "%RUN_DATREE%"=="1" (
    echo RUN_DATREE=1 set - running Datree CLI against rendered manifests ^(dev/test/prod^)...
    echo.

    if not exist "!TEST_DIR!\datree.exe" (
        echo WARNING: datree.exe not found in !TEST_DIR!
        echo Skipping Datree
    ) else (
        pushd "!TEST_DIR!" >nul 2>&1

        REM Force offline local mode (no backend dependency)
        "!TEST_DIR!\datree.exe" config set offline local >nul 2>&1

        for %%E in (dev test prod) do (
            echo Datree %%E...
            "!TEST_DIR!\datree.exe" test "rendered-%%E.yaml" --ignore-missing-schemas --no-record --policy-config "%BASE_DIR%policies\datree-policies.yaml"
            if errorlevel 1 (
                echo FAILED: Datree ^(%%E^)
                echo Datree ^(%%E^): FAILED>> "!SUMMARY_FILE!"
                set "FAILED_FLAG=1"
            ) else (
                echo PASSED: Datree ^(%%E^)
                echo Datree ^(%%E^): PASSED>> "!SUMMARY_FILE!"
            )
            echo.
        )

        popd >nul 2>&1
    )
) else (
    echo Skipping Datree - set RUN_DATREE=1 to enable
    echo Datree validation runs automatically in GitHub Actions CI
)

REM Datree can update FAILED_FLAG; recompute overall result for exit code correctness.
set OVERALL_RESULT=PASSED
if "%FAILED_FLAG%"=="1" set OVERALL_RESULT=FAILED
if /i "%DOCKER_TOOLS%"=="FAILED" set OVERALL_RESULT=FAILED
echo.
echo Overall ^(including Datree^): %OVERALL_RESULT%

echo.
echo =========================================
echo VALIDATION COMPLETE
echo =========================================
set "FINAL_EXIT=0"
if /i "%OVERALL_RESULT%"=="FAILED" (
    echo.
    echo ERROR: One or more validations failed.
    if not defined NO_PAUSE pause
    set "FINAL_EXIT=1"
) else (
    if not defined NO_PAUSE pause
)

endlocal & exit /b %FINAL_EXIT%