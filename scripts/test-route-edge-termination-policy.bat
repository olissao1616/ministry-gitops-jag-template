@echo off
setlocal

REM Tests the Conftest policy that blocks unapproved edge-terminated OpenShift Routes.
REM Expected behavior:
REM 1) Unapproved edge-terminated Route => conftest FAIL
REM 2) Approved edge-terminated Route   => conftest PASS

set "ROOT=%~dp0.."
set "POLICY_DIR=%ROOT%\charts\{{cookiecutter.charts_dir}}\policy"
set "CONFTEST=%ROOT%\conftest.exe"
if not exist "%CONFTEST%" set "CONFTEST=%ROOT%\test-output\conftest.exe"

if not exist "%CONFTEST%" goto :no_conftest

:continue

set "TMP_DIR=%ROOT%\test-output\route-policy-test"
if not exist "%TMP_DIR%" mkdir "%TMP_DIR%" >nul 2>&1

set "BAD=%TMP_DIR%\bad-edge-route.yaml"
set "GOOD=%TMP_DIR%\good-edge-route.yaml"

REM Bad: edge termination, not frontend, no approval annotation
> "%BAD%" echo apiVersion: route.openshift.io/v1
>> "%BAD%" echo kind: Route
>> "%BAD%" echo metadata:
>> "%BAD%" echo   name: internal-api
>> "%BAD%" echo   namespace: unit-test
>> "%BAD%" echo   labels:
>> "%BAD%" echo     app.kubernetes.io/component: backend
>> "%BAD%" echo spec:
>> "%BAD%" echo   host: internal-api.example.invalid
>> "%BAD%" echo   to:
>> "%BAD%" echo     kind: Service
>> "%BAD%" echo     name: internal-api
>> "%BAD%" echo   port:
>> "%BAD%" echo     targetPort: http
>> "%BAD%" echo   tls:
>> "%BAD%" echo     termination: edge
>> "%BAD%" echo     insecureEdgeTerminationPolicy: Redirect

REM Good: same, but explicitly approved
> "%GOOD%" echo apiVersion: route.openshift.io/v1
>> "%GOOD%" echo kind: Route
>> "%GOOD%" echo metadata:
>> "%GOOD%" echo   name: public-entry
>> "%GOOD%" echo   namespace: unit-test
>> "%GOOD%" echo   labels:
>> "%GOOD%" echo     app.kubernetes.io/component: backend
>> "%GOOD%" echo   annotations:
>> "%GOOD%" echo     isb.gov.bc.ca/edge-termination-approval: "ISB-UNIT-TEST"
>> "%GOOD%" echo spec:
>> "%GOOD%" echo   host: public-entry.example.invalid
>> "%GOOD%" echo   to:
>> "%GOOD%" echo     kind: Service
>> "%GOOD%" echo     name: public-entry
>> "%GOOD%" echo   port:
>> "%GOOD%" echo     targetPort: http
>> "%GOOD%" echo   tls:
>> "%GOOD%" echo     termination: edge
>> "%GOOD%" echo     insecureEdgeTerminationPolicy: Redirect

echo === [1/2] Expect FAIL: unapproved edge-terminated Route ===
"%CONFTEST%" test "%BAD%" --policy "%POLICY_DIR%" --output table
if "%ERRORLEVEL%"=="0" goto :unexpected_pass
echo OK: conftest failed as expected.

echo.
echo === [2/2] Expect PASS: approved edge-terminated Route ===
"%CONFTEST%" test "%GOOD%" --policy "%POLICY_DIR%" --output table
if not "%ERRORLEVEL%"=="0" goto :unexpected_fail
echo OK: conftest passed as expected.

echo.
echo SUCCESS: Edge-termination Route policy behaves correctly.
exit /b 0

:no_conftest
echo conftest.exe not found.
echo Expected at either:
echo   - "%ROOT%\conftest.exe"
echo   - "%ROOT%\test-output\conftest.exe"
echo Run test-all-validations.bat/.sh to populate test-output with tools.
exit /b 2

:unexpected_pass
echo ERROR: Expected conftest to FAIL, but it PASSED.
exit /b 1

:unexpected_fail
echo ERROR: Expected conftest to PASS, but it FAILED.
exit /b 1
