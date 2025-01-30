package ui

TabsItem :: struct {
    text: string,
    isPinned: bool,
    leftIconId: i32,
    leftIconSize: [2]i32,
    rightIconId: i32,
}

TabsItemStyles :: struct {
    size: [2]i32,
    padding: Rect,
}

Tabs :: struct {
    position: [2]i32,
    width: int,
    activeTabIndex: ^int,
    jumpToActive: bool, // if true will jump to active tab if it's beyond rendering box
    items: []TabsItem,
    itemStyles: TabsItemStyles,
    leftSkipOffset: ^int,
    bgColor, hoverBgColor, activeColor: [4]f32,
}

TabsActionClose :: struct {
    itemIndex: int,
}

TabsHot :: struct {
    itemIndex: int,
}

TabsSwitched :: struct {
    itemIndex: int,
}

TabsSwapTabs :: struct {
    aIndex, bIndex: int,
}

TabsActions :: union {TabsSwitched, TabsHot, TabsActionClose, TabsSwapTabs}

renderTabs :: proc(ctx: ^Context, tabs: Tabs, customId: i32 = 0, loc := #caller_location) -> TabsActions {
    assert(tabs.width > 0)
    customId := customId
    tabsActions: TabsActions = nil

    // todo: it shouldn't be tabs.itemStyles.size.y
    tabsBgRect := toRect(tabs.position, int2{ i32(tabs.width), tabs.itemStyles.size.y })
    prevClipRect := ctx.clipRect
    setClipRect(ctx, tabsBgRect)

    position := tabs.position
    startPosition := position.x

    position.x -= i32(tabs.leftSkipOffset^)
    itemsIds := make(map[Id]struct{})
    defer delete(itemsIds)

    @(static)
    dragPosition := int2{ 0, 0 }

    @(static)
    dragFromTabIndex := -1

    @(static)
    isDragTabPinned := false

    if dragFromTabIndex != -1 { dragPosition = screenToDirectXCoords(ctx.mousePosition, ctx) }

    dragToTabIndex := -1

    for item, index in tabs.items {
        width := tabs.itemStyles.size.x

        if width == 0 { width = i32(ctx.getTextWidth(item.text, ctx.font)) }

        if position.x < startPosition {
            if tabs.jumpToActive && tabs.activeTabIndex^ == index { // if active tab is skiped on left side, adjust skip value so it's visible
                tabs.leftSkipOffset^ -= int(startPosition - position.x)
            }
            if position.x + width < startPosition {
                position.x += width
    
                continue
            }
        }

        // if active tab is beyond right tabs side, continue iteration until it's not shown
        if tabs.jumpToActive && tabs.activeTabIndex^ >= index && position.x + width > i32(tabs.width) + startPosition {
            tabs.leftSkipOffset^ += int(width)
            position.x += width
            continue
        }

        if position.x > i32(tabs.width) + startPosition { break }

        height := tabs.itemStyles.size.y
        if height == 0 { height = i32(ctx.getTextHeight(ctx.font)) }

        padding := tabs.itemStyles.padding

        itemRect := toRect(position, int2{ width, height })

        itemActions, itemId := putEmptyElement(ctx, itemRect, customId = customId, loc = loc)
        itemsIds[itemId] = {}

        bgColor := tabs.bgColor

        if tabs.activeTabIndex^ == index {
            bgColor = getDarkerColor(bgColor)
        } else {
            if .HOT in itemActions {
                bgColor = getOrDefaultColor(tabs.hoverBgColor, getDarkerColor(bgColor))
                if .ACTIVE in itemActions { bgColor = getOrDefaultColor(tabs.activeColor, getDarkerColor(bgColor)) }
            }
        }

        if dragFromTabIndex == index {
            bgColor = getOrDefaultColor(tabs.activeColor, getDarkerColor(bgColor))
        }

        if .HOT in itemActions { 
            tabsActions = TabsHot{ itemIndex = index }
        }

        if .SUBMIT in itemActions {
            tabsActions = TabsSwitched{ itemIndex = index }
            tabs.activeTabIndex^ = index
        }

        if .GOT_ACTIVE in itemActions && .LEFT_WAS_DOWN in ctx.mouse {
            isDragTabPinned = item.isPinned
            dragFromTabIndex = index
            dragPosition = screenToDirectXCoords(ctx.mousePosition, ctx)
        }

        if dragFromTabIndex != -1 && dragFromTabIndex != index && 
            item.isPinned == isDragTabPinned && // guerantee that pined tabs can be shuffled among other pined tabs and vise verse
            dragPosition.x > position.x && dragPosition.x < position.x + width {
                dragToTabIndex = index
        }
        
        pushCommand(ctx, RectCommand{
            rect = itemRect,
            bgColor = bgColor,
        })

        // icon
        iconWidth: i32 = 0
        iconRightPadding: i32 = 0
        if item.leftIconId != 0 {
            iconWidth = item.leftIconSize.x
            iconRightPadding = 3
            iconPosition: int2 = { position.x + padding.left, position.y + height / 2 - item.leftIconSize.y / 2 }
            
            pushCommand(ctx, ImageCommand{
                rect = toRect(iconPosition, int2{ item.leftIconSize.x, item.leftIconSize.y }),
                textureId = item.leftIconId,
            })
        }

        textPosition: int2 = { position.x + padding.left + iconWidth + iconRightPadding, position.y + padding.bottom }
        
        pushCommand(ctx, TextCommand{
            text = item.text,
            position = textPosition,
            color = WHITE_COLOR,
            maxWidth = itemRect.right - padding.right - textPosition.x,
        })

        // right icon
        if item.rightIconId != 0 {
            iconWidth = 20
            iconRightPadding = 3
            iconPosition: int2 = { position.x + width - iconWidth - iconRightPadding, position.y + height / 2 - iconWidth / 2 }
            
            customId += 1
            rightButtonActions, rightButtonId := renderButton(ctx, ImageButton{
                position = iconPosition,
                size = { iconWidth, iconWidth },
                textureId = item.rightIconId,
                texturePadding = 2,
                bgColor = bgColor,
                noBorder = true,
            }, customId, loc)

            if .SUBMIT in rightButtonActions {
                tabsActions = TabsActionClose{ itemIndex = index }
            }
            itemsIds[rightButtonId] = {}
        }

        customId += 1
        position.x += width
    }

    if dragToTabIndex != -1 {
        tabsActions = TabsSwapTabs{ aIndex = dragFromTabIndex, bIndex = dragToTabIndex }
        dragFromTabIndex = dragToTabIndex
    }

    if .LEFT_WAS_UP in ctx.mouse {
        isDragTabPinned = false
        dragPosition = { 0, 0 }
        dragFromTabIndex = -1
    }

    tmpOffset := tabs.leftSkipOffset^
    if ctx.hotId in itemsIds && abs(ctx.scrollDelta) > 0 {
        tabs.leftSkipOffset^ -= int(ctx.scrollDelta) / 3
    }

    tabs.leftSkipOffset^ = min(int(position.x - startPosition) + tmpOffset - tabs.width, tabs.leftSkipOffset^)
    tabs.leftSkipOffset^ = max(0, tabs.leftSkipOffset^)

    setClipRect(ctx, prevClipRect)

    return tabsActions
}
