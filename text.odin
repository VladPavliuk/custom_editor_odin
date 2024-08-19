package main

import "core:strings"
import "core:unicode/utf8"
import "core:fmt"

findCursorPosition :: proc(windowData: ^WindowData) {
    if !windowData.isLeftMouseButtonDown { return }
    
    stringToRender := strings.to_string(windowData.testInputString)

    lineIndex := i16(windowData.mousePosition.y / windowData.font.lineHeight) + i16(windowData.screenGlyphs.lineIndex)
    
    // if user clicks lower on the screen where text was rendered take last line
    lineIndex = min(i16(len(windowData.screenGlyphs.lines) - 1), lineIndex)

    fromByte := windowData.screenGlyphs.lines[lineIndex].x
    toByte := windowData.screenGlyphs.lines[lineIndex].y
    
    // by default move the cursor to the last glyph
    windowData.inputState.selection = {int(toByte), int(toByte)}

    cursor: f32 = 0.0
    for byteIndex := fromByte; byteIndex < toByte; {
        char, charSize := utf8.decode_rune(stringToRender[byteIndex:])
        defer byteIndex += i32(charSize)
        
        fontChar := windowData.font.chars[char]
        
        glyphWidth: f32 = fontChar.rect.right - fontChar.rect.left

        if windowData.mousePosition.x < cursor {
            windowData.inputState.selection = {int(byteIndex), int(byteIndex)}
            break
        }

        cursor += fontChar.xAdvance
    }
}

updateCusrorData :: proc(windowData: ^WindowData) {
    // layoutLength := len(windowData.screenGlyphs.layout)
    // if layoutLength == 0 { return }

    screenGlyphs := windowData.screenGlyphs

    // find cursor line
    windowData.screenGlyphs.cursorLineIndex = 0
    cursorLine: int2 = { 0, 0 }
    cursorIndex := i32(windowData.inputState.selection[0])

    // find current cursor line index
    for line, lineIndex in screenGlyphs.lines {
        leftByte := line.x
        rightByte := line.y

        if cursorIndex >= leftByte && cursorIndex <= rightByte {
            windowData.screenGlyphs.cursorLineIndex = i32(lineIndex)
            cursorLine = { leftByte, rightByte }
            windowData.inputState.line_start = int(leftByte)
            windowData.inputState.line_end = int(rightByte)
            break
        }
    }

    // find cursor left offset
    cursorLeftOffset: f32 = 0.0
    stringToRender := strings.to_string(windowData.testInputString)
    charIndex := cursorLine.x
    for charIndex < cursorLine.y {
        char, charSize := utf8.decode_rune(stringToRender[charIndex:])
        defer charIndex += i32(charSize)
        
        if cursorIndex == charIndex { break }

        fontChar := windowData.font.chars[char]
        glyphWidth: f32 = fontChar.rect.right - fontChar.rect.left
        cursorLeftOffset += fontChar.xAdvance
    }

    cursorLineIndex := windowData.screenGlyphs.cursorLineIndex

    // calculate line above cursor position if user clicks UP
    if cursorLineIndex > 0 {
        previousLine := screenGlyphs.lines[cursorLineIndex - 1]

        windowData.inputState.up_index = int(previousLine.y)

        charIndex := previousLine.x
        leftOffset: f32 = 0.0
        for charIndex < previousLine.y {
            char, charSize := utf8.decode_rune(stringToRender[charIndex:])
            defer charIndex += i32(charSize)
            
            fontChar := windowData.font.chars[char]
            glyphWidth: f32 = fontChar.rect.right - fontChar.rect.left
            leftOffset += fontChar.xAdvance
            if leftOffset > cursorLeftOffset {
                windowData.inputState.up_index = int(charIndex)
                break
            }
        }
    } else {
        windowData.inputState.up_index = windowData.inputState.selection[0]
    }

    // calculate line below cursor position if user clicks DOWN
    if cursorLineIndex < i32(len(screenGlyphs.lines) - 1) {
        nextLine := screenGlyphs.lines[cursorLineIndex + 1]

        windowData.inputState.down_index = int(nextLine.y)

        charIndex := nextLine.x
        leftOffset: f32 = 0.0
        for charIndex < nextLine.y {
            char, charSize := utf8.decode_rune(stringToRender[charIndex:])
            defer charIndex += i32(charSize)
            
            fontChar := windowData.font.chars[char]
            glyphWidth: f32 = fontChar.rect.right - fontChar.rect.left
            leftOffset += fontChar.xAdvance
            if leftOffset > cursorLeftOffset {
                windowData.inputState.down_index = int(charIndex)
                break
            }
        }
    } else {
        windowData.inputState.down_index = windowData.inputState.selection[0]
    }
}

calculateLines :: proc(windowData: ^WindowData) {
    clear(&windowData.screenGlyphs.lines)
    stringToRender := strings.to_string(windowData.testInputString)
    stringLength := len(stringToRender)
 
    cursor: f32 = 0.0
    windowWidth := f32(windowData.size.x)
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
        glyphWidth: f32 = fontChar.rect.right - fontChar.rect.left
        cursor += fontChar.xAdvance

        // text wrapping
        if cursor >= windowWidth {
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
