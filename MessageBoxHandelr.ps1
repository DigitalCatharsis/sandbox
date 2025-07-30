$computername = "ИМЯ"

# Настройка DCOM
$options = New-CimSessionOption -Protocol Dcom
$session = New-CimSession -ComputerName $computername -SessionOption $options

# Путь к вашему .exe на удалённой машине
$exePath = "\\ПУТЬ\MessageBoxApp.exe"

# Длинное сообщение
$title = "Уведомление"



$message = 
    "Привет! Это очень длинное сообщение, которое не влезет в обычную команду msg. 
    "





# Экранируем кавычки
$escapedMessage = $message -replace '"', '""'
$commandLine = "`"$exePath`" `"$title`" `"$escapedMessage`""

# Запускаем
$process = Invoke-CimMethod -ClassName Win32_Process -MethodName Create `
    -Arguments @{ CommandLine = $commandLine } `
    -CimSession $session

if ($process.ReturnValue -eq 0) {
    Write-Host "Приложение запущено! PID: $($process.ProcessId)" -ForegroundColor Green
} else {
    Write-Host "Ошибка: $($process.ReturnValue)" -ForegroundColor Red
}

Remove-CimSession $session