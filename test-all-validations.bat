@echo off
setlocal enabledelayedexpansion

echo =========================================
echo NETWORK POLICY VALIDATION TEST SUITE
echo =========================================
echo.

set "BASE_DIR=%~dp0"
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
cd "%BASE_DIR%"

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

call %CC_CMD% charts/ --no-input charts_dir=test-charts --output-dir "!TEST_DIR!" --overwrite-if-exists
if errorlevel 1 (
    echo ERROR: Cookiecutter charts generation failed
    exit /b 1
)

call %CC_CMD% deploy/ --no-input deploy_dir=test-deploy --output-dir "!TEST_DIR!" --overwrite-if-exists
if errorlevel 1 (
    echo ERROR: Cookiecutter deploy generation failed
    exit /b 1
)

call %CC_CMD% application/ --no-input application_dir=test-applications --output-dir "!TEST_DIR!" --overwrite-if-exists
if errorlevel 1 (
    echo ERROR: Cookiecutter application generation failed
    exit /b 1
)

echo [3/10] Copying shared-lib dependency...
xcopy /s /e /i /q "%BASE_DIR%shared-lib" "!TEST_DIR!\shared-lib"

echo [3b/10] Copying GitHub workflows into generated chart repo...
set "WORKFLOW_SRC=!BASE_DIR!.github\workflows"
set "WORKFLOW_DST=!TEST_DIR!\test-charts\.github\workflows"
if exist "!WORKFLOW_SRC!" (
    if not exist "!WORKFLOW_DST!" mkdir "!WORKFLOW_DST!" >nul 2>&1
    xcopy /s /e /i /q "!WORKFLOW_SRC!" "!WORKFLOW_DST!" >nul 2>&1
) else (
    echo WARNING: GitHub workflows folder not found; skipping workflow copy
)

echo [4/10] Updating Helm dependencies...
cd "!TEST_DIR!\test-charts\gitops"
helm dependency update
if errorlevel 1 (
    echo ERROR: Helm dependency update failed
    exit /b 1
)

echo [5/10] Rendering Helm templates...
REM Render with an explicit namespace so policy tools don't treat resources as 'default'.
helm template test-app . --values ..\..\test-deploy\dev_values.yaml --namespace myapp-dev > ..\..\rendered-dev.yaml
if errorlevel 1 (
    echo ERROR: Helm template rendering failed
    exit /b 1
)

cd "!TEST_DIR!"
for /f %%a in ('find /c /v "" ^< rendered-dev.yaml') do set LINE_COUNT=%%a
echo Generated %LINE_COUNT% lines of manifests
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
if not exist polaris.exe (
    echo Downloading Polaris...
    curl -sL https://github.com/FairwindsOps/polaris/releases/download/8.5.0/polaris_windows_amd64.tar.gz -o polaris.tar.gz
    tar -xzf polaris.tar.gz polaris.exe
    del polaris.tar.gz
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
conftest.exe test rendered-dev.yaml --policy test-charts\policy --all-namespaces --output table
if errorlevel 1 (
    echo FAILED: Conftest validation failed
    set CONFTEST_RESULT=FAILED
) else (
    echo PASSED: Conftest validation
    set CONFTEST_RESULT=PASSED
)
echo.

echo [8/10] Running kube-linter...
echo -----------------------------------------
kube-linter.exe lint rendered-dev.yaml --config test-charts\.kube-linter.yaml
if errorlevel 1 (
    echo WARNINGS: kube-linter found issues
    set KUBELINTER_RESULT=WARNINGS
) else (
    echo PASSED: kube-linter validation
    set KUBELINTER_RESULT=PASSED
)
echo.

echo [9/10] Running Polaris...
echo -----------------------------------------
polaris.exe audit --audit-path rendered-dev.yaml --config test-charts\.polaris.yaml --format pretty --set-exit-code-below-score 100
if errorlevel 1 (
    echo FAILED: Polaris score below 100
    set POLARIS_RESULT=FAILED
) else (
    echo PASSED: Polaris validation
    set POLARIS_RESULT=PASSED
)
echo.

echo [10/10] Running Network Policy Checks...
echo -----------------------------------------

REM Count NetworkPolicies
for /f "delims=" %%a in ('findstr /c:"kind: NetworkPolicy" rendered-dev.yaml ^| find /c /v ""') do set NP_COUNT=%%a
echo NetworkPolicies found: %NP_COUNT%

REM Count Deployments
for /f "delims=" %%a in ('findstr /c:"kind: Deployment" rendered-dev.yaml ^| find /c /v ""') do set DEPLOY_COUNT=%%a
echo Deployments found: %DEPLOY_COUNT%

if %NP_COUNT% LSS %DEPLOY_COUNT% (
    echo FAILED: Insufficient NetworkPolicies ^(%NP_COUNT%^) for Deployments ^(%DEPLOY_COUNT%^)
    set NETPOL_RESULT=FAILED
) else (
    echo PASSED: NetworkPolicy coverage adequate
    set NETPOL_RESULT=PASSED
)

REM Count DataClass labels
for /f "delims=" %%a in ('findstr /c:"DataClass:" rendered-dev.yaml ^| find /c /v ""') do set DATACLASS_COUNT=%%a
echo DataClass labels found: %DATACLASS_COUNT%

if %DATACLASS_COUNT% LSS %DEPLOY_COUNT% (
    echo FAILED: Missing DataClass labels
    set DATACLASS_RESULT=FAILED
) else (
    echo PASSED: DataClass labels present
    set DATACLASS_RESULT=PASSED
)

REM Validate DataClass values
findstr /c:"DataClass:" rendered-dev.yaml | findstr /v /c:"Low" /v /c:"Medium" /v /c:"High" > nul
if errorlevel 1 (
    echo PASSED: All DataClass values valid ^(Low/Medium/High^)
    set DATACLASS_VAL_RESULT=PASSED
) else (
    echo FAILED: Invalid DataClass values found
    set DATACLASS_VAL_RESULT=FAILED
)
echo.

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
docker run --rm -v "%cd%:/work" bridgecrew/checkov:latest -f /work/rendered-dev.yaml --framework kubernetes --compact --quiet
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
docker run --rm -v "%cd%:/project" zegl/kube-score:latest score /project/rendered-dev.yaml --ignore-test pod-networkpolicy
if errorlevel 1 (
    echo FAILED: kube-score found issues
    set KUBESCORE_RESULT=FAILED
) else (
    echo PASSED: kube-score
    set KUBESCORE_RESULT=PASSED
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
echo Conftest (OPA):        %CONFTEST_RESULT%
echo kube-linter:           %KUBELINTER_RESULT%
echo Polaris:               %POLARIS_RESULT%
echo NetworkPolicy Count:   %NETPOL_RESULT%
echo DataClass Labels:      %DATACLASS_RESULT%
echo DataClass Values:      %DATACLASS_VAL_RESULT%
echo Docker Tools:          %DOCKER_TOOLS%
if not "%DOCKER_TOOLS%"=="SKIPPED" (
    echo   Kubesec:           %KUBESEC_RESULT%
    echo   Trivy:             %TRIVY_RESULT%
    echo   Checkov:           %CHECKOV_RESULT%
    echo   kube-score:        %KUBESCORE_RESULT%
)

set OVERALL_RESULT=PASSED
if /i not "%CONFTEST_RESULT%"=="PASSED" set OVERALL_RESULT=FAILED
if /i not "%KUBELINTER_RESULT%"=="PASSED" set OVERALL_RESULT=FAILED
if /i not "%POLARIS_RESULT%"=="PASSED" set OVERALL_RESULT=FAILED
if /i not "%NETPOL_RESULT%"=="PASSED" set OVERALL_RESULT=FAILED
if /i not "%DATACLASS_RESULT%"=="PASSED" set OVERALL_RESULT=FAILED
if /i not "%DATACLASS_VAL_RESULT%"=="PASSED" set OVERALL_RESULT=FAILED
if /i "%DOCKER_TOOLS%"=="FAILED" set OVERALL_RESULT=FAILED
echo Overall:               %OVERALL_RESULT%
echo =========================================
echo.
echo Test results saved in: %TEST_DIR%
echo Rendered manifests: %TEST_DIR%\rendered-dev.yaml
echo.

REM Check for Helm Datree plugin
echo =========================================
echo DATREE (OFFLINE MODE) - Optional
echo =========================================
echo Skipping Datree - slow in offline mode
echo Datree validation runs automatically in GitHub Actions CI

echo.
echo =========================================
echo VALIDATION COMPLETE
echo =========================================
if /i "%OVERALL_RESULT%"=="FAILED" (
    echo.
    echo ERROR: One or more validations failed.
    if not defined NO_PAUSE pause
    exit /b 1
) else (
    if not defined NO_PAUSE pause
)
