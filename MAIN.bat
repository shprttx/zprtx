@echo off
set "LOCAL_VERSION=17.06.26"

:: Проверка прав администратора
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Requesting administrator rights...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

title ZPRTX

setlocal EnableDelayedExpansion

::
for /F %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"
set "p=!ESC![38;2;0;242;255m"   :: COLOR_MAIN (Неоновый)
set "d=!ESC![38;2;112;0;255m"   :: COLOR_SECONDARY (фиолетовый)
set "w=!ESC![38;2;255;255;255m" :: TEXT_COLOR (Белый)
set "g=!ESC![38;2;85;85;102m"   :: COLOR_BORDER (Темно серый)
set "ok=!ESC![38;2;0;255;128m"  :: Успех (зеленый)
set "err=!ESC![38;2;255;8;68m"  :: COLOR_ACCENT (Красный)
set "r=!ESC![0m"                :: Сброс цвета

:: Инициализация 
if not defined IPsetStatus set "IPsetStatus=any"
if not defined GameFilterStatus set "GameFilterStatus=enabled"
if not defined CheckUpdatesStatus set "CheckUpdatesStatus=checking..."

:: MENU 
:menu
mode con: cols=60 lines=20
cls
call :ipset_switch_status
call :game_switch_status
call :check_updates_switch_status

chcp 65001 >nul

:: Настройка отображения
if /i "!GameFilterStatus!"=="enabled" (set "game_view=!ok!включен!r!") else (set "game_view=!g!выключен!r!")
if /i "!IPsetStatus!"=="any" (set "ipset_view=!p!всё!r!") 
if /i "!IPsetStatus!"=="none" (set "ipset_view=!p!выключен!r!") 
if /i "!IPsetStatus!"=="loaded" (set "ipset_view=!p!ограничено!r!")

echo.
echo   !p!Z P R T X !r!
echo   !d!v%LOCAL_VERSION%  by shprot!r!
echo  !g!══════════════════════════════════════════════!r!
echo   !g![!p!1!g!]!w! Запустить!r!
echo   !g![!p!2!g!]!w! Выключить!r!
echo   !g![!p!3!g!]!w! Проверить статус!r!
echo   !g![!p!4!g!]!w! Гайд на стратегии!r!
echo  !g!───!d! SETTINGS !g!────────────────────────────────!r!
echo   !g![!p!5!g!]!w! Запуск диагностики!r!
echo   !g![!p!6!g!]!w! Игровой Фильтр      !g!───!w! ^( !game_view! !w!^)!r!
echo   !g![!p!7!g!]!w! Фильтрация трафика !g!───!w! ^( !ipset_view! !w!^)!r!
echo  !g!══════════════════════════════════════════════!r!
echo   !g![!err!0!g!]!w! Закрыть окно!r!
echo.

set "menu_choice=null"
set /p menu_choice=!p! ❯ !w!Выбор: !p!

if "%menu_choice%"=="1" goto service_install
if "%menu_choice%"=="2" goto service_remove
if "%menu_choice%"=="3" goto service_status
if "%menu_choice%"=="4" goto strategy_guide
if "%menu_choice%"=="5" goto service_diagnostics
if "%menu_choice%"=="6" goto game_switch
if "%menu_choice%"=="7" goto ipset_switch
if "%menu_choice%"=="8" goto ipset_update
if "%menu_choice%"=="0" exit
goto menu


:: INSTALL CUSTOM ALT 
:service_install_alt
mode con: cols=100 lines=40
cls
chcp 65001 > nul

cd /d "%~dp0"
set "BIN_PATH=%~dp0bin\"
set "LISTS_PATH=%~dp0lists\"
set "ALTTS_PATH=%~dp0ALTTS\"

if not exist "!ALTTS_PATH!" (
    echo.
    echo   !p!Z P R T X !r!
    echo   !d!//!p!УСТАНОВКА КАСТОМНЫХ СЛУЖБ!r!
    echo  !g!══════════════════════════════════════════════!r!
    echo.
    echo   !err![!] Папка ALTTS не найдена в корневой директории.!r!
    echo   !w!Создайте папку ALTTS и поместите в неё .bat файлы стратегий.!r!
    echo.
    pause
    goto service_install
)

set "alt_count=0"
for %%f in ("!ALTTS_PATH!*.bat") do (
    set /a alt_count+=1
    set "alt_file!alt_count!=%%f"
    set "alt_name!alt_count!=%%~nxf"
    if "!alt_count!"=="1" (
        set "ALT_LINE_!alt_count!=  !g![!p!!alt_count!!g!]!w! %%~nxf !d!!r!"
    ) else (
        set "ALT_LINE_!alt_count!=  !g![!p!!alt_count!!g!]!w! %%~nxf!r!"
    )
)

echo.
echo   !p!Z P R T X !r!
echo   !d!//!p!УСТАНОВКА КАСТОМНЫХ СЛУЖБ!d!
echo  !g!══════════════════════════════════════════════!r!
echo   !w!Выберите кастомный ALT вариант:!r!
echo.

if !alt_count!==0 (
    echo   !err![!] В папке ALTTS не найдено .bat файлов.!r!
    echo.
    pause
    goto service_install
)

for /L %%i in (1,1,!alt_count!) do (
    echo !ALT_LINE_%%i!
)

echo.
echo  !g!──────────────────────────────────────────────!r!
echo   !g![!p!0!g!]!w! Вернуться назад!r!
echo  !g!──────────────────────────────────────────────!r!

set "alt_choice="
set /p "alt_choice=!p! ❯ !w!Введите номер: !p!"

if "!alt_choice!"=="" (
    echo  !err![!] Выбор пуст, возвращаюсь...!r!
    timeout /t 2 > nul
    goto service_install
)

if "!alt_choice!"=="0" goto service_install

set "selectedFile=!alt_file%alt_choice%!"
if not defined selectedFile (
    echo  !err![!] Неверный выбор, возвращаюсь...!r!
    timeout /t 2 > nul
    goto service_install_alt
)

set "args_with_value=sni host altorder"
set "args="
set "capture=0"
set "mergeargs=0"
set QUOTE="

for /f "tokens=*" %%a in ('type "!selectedFile!"') do (
    set "line=%%a"
    call set "line=%%line:^!=EXCL_MARK%%"

    echo !line! | findstr /i "%BIN%winws.exe" >nul
    if not errorlevel 1 (
        set "capture=1"
    )

    if !capture!==1 (
        if not defined args (
            set "line=!line:*%BIN%winws.exe"=!"
        )

        set "temp_args="
        for %%i in (!line!) do (
            set "arg=%%i"

            if not "!arg!"=="^" (
                if "!arg:~0,2!" EQU "--" if not !mergeargs!==0 (
                    set "mergeargs=0"
                )

                if "!arg:~0,1!" EQU "!QUOTE!" (
                    set "arg=!arg:~1,-1!"

                    echo !arg! | findstr ":" >nul
                    if !errorlevel!==0 (
                        set "arg=\!QUOTE!!arg!\!QUOTE!"
                    ) else if "!arg:~0,1!"=="@" (
                        set "arg=\!QUOTE!@%~dp0!arg:~1!\!QUOTE!"
                    ) else if "!arg:~0,5!"=="%%BIN%%" (
                        set "arg=\!QUOTE!!BIN_PATH!!arg:~5!\!QUOTE!"
                    ) else if "!arg:~0,7!"=="%%LISTS%%" (
                        set "arg=\!QUOTE!!LISTS_PATH!!arg:~7!\!QUOTE!"
                    ) else (
                        set "arg=\!QUOTE!%~dp0!arg!\!QUOTE!"
                    )
                ) else if "!arg:~0,12!" EQU "%%GameFilter%%" (
                    set "arg=%GameFilter%"
                )

                if !mergeargs!==1 (
                    set "temp_args=!temp_args!,!arg!"
                ) else if !mergeargs!==3 (
                    set "temp_args=!temp_args!=!arg!"
                    set "mergeargs=1"
                ) else (
                    set "temp_args=!temp_args! !arg!"
                )

                if "!arg:~0,2!" EQU "--" (
                    set "mergeargs=2"
                ) else if !mergeargs! GEQ 1 (
                    if !mergeargs!==2 set "mergeargs=1"

                    for %%x in (!args_with_value!) do (
                        if /i "%%x"=="!arg!" (
                            set "mergeargs=3"
                        )
                    )
                )
            )
        )

        if not "!temp_args!"=="" (
            set "args=!args! !temp_args!"
        )
    )
)

call :tcp_enable

set ARGS=%args%
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"
echo  !g![!p!^>!g!]!w! Final args: !p!!ARGS!!r!
set SRVCNAME=zprtx

net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
sc create %SRVCNAME% binPath= "\"%BIN_PATH%winws.exe\" !ARGS!" DisplayName= "zprtx" start= auto
sc description %SRVCNAME% "zprtx DPI bypass software"
sc start %SRVCNAME%
for %%F in ("!selectedFile!") do (
    set "filename=%%~nF"
)
reg add "HKLM\System\CurrentControlSet\Services\zprtx" /v zprtx-roblox /t REG_SZ /d "!filename! [ALTTS]" /f

pause
goto menu


:: STRATEGY GUIDE 
:strategy_guide
mode con: cols=100 lines=45
cls
chcp 65001 > nul

echo.
echo   !p!Z P R T X !r!
echo   !d!//!p!ГАЙД НА СТРАТЕГИИ!r!
echo  !g!══════════════════════════════════════════════!r!
echo.
echo   !d!Этот инструмент не является классическим VPN.!r!
echo   !w!Он не меняет ваш IP-адрес и не пускает трафик через чужие серверы.!r!
echo   !w!Вместо этого он прямо на вашем компьютере «пудрит мозги» системам!r!
echo   !w!блокировок вашего интернет-провайдера, изменяя структуру сетевых пакетов.!r!
echo.
echo  !g!════════════════════!d! ТЕРМИНЫ !g!════════════════════!r!
echo.
echo   !p!SIMPLE!r!  !g!│!r!  !w!Программа режет ваш запрос на мелкие кусочки!r!
echo          !g!│!r!  !w!^(фрагментирует^) или слегка меняет регистр букв!r!
echo          !g!│!r!  !g!^(вместо youtube.com пишет YoUtUbE.cOm^)!r!
echo.
echo   !p!FAKE!r!    !g!│!r!  !w!Программа создаёт ложный, «мусорный» пакет и кидает!r!
echo          !g!│!r!  !w!его провайдеру. Система блокировки отвлекается на этот!r!
echo          !g!│!r!  !w!мусор, а в этот момент за ним пролетает ваш запрос.!r!
echo.
echo   !p!TLS!r!     !g!│!r!  !w!Протокол защиты сайтов. Пакет замаскирован под начало!r!
echo          !g!│!r!  !w!безопасного соединения с сайтом. Это бьёт точно в цель!r!
echo          !g!│!r!  !w!при разблокировке сайтов в браузере.!r!
echo.
echo   !p!AUTO!r!    !g!│!r!  !w!Автоматический расчет дистанции. Программа сама вычисляет,!r!
echo          !g!│!r!  !w!как далеко от вас находится блокиратор провайдера, чтобы!r!
echo          !g!│!r!  !w!фейковый пакет исчез ровно на его оборудовании.!r!
echo.
echo   !p!ALT!r!     !g!│!r!  !w!Разные варианты цифровых настроек.!r!
echo          !g!│!r!  !g!^(ALT / ALT2 / ALT3^) — готовые наборы параметров для перебора.!r!
echo.
echo  !g!══════════════════!d! СТРАТЕГИИ !g!══════════════════!r!
echo.
echo   !g![!p!1!g!]!r! !p!general !g!^(SIMPLE FAKE^)!r!
echo       !w!Двойной удар. Программа сначала нарезает ваш реальный запрос!r!
echo       !w!на части, а перед ними отправляет фейковый пакет для отвлечения!r!
echo       !w!внимания. Сбалансированный вариант — часто оживляет YouTube!r!
echo       !w!на большинстве региональных провайдеров.!r!
echo.
echo   !g![!p!2!g!]!r! !p!general !g!^(FAKE TLS AUTO^)!r!
echo       !w!Создает очень правдоподобный поддельный пакет шифрования ^(TLS^)!r!
echo       !w!и автоматически настраивает его дальность ^(AUTO^),!r!
echo       !w!чтобы обмануть ТСПУ.!r!
echo.
echo  !g!══════════════════════════════════════════════!r!
echo.
pause
goto menu


:: TCP ENABLE 
:tcp_enable
netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul || netsh interface tcp set global timestamps=enabled > nul 2>&1
exit /b


:: STATUS 
:service_status
mode con: cols=60 lines=20
cls
chcp 65001 > nul

echo.
echo  !w!by shprot!r!
echo.

:: проверка 
sc query "zprtx" >nul 2>&1
if !errorlevel!==0 (
    for /f "tokens=2*" %%A in ('reg query "HKLM\System\CurrentControlSet\Services\zprtx" /v zprtx-roblox 2^>nul') do (
        echo  !w!Service strategy installed from: !d!%%B!r!
    )
)

call :test_service zprtx
call :test_service WinDivert

set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%\*.sys" (
    echo  !err!WinDivert64.sys file NOT found.!r!
)
echo:

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    echo  !w!Bypass ^(winws.exe^) is !ok!RUNNING.!r!
) else (
    echo  !w!Bypass ^(winws.exe^) is !err!NOT running.!r!
)

echo.
echo  !d!-----------------------------------------------------------!r!
echo.
pause
goto menu

:test_service
set "ServiceName=%~1"
set "ServiceStatus="

for /f "tokens=3 delims=: " %%A in ('sc query "%ServiceName%" ^| findstr /i "STATE"') do set "ServiceStatus=%%A"
set "ServiceStatus=%ServiceStatus: =%"

if "%ServiceStatus%"=="RUNNING" (
    if "%~2"=="soft" (
        echo  !w!"%ServiceName%" is ALREADY RUNNING as service, use "service.bat" and choose "Remove Services" first.!r!
        pause
        exit /b
    ) else (
        echo  !w!"%ServiceName%" service is !ok!RUNNING.!r!
    )
) else if "%ServiceStatus%"=="STOP_PENDING" (
    call :PrintYellow "!ServiceName! is STOP_PENDING, that may be caused by a conflict with another bypass. Run Diagnostics to try to fix conflicts."
) else if not "%~2"=="soft" (
    echo  !w!"%ServiceName%" service is !err!NOT running.!r!
)

exit /b


:: REMOVE 
:service_remove
mode con: cols=60 lines=20
cls
chcp 65001 > nul

echo.
echo   !p!Z P R T X !r!
echo   !d!//!err!ВЫКЛЮЧЕНИЕ!r!
echo  !g!══════════════════════════════════════════════!r!
echo.

set "SRVCNAME=zprtx"
sc query "!SRVCNAME!" >nul 2>&1
if !errorlevel!==0 (
    echo   !g![!p!^>!g!]!w! Останавливаю и удаляю службу: !SRVCNAME!...!r!
    net stop !SRVCNAME! >nul 2>&1
    sc delete !SRVCNAME! >nul 2>&1
    echo   !g![!ok!+!g!]!w! Готово.!r!
) else (
    echo   !g![!err!-!g!]!w! Служба "!SRVCNAME!" не установлена в системе.!r!
)

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
if !errorlevel!==0 (
    echo   !g![!p!^>!g!]!w! Завершаю процесс winws.exe...!r!
    taskkill /IM winws.exe /F > nul
    echo   !g![!ok!+!g!]!w! Готово.!r!
)

sc query "WinDivert" >nul 2>&1
if !errorlevel!==0 (
    echo   !g![!p!^>!g!]!w! Удаляю драйвер WinDivert...!r!
    net stop "WinDivert" >nul 2>&1
    sc query "WinDivert" >nul 2>&1
    if !errorlevel!==0 (
        sc delete "WinDivert" >nul 2>&1
    )
    echo   !g![!ok!+!g!]!w! Готово.!r!
)

echo   !g![!p!^>!g!]!w! Окончательная очистка ^(WinDivert14^)...!r!
net stop "WinDivert14" >nul 2>&1
sc delete "WinDivert14" >nul 2>&1
echo   !g![!ok!+!g!]!w! Все системы полностью очищены.!r!

echo.
echo  !g!──────────────────────────────────────────────!r!
echo.
pause
goto menu


:: INSTALL
:service_install
mode con: cols=100 lines=40
cls
chcp 65001 > nul

cd /d "%~dp0"
set "BIN_PATH=%~dp0bin\"
set "LISTS_PATH=%~dp0lists\"

set "count=0"
for %%f in (*.bat) do (
    set "filename=%%~nxf"
    if /i not "!filename:~0,7!"=="service" (
        if /i not "!filename!"=="MAIN.bat" (
            set /a count+=1
            set "file!count!=%%f"
            
            if "!count!"=="1" (
                set "FILE_LINE_!count!=  !g![!p!!count!!g!]!w! %%f !d!^<--- [ДЕФОЛТНАЯ, УНИВЕРСАЛЬНАЯ]!r!"
            ) else (
                set "FILE_LINE_!count!=  !g![!p!!count!!g!]!w! %%f!r!"
            )
        )
    )
)

echo.
echo   !p!Z P R T X !r!
echo   !d!//!p!УСТАНОВКА СЛУЖБЫ!d! // !p!Перед запуском рекомендую ознакомиться с пунктом !g![!p!4!g!]!p! в меню!r!
echo  !g!══════════════════════════════════════════════!r!
echo   !w!Выберите один из доступных вариантов:!r!
echo.

for /L %%i in (1,1,%count%) do (
    echo !FILE_LINE_%%i!
)

echo.
echo  !g!──────────────────────────────────────────────!r!
echo   !g![!p!9!g!]!w! Кастомные ALT !r!
echo  !g!──────────────────────────────────────────────!r!

set "choice="
set /p "choice=!p! ❯ !w!Введите номер: !p!"

if "!choice!"=="" (
    echo  !err![!] Выбор пуст, возвращаюсь в меню...!r!
    timeout /t 2 > nul
    goto menu
)

if "!choice!"=="9" goto service_install_alt

set "selectedFile=!file%choice%!"
if not defined selectedFile (
    echo  !err![!] Invalid choice, returning to menu...!r!
    timeout /t 2 > nul
    goto menu
)

set "args_with_value=sni host altorder"
set "args="
set "capture=0"
set "mergeargs=0"
set QUOTE="

for /f "tokens=*" %%a in ('type "!selectedFile!"') do (
    set "line=%%a"
    call set "line=%%line:^!=EXCL_MARK%%"

    echo !line! | findstr /i "%BIN%winws.exe" >nul
    if not errorlevel 1 (
        set "capture=1"
    )

    if !capture!==1 (
        if not defined args (
            set "line=!line:*%BIN%winws.exe"=!"
        )

        set "temp_args="
        for %%i in (!line!) do (
            set "arg=%%i"

            if not "!arg!"=="^" (
                if "!arg:~0,2!" EQU "--" if not !mergeargs!==0 (
                    set "mergeargs=0"
                )

                if "!arg:~0,1!" EQU "!QUOTE!" (
                    set "arg=!arg:~1,-1!"

                    echo !arg! | findstr ":" >nul
                    if !errorlevel!==0 (
                        set "arg=\!QUOTE!!arg!\!QUOTE!"
                    ) else if "!arg:~0,1!"=="@" (
                        set "arg=\!QUOTE!@%~dp0!arg:~1!\!QUOTE!"
                    ) else if "!arg:~0,5!"=="%%BIN%%" (
                        set "arg=\!QUOTE!!BIN_PATH!!arg:~5!\!QUOTE!"
                    ) else if "!arg:~0,7!"=="%%LISTS%%" (
                        set "arg=\!QUOTE!!LISTS_PATH!!arg:~7!\!QUOTE!"
                    ) else (
                        set "arg=\!QUOTE!%~dp0!arg!\!QUOTE!"
                    )
                ) else if "!arg:~0,12!" EQU "%%GameFilter%%" (
                    set "arg=%GameFilter%"
                )

                if !mergeargs!==1 (
                    set "temp_args=!temp_args!,!arg!"
                ) else if !mergeargs!==3 (
                    set "temp_args=!temp_args!=!arg!"
                    set "mergeargs=1"
                ) else (
                    set "temp_args=!temp_args! !arg!"
                )

                if "!arg:~0,2!" EQU "--" (
                    set "mergeargs=2"
                ) else if !mergeargs! GEQ 1 (
                    if !mergeargs!==2 set "mergeargs=1"

                    for %%x in (!args_with_value!) do (
                        if /i "%%x"=="!arg!" (
                            set "mergeargs=3"
                        )
                    )
                )
            )
        )

        if not "!temp_args!"=="" (
            set "args=!args! !temp_args!"
        )
    )
)

call :tcp_enable

set ARGS=%args%
call set "ARGS=%%ARGS:EXCL_MARK=^!%%"
echo  !g![!p!^>!g!]!w! Final args: !p!!ARGS!!r!
set SRVCNAME=zprtx

net stop %SRVCNAME% >nul 2>&1
sc delete %SRVCNAME% >nul 2>&1
sc create %SRVCNAME% binPath= "\"%BIN_PATH%winws.exe\" !ARGS!" DisplayName= "zprtx" start= auto
sc description %SRVCNAME% "zprtx DPI bypass software"
sc start %SRVCNAME%
for %%F in ("!file%choice%!") do (
    set "filename=%%~nF"
)
reg add "HKLM\System\CurrentControlSet\Services\zprtx" /v zprtx-roblox /t REG_SZ /d "!filename!" /f

pause
goto menu


:: DIAGNOSTICS 
:service_diagnostics
mode con: cols=100 lines=45
chcp 65001 > nul
cls
echo.
echo   !p!Z P R T X !r!
echo   !d!//!p!ДИАГНОСТИКА!r!
echo  !g!══════════════════════════════════════════════!r!
echo.

sc query BFE | findstr /I "RUNNING" > nul
if !errorlevel!==0 (
    call :PrintGreen "Base Filtering Engine check passed"
) else (
    call :PrintRed "[X] Base Filtering Engine is not running. This service is required for zprtx to work"
)
echo:

set "proxyEnabled=0"
set "proxyServer="
for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable 2^>nul ^| findstr /i "ProxyEnable"') do (
    if "%%B"=="0x1" set "proxyEnabled=1"
)

if !proxyEnabled!==1 (
    for /f "tokens=2*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer 2^>nul ^| findstr /i "ProxyServer"') do (
        set "proxyServer=%%B"
    )
    call :PrintYellow "[?] System proxy is enabled: !proxyServer!"
    call :PrintYellow "Make sure it's valid or disable it if you don't use a proxy"
) else (
    call :PrintGreen "Proxy check passed"
)
echo:

where netsh >nul 2>nul
if !errorlevel! neq 0  (
    call :PrintRed "[X] netsh command not found, check your PATH variable"
	echo PATH = "%PATH%"
	echo:
	pause
	goto menu
)

netsh interface tcp show global | findstr /i "timestamps" | findstr /i "enabled" > nul
if !errorlevel!==0 (
    call :PrintGreen "TCP timestamps check passed"
) else (
    call :PrintYellow "[?] TCP timestamps are disabled. Enabling timestamps..."
    netsh interface tcp set global timestamps=enabled > nul 2>&1
    if !errorlevel!==0 (
        call :PrintGreen "TCP timestamps successfully enabled"
    ) else (
        call :PrintRed "[X] Failed to enable TCP timestamps"
    )
)
echo:

tasklist /FI "IMAGENAME eq AdguardSvc.exe" | find /I "AdguardSvc.exe" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Adguard process found. Adguard may cause problems with Discord"
    call :PrintRed "https://github.com/Lux1de/zprtx-roblox/issues"
) else (
    call :PrintGreen "Adguard check passed"
)
echo:

sc query | findstr /I "Killer" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Killer services found. Killer conflicts with zprtx"
    call :PrintRed "https://github.com/Lux1de/zprtx-roblox/issues"
) else (
    call :PrintGreen "Killer check passed"
)
echo:

sc query | findstr /I "Intel" | findstr /I "Connectivity" | findstr /I "Network" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] Intel Connectivity Network Service found. It conflicts with zprtx"
    call :PrintRed "https://github.com/ValdikSS/GoodbyeDPI/issues/541#issuecomment-2661670982"
) else (
    call :PrintGreen "Intel Connectivity check passed"
)
echo:

set "checkpointFound=0"
sc query | findstr /I "TracSrvWrapper" > nul
if !errorlevel!==0 set "checkpointFound=1"
sc query | findstr /I "EPWD" > nul
if !errorlevel!==0 set "checkpointFound=1"

if !checkpointFound!==1 (
    call :PrintRed "[X] Check Point services found. Check Point conflicts with zprtx"
    call :PrintRed "Try to uninstall Check Point"
) else (
    call :PrintGreen "Check Point check passed"
)
echo:

sc query | findstr /I "SmartByte" > nul
if !errorlevel!==0 (
    call :PrintRed "[X] SmartByte services found. SmartByte conflicts with zprtx"
    call :PrintRed "Try to uninstall or disable SmartByte through services.msc"
) else (
    call :PrintGreen "SmartByte check passed"
)
echo:

set "BIN_PATH=%~dp0bin\"
if not exist "%BIN_PATH%\*.sys" (
    call :PrintRed "WinDivert64.sys file NOT found."
)
echo:

set "VPN_SERVICES="
sc query | findstr /I "VPN" > nul
if !errorlevel!==0 (
    for /f "tokens=2 delims=:" %%A in ('sc query ^| findstr /I "VPN"') do (
        if not defined VPN_SERVICES (
            set "VPN_SERVICES=!VPN_SERVICES!%%A"
        ) else (
            set "VPN_SERVICES=!VPN_SERVICES!,%%A"
        )
    )
    call :PrintYellow "[?] VPN services found:!VPN_SERVICES!. Some VPNs can conflict with zprtx"
    call :PrintYellow "Make sure that all VPNs are disabled"
) else (
    call :PrintGreen "VPN check passed"
)
echo:

set "dohfound=0"
for /f "delims=" %%a in ('powershell -Command "Get-ChildItem -Recurse -Path 'HKLM:System\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\' | Get-ItemProperty | Where-Object { $_.DohFlags -gt 0 } | Measure-Object | Select-Object -ExpandProperty Count"') do (
    if %%a gtr 0 set "dohfound=1"
)
if !dohfound!==0 (
    call :PrintYellow "[?] Make sure you have configured secure DNS in a browser with some non-default DNS service provider,"
    call :PrintYellow "If you use Windows 11 you can configure encrypted DNS in the Settings to hide this warning"
) else (
    call :PrintGreen "Secure DNS check passed"
)
echo:

tasklist /FI "IMAGENAME eq winws.exe" | find /I "winws.exe" > nul
set "winws_running=!errorlevel!"

sc query "WinDivert" | findstr /I "RUNNING STOP_PENDING" > nul
set "windivert_running=!errorlevel!"

if !winws_running! neq 0 if !windivert_running!==0 (
    call :PrintYellow "[?] winws.exe is not running but WinDivert service is active. Attempting to delete WinDivert..."
    
    net stop "WinDivert" >nul 2>&1
    sc delete "WinDivert" >nul 2>&1
    sc query "WinDivert" >nul 2>&1
    if !errorlevel!==0 (
        call :PrintRed "[X] Failed to delete WinDivert. Checking for conflicting services..."
        set "conflicting_services=GoodbyeDPI"
        set "found_conflict=0"
        
        for %%s in (!conflicting_services!) do (
            sc query "%%s" >nul 2>&1
            if !errorlevel!==0 (
                call :PrintYellow "[?] Found conflicting service: %%s. Stopping and removing..."
                net stop "%%s" >nul 2>&1
                sc delete "%%s" >nul 2>&1
                if !errorlevel!==0 (
                    call :PrintGreen "Successfully removed service: %%s"
                ) else (
                    call :PrintRed "[X] Failed to remove service: %%s"
                )
                set "found_conflict=1"
            )
        )
        
        if !found_conflict!==0 (
            call :PrintRed "[X] No conflicting services found. Check manually if any other bypass is using WinDivert."
        ) else (
            call :PrintYellow "[?] Attempting to delete WinDivert again..."
            net stop "WinDivert" >nul 2>&1
            sc delete "WinDivert" >nul 2>&1
            sc query "WinDivert" >nul 2>&1
            if !errorlevel! neq 0 (
                call :PrintGreen "WinDivert successfully deleted after removing conflicting services"
            ) else (
                call :PrintRed "[X] WinDivert still cannot be deleted. Check manually if any other bypass is using WinDivert."
            )
        )
    ) else (
        call :PrintGreen "WinDivert successfully removed"
    )
    echo:
)

set "conflicting_services=GoodbyeDPI discordfix_zprtx winws1 winws2"
set "found_any_conflict=0"
set "found_conflicts="

for %%s in (!conflicting_services!) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel!==0 (
        if "!found_conflicts!"=="" (
            set "found_conflicts=%%s"
        ) else (
            set "found_conflicts=!found_conflicts! %%s"
        )
        set "found_any_conflict=1"
    )
)

if !found_any_conflict!==1 (
    call :PrintRed "[X] Conflicting bypass services found: !found_conflicts!"
    
    set "CHOICE="
    set /p "CHOICE=!p!Do you want to remove these conflicting services? (Y/N) (default: N) !p!"
    if "!CHOICE!"=="" set "CHOICE=N"
    if "!CHOICE!"=="y" set "CHOICE=Y"
    
    if /i "!CHOICE!"=="Y" (
        for %%s in (!found_conflicts!) do (
            call :PrintYellow "Stopping and removing service: %%s"
            net stop "%%s" >nul 2>&1
            sc delete "%%s" >nul 2>&1
            if !errorlevel!==0 (
                call :PrintGreen "Successfully removed service: %%s"
            ) else (
                call :PrintRed "[X] Failed to remove service: %%s"
            )
        )
        net stop "WinDivert" >nul 2>&1
        sc delete "WinDivert" >nul 2>&1
        net stop "WinDivert14" >nul 2>&1
        sc delete "WinDivert14" >nul 2>&1
    )
    echo:
)

set "CHOICE="
set /p "CHOICE=!p!Do you want to clear the Discord cache? (Y/N) (default: Y) !p!"
if "!CHOICE!"=="" set "CHOICE=Y"
if "!CHOICE!"=="y" set "CHOICE=Y"

if /i "!CHOICE!"=="Y" (
    tasklist /FI "IMAGENAME eq Discord.exe" | findstr /I "Discord.exe" > nul
    if !errorlevel!==0 (
        echo !w!Discord is running, closing...!r!
        taskkill /IM Discord.exe /F > nul
        if !errorlevel! == 0 (
            call :PrintGreen "Discord was successfully closed"
        ) else (
            call :PrintRed "Unable to close Discord"
        )
    )

    set "discordCacheDir=%appdata%\discord"

    for %%d in ("Cache" "Code Cache" "GPUCache") do (
        set "dirPath=!discordCacheDir!\%%~d"
        if exist "!dirPath!" (
            rd /s /q "!dirPath!"
            if !errorlevel!==0 (
                call :PrintGreen "Successfully deleted !dirPath!"
            ) else (
                call :PrintRed "Failed to delete !dirPath!"
            )
        ) else (
            call :PrintRed "!dirPath! does not exist"
        )
    )
)
echo:

pause
goto menu


:: GAME SWITCH 
:game_switch_status
chcp 65001 > nul
set "gameFlagFile=%~dp0utils\game_filter.enabled"
if exist "%gameFlagFile%" (
    set "GameFilterStatus=enabled"
    set "GameFilter=1024-65535"
) else (
    set "GameFilterStatus=disabled"
    set "GameFilter=12"
)
exit /b

:game_switch
chcp 65001 > nul
cls
if not exist "%gameFlagFile%" (
    echo !w!Enabling game filter...!r!
    echo ENABLED > "%gameFlagFile%"
    call :PrintYellow "Restart the zprtx to apply the changes"
) else (
    echo !w!Disabling game filter...!r!
    del /f /q "%gameFlagFile%"
    call :PrintYellow "Restart the zprtx to apply the changes"
)
pause
goto menu


:: CHECK UPDATES SWITCH 
:check_updates_switch_status
chcp 65001 > nul
set "checkUpdatesFlag=%~dp0utils\check_updates.enabled"
if exist "%checkUpdatesFlag%" (
    set "CheckUpdatesStatus=enabled"
) else (
    set "CheckUpdatesStatus=disabled"
)
exit /b

:check_updates_switch
chcp 65001 > nul
cls
if not exist "%checkUpdatesFlag%" (
    echo !w!Enabling check updates...!r!
    echo ENABLED > "%checkUpdatesFlag%"
) else (
    echo !w!Disabling check updates...!r!
    del /f /q "%checkUpdatesFlag%"
)
pause
goto menu


:: IPSET SWITCH 
:ipset_switch_status
chcp 65001 > nul
set "listFile=%~dp0lists\ipset-all.txt"
for /f %%i in ('type "%listFile%" 2^>nul ^| find /c /v ""') do set "lineCount=%%i"
if !lineCount!==0 (
    set "IPsetStatus=any"
) else (
    findstr /R "^203\.0\.113\.113/32$" "%listFile%" >nul
    if !errorlevel!==0 (
        set "IPsetStatus=none"
    ) else (
        set "IPsetStatus=loaded"
    )
)
exit /b

:ipset_switch
chcp 65001 > nul
cls
set "listFile=%~dp0lists\ipset-all.txt"
set "backupFile=%listFile%.backup"

if "%IPsetStatus%"=="loaded" (
    echo !w!Switching to none mode...!r!
    if not exist "%backupFile%" (
        ren "%listFile%" "ipset-all.txt.backup"
    ) else (
        del /f /q "%backupFile%"
        ren "%listFile%" "ipset-all.txt.backup"
    )
    >"%listFile%" echo 203.0.113.113/32
) else if "%IPsetStatus%"=="none" (
    echo !w!Switching to any mode...!r!
    >"%listFile%" echo.
) else if "%IPsetStatus%"=="any" (
    echo !w!Switching to loaded mode...!r!
    if exist "%backupFile%" (
        del /f /q "%listFile%"
        ren "%backupFile%" "ipset-all.txt"
    ) else (
        echo !err!Error: no backup to restore. Update list from service menu first!r!
        pause
        goto menu
    )
)
pause
goto menu


:: IPSET UPDATE 
:ipset_update
chcp 65001 > nul
cls
set "listFile=%~dp0lists\ipset-all.txt"
set "url=https://raw.githubusercontent.com/Lux1de/zprtx-roblox/refs/heads/main/.service/ipset-service.txt"
echo !w!Updating ipset-all...!r!

if exist "%SystemRoot%\System32\curl.exe" (
    curl -L -o "%listFile%" "%url%"
) else (
    powershell -Command ^
        "$url = '%url%';" ^
        "$out = '%listFile%';" ^
        "$dir = Split-Path -Parent $out;" ^
        "if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null };" ^
        "$res = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing;" ^
        "if ($res.StatusCode -eq 200) { $res.Content | Out-File -FilePath $out -Encoding UTF8 } else { exit 1 }"
)
echo !ok!Finished!r!
pause
goto menu


:: HOSTS UPDATE =======================
:hosts_update
chcp 65001 > nul
cls
set "hostsFile=%SystemRoot%\System32\drivers\etc\hosts"
set "hostsUrl=https://raw.githubusercontent.com/Lux1de/zprtx-roblox/refs/heads/main/.service/hosts"
set "tempFile=%TEMP%\zprtx_hosts.txt"
set "needsUpdate=0"

echo !w!Checking hosts file...!r!

if exist "%SystemRoot%\System32\curl.exe" (
    curl -L -s -o "%tempFile%" "%hostsUrl%"
) else (
    powershell -Command ^
        "$url = '%hostsUrl%';" ^
        "$out = '%tempFile%';" ^
        "$res = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UseBasicParsing;" ^
        "if ($res.StatusCode -eq 200) { $res.Content | Out-File -FilePath $out -Encoding UTF8 } else { exit 1 }"
)

if not exist "%tempFile%" (
    call :PrintRed "Failed to download hosts file from repository"
    call :PrintYellow "Copy hosts file manually from %hostsUrl%"
    pause
    goto menu
)

set "firstLine="
set "lastLine="
for /f "usebackq delims=" %%a in ("%tempFile%") do (
    if not defined firstLine set "firstLine=%%a"
    set "lastLine=%%a"
)

findstr /C:"!firstLine!" "%hostsFile%" >nul 2>&1
if !errorlevel! neq 0 (
    echo !w!First line from repository not found in hosts file!r!
    set "needsUpdate=1"
)

findstr /C:"!lastLine!" "%hostsFile%" >nul 2>&1
if !errorlevel! neq 0 (
    echo !w!Last line from repository not found in hosts file!r!
    set "needsUpdate=1"
)

if "%needsUpdate%"=="1" (
    echo:
    call :PrintYellow "Hosts file needs to be updated"
    call :PrintYellow "Please manually copy the content from the downloaded file to your hosts file"
    start notepad "%tempFile%"
    explorer /select,"%hostsFile%"
) else (
    call :PrintGreen "Hosts file is up to date"
    if exist "%tempFile%" del /f /q "%tempFile%"
)
echo:
pause
goto menu


:: RUN TESTS 
:run_tests
chcp 65001 >nul
cls

powershell -NoProfile -Command "if ($PSVersionTable -and $PSVersionTable.PSVersion -and $PSVersionTable.PSVersion.Major -ge 3) { exit 0 } else { exit 1 }" >nul 2>&1
if %errorLevel% neq 0 (
    echo !err!PowerShell 3.0 or newer is required.!r!
    echo !err!Please upgrade PowerShell and rerun this script.!r!
    echo.
    pause
    goto menu
)

echo !p!Starting configuration tests in PowerShell window...!r!
echo.
start "" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0utils\test zprtx.ps1"
pause
goto menu


:: Utility functions
:PrintGreen
echo !ok!%~1!r!
exit /b

:PrintRed
echo !err!%~1!r!
exit /b

:PrintYellow
echo !p!%~1!r!
exit /b

:check_command
where %1 >nul 2>&1
if %errorLevel% neq 0 (
    echo !err![ERROR] %1 not found in PATH!r!
    echo !w!Fix your PATH variable with instructions here https://github.com/Lux1de/zprtx-roblox/issues!r!
    pause
    exit /b 1
)
exit /b 0

:check_extracted
set "extracted=1"
if not exist "%~dp0bin\" set "extracted=0"
if "%extracted%"=="0" (
    echo !err!zprtx must be extracted from archive first or bin folder not found for some reason!r!
    pause
    exit
)
exit /b 0
