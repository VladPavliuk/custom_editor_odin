package main

import "core:os"

Explorer :: struct {
    rootPath: string,
    items: [dynamic]ExplorerItem,
}

ExplorerItem :: struct {
    name: string,
    fullPath: string,
    isDir: bool,
    isOpen: bool,
    level: i32, // how deep relative to root folder the item is
    child: [dynamic]ExplorerItem,
}

//TODO: since some changes might happen in files structure, we should always load files and compare them with current loaded files!

showExplorer :: proc(root: string) {
    if windowData.explorer != nil {
        clearExplorer(windowData.explorer)
        windowData.explorer = nil
    }

    windowData.explorer = initExplorer(root)

    windowData.editorPadding.left = 250 // TODO: looks awful!!!
    recalculateFileTabsContextRects()
}

initExplorer :: proc(root: string) -> ^Explorer {
    explorer := new(Explorer)

    explorer.rootPath = root
    populateExplorerSubItems(root, &explorer.items)

    return explorer
}

populateExplorerSubItems :: proc(root: string, explorerItems: ^[dynamic]ExplorerItem, level: i32 = 0) {
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
            level = level,
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
            level = level,
        }
        
        append(explorerItems, subItem)
    }
}

getOpenedItemsFlaten :: proc(itemsToIterate: ^[dynamic]ExplorerItem, flatenItems: ^[dynamic]^ExplorerItem) {
    for &item in itemsToIterate {
        append(flatenItems, &item)

        if item.isDir && item.isOpen {
            getOpenedItemsFlaten(&item.child, flatenItems)
        }
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
