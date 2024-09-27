package main

import "core:os"
// import "core:slice"
// import "core:path/filepath"

Explorer :: struct {
    items: [dynamic]ExplorerItem,
}

ExplorerItem :: struct {
    name: string,
    fullPath: string,
    isDir: bool,
    isOpen: bool,
    child: [dynamic]ExplorerItem,
}

//TODO: since some changes might happen in files structure, we should always load files and compare them with current loaded files!

showExplorer :: proc() {
    folderPath, ok := showOpenFileDialog(true)
    assert(ok)

    if windowData.explorer != nil {
        clearExplorer(windowData.explorer)
        windowData.explorer = nil
    }

    windowData.explorer = initExplorer(folderPath)

    windowData.editorPadding.left = 250 // TODO: looks awful!!!
    recalculateFileTabsContextRects()
}

initExplorer :: proc(root: string) -> ^Explorer {
    explorer := new(Explorer)

    populateExplorerSubItems(root, &explorer.items)

    return explorer
}

populateExplorerSubItems :: proc(root: string, explorerItems: ^[dynamic]ExplorerItem) {
    info, err := os.lstat(root, context.temp_allocator)
    assert(err == nil)
	defer os.file_info_delete(info, context.temp_allocator)

    dirHandler, dirHandlerErr := os.open(info.fullpath, os.O_RDONLY)
    assert(dirHandlerErr == nil)
	defer os.close(dirHandler)
	dirItems, _ := os.read_dir(dirHandler, -1, context.temp_allocator)

    // NOTE: First we populate directory items, then files items
    for item in dirItems {
        if !item.is_dir { continue }

        subItem := ExplorerItem{
            name = item.name,
            fullPath = item.fullpath,
            isDir = true,
        }
        
        // keep it if you want preload all nested folders
        //populateExplorerSubItems(item.fullpath, &subItem.child)

        append(explorerItems, subItem)
    }

    for item in dirItems {
        if item.is_dir { continue }

        subItem := ExplorerItem{
            name = item.name,
            fullPath = item.fullpath,
            isDir = false,
        }
        
        append(explorerItems, subItem)
    }
}

closeExplorer :: proc() {
    clearExplorer(windowData.explorer)
    windowData.explorer = nil
    
    windowData.editorPadding.left = 50
    recalculateFileTabsContextRects()    
}

clearExplorer :: proc(explorer: ^Explorer) {
    if explorer == nil { return }

    for &item in explorer.items {
        removeExplorerSubItems(&item, false)
    }
    delete(explorer.items)
    free(explorer)
}

removeExplorerSubItems :: proc(item: ^ExplorerItem, keepRootChildArray := true) {
    for &subItem in item.child {
        if subItem.isDir{
            removeExplorerSubItems(&subItem, false)
        }
    }

    if !keepRootChildArray {
        delete(item.child)
    } else {
        clear(&item.child)
    }
}