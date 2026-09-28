; linux-hotkeys.ahk: GNOME-style workspace keys from olympus-terminal/linux_desktop_customization
; (configs/gnome-keybindings.dconf), plus Mac-style screenshots and a Ctrl+Space terminal.
; Requires AutoHotkey v2 and VirtualDesktopAccessor.dll (Ciantic) in this folder.
#Requires AutoHotkey v2.0
#SingleInstance Force

NUM_DESKTOPS := 10   ; Ctrl+1..9, Ctrl+0 (GNOME config: dynamic-workspaces=false)

; ---------------------------------------------------------------- VirtualDesktopAccessor
hVDA := DllCall("LoadLibrary", "Str", A_ScriptDir "\VirtualDesktopAccessor.dll", "Ptr")
if !hVDA {
    MsgBox "Could not load VirtualDesktopAccessor.dll from " A_ScriptDir
    ExitApp
}
VDA(name) => DllCall("GetProcAddress", "Ptr", hVDA, "AStr", name, "Ptr")
pGetCount   := VDA("GetDesktopCount")
pGetCurrent := VDA("GetCurrentDesktopNumber")
pGoTo       := VDA("GoToDesktopNumber")
pMoveWin    := VDA("MoveWindowToDesktopNumber")
pCreate     := VDA("CreateDesktop")

DesktopCount()   => DllCall(pGetCount, "Int")
CurrentDesktop() => DllCall(pGetCurrent, "Int")

; Fixed number of workspaces, like GNOME with dynamic workspaces off
while DesktopCount() < NUM_DESKTOPS && pCreate
    DllCall(pCreate, "Int")

GoToDesktop(n, *) {
    if n < 0 || n >= DesktopCount()
        return
    DllCall(pGoTo, "Int", n)
}

MoveWindowToDesktop(n) {
    hwnd := WinExist("A")
    if !hwnd || n < 0 || n >= DesktopCount()
        return
    DllCall(pMoveWin, "Ptr", hwnd, "Int", n)
    DllCall(pGoTo, "Int", n)           ; follow the window, as GNOME does
    try WinActivate hwnd
}

; ---------------------------------------------------------------- workspaces
; switch-to-workspace-1..10 = Ctrl+1..Ctrl+0
Loop 9
    Hotkey "^" A_Index, GoToDesktop.Bind(A_Index - 1)
Hotkey "^0", GoToDesktop.Bind(9)

; switch-to-workspace-left/right = Shift+Ctrl+Left/Right
^+Left::  GoToDesktop(CurrentDesktop() - 1)
^+Right:: GoToDesktop(CurrentDesktop() + 1)

; move-to-workspace-left/right
#+PgUp::    MoveWindowToDesktop(CurrentDesktop() - 1)
#+PgDn::    MoveWindowToDesktop(CurrentDesktop() + 1)
#+!Left::   MoveWindowToDesktop(CurrentDesktop() - 1)
#+!Right::  MoveWindowToDesktop(CurrentDesktop() + 1)
^+!Left::   MoveWindowToDesktop(CurrentDesktop() - 1)
^+!Right::  MoveWindowToDesktop(CurrentDesktop() + 1)

; ---------------------------------------------------------------- window tiler (Super+T)
; Same cycle as gnome-window-tiler: full -> left half -> right half -> TL -> TR -> BL -> BR
TileStates := Map()

#t:: {
    hwnd := WinExist("A")
    if !hwnd
        return
    state := Mod(TileStates.Get(hwnd, 0) + 1, 7)
    TileStates[hwnd] := state
    if state = 0 {
        WinMaximize hwnd
        return
    }
    MonitorGetWorkArea(MonitorOfWindow(hwnd), &L, &T, &R, &B)
    w := (R - L) // 2, h := B - T, qh := h // 2
    rects := [
        [L,     T,      w, h ],   ; left half
        [L + w, T,      w, h ],   ; right half
        [L,     T,      w, qh],   ; top-left
        [L + w, T,      w, qh],   ; top-right
        [L,     T + qh, w, qh],   ; bottom-left
        [L + w, T + qh, w, qh],   ; bottom-right
    ]
    r := rects[state]
    if WinGetMinMax(hwnd) != 0
        WinRestore hwnd
    MoveVisible(hwnd, r[1], r[2], r[3], r[4])
}

MonitorOfWindow(hwnd) {
    WinGetPos &x, &y, &w, &h, hwnd
    cx := x + w // 2, cy := y + h // 2
    Loop MonitorGetCount() {
        MonitorGet A_Index, &L, &T, &R, &B
        if cx >= L && cx < R && cy >= T && cy < B
            return A_Index
    }
    return MonitorGetPrimary()
}

; Windows 10/11 windows have invisible resize borders; offset them so tiles sit edge to edge
MoveVisible(hwnd, x, y, w, h) {
    WinMove x, y, w, h, hwnd
    rect := Buffer(16)
    if DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 9, "Ptr", rect, "UInt", 16) != 0
        return
    WinGetPos &ox, &oy, &ow, &oh, hwnd
    dl := NumGet(rect, 0, "Int") - ox, dt := NumGet(rect, 4, "Int") - oy
    dr := (ox + ow) - NumGet(rect, 8, "Int"), db := (oy + oh) - NumGet(rect, 12, "Int")
    WinMove x - dl, y - dt, w + dl + dr, h + dt + db, hwnd
}

; ---------------------------------------------------------------- terminal (Ctrl+Space)
^Space:: Run "wt.exe"

; ---------------------------------------------------------------- screenshots (Mac-style, Ctrl for Cmd)
^+3:: Send "#{PrintScreen}"   ; full screen -> Pictures\Screenshots
^+4:: Send "#+s"              ; drag to select a region (copied + saved by Snipping Tool)
^+5:: Send "#+r"              ; screen recording
; from the GNOME config
^!4:: Send "#+s"              ; show-screenshot-ui
^!5:: Send "!{PrintScreen}"   ; screenshot-window -> clipboard
