#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetTitleMatchMode 2
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
CoordMode "ToolTip", "Screen"

; ------------------------------------------------------------
; Пошаговый мастер с автоматическими и ручными шагами.
;
; Что заменить под себя:
; - файлы в папке assets\
; - TargetRect у ручных шагов, если хочешь автопоймать клик
; - при необходимости сами команды установки
;
; Примечание:
; - GUI написан под AHK v2
; - переменная gui не используется
; - без #NoEnv и без устаревшего синтаксиса
; - действия для ручных шагов снабжены плейсхолдерами
; ------------------------------------------------------------

global App := WizardApp()
App.Show()

~LButton::HandleGlobalLeftClick()

HandleGlobalLeftClick(*)
{
    global App
    if IsObject(App)
        App.HandleLeftClick()
}

OnWizardClose(*)
{
    ExitApp
}

OnWizardEscape(*)
{
    ExitApp
}

class WizardApp
{
    Steps := []
    StepIndex := 1
    TrackingEnabled := true
    LogBuffer := ""

    mainGui := 0
    headerText := 0
    progressText := 0
    stepTitleText := 0
    instructionText := 0
    statusText := 0
    previewPic := 0
    previewPlaceholderText := 0
    logEdit := 0
    btnBack := 0
    btnRun := 0
    btnNext := 0
    btnToggle := 0
    btnExit := 0

    __New()
    {
        DirCreate(A_ScriptDir . "\assets")
        this.Steps := BuildWizardSteps()
        this.BuildGui()
        this.RenderStep()
    }

    BuildGui()
    {
        this.mainGui := Gui("+Resize", "Пошаговый мастер установки")
        this.mainGui.SetFont("s10", "Segoe UI")
        this.mainGui.OnEvent("Close", OnWizardClose)
        this.mainGui.OnEvent("Escape", OnWizardEscape)

        this.headerText := this.mainGui.AddText("xm ym w920 h28", "")
        this.headerText.SetFont("s14 Bold")

        this.progressText := this.mainGui.AddText("xm y+8 w920 h20", "")
        this.stepTitleText := this.mainGui.AddText("xm y+10 w920 h26", "")
        this.stepTitleText.SetFont("s12 Bold")

        this.instructionText := this.mainGui.AddText("xm y+6 w920 h70", "")
        this.statusText := this.mainGui.AddText("xm y+6 w920 h22", "")

        this.previewPic := this.mainGui.AddPicture("xm y+10 w920 h420 Border", "")
        this.previewPlaceholderText := this.mainGui.AddText("xm yp w920 h420 Center 0x200 Border", "")
        this.previewPlaceholderText.Visible := false

        this.logEdit := this.mainGui.AddEdit("xm y+10 w920 h140 ReadOnly -Wrap")

        this.btnBack := this.mainGui.AddButton("xm y+10 w120", "Назад")
        this.btnRun := this.mainGui.AddButton("x+10 w150", "Выполнить шаг")
        this.btnNext := this.mainGui.AddButton("x+10 w120", "Далее")
        this.btnToggle := this.mainGui.AddButton("x+10 w190", "Отслеживание: вкл")
        this.btnExit := this.mainGui.AddButton("x+10 w100", "Выход")

        this.btnBack.OnEvent("Click", WizardBack)
        this.btnRun.OnEvent("Click", WizardRunCurrent)
        this.btnNext.OnEvent("Click", WizardNext)
        this.btnToggle.OnEvent("Click", WizardToggleTracking)
        this.btnExit.OnEvent("Click", WizardExit)
    }

    Show()
    {
        this.mainGui.Show("w980 h820")
    }

    CurrentStep()
    {
        return this.Steps[this.StepIndex]
    }

    RenderStep()
    {
        current := this.CurrentStep()

        this.headerText.Text := "Пошаговый мастер"
        this.progressText.Text := Format("Шаг {} из {}", this.StepIndex, this.Steps.Length)
        this.stepTitleText.Text := current.Title
        this.instructionText.Text := current.Instruction

        if (current.Mode = "auto")
        {
            this.statusText.Text := "Режим: автоматический шаг"
            this.btnRun.Enabled := true
            this.btnNext.Enabled := false
        }
        else
        {
            this.statusText.Text := "Режим: ручной шаг. Если заполнен TargetRect, нужный клик можно поймать автоматически."
            this.btnRun.Enabled := false
            this.btnNext.Enabled := true
        }

        this.btnBack.Enabled := (this.StepIndex > 1)
        this.btnNext.Text := (current.Mode = "auto") ? "Далее" : "Подтвердить шаг"
        this.btnToggle.Text := this.TrackingEnabled ? "Отслеживание: вкл" : "Отслеживание: выкл"

        this.ShowStepPreview(current)
        this.Log(Format("Открыт шаг {}: {}", this.StepIndex, current.Title))

        if (current.Mode = "auto")
            this.RunCurrentStep()
    }

    ShowStepPreview(step)
    {
        screenshotPath := step.Screenshot
        if (screenshotPath != "" && FileExist(screenshotPath))
        {
            try
            {
                this.previewPic.Value := LoadPicture(screenshotPath)
                this.previewPic.Visible := true
                this.previewPlaceholderText.Visible := false
                return
            }
            catch as e
            {
                this.Log("Не удалось загрузить скриншот: " . e.Message)
            }
        }

        placeholder := "СКРИНШОТ-ЗАГЛУШКА`n`nОжидаемый файл:`n" . step.Screenshot . "`n`nПоложи сюда PNG или JPG с этим экраном."
        this.previewPic.Visible := false
        this.previewPlaceholderText.Text := placeholder
        this.previewPlaceholderText.Visible := true
    }

    Log(message)
    {
        timestamp := FormatTime(A_Now, "HH:mm:ss")
        this.LogBuffer .= "[" . timestamp . "] " . message . "`r`n"
        this.logEdit.Value := this.LogBuffer
    }

    RunCurrentStep()
    {
        current := this.CurrentStep()
        if (current.Mode != "auto")
            return

        try
        {
            this.Log("Запускаю автоматический шаг: " . current.Title)

            if IsObject(current.Action)
            {
                result := current.Action.Call(this, current)
                if (result = false)
                {
                    this.Log("Шаг завершён без перехода дальше.")
                    return
                }
            }

            if (!this.IsLastStep())
                this.GoToStep(this.StepIndex + 1)
            else
                this.MarkFinished()
        }
        catch as e
        {
            this.Log("Ошибка: " . e.Message)
            MsgBox("Не удалось выполнить шаг:`n`n" . current.Title . "`n`n" . e.Message, "Ошибка", "Iconx")
        }
    }

    GoToStep(stepIndex)
    {
        if (stepIndex < 1)
            stepIndex := 1

        if (stepIndex > this.Steps.Length)
        {
            this.MarkFinished()
            return
        }

        this.StepIndex := stepIndex
        this.RenderStep()
    }

    NextManualStep()
    {
        if (this.IsLastStep())
        {
            this.MarkFinished()
            return
        }

        this.GoToStep(this.StepIndex + 1)
    }

    Back()
    {
        if (this.StepIndex > 1)
            this.GoToStep(this.StepIndex - 1)
    }

    RepeatCurrent()
    {
        current := this.CurrentStep()
        if (current.Mode = "auto")
            this.RunCurrentStep()
        else
            this.Log("Ручной шаг показан снова вместе со скриншотом.")
    }

    ToggleTracking()
    {
        this.TrackingEnabled := !this.TrackingEnabled
        this.btnToggle.Text := this.TrackingEnabled ? "Отслеживание: вкл" : "Отслеживание: выкл"
        this.Log(this.TrackingEnabled ? "Отслеживание кликов включено." : "Отслеживание кликов выключено.")
    }

    HandleLeftClick()
    {
        if (!this.TrackingEnabled)
            return

        current := this.CurrentStep()
        if (current.Mode != "manual")
            return

        MouseGetPos &x, &y, &winId, &ctrlHwnd
        this.statusText.Text := Format("Последний клик: x={}, y={}", x, y)

        rect := current.TargetRect
        if (!IsConfiguredRect(rect))
        {
            this.Log(Format("Клик записан: x={}, y={} (TargetRect не задан)", x, y))
            return
        }

        if (PointInRect(x, y, rect))
        {
            this.Log(Format("Нужный клик пойман: x={}, y={}", x, y))
            SoundBeep(1500, 80)
            this.NextManualStep()
        }
        else
        {
            this.Log(Format("Клик мимо цели: x={}, y={}. Ожидается область X{}..{}, Y{}..{}", x, y, rect.X1, rect.X2, rect.Y1, rect.Y2))
        }
    }

    MarkFinished()
    {
        this.statusText.Text := "Мастер завершён."
        this.headerText.Text := "Готово"
        this.stepTitleText.Text := "Все шаги пройдены"
        this.instructionText.Text := "Если нужно, можно сохранить этот шаблон и заменить плейсхолдеры на свои скриншоты и координаты."
        this.previewPic.Visible := false
        this.previewPlaceholderText.Visible := true
        this.previewPlaceholderText.Text := "Мастер завершён."
        this.btnBack.Enabled := false
        this.btnRun.Enabled := false
        this.btnNext.Enabled := false
        this.btnToggle.Enabled := false
        this.Log("Мастер завершён.")
    }

    IsLastStep()
    {
        return this.StepIndex >= this.Steps.Length
    }
}

BuildWizardSteps()
{
    steps := []

    steps.Push(Step(
        1,
        "Node.js — автоматическая установка",
        "Попытка установки Node.js через winget. Если winget отсутствует, скрипт скачает MSI и поставит его в тихом режиме.",
        "auto",
        Func("InstallNodeJs"),
        A_ScriptDir . "\assets\step01_node.png"
    ))

    steps.Push(Step(
        2,
        "Проверка Node.js",
        "Проверяем node --version. Если версия не видна сразу, иногда нужен новый терминал или перезапуск проводника/компьютера.",
        "auto",
        Func("VerifyNodeJs"),
        A_ScriptDir . "\assets\step02_node_version.png"
    ))

    steps.Push(Step(
        3,
        "OmniRoute — установка",
        "Ставим OmniRoute через npm.",
        "auto",
        Func("InstallOmniRoute"),
        A_ScriptDir . "\assets\step03_omniroute.png"
    ))

    steps.Push(Step(
        4,
        "OmniRoute — запуск дашборда",
        "Открываем omniroute. Дальше браузер и авторизация будут выполняться вручную.",
        "auto",
        Func("LaunchOmniRoute"),
        A_ScriptDir . "\assets\step04_omniroute_dashboard.png"
    ))

    steps.Push(Step(
        5,
        "OmniRoute — Providers → Kiro → Connect",
        "Вручную открой Providers, нажми Connect и выполни вход через Google. Скриншот-шаблон лежит в assets\\step05_kiro_connect.png. Заполни TargetRect, если хочешь, чтобы клик отслеживался автоматически.",
        "manual",
        "",
        A_ScriptDir . "\assets\step05_kiro_connect.png",
        MakeRect(0, 0, 0, 0)
    ))

    steps.Push(Step(
        6,
        "OmniRoute — API Keys → Create API Key",
        "Создай API Key и обязательно сохрани его. Ключ показывается один раз. Скриншот-шаблон лежит в assets\\step06_create_api_key.png.",
        "manual",
        "",
        A_ScriptDir . "\assets\step06_create_api_key.png",
        MakeRect(0, 0, 0, 0)
    ))

    steps.Push(Step(
        7,
        "Claude Code — установка",
        "Ставим Claude Code через npm.",
        "auto",
        Func("InstallClaudeCode"),
        A_ScriptDir . "\assets\step07_claude_code.png"
    ))

    steps.Push(Step(
        8,
        "CC.bat — создание файла запуска",
        "Создаём C:\\Scripts\\CC.bat с плейсхолдером ключа. Потом его нужно заменить на свой API Key.",
        "auto",
        Func("CreateCcBat"),
        A_ScriptDir . "\assets\step08_cc_bat.png"
    ))

    steps.Push(Step(
        9,
        "PATH — добавление C:\\Scripts",
        "Добавляем C:\\Scripts в пользовательский PATH.",
        "auto",
        Func("AddScriptsToPath"),
        A_ScriptDir . "\assets\step09_path.png"
    ))

    steps.Push(Step(
        10,
        "Финальный запуск CC",
        "Открой папку C:\\Scripts, вызови cmd в адресной строке и запусти CC. Если нужно, замени этот шаг на полностью автоматический запуск.",
        "manual",
        "",
        A_ScriptDir . "\assets\step10_launch_cc.png",
        MakeRect(0, 0, 0, 0)
    ))

    return steps
}

Step(index, title, instruction, mode, action := "", screenshot := "", targetRect := "", expectedImage := "", successText := "")
{
    return {
        Index: index,
        Title: title,
        Instruction: instruction,
        Mode: mode,
        Action: action,
        Screenshot: screenshot,
        TargetRect: targetRect,
        ExpectedImage: expectedImage,
        SuccessText: successText
    }
}

MakeRect(x1, y1, x2, y2)
{
    return {X1: x1, Y1: y1, X2: x2, Y2: y2}
}

IsConfiguredRect(rect)
{
    return IsObject(rect) && !(rect.X1 = 0 && rect.Y1 = 0 && rect.X2 = 0 && rect.Y2 = 0)
}

PointInRect(x, y, rect)
{
    return (x >= rect.X1 && x <= rect.X2 && y >= rect.Y1 && y <= rect.Y2)
}

WizardBack(*)
{
    global App
    App.Back()
}

WizardRunCurrent(*)
{
    global App
    App.RunCurrentStep()
}

WizardNext(*)
{
    global App
    current := App.CurrentStep()
    if (current.Mode = "auto")
        return
    App.NextManualStep()
}

WizardToggleTracking(*)
{
    global App
    App.ToggleTracking()
}

WizardExit(*)
{
    ExitApp
}

InstallNodeJs(app, step)
{
    app.Log("Проверяю, установлен ли Node.js...")

    result := ExecCapture('cmd.exe /c node --version')
    output := Trim(result.StdOut . result.StdErr)

    if (result.ExitCode = 0 && InStr(output, "v22.22.2"))
    {
        app.Log("Node.js уже установлен: " . output)
        return true
    }

    app.Log("Node.js не найден или версия отличается. Устанавливаю...")

    tempMsi := A_Temp . "\node-v22.22.2-x64.msi"
    if FileExist(tempMsi)
        try FileDelete tempMsi

    downloadCmd := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
        . '"Invoke-WebRequest -Uri ''https://nodejs.org/dist/v22.22.2/node-v22.22.2-x64.msi'' -OutFile ''' . tempMsi . '''"'

    exitCode := RunWait(downloadCmd, , "Hide")
    if (exitCode != 0)
        throw Error("Ошибка скачивания Node.js")

    installCmd := 'msiexec /i "' . tempMsi . '" /qn /norestart'
    exitCode := RunWait(installCmd, , "Hide")
    if (exitCode != 0)
        throw Error("Ошибка установки Node.js")

    app.Log("Node.js установлен")
    return true
}

VerifyNodeJs(app, step)
{
    result := ExecCapture('cmd.exe /c node --version')
    output := Trim(result.StdOut . result.StdErr)

    if (result.ExitCode = 0 && RegExMatch(output, '^v\d+'))
    {
        app.Log("Node.js найден: " . output)
        return true
    }

    app.Log("Проверка node --version не прошла: " . output)
    MsgBox("Node.js ещё не виден в текущей оболочке.`n`nПопробуй открыть новый терминал или перезагрузить компьютер, затем повтори шаг.", "Проверка Node.js", "Iconi")
    return false
}

InstallOmniRoute(app, step)
{
    app.Log("Проверяю OmniRoute...")

    result := ExecCapture('cmd.exe /c npm list -g omniroute')
    output := result.StdOut

    if InStr(output, "omniroute@")
    {
        app.Log("OmniRoute уже установлен")
        return true
    }

    app.Log("OmniRoute не найден. Устанавливаю...")

    exitCode := RunWait('cmd.exe /c npm install -g omniroute', , "Hide")
    if (exitCode != 0)
        throw Error("Ошибка установки OmniRoute")

    app.Log("OmniRoute установлен")
    return true
}

LaunchOmniRoute(app, step)
{
    app.Log("Запускаю omniroute...")
    Run('cmd.exe /c omniroute')
    app.Log("OmniRoute должен открыть дашборд в браузере.")
    return true
}

InstallClaudeCode(app, step)
{
    app.Log("Проверяю Claude Code...")

    result := ExecCapture('cmd.exe /c npm list -g @anthropic-ai/claude-code')
    output := result.StdOut

    if InStr(output, "@anthropic-ai/claude-code@")
    {
        app.Log("Claude Code уже установлен")
        return true
    }

    app.Log("Claude Code не найден. Устанавливаю...")

    exitCode := RunWait('cmd.exe /c npm install -g @anthropic-ai/claude-code', , "Hide")
    if (exitCode != 0)
        throw Error("Ошибка установки Claude Code")

    app.Log("Claude Code установлен")
    return true
}

CreateCcBat(app, step)
{
    scriptsDir := "C:\Scripts"
    DirCreate(scriptsDir)

    batPath := scriptsDir . "\CC.bat"
    batContent := "@echo off`r`n"
        . "set ANTHROPIC_BASE_URL=http://localhost:20128`r`n"
        . "set ANTHROPIC_API_KEY=ВСТАВЬ_СЮДА_СВОЙ_КЛЮЧ`r`n"
        . "claude %*`r`n"

    if FileExist(batPath)
    {
        try FileDelete(batPath)
    }

    FileAppend(batContent, batPath, "UTF-8")
    app.Log("Создан файл: " . batPath)
    return true
}

AddScriptsToPath(app, step)
{
    scriptsDir := "C:\Scripts"
    currentPath := ""
    try currentPath := RegRead("HKCU\Environment", "Path")

    if InStr(";" . currentPath . ";", ";" . scriptsDir . ";")
    {
        app.Log("C:\Scripts уже есть в пользовательском PATH.")
        EnvSet("Path", currentPath)
        return true
    }

    newPath := currentPath
    if (newPath != "")
        newPath .= ";"
    newPath .= scriptsDir

    RegWrite(newPath, "REG_EXPAND_SZ", "HKCU\Environment", "Path")
    EnvSet("Path", newPath)
    app.Log("C:\Scripts добавлен в пользовательский PATH.")
    MsgBox("Путь сохранён в пользовательском PATH.`n`nОткрой новый терминал, чтобы он увидел изменение.", "PATH", "Iconi")
    return true
}

HasWinget()
{
    try
    {
        return (RunWait('cmd.exe /c winget --version', , "Hide") = 0)
    }
    catch as e
    {
        return false
    }
}

ExecCapture(command)
{
    shell := ComObject("WScript.Shell")
    exec := shell.Exec(command)

    while (exec.Status = 0)
        Sleep(100)

    stdout := ""
    stderr := ""
    try stdout := exec.StdOut.ReadAll()
    try stderr := exec.StdErr.ReadAll()

    return {ExitCode: exec.ExitCode, StdOut: stdout, StdErr: stderr}
}
