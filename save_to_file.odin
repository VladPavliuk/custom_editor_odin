package main

import win32 "core:sys/windows"
import "core:strings"
import "core:unicode/utf8"
import "core:os"

saveToOpenedFile :: proc(windowData: ^WindowData) -> (success: bool) {
    if len(windowData.openedFilePath) > 0 {
        err := os.write_entire_file_or_err(windowData.openedFilePath, windowData.testInputString.buf[:])
        assert(err == nil)
    } else {
        showSaveAsFileDialog(windowData)
    }

    return true
}

showSaveAsFileDialog :: proc(windowData: ^WindowData) -> (success: bool) {
    hr := win32.CoInitializeEx(nil, win32.COINIT(0x2 | 0x4))
    assert(hr == 0)
    defer win32.CoUninitialize()

    pFileSave: ^win32.IFileSaveDialog
    hr = win32.CoCreateInstance(win32.CLSID_FileSaveDialog, nil, 
        win32.CLSCTX_INPROC_SERVER | win32.CLSCTX_INPROC_HANDLER | win32.CLSCTX_LOCAL_SERVER | win32.CLSCTX_REMOTE_SERVER, 
        win32.IID_IFileSaveDialog, 
        cast(^win32.LPVOID)(&pFileSave))
    assert(hr == 0)
    defer pFileSave->Release()
    
    // set file types
    fileTypes: []win32.COMDLG_FILTERSPEC = {
        // { win32.utf8_to_wstring("All Files"), win32.utf8_to_wstring("*") },
        { win32.utf8_to_wstring("Text file (*.txt)"), win32.utf8_to_wstring("*.txt") },
    }

    hr = pFileSave->SetFileTypes(u32(len(fileTypes)), raw_data(fileTypes[:]))
    assert(hr == 0)

    // set default file name
    defaultFileName := "New Text File.txt"
    
    text := strings.to_string(windowData.testInputString)

    defaultFileNameBuilder, ok := tryGetDefaultFileName(text)
    defer strings.builder_destroy(&defaultFileNameBuilder)

    if ok {
        defaultFileName = strings.to_string(defaultFileNameBuilder)
    }

    hr = pFileSave->SetFileName(win32.utf8_to_wstring(defaultFileName))
    assert(hr == 0)

    // set default path, if no recent
    IID_IShellItem := &win32.GUID{0x43826d1e, 0xe718, 0x42ee, {0xbc, 0x55, 0xa1, 0xe2, 0x61, 0xc3, 0x7b, 0xfe}}

    defaultPath := "C:\\"
    if os.is_dir(defaultPath) {
        defaultFolder: ^win32.IShellItem
        hr = SHCreateItemFromParsingName(win32.utf8_to_wstring(defaultPath), nil, IID_IShellItem, &defaultFolder)
        if hr == 0 {
            pFileSave->SetDefaultFolder(defaultFolder) 
            // pFileSave->SetFolder(defaultFolder) 
        }
        defaultFolder->Release()
    }

    // show window
    hr = pFileSave->Show(windowData.parentHwnd)
    if hr != 0 { return false }

    // get path
    shellItem: ^win32.IShellItem
    pFileSave->GetResult(&shellItem)
    defer shellItem->Release()

    filePathW: win32.LPWSTR
    shellItem->GetDisplayName(win32.SIGDN.FILESYSPATH, &filePathW)
    defer win32.CoTaskMemFree(filePathW)

    filePath, _ := win32.wstring_to_utf8(filePathW, -1)

    err := os.write_entire_file_or_err(filePath, windowData.testInputString.buf[:])
    assert(err == nil)

    windowData.openedFilePath = filePath

    return true
}

@(private="file")
tryGetDefaultFileName :: proc(text: string) -> (strings.Builder, bool)  {
    maxFileLength :: 10

    defaultFileNameBuilder := strings.builder_make()

    if len(text) == 0 {
        return defaultFileNameBuilder, false
    }

    invalidSymbols := "<>:\"/\\|?*" // invalid as a part of file name

    threshold := 100
    startIndex := -1

    // skip all whitespaces
    for symbol, i in text {
        if i > threshold {
            break
        }

        if !strings.is_space(symbol) {
            startIndex = i 
            break 
        }
    }

    if startIndex == -1 {
        return defaultFileNameBuilder, false
    }

    for symbol, i in text[startIndex:] {
        if i > threshold { break }

        if strings.builder_len(defaultFileNameBuilder) > maxFileLength { break }

        if symbol == '\n' { break }

        if !strings.contains_rune(invalidSymbols, symbol) {
            if strings.is_space(symbol) {
                strings.write_rune(&defaultFileNameBuilder, ' ')
            }  else {
                strings.write_rune(&defaultFileNameBuilder, symbol)
            }
        }
    }

    if strings.builder_len(defaultFileNameBuilder) == 0 {
        return defaultFileNameBuilder, false
    }

    // remove all whitespaces at the end
    hasWhitespaceAtEnd := true
    for hasWhitespaceAtEnd {           
        lastSymbol, width := utf8.decode_last_rune(defaultFileNameBuilder.buf[:])

        if width == utf8.RUNE_ERROR { break }

        hasWhitespaceAtEnd = strings.is_space(lastSymbol) 
        
        if hasWhitespaceAtEnd {
            strings.pop_rune(&defaultFileNameBuilder) 
        }
    }

    strings.write_string(&defaultFileNameBuilder, ".txt")

    return defaultFileNameBuilder, true
}
