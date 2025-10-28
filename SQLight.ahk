; SQLight.ahk
#Requires Autohotkey v2.0+ ; prefer 64-Bit

/********************************************************************
*
*	Name:			SQLight
*	Version: 		1.0
*	Description:	Interface to SQLite3's dynamic link library.
*	
*	Author: 		Nachtgigerbyte
*	E-mail: 		nachtgigerbyte@proton.me
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

/* return codes */
SQLITE_OK                             := 0                          ; Successful result
SQLITE_ERROR                          := 1                          ; Generic error
SQLITE_BUSY                           := 5                          ; The database file is locked
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
SQLITE3_TEXT  	:= 3
SQLITE_BLOB  	:= 4
SQLITE_NULL   	:= 5

/* SQLight */
SQLIGHT_ROW_MAP		:= 0
SQLIGHT_ROW_ARRAY	:= 1

/* sqlight error strings */
SQLIGHT_NOT_CONNECTED	:= 'No database connected, handle invalid.'
SQLIGHT_NO_STATEMENT	:= 'No statement to operate on.'


/*	
	A light interface to SQLite3.
*/
class SQLight  {	


	/* returns: module handle(pointer), 0 if failed */
	static _LoadLibrary(path) => DllCall('LoadLibrary', 'str', path, 'cdecl ptr')	
	static _sourceid() => StrGet(DllCall(SQLight.sqlite3_dll '\sqlite3_sourceid', 'cdecl ptr'), 'UTF-8')
	static _libversion() => StrGet(DllCall(SQLight.sqlite3_dll '\sqlite3_libversion', 'cdecl ptr'), 'UTF-8')
	static _libversion_number() => DllCall(SQLight.sqlite3_dll '\sqlite3_libversion_number', 'cdecl int')	
	
	/* get error string by `sqlite3` result code */
	static _errstr(rc) => StrGet(DllCall(SQLight.sqlite3_dll '\sqlite3_errstr', 'int', rc, 'cdecl ptr'), 'UTF-8')
	/* returns last error message */
	static _errmsg(h) => StrGet(DllCall(SQLight.sqlite3_dll '\sqlite3_errmsg', 'ptr', h, 'cdecl ptr'), 'UTF-8')	
	/* returns last error code */
	static _errcode(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_errcode', 'ptr', h, 'cdecl int')
	/* returns last extended error code */
	static _extended_errcode(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_extended_errcode', 'ptr', h, 'cdecl int')
	
	/* open database, buf = database file, h = receives db handle */
	static _open_v2(buf, &h, flags) => DllCall(SQLight.sqlite3_dll '\sqlite3_open_v2', 'ptr', buf, 'ptr*', &h, 'int', flags, 'ptr', 0, 'cdecl int')
	/* returns result code */
	static _close_v2(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_close_v2', 'ptr', h, 'cdecl')

	/* execute sql, h = handle to db, errmsg = error message to receive */
	static _exec(h, sql) => DllCall(SQLight.sqlite3_dll '\sqlite3_exec','ptr', h, 'ptr', sql, 'ptr', 0, 'ptr', 0, 'ptr*', 0, 'cdecl int')
	static _free(s) => DllCall(SQLight.sqlite3_dll '\sqlite3_free', 'ptr', s, 'cdecl')
	/* returns sqlite return code, h = handle to database, h_stmt = received statement handle */
	static _prepare_v2(h, sql, &h_stmt) => DllCall(SQLight.sqlite3_dll '\sqlite3_prepare_v2', 'Ptr', h, 'Ptr', sql, 'Int', -1, 'UPtrP', &h_stmt, 'Ptr', 0, 'Cdecl Int')
	/* returns sqlite return code, h = handle to statement */
	static _bind_blob(h, i, buf, buf_size) => DllCall(SQLight.sqlite3_dll '\sqlite3_bind_blob', 'Ptr', h, 'Int', i, 'Ptr', buf, 'Int', buf_size, 'Ptr', -1, 'Cdecl Int')
	static _bind_int64(h, i, v) => DllCall(SQLight.sqlite3_dll '\sqlite3_bind_int64', 'Ptr', h, 'Int', i, 'Int64', v, 'Cdecl Int')
	static _bind_double(h, i, v) => DllCall(SQLight.sqlite3_dll '\sqlite3_bind_double', 'Ptr', h, 'Int', i, 'Double', v, 'Cdecl Int')
	static _bind_text(h, i, v) => DllCall(SQLight.sqlite3_dll '\sqlite3_bind_text', 'Ptr', h, 'Int', i, 'Ptr', v, 'Int', -1, 'Ptr', -1, 'Cdecl Int')
	
	/* reset result pointer of the prepared statement, returns sqlite return code, h = handle to statement */
	static _reset(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_reset', 'Ptr', h, 'Cdecl Int')
	/* clear bound SQL parameter values, returns sqlite return code, h = handle to statement */
	static _clear_bindings(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_clear_bindings', 'Ptr', h, 'Cdecl Int')
	/* free the prepared statement, returns sqlite return code, h = handle to statement */
	static _finalize(h) => DllCall(SQLight.sqlite3_dll '\sqlite3_finalize', 'Ptr', h, 'Cdecl Int')
	
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
	/* returns integer from column index, h = handle to statement, i = column index starting from 0 */ 
	static _column_int64(h, i) => DllCall(SQLight.sqlite3_dll '\sqlite3_column_int64', 'Ptr', h, 'Int', i, 'Cdecl Int64')
	/* returns double from column index, h = handle to statement, i = column index starting from 0 */ 
	static _column_double(h, i) => DllCall(SQLight.sqlite3_dll '\sqlite3_column_double', 'Ptr', h, 'Int', i, 'Cdecl Double')
	/* returns string from column index, h = handle to statement, i = column index starting from 0 */ 
	static _column_text(h, i) => StrGet(DllCall(SQLight.sqlite3_dll '\sqlite3_column_text', 'Ptr', h, 'Int', i, 'Cdecl UPtr'), 'UTF-8')
	
	; copies an ahk-string into a raw buffer equivalent and returns that buffer
	static _StrToBuf(str, enc := 'UTF-8') { 
		buf := Buffer(StrPut(str, enc))
		StrPut(str, buf, enc)
		return buf
	}

	static FileDir := 0
	; path to splite3.dll file
	static sqlite3_dll := ''
	; handle to splite3.dll module
	static hDll := 0
	; handle to database
	hDB := 0
	; current statement handle 
	hStmt := 0
	; last temp statement 
	hStmt_tmp := 0
	; has result rows 
	Stmts := Array()
	
	status := 0
	error { 
		get {			
			_error_ext_str := this.hDB ? SQLight._errmsg(this.hDB) : ''
			_error_str := Format('SQLite-ERROR ({1}): {2}: {3}', this.status, SQLight._errstr(this.status), _error_ext_str) 
			return _error_str
		}
	}
	
	/*
		Constructor.
		
		db:		the database to connect:
					path to an sqlite database file;
					an empty string '' which creates a temporary anonymous disk file;
					special string ':memory:' which is an in-memory database that 
					only exists for the duration of the session
		flags:	OR'ed combination of `SQLITE_OPEN_*`-flags (above)
		dll:	path to sqlite3.dll-file;
				if 0 or an empty string, following locations are searched, in this order:
					'SQLight\sqlite3.dll'
					'SQLight\lib\sqlite3.dll'
					'SQLight\lib\bin\sqlite3.dll'
	*/	
	__New(db := 0, flags := SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, dll := 0) {	
		if (!SQLight.FileDir) {
			SplitPath A_LineFile, &file, &dir
			SQLight.FileDir := dir
		}
		SQLight._LoadSQLite(dll)	
		if (db)
			this.Connect(db, flags)
	}	
	__Delete() {
		this.Disconnect()
		; unload library, is usually done autom. by OS at prog-exit
	}		
	
	static _LoadSQLite(dll) {
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
	}
	
	static _FreeStatement(h) {
		if (h) {
			this.status := SQLight._finalize(h) 
			if (this.status)
				return false
		}
		return true
	}
	
	_Set_hDB(h) {
		if (this.hDB) {
			this.status := SQLight._close_v2(this.hDB)
			if (this.status)
				return false
		}
		if (!this._Set_hStmt_tmp(0))
			return false
		if (!this._Clear_Stmts())
			return false
		this.hStmt := 0
		this.hDB := h
		return true
	}
	
	_Set_hStmt_tmp(h) {
		if (!SQLight._FreeStatement(this.hStmt_tmp))
			return false
		this.hStmt_tmp := h	
		return true
	}
	
	_Clear_Stmts() {
		loop this.Stmts.Length {
			if (!SQLight._FreeStatement(this.Stmts[A_Index]))
				return false
		}
		this.Stmts.Length := 0
		return true
	}	
	
	_Prepare(sql, &h) {
		; get the new statement handle
		this.status := SQLight._prepare_v2(this.hDB, SQLight._StrToBuf(sql), &h)
		if (this.status)
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
		
		RETURNS: 	`true` on success
					`false` otherwise
	*/	
	Connect(db, flags := SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE) {
		h := 0
		this.status := SQLight._open_v2(SQLight._StrToBuf(db), &h, flags)
		if (this.status) 
			throw Error(this.error, -1) 
		if (!h)
			throw OSError('Memory error, invalid handle.', -1)	
		if (!this._Set_hDB(h))	
			return false
		return true
	}
	
	/*
		Disconnect database.
		RETURNS: 	`true` on success
					`false` otherwise
	*/
	Disconnect() {
		if (!this._Set_hDB(0))
			return false
		return true
	}
	
	/*
		Execute `sql`. 
		Getting results from a query is not supported, use `Load()`, `Go()` instead. 
		RETURNS: 	`true` on success
					`false` otherwise
	*/
	Now(sql) {
		if (!this.hDB) 
			throw ValueError(SQLIGHT_NOT_CONNECTED, -1, this.hDB)
		this.status := SQLight._exec(this.hDB, SQLight._StrToBuf(sql))  ;  &err := 0 
		if (this.status) {
			return false
			/*
			errstr := StrGet(err, 'UTF-8')
			if (errstr)
				this._free(err)
			*/	
		}
		return true
	}
	
	/*
		Save `sql`-patterns for later use
		`sql`:	the sql to save
		RETURNS: 	index(integer) where the statement had been saved, 
					-1 otherwise (check `this.status`, `this.error`)
	*/
	Save(sql) {
		if (!this.hDB) 
			throw ValueError(SQLIGHT_NOT_CONNECTED, -1, this.hDB)
		if (!this._Prepare(sql, &h := 0))
			return -1
		this.Stmts.Push(h)
		return this.Stmts.Length
	}
	
	/*
		Load SQL-Statement.
		Loads a previously saved statement, or a temporary one, ready to be executed by `Go()`.
		
		`sql`: 	if 'String': 	temporary sql-statement to load
				if 'Integer':  	number that refers to a previously saved statement using `Save()`
			NOTE: 
				`?` is the only supported placeholder for parameters
		`params`:	parameters for `?`-bindings in an `sql`-statement
			NOTE:
				blob parameters must be of type 'Buffer' -> `Buffer()`;
				Supported parameter types: 'Buffer'(BLOB), 'Integer'(INTEGER), 'Float'(REAL), 'String'(TEXT)
		
		RETURNS: 	`true`: 	if loaded successfully
					`false`:	on error, check `this.status` and `this.error` 
	*/
	Load(sql, params*) {
		if (!this.hDB) 
			throw ValueError(SQLIGHT_NOT_CONNECTED, -1, this.hDB)

		if (type(sql) = 'Integer') {
			; use saved statement handle
			if (!this.Stmts.Has(sql))
				return false
			h_stmt := this.Stmts[sql]
			this.status := SQLight._reset(h_stmt) 	
			if (this.status)
				return false   ; throw Error(this.error, -1)
			this.status := SQLight._clear_bindings(h_stmt)
			if (this.status)
				return false
		}
		else {
			; get the new statement handle
			if (!this._Prepare(sql, &h_stmt := 0))
				return false
			if (!this._Set_hStmt_tmp(h_stmt))
				return false
		}
		h := h_stmt
		; bind parameters, if any
		loop params.Length {
			i := A_Index
			v := params[i]
			switch type(v) { 
				case 'Buffer':
					this.status := SQLight._bind_blob(h, i, v.Ptr, v.Size)
				case 'Integer':
					this.status := SQLight._bind_int64(h, i, v)
				case 'Float':	
					this.status := SQLight._bind_double(h, i, v)
				case 'String':
					this.status := SQLight._bind_text(h, i, SQLight._StrToBuf(v))	
				default:
					throw ValueError('Invalid parameter type', -1, type(v))
			}
			if (this.status)
				return false
		}	
		; assign new current
		this.hStmt := h
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
		if (!this.hDB) 
			throw ValueError(SQLIGHT_NOT_CONNECTED, -1, this.hDB)
		if (!this.hStmt) 
			throw ValueError(SQLIGHT_NO_STATEMENT, -1, this.hStmt)	
				
		h := this.hStmt   
				
		; execute
		this.status := SQLight._step(h)
		if (this.status != SQLITE_ROW)
			return this.status
				
		; row available, get result
		col_count := SQLight._data_count(h)		; returns 0 if statement does not have results to return
		if (!col_count) {
			throw ValueError('No data.', -1, col_count)
		}	
		rec := mode ? Array() : Map()
		if (mode)
			rec.Length := col_count
			
        loop col_count {
			i := A_Index - 1
			ix := mode ? A_Index : SQLight._column_name(h, i)
			t := SQLight._column_type(h, i)
			switch t {
				case SQLITE_BLOB: 
					ptr := SQLight._column_blob(h, i)
					size := SQLight._column_bytes(h, i)
					rec[ix] := ''
					if (ptr) {
						buf := Buffer(size)
						SQLight._RtlMoveMemory(buf, ptr, size)
						rec[ix] := buf
					}
				case SQLITE_INTEGER:
					rec[ix] := SQLight._column_int64(h, i)
				case SQLITE_FLOAT:
					rec[ix] := SQLight._column_double(h, i) 
				case SQLITE_NULL:
					rec[ix] := ''
				case SQLITE3_TEXT:
					rec[ix] := SQLight._column_text(h, i)
				default:
					rec[ix] := SQLight._column_text(h, i)
					; throw ValueError('Unsupported column type', -1, t)
			}		
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
		if (!this.hDB) 
			throw ValueError(SQLIGHT_NOT_CONNECTED, -1, this.hDB)
		if (!this.hStmt) 
			throw ValueError(SQLIGHT_NO_STATEMENT, -1, this.hStmt)	
		this.status := SQLight._reset(this.hStmt)
		if (this.status)
			return false   ; throw Error(this.error, -1)	
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
		RETURNS: `true` on success, otherwise `false` on timeout or error	
	*/
	__BEGIN_TRANSACTION__(mode := 0, timeout_ms := 9999, interval_ms := 100) {
		if (!this.hDB) 
			throw ValueError(SQLIGHT_NOT_CONNECTED, -1, this.hDB)
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
				throw ValueError('Invalid mode', -1, mode)
		}		
		ts := A_TickCount
		while ((A_TickCount - ts) < timeout_ms) {	
			this.status := SQLight._exec(this.hDB, SQLight._StrToBuf(sql)) 
			switch this.status {
				case SQLITE_OK:
					return true
				case SQLITE_BUSY:
					Sleep interval_ms
					continue
				default:
					return false
			}			
		}
		return false
	}	
	
	/*
		Commits a previous initiated transaction by `__BEGIN_TRANSACTION__()`.
		RETURNS: `true` on success, otherwise `false`	
	*/
	__COMMIT_TRANSACTION__() {
		if (!this.hDB) 
			throw ValueError(SQLIGHT_NOT_CONNECTED, -1, this.hDB)
		this.status := SQLight._exec(this.hDB, SQLight._StrToBuf('COMMIT TRANSACTION;')) 
		if (this.status)
			return false
		return true
	}

	/*
		Get column names of a table.
		`col_arr`:		receives column names of a table in an `Array()`
		`table_name`: 	name of the table to operate on
		NOTE:
			This statement uses the table-valued pragma function `pragma_*`, 
			which can select a subset of columns (`WHERE` can also be used).
		RETURNS:	`true` on success,
					`false` otherwise
				
	*/
	GetColumnNames(&col_arr,table_name)  {
		if (!this.hDB) 
			throw ValueError(SQLIGHT_NOT_CONNECTED, -1, this.hDB)
		if (!this.Load(Format('SELECT name FROM pragma_table_xinfo("{1}")', table_name)))   ; only column `name`
			return false
		arr := Array()
		while ((ret := this.Go(&row, 0)) = SQLITE_ROW)  {
			for k,v in row {
				arr.Push(v)
			}
		}
		if (ret != SQLITE_DONE)
			return false
		col_arr := arr
		return true
	}	
	
	
}



