#Requires AutoHotkey v2+

F8::
{
    hwnd := WinExist("A")
    WinActivate(hwnd)

    A_Clipboard := ""

    Send "^+a"     ; Select All
    Sleep 50
    Send "^+c"     ; Copy

    ClipWait 2

    MsgBox A_Clipboard
}