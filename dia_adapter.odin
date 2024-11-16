package main
import win32 "core:sys/windows"

// foreign import msdia140 "system:msdia140.lib"

SymTagEnum :: enum u32 {
    SymTagNull,
    SymTagExe,
    SymTagCompiland,
    SymTagCompilandDetails,
    SymTagCompilandEnv,
    SymTagFunction,
    SymTagBlock,
    SymTagData,
    SymTagAnnotation,
    SymTagLabel,
    SymTagPublicSymbol,
    SymTagUDT,
    SymTagEnum,
    SymTagFunctionType,
    SymTagPointerType,
    SymTagArrayType,
    SymTagBaseType,
    SymTagTypedef,
    SymTagBaseClass,
    SymTagFriend,
    SymTagFunctionArgType,
    SymTagFuncDebugStart,
    SymTagFuncDebugEnd,
    SymTagUsingNamespace,
    SymTagVTableShape,
    SymTagVTable,
    SymTagCustom,
    SymTagThunk,
    SymTagCustomType,
    SymTagManagedType,
    SymTagDimension,
    SymTagCallSite,
    SymTagInlineSite,
    SymTagBaseInterface,
    SymTagVectorType,
    SymTagMatrixType,
    SymTagHLSLType,
    SymTagCaller,
    SymTagCallee,
    SymTagExport,
    SymTagHeapAllocationSite,
    SymTagCoffGroup,
    SymTagInlinee,
    SymTagTaggedUnionCase, // a case of a tagged union UDT type
    SymTagMax
}

NameSearchOptions :: enum u32 {
    nsNone	= 0,
    nsfCaseSensitive	= 0x1,
    nsfCaseInsensitive	= 0x2,
    nsfFNameExt	= 0x4,
    nsfRegularExpression	= 0x8,
    nsfUndecoratedName	= 0x10,
    nsCaseSensitive	= nsfCaseSensitive,
    nsCaseInsensitive	= nsfCaseInsensitive,
    nsFNameExt	= ( nsfCaseInsensitive | nsfFNameExt ) ,
    nsRegularExpression	= ( nsfRegularExpression | nsfCaseSensitive ) ,
    nsCaseInRegularExpression	= ( nsfRegularExpression | nsfCaseInsensitive ) 
}

IDiaEnumSymbols_UUID_STRING :: "CAB72C48-443B-48f5-9B0B-42F0820AB29A"
IDiaEnumSymbols_UUID := &win32.IID{0xCAB72C48, 0x443B, 0x48f5, {0x9b, 0x0b, 0x42, 0xf0, 0x82, 0x0a, 0xb2, 0x9a}}
IDiaEnumSymbols :: struct #raw_union {
	#subtype iunknown: win32.IUnknown,
	using idiaenumsymbols_vtable: ^IDiaEnumSymbols_VTable,
}

IDiaEnumSymbols_VTable :: struct {
    using iunknown_vtable: win32.IUnknown_VTable,

    get__NewEnum: proc "system" (this: ^IDiaEnumSymbols, pRetVal: ^^win32.IUnknown) -> win32.HRESULT,
    get_Count: proc "system" (this: ^IDiaEnumSymbols, pRetVal: ^win32.LONG) -> win32.HRESULT,
    Item: proc "system" (this: ^IDiaEnumSymbols, index: win32.DWORD, symbol: ^^IDiaSymbol) -> win32.HRESULT,
    Next: proc "system" (this: ^IDiaEnumSymbols, celt: win32.ULONG, rgelt: ^^IDiaSymbol, pceltFetched: ^win32.ULONG) -> win32.HRESULT,
}

IDiaSymbol_UUID_STRING :: "cb787b2f-bd6c-4635-ba52-933126bd2dcd"
IDiaSymbol_UUID := &win32.IID{0xcb787b2f, 0xbd6c, 0x4635, {0xba, 0x52, 0x93, 0x31, 0x26, 0xbd, 0x2d, 0xcd}}
IDiaSymbol :: struct #raw_union {
	#subtype iunknown: win32.IUnknown,
	using idiasymbol_vtable: ^IDiaSymbol_VTable,
}

IDiaSymbol_VTable :: struct {
    using iunknown_vtable: win32.IUnknown_VTable,

    get_symIndexId: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_symTag: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_name: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BSTR) -> win32.HRESULT, 
    get_lexicalParent: proc "system" (this: ^IDiaSymbol, pRetVal: ^^IDiaSymbol) -> win32.HRESULT, 
    get_classParent: proc "system" (this: ^IDiaSymbol, pRetVal: ^^IDiaSymbol) -> win32.HRESULT, 
    get_type: proc "system" (this: ^IDiaSymbol, pRetVal: ^^IDiaSymbol) -> win32.HRESULT, 
    get_dataKind: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_locationType: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_addressSection: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_addressOffset: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_relativeVirtualAddress: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_virtualAddress: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.ULONGLONG) -> win32.HRESULT, 
    get_registerId: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_offset: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.LONG) -> win32.HRESULT, 
    get_length: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.ULONGLONG) -> win32.HRESULT, 
    get_slot: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_volatileType: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_constType: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_unalignedType: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_access: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_libraryName: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BSTR) -> win32.HRESULT, 
    get_platform: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_editAndContinueEnabled: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_frontEndMajor: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_frontEndMinor: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_frontEndBuild: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_backEndMajor: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_backEndMinor: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_backEndBuild: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_sourceFileName: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BSTR) -> win32.HRESULT, 
    get_unused: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BSTR) -> win32.HRESULT, 
    get_thunkOrdinal: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_thisAdjust: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.LONG) -> win32.HRESULT, 
    get_virtualBaseOffset: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_virtual: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_intro: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_pure: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_callingConvention: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_value: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, /// it should be win32.VARIANT instead of win32.DWORD !!!!!!!
    get_baseType: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_token: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_timeStamp: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_guid: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.GUID) -> win32.HRESULT, 
    get_symbolsFileName: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BSTR) -> win32.HRESULT, 
    get_reference: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_count: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_bitPosition: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_arrayIndexType: proc "system" (this: ^IDiaSymbol, pRetVal: ^^IDiaSymbol) -> win32.HRESULT, 
    get_packed: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_constructor: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_overloadedOperator: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_nested: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_hasNestedTypes: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_hasAssignmentOperator: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_hasCastOperator: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_scoped: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_virtualBaseClass: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_indirectVirtualBaseClass: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_virtualBasePointerOffset: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.LONG) -> win32.HRESULT, 
    get_virtualTableShape: proc "system" (this: ^IDiaSymbol, pRetVal: ^^IDiaSymbol) -> win32.HRESULT, 
    get_lexicalParentId: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_classParentId: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_typeId: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_arrayIndexTypeId: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_virtualTableShapeId: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_code: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_function: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_managed: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_msil: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_virtualBaseDispIndex: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_undecoratedName: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BSTR) -> win32.HRESULT, 
    get_age: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_signature: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_compilerGenerated: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_addressTaken: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.BOOL) -> win32.HRESULT, 
    get_rank: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_lowerBound: proc "system" (this: ^IDiaSymbol, pRetVal: ^^IDiaSymbol) -> win32.HRESULT, 
    get_upperBound: proc "system" (this: ^IDiaSymbol, pRetVal: ^^IDiaSymbol) -> win32.HRESULT, 
    get_lowerBoundId: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_upperBoundId: proc "system" (this: ^IDiaSymbol, pRetVal: ^win32.DWORD) -> win32.HRESULT, 
    get_dataBytes: proc "system" (this: ^IDiaSymbol, cbData: win32.DWORD, pcbData: ^win32.DWORD, pbData: ^win32.BYTE) -> win32.HRESULT, 

    findChildren: proc "system" (this: ^IDiaSymbol, symtag: SymTagEnum, name: win32.LPCOLESTR,
        compareFlags: win32.DWORD, ppResult: ^^IDiaEnumSymbols) -> win32.HRESULT,

    findChildrenEx: proc "system" (this: ^IDiaSymbol, symtag: SymTagEnum, name: win32.LPCOLESTR,
        compareFlags: win32.DWORD, ppResult: ^^IDiaEnumSymbols) -> win32.HRESULT,

    findChildrenExByAddr: proc "system" (this: ^IDiaSymbol, symtag: SymTagEnum, name: win32.LPCOLESTR,
        compareFlags, isect, offset: win32.DWORD, ppResult: ^^IDiaEnumSymbols) -> win32.HRESULT,

    findChildrenExByVA: proc "system" (this: ^IDiaSymbol, symtag: SymTagEnum, name: win32.LPCOLESTR,
        compareFlags: win32.DWORD, va: win32.ULONGLONG, ppResult: ^^IDiaEnumSymbols) -> win32.HRESULT,

    findChildrenExByRVA: proc "system" (this: ^IDiaSymbol, symtag: SymTagEnum, name: win32.LPCOLESTR,
        compareFlags: win32.DWORD, rva: win32.ULONGLONG, ppResult: ^^IDiaEnumSymbols) -> win32.HRESULT,
}

IDiaSession_UUID_STRING :: "2F609EE1-D1C8-4E24-8288-3326BADCD211"
IDiaSession_UUID := &win32.IID{0x2F609EE1, 0xD1C8, 0x4E24, {0x82, 0x88, 0x33, 0x26, 0xBA, 0xDC, 0xD2, 0x11}}
IDiaSession :: struct #raw_union {
	#subtype iunknown: win32.IUnknown,
	using idiasession_vtable: ^IDiaSession_VTable,
}

IDiaSession_VTable :: struct {
	using iunknown_vtable: win32.IUnknown_VTable,

    get_loadAddress: proc "system" (this: ^IDiaSession, pRetVal: ^win32.ULONGLONG) -> win32.HRESULT,
    
    put_loadAddress: proc "system" (this: ^IDiaSession, NewVal: win32.ULONGLONG) -> win32.HRESULT,

    get_globalScope: proc "system" (this: ^IDiaSession, pRetVal: ^^IDiaSymbol) -> win32.HRESULT,
}

DiaSource_UUID_STRING :: "e6756135-1e65-4d17-8576-610761398c3c"
DiaSource_UUID := &win32.IID{0xe6756135, 0x1e65, 0x4d17, {0x85, 0x76, 0x61, 0x07, 0x61, 0x39, 0x8c, 0x3c}}

IDiaDataSource_UUID_STRING :: "79F1BB5F-B66E-48e5-B6A9-1545C323CA3D"
IDiaDataSource_UUID := &win32.IID{0x79F1BB5F, 0xB66E, 0x48e5, {0xB6, 0xA9, 0x15, 0x45, 0xC3, 0x23, 0xCA, 0x3D}}
IDiaDataSource :: struct #raw_union {
	#subtype iunknown: win32.IUnknown,
	using idiadatasource_vtable: ^IDiaDataSource_VTable,
}

IDiaDataSource_VTable :: struct {
	using iunknown_vtable: win32.IUnknown_VTable,
    get_lastError: proc "system" (this: ^IDiaDataSource, pRetVal: ^win32.BSTR) -> win32.HRESULT,
	
    loadDataFromPdb: proc "system" (this: ^IDiaDataSource, pdbPath: win32.LPCOLESTR) -> win32.HRESULT,
	
    loadAndValidateDataFromPdb: proc "system" (this: ^IDiaDataSource, pdbPath: win32.LPCOLESTR, 
        pcsig70: ^win32.GUID, sig: win32.DWORD, age: win32.DWORD) -> win32.HRESULT,
    
    loadDataForExe: proc "system" (this: ^IDiaDataSource, executable, searchPath: win32.LPCOLESTR, pCallback: ^win32.IUnknown) -> win32.HRESULT,

    loadDataFromIStream: proc "system" (this: ^IDiaDataSource, pIStream: ^win32.IStream) -> win32.HRESULT,
    
    openSession: proc "system" (this: ^IDiaDataSource, ppSession: ^^IDiaSession) -> win32.HRESULT,

    loadDataFromCodeViewInfo: proc "system" (this: ^IDiaDataSource, executable, searchPath: win32.LPCOLESTR, 
        cbCvInfo: win32.DWORD, pbCvInfo: ^win32.BYTE, pCallback: ^win32.IUnknown) -> win32.HRESULT,

    loadDataFromMiscInfo: proc "system" (this: ^IDiaDataSource, executable, searchPath: win32.LPCOLESTR, 
        timeStampExe, timeStampDbg, sizeOfExe, cbMiscInfo: win32.DWORD, 
        pbMiscInfo: ^win32.BYTE, 
        pCallback: ^win32.IUnknown) -> win32.HRESULT,
}

testDia :: proc() -> u32 {
    dataSource: ^IDiaDataSource
    win32.CoInitialize(nil)
    hr := win32.CoCreateInstance(DiaSource_UUID, nil, win32.CLSCTX_INPROC_SERVER, IDiaDataSource_UUID, cast(^win32.LPVOID)(&dataSource))

    path := win32.utf8_to_wstring("C:\\projects\\cpp_test_cmd\\x64\\Debug\\cpp_test_cmd.pdb")
    hr = dataSource->loadDataFromPdb(transmute(win32.LPCOLESTR)(path))
    // dataSource->Release();

    dataSession: ^IDiaSession
    hr = dataSource->openSession(&dataSession)

    pGlobal: ^IDiaSymbol
    hr = dataSession->get_globalScope(&pGlobal)
    
    // print all functions
    // tst32: win32.DWORD
    // hr = pGlobal->get_upperBoundId(&tst32)
    // test2 := win32.GetLastError()

    diaEnumSymbols: ^IDiaEnumSymbols
    hr = pGlobal->findChildrenEx(.SymTagFunction, nil, 0, &diaEnumSymbols) // TODO: findChildren returns 0x80070057, which is super weird!!!
    // test2 := win32.GetLastError()

    pFunction: ^IDiaSymbol
    celt: win32.ULONG = 0

    functions := make(map[string]u32)
    for {        
        hr = diaEnumSymbols->Next(1, &pFunction, &celt)

        if hr != 0 || celt != 1 {
            break
        }
        bstrName: win32.BSTR
        hr = pFunction->get_name(&bstrName)

        rva: win32.DWORD
        pFunction->get_relativeVirtualAddress(&rva)

        path2, _ := win32.wstring_to_utf8(win32.wstring(bstrName), -1)
        functions[path2] = rva
    }
    
    return functions["test"]
}