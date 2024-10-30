package ui

TabsItem :: struct {
    text: string,
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
    activeTabIndex: ^i32,
    items: []TabsItem,
    itemStyles: TabsItemStyles,
    bgColor, hoverBgColor, activeColor: [4]f32,
}

TabsActionClose :: struct {
    closedTabIndex: i32,
}

TabsSwitched :: struct {
    index: i32,
}

TabsActions :: union {TabsSwitched, TabsActionClose}

renderTabs :: proc(ctx: ^Context, tabs: Tabs, customId: i32 = 0, loc := #caller_location) -> TabsActions {
    customId := customId
    tabsActions: TabsActions = nil

    leftOffset: i32 = 0
    for item, index in tabs.items {
        position: int2 = { tabs.position.x + leftOffset, tabs.position.y }
        padding := tabs.itemStyles.padding
        
        width := tabs.itemStyles.size.x
        if width == 0 { width = i32(ctx.getTextWidth(item.text, ctx.font)) }
        
        height := tabs.itemStyles.size.y
        if height == 0 { height = i32(ctx.getTextHeight(ctx.font)) }

        itemRect := toRect(position, int2{ width, height })

        itemActions, _ := putEmptyElement(ctx, itemRect, customId = customId, loc = loc)

        bgColor := tabs.bgColor

        if tabs.activeTabIndex^ == i32(index) {
            bgColor = getDarkerColor(bgColor)
        } else {
            if .HOT in itemActions { bgColor = getOrDefaultColor(tabs.hoverBgColor, getDarkerColor(bgColor)) }
            if .ACTIVE in itemActions { bgColor = getOrDefaultColor(tabs.activeColor, getDarkerColor(bgColor)) }
        }

        if .SUBMIT in itemActions {
            tabsActions = TabsSwitched{ index = i32(index) } 
            tabs.activeTabIndex^ = i32(index)
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
        
        // pushCommand(ctx, ClipCommand{
        //     rect = Rect { top = itemRect.top, bottom = itemRect.bottom, left = textPosition.x, right = itemRect.right - padding.right },
        // })
        pushCommand(ctx, TextCommand{
            text = item.text,
            position = textPosition,
            color = WHITE_COLOR,
            maxWidth = itemRect.right - padding.right - textPosition.x,
        })
        // pushCommand(ctx, ResetClipCommand{})

        if item.rightIconId != 0 {
            iconWidth = 20
            iconRightPadding = 3
            iconPosition: int2 = { position.x + width - iconWidth - iconRightPadding, position.y + height / 2 - iconWidth / 2 }
            
            customId += 1
            if .SUBMIT in renderButton(ctx, ImageButton{
                position = iconPosition,
                size = { iconWidth, iconWidth },
                textureId = item.rightIconId,
                texturePadding = 4,
                bgColor = bgColor,
                noBorder = true,
            }, customId, loc) {
                tabsActions = TabsActionClose{
                    closedTabIndex = i32(index),
                }
            }
        }

        customId += 1
        leftOffset += width
    }

    return tabsActions
}
