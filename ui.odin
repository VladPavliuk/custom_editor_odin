package main

import "base:runtime"

import "core:os"
import "core:slice"
import "core:strings"
import "core:text/edit"
import "core:path/filepath"
import win32 "core:sys/windows"

uiId :: i64

UiActions :: bit_set[UiAction; u32]

UiAction :: enum u32 {
    SUBMIT,
    RIGHT_CLICK,
    HOT,
    ACTIVE,
    GOT_ACTIVE,
    LOST_ACTIVE,
    FOCUSED,
    GOT_FOCUS,
    LOST_FOCUS,
    MOUSE_ENTER,
    MOUSE_LEAVE,
    MOUSE_WHEEL_SCROLL,
}

CursorType :: enum {
    DEFAULT,
    VERTICAL_SIZE,
    HORIZONTAL_SIZE,
}

UiElement :: struct {
    id: uiId,
    parent: ^UiElement,
}

UiContext :: struct {
    zIndex: f32,

    elements: [dynamic]UiElement,
    parentElementsStack: [dynamic]^UiElement,

    isAnyPopupOpened: ^bool,

    hotId: uiId,
    prevHotId: uiId,
    hotIdChanged: bool,
    tmpHotId: uiId,

    activeId: uiId,
    
    prevFocusedId: uiId,
    focusedId: uiId,
    focusedIdChanged: bool,
    tmpFocusedId: uiId,

    textInputCtx: EditableTextContext,

    scrollableElements: [dynamic]map[uiId]struct{},
    
    parentPositionsStack: [dynamic]int2,

    activeAlert: ^UiAlert,

    setCursor: proc(CursorType),
}

// @(private="file")
pushElement :: proc(ctx: ^UiContext, id: uiId, isParent := false) {
    parent := len(ctx.parentElementsStack) == 0 ? nil : slice.last(ctx.parentElementsStack[:])

    element := UiElement{
        id = id,
        parent = parent,
    }
    append(&ctx.elements, element)

    if isParent {
        append(&ctx.parentElementsStack, &ctx.elements[len(ctx.elements) - 1])
    }
}

isSubElement :: proc(ctx: ^UiContext, parentId: uiId, childId: uiId) -> bool {
    if childId == 0 { return false }
    assert(parentId != 0)
    assert(childId != 0)
    childElement: ^UiElement

    for &element in ctx.elements {
        if element.id == childId {
            childElement = &element
            break
        }
    }

    // TODO: maybe, it's better to show some dev error
    if childElement == nil { return false }
    // assert(childElement != nil)

    for childElement.parent != nil {
        if childElement.parent.id == parentId { return true }
        childElement = childElement.parent
    }

    return false
}

getUiId :: proc(customIdentifier: i32, callerLocation: runtime.Source_Code_Location) -> i64 {
    return i64(customIdentifier + 1) * i64(callerLocation.line + 1) * i64(callerLocation.column) * i64(uintptr(raw_data(callerLocation.file_path)))
}

beginUi :: proc(using ctx: ^UiContext, initZIndex: f32) {
    zIndex = initZIndex
    tmpHotId = 0
    focusedId = tmpFocusedId

    // if clicked on empty element - lost any focus
    if .LEFT_WAS_DOWN in inputState.mouse && hotId == 0 {
        tmpFocusedId = 0
    }

    // ctx.elements = make([dynamic]UiElement)
}

endUi :: proc(using ctx: ^UiContext, frameDelta: f64) {
    updateAlertTimeout(ctx, frameDelta)
    if ctx.activeAlert != nil {
        renderActiveAlert(ctx)
    }

    hotIdChanged = false
    if tmpHotId != hotId {
        prevHotId = hotId
        hotIdChanged = true
    }

    hotId = tmpHotId

    focusedIdChanged = false
    if tmpFocusedId != focusedId {
        prevFocusedId = focusedId
        focusedIdChanged = true
    }

    clear(&ctx.elements)
    assert(len(ctx.parentElementsStack) == 0)
}

renderTopMenu :: proc() {
    // top menu background
    fileMenuHeight: i32 = 25
    renderRect(Rect{ 
        top = windowData.size.y / 2,
        bottom = windowData.size.y / 2 - fileMenuHeight,
        left = -windowData.size.x / 2,
        right = windowData.size.x / 2,
    }, windowData.uiContext.zIndex, DARKER_GRAY_COLOR)
    advanceUiZIndex(&windowData.uiContext)

    topItemPosition: int2 = { -windowData.size.x / 2, windowData.size.y / 2 - fileMenuHeight }

    { // File menu
        fileItems := []UiDropdownItem{
            { text = "New File", rightText = "Ctrl+N" },
            { text = "Open Folder" },
            { text = "Open...", rightText = "Ctrl+O" },
            { text = "Save", rightText = "Ctrl+S" },
            { text = "Save as..." },
            { isSeparator = true },
            { text = "Exit", rightText = "Alt+F4" },
        }

        @(static)
        isOpen: bool = false

        if actions, selected := renderDropdown(&windowData.uiContext, UiDropdown{
            text = "File",
            position = topItemPosition, size = { 60, fileMenuHeight },
            items = fileItems,
            bgColor = DARKER_GRAY_COLOR,
            selectedItemIndex = -1,
            maxItemShow = i32(len(fileItems)),
            isOpen = &isOpen,
            itemStyles = {
                size = { 250, 0 },
                padding = Rect{ top = 2, bottom = 3, left = 20, right = 10, },
            },
        }); .SUBMIT in actions {
            switch selected {
            case 0: addEmptyTab()
            case 1:
                folderPath, ok := showOpenFileDialog(true)
                if ok { showExplorer(strings.clone(folderPath)) }
            case 2: loadFileFromExplorerIntoNewTab()
            case 3: saveToOpenedFile(getActiveTab())            
            case 4: showSaveAsFileDialog(getActiveTab())
            case 6: tryCloseEditor()
            }
        }
        topItemPosition.x += 60
    }

    { // Edit
        // TODO: add disabling of items that do nothing at the moment
        editItems := []UiDropdownItem{
            { text = "Undo", rightText = "Ctrl+Z" },
            { text = "Redo", rightText = "Ctrl+Shift+Z" },
            { isSeparator = true },
            { text = "Cut", rightText = "Ctrl+X" },
            { text = "Copy", rightText = "Ctrl+C" },
            { text = "Paste", rightText = "Ctrl+V" },
            { isSeparator = true },
            { text = "Find in current file", rightText = "Ctrl+F" },
            { text = "Replace in current file", rightText = "Ctrl+H" },
            { isSeparator = true },
            { text = "Find in files", rightText = "Ctrl+Shift+F" },
            { text = "Replace in files", rightText = "Ctrl+Shift+H" },
        }

        @(static)
        isOpen: bool = false

        if actions, selected := renderDropdown(&windowData.uiContext, UiDropdown{
            text = "Edit",
            position = topItemPosition, size = { 60, fileMenuHeight },
            items = editItems,
            bgColor = DARKER_GRAY_COLOR,
            selectedItemIndex = -1,
            maxItemShow = i32(len(editItems)),
            isOpen = &isOpen,
            itemStyles = {
                size = { 300, 0 },
                padding = Rect{ top = 2, bottom = 3, left = 20, right = 10, },
            },
        }); .SUBMIT in actions {
            editorState := &getActiveTabContext().editorState
            switch selected {
            case 0: edit.perform_command(editorState, edit.Command.Undo)
            case 1: edit.perform_command(editorState, edit.Command.Redo)
            case 3: edit.perform_command(editorState, edit.Command.Cut)
            case 4:
                if edit.has_selection(editorState) {
                    edit.perform_command(editorState, edit.Command.Copy)
                }
            case 5: edit.perform_command(editorState, edit.Command.Paste)
            }
        }
        topItemPosition.x += 60
    }

    { // Settings menu
        @(static)
        showSettings := false
        if .SUBMIT in renderButton(&windowData.uiContext, UiTextButton{
            text = "Settings",
            position = topItemPosition, size = { 100, fileMenuHeight },
            bgColor = DARKER_GRAY_COLOR,
            noBorder = true,
        }) {
            showSettings = !showSettings
        }

        if showSettings {
            @(static)
            panelPosition: int2 = { -250, -100 } 

            @(static)
            panelSize: int2 = { 250, 300 }

            beginPanel(&windowData.uiContext, UiPanel{
                title = "Settings",
                position = &panelPosition,
                size = &panelSize,
                bgColor = GRAY_COLOR,
                borderColor = BLACK_COLOR,
                // hoverBgColor = THEME_COLOR_5,
            }, &showSettings)

            renderLabel(&windowData.uiContext, UiLabel{
                text = "Custom Font",
                position = { 0, 250 },
                color = WHITE_COLOR,
            })

            renderTextField(&windowData.uiContext, UiTextField{
                text = "YEAH",
                position = { 0, 220 },
                size = { 200, 30 },
                bgColor = LIGHT_GRAY_COLOR,
            })

            if .SUBMIT in renderButton(&windowData.uiContext, UiTextButton{
                text = "Load Font",
                position = { 0, 190 },
                size = { 100, 30 },
                bgColor = THEME_COLOR_1,
                disabled = strings.builder_len(windowData.uiContext.textInputCtx.text) == 0,
            }) {
                // try load font
                fontPath := strings.to_string(windowData.uiContext.textInputCtx.text)

                if os.exists(fontPath) {
                    directXState.textures[.FONT], windowData.font = loadFont(fontPath)
                } else {
                    pushAlert(&windowData.uiContext, UiAlert{
                        text = strings.clone("Specified file does not exist!"),
                        bgColor = RED_COLOR,
                    })
                }
            }
            
            @(static)
            checked := false
            if .SUBMIT in renderCheckbox(&windowData.uiContext, UiCheckbox{
                text = "word wrapping",
                checked = &windowData.wordWrapping,
                position = { 0, 40 },
                color = WHITE_COLOR,
                bgColor = GREEN_COLOR,
                hoverBgColor = BLACK_COLOR,
            }) {
                //TODO: looks a bit hacky
                if windowData.wordWrapping {
                    getActiveTabContext().leftOffset = 0
                }
                // jumpToCursor(&windowData.editorCtx)
            }

            //testingButtons()
            
            endPanel(&windowData.uiContext)
        }
        topItemPosition += 100
    }
}

renderFolderExplorer :: proc() {
    if windowData.explorer == nil { return }

    topOffset: i32 = 25 // TODO: make it configurable
    
    // @(static)
    // explorerWidth: i32 = 200 // TODO: make it configurable

    bgRect := Rect{
        top = windowData.size.y / 2 - topOffset,
        bottom = -windowData.size.y / 2,
        left = -windowData.size.x / 2,
        right = -windowData.size.x / 2 + windowData.explorerWidth,
    }
    bgRectSize := getRectSize(bgRect)

    renderRect(bgRect, windowData.uiContext.zIndex, GRAY_COLOR)
    advanceUiZIndex(&windowData.uiContext)

    // explorer header
    explorerButtonsWidth: i32 = 50 
    explorerHeaderHeight: i32 = 25
    
    headerPosition: int2 = { -windowData.size.x / 2, windowData.size.y / 2 - topOffset - explorerHeaderHeight }
    headerBgRect := toRect(headerPosition, { windowData.explorerWidth, explorerHeaderHeight })

    // header background
    putEmptyUiElement(&windowData.uiContext, headerBgRect)
    renderRect(headerBgRect, windowData.uiContext.zIndex, GRAY_COLOR)
    advanceUiZIndex(&windowData.uiContext)

    // explorer root folder name
    setClipRect(toRect(headerPosition, { windowData.explorerWidth - explorerButtonsWidth, explorerHeaderHeight }))
    renderLine(filepath.base(windowData.explorer.rootPath), &windowData.font, headerPosition, WHITE_COLOR, windowData.uiContext.zIndex, explorerHeaderHeight)
    advanceUiZIndex(&windowData.uiContext)
    resetClipRect()

    topOffset += explorerHeaderHeight

    @(static)
    topItemIndex: i32 = 0
    
    contentRect := Rect{
        top = windowData.size.y / 2 - topOffset,
        bottom = -windowData.size.y / 2,
        left = -windowData.size.x / 2,
        right = -windowData.size.x / 2 + windowData.explorerWidth,
    }
    contentRectSize := getRectSize(contentRect)

    itemVerticalPadding :: 4
    itemHeight := i32(windowData.font.lineHeight) + itemVerticalPadding 

    maxItemsOnScreen := contentRectSize.y / itemHeight

    // explorer action buttons
    // collapse button
    activeTab := getActiveTab()
    if .SUBMIT in renderButton(&windowData.uiContext, UiImageButton{
        position = { headerPosition.x + windowData.explorerWidth - explorerButtonsWidth, headerPosition.y },
        size = { explorerHeaderHeight, explorerHeaderHeight },
        texture = .COLLAPSE_FILES_ICON,
        texturePadding = 4,
        hoverBgColor = getDarkerColor(GRAY_COLOR),
    }) {
        collapseExplorer(windowData.explorer)
    }

    // jump to current file button
    if .SUBMIT in renderButton(&windowData.uiContext, UiImageButton{
        position = { headerPosition.x + windowData.explorerWidth - explorerButtonsWidth + explorerHeaderHeight, headerPosition.y },
        size = { explorerHeaderHeight, explorerHeaderHeight },
        texture = .JUMP_TO_CURRENT_FILE_ICON,
        texturePadding = 4,
        hoverBgColor = getDarkerColor(GRAY_COLOR),
    }) {
        if expandExplorerToFile(windowData.explorer, activeTab.filePath) {
            itemIndex := getIndexInFlatenItemsByFilePath(activeTab.filePath, &windowData.explorer.items)

            if itemIndex < topItemIndex {
                topItemIndex = itemIndex
            } else if itemIndex >= topItemIndex + maxItemsOnScreen {
                topItemIndex = itemIndex - maxItemsOnScreen + 1
            }
        }
    }

    position: int2 = {
        -windowData.size.x / 2,
        windowData.size.y / 2 - topOffset - i32(windowData.font.lineHeight),
    }

    beginScroll(&windowData.uiContext)

    openedItems := make([dynamic]^ExplorerItem)
    getOpenedItemsFlaten(&windowData.explorer.items, &openedItems)
    defer delete(openedItems)
    openedItemsCount := i32(len(openedItems))

    @(static)
    itemsLeftOffset: i32 = 0

    topItemIndex = min(topItemIndex, openedItemsCount - maxItemsOnScreen)
    topItemIndex = max(topItemIndex, 0)
    lastItemIndex := min(openedItemsCount, maxItemsOnScreen + topItemIndex)
    maxWidthItem: i32 = 0

    @(static)
    showFileContextMenu := false

    // TODO: it's possible to have a bug if selected got deleted externally
    @(static)
    itemContextMenuIndex: i32 = -1

    @(static)
    renameItemIndex: i32 = -1

    @(static)
    fileContextMenuPosition: int2 = {-1,-1}

    // TODO: used only for setting focus to just selected item's action (like rename). that looks awful!
    @(static)
    fileContextMenuJustOpened := false
    for itemIndex in topItemIndex..<lastItemIndex {
        item := openedItems[itemIndex]
        defer position.y -= itemHeight

        itemRect := Rect{ 
            top = position.y + itemHeight, 
            bottom = position.y,
            left = position.x,
            right = position.x + windowData.explorerWidth,
        }

        if renameItemIndex == itemIndex {
            if .ESC in inputState.wasPressedKeys {
                renameItemIndex = -1
                continue
            }
            
            textInputActions, textInputId := renderTextField(&windowData.uiContext, UiTextField{
                text = item.name,
                initSelection = { i32(len(filepath.short_stem(item.name))), 0 },
                position = position,
                size = { windowData.explorerWidth, itemHeight }
            })

            if fileContextMenuJustOpened {
                windowData.uiContext.tmpFocusedId = textInputId
                fileContextMenuJustOpened = false
            }

            if .ENTER in inputState.wasPressedKeys {
                windowData.uiContext.tmpFocusedId = 0
            }

            if .LOST_FOCUS in textInputActions {
                // if after rename the name is the same, do nothing
                newFileName := strings.to_string(windowData.uiContext.textInputCtx.text)

                if newFileName == item.name {
                    renameItemIndex = -1
                    continue
                }

                newFilePath := strings.builder_make(context.temp_allocator)

                strings.write_string(&newFilePath, filepath.dir(item.fullPath))
                strings.write_rune(&newFilePath, filepath.SEPARATOR)
                strings.write_string(&newFilePath, newFileName)

                if len(newFileName) == 0 {
                    fileContextMenuJustOpened = true

                    pushAlert(&windowData.uiContext, UiAlert{
                        text = strings.clone("Can't save empty file name!"),
                        timeout = 5.0,
                        bgColor = RED_COLOR,
                    })
                    continue
                }

                err := os.rename(item.fullPath, strings.to_string(newFilePath))

                if err != nil {
                    fileContextMenuJustOpened = true

                    pushAlert(&windowData.uiContext, UiAlert{
                        text = strings.clone(fmt.tprintf("Error: %s!", err)),
                        timeout = 5.0,
                        bgColor = RED_COLOR,
                    })
                    continue
                }
                
                // update into in tab
                tabIndex := getFileTabIndex(windowData.fileTabs[:], item.fullPath)
                fmt.println(tabIndex)
                if tabIndex != -1 {
                    tab := &windowData.fileTabs[tabIndex]

                    delete(tab.filePath)
                    delete(tab.name)

                    tab.filePath = strings.clone(strings.to_string(newFilePath))
                    tab.name = strings.clone(newFileName)
                }

                // update explorer
                validateExplorerItems(&windowData.explorer)

                renameItemIndex = -1
            }
            continue
        }

        itemActions := putEmptyUiElement(&windowData.uiContext, itemRect, customId = itemIndex)

        if item.fullPath == activeTab.filePath { // highlight selected file
            renderRect(itemRect, windowData.uiContext.zIndex, getDarkerColor(GRAY_COLOR))
            advanceUiZIndex(&windowData.uiContext)
        }

        if .FOCUSED in itemActions && .F2 in inputState.wasPressedKeys {
            renameItemIndex = itemIndex
            fileContextMenuJustOpened = true
        }

        if .HOT in itemActions {
            renderRect(itemRect, windowData.uiContext.zIndex, THEME_COLOR_1)
            advanceUiZIndex(&windowData.uiContext)
        }

        if .SUBMIT in itemActions {
            if item.isDir {
                item.isOpen = !item.isOpen

                if item.isOpen {
                    populateExplorerSubItems(item.fullPath, &item.child, item.level + 1)
                } else {
                    removeExplorerSubItems(item)
                }
            } else {
                loadFileIntoNewTab(item.fullPath)
            }
        }

        if .RIGHT_CLICK in itemActions {
            showFileContextMenu = true
            fileContextMenuPosition = screenToDirectXCoords(inputState.mousePosition)
            itemContextMenuIndex = itemIndex
        }

        setClipRect(itemRect)
        iconSize: i32 = 16
        icon: TextureType

        if item.isDir {
            icon = item.isOpen ? .ARROW_DOWN_ICON : .ARROW_RIGHT_ICON
        } else {
            icon = getIconByFilePath(item.fullPath)
        }

        leftOffset: i32 = itemsLeftOffset + item.level * 20
        itemWidth := iconSize + 5 + i32(getTextWidth(item.name, &windowData.font))
        if itemWidth > maxWidthItem { maxWidthItem = itemWidth } 
        
        renderImageRect(int2{ position.x + leftOffset, position.y + itemVerticalPadding / 2 }, int2{ iconSize, iconSize }, windowData.uiContext.zIndex, icon)
        renderLine(item.name, &windowData.font, { position.x + leftOffset + iconSize + 5, position.y + itemVerticalPadding / 2 }, WHITE_COLOR, windowData.uiContext.zIndex)
        resetClipRect()
    }
    advanceUiZIndex(&windowData.uiContext) // there's no need to update zIndex multiple times per explorer item, so we do it once

    verticalScrollSize: i32 = min(i32(f32(contentRectSize.y) * f32(maxItemsOnScreen) / f32(openedItemsCount)), contentRectSize.y)
    horizontalScrollSize: i32 = min(i32(f32(contentRectSize.x) * f32(contentRectSize.x) / f32(maxWidthItem)), contentRectSize.x)
    
    @(static)
    scrollVerticalOffset: i32 = 0

    @(static)
    scrollHorizontalOffset: i32 = 0
    verticalScrollActions, _ := endScroll(&windowData.uiContext, UiScroll{
        bgRect = Rect{
            top = contentRect.top,
            bottom = contentRect.bottom,
            right = contentRect.right,
            left = contentRect.right - 15,
        },
        offset = &scrollVerticalOffset,
        size = verticalScrollSize,
        color = setColorAlpha(DARKER_GRAY_COLOR, 0.6),
        hoverColor = setColorAlpha(DARK_GRAY_COLOR, 0.9),
    }, UiScroll{
        bgRect = Rect{
            top = contentRect.bottom + 15,
            bottom = contentRect.bottom,
            right = contentRect.right,
            left = contentRect.left,
        },
        offset = &scrollHorizontalOffset,
        size = horizontalScrollSize,
        color = setColorAlpha(DARKER_GRAY_COLOR, 0.6),
        hoverColor = setColorAlpha(DARK_GRAY_COLOR, 0.9),
    })

    if openedItemsCount > maxItemsOnScreen { // has vertical scrollbar
        if .MOUSE_WHEEL_SCROLL in verticalScrollActions || .ACTIVE in verticalScrollActions {
            topItemIndex = i32(f32(openedItemsCount - maxItemsOnScreen) * f32(scrollVerticalOffset) / f32(contentRectSize.y - verticalScrollSize))
        } else {
            scrollVerticalOffset = i32(f32(topItemIndex) * f32(contentRectSize.y - verticalScrollSize) / f32(openedItemsCount - maxItemsOnScreen))
        }
    }

    if maxWidthItem > contentRectSize.x { // has horizontal scrollbar
        itemsLeftOffset = -i32(f32(maxWidthItem - contentRectSize.x) * f32(scrollHorizontalOffset) / f32(contentRectSize.x - horizontalScrollSize))
    }

    // NOTE: it won't work if some code above will show for example a popup
    resizeDirection := putResizableRect(&windowData.uiContext, bgRect)

    #partial switch resizeDirection {
    case .RIGHT:
        windowData.explorerWidth = inputState.mousePosition.x
        windowData.editorPadding.left = windowData.explorerWidth + 50 // TODO: looks awful!!!
        recalculateFileTabsContextRects()
    }

    if beginPopup(&windowData.uiContext, UiPopup{
        position = fileContextMenuPosition, size = {100,75},
        bgColor = DARKER_GRAY_COLOR,
        isOpen = &showFileContextMenu,
        clipRect = Rect{
            top = windowData.size.y / 2 - 25, // TODO: remove hardcoded value
            bottom = -windowData.size.y / 2,
            right = windowData.size.x / 2,
            left = -windowData.size.x / 2,
        },
    }) {
        defer endPopup(&windowData.uiContext)

        if .SUBMIT in renderButton(&windowData.uiContext, UiTextButton{
            text = "New file",
            position = { 0, 50 },
            size = { 100, 25 },
            noBorder = true,
            hoverBgColor = THEME_COLOR_1,
        }) {
            item := openedItems[itemContextMenuIndex]
            showFileContextMenu = false

            newFilePath := strings.builder_make(context.temp_allocator)

            // NOTE: try to create "New File (n).txt" 
            newFileNumber := 0
            for {
                newFileName := "New File"

                strings.write_string(&newFilePath, item.isDir ? item.fullPath : filepath.dir(item.fullPath))
                strings.write_rune(&newFilePath, filepath.SEPARATOR)
                strings.write_string(&newFilePath, newFileName)
                if newFileNumber > 0 {
                    strings.write_string(&newFilePath, fmt.tprintf(" (%i)", newFileNumber))
                }
                strings.write_string(&newFilePath, ".txt")
    
                if !os.exists(strings.to_string(newFilePath)) {
                    break
                }
                newFileNumber += 1
                strings.builder_reset(&newFilePath)
            }                
            
            err := os.write_entire_file_or_err(strings.to_string(newFilePath), []byte{})
            assert(err == nil)

            loadFileIntoNewTab(strings.to_string(newFilePath))
            expandExplorerToFile(windowData.explorer, strings.to_string(newFilePath))
        }
        
        // if .SUBMIT in renderButton(&windowData.uiContext, UiTextButton{
        //     text = "New folder",
        //     position = { 0, 50 },
        //     size = { 100, 25 },
        //     noBorder = true,
        //     hoverBgColor = THEME_COLOR_1,
        // }) {
        //     item := openedItems[itemContextMenuIndex]
        //     showFileContextMenu = false
        // }

        if .SUBMIT in renderButton(&windowData.uiContext, UiTextButton{
            text = "Rename",
            position = { 0, 25 },
            size = { 100, 25 },
            noBorder = true,
            hoverBgColor = THEME_COLOR_1,
        }) {
            renameItemIndex = itemContextMenuIndex
            showFileContextMenu = false
            fileContextMenuJustOpened = true
        }

        if .SUBMIT in renderButton(&windowData.uiContext, UiTextButton{
            text = "Delete",
            position = { 0, 0 },
            size = { 100, 25 },
            noBorder = true,
            hoverBgColor = THEME_COLOR_1,
        }) {
            item := openedItems[itemContextMenuIndex]

            // TODO: add switching to tab, if file is about to be deleted (now the ui thread is blocked by win message)
            // tabIndex := getFileTabIndex(windowData.fileTabs[:], item.fullPath)

            // if tabIndex != -1 {
            //     windowData.activeFileTab = tabIndex
            // }

            #partial switch showOsConfirmMessage("Edi the editor", fmt.tprintf("Do you really want to delete: \"%s\"?", item.name)) {
            case .YES:
                tabIndex := getFileTabIndex(windowData.fileTabs[:], item.fullPath)

                if tabIndex != -1 {
                    tryCloseFileTab(tabIndex, true)
                }

                err := os.remove(item.fullPath)

                if err != nil {
                    pushAlert(&windowData.uiContext, UiAlert{
                        text = strings.clone(fmt.tprintf("Couldn't delete: \"%s\"!", item.name)),
                        timeout = 5.0,
                        bgColor = RED_COLOR,
                    })
                    break
                }

                pushAlert(&windowData.uiContext, UiAlert{
                    text = strings.clone(fmt.tprintf("File: \"%s\" deleted!", item.name)),
                    timeout = 5.0,
                    bgColor = GREEN_COLOR,
                })

                // update explorer
                validateExplorerItems(&windowData.explorer)
            }
            showFileContextMenu = false
        }
    }
}

renderEditorFileTabs :: proc() {
    tabsHeight: i32 = 25
    topOffset: i32 = 25 // TODO: calcualte it
    leftOffset: i32 = windowData.explorer == nil ? 0 : windowData.explorerWidth // TODO: make it configurable
    
    renderRect(toRect({ -windowData.size.x / 2 + leftOffset, windowData.size.y / 2 - topOffset - tabsHeight }, { windowData.size.x - leftOffset, tabsHeight }), 
        windowData.uiContext.zIndex, GRAY_COLOR)
    advanceUiZIndex(&windowData.uiContext)

    tabItems := make([dynamic]UiTabsItem)
    defer delete(tabItems)

    atLeastTwoTabsOpened := len(windowData.fileTabs) > 1
    for &fileTab in windowData.fileTabs {
        rightIcon: TextureType = .NONE
        
        if atLeastTwoTabsOpened { rightIcon = .CLOSE_ICON } // we always want to show at least one file tab, so remove close icon if only tab
        if !fileTab.isSaved { rightIcon = .CIRCLE }

        tab := UiTabsItem{
            text = fileTab.name,
            leftIcon = getIconByFilePath(fileTab.filePath),
            leftIconSize = { 16, 16 },
            rightIcon = rightIcon,
        }

        append(&tabItems, tab)
    }

    tabActions := renderTabs(&windowData.uiContext, UiTabs{
        position = { -windowData.size.x / 2 + leftOffset, windowData.size.y / 2 - topOffset - tabsHeight },
        activeTabIndex = &windowData.activeFileTab,
        items = tabItems[:],
        itemStyles = {
            padding = { top = 2, bottom = 2, left = 15, right = 30 },
            size = { 120, tabsHeight },
        },
        bgColor = GRAY_COLOR,
    })

    switch action in tabActions {
    case UiTabsSwitched:
        switchInputContextToEditor()
    case UiTabsActionClose:
        tryCloseFileTab(action.closedTabIndex)
    }
}

recalculateFileTabsContextRects :: proc() {
    for fileTab in windowData.fileTabs {
        fileTab.ctx.rect = Rect{
            top = windowData.size.y / 2 - windowData.editorPadding.top,
            bottom = -windowData.size.y / 2 + windowData.editorPadding.bottom,
            left = -windowData.size.x / 2 + windowData.editorPadding.left,
            right = windowData.size.x / 2 - windowData.editorPadding.right,
        }
    }
}

getIconByFilePath :: proc(filePath: string) -> TextureType {
    if len(filePath) == 0 { return .NONE }

    fileExtension := filepath.ext(filePath)

    switch fileExtension {
    case ".txt": return .TXT_FILE_ICON
    case ".c": return .C_FILE_ICON
    case ".cpp": return .C_PLUS_PLUS_FILE_ICON
    case ".cs": return .C_SHARP_FILE_ICON
    case ".js": return .JS_FILE_ICON
    }

    return .TXT_FILE_ICON // by default treat unknown types as txt files
}

// TODO: move it from here
renderEditorContent :: proc() {
    editorCtx := getActiveTabContext()
    maxLinesOnScreen := getEditorSize().y / i32(windowData.font.lineHeight)
    totalLines := i32(len(editorCtx.lines))

    editorRectSize := getRectSize(editorCtx.rect)

    @(static)
    verticalOffset: i32 = 0

    verticalScrollWidth := windowData.editorPadding.right
    verticalScrollSize := i32(f32(editorRectSize.y * maxLinesOnScreen) / f32(maxLinesOnScreen + (totalLines - 1)))

    @(static)
    horizontalOffset: i32 = 0

    horizontalScrollHeight := windowData.editorPadding.bottom
    horizontalScrollSize := editorRectSize.x

    hasHorizontalScroll := editorCtx.maxLineWidth > f32(editorRectSize.x)

    if hasHorizontalScroll {
        horizontalScrollSize = i32(f32(editorRectSize.x) * f32(editorRectSize.x) / editorCtx.maxLineWidth)
    }

    beginScroll(&windowData.uiContext)

    editorContentActions := putEmptyUiElement(&windowData.uiContext, editorCtx.rect)

    handleTextInputActions(editorCtx, editorContentActions)

    calculateLines(editorCtx)
    updateCusrorData(editorCtx)

    setClipRect(editorCtx.rect)
    glyphsCount, selectionsCount := fillTextBuffer(editorCtx, windowData.maxZIndex)
    
    renderText(glyphsCount, selectionsCount, WHITE_COLOR, TEXT_SELECTION_BG_COLOR)
    resetClipRect()

    verticalScrollActions, horizontalScrollActions := endScroll(&windowData.uiContext, UiScroll{
        bgRect = {
            top = editorCtx.rect.top,
            bottom = editorCtx.rect.bottom,
            left = editorCtx.rect.right,
            right = editorCtx.rect.right + verticalScrollWidth,
        },
        size = verticalScrollSize,
        offset = &verticalOffset,
        color = float4{ 0.7, 0.7, 0.7, 1.0 },
        hoverColor = float4{ 1.0, 1.0, 1.0, 1.0 },
        bgColor = float4{ 0.2, 0.2, 0.2, 1.0 },
    }, UiScroll{
        bgRect = {
            top = editorCtx.rect.bottom,
            bottom = editorCtx.rect.bottom - horizontalScrollHeight,
            left = editorCtx.rect.left,
            right = editorCtx.rect.right,
        },
        size = horizontalScrollSize,
        offset = &horizontalOffset,
        color = float4{ 0.7, 0.7, 0.7, 1.0 },
        hoverColor = float4{ 1.0, 1.0, 1.0, 1.0 },
        bgColor = float4{ 0.2, 0.2, 0.2, 1.0 },
    })

    if .MOUSE_WHEEL_SCROLL in verticalScrollActions {
         if inputState.scrollDelta > 5 {
            editorCtx.lineIndex -= 1
        } else if inputState.scrollDelta < -5 {
            editorCtx.lineIndex += 1
        }

        validateTopLine(editorCtx)
    }

    if .ACTIVE in verticalScrollActions {
        editorCtx.lineIndex = i32(f32(totalLines) * (f32(verticalOffset) / f32(editorRectSize.y - verticalScrollSize)))

        // TODO: temporary fix, for some reasons it's possible to move vertical scroll bar below last line???
        editorCtx.lineIndex = min(i32(totalLines) - 1, editorCtx.lineIndex)
    } else {
        verticalOffset = i32(f32(editorCtx.lineIndex) / f32(maxLinesOnScreen + totalLines) * f32(editorRectSize.y))
    }

    if .ACTIVE in horizontalScrollActions {
        editorCtx.leftOffset = i32(editorCtx.maxLineWidth * f32(horizontalOffset) / f32(editorRectSize.x))
    } else {
        horizontalOffset = i32(f32(editorRectSize.x) * f32(editorCtx.leftOffset) / editorCtx.maxLineWidth)
    }
}

putEmptyUiElement :: proc(ctx: ^UiContext, rect: Rect, ignoreFocusUpdate := false, customId: i32 = 0, loc := #caller_location) -> UiActions {
    uiId := getUiId(customId, loc)

    return checkUiState(ctx, uiId, rect, ignoreFocusUpdate)
}

advanceUiZIndex :: proc(uiContext: ^UiContext) {
    uiContext.zIndex -= 0.1
}

checkUiState :: proc(ctx: ^UiContext, uiId: uiId, rect: Rect, ignoreFocusUpdate := false) -> UiActions {
    if len(ctx.scrollableElements) > 0 {
        ctx.scrollableElements[len(ctx.scrollableElements) - 1][uiId] = {}
    }

    mousePosition := screenToDirectXCoords({ i32(inputState.mousePosition.x), i32(inputState.mousePosition.y) })

    action: UiActions = nil
    
    if ctx.activeId == uiId {
        if .LEFT_WAS_UP in inputState.mouse || .RIGHT_WAS_UP in inputState.mouse {
            if ctx.hotId == uiId {
                if .RIGHT_WAS_UP in inputState.mouse {
                    action += {.RIGHT_CLICK}
                } else {
                    action += {.SUBMIT}
                }
            }

            action += {.LOST_ACTIVE}
            ctx.activeId = {}
        } else {
            action += {.ACTIVE}
        }
    } else if ctx.hotId == uiId {
        if .LEFT_WAS_DOWN in inputState.mouse || .RIGHT_WAS_DOWN in inputState.mouse {
            ctx.activeId = uiId

            action += {.GOT_ACTIVE}

            if !ignoreFocusUpdate { ctx.tmpFocusedId = uiId }
        }
    }

    if ctx.focusedIdChanged && ctx.focusedId == uiId {
        action += {.GOT_FOCUS}
    } else if ctx.focusedIdChanged && ctx.prevFocusedId == uiId {
        action += {.LOST_FOCUS}
    }

    if ctx.hotIdChanged && ctx.hotId == uiId {
        action += {.MOUSE_ENTER}
    } else if ctx.hotIdChanged && ctx.prevHotId == uiId {
        action += {.MOUSE_LEAVE}
    }
    
    if ctx.hotId == uiId {
        action += {.HOT}

        if abs(inputState.scrollDelta) > 0 {
            action += {.MOUSE_WHEEL_SCROLL}
        }
    }

    if isInRect(rect, mousePosition) {
        ctx.tmpHotId = uiId
    }

    if ctx.focusedId == uiId {
        action += {.FOCUSED}
    }

    return action
}

getDarkerColor :: proc(color: float4) -> float4 {
    rgb := color.rgb * 0.8
    return { rgb.r, rgb.g, rgb.b, color.a }
}

getAbsolutePosition :: proc(uiContext: ^UiContext) -> int2 {
    absolutePosition := int2{ 0, 0 }

    for position in uiContext.parentPositionsStack {
        absolutePosition += position
    }

    return absolutePosition
}

clipRect :: proc(target, source: Rect) -> Rect {
    targetSize := getRectSize(target)
    sourceSize := getRectSize(source)

    // if source panel size is bigger then target panel size, do nothing 
    if sourceSize.x > targetSize.x || sourceSize.y > targetSize.y {
        return source
    }

    source := source

    // right side
    source.right = min(source.right, target.right)
    source.left = source.right - sourceSize.x

    // left side
    source.left = max(source.left, target.left)
    source.right = source.left + sourceSize.x

    // top side
    source.top = min(source.top, target.top)
    source.bottom = source.top - sourceSize.y

    // bottom side
    source.bottom = max(source.bottom, target.bottom)
    source.top = source.bottom + sourceSize.y

    return source
}

screenToDirectXCoords :: proc(coords: int2) -> int2 {
    return {
        coords.x - windowData.size.x / 2,
        -coords.y + windowData.size.y / 2,
    }
}

directXToScreenRect :: proc(rect: Rect) -> Rect {
    return Rect{
        top = windowData.size.y / 2 - rect.top, 
        bottom = windowData.size.y / 2 - rect.bottom, 
        left = rect.left + windowData.size.x / 2, 
        right = rect.right + windowData.size.x / 2, 
    }
}

directXToScreenToCoords :: proc(coords: int2) -> int2 {
    return {
        coords.x + windowData.size.x / 2,
        coords.y + windowData.size.x / 2,
    }
}
