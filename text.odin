package main

import "core:strings"
import "core:unicode/utf8"

findCursorPosition :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    if !windowData.isLeftMouseButtonDown { return }
    lineHeight := directXState.fontData.ascent - directXState.fontData.descent

    lineIndex := i16(windowData.mousePosition.y / lineHeight)
    
    // if user clicks lower on the screen where text was rendered take last line
    lineIndex = min(i16(len(windowData.screenGlyphs.lines) - 1), lineIndex)

    leftIndex := windowData.screenGlyphs.lines[lineIndex].x
    rightIndex := windowData.screenGlyphs.lines[lineIndex].y
    
    // by default move the cursor to the last glyph
    lastGlyph := windowData.screenGlyphs.layout[int(rightIndex)]
    windowData.inputState.selection = {int(lastGlyph.indexInString), int(lastGlyph.indexInString)}

    for i in leftIndex..<rightIndex {
        glyph := windowData.screenGlyphs.layout[int(i)]
        if windowData.mousePosition.x - f32(windowData.size.x / 2) < glyph.x {
            windowData.inputState.selection = {int(glyph.indexInString), int(glyph.indexInString)}
            break
        }
    }
}

updateCusrorData :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    layoutLength := len(windowData.screenGlyphs.layout)
    if layoutLength == 0 { return }

    screenGlyphs := windowData.screenGlyphs

    // find cursor line
    cursorLine := 0
    cursorIndex := i64(windowData.inputState.selection[0])
    for line, lineIndex in screenGlyphs.lines {
        leftGlyph := screenGlyphs.layout[line.x]
        rightGlyph := screenGlyphs.layout[line.y]

        if cursorIndex >= leftGlyph.indexInString && cursorIndex <= rightGlyph.indexInString {
            cursorLine = lineIndex 
            windowData.inputState.line_start = int(leftGlyph.indexInString)
            windowData.inputState.line_end = int(rightGlyph.indexInString)
            break
        }
    }

    cursorPosition := windowData.cursorScreenPosition

    if cursorLine > 0 {
        previousLine := screenGlyphs.lines[cursorLine - 1]

        windowData.inputState.up_index = int(screenGlyphs.layout[previousLine.y].indexInString)

        for glyphIndex in previousLine.x..<previousLine.y {
            if cursorPosition.x < screenGlyphs.layout[glyphIndex].x {
                windowData.inputState.up_index = int(screenGlyphs.layout[glyphIndex].indexInString)
                break
            }
        }
    }

    if cursorLine < len(screenGlyphs.lines) - 2 {
        nextLine := screenGlyphs.lines[cursorLine + 1]

        windowData.inputState.down_index = int(screenGlyphs.layout[nextLine.y].indexInString)

        for glyphIndex in nextLine.x..<nextLine.y {
            if cursorPosition.x < screenGlyphs.layout[glyphIndex].x {
                windowData.inputState.down_index = int(screenGlyphs.layout[glyphIndex].indexInString)
                break
            }
        }
    }
}

// BENCHMARKS: +-200 microseconds with -speed build option
calculateTextLayout :: proc(directXState: ^DirectXState, windowData: ^WindowData) {
    // NOTE: FOR NOW WE ASSUME THAT WRAPPING IS TURNED ON ALWAYS
    clear(&windowData.screenGlyphs.layout)
    clear(&windowData.screenGlyphs.lines)

    // stringToRender := windowData.testInputString.buf
    stringToRender := strings.to_string(windowData.testInputString)

    lineHeight := directXState.fontData.ascent - directXState.fontData.descent
    initialPosition: float2 = { -f32(windowData.size.x) / 2.0, f32(windowData.size.y) / 2.0 - lineHeight }
    cursorPosition := initialPosition
    lineBoundaryIndexes: int2 = { 0, 0 }

    startFromIndex: int = 0
    // append(&windowData.screenGlyphs.lines, startFromIndex)

    stringLength := len(stringToRender)
    charIndex := startFromIndex
    charSize := 1
    runeIndex := 0
    for ;charIndex < stringLength; charIndex += charSize {
        defer runeIndex += 1
        char: rune
        char, charSize = utf8.decode_rune(stringToRender[charIndex:])

        // defer { charIndex += size }

        // if cursor moves outside of the screen, stop layout generation
        if cursorPosition.y < -f32(windowData.size.y) / 2 {
            break
        }

        if char == '\n' {
            append(&windowData.screenGlyphs.layout, GlyphItem{
                char = char,
                indexInString = i64(charIndex),
                x = cursorPosition.x,
                y = cursorPosition.y,
                width = -1,
                height = -1,
            })

            cursorPosition.y -= lineHeight
            cursorPosition.x = initialPosition.x
            
            lineBoundaryIndexes.y = i32(runeIndex)
            append(&windowData.screenGlyphs.lines, lineBoundaryIndexes)
            lineBoundaryIndexes.x = lineBoundaryIndexes.y + 1
            continue 
        }

        fontChar := directXState.fontData.chars[char]

        kerning: f32 = 0.0
        if charIndex + 1 < len(stringToRender) {
            // kerning = directXState.fontData.kerningTable[char][rune(stringToRender[charIndex + 1])]
        }
        
        glyphSize: float2 = { fontChar.rect.right - fontChar.rect.left, fontChar.rect.top - fontChar.rect.bottom }
        glyphPosition: float2 = { cursorPosition.x + fontChar.offset.x + kerning, cursorPosition.y - glyphSize.y - fontChar.offset.y }

        // text wrapping
        if glyphPosition.x + glyphSize.x >= f32(windowData.size.x) / 2 {
            cursorPosition.y -= lineHeight
            cursorPosition.x = initialPosition.x

            // since we do text wrapping, line should end on the previous symbol
            lineBoundaryIndexes.y = i32(runeIndex) - 1
            append(&windowData.screenGlyphs.lines, lineBoundaryIndexes)
            lineBoundaryIndexes.x = lineBoundaryIndexes.y + 1

            glyphPosition = { cursorPosition.x + fontChar.offset.x + kerning, cursorPosition.y - glyphSize.y - fontChar.offset.y }
        }

        append(&windowData.screenGlyphs.layout, GlyphItem{
            char = char,
            indexInString = i64(charIndex),
            x = glyphPosition.x,
            y = glyphPosition.y,
            width = glyphSize.x,
            height = glyphSize.y,
        })
        
        cursorPosition.x += fontChar.xAdvance + fontChar.offset.x
    }

    // add artificial glyph at the end of layout, so cursor can be rendered
    append(&windowData.screenGlyphs.layout, GlyphItem{
        char = ' ',
        indexInString = i64(len(stringToRender)),
        x = cursorPosition.x,
        y = cursorPosition.y,
        width = -1,
        height = -1,
    })

    lineBoundaryIndexes.y = i32(runeIndex)
    append(&windowData.screenGlyphs.lines, lineBoundaryIndexes)
}
