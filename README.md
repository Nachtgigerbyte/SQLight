# SQLight AHK library - Autohotkey interface to SQLite library

An `Autohotkey v2` interface to the `sqlite3.dll` dynamic link library. 
This library enables your `AHK` script to accomplish operations and interactions within 
the widely appreciated `SQLite` database framework.

The library can be included to your `AHK` project the usual way, depending 
on where you place it.
```
#Include some\path\SQLight\SQLight.ahk
```
If you place the `SQLight` folder in the `lib` folder of your project, you could also use:
```
#Include <SQLight\SQLight>
```
OR if in a subdirectory:
```
#Include <sub\dir\SQLight\SQLight>
```

Note that the `sqlite3.dll` is already included in `\lib\bin`. 
But you are free to replace it with a newer one downloaded from [SQLite](https://sqlite.org). 
Just make sure to place it in one of the following locations:
* `...\SQLight\lib\bin\`
* `...\SQLight\lib\`
* `...\SQLight\`
<details>
<summary>Suggestive structure</summary>
Suggestive structure
```javascript
YourProject
|
+---lib
	|
	+---SQLight			<--- place dll here
		|
		+---lib			<--- or here
		|	|
		|	+---bin 	<--- or here (default)
		|
		+---SQLight.ahk
```
</details>

Though, you dont have to follow this suggestive structure. To keep it as simple as you might like, 
this structure would suffice:
```
YourProject
|
+---sqlite3.dll
|
+---SQLight.ahk
```
But before messing around with the files in this package, just leave it intact for a while to 
run a few tests using the fantastic `Yunit` test framework, which is also included. 
To do so, navigate to the `tests` folder within the `SQLight` folder and execute the 
test script named `SQLight_test.ahk`. If all goes well, you should see 
all tests being passed indicated by a green bar at the button of the `Yunit` window. 
Otherwise a red bar would appear `:(`. If you can make yourself a clue of what was going wrong, tell me. 
 
## Ok then, lets assume all went well, we proceed with some coding.
Create a `SQLight` instance and establish connection to `.\test.db`, if the database does not exist its created.
```
db := SQLight()
db.Connect('.\test.db')
```
Or equivalent one-liner:
```
db := SQLight('test.db', SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
```
You could also explicitly specify some flags as seen above, which reflect the default flags and therefore could 
have been avoided. Other flags to combine can be found in the source or at sqlite's `sqlite3_open_v2()` documentation. 
To create an "in-memory" database that exist in memory only for the duration of the `SQLight` instance, add `SQLITE_OPEN_MEMORY`. 
Suitable for testing frameworks.
```
db := SQLight('test.db', SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_MEMORY)
```

## Ok we have a connection, lets interact with the database.
```
ret := db.Now('CREATE TABLE test_table (col_1 TEXT UNIQUE, col_2 INT64, col_3 REAL, col_4 BLOB)')
if (ret = false)
	throw Error(db.error, -1)  
```	
The `Now()` method takes a single argument, which is the sql string we want to execute. In this 
case we create a new table named `test_table` with 4 columns. 
Note that this method cannot receive any result rows, if rows are going to be expected, 
depending on the sql string, `Load()` and `Go()` must be used instead; we come to that later. 

## Insert rows 
```	
db.Now('INSERT INTO test_table (col_1, col_2, col_3, col_4) VALUES ("text_1", 123, 3.14, NULL)')
```	
This inserts a row into our `test_table`, but notice that for the last column, the blob column, we inserted NULL. Thats 
because we cannot insert blobs with the `Now()` method directly, we need another approach, with a `?` placeholder.
Here comes the `Load()` and `Go()` methods.

First we need to `Load()` our sql string which seems quite the same as with the `Now()` method except that 
the `Load()` method can 
* take placeholders (`?`), along with their parameters
* handle sql statements that receive results (like `SELECT`)
* not execute the sql directly, it just loads and holds the sql `statement`, until it is executed by `Go()`.  

The second argument to the `Load()` method is in fact a dynamic parameter list, which relates to the corresponding 
`?` placeholders. `Load(sql_string, parameters*, ...)` 

Our table now contains a single row, including a `NULL` blob, lets insert a "real" blob. 
```
; copy file to buffer, which is then used as blob data
buf := FileRead('img.jpg',"RAW") 

; load the sql using placeholder `?`
db.Load('INSERT INTO test_table (col_1, col_2, col_3, col_4) VALUES ("text_2", 345 , 3.14, ?)',  buf)

; execute the loaded sql
db.Go()
```
Notice the column value `?` used for `col_4`. As we only have one `?`, the first parameter `buf` refers 
to that placeholder. 
> The order the placeholders appear, from left to right, must match the sequence of the dynamic parameter list.

Lets try this:
```
db.Load('INSERT INTO test_table (col_1, col_2, col_3, col_4) VALUES ("text_3", ? , 3.14, ?)', 678, buf)
db.Go()
```
As you might guess, we have a second placeholder for the integer column `col_2` and 
therefore a second parameter: `db.Load(..., 678, buf)`

Lets get fancy about this and introduce a new method named `Save()`. This method takes a single 
argument: an sql string. It returns an integer, which represents an "id" to be refered by `Load()`. 
```
; save sql
my_insert_pattern := db.Save('INSERT INTO test_table (col_1, col_2, col_3, col_4) VALUES (?, ?, ?, ?)')

; load and execute
db.Load(my_insert_pattern, "text_4", 123, 3.14, FileRead('img1.jpg',"RAW"))
db.Go()
db.Load(my_insert_pattern, "text_5", 456, 3.15, FileRead('img2.jpg',"RAW"))
db.Go()
db.Load(my_insert_pattern, "text_6", 789, 3.16, FileRead('img3.jpg',"RAW"))
db.Go()
```
As you can see, the first parameter of `Load()` can be replaced by an integer "id" to refer to a previously saved 
pattern.

## Getting results
Until now we used the `Go()` method without any arguments to execute a loaded sql statement, but it can take additional 
two arguments: the first one is a `reference` to a variable you pass in, the second one determins the 
`datatype` of the first one, which can be either `SQLIGHT_ROW_ARRAY` (`Array()`) or `SQLIGHT_ROW_MAP` (`Map()`).  
`Go(&row, mode)` returns:
* `SQLITE_DONE`:	successfully executet the statement, no (more) rows available
* `SQLITE_ROW`:	 	successfully executet the statement, (next) row has been received in `&row`
* otherwise:		an error code (check `.error`)

This becomes handy when results (rows) are expected, like with `SELECT`.
```
; request the row where "col_1" is "text_4"
db.Load('SELECT * FROM test_table WHERE col_1 IS "text_4"')
/*
	execute and get the row
	`SQLIGHT_ROW_MAP`: request the row as a `Map()`
*/
ret := db.Go(&row, SQLIGHT_ROW_MAP)   

; check the return value
switch ret {
	case SQLITE_DONE:
		msgbox 'Go() has successfully executed the sql but NO row is saved in row.'
		
	case SQLITE_ROW: 	 ; <--- we expect this
		msgbox 'Go() has successfully executed the sql and a row had been saved in row.'
		
	default:
		throw Error(db.error, -1)   ; an error occured
}

; since we requested a row-`Map()`, we access like that
msgbox 'col_2 = ' row['col_2'] ', col_3 = ' row['col_3'] 

; lets try to call `Go()` again, but wait there should be no more rows...
ret := db.Go(&row, SQLIGHT_ROW_MAP) 
if (ret = SQLITE_DONE)
	msgbox 'Go() says there are no more rows available, we are done'
/*
	notice that calling `Go()` after `SQLITE_DONE` was returned an 
	"auto-reset" is performed and the loaded sql-statement get executed once again, 
	in that case we get the 1st row again...
	(also note that you can manually do a "reset" of the current loaded sql-statement by
	calling the `Reset()` method)
*/
; we request an `Array()` this time
db.Go(&row, SQLIGHT_ROW_ARRAY)
msgbox 'col_2 = ' row[2] ', col_3 = ' row[3] 
```

But hey, we didnt accessed the blob yet how is that accomplished.
```
db.Load('SELECT * FROM test_table WHERE col_1 IS "text_4"')
ret := db.Go(&row, SQLIGHT_ROW_MAP)   
if (ret = SQLITE_ROW) {
	outfile := FileOpen("col_4_blob.jpg", "w")    
	outfile.RawWrite(row['col_4'], row['col_4'].Size)   ; <--- store blob data in a file
	outfile.Close()
}
```
Note that in the above example the blob value that is saved in `row['col_4']` is actually a `Buffer()` object which 
hosts a pointer to the buffer and a `.Size` property, perfectly fit for being used with `RawWrite()`.

So far we requested only one result row, extend that for multiple rows.
```
db.Load('SELECT * FROM test_table')

; parse all result rows
while ((ret := db.Go(&row, SQLIGHT_ROW_ARRAY)) = SQLITE_ROW)  {
	
	msgbox A_Index '. Row: ' 'col_1 = ' row[1]
	
	; ... do something with row ...
	
}
if (ret != SQLITE_DONE) 
	throw Error('Not all rows had been parsed successfully', -1)
```
Dont miss the test `if (ret != SQLITE_DONE)` after the loop has finished to make sure 
all rows had been parsed successfully. 

## Disconnect/close a database connection:
```
db.Disconnect()
```
After doing this you are free to open another connection using `Connect()`.
Also note that if the `SQLight` instance looses scope, the database connection associated with it get disconnected by default.

## Error handling
Methods return `true` on success, `false` otherwise (except for `Go()` and `Save()`).
Furthermore, you can always check for an error using `.status`.
* `.status` contains last error code
* `.error` contains last error description
```
db := SQLight()
ret := db.Connect('test.db')
if (ret = false)
	msgbox "error code: " db.status ", description: " db.error
```

## Last but not least
There are two additional methods to shield your transactions from being corrupted by other database connections.
* `.__BEGIN_TRANSACTION__()` 
* `.__COMMIT_TRANSACTION__()`
```
db.__BEGIN_TRANSACTION__()

db.Now('UPDATE "test_table" SET col_2=0')

; ... do some more SQLight ...

db.__COMMIT_TRANSACTION__()

```
Thats it. For more information refer to
* `SQLight\SQLight.ahk` source
* `SQLight\tests\SQLight_test.ahk` test file
* [SQLite](https://sqlite.org)

