package main

import "core:os"
import "core:strings"
import "core:text/edit"
import "core:path/filepath"
import "core:time"
import "core:slice"

import "ui"

renderTopMenu :: proc() {
    // top menu background
    fileMenuHeight: i32 = 25
    
    append(&windowData.uiContext.commands, ui.RectCommand{
        rect = ui.Rect{
            top = windowData.size.y / 2,
            bottom = windowData.size.y / 2 - fileMenuHeight,
            left = -windowData.size.x / 2,
            right = windowData.size.x / 2,
        },
        bgColor = DARKER_GRAY_COLOR,
    })

    topItemPosition: int2 = { -windowData.size.x / 2, windowData.size.y / 2 - fileMenuHeight }

    { // File menu
        fileItems := []ui.DropdownItem{
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

        if actions, selected := ui.renderDropdown(&windowData.uiContext, ui.Dropdown{
            text = "File",
            position = topItemPosition, size = { 60, fileMenuHeight },
            items = fileItems,
            bgColor = DARKER_GRAY_COLOR,
            selectedItemIndex = -1,
            maxItemShow = i32(len(fileItems)),
            isOpen = &isOpen,
            itemStyles = {
                size = { 250, 0 },
                padding = ui.Rect{ top = 2, bottom = 3, left = 20, right = 10, },
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
        editItems := []ui.DropdownItem{
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

        if actions, selected := ui.renderDropdown(&windowData.uiContext, ui.Dropdown{
            text = "Edit",
            position = topItemPosition, size = { 60, fileMenuHeight },
            items = editItems,
            bgColor = DARKER_GRAY_COLOR,
            selectedItemIndex = -1,
            maxItemShow = i32(len(editItems)),
            isOpen = &isOpen,
            itemStyles = {
                size = { 300, 0 },
                padding = ui.Rect{ top = 2, bottom = 3, left = 20, right = 10, },
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
        if .SUBMIT in ui.renderButton(&windowData.uiContext, ui.TextButton{
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

            ui.beginPanel(&windowData.uiContext, ui.Panel{
                title = "Settings",
                position = &panelPosition,
                size = &panelSize,
                bgColor = GRAY_COLOR,
                borderColor = BLACK_COLOR,
                // hoverBgColor = THEME_COLOR_5,
            }, &showSettings)

            ui.renderLabel(&windowData.uiContext, ui.Label{
                text = "Custom Font",
                position = { 0, 250 },
                color = WHITE_COLOR,
            })

            renderTextField(&windowData.uiContext, ui.TextField{
                text = "YEAH",
                position = { 0, 220 },
                size = { 200, 30 },
                bgColor = LIGHT_GRAY_COLOR,
            })

            if .SUBMIT in ui.renderButton(&windowData.uiContext, ui.TextButton{
                text = "Load Font",
                position = { 0, 190 },
                size = { 100, 30 },
                bgColor = THEME_COLOR_1,
                disabled = strings.builder_len(windowData.uiTextInputCtx.text) == 0,
            }) {
                // try load font
                fontPath := strings.to_string(windowData.uiTextInputCtx.text)

                if os.exists(fontPath) {
                    directXState.textures[.FONT], windowData.font = loadFont(fontPath)
                } else {
                    ui.pushAlert(&windowData.uiContext, ui.Alert{
                        text = strings.clone("Specified file does not exist!"),
                        bgColor = RED_COLOR,
                    })
                }
            }
            
            @(static)
            checked := false
            if .SUBMIT in ui.renderCheckbox(&windowData.uiContext, ui.Checkbox{
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
            
            ui.endPanel(&windowData.uiContext)
        }
        topItemPosition += 100
    }
}

renderFolderExplorer :: proc() {
    if windowData.explorer == nil { return }

    topOffset: i32 = 25 // TODO: make it configurable
    
    // @(static)
    // explorerWidth: i32 = 200 // TODO: make it configurable

    bgRect := ui.Rect{
        top = windowData.size.y / 2 - topOffset,
        bottom = -windowData.size.y / 2,
        left = -windowData.size.x / 2,
        right = -windowData.size.x / 2 + windowData.explorerWidth,
    }

    append(&windowData.uiContext.commands, ui.RectCommand{
        rect = bgRect,
        bgColor = GRAY_COLOR,
    })

    // explorer header
    explorerButtonsWidth: i32 = 50 
    explorerHeaderHeight: i32 = 25
    
    headerPosition: int2 = { -windowData.size.x / 2, windowData.size.y / 2 - topOffset - explorerHeaderHeight }
    headerBgRect := ui.toRect(headerPosition, { windowData.explorerWidth, explorerHeaderHeight })

    // header background
    ui.putEmptyElement(&windowData.uiContext, headerBgRect)
    
    append(&windowData.uiContext.commands, ui.RectCommand{
        rect = headerBgRect,
        bgColor = GRAY_COLOR,
    })

    // explorer root folder name
    append(&windowData.uiContext.commands, ui.ClipCommand{
        rect = ui.toRect(headerPosition, { windowData.explorerWidth - explorerButtonsWidth, explorerHeaderHeight }), 
    })
    append(&windowData.uiContext.commands, ui.TextCommand{
        text = filepath.base(windowData.explorer.rootPath), 
        position = headerPosition,
        color = WHITE_COLOR,
    })
    append(&windowData.uiContext.commands, ui.ResetClipCommand{})

    topOffset += explorerHeaderHeight

    @(static)
    topItemIndex: i32 = 0
    
    contentRect := ui.Rect{
        top = windowData.size.y / 2 - topOffset,
        bottom = -windowData.size.y / 2,
        left = -windowData.size.x / 2,
        right = -windowData.size.x / 2 + windowData.explorerWidth,
    }
    contentRectSize := ui.getRectSize(contentRect)

    itemVerticalPadding :: 4
    itemHeight := i32(windowData.font.lineHeight) + itemVerticalPadding 

    maxItemsOnScreen := contentRectSize.y / itemHeight

    // explorer action buttons
    // collapse button
    activeTab := getActiveTab()
    if .SUBMIT in ui.renderButton(&windowData.uiContext, ui.ImageButton{
        position = { headerPosition.x + windowData.explorerWidth - explorerButtonsWidth, headerPosition.y },
        size = { explorerHeaderHeight, explorerHeaderHeight },
        textureId = i32(TextureId.COLLAPSE_FILES_ICON),
        texturePadding = 4,
        hoverBgColor = ui.getDarkerColor(GRAY_COLOR),
    }) {
        collapseExplorer(windowData.explorer)
    }

    // jump to current file button
    if .SUBMIT in ui.renderButton(&windowData.uiContext, ui.ImageButton{
        position = { headerPosition.x + windowData.explorerWidth - explorerButtonsWidth + explorerHeaderHeight, headerPosition.y },
        size = { explorerHeaderHeight, explorerHeaderHeight },
        textureId = i32(TextureId.JUMP_TO_CURRENT_FILE_ICON),
        texturePadding = 4,
        hoverBgColor = ui.getDarkerColor(GRAY_COLOR),
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

    ui.beginScroll(&windowData.uiContext)

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

        itemRect := ui.Rect{ 
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
            
            textInputActions, textInputId := renderTextField(&windowData.uiContext, ui.TextField{
                text = item.name,
                initSelection = { i32(len(filepath.short_stem(item.name))), 0 },
                position = position,
                size = { windowData.explorerWidth, itemHeight },
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
                newFileName := strings.to_string(windowData.uiTextInputCtx.text)

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

                    ui.pushAlert(&windowData.uiContext, ui.Alert{
                        text = strings.clone("Can't save empty file name!"),
                        timeout = 5.0,
                        bgColor = RED_COLOR,
                    })
                    continue
                }

                err := os.rename(item.fullPath, strings.to_string(newFilePath))

                if err != nil {
                    fileContextMenuJustOpened = true

                    ui.pushAlert(&windowData.uiContext, ui.Alert{
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

        itemActions := ui.putEmptyElement(&windowData.uiContext, itemRect, customId = itemIndex)

        if item.fullPath == activeTab.filePath { // highlight selected file
            append(&windowData.uiContext.commands, ui.RectCommand{
                rect = itemRect,
                bgColor = ui.getDarkerColor(GRAY_COLOR),
            })
        }

        if .FOCUSED in itemActions && .F2 in inputState.wasPressedKeys {
            renameItemIndex = itemIndex
            fileContextMenuJustOpened = true
        }

        if .HOT in itemActions {    
            append(&windowData.uiContext.commands, ui.RectCommand{
                rect = itemRect,
                bgColor = THEME_COLOR_1,
            })
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
            fileContextMenuPosition = ui.screenToDirectXCoords(inputState.mousePosition, &windowData.uiContext)
            itemContextMenuIndex = itemIndex
        }
        
        append(&windowData.uiContext.commands, ui.ClipCommand{
            rect = itemRect,
        })

        iconSize: i32 = 16
        icon: TextureId

        if item.isDir {
            icon = item.isOpen ? .ARROW_DOWN_ICON : .ARROW_RIGHT_ICON
        } else {
            icon = getIconByFilePath(item.fullPath)
        }

        leftOffset: i32 = itemsLeftOffset + item.level * 20
        itemWidth := iconSize + 5 + i32(getTextWidth(item.name, &windowData.font))
        if itemWidth > maxWidthItem { maxWidthItem = itemWidth } 
        
        append(&windowData.uiContext.commands, ui.ImageCommand{
            rect = ui.toRect(int2{ position.x + leftOffset, position.y + itemVerticalPadding / 2 }, int2{ iconSize, iconSize }),
            textureId = i32(icon)
        })
        append(&windowData.uiContext.commands, ui.TextCommand{
            text = item.name, 
            position = { position.x + leftOffset + iconSize + 5, position.y + itemVerticalPadding / 2 },
            color = WHITE_COLOR,
        })
        append(&windowData.uiContext.commands, ui.ResetClipCommand{})
    }
    ui.advanceZIndex(&windowData.uiContext) // there's no need to update zIndex multiple times per explorer item, so we do it once

    verticalScrollSize: i32 = min(i32(f32(contentRectSize.y) * f32(maxItemsOnScreen) / f32(openedItemsCount)), contentRectSize.y)
    horizontalScrollSize: i32 = min(i32(f32(contentRectSize.x) * f32(contentRectSize.x) / f32(maxWidthItem)), contentRectSize.x)
    
    @(static)
    scrollVerticalOffset: i32 = 0

    @(static)
    scrollHorizontalOffset: i32 = 0
    verticalScrollActions, _ := ui.endScroll(&windowData.uiContext, ui.Scroll{
        bgRect = ui.Rect{
            top = contentRect.top,
            bottom = contentRect.bottom,
            right = contentRect.right,
            left = contentRect.right - 15,
        },
        offset = &scrollVerticalOffset,
        size = verticalScrollSize,
        color = ui.setColorAlpha(DARKER_GRAY_COLOR, 0.6),
        hoverColor = ui.setColorAlpha(DARK_GRAY_COLOR, 0.9),
    }, ui.Scroll{
        bgRect = ui.Rect{
            top = contentRect.bottom + 15,
            bottom = contentRect.bottom,
            right = contentRect.right,
            left = contentRect.left,
        },
        offset = &scrollHorizontalOffset,
        size = horizontalScrollSize,
        color = ui.setColorAlpha(DARKER_GRAY_COLOR, 0.6),
        hoverColor = ui.setColorAlpha(DARK_GRAY_COLOR, 0.9),
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
    resizeDirection := ui.putResizableRect(&windowData.uiContext, bgRect)

    #partial switch resizeDirection {
    case .RIGHT:
        windowData.explorerWidth = inputState.mousePosition.x
        windowData.editorPadding.left = windowData.explorerWidth + 50 // TODO: looks awful!!!
        recalculateFileTabsContextRects()
    }

    if ui.beginPopup(&windowData.uiContext, ui.Popup{
        position = fileContextMenuPosition, size = {100,75},
        bgColor = DARKER_GRAY_COLOR,
        isOpen = &showFileContextMenu,
        clipRect = ui.Rect{
            top = windowData.size.y / 2 - 25, // TODO: remove hardcoded value
            bottom = -windowData.size.y / 2,
            right = windowData.size.x / 2,
            left = -windowData.size.x / 2,
        },
    }) {
        defer ui.endPopup(&windowData.uiContext)

        if .SUBMIT in ui.renderButton(&windowData.uiContext, ui.TextButton{
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

        if .SUBMIT in ui.renderButton(&windowData.uiContext, ui.TextButton{
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

        if .SUBMIT in ui.renderButton(&windowData.uiContext, ui.TextButton{
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
                    ui.pushAlert(&windowData.uiContext, ui.Alert{
                        text = strings.clone(fmt.tprintf("Couldn't delete: \"%s\"!", item.name)),
                        timeout = 5.0,
                        bgColor = RED_COLOR,
                    })
                    break
                }

                ui.pushAlert(&windowData.uiContext, ui.Alert{
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
    
    append(&windowData.uiContext.commands, ui.RectCommand{
        rect = ui.toRect({ -windowData.size.x / 2 + leftOffset, windowData.size.y / 2 - topOffset - tabsHeight }, { windowData.size.x - leftOffset, tabsHeight }),
        bgColor = GRAY_COLOR,
    })

    tabItems := make([dynamic]ui.TabsItem)
    defer delete(tabItems)

    atLeastTwoTabsOpened := len(windowData.fileTabs) > 1
    for &fileTab in windowData.fileTabs {
        rightIcon: TextureId = .NONE
        
        if atLeastTwoTabsOpened { rightIcon = .CLOSE_ICON } // we always want to show at least one file tab, so remove close icon if only tab
        if !fileTab.isSaved { rightIcon = .CIRCLE }

        tab := ui.TabsItem{
            text = fileTab.name,
            leftIconId = i32(getIconByFilePath(fileTab.filePath)),
            leftIconSize = { 16, 16 },
            rightIconId = i32(rightIcon),
        }

        append(&tabItems, tab)
    }

    tabActions := ui.renderTabs(&windowData.uiContext, ui.Tabs{
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
    case ui.TabsSwitched:
        switchInputContextToEditor()
    case ui.TabsActionClose:
        tryCloseFileTab(action.closedTabIndex)
    }
}

recalculateFileTabsContextRects :: proc() {
    for fileTab in windowData.fileTabs {
        fileTab.ctx.rect = ui.Rect{
            top = windowData.size.y / 2 - windowData.editorPadding.top,
            bottom = -windowData.size.y / 2 + windowData.editorPadding.bottom,
            left = -windowData.size.x / 2 + windowData.editorPadding.left,
            right = windowData.size.x / 2 - windowData.editorPadding.right,
        }
    }
}

getIconByFilePath :: proc(filePath: string) -> TextureId {
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

    editorRectSize := ui.getRectSize(editorCtx.rect)

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

    ui.beginScroll(&windowData.uiContext)

    editorContentActions := ui.putEmptyElement(&windowData.uiContext, editorCtx.rect)

    handleTextInputActions(editorCtx, editorContentActions)

    calculateLines(editorCtx)
    updateCusrorData(editorCtx)

    setClipRect(editorCtx.rect)
    glyphsCount, selectionsCount := fillTextBuffer(editorCtx, windowData.maxZIndex)
    
    renderText(glyphsCount, selectionsCount, WHITE_COLOR, TEXT_SELECTION_BG_COLOR)
    resetClipRect()

    verticalScrollActions, horizontalScrollActions := ui.endScroll(&windowData.uiContext, ui.Scroll{
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
    }, ui.Scroll{
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

renderTextField :: proc(ctx: ^ui.Context, textField: ui.TextField, customId: i32 = 0, loc := #caller_location) -> (ui.Actions, ui.Id) {
    actions, id := ui.renderTextField(&windowData.uiContext, textField, customId, loc)

    // TODO: it's better to return rect from  renderTextField
    position := textField.position + ui.getAbsolutePosition(ctx)
    uiRect := ui.toRect(position, textField.size)

    textHeight := ctx.getTextHeight(ctx.font)
    
    if .GOT_FOCUS in actions {
        switchInputContextToUiElement(textField.text, ui.Rect{
            top = uiRect.top - textField.size.y / 2 + i32(textHeight / 2),
            bottom = uiRect.bottom + textField.size.y / 2 - i32(textHeight / 2),
            left = uiRect.left + 5,
            right = uiRect.right - 5,
        }, true)

        // pre-select text
        windowData.uiTextInputCtx.editorState.selection = { int(textField.initSelection[0]), int(textField.initSelection[1]) }
    } 

    if .LOST_FOCUS in actions {
        switchInputContextToEditor()
    }

    if .FOCUSED in actions {
        calculateLines(&windowData.uiTextInputCtx)
        updateCusrorData(&windowData.uiTextInputCtx)
    
        handleTextInputActions(&windowData.uiTextInputCtx, actions)
    }

    return actions, id
}

handleTextInputActions :: proc(ctx: ^EditableTextContext, actions: ui.Actions) {
    // NOTE: that looks kinda werid,
    // but I can't find any place where it might be used else where, so I just created a local var
    @(static)
    originalCurosorIndex: i32 = -1

    if .GOT_ACTIVE in actions {
        pos := getCursorIndexByMousePosition(ctx, inputState.mousePosition)
        ctx.editorState.selection = { pos, pos }

        originalCurosorIndex = i32(pos)
    }

    if .LOST_ACTIVE in actions {
        originalCurosorIndex = -1
    }

    if .ACTIVE in actions {
        if .LEFT_IS_DOWN_AFTER_DOUBLE_CLICKED in inputState.mouse {
            currentCursorIndex := getCursorIndexByMousePosition(ctx, inputState.mousePosition)

            selectWholeWord(ctx, i32(originalCurosorIndex))

            originalSelectedWordSelection := ctx.editorState.selection

            selectWholeWord(ctx, i32(currentCursorIndex))

            ctx.editorState.selection = {
                max(originalSelectedWordSelection[0], ctx.editorState.selection[0]),
                min(originalSelectedWordSelection[1], ctx.editorState.selection[1]),
            }

            // NOTE: If after words selection, user moves cursor moves before originally selected word, 
            // set cursor at the beginning of the whole selection.
            if currentCursorIndex < min(originalSelectedWordSelection[0], originalSelectedWordSelection[1]) {
                slice.reverse(ctx.editorState.selection[:])
            }
        } else {
            ctx.editorState.selection[0] = getCursorIndexByMousePosition(ctx, inputState.mousePosition)
        }
 
        mousePosition := ui.screenToDirectXCoords(inputState.mousePosition, &windowData.uiContext)

        if mousePosition.y > ctx.rect.top {
            ctx.lineIndex -= max(1, (mousePosition.y - ctx.rect.top) / 10)
            validateTopLine(ctx)
        } else if mousePosition.y < ctx.rect.bottom {
            ctx.lineIndex += max(1, (ctx.rect.bottom - mousePosition.y) / 10)
            validateTopLine(ctx)
        }
        
        if mousePosition.x > ctx.rect.right {
            ctx.leftOffset += max(5, (mousePosition.x - ctx.rect.right) / 5)
            validateLeftOffset(ctx)
        } else if mousePosition.x < ctx.rect.left {
            ctx.leftOffset -= max(5, (ctx.rect.left - mousePosition.x) / 5)
            validateLeftOffset(ctx)
        }
    }
}
