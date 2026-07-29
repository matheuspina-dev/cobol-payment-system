@echo off
cobc -x src\PAYMENTPROC.cob -o PAYMENTPROC.exe
if errorlevel 1 exit /b 1
PAYMENTPROC.exe
