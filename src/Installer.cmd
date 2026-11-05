@echo off
setlocal
set "JOURNAUX=%LOCALAPPDATA%\InstallationGitHubJJ\journaux"
set "MARQUE=%LOCALAPPDATA%\InstallationGitHubJJ\fin-du-script.txt"

if not exist "%~dp0setup-github-jj.ps1" (
    echo Le fichier setup-github-jj.ps1 est introuvable a cote de Installer.cmd.
    echo Si le dossier est dans un ZIP, extrais-le d'abord, puis relance.
    echo Code de l'erreur : E-FICHIER-ABSENT
    pause
    exit /b 2
)

if exist "%MARQUE%" del "%MARQUE%"

rem Chemin complet : un faux powershell.exe pose dans ce dossier ne peut pas etre lance.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-github-jj.ps1" %*
set "CODE=%ERRORLEVEL%"

rem Ctrl+C rend le code 0xC000013A, ou parfois 0 : sans le fichier de fin, le script n'est pas alle au bout.
if "%CODE%"=="-1073741510" goto interrompu
if "%CODE%"=="0" if not exist "%MARQUE%" goto interrompu

rem Le script utilise 0, 10, 20 et 30. Un autre code veut dire qu'il n'a pas pu demarrer ou s'est arrete net.
if "%CODE%"=="0" goto fin
if "%CODE%"=="10" goto fin
if "%CODE%"=="20" goto fin
if "%CODE%"=="30" goto fin

rem Pas de bloc entre parentheses ici : un ) dans le nom du compte Windows le fermerait.
echo.
echo Le script n'a pas pu demarrer, ou il s'est arrete net, code %CODE%.
echo Sur un PC d'entreprise, une regle de securite peut bloquer les scripts :
echo montre ce message a ton service informatique.
echo Code de l'erreur : E-LANCEMENT
echo Journaux : "%JOURNAUX%"
goto fin

:interrompu
echo.
echo Installation interrompue. Relance Installer.cmd quand tu veux, le script reprendra.
echo Journaux : "%JOURNAUX%"
set "CODE=30"

:fin
echo.
pause
exit /b %CODE%
