@echo off
title Kant Lean Worker
color 0A

echo.
echo  =======================================================
echo    KANT LEAN WORKER - Pornire Nod Matematic
echo  =======================================================
echo.
echo  Se porneste serverul in fundal... (te rog asteapta)
echo.

:: Pornim serviciul in WSL
wsl bash -c "systemctl --user start kant-lean-worker.service 2>/dev/null || ~/.local/bin/kant-lean-worker start 2>/dev/null || (cd ~/ZOS_INT02_LAB.6hY9Ggte/lean-worker && nohup lake exe lean-worker > /tmp/lean-worker.log 2>&1 &)"

:: Așteptăm 3 secunde
timeout /t 3 /nobreak > nul

:: Luăm IP-ul WSL-ului automat
for /f "tokens=1" %%i in ('wsl hostname -I') do set WSL_IP=%%i

echo  Serverul ruleaza la: http://%WSL_IP%:8080
echo  Se deschide browserul...
start http://%WSL_IP%:8080/ui

echo.
echo  ✅ Gata! Poti inchide aceasta fereastra.
echo.
timeout /t 5
