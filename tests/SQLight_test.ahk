#Requires Autohotkey v2.0+ ; prefer 64-Bit
; #Warn all, off

#Include <Yunit\Yunit>
#Include <Yunit\Window>
;#Include <Yunit\Stdout>
;#Include <Yunit\OutputDebug>
;#Include <Yunit\JUnit>

#Include ..\SQLight.ahk


Yunit.Use(YunitWindow).Test(SQLight_Main)


find_dll() {
	dll := 0
	paths := [ '', '\lib', '\lib\bin', '\..', '\..\lib', '\..\lib\bin']
	for p in paths {
		p := A_ScriptDir p '\sqlite3.dll'
		if (FileExist(p)) {
			dll := p
			break
		}	
	}			
	return dll
}


class SQLight_Main {
	
	static sqlite_dll := find_dll()
	static test_jpg := 'img.jpg'
	static blob_jpg := 'blob.jpg'
	
	begin() {
		this.db := SQLight('test.db', SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_MEMORY, SQLight_Main.sqlite_dll)
	}
	end() => this.db.Disconnect()
	
	is_opened_correctly() {
		db := this.db	
			Yunit.Assert(db.status = SQLITE_OK, 'status is not OK: ' db.error)	
		; reconnect another database
		ret := db.Connect('new_test.db', SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_MEMORY)
			Yunit.Assert(ret = true && db.status = SQLITE_OK, 'should be true/ok: ' db.error)	
	}	
	is_closed_correctly() {
		db := this.db
		ret := db.Disconnect()
			Yunit.Assert(ret = true && db.status = SQLITE_OK, 'should be true/ok: ' db.error)	
	}	
	create_table() {
		db := this.db
		ret := db.Now('CREATE TABLE test_table (col_1 TEXT UNIQUE, col_2 INT64, col_3 REAL, col_4 BLOB)')		
			Yunit.Assert(ret = true && db.status = SQLITE_OK, 'should be true/ok: ' db.error)	
	}
	
	class SQLight_Table {
	
		__New() {
			if (FileExist(SQLight_Main.blob_jpg))
				FileDelete SQLight_Main.blob_jpg
		}		
		__Delete() {
			if (FileExist(SQLight_Main.blob_jpg))
				FileDelete SQLight_Main.blob_jpg
		}
		
		begin() {		
			this.db := SQLight('test.db', SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_MEMORY, SQLight_Main.sqlite_dll)
			ret := this.db.Now('CREATE TABLE test_table (col_1 TEXT UNIQUE, col_2 INT64, col_3 REAL, col_4 BLOB)')
		}
		end() => this.db.Disconnect()
	
		table_action() {
			db := this.db	
			
			ret := db.SetBusyHandler(1111)
				Yunit.Assert(ret = true && db.status = SQLITE_OK, 'should be true/ok: ' db.error)	
			
			; insert rows
			ret := db.Now('BEGIN TRANSACTION;')
				Yunit.Assert(ret = true && db.status = SQLITE_OK, 'should be true/ok: ' db.error)	
									
			buf := FileRead(SQLight_Main.test_jpg,"RAW")							
			loop 10 {
				ret := db.Load(Format('INSERT INTO test_table (col_1, col_2, col_3, col_4) VALUES (?, {1} ,?,?)', A_Index + 100),  'col_1_' A_Index, Float(A_Index + 0.777), buf)
					Yunit.Assert(ret = true, 'should be true: ' db.error)	
				ret := db.Go()
					Yunit.Assert(ret = SQLITE_DONE && db.status = SQLITE_DONE, 'should be done: ' db.error)	
			}
			ret := db.Now('COMMIT TRANSACTION;')
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)	
						
			; get row
			; request invalid row
			ret := db.Load('SELECT * FROM test_table WHERE rowid IS 99')
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)	
			row := 0
			ret := db.Go(&row)
				Yunit.Assert(ret = SQLITE_DONE && db.status = SQLITE_DONE, 'should be done: ' db.error)	
				Yunit.Assert(row = 0, 'should be 0: ' db.error)						
							
			; request valid row
			ret := db.Load('SELECT * FROM test_table WHERE rowid IS 7')
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)	
			; get the 1st row
			row := unset	
			ret := db.Go(&row, 1)
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)	
				Yunit.Assert(row[1] = 'col_1_7', 'invalid value: ' db.error)	
				Yunit.Assert(row[2] = 107, 'should be 107: ' db.error)	
			; try get the 2nd row, but there is only one result row...
			row := 0
			ret := db.Go(&row, 1)
				Yunit.Assert(ret = SQLITE_DONE, 'should be done: ' db.error)	
				Yunit.Assert(row = 0, 'should be 0: ' db.error)		
			; execute again, causes auto-reset, back at 1st row
			row := unset	
			ret := db.Go(&row, 1)
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)	
				Yunit.Assert(row[1] = 'col_1_7', 'invalid value: ' db.error)	
				Yunit.Assert(row[2] = 107, 'should be 107: ' db.error)	
								
			; reset then try again
			ret := db.Reset()
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)		
			; request a map this time
			row := unset	
			ret := db.Go(&row, 0)
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)	
				Yunit.Assert(row.Count = 4, 'should be 4 columns')	
				Yunit.Assert(row['col_1'] = 'col_1_7', 'should be col_1_7: ' db.error)	
				Yunit.Assert(row['col_2'] = 107, 'should be 107: ' db.error)	
			; try to get the BLOB
			outfile := FileOpen("blob.jpg", "w")
			outfile.RawWrite(row['col_4'], row['col_4'].Size) 
			outfile.Close()
				Yunit.Assert(FileGetSize(SQLight_Main.test_jpg) = FileGetSize(SQLight_Main.blob_jpg), 'file size should be equal')
			
			
			ret := db.Now('BEGIN TRANSACTION;')
				Yunit.Assert(ret = true && db.status = SQLITE_OK, 'should be true/ok: ' db.error)
			; get multiple rows
			ret := db.Load('SELECT rowid, col_2 FROM test_table')
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)	
			; get the 1st row
			ret := db.Go(&row, 1)
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)	
				Yunit.Assert(row.Length = 2, 'should be 2 columns')	
				Yunit.Assert(row[1] = 1, 'should be 1: ' db.error)	
				Yunit.Assert(row[2] = 101, 'should be 101: ' db.error)	
			; get the next row (2)
			ret := db.Go(&row, 1)
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)
			; get the next row (3)
			ret := db.Go(&row, 1)
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)
				Yunit.Assert(row[1] = 3, 'should be 3: ' db.error)	
				Yunit.Assert(row[2] = 103, 'should be 103: ' db.error)	
			ret := db.Now('COMMIT TRANSACTION;')
				Yunit.Assert(ret = true && db.status = SQLITE_OK, 'should be true/ok: ' db.error)
			
			
			ret := db.__BEGIN_TRANSACTION__()
				Yunit.Assert(ret = true, 'should be true: ' db.error)	
			; reset 
			ret := db.Reset()
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)		
			; loop all rows
			ix := 0
			while ((ret := db.Go(&row, 1)) = SQLITE_ROW)  {
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)
				Yunit.Assert(row[2] = A_Index + 100, 'wrong value: ' db.error)					
				ix++
			}
			; make sure all rows have been parsed without errors
			Yunit.Assert(ret = SQLITE_DONE && db.status = SQLITE_DONE, 'should be row: ' db.error)
			Yunit.Assert(ix = 10, 'should be 10')	
			; test automatic reset
			ret := db.Go(&row, 1)
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)
				Yunit.Assert(row[2] = 101, 'wrong value: ' db.error)	; back at start
			ret := db.__COMMIT_TRANSACTION__()
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)		
			
			
			; save some sql
			select_all := db.Save('SELECT * FROM test_table')  
				Yunit.Assert(select_all = 1, 'should be 1: ' db.error)	
			select_7 := db.Save('SELECT * FROM test_table WHERE rowid IS 7')
				Yunit.Assert(select_7 = 2, 'should be 2: ' db.error)	
			insert_pattern := db.Save('INSERT INTO test_table (col_1, col_2, col_3, col_4) VALUES (?, ? ,?, ?)')   ; ix = 3
				Yunit.Assert(insert_pattern = 3, 'should be 3: ' db.error)	
			count_all := db.Save('SELECT COUNT(*) FROM test_table')  
				Yunit.Assert(count_all = 4, 'should be 4: ' db.error)	
			count_7 := db.Save('SELECT COUNT(*) FROM test_table WHERE rowid IS 7')	
				Yunit.Assert(count_7 = 5, 'should be 5: ' db.error)	
				
			get_column_info := db.Save('PRAGMA table_xinfo("test_table")')	; this statement queries all result columns
			get_column_names := db.Save('SELECT name FROM pragma_table_xinfo(?)')	 ; get names only
			
			
			; load some saved statements			
			ret := db.Load(1)  ; select_all = index 1
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)	
			ret := db.Go(&row, 0)
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)
				Yunit.Assert(row.Count = 4, 'should be 1: ' db.error)	
			headers := ''
			for k,v in row {
				headers .= k ', '
			}			
			; msgbox headers
						
			; count resulting rows for 'select_7'
			ret := db.Load(count_7)
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)	
			ret := db.Go(&row, 1)
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)
				Yunit.Assert(row[1] = 1, 'should be 1: ' db.error)
				
			ret := db.Load(select_7)
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)	
			ret := db.Go(&row, 0)
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)
				Yunit.Assert(row['col_2'] = 107, 'should be 107: ' db.error)	
			ret := db.Go(&row, 1)
				Yunit.Assert(ret = SQLITE_DONE && db.status = SQLITE_DONE, 'should be done: ' db.error)
										
			; count
			ret := db.Load(count_all)
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)	
			ret := db.Go(&row, 1)
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)
				Yunit.Assert(row.Length = 1, 'should be 1: ' db.error)	
				Yunit.Assert(row[1] = 10, 'should be 10: ' db.error)	
						
			; load insert statement with parameters
			ret := db.Load(insert_pattern, 'new text value', 9999, Float(1.345), FileRead(SQLight_Main.test_jpg,"RAW"))
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)	
			ret := db.Go()	
				Yunit.Assert(ret = SQLITE_DONE && db.status = SQLITE_DONE, 'should be done: ' db.error)
				
			ret := db.Load(insert_pattern, 'another', 7777, Float(51.234), FileRead(SQLight_Main.test_jpg,"RAW"))
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)	
			ret := db.Go()	
				Yunit.Assert(ret = SQLITE_DONE && db.status = SQLITE_DONE, 'should be done: ' db.error)	
			; try to insert the same row, but UNIQUE should prevent that
			ret := db.Go()
				Yunit.Assert(ret = 19 && db.status = 19, 'should be error 19: ' db.error)	
				
			; insert datetime
			_date := '2000-01-01'
			_time := '05:59:59'
			ret := db.Load('INSERT INTO test_table (col_1, col_2, col_3, col_4) VALUES ("datetime", julianday("' _date ' ' _time '") , 0.345, NULL)')
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)	
			ret := db.Go()	
				Yunit.Assert(ret = SQLITE_DONE && db.status = SQLITE_DONE, 'should be done: ' db.error)		
				
			; get datetime
			ret := db.Load('SELECT datetime(col_2), date(col_2), time(col_2), strftime("%d.%m.%Y", col_2) FROM test_table WHERE col_1 IS "datetime"')
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)	
			ret := db.Go(&row, 1) 
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)
				Yunit.Assert(row.Length = 4, 'should be 4: ' db.error)	
				Yunit.Assert(row[2] = _date, 'invalid date: ' db.error)	
							
			; count again			
			ret := db.Load(count_all)
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)					
			ret := db.Go(&row, 0)					 
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)
				Yunit.Assert(row.Count = 1, 'should be 1: ' db.error)	
			for k in row {
				Yunit.Assert(row[k] = 13, 'should be 13: ' db.error)	
			}	
			
			
			ret := db.Load(get_column_names, 'test_table')
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)				
			while ((ret := db.Go(&row, 1)) = SQLITE_ROW)  {
				Yunit.Assert(ret = SQLITE_ROW && db.status = SQLITE_ROW, 'should be row: ' db.error)
				; msgbox row[1]
			}	
			Yunit.Assert(ret = SQLITE_DONE && db.status = SQLITE_DONE, 'should be row: ' db.error)
			
			
			ret := db.GetColumnNames(&col, 'test_table')
			Yunit.Assert(ret = true && db.status = SQLITE_DONE , 'should be true/ok: ' db.error)	
			msg := ''
			for v in col {
				msg .= v ', '
			}			
			Yunit.Assert(col[2] = 'col_2', 'should be 2: ' db.error)	
			Yunit.Assert(col.Length = 4, 'Column count should be 4: ' db.error)	
			
			; Now()
			; insert
			ret := db.Now('INSERT INTO test_table (col_1, col_2, col_3, col_4) VALUES ("get_table_test", 777, 0.3, NULL)')
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be true/ok: ' db.error)	
			; constraint error
			ret := db.Now('INSERT INTO test_table (col_1, col_2, col_3, col_4) VALUES ("get_table_test", 777, 0.3, NULL)')
				Yunit.Assert(ret = false && db.status = 19 , 'shouldnt be ok: ' db.error)	
			; request single result
			ret := db.Now('SELECT * FROM test_table WHERE rowid IS 7', &tbl, SQLIGHT_ROW_MAP)
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be ok: ' db.error)	
				Yunit.Assert(type(tbl) = 'Array', 'should be array: ' db.error)	
				Yunit.Assert(tbl.Length = 1, 'should be 1: ' db.error)	
				Yunit.Assert(type(tbl[1]) = 'Map', 'should be map: ' db.error)	
				Yunit.Assert(tbl[1].Count = 4, 'should be 4: ' db.error)	
				Yunit.Assert(tbl[1]['col_2'] = 107, 'should be 107: ' db.error)	
			; request result but there is none
			ret := db.Now('SELECT * FROM test_table WHERE rowid IS 777', &tbl, SQLIGHT_ROW_MAP)
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be ok: ' db.error)	
				Yunit.Assert(tbl = '', 'should be none: ' db.error)	
			; request multiple results	 
			ret := db.Now('SELECT rowid,* FROM test_table', &tbl, SQLIGHT_ROW_MAP)
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be ok: ' db.error)	
				Yunit.Assert(type(tbl) = 'Array', 'should be array: ' db.error)	
				Yunit.Assert(tbl.Length = 14, 'should be 14: ' db.error)	
				Yunit.Assert(type(tbl[1]) = 'Map', 'should be map: ' db.error)	
				Yunit.Assert(tbl[1].Count = 5, 'should be 5: ' db.error)	
				if (tbl[7]['rowid'] = 7)
					Yunit.Assert(tbl[7]['col_2'] = 107, 'should be 107: ' db.error)	
			; same but request array of arrays	
			ret := db.Now('SELECT rowid,* FROM test_table', &tbl, SQLIGHT_ROW_ARRAY)
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be ok: ' db.error)	
				Yunit.Assert(type(tbl) = 'Array', 'should be array: ' db.error)	
				Yunit.Assert(tbl.Length = 14, 'should be 14: ' db.error)	
				Yunit.Assert(type(tbl[1]) = 'Array', 'should be array: ' db.error)	
				Yunit.Assert(tbl[1].Length = 5, 'should be 5: ' db.error)	
				if (tbl[7][1] = 7)
					Yunit.Assert(tbl[7][3] = 107, 'should be 107: ' db.error)	
			; count		
			ret := db.Now('SELECT COUNT(*) FROM test_table', &tbl, SQLIGHT_ROW_ARRAY)
				Yunit.Assert(ret = true && db.status = SQLITE_OK , 'should be ok: ' db.error)
				Yunit.Assert(tbl[1][1] = 14, 'should be 14: ' db.error)	
			
			; msgbox SQLight._libversion()
			
			
		}
	}
	
	
}

