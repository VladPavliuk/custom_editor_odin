package main

import win32 "core:sys/windows"

// NOTE: for now we just use a library to parse machine code
ZydisDisassembledInstruction :: struct {
    runtime_address: u64,
    info: struct {
        machine_mode: u32,
        mnemonic: u32,
        length: u8,
        encoding: u32,
        opcode_map: u32,
        opcode: u8,
        stack_width: u8,
        operand_width: u8,
        address_width: u8,
        operand_count: u8,
        operand_count_visible: u8,
        attributes: u64,
        cpu_flags: uintptr,
        fpu_flags: uintptr,
        // _: [272]u8,
        _: [56]u8,
        raw: struct {
            prefix_count: u8,
            prefixes: [15]struct {
                type: u32,
                value: u8,
            },
            encoding2: u32,
            _: [15]u8,
            modrm: u32,
            sib: u32,
            disp: [16]u8,
            imm: [2]struct {
                is_signed: u8,
                is_relative: u8,
                value: u64,
                size: u8,
                offset: u8,
            },
        }
    },
    // _: u32,
    // _: u32,
    // opcode: u8,
    // _: [307]u8,
    operands: [10]struct {
        id: u8,
        visibility: u32,
        actions: u8,
        encoding: u32,
        size: u16,
        element_type: u32,
        element_size: u16,
        element_count: u16,
        attributes: u8,
        type: u32,
        value: struct #raw_union {
            reg: u32,
            mem: struct {
                type: u32,
                segment: u32,
                base: u32,
                index: u32,
                scale: u8,
                value: i64,
                offset: u8,
                size: u8,
            },
            ptr: struct {
                segment: u16,
                offset: u32,
            },
            imm: struct {
                is_signed: u8,
                is_relative: u8,
                value: struct #raw_union {
                    u: u64,
                    s: i64,
                },
                offset: u8,
                size: u8,
            },
        },
    },
    text: [96]u8,
}

parseInstructionsFromProcess :: proc(process: win32.HANDLE, startAddress: uintptr, length: u32) {
    instructions: [1024]u8
    read: uint
    res := win32.ReadProcessMemory(process, rawptr(startAddress), raw_data(instructions[:]), uint(length), &read)
    assert(res == true, "Could not read the debugged process memory")

    zydisInstruction: ZydisDisassembledInstruction

    offset: u64 = 0
    runtimeAddress := startAddress
    potentialAddresses := make([dynamic]uintptr)
    defer delete(potentialAddresses)

    for ZydisDisassembleIntel(0, rawptr(runtimeAddress), rawptr(uintptr(raw_data(instructions[:])) + uintptr(offset)), u64(length) - offset, &zydisInstruction) & 0x80000000 == 0 {
        offset += u64(zydisInstruction.info.length)
        runtimeAddress += uintptr(zydisInstruction.info.length)

        switch zydisInstruction.info.opcode {
        case
            0xE8, // call
            0x74, // je
            0x7E, // jle
            0xEB, // jmp
            0x7D: // jnl
            address := i128(runtimeAddress) + i128(zydisInstruction.operands[0].value.imm.value.s)
            append(&potentialAddresses, uintptr(address))

            //fmt.printfln("YEAH(%#X)", address)
        }
        
        // fmt.printfln("opcode(%#X) %s", zydisInstruction.info.opcode, cstring(raw_data(zydisInstruction.text[:])))
        fmt.println(cstring(raw_data(zydisInstruction.text[:])))
        // setBreakpointForThread(debugEvent.dwThreadId, exeBaseAddress + rva)
    }

    fmt.println("POTENTIAL ADDRESSES:")
    for address in potentialAddresses {
        fmt.println(address)
    }
}