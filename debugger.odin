package main

import "core:sync"
import "core:thread"
import "core:strings"
import "core:os"
import win32 "core:sys/windows"

foreign import kernel32 "system:Kernel32.lib"
foreign import psapi "system:Psapi.lib"

@(default_calling_convention = "std")
foreign kernel32 {
    DebugActiveProcess :: proc(dwProcessId: win32.DWORD) -> win32.BOOL ---
    WaitForDebugEvent :: proc(lpDebugEvent: ^WIN32_DEBUG_EVENT, dwMilliseconds: win32.DWORD) -> win32.BOOL ---
    ContinueDebugEvent :: proc(dwProcessId: win32.DWORD, dwThreadId: win32.DWORD, dwContinueStatus: win32.DWORD) -> win32.BOOL ---
    GetThreadId :: proc(Thread: win32.HANDLE) -> win32.DWORD ---
}

@(default_calling_convention = "std")
foreign psapi {
    EnumProcesses :: proc(lpidProcess: ^win32.DWORD, cb: win32.DWORD, lpcbNeeded: win32.LPDWORD) -> win32.BOOL ---
    EnumProcessModules :: proc(hProcess: win32.HANDLE, lphModule: ^win32.HMODULE, cb: win32.DWORD, lpcbNeeded: win32.LPDWORD) -> win32.BOOL ---
    GetModuleBaseNameW :: proc(hProcess: win32.HANDLE, hModule: win32.HMODULE, lpBaseName: win32.LPWSTR, nSize: win32.DWORD) -> win32.DWORD ---
}

TRAP_FLAG :: 1 << 8;

DebuggerCommand :: enum {
    NONE,
    CONTINUE,
    READ,
    STOP,
    STEP,
}

stopDebugger :: proc() {
    if windowData.debuggerThread == nil { return }

    win32.TerminateProcess(windowData.debuggerProcessHandler, 0)
    for !thread.is_done(windowData.debuggerThread) { }

    thread.join(windowData.debuggerThread)
    thread.destroy(windowData.debuggerThread)
    
    windowData.debuggerThread = nil
    win32.CloseHandle(windowData.debuggerProcessHandler)
}

runDebugProcess :: proc(exePath: string) {
    windowData.debuggerThread = thread.create_and_start_with_poly_data(exePath, runDebugProcess_Function, default_context)
}

// ThreadContext :: struct #align(16) {
//     ctx: win32.CONTEXT,
// }

runDebugProcess_Function :: proc(exePath: string) {
    // working_dir_w := (win32_utf8_to_wstring(desc.working_dir, temp_allocator()) or_else nil) if len(desc.working_dir) > 0 else nil
	processInfo: win32.PROCESS_INFORMATION
	ok := win32.CreateProcessW(
		win32.utf8_to_wstring(exePath),
		nil,
		nil,
		nil,
		false,
		win32.DEBUG_PROCESS | win32.DEBUG_ONLY_THIS_PROCESS | win32.CREATE_UNICODE_ENVIRONMENT | win32.NORMAL_PRIORITY_CLASS | win32.CREATE_NEW_CONSOLE,
		// win32.DEBUG_ONLY_THIS_PROCESS | win32.CREATE_NEW_CONSOLE,
		nil, // it's for passing env data???
        nil, // win32.utf8_to_wstring("C:\\projects\\mandelbrot_set_odin\\bin"),
		&win32.STARTUPINFOW{
			cb = size_of(win32.STARTUPINFOW),
            dwFlags = 0x00000001 | win32.STARTF_USESTDHANDLES, //STARTF_USESHOWWINDOW
            wShowWindow = 5, // SW_SHOW
			// hStdError  = stderr_handle,
			// hStdOutput = stdout_handle,
			// hStdInput  = stdin_handle,
			// dwFlags = win32.STARTF_USESTDHANDLES,
		},
		&processInfo,
	)

	if !ok {
		panic("FAILED")
	}

    Module :: struct {
        name: string,
        address: uintptr,
        size: i32,
        pdbFiles: [dynamic]PdbFile,
        exportFunctions: [dynamic]ExportFunction,
    }
    PdbFile :: struct {
        filePath: string,
        content: []u8,
    }
    ExportFunction :: struct {
        name: string,
        address: uintptr,
    }
    modules := make([dynamic]Module)
    defer delete(modules)

    PdbInfo :: struct {
        signature: u32,
        guid: win32.GUID,
        age: u32,
    }

    win32.CloseHandle(processInfo.hThread)
    
    sync.atomic_store(&windowData.debuggerProcessHandler, processInfo.hProcess)

    debugEvent: WIN32_DEBUG_EVENT
    expectStepException := false

    threadsIds := make([dynamic]u32)

    testFunctionRVA := testDia()
    exeBaseAddress: uintptr = 0

    for WaitForDebugEvent(&debugEvent, WIN32_INFINITE) {
        continueStatus: u32 = WIN32_DBG_EXCEPTION_NOT_HANDLED // why should it be always that and not WIN32_DBG_CONTINUE???
        exitDebugger := false

        // if sync.atomic_load(&windowData.windowCloseRequested) { 
        //     break 
        // }

        switch debugEvent.dwDebugEventCode {
        case 3: {
            fmt.println("CREATE_PROCESS_DEBUG_EVENT")
            
            read: uint

            threadId := GetThreadId(debugEvent.u.CreateProcessInfo.hThread)
            append(&threadsIds, threadId)
            // fmt.println(threadId)

            exeNameBufferLength :: 255
            exeNameBuffer: [exeNameBufferLength]u16
            exeBasePointer := uintptr(debugEvent.u.CreateProcessInfo.lpBaseOfImage)

            exeBaseAddress = exeBasePointer 
            nameLength := win32.GetFinalPathNameByHandleW(debugEvent.u.CreateProcessInfo.hFile, raw_data(exeNameBuffer[:]), exeNameBufferLength, 0)
            exeName, err := win32.wstring_to_utf8(win32.wstring(raw_data(exeNameBuffer[:])), int(nameLength))

            fmt.printfln("Load Process: %s (%#X)", exeName, exeBasePointer)

            // read dos header
            dosHeader: win32.IMAGE_DOS_HEADER
            win32.ReadProcessMemory(processInfo.hProcess, rawptr(exeBasePointer), &dosHeader, size_of(dosHeader), &read)

            peHeader: win32.IMAGE_NT_HEADERS64
            win32.ReadProcessMemory(processInfo.hProcess, rawptr(exeBasePointer + uintptr(dosHeader.e_lfanew)), &peHeader, size_of(peHeader), &read)
            
            // exportDirectory: win32.IMAGE_EXPORT_DIRECTORY
            // win32.ReadProcessMemory(processInfo.hProcess, rawptr(dllBasePointer + uintptr(peHeader.OptionalHeader.ExportTable.VirtualAddress)), 
            //     &exportDirectory, size_of(exportDirectory), &read)

            // get name of module through IMAGE_EXPORT_DIRECTORY
            // win32.ReadProcessMemory(processInfo.hProcess, rawptr(dllBasePointer + uintptr(exportDirectory.Name)), 
            //     raw_data(dllNameBuffer[:]), dllNameBufferLength, &read)

            // fmt.printfln("Load DLL 2: %s", strings.truncate_to_byte(string(dllNameBuffer[:]), 0))
            
            // private symbols
            debugDirectoriesCount := peHeader.OptionalHeader.Debug.Size / size_of(win32.IMAGE_DEBUG_DIRECTORY)
            
            pdbFiles := make([dynamic]PdbFile)

            for debugDirectoryIndex in 0..<debugDirectoriesCount {      
                debugDirectory: win32.IMAGE_DEBUG_DIRECTORY
                offset := debugDirectoryIndex * size_of(win32.IMAGE_DEBUG_DIRECTORY)
                debugDirectoryAddress := rawptr(exeBasePointer + uintptr(peHeader.OptionalHeader.Debug.VirtualAddress) + uintptr(offset))
                win32.ReadProcessMemory(processInfo.hProcess, debugDirectoryAddress, 
                    &debugDirectory, size_of(debugDirectory), &read)

                if debugDirectory.Type == win32.IMAGE_DEBUG_TYPE_CODEVIEW {
                    pdbInfo: PdbInfo
                    win32.ReadProcessMemory(processInfo.hProcess, rawptr(exeBasePointer + uintptr(debugDirectory.AddressOfRawData)), 
                        &pdbInfo, size_of(pdbInfo), &read)
        
                    pdbNameBuffer: [260]byte
                    win32.ReadProcessMemory(processInfo.hProcess, rawptr(exeBasePointer + uintptr(debugDirectory.AddressOfRawData) + size_of(pdbInfo)), 
                        raw_data(pdbNameBuffer[:]), 260, &read)
        
                    pdbFilePath := strings.truncate_to_byte(string(pdbNameBuffer[:]), 0)
                    pdbFileContent, err := os.read_entire_file_from_filename_or_err(pdbFilePath)

                    append(&pdbFiles, PdbFile{
                        filePath = pdbFilePath,
                        content = pdbFileContent,
                    })
                    // fmt.println("Process pdb file:", strings.truncate_to_byte(string(pdbNameBuffer[:]), 0))
                }
            } 

            append(&modules, Module{
                name = strings.clone(exeName),
                address = exeBasePointer,
                size = i32(peHeader.OptionalHeader.SizeOfImage),
                pdbFiles = pdbFiles,
            })
        }
        case 2: {
            threadId := GetThreadId(debugEvent.u.CreateThread.hThread)
            append(&threadsIds, threadId)
            fmt.println("CREATE_THREAD_DEBUG_EVENT ", threadId)
        }
        case 1: {
            continueStatus = WIN32_DBG_EXCEPTION_NOT_HANDLED

            firstChance := debugEvent.u.Exception.dwFirstChance
            
            //> was breakpoint hit
            threadHandler := win32.OpenThread(
                win32.THREAD_GET_CONTEXT | win32.THREAD_SET_CONTEXT,
                false,
                debugEvent.dwThreadId,
            )
            defer win32.CloseHandle(threadHandler)
            
            ctx: win32.CONTEXT
            ctx.ContextFlags = win32.WOW64_CONTEXT_ALL
            win32.GetThreadContext(threadHandler, &ctx)
            if ctx.Dr6 & 0x1 == 1 {
                fmt.println("HIT!!!!!!", ctx.Dr6)
                continueStatus = WIN32_DBG_CONTINUE
            }
            //<

            if expectStepException && debugEvent.u.Exception.ExceptionRecord.ExceptionCode == win32.EXCEPTION_SINGLE_STEP {
                continueStatus = WIN32_DBG_CONTINUE
            }

            switch debugEvent.u.Exception.ExceptionRecord.ExceptionCode {
            case win32.EXCEPTION_ACCESS_VIOLATION: fmt.println("EXCEPTION_ACCESS_VIOLATION")     
            case win32.EXCEPTION_ARRAY_BOUNDS_EXCEEDED: fmt.println("EXCEPTION_ARRAY_BOUNDS_EXCEEDED")     
            case win32.EXCEPTION_BREAKPOINT: fmt.println("EXCEPTION_BREAKPOINT")     
            case win32.EXCEPTION_DATATYPE_MISALIGNMENT: fmt.println("EXCEPTION_DATATYPE_MISALIGNMENT")     
            case win32.EXCEPTION_FLT_DENORMAL_OPERAND: fmt.println("EXCEPTION_FLT_DENORMAL_OPERAND")     
            case win32.EXCEPTION_FLT_DIVIDE_BY_ZERO: fmt.println("EXCEPTION_FLT_DIVIDE_BY_ZERO")     
            case win32.EXCEPTION_FLT_INEXACT_RESULT: fmt.println("EXCEPTION_FLT_INEXACT_RESULT")     
            case win32.EXCEPTION_FLT_INVALID_OPERATION: fmt.println("EXCEPTION_FLT_INVALID_OPERATION")     
            case win32.EXCEPTION_FLT_OVERFLOW: fmt.println("EXCEPTION_FLT_OVERFLOW")     
            case win32.EXCEPTION_FLT_STACK_CHECK: fmt.println("EXCEPTION_FLT_STACK_CHECK")     
            case win32.EXCEPTION_FLT_UNDERFLOW: fmt.println("EXCEPTION_FLT_UNDERFLOW")     
            case win32.EXCEPTION_ILLEGAL_INSTRUCTION: fmt.println("EXCEPTION_ILLEGAL_INSTRUCTION")     
            case win32.EXCEPTION_IN_PAGE_ERROR: fmt.println("EXCEPTION_IN_PAGE_ERROR")     
            case win32.EXCEPTION_INT_DIVIDE_BY_ZERO: fmt.println("EXCEPTION_INT_DIVIDE_BY_ZERO")     
            case win32.EXCEPTION_INT_OVERFLOW: fmt.println("EXCEPTION_INT_OVERFLOW")     
            case win32.EXCEPTION_INVALID_DISPOSITION: fmt.println("EXCEPTION_INVALID_DISPOSITION")     
            case win32.EXCEPTION_NONCONTINUABLE_EXCEPTION: fmt.println("EXCEPTION_NONCONTINUABLE_EXCEPTION")     
            case win32.EXCEPTION_PRIV_INSTRUCTION: fmt.println("EXCEPTION_PRIV_INSTRUCTION")     
            case win32.EXCEPTION_SINGLE_STEP: fmt.println("EXCEPTION_SINGLE_STEP")     
            case win32.EXCEPTION_STACK_OVERFLOW: fmt.println("EXCEPTION_STACK_OVERFLOW")     
            }

            // fmt.println("EXCEPTION_DEBUG_EVENT", debugEvent.u.Exception.ExceptionRecord.ExceptionCode)
        }
        case 5: {
            fmt.println("EXIT_PROCESS_DEBUG_EVENT")
            exitDebugger = true
        }
        case 4: fmt.println("EXIT_THREAD_DEBUG_EVENT")
        case 6: { // LOAD_DLL_DEBUG_EVENT
            read: uint
            imageNamePointer: uintptr
            win32.ReadProcessMemory(processInfo.hProcess, debugEvent.u.LoadDll.lpImageName, &imageNamePointer, size_of(uintptr), &read)

            dllNameBufferLength :: 255
            dllNameBuffer: [dllNameBufferLength]byte
            dllName: string
            win32.ReadProcessMemory(processInfo.hProcess, rawptr(imageNamePointer), raw_data(dllNameBuffer[:]), dllNameBufferLength, &read)

            if read != 0 {           
                isWide := debugEvent.u.LoadDll.fUnicode != 0
                
                if isWide {
                    dllName, _ = win32.wstring_to_utf8(win32.wstring(raw_data(dllNameBuffer[:])), int(read))
                    // fmt.printfln("Load DLL: %s (%#X)", dllName, debugEvent.u.LoadDll.lpBaseOfDll)
                } else {
                    dllName = string(dllNameBuffer[:])
                    // fmt.printfln("Load DLL: %s (%#X)", string(dllNameBuffer[:]), debugEvent.u.LoadDll.lpBaseOfDll)
                }
            }

            // read dos header
            dllBasePointer := uintptr(debugEvent.u.LoadDll.lpBaseOfDll)
            dosHeader: win32.IMAGE_DOS_HEADER
            win32.ReadProcessMemory(processInfo.hProcess, rawptr(dllBasePointer), &dosHeader, size_of(dosHeader), &read)

            peHeader: win32.IMAGE_NT_HEADERS64
            win32.ReadProcessMemory(processInfo.hProcess, rawptr(dllBasePointer + uintptr(dosHeader.e_lfanew)), &peHeader, size_of(peHeader), &read)
            
            exportDirectory: win32.IMAGE_EXPORT_DIRECTORY
            win32.ReadProcessMemory(processInfo.hProcess, rawptr(dllBasePointer + uintptr(peHeader.OptionalHeader.ExportTable.VirtualAddress)), 
                &exportDirectory, size_of(exportDirectory), &read)

            // get name of module through IMAGE_EXPORT_DIRECTORY
            win32.ReadProcessMemory(processInfo.hProcess, rawptr(dllBasePointer + uintptr(exportDirectory.Name)), 
                raw_data(dllNameBuffer[:]), dllNameBufferLength, &read)

            dllName = strings.clone(strings.truncate_to_byte(string(dllNameBuffer[:]), 0))

            // get list of functions
            functionsAddressesSize := exportDirectory.NumberOfFunctions * size_of(u32)
            functionsAddresses := make([]u32, exportDirectory.NumberOfFunctions)
            defer delete(functionsAddresses)
            win32.ReadProcessMemory(processInfo.hProcess, rawptr(dllBasePointer + uintptr(exportDirectory.AddressOfFunctions)),
                raw_data(functionsAddresses[:]), uint(functionsAddressesSize), &read)
            
            functionsNamesSize := exportDirectory.NumberOfNames * size_of(u32)
            functionsNames := make([]u32, exportDirectory.NumberOfNames)
            defer delete(functionsNames)
            win32.ReadProcessMemory(processInfo.hProcess, rawptr(dllBasePointer + uintptr(exportDirectory.AddressOfNames)),
                raw_data(functionsNames[:]), uint(functionsNamesSize), &read)
            
            functionsOrdinalsSize := exportDirectory.NumberOfNames * size_of(u16)
            functionsOrdinals := make([]u16, exportDirectory.NumberOfNames)
            defer delete(functionsOrdinals)
            win32.ReadProcessMemory(processInfo.hProcess, rawptr(dllBasePointer + uintptr(exportDirectory.AddressOfNameOrdinals)),
                raw_data(functionsOrdinals[:]), uint(functionsOrdinalsSize), &read)

            exportFunctions := make([dynamic]ExportFunction)
            for functionAddress, index in functionsAddresses {
                ordinalIndex := exportDirectory.Base + u32(index)
                // test := functionsAddresses[i * size_of(u32)]

                nameIndex: u32
                for ordinal, oIndex in functionsOrdinals {
                    if ordinal == u16(ordinalIndex) {
                        nameIndex = u32(oIndex)
                        break
                    }
                }

                if nameIndex != 0 {
                    nameAddress := dllBasePointer + uintptr(functionsNames[nameIndex])

                    functionNameBufferLength :: 255
                    functionNameBuffer: [functionNameBufferLength]byte
                    win32.ReadProcessMemory(processInfo.hProcess, rawptr(nameAddress), raw_data(functionNameBuffer[:]), functionNameBufferLength, &read)

                    functionName := strings.clone(strings.truncate_to_byte(string(functionNameBuffer[:]), 0))
                    append(&exportFunctions, ExportFunction{
                        name = functionName,
                        address = dllBasePointer + uintptr(functionAddress),
                    })
                    //fmt.println(functionName)
                }

                //fmt.println(functionAddress, ordinalIndex)
                test32 := functionAddress
            }
            
            // // private symbols
            // debugDirectory: win32.IMAGE_DEBUG_DIRECTORY
            // win32.ReadProcessMemory(processInfo.hProcess, rawptr(dllBasePointer + uintptr(peHeader.OptionalHeader.Debug.VirtualAddress)), 
            //     &debugDirectory, size_of(debugDirectory), &read)

            // debugDirectoriesCount := peHeader.OptionalHeader.Debug.Size / size_of(debugDirectory)
            
            // if debugDirectory.Type == win32.IMAGE_DEBUG_TYPE_CODEVIEW {
            //     pdbInfo: PdbInfo
            //     win32.ReadProcessMemory(processInfo.hProcess, rawptr(dllBasePointer + uintptr(debugDirectory.AddressOfRawData)), 
            //         &pdbInfo, size_of(pdbInfo), &read)
      
            //     pdbNameBuffer: [260]byte
            //     win32.ReadProcessMemory(processInfo.hProcess, rawptr(dllBasePointer + uintptr(debugDirectory.AddressOfRawData) + size_of(pdbInfo)), 
            //         raw_data(pdbNameBuffer[:]), 260, &read)
      
            //     test32 := string(pdbNameBuffer[:])
            //     test := 2
            // }

            fmt.printfln("Load DLL: %s (%#X)", dllName, dllBasePointer)
            append(&modules, Module{
                name = dllName,
                address = dllBasePointer,
                size = i32(peHeader.OptionalHeader.SizeOfImage),
                exportFunctions = exportFunctions,
            })
        }
        case 8: {
            fmt.println("OUTPUT_DEBUG_STRING_EVENT")

            length := uint(debugEvent.u.DebugString.nDebugStringLength) - 1
            isWide := debugEvent.u.DebugString.fUnicode != 0
            // strings.
            // test := cstring(debugEvent.u.DebugString.lpDebugStringData)

            test := make([]byte, length)
            defer delete(test)
            read: uint
            win32.ReadProcessMemory(processInfo.hProcess, debugEvent.u.DebugString.lpDebugStringData, raw_data(test[:]), length, &read)
            
            if isWide {
                fmt.println(win32.wstring_to_utf8(win32.wstring(raw_data(test[:])), int(length)))
            } else {
                fmt.println(string(test))
            }
        }
        case 9: fmt.println("RIP_EVENT")
        case 7: fmt.println("UNLOAD_DLL_DEBUG_EVENT")
        }

        if exitDebugger { break }

        // if sync.atomic_load(&windowData.debuggerCommand) == .STOP {
        //     sync.atomic_store(&windowData.debuggerCommand, .NONE)

        //     for {

        //     }
        // }

        // switch sync.atomic_load(&windowData.debuggerCommand) {
        // case .NONE:
        // case .CONTINUE:
        // case .STOP:
        // }

        //> set break testing breakpoint for all threads
        // for threadId in threadsIds {
            threadHandler2 := win32.OpenThread(
                win32.THREAD_GET_CONTEXT | win32.THREAD_SET_CONTEXT,
                false,
                debugEvent.dwThreadId,
            )
            defer win32.CloseHandle(threadHandler2)
            
            ctx2: win32.CONTEXT
            ctx2.ContextFlags = win32.WOW64_CONTEXT_ALL
            win32.GetThreadContext(threadHandler2, &ctx2)

            ctx2.Dr0 = win32.DWORD64(exeBaseAddress + uintptr(testFunctionRVA))
            ctx2.Dr7 |= 0x1

            ctx2.EFlags |= (1 << 16) // set resume flag
            // ctx.Dr7 |= (1 << 16)
            
            if !win32.SetThreadContext(threadHandler2, &ctx2) {
                // win32.GetLastError()
                fmt.println(win32.GetLastError())
                //panic("ERROR ")
            }
            // exeBaseAddress + uintptr(testFunctionRVA)
        // }
        //<

        threadHandler := win32.OpenThread(
            win32.THREAD_GET_CONTEXT | win32.THREAD_SET_CONTEXT,
            false,
            debugEvent.dwThreadId,
        )
        defer win32.CloseHandle(threadHandler)
        
        ctx: win32.CONTEXT
        ctx.ContextFlags = win32.WOW64_CONTEXT_ALL
        win32.GetThreadContext(threadHandler, &ctx)

        // addressToCheck := exeBaseAddress + uintptr(testFunctionRVA)
        addressToCheck := uintptr(ctx.Rip)
        for module in modules {
            startAddress := module.address 
            endAddress := module.address + uintptr(module.size)

            if addressToCheck >= startAddress && addressToCheck < endAddress {
                functionName: string
                minFunctionStartOffset := uintptr((1 << 64) - 1)
                for exportFunction in module.exportFunctions {
                    if addressToCheck >= exportFunction.address {
                        startOffset := addressToCheck - exportFunction.address

                        if minFunctionStartOffset > startOffset {
                            minFunctionStartOffset = startOffset
                            functionName = exportFunction.name
                        }
                    }
                }
                fmt.printfln("match %s %s %i", module.name, functionName, addressToCheck)
            }
        }
        // ctx.Rip

        //> testing
        for {
            if sync.atomic_load(&windowData.debuggerCommand) == .CONTINUE {
                sync.atomic_store(&windowData.debuggerCommand, .NONE)
                break
            }

            if sync.atomic_load(&windowData.debuggerCommand) == .STEP {
                sync.atomic_store(&windowData.debuggerCommand, .NONE)

                expectStepException = true
                ctx.EFlags |= 0x100
                if !win32.SetThreadContext(threadHandler, &ctx) {
                    panic("ASDASD")
                }
                break
            }

            if sync.atomic_load(&windowData.debuggerCommand) == .READ {
                sync.atomic_store(&windowData.debuggerCommand, .NONE)

                // win32.ReadProcessMemory()
                break
            }
        }
        //<

        //> render registers
        //fmt.println("rax: %i", ctx.Rax)
        //<

        ContinueDebugEvent(debugEvent.dwProcessId, debugEvent.dwThreadId, continueStatus)
    }

    // ok = DebugActiveProcess(processInfo.dwProcessId)

	// if !ok {
	// 	panic("FAILED")
	// }

    // win32.CloseHandle(processInfo.hProcess)
    win32.CloseHandle(processInfo.hThread)
}

test :: proc() {
    MAX_PROCESSES_COUNT :: 1024
    //DebugActiveProcess(0)

    processesIds: [MAX_PROCESSES_COUNT]win32.DWORD
    processesCount: win32.DWORD

    if !EnumProcesses(raw_data(processesIds[:]), 4 * MAX_PROCESSES_COUNT, &processesCount) {
        panic("YEAH>???!!!")
    }

    processesCount /= 4 // because of windows

    for processId in processesIds {
        test: [255]win32.WCHAR
        processHandle := win32.OpenProcess(win32.PROCESS_QUERY_INFORMATION | win32.PROCESS_VM_READ, false, processId)
        defer win32.CloseHandle(processHandle)

        if processHandle == nil { continue }
        
        hMod: win32.HMODULE // to get the first one
        modulesCount: win32.DWORD
        if !EnumProcessModules(processHandle, &hMod, size_of(hMod), &modulesCount) {
            // panic("YEAH>???!!!")
            continue
        }
        modulesCount /= 4 // because of windows

        GetModuleBaseNameW(processHandle, hMod, raw_data(test[:]), 255)

        fmt.println(win32.wstring_to_utf8(raw_data(test[:]), 255))
    }
    
    // win32.Deb
}