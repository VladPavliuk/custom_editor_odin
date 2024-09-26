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
    return i64(customIdentifier + 1) * i64(callerLocation.line + 1) * i64(uintptr(raw_data(callerLocation.file_path)))
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

    fileItems := []UiDropdownItem{
        { text = "New File", rightText = "Ctrl+N" },
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
        case 0:
            addEmptyTab()
        case 1:
            loadFileFromExplorerIntoNewTab()
        case 2:
            saveToOpenedFile(getActiveTab())            
        case 3:
            showSaveAsFileDialog(getActiveTab())
        case 5:
            tryCloseEditor()
        }
    }
    topItemPosition.x += 60

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
}

renderEditorFileTabs :: proc() {
    tabsHeight: i32 = 25
    topOffset: i32 = 25 // TODO: calcualte it
    
    renderRect(toRect({ -windowData.size.x / 2, windowData.size.y / 2 - topOffset - tabsHeight }, { windowData.size.x, tabsHeight }), 
        windowData.uiContext.zIndex, GRAY_COLOR)
    advanceUiZIndex(&windowData.uiContext)

    tabItems := make([dynamic]UiTabsItem)
    defer delete(tabItems)

    for fileTab in windowData.fileTabs {
        tab := UiTabsItem{
            text = fileTab.name,
        }

        append(&tabItems, tab)
    }

    tabActions := renderTabs(&windowData.uiContext, UiTabs{
        position = { -windowData.size.x / 2, windowData.size.y / 2 - topOffset - tabsHeight },
        activeTabIndex = &windowData.activeFileTab,
        items = tabItems[:],
        itemStyles = {
            padding = { top = 2, bottom = 2, left = 15, right = 30 },
            size = { 120, tabsHeight },
        },
        bgColor = GRAY_COLOR,
        hasClose = len(tabItems) > 1, // we always want to show at least one file tab, so remove close icon if only tab
    })

    switch action in tabActions {
        case UiTabsSwitched:
            switchInputContextToEditor()
        case UiTabsActionClose:
            tryCloseFileTab(action.closedTabIndex)
    }

    //windowData.editorCtx = windowData.fileTabs[windowData.activeFileTab].ctx

    // if activeTab == 1 {
    //     testingButtons()
    // }
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
