package main

import "core:strings"
import "core:unicode/utf8"

findCursorPosition :: proc() {
    getCursorPosition :: proc() -> int {
        stringToRender := strings.to_string(windowData.text)

        mousePosition: int2 = {
            i32(inputState.mousePosition.x) - windowData.editorPadding.left,
            i32(inputState.mousePosition.y) - windowData.editorPadding.top,
        }
        lineIndex := i16(f32(mousePosition.y) / windowData.font.lineHeight) + i16(windowData.screenGlyphs.lineIndex)
        
        // if user clicks lower on the screen where text was rendered take last line
        lineIndex = min(i16(len(windowData.screenGlyphs.lines) - 1), lineIndex)
    
        fromByte := windowData.screenGlyphs.lines[lineIndex].x
        toByte := windowData.screenGlyphs.lines[lineIndex].y
        
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

    if inputState.wasLeftMouseButtonDown {
        pos := getCursorPosition()
        windowData.editorState.selection = { pos, pos }
        return
    }

    if inputState.isLeftMouseButtonDown { 
        windowData.editorState.selection[0] = getCursorPosition()
    }
}

updateCusrorData :: proc() {
    // layoutLength := len(windowData.screenGlyphs.layout)
    // if layoutLength == 0 { return }

    screenGlyphs := windowData.screenGlyphs

    // find cursor line
    windowData.screenGlyphs.cursorLineIndex = 0
    cursorLine: int2 = { 0, 0 }
    cursorIndex := i32(windowData.editorState.selection[0])

    // find current cursor line index
    for line, lineIndex in screenGlyphs.lines {
        leftByte := line.x
        rightByte := line.y

        if cursorIndex >= leftByte && cursorIndex <= rightByte {
            windowData.screenGlyphs.cursorLineIndex = i32(lineIndex)
            cursorLine = { leftByte, rightByte }
            windowData.editorState.line_start = int(leftByte)
            windowData.editorState.line_end = int(rightByte)
            break
        }
    }

    // find cursor left offset
    cursorLeftOffset: f32 = 0.0
    stringToRender := strings.to_string(windowData.text)
    charIndex := cursorLine.x
    for charIndex < cursorLine.y {
        char, charSize := utf8.decode_rune(stringToRender[charIndex:])
        defer charIndex += i32(charSize)
        
        if cursorIndex == charIndex { break }

        fontChar := windowData.font.chars[char]
        cursorLeftOffset += fontChar.xAdvance
    }

    cursorLineIndex := windowData.screenGlyphs.cursorLineIndex

    // calculate line above cursor position if user clicks UP
    if cursorLineIndex > 0 {
        previousLine := screenGlyphs.lines[cursorLineIndex - 1]

        windowData.editorState.up_index = int(previousLine.y)

        charIndex = previousLine.x
        leftOffset: f32 = 0.0
        for charIndex < previousLine.y {
            char, charSize := utf8.decode_rune(stringToRender[charIndex:])
            defer charIndex += i32(charSize)
            
            fontChar := windowData.font.chars[char]
            leftOffset += fontChar.xAdvance
            if leftOffset > cursorLeftOffset {
                windowData.editorState.up_index = int(charIndex)
                break
            }
        }
    } else {
        windowData.editorState.up_index = windowData.editorState.selection[0]
    }

    // calculate line below cursor position if user clicks DOWN
    if cursorLineIndex < i32(len(screenGlyphs.lines) - 1) {
        nextLine := screenGlyphs.lines[cursorLineIndex + 1]

        windowData.editorState.down_index = int(nextLine.y)

        charIndex = nextLine.x
        leftOffset: f32 = 0.0
        for charIndex < nextLine.y {
            char, charSize := utf8.decode_rune(stringToRender[charIndex:])
            defer charIndex += i32(charSize)
            
            fontChar := windowData.font.chars[char]
            leftOffset += fontChar.xAdvance
            if leftOffset > cursorLeftOffset {
                windowData.editorState.down_index = int(charIndex)
                break
            }
        }
    } else {
        windowData.editorState.down_index = windowData.editorState.selection[0]
    }
}

validateTopLine :: proc() {
    windowData.screenGlyphs.lineIndex = max(0, windowData.screenGlyphs.lineIndex)
    windowData.screenGlyphs.lineIndex = min(i32(len(windowData.screenGlyphs.lines) - 1), windowData.screenGlyphs.lineIndex)
}

jumpToCursor :: proc(cursorLineIndex: i32) {
    maxLinesOnScreen := i32(f32(getEditorSize().y) / windowData.font.lineHeight)

    if cursorLineIndex < windowData.screenGlyphs.lineIndex {
        windowData.screenGlyphs.lineIndex = cursorLineIndex
    } else if cursorLineIndex >= windowData.screenGlyphs.lineIndex + maxLinesOnScreen {
        windowData.screenGlyphs.lineIndex = cursorLineIndex - maxLinesOnScreen + 1
    }
}

calculateLines :: proc() {
    clear(&windowData.screenGlyphs.lines)
    stringToRender := strings.to_string(windowData.text)
    stringLength := len(stringToRender)
 
    cursor: f32 = 0.0
    lineWidth := f32(getEditorSize().x)
    lineBoundaryIndexes: int2 = { 0, 0 }
    
    for charIndex := 0; charIndex < stringLength; {
        char, charSize := utf8.decode_rune(stringToRender[charIndex:])
        defer charIndex += charSize

        if char == '\n' {
            cursor = 0.0
            
            lineBoundaryIndexes.y = i32(charIndex)
            append(&windowData.screenGlyphs.lines, lineBoundaryIndexes)
            lineBoundaryIndexes.x = lineBoundaryIndexes.y + i32(charSize)
            continue 
        }

        fontChar := windowData.font.chars[char]
        cursor += fontChar.xAdvance

        // text wrapping
        // TODO: make two functions, 1 - with wrapping, 2 - no wrapping, to avoid additional check
        if windowData.wordWrapping && cursor >= lineWidth {
            cursor = 0.0

            // since we do text wrapping, line should end on the previous symbol
            lineBoundaryIndexes.y = i32(charIndex) - i32(charSize)
            append(&windowData.screenGlyphs.lines, lineBoundaryIndexes)
            lineBoundaryIndexes.x = lineBoundaryIndexes.y + i32(charSize)
        }
    }
    
    lineBoundaryIndexes.y = i32(stringLength)
    append(&windowData.screenGlyphs.lines, lineBoundaryIndexes)
}
