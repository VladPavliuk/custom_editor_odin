package main

import win32 "core:sys/windows"

foreign import user32 "system:user32.lib"
foreign import shell32 "system:shell32.lib"

@(default_calling_convention = "std")
foreign user32 {
	@(link_name="CreateMenu") CreateMenu :: proc() -> win32.HMENU ---
	@(link_name="DrawMenuBar") DrawMenuBar :: proc(win32.HWND) ---
    @(link_name="GlobalLock") GlobalLock :: proc(win32.HGLOBAL) -> win32.LPVOID ---
    @(link_name="GetMenuBarInfo") GetMenuBarInfo :: proc(win32.HWND, u64, win32.LONG, ^WIN32_MENUBARINFO) -> bool ---
}

@(default_calling_convention = "std")
foreign shell32 {
    SHCreateItemFromParsingName :: proc(win32.PCWSTR, ^win32.IBindCtx, win32.REFIID, rawptr) -> win32.HRESULT ---
}

WIN32_OBJID_MENU :: 0xFFFFFFFD

WIN32_MENUBARINFO :: struct #packed {
    cbSize: win32.DWORD,
    rcBar: win32.RECT,
    hMenu: win32.HMENU,
    hwndMenu: win32.HWND,
    fBarFocused: i32,
    fFocused: i32,
    fUnused: i32,
} 

get_WIN32_MENUBARINFO :: proc() -> WIN32_MENUBARINFO {
    return WIN32_MENUBARINFO{
        cbSize = size_of(WIN32_MENUBARINFO),
        fBarFocused = 1,
        fFocused = 1,
        fUnused = 30,
    }
}

WIN32_CF_TEXT :: 1
WIN32_CF_UNICODETEXT :: 13

IDI_ICON :: 101 // copied from resources/resource.rc file
