package ui

DropdownItem :: struct {
    text: string,
    rightText: string, // optional
    checkbox: ^bool, // if nil, don't show it
    isSeparator: bool,
    //TODO: add context menu item
}

DropdownItemStyle :: struct {
    size: [2]i32,
    padding: Rect,
    bgColor, hoverColor, activeColor: [4]f32,
}

Dropdown :: struct {
    text: string,
    position: [2]i32,
    size: [2]i32,
    bgColor: [4]f32,
    items: []DropdownItem, // TODO: maybe union{[]UiDropdownItem, []string}, ???
    selectedItemIndex: i32,
    isOpen: ^bool,
    scrollOffset: ^i32,
    maxItemShow: i32,
    itemStyles: DropdownItemStyle,
}

renderDropdown :: proc(ctx: ^Context, dropdown: Dropdown, customId: i32 = 0, loc := #caller_location) -> (Actions, i32) {
    assert(dropdown.isOpen != nil)
    itemsCount := i32(len(dropdown.items))
    assert(dropdown.selectedItemIndex >= -1 && dropdown.selectedItemIndex < itemsCount)
    assert(itemsCount > 0)
    assert(dropdown.maxItemShow > 0)
    customId := customId
    customId += 1
    scrollWidth: i32 = 10
    selectedItemIndex := dropdown.selectedItemIndex
    actions: Actions = {}
    //pushElement(ctx, Id)

    text: string
    if len(dropdown.text) > 0 { text = dropdown.text }
    else {
        assert(dropdown.selectedItemIndex >= 0)
        text = dropdown.items[dropdown.selectedItemIndex].text
    }

    buttonActions := renderButton(ctx, TextButton{
        text = text,
        position = dropdown.position,
        size = dropdown.size,
        bgColor = dropdown.bgColor,
        noBorder = true,
    }, customId, loc)

    if .SUBMIT in buttonActions {
        dropdown.isOpen^ = !(dropdown.isOpen^)
    }

    if .LOST_FOCUS in buttonActions {
        dropdown.isOpen^ = false
    }

    if dropdown.isOpen^ {
        itemPadding := dropdown.itemStyles.padding
        itemHeight := i32(ctx.getTextHeight(ctx.font)) + itemPadding.bottom + itemPadding.top
        offset := dropdown.position.y - itemHeight

        scrollOffsetIndex: i32 = 0
        hasScrollBar := false
        scrollHeight: i32 = -1
        itemsToShow := min(dropdown.maxItemShow, itemsCount)
        itemsContainerHeight := itemsToShow * itemHeight
        itemsContainerWidth := dropdown.itemStyles.size.x > 0 ? dropdown.itemStyles.size.x : dropdown.size.x
        
        // show scrollbar
        if itemsCount > dropdown.maxItemShow {
            hasScrollBar = true
            scrollHeight = i32(f32(dropdown.maxItemShow) / f32(itemsCount) * f32(itemsContainerHeight))

            beginScroll(ctx)

            scrollOffsetIndex = i32(f32(f32(dropdown.scrollOffset^) / f32(itemsContainerHeight - scrollHeight)) * f32(itemsCount - dropdown.maxItemShow))
        }
        
        itemWidth := itemsContainerWidth

        if hasScrollBar { itemWidth -= scrollWidth } 

        // render list
        for i in 0..<itemsToShow {
            index := i + scrollOffsetIndex
            item := dropdown.items[index]
            customId += 1

            defer offset -= itemHeight

            itemRect := toRect({ dropdown.position.x, offset }, { itemWidth, itemHeight })

            bgColor := getOrDefaultColor(dropdown.itemStyles.bgColor, dropdown.bgColor)

            if item.isSeparator {
                putEmptyElement(ctx, itemRect, true, customId, loc) // just to prevent closing dropdown on seperator click

                append(&ctx.commands, RectCommand{
                    rect = itemRect,
                    bgColor = bgColor,
                })

                separatorHorizontalPadding: i32 = 10
                
                append(&ctx.commands, RectCommand{
                    rect = toRect([2]i32{ dropdown.position.x + separatorHorizontalPadding, offset + itemHeight / 2 }, 
                        [2]i32{ itemWidth - 2 * separatorHorizontalPadding, 1 }),
                    bgColor = WHITE_COLOR,
                })

                continue
            }

            itemActions := putEmptyElement(ctx, itemRect, true, customId, loc)

            if .HOT in itemActions { bgColor = getOrDefaultColor(dropdown.itemStyles.hoverColor, getDarkerColor(bgColor)) }
            if .ACTIVE in itemActions { bgColor = getOrDefaultColor(dropdown.itemStyles.activeColor, getDarkerColor(bgColor)) } 

            append(&ctx.commands, ClipCommand{
                rect = itemRect,
            })            
            append(&ctx.commands, RectCommand{
                rect = itemRect,
                bgColor = bgColor,
            })

            append(&ctx.commands, TextCommand{
                text = item.text, 
                position = { dropdown.position.x + itemPadding.left, offset + itemPadding.bottom },
                color = WHITE_COLOR,
            })          

            // optional checkbox
            if item.checkbox != nil {
                checkboxSize := itemHeight

                checkboxPosition: int2 = { dropdown.position.x, offset }
                checkboxRect := toRect(checkboxPosition, { checkboxSize, checkboxSize })
                if item.checkbox^ {
                    append(&ctx.commands, ImageCommand{
                        rect = shrinkRect(checkboxRect, 3),
                        textureId = ctx.checkIconId,
                    })
                }
                
                append(&ctx.commands, BorderRectCommand{
                    rect = checkboxRect,
                    color = DARK_GRAY_COLOR,
                    thikness = 2,
                })

                if .SUBMIT in putEmptyElement(ctx, checkboxRect, true) {
                    item.checkbox^ = !item.checkbox^
                }
            }

            if len(item.rightText) > 0 {
                rightTextPositionX := dropdown.position.x + itemWidth - i32(ctx.getTextWidth(item.rightText, ctx.font)) - itemPadding.right
                
                append(&ctx.commands, TextCommand{
                    text = item.rightText, 
                    position = { rightTextPositionX, offset + itemPadding.bottom },
                    color = WHITE_COLOR,
                })
            }
            append(&ctx.commands, ResetClipCommand{})

            if .SUBMIT in itemActions {
                selectedItemIndex = i32(index)
                actions += {.SUBMIT}
                dropdown.isOpen^ = false

                if checkbox := dropdown.items[selectedItemIndex].checkbox; checkbox != nil {
                    checkbox^ = !checkbox^
                }
            }
        }

        if hasScrollBar {
            customId += 1

            endScroll(ctx, Scroll{
                bgRect = Rect{
                    top = dropdown.position.y,
                    bottom = dropdown.position.y - itemsContainerHeight,
                    right = dropdown.position.x + itemsContainerWidth,
                    left = dropdown.position.x + itemsContainerWidth - scrollWidth,
                },
                offset = dropdown.scrollOffset,
                size = scrollHeight,
                color = WHITE_COLOR,
                hoverColor = LIGHT_GRAY_COLOR,
                bgColor = BLACK_COLOR,
            }, customId = customId, loc = loc)
        }
    }

    return actions, selectedItemIndex
}
