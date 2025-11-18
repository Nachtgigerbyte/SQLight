; SQLight.ahk
#Requires Autohotkey v2.0+  

/********************************************************************
*
*	Name:			SQLight <nachtgigerbyte@proton.me>
*	Version: 		1.2.22
*	Description:	Interface to SQLite3's dynamic link library.
*
*	Tests:
*			OS: 				Windows 10 pro (x64)
*			AutoHotkey64:		Version 2.0.19 
*			sqlite3.dll:		Version 3.50.4
*			Testframework:		Yunit
*			Test file:			\tests\SQLight_test.ahk
*			Tested files:		SQLight.ahk
*
*	This software is provided as it is. You are free to use it, 
*	but there are no warranties nor guarantees.
*
********************************************************************/

SQLIGHT_SQLITE_VERSION := '>=3.50.4'

/* --- SQLITE --- */
SQLITE_OK                             := 0                          ; Successful result
SQLITE_ERROR                          := 1                          ; Generic error
SQLITE_BUSY                           := 5                          ; The database file is locked
SQLITE_LOCKED                         := 6                          ; A table in the database is locked
SQLITE_ROW                            := 100                        ; sqlite3_step() has another row ready
SQLITE_DONE                           := 101                        ; sqlite3_step() has finished executing

/* open flags */
SQLITE_OPEN_READONLY                  := 0x00000001                 ; Ok for sqlite3_open_v2()
SQLITE_OPEN_READWRITE                 := 0x00000002                 ; Ok for sqlite3_open_v2()
SQLITE_OPEN_CREATE                    := 0x00000004                 ; Ok for sqlite3_open_v2()
SQLITE_OPEN_DELETEONCLOSE             := 0x00000008                 ; VFS only
SQLITE_OPEN_EXCLUSIVE                 := 0x00000010                 ; VFS only
SQLITE_OPEN_AUTOPROXY                 := 0x00000020                 ; VFS only
SQLITE_OPEN_URI                       := 0x00000040                 ; Ok for sqlite3_open_v2()
SQLITE_OPEN_MEMORY                    := 0x00000080                 ; Ok for sqlite3_open_v2()
SQLITE_OPEN_MAIN_DB                   := 0x00000100                 ; VFS only
SQLITE_OPEN_TEMP_DB                   := 0x00000200                 ; VFS only
SQLITE_OPEN_TRANSIENT_DB              := 0x00000400                 ; VFS only
SQLITE_OPEN_MAIN_JOURNAL              := 0x00000800                 ; VFS only
SQLITE_OPEN_TEMP_JOURNAL              := 0x00001000                 ; VFS only
SQLITE_OPEN_SUBJOURNAL                := 0x00002000                 ; VFS only
SQLITE_OPEN_SUPER_JOURNAL             := 0x00004000                 ; VFS only
SQLITE_OPEN_NOMUTEX                   := 0x00008000                 ; Ok for sqlite3_open_v2()
SQLITE_OPEN_FULLMUTEX                 := 0x00010000                 ; Ok for sqlite3_open_v2()
SQLITE_OPEN_SHAREDCACHE               := 0x00020000                 ; Ok for sqlite3_open_v2()
SQLITE_OPEN_PRIVATECACHE              := 0x00040000                 ; Ok for sqlite3_open_v2()
SQLITE_OPEN_WAL                       := 0x00080000                 ; VFS only
SQLITE_OPEN_NOFOLLOW                  := 0x01000000                 ; Ok for sqlite3_open_v2()
SQLITE_OPEN_EXRESCODE                 := 0x02000000                 ; Extended result codes
SQLITE_OPEN_MASTER_JOURNAL            := 0x00004000                 ; VFS only

/* column data types */
SQLITE_INTEGER 	:= 1
SQLITE_FLOAT  	:= 2
SQLITE_TEXT  	:= 3
SQLITE_BLOB  	:= 4
SQLITE_NULL   	:= 5

/* bind mode */
SQLITE_STATIC 		:= 0
SQLITE_TRANSIENT   	:= -1

/* --- SQLight --- */
SQLIGHT_OK	   			:= 0xFFFF
SQLIGHT_ERROR			:= SQLIGHT_OK + 1
SQLIGHT_NO_CONNECTION	:= SQLIGHT_OK + 2
SQLIGHT_NO_STATEMENT	:= SQLIGHT_OK + 3
SQLIGHT_INVALID_TYPE  	:= SQLIGHT_OK + 4
SQLIGHT_INVALID_VALUE 	:= SQLIGHT_OK + 5
SQLIGHT_TIMEOUT			:= SQLIGHT_OK + 6

/* row datatypes */
SQLIGHT_ROW_MAP		:= 0
SQLIGHT_ROW_ARRAY	:= 1


/*	
	A light interface to SQLite3. Each instance of the object can be 
	considered a database connection.
*/
class SQLight  {	
	
	/* this file's dir */
	static FileDir := 0
	; path to splite3.dll file
	static sqlite3_dll := ''
	; handle to splite3.dll module
	static hDll := 0
	/* bind mode */
	static BIND_MODE := SQLITE_TRANSIENT
	
	; handle to database
	hDB := 0
	; current statement handle 
	hStmt := 0
	; last temp statement 
	hStmt_tmp := 0
	; saved statements
	Stmts := Array()
		
	status := 0
	error { 
		get {	
			if (this.status < SQLIGHT_OK) 
				return SQLight._sqlite_errmsg(this.status, this.hDB)
			else 
				return SQLight._sqlight_errmsg(this.status)
		}
	}
	
	static _sqlite_errmsg(stat, hdb) {
		_errmsg_last := hdb ? SQLight._errmsg(hdb) : ''
		return Format('[Status]: {1}: {2}: [Last Error]: {3}', stat, SQLight._errstr(stat), _errmsg_last) 
	}	
	static _sqlight_errmsg(stat) {
		return Format('[Status]: {1}: {2}', stat, SQLight._sqlight_errstr(stat)) 
	}	
	static _sqlight_errstr(stat) {
		switch stat {
			case SQLIGHT_OK: 			return 'Ok.'
			case SQLIGHT_ERROR:			return 'Sqlight error.'
			case SQLIGHT_NO_CONNECTION: return 'No database connected, handle invalid.'
			case SQLIGHT_NO_STATEMENT:	return 'No statement to operate on.'
			case SQLIGHT_INVALID_TYPE: 	return 'Invalid type.'
			case SQLIGHT_INVALID_VALUE:	return 'Invalid value.'
			default: 					return 'Unknown error.'
		}
	}
	
	; copies an ahk-string into a raw buffer equivalent and returns that buffer
	static _StrToBuf(str, enc := 'UTF-8') { 
		buf := Buffer(StrPut(str, enc))
		StrPut(str, buf, enc)
		return buf
	}

	/* returns: module handle, 0 if failed */
	static _LoadLibrary(path) => DllCall('LoadLibrary', 'Str', path, 'Cdecl Ptr')	
	static _FreeLibrary(h) => DllCall('FreeLibrary', 'Ptr', h)
	static _sourceid() => StrGet(DllCall(SQLight.sqlite3_dll '\sqlite3_sourceid', 'Cdecl Ptr'), 'UTF-8')
	static _libversion() => StrGet(DllCall(SQLight.sqlite3_dll '\sqlite3_libversion', 'Cdecl Ptr'), 'UTF-8')
	static _libversion_number() => DllCall(SQLight.sqlite3_dll '\sqlite3_libversion_number', 'Cdecl Int')	
	
	/* get error string by `sqlite3` result code */
	static _errstr(rc) => StrGet(DllCall(SQLight.sqlite3_dll '\sqlite3_errstr', 'Int', rc, 'Cdecl Ptr'), 'UTF-8')
	/* returns last error message */
	static _errmsg(h) => StrGet(DllCall(SQLight.sqlite3_dll '\sqlite3_errmsg', 'Ptr', h, 'Cdecl Ptr'), 'UTF-8')	
	/* returns last error code */
	static _errcode(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_errcode', 'Ptr', h, 'Cdecl Int')
	/* returns last extended error code */
	static _extended_errcode(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_extended_errcode', 'Ptr', h, 'Cdecl Int')
	
	/* open database, db = database file, h = receives db handle */
	static _open_v2(db, &h, flags) => DllCall(SQLight.sqlite3_dll '\sqlite3_open_v2', 'Ptr', SQLight._StrToBuf(db), 'Ptr*', &h, 'Int', flags, 'Ptr', 0, 'Cdecl Int')
	/* returns result code */
	static _close_v2(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_close_v2', 'Ptr', h, 'Cdecl')
	/* sets a busy handler, time to wait until SQLITE_BUSY is returned; h = handle to database, ms = milliseconds */
	static _busy_timeout(h, ms) => DllCall(SQLight.sqlite3_dll '\sqlite3_busy_timeout', 'Ptr', h, 'Int', ms, 'Cdecl Int')
		
	/* execute sql, h = handle to db */
	static _exec(hdb, sql) => DllCall(SQLight.sqlite3_dll '\sqlite3_exec','Ptr', hdb, 'Ptr', SQLight._StrToBuf(sql), 'Ptr', 0, 'Ptr', 0, 'Ptr*', 0, 'Cdecl Int')
	/* get table, 'errmsg' parameter omitted due to similarity of `_errmsg()` implementation on this.error.get(), and therefore not needed */
	static _get_table(hdb, sql, &res, &n, &m) => DllCall(SQLight.sqlite3_dll '\sqlite3_get_table', 'Ptr', hdb, 'Ptr', SQLight._StrToBuf(sql), 'Ptr*', &res, 'Int*', &n, 'Int*', &m, 'Ptr*', 0, 'Cdecl Int')
	static _get_table_ex(hdb, sql, &tbl?, mode := SQLIGHT_ROW_MAP) {
		if (ret := SQLight._get_table(hdb, sql, &ptr := 0, &n := 0, &m := 0))
			return ret
		; check for results
		if (!n) {
			tbl := ''
			return ret
		}	
		col := Array()		
		item := 0
		loop m 
			col.Push(StrGet(NumGet(ptr, item++ * A_PtrSize, 'Ptr'), 'UTF-8'))
		rows := Array()
		loop n {
			rec := mode ? Array() : Map()
			if (mode)
				rec.Length := m
			loop m {
				ix := mode ? A_Index : col[A_Index]
				v := NumGet(ptr, item++ * A_PtrSize, 'Ptr') 
				v := v ? StrGet(v, 'UTF-8') : ''
				rec[ix] := v
			}
			rows.Push(rec)
		}			
		SQLight._free_table(ptr)
		tbl := rows
		return ret
	}
	/* free table */
	static _free_table(p) => DllCall(SQLight.sqlite3_dll '\sqlite3_free_table', 'Ptr', p, 'Cdecl')
	static _free(s) => DllCall(SQLight.sqlite3_dll '\sqlite3_free', 'Ptr', s, 'Cdecl')
	
	/* returns sqlite return code, h = handle to database, h_stmt = received statement handle */
	static _prepare_v2(hdb, sql, &h_stmt) => DllCall(SQLight.sqlite3_dll '\sqlite3_prepare_v2', 'Ptr', hdb, 'Ptr', SQLight._StrToBuf(sql), 'Int', -1, 'Ptr*', &h_stmt, 'Ptr', 0, 'Cdecl Int')
	/* returns sqlite return code, h = handle to statement */
	static _bind_blob(h, i, v) => DllCall(SQLight.sqlite3_dll '\sqlite3_bind_blob', 'Ptr', h, 'Int', i, 'Ptr', v.Ptr, 'Int', v.Size, 'Ptr', SQLight.BIND_MODE, 'Cdecl Int')
	static _bind_int64(h, i, v) => DllCall(SQLight.sqlite3_dll '\sqlite3_bind_int64', 'Ptr', h, 'Int', i, 'Int64', v, 'Cdecl Int')
	static _bind_double(h, i, v) => DllCall(SQLight.sqlite3_dll '\sqlite3_bind_double', 'Ptr', h, 'Int', i, 'Double', v, 'Cdecl Int')
	static _bind_text(h, i, v) => DllCall(SQLight.sqlite3_dll '\sqlite3_bind_text', 'Ptr', h, 'Int', i, 'Ptr', SQLight._StrToBuf(v), 'Int', -1, 'Ptr', SQLight.BIND_MODE, 'Cdecl Int')
	static _bind_ex(h, var*) {
		ret := 0
		loop var.Length {
			v := var[A_Index]
			switch type(v) { 
				case 'Buffer': 	ret := DllCall(SQLight.sqlite3_dll '\sqlite3_bind_blob', 'Ptr', h, 'Int', A_Index, 'Ptr', v.Ptr, 'Int', v.Size, 'Ptr', SQLight.BIND_MODE, 'Cdecl Int')
				case 'Integer': ret := DllCall(SQLight.sqlite3_dll '\sqlite3_bind_int64', 'Ptr', h, 'Int', A_Index, 'Int64', v, 'Cdecl Int')
				case 'Float':	ret := DllCall(SQLight.sqlite3_dll '\sqlite3_bind_double', 'Ptr', h, 'Int', A_Index, 'Double', v, 'Cdecl Int')
				case 'String':	ret := DllCall(SQLight.sqlite3_dll '\sqlite3_bind_text', 'Ptr', h, 'Int', A_Index, 'Ptr', SQLight._StrToBuf(v), 'Int', -1, 'Ptr', SQLight.BIND_MODE, 'Cdecl Int')
				default:		return SQLIGHT_INVALID_TYPE
			}	
			if (ret)
				return ret
		}
		return ret
	}
	/* reset result pointer of the prepared statement, returns sqlite return code, h = handle to statement */
	static _reset(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_reset', 'Ptr', h, 'Cdecl Int')
	static _reset_ex(h) {
		ret := 0
		loop 2 {
			ret := DllCall(SQLight.sqlite3_dll '\sqlite3_reset', 'Ptr', h, 'Cdecl Int')
			if (ret = SQLITE_OK)
				return ret
		}
		return ret
	}
	/* clear bound SQL parameter values, returns sqlite return code, h = handle to statement */
	static _clear_bindings(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_clear_bindings', 'Ptr', h, 'Cdecl Int')
	/* free the prepared statement, returns sqlite return code, h = handle to statement */
	static _finalize(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_finalize', 'Ptr', h, 'Cdecl Int')
	static _free_stmt(h) {
		ret := SQLITE_OK
		if (h) {
			ret := DllCall(SQLight.sqlite3_dll '\sqlite3_finalize', 'Ptr', h, 'Cdecl Int')
		}
		return ret
	}
	/* execute the statement and get next row of the query result if available, returns sqlite return code, h = handle to statement */
	static _step(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_step', 'Ptr', h, 'Cdecl Int')
	/* returns column count, h = handle to statement */
	static _column_count(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_column_count', 'Ptr', h, 'Cdecl Int')
	/* returns column name string, h = handle to statement */
	static _column_name(h, i) => StrGet(DllCall(SQLight.sqlite3_dll '\sqlite3_column_name', 'Ptr', h, 'Int', i, 'Cdecl UPtr'), 'UTF-8')	
	/* returns number of columns in row, h = handle to statement */
	static _data_count(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_data_count', 'Ptr', h, 'Cdecl Int')
	/* returns column data type, h = handle to statement, i = column index starting from 0 */
	static _column_type(h, i) => DllCall(SQLight.sqlite3_dll '\sqlite3_column_type', 'Ptr', h, 'Int', i, 'Cdecl Int')
	
	/* returns address(pointer) to the blob, h = handle to statement, i = column index starting from 0 */ 
	static _column_blob(h, i) => DllCall(SQLight.sqlite3_dll '\sqlite3_column_blob', 'Ptr', h, 'Int', i, 'Cdecl UPtr')	
	/* returns blob size, h = handle to statement, i = column index starting from 0 */ 
	static _column_bytes(h, i) => DllCall(SQLight.sqlite3_dll '\sqlite3_column_bytes', 'Ptr', h, 'Int', i, 'Cdecl Int')
	/* moves blob to buffer, `from` is a pointer from `_column_blob()`, `from_size` is size from `_column_bytes()` */
	static _RtlMoveMemory(to_buf, from, from_size) => DllCall('Kernel32.dll\RtlMoveMemory', 'Ptr', to_buf, 'Ptr', from, 'Ptr', from_size)
	/* returns buffer that conatins blob, if blob is NULL, '' is returned */
	static _column_blob_to_buf(h, i) {
		blob := DllCall(SQLight.sqlite3_dll '\sqlite3_column_blob', 'Ptr', h, 'Int', i, 'Cdecl UPtr')
		if (!blob)
			return ''
		blob_size := DllCall(SQLight.sqlite3_dll '\sqlite3_column_bytes', 'Ptr', h, 'Int', i, 'Cdecl Int')
		buf := Buffer(blob_size)
		DllCall('Kernel32.dll\RtlMoveMemory', 'Ptr', buf, 'Ptr', blob, 'Ptr', blob_size)
		return buf
	}	
	/* returns integer from column index, h = handle to statement, i = column index starting from 0 */ 
	static _column_int64(h, i) => DllCall(SQLight.sqlite3_dll '\sqlite3_column_int64', 'Ptr', h, 'Int', i, 'Cdecl Int64')
	/* returns double from column index, h = handle to statement, i = column index starting from 0 */ 
	static _column_double(h, i) => DllCall(SQLight.sqlite3_dll '\sqlite3_column_double', 'Ptr', h, 'Int', i, 'Cdecl Double')
	/* returns string from column index, h = handle to statement, i = column index starting from 0 */ 
	static _column_text(h, i) => StrGet(DllCall(SQLight.sqlite3_dll '\sqlite3_column_text', 'Ptr', h, 'Int', i, 'Cdecl UPtr'), 'UTF-8')
	static _column_value_ex(h, i) {
		switch SQLight._column_type(h, i) {
			case SQLITE_NULL:		return ''
			case SQLITE_BLOB: 		return SQLight._column_blob_to_buf(h, i)
			case SQLITE_INTEGER: 	return DllCall(SQLight.sqlite3_dll '\sqlite3_column_int64', 'Ptr', h, 'Int', i, 'Cdecl Int64')
			case SQLITE_FLOAT:		return DllCall(SQLight.sqlite3_dll '\sqlite3_column_double', 'Ptr', h, 'Int', i, 'Cdecl Double')
			case SQLITE_TEXT: 		return StrGet(DllCall(SQLight.sqlite3_dll '\sqlite3_column_text', 'Ptr', h, 'Int', i, 'Cdecl UPtr'), 'UTF-8')
			default:				return StrGet(DllCall(SQLight.sqlite3_dll '\sqlite3_column_text', 'Ptr', h, 'Int', i, 'Cdecl UPtr'), 'UTF-8')									
		}
	}	
	/* 
		RETURNS: 	column count: 
						>0: `row` has received row
						0: no columns, which may indicate a non `SQLITE_ROW` result from `step()`
	*/
	static _row_get(h, &row, mode := SQLIGHT_ROW_MAP) {
		col_count := SQLight._data_count(h)		; returns 0 if statement does not have results to return
		if (!col_count) {
			return col_count
		}	
		rec := mode ? Array() : Map()
		if (mode)
			rec.Length := col_count
        loop col_count {
			i := A_Index - 1
			ix := mode ? A_Index : SQLight._column_name(h, i)
			rec[ix] := SQLight._column_value_ex(h, i)
        }
		row := rec	
		return col_count
	}	
	
	static _load_sqlite(dll) {
		; load library, if not already loaded
		if (SQLight.hDll)
			return 
		_dll := dll
		if (!_dll) {
			paths := [ '', '\lib', '\lib\bin']
			for p in paths {
				p := SQLight.FileDir p '\sqlite3.dll'
				if (FileExist(p)) {
					_dll := p
					break
				}	
			}	
		}	
		if (!FileExist(_dll))
			throw ValueError('Dll not found.', -1, 'File not found: ' _dll)
		SQLight.sqlite3_dll := _dll	
		SQLight.hDll := SQLight._LoadLibrary(SQLight.sqlite3_dll)
		if (!SQLight.hDll)
			throw OSError(A_LastError, -1, 'LoadLibrary')	
		; loaded, check version
		ver := SQLight._libversion()
		if (!VerCompare(ver, SQLIGHT_SQLITE_VERSION)) {
			SQLight.FreeLibrary()
			SplitPath SQLight.sqlite3_dll, &fname
			throw Error(Format('`{1}` version `{2}` not supported.', fname, ver), -1, SQLIGHT_SQLITE_VERSION)
		}	
	}
	
	static FreeLibrary() {
		if (SQLight.hDll) {
			SQLight._FreeLibrary(SQLight.hDll)
			SQLight.hDll := 0
		}	
	}
		
	/*
		Constructor.
		
		`db`:	the database to connect:
					path to an sqlite database file;
					an empty string '' which creates a temporary anonymous disk file;
					special string ':memory:' which is an in-memory database that 
					only exists for the duration of the session
		`flags`:		OR'ed combination of `SQLITE_OPEN_*`-flags (above)
		`dll`:	path to sqlite3.dll-file;
				if 0 or an empty string, following locations are searched, relative to the folder where 
				`SQLight.ahk` is placed into, in this order:
					'\sqlite3.dll'
					'\lib\sqlite3.dll'
					'\lib\bin\sqlite3.dll'
	*/	
	__New(	db := 0, 
			flags := SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, 
			dll := 0
		) {	
		if (!SQLight.FileDir) {
			SplitPath A_LineFile, &file, &dir
			SQLight.FileDir := dir
		}
		SQLight._load_sqlite(dll)	
		if (db)
			this.Connect(db, flags)
	}	
	__Delete() {
		this.Disconnect()
		/*
			free dll, is usually done by OS at prog-exit;
			use `SQLight.FreeLibrary()` to do it manually
		*/
	}	
	
	_set_hDB(h) {
		if (this.hDB) {
			if (this.status := SQLight._close_v2(this.hDB))
				return false
		}
		if (!this._set_hStmt_tmp(0))
			return false
		if (!this.ClearSaved())
			return false
		this.hStmt := 0
		this.hDB := h
		return true
	}
	
	_set_hStmt_tmp(h) {
		if (this.status := SQLight._free_stmt(this.hStmt_tmp))
			return false
		this.hStmt_tmp := h	
		return true
	}
	
	/*
		Sets internal busy handler, time to wait until SQLITE_BUSY is returned
		`ms`:	if <=0, all busy handlers are turned off, otherwise time in milliseconds
	*/
	SetBusyHandler(ms) {
		if (this.status := SQLight._busy_timeout(this.hDB, ms))
			return false
		return true
	}
	
	/*
		Connect database.
		
		`db`:		the database to connect:
						path to an sqlite database file;
						an empty string '' which creates a temporary anonymous disk file;
						special string ':memory:' which is an in-memory database that 
						only exists for the duration of the session
		`flags`:	OR'ed combination of `SQLITE_OPEN_*`-flags (above)
		`timeout_ms`: 	refer to `SetBusyHandler()` 
		
		RETURNS: 	`true` on success
					`false` otherwise
	*/	
	Connect(db, flags := SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, timeout_ms := 5555) {
		h := 0
		this.status := SQLight._open_v2(db, &h, flags)
		if (this.status) 
			throw Error(this.error, -1) 
		if (!h)
			throw OSError('Memory error, invalid handle.', -1)	
		if (!this._set_hDB(h))	
			return false
		if (!this.SetBusyHandler(timeout_ms))
			return false
		return true
	}
	
	/*
		Disconnect database.
		RETURNS: 	`true` on success
					`false` otherwise
	*/
	Disconnect() {
		if (!this._set_hDB(0))
			return false
		return true
	}
		
	/*
		Execute `sql` directly, and get the results if any.
		This method can NOT use placeholders `?`, use `Load()`, `Go()` instead. 
		All results received by this method are of type `String`, 
		number columns like `INT64` and `REAL` are converted to text too. Blob columns 
		are converted, but break at the first zero string terminator and therefore 
		its not recommended to receive blob columns with this method, except they are not 
		accessed/needed in subsequent operations.
		
		`sql`: 	the sql to execute
		`tbl`:		if defined and if results available, this parameter receives a result table,
					which is an `Array()` whose elements datatype is defined by `mode`;
					if defined and if no result is available, this parameter receives an 
					empty string
		`mode`:	determins the datatype of the elements in `tbl`-Array(), 
				which is of type:
					`Map()`, if `mode` is `SQLIGHT_ROW_MAP`
					`Array()`, if `mode` is `SQLIGHT_ROW_ARRAY`
					
		RETURNS:	true on success, false otherwise
	*/
	Now(sql, &tbl?, mode := SQLIGHT_ROW_MAP) {	
		if (!this.hDB) {
			this.status := SQLIGHT_NO_CONNECTION
			throw ValueError(this.error, -1, this.hDB)
		}	
		if (this.status := SQLight._get_table_ex(this.hDB, sql, &tbl, mode))
			return false
		return true
	}
		
	/*
		Save `sql`-patterns for later use
		
		`sql`:	the sql to save, can take placeholder `?` ready to be used by `Load()`
		
		RETURNS: 	index(integer) where the statement had been saved, 
					-1 otherwise (check `this.status`, `this.error`)
	*/
	Save(sql) {
		if (!this.hDB) {
			this.status := SQLIGHT_NO_CONNECTION
			throw ValueError(this.error, -1, this.hDB)
		}	
		if (this.status := SQLight._prepare_v2(this.hDB, sql, &h := 0))
			return -1
		this.Stmts.Push(h)
		return this.Stmts.Length
	}
	
	/*
		Clear all saved statements
	*/
	ClearSaved() {
		loop this.Stmts.Length {
			if (this.status := SQLight._free_stmt(this.Stmts[A_Index]))
				return false
			this.Stmts[A_Index] := 0	
		}
		this.Stmts.Length := 0
		return true
	}	
	
	/*
		Load SQL-Statement.
		Loads a previously saved statement, or a temporary one, ready to be executed by `Go()`.
		Each time a new (saved or temporary) statement is loaded the previous statement get reset in 
		order to make sure no transaction is kept open. 
		To avoid running into character escaping troubles, this function should be prefered over `Now()`.
		
		`sql`: 	if 'String': 	temporary sql-statement to load
				if 'Integer':  	number that refers to a previously saved statement using `Save()`
			NOTE: 
				`?` is the only supported placeholder for parameters and can only applied on values
		`params`:	parameters for `?`-bindings in an `sql`-statement
			NOTE:
				blob parameters must be of type 'Buffer' -> `Buffer()`;
				Supported parameter types: 'Buffer'(BLOB), 'Integer'(INTEGER), 'Float'(REAL), 'String'(TEXT)
		
		RETURNS: 	`true`: 	if loaded successfully
					`false`:	on error, check `this.status` and `this.error` 
	*/
	Load(sql, params*) {
		if (!this.hDB) {
			this.status := SQLIGHT_NO_CONNECTION
			throw ValueError(this.error, -1, this.hDB)
		}	
		; reset current
		if (this.hStmt)  {
			if (this.status := SQLight._reset_ex(this.hStmt))
				return false
		}	
		h_stmt := 0
		switch (type(sql)) {
			case 'Integer':
				; use saved statement handle
				if (!this.Stmts.Has(sql)) {
					this.status := SQLIGHT_INVALID_VALUE
					throw ValueError(this.error, -1, sql)
				}	
				h_stmt := this.Stmts[sql]
				if (this.status := SQLight._clear_bindings(h_stmt))
					return false
			case 'String':
				; get new temp statement handle
				if (this.status := SQLight._prepare_v2(this.hDB, sql, &h_stmt))
					return false
				if (!this._set_hStmt_tmp(h_stmt))
					return false
			default:
				this.status := SQLIGHT_INVALID_TYPE
				throw ValueError(this.error, -1, type(sql))
		}
		; bind parameters, if any
		if (this.status := SQLight._bind_ex(h_stmt, params*))
			return false
			
		; assign new current
		this.hStmt := h_stmt
		return true		
	}
	
	/*	
		Execute the current loaded statement.
		If result rows expected, consecutive calls to this function can be used 
		to iterate over the resulting rows.
		
		`row`:		receives (next) row, if result is available
		`mode`:		data structure of received `&row`, one of these: 	
					`SQLIGHT_ROW_MAP`: 		0: 		`Map()`
					`SQLIGHT_ROW_ARRAY`: 	!=0:	`Array()` 
		
		RETURNS: 	`SQLITE_DONE`:	successfully executet the statement, no (more) rows available;
									NOTE: 
										if a previous call to this function returned `SQLITE_DONE`, 
										the next call to this function performs an auto
										reset and starts over again;
					`SQLITE_ROW`:	successfully executet the statement, (next) row has been received in `&row`;
					otherwise:		an error code (check `this.error`)
			
		EXAMPLE:	Parse all resulting rows:		
					while ((ret := db.Go(&row)) = SQLITE_ROW) {
						... do something with `row` ...
					}
					; make sure all rows had been parsed without errors
					if (ret != SQLITE_DONE)  
						throw Error(db.error,-1)
	*/
	Go(&row?, mode := SQLIGHT_ROW_MAP) {
		if (!this.hDB) {
			this.status := SQLIGHT_NO_CONNECTION
			throw ValueError(this.error, -1, this.hDB)
		}
		if (!this.hStmt) {
			this.status := SQLIGHT_NO_STATEMENT
			throw ValueError(this.error, -1, this.hStmt)	
		}		
		h := this.hStmt 
		; execute
		this.status := SQLight._step(h)
		if (this.status != SQLITE_ROW)
			return this.status
				
		col_count := SQLight._row_get(h, &rec, mode)	
		if (!col_count) {
			this.status := SQLIGHT_INVALID_VALUE
			throw ValueError(this.error, -1, col_count)
		}
		row := rec	
        return this.status
	}	
	
	/*
		Resets the current loaded statement, ready to be executed again by `Go()`.
		
		RETURNS: 	`true` if successfull, 
					otherwise `false`
	*/
	Reset() {
		if (!this.hDB) {
			this.status := SQLIGHT_NO_CONNECTION
			throw ValueError(this.error, -1, this.hDB)
		}
		if (!this.hStmt) {
			this.status := SQLIGHT_NO_STATEMENT
			throw ValueError(this.error, -1, this.hStmt)	
		}	
		if (this.status := SQLight._reset_ex(this.hStmt))
			return false
		return true
	}
	
	/* 
		Begin a transaction.
		
		`mode`: 0: 	`IMMEDIATE`: 	might itself return `SQLITE_BUSY`, but if it succeeds, 
									then SQLite guarantees that no subsequent operations on the same 
									database through the next `COMMIT` will return `SQLITE_BUSY`
				1: 	`EXCLUSIVE`: 	same as `IMMEDIATE`, but also prohibits read operations from other connections 
				2: 	`DEFERRED`:		might return `SQLITE_BUSY` on subsequent operations 
			   -1:	no mode
		`timeout_ms`:	timeout in ms, this adds to the time of the internal sqlite busy handler, if in force
		`interval_ms`:	sleep interval until max timeout `timeout_ms` is reached 
			   
		RETURNS: `true` on success, otherwise `false` on timeout or error	
	*/
	__BEGIN_TRANSACTION__(mode := 0, timeout_ms := 5555, interval_ms := 111) {
		if (!this.hDB) {
			this.status := SQLIGHT_NO_CONNECTION
			throw ValueError(this.error, -1, this.hDB)
		}
		switch mode {
			case -1: 
				sql := 'BEGIN TRANSACTION;'	
			case 0: 
				sql := 'BEGIN IMMEDIATE TRANSACTION;'
			case 1:
				sql := 'BEGIN EXCLUSIVE TRANSACTION;'
			case 2:
				sql := 'BEGIN DEFERRED TRANSACTION;'	
			default:
				this.status := SQLIGHT_INVALID_VALUE
				throw ValueError(this.error, -1, mode)
		}		
		ts := A_TickCount
		while ((A_TickCount - ts) < timeout_ms) {	
			this.status := SQLight._exec(this.hDB, sql) 
			switch this.status {
				case SQLITE_OK:
					return true
				case SQLITE_BUSY:
					Sleep interval_ms
					continue
				default:
					this.status := SQLIGHT_INVALID_VALUE
					return false
			}			
		}
		this.status := SQLIGHT_TIMEOUT
		return false
	}	
	
	/*
		Commits a previous initiated transaction by `__BEGIN_TRANSACTION__()`.
		
		RETURNS: `true` on success, otherwise `false`	
	*/
	__COMMIT_TRANSACTION__() {
		if (!this.hDB) {
			this.status := SQLIGHT_NO_CONNECTION
			throw ValueError(this.error, -1, this.hDB)
		}		
		if (this.status := SQLight._exec(this.hDB, 'COMMIT TRANSACTION;'))
			return false
		return true
	}
		
	/*
		Establish a direct link to a database table to perform synchronous operations on it.	
		`tbl_name`:		name of the table to operate on
		`key_col`:	must be a "UNIQUE" or "PRIMARY KEY" column name, subsequent 
					operations use that column to "pin-point" a row thru its value (`key_col_value`)
		RETURNS: 	`LightTable` instance			
	*/	
	Link(tbl_name, key_col) {
		this.status := SQLIGHT_OK
		return SQLight.LightTable(this.hDB, tbl_name, key_col)
	}
	
	/*
		A direct link to a database table to perform synchronous operations on it.	
	*/
	class LightTable {	
	
		
		static SQL_table_list		:= 'SELECT "{1}" FROM pragma_table_list("{2}")' 	; ColCount, _table_exist()
		static SQL_xinfo_col 		:= 'SELECT "{1}" FROM pragma_table_xinfo("{2}")'  	; ColNames
		static SQL_row_count		:= 'SELECT COUNT(*) FROM "{1}"'  					; RowCount
		static SQL_item_get 		:= 'SELECT "{1}" FROM "{2}" WHERE "{3}" IS ?'	  	; Get()
		static SQL_row_get			:= 'SELECT * FROM "{1}" WHERE "{2}" IS ?'   		; GetRow()
		static SQL_item_set 		:= 'UPDATE "{1}" SET "{2}" = ? WHERE "{3}" IS ?'    ; Set()
		static SQL_delete			:= 'DELETE FROM "{1}" WHERE "{2}" IS ?'   			; Delete()
		static SQL_row_check		:= 'SELECT "{1}" FROM "{2}" WHERE "{3}" IS ?'   	; _row_exist()
		static SQL_insert_replace	:= '{1} INTO "{2}" VALUES ( {3} )'   				; _insert_replace()
	
		/*
			returns: SQLIGHT_OK if exists, SQLIGHT_INVALID_VALUE if not, or an sqlite error code
		*/
		static _table_exist(h, tbl_name) {
			if (ret := SQLight._get_table_ex(h, Format(SQLight.LightTable.SQL_table_list, 'name', tbl_name), &nfo, SQLIGHT_ROW_ARRAY))
				return ret
			if (nfo = '') 
				return SQLIGHT_INVALID_VALUE
			return SQLIGHT_OK
		}
		/*
			Check for rows.
			RETURNS: 	`SQLITE_ROW`, if at least one row exists,
						`SQLITE_DONE`, if no row exists,
						otherwise error code
		*/
		static _row_exist(hdb, tbl_name, col, col_value) {
			h_stmt := 0
			sql := Format(SQLight.LightTable.SQL_row_check, col, tbl_name, col)
			SQLight._prepare_v2(hdb, sql, &h_stmt)
			SQLight._bind_ex(h_stmt, col_value)
			ret := SQLight._step(h_stmt)
			SQLight._finalize(h_stmt)
			return ret
		}
	
		; handle to database
		hDB  {
			get => this._hDB
			set {
				if (!value) {
					this.status := SQLIGHT_INVALID_VALUE
					throw ValueError(this.error, -1, 'Not connected, invalid database handle.')
				}	
				this._hDB := value
			}
		}
		tbl_name {
			get => this._tbl_name
			set {
				this.status := SQLight.LightTable._table_exist(this.hDB, value) 
				switch this.status {
					case SQLIGHT_OK:
					case SQLIGHT_INVALID_VALUE:
						throw ValueError(this.error, -1, 'Table ' '"' value '"' ' does not exist.')
					default:
						throw Error(this.error, -1)
				}
				this._tbl_name := value
			}		
		}
		; column names index (this._ColNamesIndex.Count = column count)
		_ColNamesIndex := Map()
		
		key_col {
			get => this._key_col
			set {
				if (!this._ColNamesIndex.Has(value)) {
					this.status := SQLIGHT_INVALID_VALUE
					throw ValueError(this.error, -1, '"' value '"' ' column does not exist.')
				}	
				this._key_col := value
			}
		}
		
		status := 0
		error { 
			get {	
				if (this.status < SQLIGHT_OK) 
					return SQLight._sqlite_errmsg(this.status, this.hDB)
				else 
					return SQLight._sqlight_errmsg(this.status)
			}
		}
		
		/*
			`hdb`:	handle to database
			`tbl_name`:		name of the table to operate on
			`key_col`:	must be a "UNIQUE" or "PRIMARY KEY" column name, subsequent 
						operations use that column to "pin-point" a row thru its value (`key_col_value`)
		*/
		__New(hdb, tbl_name, key_col) {
			this.hDB := hdb						
			this._init(tbl_name, key_col)
		}
		_init(tbl_name, key_col) {	
			this.tbl_name := tbl_name			
			
			; assign `_ColNamesIndex`
			this._ColNamesIndex.Clear()
			names := this.ColNames
			loop names.Length {
				this._ColNamesIndex.Set(names[A_Index], A_Index)
			}			
			
			this.key_col := key_col
		}
		
		/* returns number of columns */
		ColCount {
			get {			
				if (this.status := SQLight._get_table_ex(this.hDB, Format(SQLight.LightTable.SQL_table_list, 'ncol', this.tbl_name), &nfo, SQLIGHT_ROW_ARRAY))
					throw Error(this.error, -1)
				return nfo[1][1]
			}
		}
		/* returns `Array()` of column names */
		ColNames {
			get {
				if (this.status := SQLight._get_table_ex(this.hDB, Format(SQLight.LightTable.SQL_xinfo_col, 'name', this.tbl_name), &nfo, SQLIGHT_ROW_ARRAY))
					throw Error(this.error, -1)
				if (nfo = '') {
					this.status := SQLIGHT_INVALID_VALUE
					throw ValueError(this.error, -1, 'No result.')
				}			
				names := Array()
				for row in nfo {
					names.Push(row[1])
				}
				return names
			}
		}
		/* returns number of rows */
		RowCount {
			get {
				if (this.status := SQLight._get_table_ex(this.hDB, Format(SQLight.LightTable.SQL_row_count, this.tbl_name), &cnt, SQLIGHT_ROW_ARRAY))
					throw Error(this.error, -1)
				return cnt[1][1]
			}
		}
		
		/* switch the table and key col to operate on, includes a re-init/refresh */
		Switch(tbl_name, key_col) {
			this._init(tbl_name, key_col) 
			this.status := SQLIGHT_OK
		}
		/* NEED to be called if table properties change, like column count */
		Refresh() {
			this._init(this.tbl_name, this.key_col) 
			this.status := SQLIGHT_OK	
		}
		
		/* 
			DELETE a row.
			Delete if exist.
			`value`: 	MUST be a 0 integer
				NOTE: 		`key_col_value` MUST refer to an 
							existing value within the `key_col`, 
							generally speaking: the row must exist;
							fails if not existant
		*/
		Delete(key_col_value) {
			; DELETE row
			h_db := this.hDB
			h_stmt := 0
			; check if row exists
			this.status := SQLight.LightTable._row_exist(h_db, this.tbl_name, this.key_col, key_col_value)
			switch this.status {
				case SQLITE_ROW: 
				case SQLITE_DONE: 
					this.status := SQLIGHT_INVALID_VALUE
					throw ValueError(this.error, -1, '"' key_col_value '"' ': value not found in key column: ' '"' this.key_col '"' '`nINFO: DELETE requires the row to exist.')
				default:
					throw Error(this.error, -1)
			}	
			sql := Format(SQLight.LightTable.SQL_delete, this.tbl_name, this.key_col)
			SQLight._prepare_v2(h_db, sql, &h_stmt)
			SQLight._bind_ex(h_stmt, key_col_value)
			this.status := SQLight._step(h_stmt)
			SQLight._finalize(h_stmt)
			if (this.status != SQLITE_DONE) {
				throw Error(this.error, -1)
			}
			this.status := SQLIGHT_OK
		}
		/*
			INSERT or REPLACE a row.
			Insert if not exist.
			Replace if exist.
			`values`: 	variadic parameter list, `Array()`;
						The values in the array (from left to right) 
						MUST match the order (and type) of the columns 
						in the table. `Buffer()`-type refers to a blob type column.
				INSERT:		`key_col_value` MUST be `unset`;
							fails on constraint error, no replace
				REPLACE:	`key_col_value` MUST refer to an 
							existing value within the `key_col`;
							`key_col_value` MUST match the `key_col` value in 
							the `values`-array at the correct position;
							generally speaking: the row must exist;
							fails if not existant
					NOTE:		REPLACE can have unconsidered side effects.
								If there are constraint conflicts on column values
								other than from `key_col` which are also UNIQUE, 
								these conflicts result in deletion of any 
								rows that apply to these conflicts. This is not 
								a bug, its normal behaviour of REPLACE.
		*/
		_insert_replace(cmd, values*) {
			h_stmt := 0
			; insert 
			sql_values := ''
			loop this._ColNamesIndex.Count {  ; loop parameters
				if (A_Index != 1) 
					sql_values .= ' , '
				sql_values .= '?'		
			}
			sql := Format(SQLight.LightTable.SQL_insert_replace, cmd, this.tbl_name, sql_values)
			SQLight._prepare_v2(this.hDB, sql, &h_stmt)			
			SQLight._bind_ex(h_stmt, values*)
			this.status := SQLight._step(h_stmt)
			SQLight._finalize(h_stmt)
			if (this.status != SQLITE_DONE) {
				throw Error(this.error, -1)
			}
			this.status := SQLIGHT_OK
		}
		Insert(values*) {
			this._insert_replace('INSERT', values*)
		}
		Replace(key_col_value, values*) {
			; `key_col_value` must match the key col value in the `values` array
			ix := this._ColNamesIndex[this.key_col]
			if (key_col_value != values[ix]) {
				this.status := SQLIGHT_INVALID_VALUE
				throw ValueError(this.error, -1, '"' key_col_value '"' ' != ' '"' values[ix] '"' '`nINFO: REPLACE requires these values to match.')
			}
			; replace requires the row to exist, if not, error
			this.status := SQLight.LightTable._row_exist(this.hDB, this.tbl_name, this.key_col, key_col_value)
			switch this.status {
				case SQLITE_ROW:
				case SQLITE_DONE: 
					this.status := SQLIGHT_INVALID_VALUE
					throw ValueError(this.error, -1, '"' key_col_value '":' ' value not found in key column: ' '"' this.key_col '"' '`nINFO: REPLACE requires the row to exist.')
				default:
					throw Error(this.error, -1)
			}
			this._insert_replace('REPLACE', values*)
		}
		
		; get a cell value at row with `key_col` value `key_col_value` at column `col`
		Get(key_col_value, col) {
			if (!IsSet(col)) {
				; return row map
			}
			; get a cell value
			h_stmt := 0
			; `col` must exist
			if (!this._ColNamesIndex.Has(col)) {
				this.status := SQLIGHT_INVALID_VALUE
				throw ValueError(this.error, -1, '"' col '"' 'column does not exist.')
			}
			sql := Format(SQLight.LightTable.SQL_item_get, col, this.tbl_name, this.key_col)
			SQLight._prepare_v2(this.hDB, sql, &h_stmt)
			SQLight._bind_ex(h_stmt, key_col_value)
			this.status := SQLight._step(h_stmt)
			if (this.status != SQLITE_ROW) {
				SQLight._finalize(h_stmt)
				throw Error(this.error, -1) 
			}
			v := SQLight._column_value_ex(h_stmt, 0)
			SQLight._finalize(h_stmt)
			this.status := SQLIGHT_OK
			return v
		}
		
		; set a cell value `value` at row with `key_col` value `key_col_value` at column `col`
		Set(key_col_value, col, value) {
			; set a cell value
			h_stmt := 0
			sql := Format(SQLight.LightTable.SQL_item_set, this.tbl_name, col, this.key_col)
			SQLight._prepare_v2(this.hDB, sql, &h_stmt)
			SQLight._bind_ex(h_stmt, value, key_col_value)
			this.status := SQLight._step(h_stmt)
			SQLight._finalize(h_stmt)
			if (this.status != SQLITE_DONE) {
				throw Error(this.error, -1) 
			}	
			this.status := SQLIGHT_OK
			return value
		}
		
		; get a temporary copy of row `key_col_value`, either as map or array
		GetRow(key_col_value, mode := SQLIGHT_ROW_MAP) {
			h_stmt := 0
			sql := Format(SQLight.LightTable.SQL_row_get, this.tbl_name, this.key_col)
			SQLight._prepare_v2(this.hDB, sql, &h_stmt)
			SQLight._bind_ex(h_stmt, key_col_value)
			this.status := SQLight._step(h_stmt)
			if (this.status != SQLITE_ROW) {
				SQLight._finalize(h_stmt)
				throw Error(this.error, -1) 
			}
			SQLight._row_get(h_stmt, &row, mode)
			SQLight._finalize(h_stmt)
			this.status := SQLIGHT_OK
			return row
		}
		
		__Item[key_col_value?] {
			; get `Row` instance
			get {
				if (!IsSet(key_col_value)) 
					return
				return SQLight.LightTable.Row(this, key_col_value)			
			}	
			; delete, insert, replace a row
			set  {
				switch type(value) {
					case 'Integer':
						/* 
							DELETE a row.
							Delete if exist.
							`value`: 	MUST be a 0 integer
								NOTE: 		`key_col_value` MUST refer to an 
											existing value within the `key_col`, 
											generally speaking: the row must exist;
											fails if not existant
						*/
						if (!IsSet(key_col_value)) {
							this.status := SQLIGHT_INVALID_VALUE
							throw ValueError(this.error, -1, 'Parameter not set.')
						}
						if (value != 0) {
							; if integer, it MUST be 0 to delete a row 
							this.status := SQLIGHT_INVALID_VALUE
							throw ValueError(this.error, -1, '"' value '"' ': value not valid. `nINFO: Assign "0" integer to perform a DELETE.') 
						}
						this.Delete(key_col_value)
					
					case 'Array':
						/*
							INSERT or REPLACE a row.
							Insert if not exist.
							Replace if exist.
							`value`: 	MUST be an `Array()`;
										The values in the array (from left to right) 
										MUST match the order (and type) of the columns 
										in the table. `Buffer()`-type refers to a blob type column.
								INSERT:		`key_col_value` MUST be `unset`;
											fails on constraint error, no replace
								REPLACE:	`key_col_value` MUST refer to an 
											existing value within the `key_col`;
											`key_col_value` MUST match the `key_col` value in 
											the `value`-array at the correct position;
											generally speaking: the row must exist;
											fails if not existant
						*/
						if (IsSet(key_col_value))  
							this.Replace(key_col_value, value*)
						else 						
							this._insert_replace('INSERT', value*)
					default:
						this.status := SQLIGHT_INVALID_TYPE
						throw ValueError(this.error, -1, type(value)) 
				}
				return value
			}
		}
		
		class Row {		
			parent := 0
			key_col_value := 0
			/*
				`parent`: 	reference to parent class which is `LightTable`
				`key_col_value`: a value from key column `key_col`
			*/
			__New(parent, key_col_value) {
				this.parent := parent
				this.key_col_value := key_col_value		
			}
			__Item[col?] {
				get {
					if (!IsSet(col)) {
						; get a temporary copy of row `key_col_value`, as map
						return this.parent.GetRow(this.key_col_value)
					}
					; get a cell value at row with `key_col` value `key_col_value` at column `col`
					return this.parent.Get(this.key_col_value, col)	
				}	
				set {
					if (!IsSet(col))  
						return 
					; set a cell value `value` at row with `key_col` value `key_col_value` at column `col`	
					this.parent.Set(this.key_col_value, col, value)
					return value
				}	
			}
		}
	}
}
