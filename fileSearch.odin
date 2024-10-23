package main

import "ui"
import "base:intrinsics"
import "core:strings"
import "core:unicode/utf8"

renderFileSearch :: proc() {
    size := int2{ 120, 80 }
    position := int2{ windowData.size.x / 2 - size.x - 15, windowData.size.y / 2 - size.y - 60 }

    bgRect := ui.toRect(position, size)
    ui.putEmptyElement(&windowData.uiContext, bgRect)
    append(&windowData.uiContext.commands, ui.RectCommand{
        rect = bgRect,
        bgColor = GRAY_COLOR,
    })
    append(&windowData.uiContext.commands, ui.BorderRectCommand{
        rect = bgRect,
        color = BLACK_COLOR,
        thikness = 1,
    })

    ui.renderLabel(&windowData.uiContext, ui.Label{
        text = "File search",
        position = { position.x + 5, position.y + 55 },
        color = BLACK_COLOR,
    })
    actions, fieldId := renderTextField(&windowData.uiContext, ui.TextField{
        text = strings.to_string(windowData.fileSearchStr),
        position = { position.x + 5, position.y + 25 },
        size = { size.x - 10, 25 },
    })

    if windowData.fileSearchJustOpened {
        windowData.uiContext.tmpFocusedId = fieldId
        windowData.fileSearchJustOpened = false
    }

    if windowData.uiContext.focusedId == fieldId && .ESC in inputState.wasPressedKeys {
        windowData.isFileSearchOpen = false
        windowData.uiContext.tmpFocusedId = 0
        switchInputContextToEditor()
    }

    count, indexes := count_with_indexes(strings.to_string(getActiveTab().ctx.text), strings.to_string(windowData.fileSearchStr))

    ui.renderLabel(&windowData.uiContext, ui.Label{
        text = fmt.tprintf("%i of %i matches", windowData.currentFileSearchTermIndex + 1, count),
        position = { position.x + 5, position.y + 5 },
        color = BLACK_COLOR,
    })

    if .FOCUSED in actions {
        strings.builder_reset(&windowData.fileSearchStr)

        strings.write_string(&windowData.fileSearchStr, strings.to_string(windowData.uiTextInputCtx.text))

        if count > 0 && .ENTER in inputState.wasPressedKeys {
            windowData.currentFileSearchTermIndex = (windowData.currentFileSearchTermIndex + 1) % i32(len(indexes))

            tabTextCtx := getActiveTabContext() 

            tabTextCtx.editorState.selection = {
                indexes[windowData.currentFileSearchTermIndex],
                indexes[windowData.currentFileSearchTermIndex],
            }
            updateCusrorData(tabTextCtx)
            jumpToCursor(tabTextCtx)
        }
    }

    renderFoundSearchTerms(indexes, strings.to_string(windowData.fileSearchStr))
}

renderFoundSearchTerms :: proc(indexes: []int, serchTerm: string) {
    ctx := getActiveTab().ctx
    textToSearch := strings.to_string(ctx.text)

    serchTermLength := i32(len(serchTerm))

    editableRectSize := ui.getRectSize(ctx.rect)
    maxLinesOnScreen := editableRectSize.y / i32(windowData.font.lineHeight)

    topLine := ctx.lineIndex
    bottomLine := min(topLine + maxLinesOnScreen, i32(len(ctx.lines)) - 1)

    firstFoundIndex: i32 = -1
    lastFoundIndex: i32 = -1

    for i, index in indexes {
        if i32(i) >= ctx.lines[topLine].x {
            firstFoundIndex = i32(index)
            break
        }
    }

    #reverse for i, index in indexes {
        if i32(i) < ctx.lines[bottomLine].y {
            lastFoundIndex = i32(index)
            break
        }
    }

    if firstFoundIndex == -1 || lastFoundIndex == -1 { return }

    for byteIndex in ctx.glyphsLocations {
        if has, index := any_of_with_index(indexes[firstFoundIndex:lastFoundIndex + 1], int(byteIndex)); has {
            initLocation := ctx.glyphsLocations[byteIndex]

            size: f32 = 0.0
            byteIndex := byteIndex
            for _ in 0..<serchTermLength {
                char, charSize := utf8.decode_rune(textToSearch[byteIndex:])
                defer byteIndex += i32(charSize)
                fontChar := windowData.font.chars[char]

                size += fontChar.xAdvance
            }

            if int(firstFoundIndex) + index == int(windowData.currentFileSearchTermIndex) {
                renderRectBorder(ui.toRect({ initLocation.position.x, initLocation.lineStart }, { i32(size), i32(windowData.font.lineHeight) }), 1, windowData.uiContext.zIndex, RED_COLOR)
            } else {
                renderRectBorder(ui.toRect({ initLocation.position.x, initLocation.lineStart }, { i32(size), i32(windowData.font.lineHeight) }), 1, windowData.uiContext.zIndex, BLACK_COLOR)
            }
        }
    }
}

@(require_results)
any_of_with_index :: proc(s: $S/[]$T, value: T) -> (bool, int) where intrinsics.type_is_comparable(T) {
	for v, i in s {
		if v == value {
			return true, i
		}
	}
	return false, -1
}

count_with_indexes :: proc(s, substr: string) -> (res: int, indexes: []int) {
    indexes_list := make([dynamic]int, context.temp_allocator)

	if len(substr) == 0 { // special case
		return 0, indexes_list[:]
	}

	if len(substr) == 1 {
		c := substr[0]
		switch len(s) {
		case 0:
			return 0, indexes_list[:]
		case 1:
			return int(s[0] == c), indexes_list[:]
		}
		n := 0
		for i := 0; i < len(s); i += 1 {
			if s[i] == c {
				n += 1
                append(&indexes_list, i)
			}
		}
		return n, indexes_list[:]
	}

	// TODO(bill): Use a non-brute for approach
	n := 0
	str := s
    c := 0
	for {
		i := strings.index(str, substr)
		if i == -1 {
			return n, indexes_list[:]
		}
		n += 1
        append(&indexes_list, i + c)
		str = str[i+len(substr):]
        c += i+len(substr)
	}
	return n, indexes_list[:]
}