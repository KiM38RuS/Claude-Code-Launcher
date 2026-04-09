; ============================================
; Claude Code Launcher with Omniroute
; ============================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; === НАСТРОЙКИ ===
MAX_HISTORY := 10  ; Максимальное количество папок в истории
TIMEOUT_SECONDS := 30  ; Таймаут ожидания запуска Omniroute (в секундах)
HISTORY_FILE := A_ScriptDir "\cc_history.txt"

; === ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ===
global selectedFolder := ""
global historyList := []

; === ОСНОВНАЯ ЛОГИКА ===
Main()

Main() {
    ; Загружаем историю папок
    LoadHistory()

    ; Показываем GUI для выбора папки
    ShowFolderSelectionGUI()
}

; === ЗАГРУЗКА ИСТОРИИ ===
LoadHistory() {
    global historyList
    historyList := []

    if FileExist(HISTORY_FILE) {
        content := FileRead(HISTORY_FILE)
        Loop Parse, content, "`n", "`r" {
            if (A_LoopField != "" && DirExist(A_LoopField)) {
                historyList.Push(A_LoopField)
            }
        }
    }
}

; === СОХРАНЕНИЕ ИСТОРИИ ===
SaveHistory(newFolder) {
    global historyList, MAX_HISTORY

    ; Удаляем папку из списка, если она уже есть
    for index, folder in historyList {
        if (folder = newFolder) {
            historyList.RemoveAt(index)
            break
        }
    }

    ; Добавляем папку в начало списка
    historyList.InsertAt(1, newFolder)

    ; Ограничиваем размер истории
    while (historyList.Length > MAX_HISTORY) {
        historyList.Pop()
    }

    ; Сохраняем в файл
    content := ""
    for folder in historyList {
        content .= folder "`n"
    }

    try {
        FileDelete(HISTORY_FILE)
    }
    FileAppend(content, HISTORY_FILE)
}

; === GUI ДЛЯ ВЫБОРА ПАПКИ ===
ShowFolderSelectionGUI() {
    global selectedFolder, historyList

    myGui := Gui("", "Запуск Claude Code")
    myGui.SetFont("s10")

    ; Текст
    myGui.Add("Text", "x10 y10 w400", "Выберите папку для запуска Claude Code:")

    ; ComboBox с историей
    folderCombo := myGui.Add("ComboBox", "x10 y35 w400 vFolderPath")
    if (historyList.Length > 0) {
        for folder in historyList {
            folderCombo.Add([folder])
        }
        folderCombo.Choose(1)
    }

    ; Кнопка "Обзор"
    browseBtn := myGui.Add("Button", "x420 y35 w80 h23", "Обзор...")
    browseBtn.OnEvent("Click", (*) => BrowseFolder(myGui, folderCombo))

    ; Текстовое поле для статуса
    statusText := myGui.Add("Text", "x10 y70 w490 h20 +Center", "")
    statusText.SetFont("s9 bold")

    ; Кнопки Запустить и Отмена
    launchBtn := myGui.Add("Button", "x320 y100 w80 h30 Default", "Запустить")
    launchBtn.OnEvent("Click", (*) => OnLaunchClick(myGui, folderCombo, launchBtn, cancelBtn, statusText))

    cancelBtn := myGui.Add("Button", "x410 y100 w80 h30", "Закрыть")
    cancelBtn.OnEvent("Click", (*) => ExitApp())

    myGui.OnEvent("Close", (*) => ExitApp())
    myGui.Show("w510 h145")
}

; === ОБРАБОТЧИК КНОПКИ "ОБЗОР" ===
BrowseFolder(guiObj, folderCombo) {
    startPath := (folderCombo.Text != "" ? folderCombo.Text : "")
    selectedPath := DirSelect("*" startPath, 3, "Выберите папку для Claude Code")
    if (selectedPath != "") {
        folderCombo.Text := selectedPath
    }
}

; === ОБРАБОТЧИК КНОПКИ "ЗАПУСТИТЬ" ===
OnLaunchClick(guiObj, folderCombo, launchBtn, cancelBtn, statusText) {
    global selectedFolder

    selectedFolder := folderCombo.Text

    if (selectedFolder = "") {
        MsgBox("Пожалуйста, выберите папку!", "Ошибка", "Icon!")
        return
    }

    if (!DirExist(selectedFolder)) {
        MsgBox("Выбранная папка не существует!", "Ошибка", "Icon!")
        return
    }

    ; Сохраняем в историю
    SaveHistory(selectedFolder)

    ; Отключаем только кнопку Запустить во время выполнения
    launchBtn.Enabled := false

    ; Запускаем процесс с передачей statusText и кнопок
    LaunchProcess(statusText, guiObj, launchBtn, cancelBtn)
}

; === ЗАПУСК ПРОЦЕССА ===
LaunchProcess(statusText, guiObj, launchBtn, cancelBtn) {
    global selectedFolder, TIMEOUT_SECONDS

    ; Проверяем, не запущен ли уже Omniroute
    statusText.Value := "Проверка Omniroute..."
    statusText.SetFont("cBlue")

    if (IsOmnirouteRunning()) {
        statusText.Value := "Omniroute уже запущен"
        statusText.SetFont("cGreen")
        Sleep(500)
        LaunchClaudeCode(statusText, guiObj, cancelBtn, launchBtn)
        return
    }

    ; Запускаем Omniroute
    statusText.Value := "Запуск Omniroute..."
    statusText.SetFont("cBlue")

    try {
        Run("powershell.exe -NoExit -Command omniroute", , , &omniPID)
    } catch as err {
        statusText.Value := "Ошибка запуска Omniroute!"
        statusText.SetFont("cRed")
        MsgBox("Ошибка запуска Omniroute: " err.Message, "Ошибка", "Icon!")
        launchBtn.Enabled := true
        return
    }

    ; Ждём появления строки в окне PowerShell
    startTime := A_TickCount
    found := false

    Loop {
        ; Проверяем таймаут
        if ((A_TickCount - startTime) > (TIMEOUT_SECONDS * 1000)) {
            statusText.Value := "Таймаут ожидания Omniroute!"
            statusText.SetFont("cRed")
            MsgBox("Таймаут ожидания запуска Omniroute (" TIMEOUT_SECONDS " сек).`nПроверьте, что Omniroute установлен и работает корректно.", "Ошибка", "Icon!")
            launchBtn.Enabled := true
            return
        }

        ; Используем функцию IsOmnirouteRunning для проверки
        if (IsOmnirouteRunning()) {
            found := true
            break
        }

        Sleep(500)  ; Проверяем каждые 500 мс
    }

    if (found) {
        statusText.Value := "Omniroute запущен успешно"
        statusText.SetFont("cGreen")

        ; Небольшая пауза для стабильности
        Sleep(1000)

        ; Запускаем Claude Code
        LaunchClaudeCode(statusText, guiObj, cancelBtn, launchBtn)
    }
}

; === ПРОВЕРКА, ЗАПУЩЕН ЛИ OMNIROUTE ===
IsOmnirouteRunning() {
    ; Метод 1: Реальная проверка доступности сервера через HTTP-запрос
    /* try {
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.SetTimeouts(1000, 1000, 2000, 2000)  ; Короткие таймауты
        http.Open("GET", "http://localhost:20128/health", false)
        http.Send()

        ; Если получили ответ (любой код), сервер работает
        if (http.Status >= 200 && http.Status < 600) {
            return true
        }
    } catch {
        ; Если запрос не прошёл, пробуем другие методы
    } */

    ; Метод 2: Проверяем процессы node.exe на наличие omniroute в командной строке
    try {
        result := ComObjGet("winmgmts:").ExecQuery("SELECT CommandLine FROM Win32_Process WHERE Name='node.exe'")
        for process in result {
            if (InStr(process.CommandLine, "omniroute")) {
                ; Нашли процесс, но HTTP не ответил - возможно, ещё запускается
                return true
            }
        }
    }

    return false
}

; === ЗАПУСК CLAUDE CODE ===
LaunchClaudeCode(statusText, guiObj, cancelBtn, launchBtn) {
    global selectedFolder

    statusText.Value := "Запуск Claude Code..."
    statusText.SetFont("cBlue")

    ; Запускаем cmd в выбранной папке и вводим команду cc
    try {
        Run('cmd.exe /k "cd /d "' selectedFolder '" && cc"')
        Sleep(1000)
        statusText.Value := "Готово!"
        statusText.SetFont("cGreen")

        ; Включаем кнопку Запустить обратно
        launchBtn.Enabled := true
    } catch as err {
        statusText.Value := "Ошибка запуска Claude Code!"
        statusText.SetFont("cRed")
        MsgBox("Ошибка запуска Claude Code: " err.Message, "Ошибка", "Icon!")
        launchBtn.Enabled := true
        return
    }
}
