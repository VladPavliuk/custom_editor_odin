package main

import "core:strings"
import "core:unicode/utf8"
import "core:fmt"

/*
    CURRENT APPROACH
    
    Current approach is really slow and works like the following:

    1. 

*/

/*
    It seeems that for wrapping and non wrapping there should be 2 different algorithms
    Each algorithm consits of 2 parts:
    1. Aproximate vertical and horizontal scrolls size and current position
    2. Draw text based on the position in the file (position should be calculated based on scrolls positions)

    First, let's implement non-wrapping algorithm.

    NON-WRAPPING
    SCROLL

    It seems there are 2 options
    heuristic vs precise approaches (and their combination)

    heuristic algorithm:
    1. Calculate average length of any n lines
    2. 

    1. Pick any char by index

*/
newStaff :: proc(text: string) {
    pivotCharIndex: i32 // visible top left char index in buffer
    pivotCharOffset: int2 // offset to top-left rendering corner



}

getCursorIndexByMousePosition :: proc(ctx: ^EditableTextContext) -> int {
    stringToRender := strings.to_string(ctx.text)

    mousePosition := screenToDirectXCoords(inputState.mousePosition)

    mousePosition = {
        mousePosition.x - ctx.rect.left + ctx.leftOffset,
        ctx.rect.top - mousePosition.y,
    }

    lineIndex := i16(f32(mousePosition.y) / windowData.font.lineHeight) + i16(ctx.lineIndex)
    
    // if user clicks lower on the screen where text was rendered take last line
    lineIndex = min(i16(len(ctx.lines) - 1), lineIndex)

    fromByte := ctx.lines[lineIndex].x
    toByte := ctx.lines[lineIndex].y
    
    cursor: f32 = 0.0
    for byteIndex := fromByte; byteIndex < toByte; {
        char, charSize := utf8.decode_rune(stringToRender[byteIndex:])
        defer byteIndex += i32(charSize)
        
        fontChar := windowData.font.chars[char]
        
        if f32(mousePosition.x) < cursor {
            return int(byteIndex)
        }

        cursor += fontChar.xAdvance
    }

    // if no glyph found move the cursor to the last glyph
    return int(toByte)
}

updateCusrorData :: proc(ctx: ^EditableTextContext) {
    // find cursor line
    ctx.cursorLineIndex = 0
    cursorLine: int2 = { 0, 0 }
    cursorIndex := i32(ctx.editorState.selection[0])

    // find current cursor line index
    for line, lineIndex in ctx.lines {
        leftByte := line.x
        rightByte := line.y

        if cursorIndex >= leftByte && cursorIndex <= rightByte {
            ctx.cursorLineIndex = i32(lineIndex)
            cursorLine = { leftByte, rightByte }
            ctx.editorState.line_start = int(leftByte)
            ctx.editorState.line_end = int(rightByte)
            break
        }
    }

    // find cursor left offset
    ctx.cursorLeftOffset = 0.0
    stringToRender := strings.to_string(ctx.text)
    charIndex := cursorLine.x
    for charIndex < cursorLine.y {
        char, charSize := utf8.decode_rune(stringToRender[charIndex:])
        defer charIndex += i32(charSize)
        
        if cursorIndex == charIndex { break }

        fontChar := windowData.font.chars[char]
        ctx.cursorLeftOffset += fontChar.xAdvance
    }

    cursorLineIndex := ctx.cursorLineIndex

    // calculate line above cursor position if user clicks UP
    if cursorLineIndex > 0 {
        previousLine := ctx.lines[cursorLineIndex - 1]

        ctx.editorState.up_index = int(previousLine.y)

        charIndex = previousLine.x
        leftOffset: f32 = 0.0
        for charIndex < previousLine.y {
            char, charSize := utf8.decode_rune(stringToRender[charIndex:])
            defer charIndex += i32(charSize)
            
            fontChar := windowData.font.chars[char]
            leftOffset += fontChar.xAdvance
            if leftOffset > ctx.cursorLeftOffset {
                ctx.editorState.up_index = int(charIndex)
                break
            }
        }
    } else {
        ctx.editorState.up_index = ctx.editorState.selection[0]
    }

    // calculate line below cursor position if user clicks DOWN
    if cursorLineIndex < i32(len(ctx.lines) - 1) {
        nextLine := ctx.lines[cursorLineIndex + 1]

        ctx.editorState.down_index = int(nextLine.y)

        charIndex = nextLine.x
        leftOffset: f32 = 0.0
        for charIndex < nextLine.y {
            char, charSize := utf8.decode_rune(stringToRender[charIndex:])
            defer charIndex += i32(charSize)
            
            fontChar := windowData.font.chars[char]
            leftOffset += fontChar.xAdvance
            if leftOffset > ctx.cursorLeftOffset {
                ctx.editorState.down_index = int(charIndex)
                break
            }
        }
    } else {
        ctx.editorState.down_index = ctx.editorState.selection[0]
    }
}

validateTopLine :: proc(ctx: ^EditableTextContext) {
    ctx.lineIndex = max(0, ctx.lineIndex)
    ctx.lineIndex = min(i32(len(ctx.lines) - 1), ctx.lineIndex)
}

jumpToCursor :: proc(ctx: ^EditableTextContext) {
    maxLinesOnScreen := i32(f32(getEditorSize().y) / windowData.font.lineHeight)

    if ctx.cursorLineIndex < ctx.lineIndex {
        ctx.lineIndex = ctx.cursorLineIndex
    } else if ctx.cursorLineIndex >= ctx.lineIndex + maxLinesOnScreen {
        ctx.lineIndex = ctx.cursorLineIndex - maxLinesOnScreen + 1
    }

    if ctx.leftOffset > i32(ctx.cursorLeftOffset) {
        ctx.leftOffset = i32(ctx.cursorLeftOffset)
    } else if ctx.leftOffset < i32(ctx.cursorLeftOffset) - getRectSize(ctx.rect).x {
        ctx.leftOffset = i32(ctx.cursorLeftOffset) - getRectSize(ctx.rect).x
    }
}

calculateLines :: proc(ctx: ^EditableTextContext) {
    clear(&ctx.lines)
    stringToRender := strings.to_string(ctx.text)
    stringLength := len(stringToRender)
 
    cursor: f32 = 0.0

    lineWidth := f32(getRectSize(windowData.editorCtx.rect).x)
    lineBoundaryIndexes: int2 = { 0, 0 }
    ctx.maxLineWidth = -1.0
    
    for charIndex := 0; charIndex < stringLength; {
        char, charSize := utf8.decode_rune(stringToRender[charIndex:])
        defer charIndex += charSize

        if char == '\n' {
            cursor = 0.0
            
            lineBoundaryIndexes.y = i32(charIndex)
            append(&ctx.lines, lineBoundaryIndexes)
            lineBoundaryIndexes.x = lineBoundaryIndexes.y + i32(charSize)
            continue 
        }

        fontChar := windowData.font.chars[char]
        cursor += fontChar.xAdvance

        // text wrapping
        // TODO: make two functions, 1 - with wrapping, 2 - no wrapping, to avoid additional check
        if windowData.wordWrapping {
            if cursor >= lineWidth {
                cursor = 0.0

                // since we do text wrapping, line should end on the previous symbol
                lineBoundaryIndexes.y = i32(charIndex) - i32(charSize)
                append(&ctx.lines, lineBoundaryIndexes)
                lineBoundaryIndexes.x = lineBoundaryIndexes.y + i32(charSize)
            }
        } else {
            // TODO: make two functions, 1 - with wrapping, 2 - no wrapping, to avoid additional check
            // maxLineWidth makes sense only if in word wrapping is off
            if cursor >= ctx.maxLineWidth {
                ctx.maxLineWidth = cursor
            }
        }
    }
    
    lineBoundaryIndexes.y = i32(stringLength)
    append(&ctx.lines, lineBoundaryIndexes)
}
