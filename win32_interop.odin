package main

import win32 "core:sys/windows"

foreign import user32 "system:user32.lib"
foreign import shell32 "system:shell32.lib"

@(default_calling_convention = "std")
foreign user32 {
	@(link_name="CreateMenu") CreateMenu :: proc() -> win32.HMENU ---
	@(link_name="DrawMenuBar") DrawMenuBar :: proc(win32.HWND) ---
	@(link_name="IsClipboardFormatAvailable") IsClipboardFormatAvailable :: proc(uint) -> bool ---
	@(link_name="OpenClipboard") OpenClipboard :: proc(win32.HWND) -> bool ---
	@(link_name="EmptyClipboard") EmptyClipboard :: proc() -> bool ---
	@(link_name="SetClipboardData") SetClipboardData :: proc(uint, win32.HANDLE) -> win32.HANDLE ---
	@(link_name="GetClipboardData") GetClipboardData :: proc(uint) -> win32.HANDLE ---
	@(link_name="CloseClipboard") CloseClipboard :: proc() -> bool ---
    @(link_name="GlobalLock") GlobalLock :: proc(win32.HGLOBAL) -> win32.LPVOID ---
    @(link_name="GlobalUnlock") GlobalUnlock :: proc(win32.HGLOBAL) -> bool ---
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

IDM_FILE_NEW :: 1
IDM_FILE_OPEN :: 2
IDM_FILE_SAVE :: 3
IDM_FILE_SAVE_AS :: 4
IDM_FILE_QUIT :: 5

IDI_ICON :: 101 // copied from resources/resource.rc file
