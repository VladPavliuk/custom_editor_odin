package main

import "base:runtime"

import "core:os"
import "core:strings"
import "core:text/edit"
import "core:path/filepath"

uiId :: i64

UiActions :: bit_set[UiAction; u32]

UiAction :: enum u32 {
    SUBMIT,
    HOT,
    ACTIVE,
    GOT_ACTIVE,
    LOST_ACTIVE,
    GOT_FOCUS,
    LOST_FOCUS,
    MOUSE_ENTER,
    MOUSE_LEAVE,
    MOUSE_WHEEL_SCROLL,
}

getUiId :: proc(customIdentifier: i32, callerLocation: runtime.Source_Code_Location) -> i64 {
    return i64(customIdentifier + 1) * i64(callerLocation.line + 1) * i64(callerLocation.column) * i64(uintptr(raw_data(callerLocation.file_path)))
}

beginUi :: proc(using ctx: ^UiContext, initZIndex: f32) {
    zIndex = initZIndex
    tmpHotId = 0
    focusedId = tmpFocusedId

    // if clicked on empty element - lost any focus
    if inputState.wasLeftMouseButtonDown && hotId == 0 {
        tmpFocusedId = 0
    }
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
                if ok { showExplorer(folderPath) }
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
                text = strings.to_string(windowData.uiContext.textInputCtx.text),
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
                        text = "Specified file does not exist!",
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
    explorerWidth: i32 = 200 // TODO: make it configurable


    // explorer header
    explorerButtonsWidth: i32 = 50 
    explorerHeaderHeight: i32 = 25
    
    headerPosition: int2 = { -windowData.size.x / 2, windowData.size.y / 2 - topOffset - explorerHeaderHeight }
    headerBgRect := toRect(headerPosition, { explorerWidth, explorerHeaderHeight })

    // header background
    putEmptyUiElement(&windowData.uiContext, headerBgRect)
    renderRect(headerBgRect, windowData.uiContext.zIndex, GRAY_COLOR)
    advanceUiZIndex(&windowData.uiContext)

    // explorer root folder name
    setClipRect(toRect(headerPosition, { explorerWidth - explorerButtonsWidth, explorerHeaderHeight }))
    renderLine(filepath.base(windowData.explorer.rootPath), &windowData.font, headerPosition, WHITE_COLOR, windowData.uiContext.zIndex, explorerHeaderHeight)
    advanceUiZIndex(&windowData.uiContext)
    resetClipRect()

    topOffset += explorerHeaderHeight

    @(static)
    topItemIndex: i32 = 0
    
    bgRect := Rect{
        top = windowData.size.y / 2 - topOffset,
        bottom = -windowData.size.y / 2,
        left = -windowData.size.x / 2,
        right = -windowData.size.x / 2 + explorerWidth,
    }
    bgRectSize := getRectSize(bgRect)

    itemVerticalPadding :: 4
    itemHeight := i32(windowData.font.lineHeight) + itemVerticalPadding 

    maxItemsOnScreen := bgRectSize.y / itemHeight

    // explorer action buttons
    // collapse button
    activeTab := getActiveTab()
    if .SUBMIT in renderButton(&windowData.uiContext, UiImageButton{
        position = { headerPosition.x + explorerWidth - explorerButtonsWidth, headerPosition.y },
        size = { explorerHeaderHeight, explorerHeaderHeight },
        texture = .COLLAPSE_FILES_ICON,
        texturePadding = 4,
        hoverBgColor = getDarkerColor(GRAY_COLOR),
    }) {
        collapseExplorer(windowData.explorer)
    }

    // jump to current file button
    if .SUBMIT in renderButton(&windowData.uiContext, UiImageButton{
        position = { headerPosition.x + explorerWidth - explorerButtonsWidth + explorerHeaderHeight, headerPosition.y },
        size = { explorerHeaderHeight, explorerHeaderHeight },
        texture = .JUMP_TO_CURRENT_FILE_ICON,
        texturePadding = 4,
        hoverBgColor = getDarkerColor(GRAY_COLOR),
    }) {
        expandExplorerToFile(windowData.explorer, activeTab.filePath)
        itemIndex := getIndexInFlatenItemsByFilePath(activeTab.filePath, &windowData.explorer.items)

        if itemIndex < topItemIndex {
            topItemIndex = itemIndex
        } else if itemIndex >= topItemIndex + maxItemsOnScreen {
            topItemIndex = itemIndex - maxItemsOnScreen + 1
        }

    }

    renderRect(bgRect, windowData.uiContext.zIndex, GRAY_COLOR)
    advanceUiZIndex(&windowData.uiContext)

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

    for itemIndex in topItemIndex..<lastItemIndex {
        item := openedItems[itemIndex]

        itemRect := Rect{ 
            top = position.y + itemHeight, 
            bottom = position.y,
            left = position.x,
            right = position.x + explorerWidth,
        }

        itemActions := putEmptyUiElement(&windowData.uiContext, itemRect, customId = itemIndex)

        if item.fullPath == activeTab.filePath {
            renderRect(itemRect, windowData.uiContext.zIndex, getDarkerColor(GRAY_COLOR))
            advanceUiZIndex(&windowData.uiContext)
        }

        if .HOT in itemActions {
            renderRect(itemRect, windowData.uiContext.zIndex, THEME_COLOR_1)
            advanceUiZIndex(&windowData.uiContext)
        }

        if .GOT_ACTIVE in itemActions {
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
        position.y -= itemHeight
    }
    advanceUiZIndex(&windowData.uiContext) // there's no need to update zIndex multiple times per explorer item, so we do it once

    verticalScrollSize: i32 = min(i32(f32(bgRectSize.y) * f32(maxItemsOnScreen) / f32(openedItemsCount)), bgRectSize.y)
    horizontalScrollSize: i32 = min(i32(f32(bgRectSize.x) * f32(bgRectSize.x) / f32(maxWidthItem)), bgRectSize.x)
    
    @(static)
    scrollVerticalOffset: i32 = 0

    @(static)
    scrollHorizontalOffset: i32 = 0
    verticalScrollActions, _ := endScroll(&windowData.uiContext, UiScroll{
        bgRect = Rect{
            top = bgRect.top,
            bottom = bgRect.bottom,
            right = bgRect.right,
            left = bgRect.right - 15,
        },
        offset = &scrollVerticalOffset,
        size = verticalScrollSize,
        color = setColorAlpha(DARKER_GRAY_COLOR, 0.6),
        hoverColor = setColorAlpha(DARK_GRAY_COLOR, 0.9),
    }, UiScroll{
        bgRect = Rect{
            top = bgRect.bottom + 15,
            bottom = bgRect.bottom,
            right = bgRect.right,
            left = bgRect.left,
        },
        offset = &scrollHorizontalOffset,
        size = horizontalScrollSize,
        color = setColorAlpha(DARKER_GRAY_COLOR, 0.6),
        hoverColor = setColorAlpha(DARK_GRAY_COLOR, 0.9),
    })

    if openedItemsCount > maxItemsOnScreen { // has vertical scrollbar
        if .MOUSE_WHEEL_SCROLL in verticalScrollActions || .ACTIVE in verticalScrollActions {
            topItemIndex = i32(f32(openedItemsCount - maxItemsOnScreen) * f32(scrollVerticalOffset) / f32(bgRectSize.y - verticalScrollSize))
        } else {
            scrollVerticalOffset = i32(f32(topItemIndex) * f32(bgRectSize.y - verticalScrollSize) / f32(openedItemsCount - maxItemsOnScreen))
        }
    }

    if maxWidthItem > bgRectSize.x { // has horizontal scrollbar
        itemsLeftOffset = -i32(f32(maxWidthItem - bgRectSize.x) * f32(scrollHorizontalOffset) / f32(bgRectSize.x - horizontalScrollSize))
    }
}

renderEditorFileTabs :: proc() {
    tabsHeight: i32 = 25
    topOffset: i32 = 25 // TODO: calcualte it
    leftOffset: i32 = windowData.explorer == nil ? 0 : 200 // TODO: make it configurable
    
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

    return .TXT_FILE_ICON // dy default treat unknown types as txt files
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
        if inputState.wasLeftMouseButtonUp {
            if ctx.hotId == uiId {
                action += {.SUBMIT}
            }

            action += {.LOST_ACTIVE}
            ctx.activeId = {}
        } else {
            action += {.ACTIVE}
        }
    } else if ctx.hotId == uiId {
        if inputState.wasLeftMouseButtonDown {
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
