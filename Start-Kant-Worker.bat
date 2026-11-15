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

:: Așteptăm 3 secunde ca serverul să se încarce
timeout /t 3 /nobreak > nul

echo  Deschidem interfata in browser...
start http://localhost:8080/ui

echo.
echo  ✅ Gata! Serverul ruleaza in fundal.
echo  Poti inchide aceasta fereastra.
echo.
timeout /t 5
