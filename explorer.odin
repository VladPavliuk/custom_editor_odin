package main

import "core:os"
import "core:strings"
import "core:path/filepath"

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

@(private="file")
initExplorer :: proc(root: string) -> ^Explorer {
    explorer := new(Explorer)

    explorer.rootPath = root
    populateExplorerSubItems(explorer.rootPath, &explorer.items)

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
            name = strings.clone(item.name),
            fullPath = strings.clone(item.fullpath),
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
            name = strings.clone(item.name),
            fullPath = strings.clone(item.fullpath),
            isDir = false,
            level = level,
        }
        
        append(explorerItems, subItem)
    }
}

validateExplorerItems :: proc(explorer: ^Explorer) {

}

getOpenedItemsFlaten :: proc(itemsToIterate: ^[dynamic]ExplorerItem, flatenItems: ^[dynamic]^ExplorerItem) {
    for &item in itemsToIterate {
        append(flatenItems, &item)

        if item.isDir && item.isOpen {
            getOpenedItemsFlaten(&item.child, flatenItems)
        }
    }
}

collapseExplorer :: proc(explorer: ^Explorer) {
    for &item in explorer.items {
        if item.isDir {
            removeExplorerSubItems(&item)
            item.isOpen = false
        }
    }
}

expandExplorerToFile :: proc(explorer: ^Explorer, filePath: string) -> bool {
    fullElements := strings.split(filePath, "\\")
    defer delete(fullElements)

    isFileInExplorer := false
    rootFolderName := filepath.base(explorer.rootPath)
    elements: []string
    for item, index in fullElements {
        if rootFolderName == item {
            isFileInExplorer = true
            elements = fullElements[index + 1:len(fullElements) - 1]
            break
        }
    }

    if !isFileInExplorer { return false }

    if len(elements) == 0 { return false } // when the file is in root folder

    itemsToExpand := &explorer.items
    for item in elements {
        found := false
        for &explorerItem in itemsToExpand { // TODO: it's better to optimize it
            if item == explorerItem.name {
                found = true
                if !explorerItem.isOpen {
                    populateExplorerSubItems(explorerItem.fullPath, &explorerItem.child, explorerItem.level + 1)
                    explorerItem.isOpen = true
                }
                
                itemsToExpand = &explorerItem.child

                break
            }
        }

        if !found { return false }
    }

    return true
}

getIndexInFlatenItemsByFilePath :: proc(filePath: string, items: ^[dynamic]ExplorerItem) -> i32 {
    openedItems := make([dynamic]^ExplorerItem)
    defer delete(openedItems)

    getOpenedItemsFlaten(items, &openedItems)

    for item, index in openedItems {
        if item.fullPath == filePath {
            return i32(index)
        }
    }

    return -1
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
    delete(explorer.rootPath)
    delete(explorer.items)
    free(explorer)
}

removeExplorerSubItems :: proc(item: ^ExplorerItem, keepRootChildArray := true) {
    for &subItem in item.child {
        // if subItem.isDir{
            removeExplorerSubItems(&subItem, false)
        // }
    }

    if !keepRootChildArray {
        delete(item.name)
        delete(item.fullPath)
        delete(item.child)
    } else {
        clear(&item.child)
    }
}
