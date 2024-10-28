package main

import "core:strings"
import "core:os"
import "core:path/filepath"
import "ui"

getActiveTab :: proc() -> ^FileTab {
    return &windowData.fileTabs[windowData.activeFileTab]
}

getActiveTabContext :: proc() -> ^EditableTextContext {
    return getActiveTab().ctx
}

isActiveTabContext :: proc() -> bool {
    return windowData.editableTextCtx == getActiveTab().ctx
}

addEmptyTab :: proc() {
    addTab(strings.clone("(empty)"))
}

addTab :: proc(title: string, filePath := "", text := "") {
    tab := FileTab{
        name = title,
        filePath = filePath,
        ctx = createEmptyTextContext(text),
        isSaved = true,
    }
    append(&windowData.fileTabs, tab)

    windowData.activeFileTab = i32(len(windowData.fileTabs) - 1) // switch to new tab
    windowData.wasFileTabChanged = true

    switchInputContextToEditor()
}

loadFileFromExplorerIntoNewTab :: proc() {
    filePath, ok := showOpenFileDialog()
    if !ok { return }

    loadFileIntoNewTab(filePath)
}

loadFileIntoNewTab :: proc(filePath: string) {
    fileText := loadTextFile(filePath)

    // find if any tab is already associated with opened file
    tabIndex: i32 = -1
    for tab, index in windowData.fileTabs {
        if tab.filePath == filePath {
            tabIndex = i32(index)
            break
        }
    }

    if tabIndex != -1 {
        windowData.activeFileTab = tabIndex
        windowData.wasFileTabChanged = true
        switchInputContextToEditor()
        return
    }

    activeTab := getActiveTab()

    if len(windowData.fileTabs) == 1 && 
        len(activeTab.filePath) == 0 && activeTab.isSaved {
        replaceTabInfoByIndex(FileTab{
            name = strings.clone(filepath.base(filePath)),
            ctx = createEmptyTextContext(fileText),
            filePath = strings.clone(filePath),
            isSaved = true,
        }, windowData.activeFileTab)
        return
    }

    addTab(strings.clone(filepath.base(filePath)), strings.clone(filePath), fileText)
}

getFileTabIndex :: proc(tabs: []FileTab, filePath: string) -> i32 {
    for tab, index in tabs {
        if tab.filePath == filePath {
            return i32(index)
        }
    }

    return -1
}

replaceTabInfoByIndex :: proc(tab: FileTab, index: i32) {
    oldTab := &windowData.fileTabs[index]
    
    freeTextContext(oldTab.ctx)
    delete(oldTab.name)
    delete(oldTab.filePath)

    oldTab.ctx = tab.ctx
    oldTab.filePath = tab.filePath
    oldTab.isSaved = tab.isSaved
    oldTab.name = tab.name

    switchInputContextToEditor()
}

moveToNextTab :: proc() {
    windowData.activeFileTab = (windowData.activeFileTab + 1) % i32(len(windowData.fileTabs))
    windowData.wasFileTabChanged = true
    switchInputContextToEditor()
}

moveToPrevTab :: proc() {
    windowData.activeFileTab = windowData.activeFileTab == 0 ? i32(len(windowData.fileTabs) - 1) : windowData.activeFileTab - 1
    windowData.wasFileTabChanged = true

    switchInputContextToEditor()
}

wasFileModifiedOutside :: proc(tab: ^FileTab) {
    // add validation
    switch showOsConfirmMessage("Edi the editor", "File was modified outside the editor, override the existing?") {
    case .YES:
        newText := loadTextFile(tab.filePath)

        freeTextContext(tab.ctx)
        tab.ctx = createEmptyTextContext(newText)

        switchInputContextToEditor()
    case .NO, .CANCEL, .CLOSE_WINDOW:
        tab.isSaved = false
        delete(tab.filePath)
        tab.filePath = ""        
    }
}

checkTabFileExistance :: proc(tab: ^FileTab) {
    if len(tab.filePath) > 0 && !os.exists(tab.filePath) {
        // if file does not exist anymore, just mark tab as unsafed and remove old file association

        ui.pushAlert(&windowData.uiContext, ui.Alert{
            text = strings.clone(fmt.tprintfln("%q was removed!", tab.name)),
            timeout = 5.0,
            bgColor = RED_COLOR,
        })

        tab.isSaved = false
        delete(tab.filePath)
        tab.filePath = ""
    }
}

tryCloseFileTab :: proc(index: i32, force := false) {
    tab := &windowData.fileTabs[index]

    // if there's any unsaved changes, show confirmation box
    if !tab.isSaved && !force {
        switch showOsConfirmMessage("Edi the editor", "Do you want to save the changes?") {
        case .YES: saveToOpenedFile(tab)
        case .NO:
        case .CANCEL, .CLOSE_WINDOW: return    
        }
    }

    freeTextContext(tab.ctx)
    delete(tab.name)
    delete(tab.filePath)
    
    ordered_remove(&windowData.fileTabs, index)
    windowData.activeFileTab = index == 0 ? index : index - 1
    windowData.wasFileTabChanged = true

    if len(windowData.fileTabs) == 0 {
        addEmptyTab()
    }

    switchInputContextToEditor()
}