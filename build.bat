@echo off
echo Building shirSEARCH...
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /target:winexe /optimize+ /platform:anycpu /out:shirSEARCH.exe shirSEARCH.cs
if %ERRORLEVEL% EQU 0 (
    echo [SUCCESS] shirSEARCH.exe compiled successfully!
) else (
    echo [ERROR] Compilation failed.
)
pause
