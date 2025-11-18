# SQLight  
## Autohotkey(AHK) database interface to SQLite 

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
Just make sure to place it in one of the following locations, relative to the folder where 
`SQLight.ahk` is placed into: 
* `\` 
* `\lib\` 
* `\lib\bin\` 
```
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
Otherwise a red bar would appear `:(`. If you can make yourself a clue of what went wrong, tell me please. 
 
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

## Ok we have a connection, interact with the database. 

<details> 
<summary>The `Now()` method</summary> 

`Now(sql, &tbl?, mode := SQLIGHT_ROW_MAP)` 

```javascript
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
```

</details> 

Here's an example:  
```
ret := db.Now('CREATE TABLE test_table (col_1 TEXT UNIQUE, col_2 INT64, col_3 REAL, col_4 BLOB)')
if (ret = false)
	throw Error(db.error, -1)  
	
db.Now('INSERT INTO test_table (col_1, col_2, col_3, col_4) VALUES ("col_1_A", 1, 1.14, NULL)')	
db.Now('INSERT INTO test_table (col_1, col_2, col_3, col_4) VALUES ("col_1_B", 2, 2.14, NULL)')	
```	
The `Now()` method takes the sql you throw at and executes it. No intermediate functions required. 
In this case we created a new table named `test_table` with 4 columns and inserted two rows. 
Lets query these rows, for which we need the 2nd and 3rd parameter, 
the second one, a `reference` to a variable you pass in, receives a potential result 
consisting as an array of rows, the third one determins the row `datatype`, 
which can be either `SQLIGHT_ROW_ARRAY` (`Array()`) or `SQLIGHT_ROW_MAP` (`Map()`). 
```
db.Now('SELECT * FROM test_table', &tbl, SQLIGHT_ROW_MAP)

; get the number of rows in the table
ret := tbl.Length  		; ret = 2

; get the number of columns in a row
ret := tbl[1].Count   	; ret = 4

; as we requested a `SQLIGHT_ROW_MAP` we access like that

; get the value of 'col_1' in the 1st row
ret := tbl[1]['col_1']  ; ret = "col_1_A"

; get the value of 'col_2' in the 2nd row
ret := tbl[2]['col_2']  ; ret = 2

; --------------------------------------

; now request a 'SQLIGHT_ROW_ARRAY'
db.Now('SELECT * FROM test_table', &tbl, SQLIGHT_ROW_ARRAY)

; get the number of rows in the table
ret := tbl.Length  		; ret = 2

; get the number of columns in a row;
; notice, it is `ArrayObj.Length` not `MapObj.Count` as we requested a row array
ret := tbl[1].Length   	; ret = 4

; get the value of the 1st column in the 1st row
ret := tbl[1][1]  ; ret = "col_1_A"

; get the value of the 2nd column in the 2nd row
ret := tbl[2][2]  ; ret = 2
```

## Load and Go
First, insert another row with the previously discussed `Now()` method.  
```	
db.Now('INSERT INTO test_table (col_1, col_2, col_3, col_4) VALUES ("text_1", 123, 3.14, NULL)')
```	
Notice that for the last column, the blob column, we inserted NULL. Thats 
because we cannot insert blobs with the `Now()` method directly, we need another approach, with a `?` placeholder. 
Here comes the `Load()` and `Go()` methods. 

<details> 
<summary>The `Load()` method</summary> 

`Load(sql, params*)` 

```javascript
Load SQL-Statement.
Loads a previously saved statement, or a temporary one, ready to be executed by `Go()`.
Each time a new (saved or temporary) statement is loaded the previous statement get reset in 
order to make sure no transaction is kept open. 
To avoid running into character escaping troubles, this function should be prefered over `Now()`.

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
```

</details> 

<details> 
<summary>The `Go()` method</summary> 

`Go(&row?, mode := SQLIGHT_ROW_MAP)` 

```javascript
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
```

</details> 

First we need to `Load()` our sql string, which is then ready to be executed by `Go()`.
The second argument to the `Load()` method is in fact a dynamic parameter list, which relates to the corresponding 
`?` placeholders. `Load(sql_string, parameter1, parameter2, ...)` 

Our table now contains a few rows, including `NULL` blob's, lets insert a "real" blob. 
```
; copy file to buffer, which is then used as blob data
buf := FileRead('img.jpg',"RAW") 

; load the sql using placeholder `?` for the blob column
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

<details> 
<summary>The `Save()` method</summary> 

`Save(sql)` 

```javascript
Save `sql`-patterns for later use

`sql`:	the sql to save, can take placeholder `?`, ready to be used by `Load()`

RETURNS: 	index(integer) where the statement had been saved, 
			-1 otherwise (check `this.status`, `this.error`)
```

</details> 

```
; save sql pattern
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
pattern. To clear all saved patterns call the `ClearSaved()` method, which is called on destruction by default. 

## Getting results with `Go()`
Until now we used the `Go()` method without any arguments to execute a loaded sql statement, but it 
can take two arguments: the first one, a `reference` to a variable you pass in, receives a 
potential result row, the second one determins the `datatype` of the first one, 
which can be either `SQLIGHT_ROW_ARRAY` (`Array()`) or `SQLIGHT_ROW_MAP` (`Map()`). 

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
	`SQLIGHT_ROW_MAP`: request row as `Map()`
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

; now request an `Array()` this time
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
ret := db.__BEGIN_TRANSACTION__()
if (ret = true)
	msgbox 'From now on, subsequent database transactions wont return SQLITE_BUSY until __COMMIT_TRANSACTION__()'

db.Now('UPDATE "test_table" SET col_2=0')

; ... do some more SQLight ...

db.__COMMIT_TRANSACTION__()
```

## Summary 
The `Save()`, `Load()` and `Go()` methods can be considered core methods of the SQLight object, as 
they are more general and flexible in use than the `Now()` method. Anything you can do 
with the `Now()` method can be done with the `Save()`, `Load()` and `Go()` methods, but the reverse 
does not apply. 

The `Now()` method can be considered a convenience method, which makes it easy for 
quick sql executions, especially when there are no results, but if there are, it must be 
taken into account that all results are being converted to strings. On native 
string columns this shouldnt be a problem. 

# Version 1.2.22 
Since version `1.2.22` the `LightTable` class was introduced, which represents 
a direct link to a database table to perform synchronous operations on it. 

The following introduction demonstrates the usage of the `LightTable` object, 
based on a simple example of creating and interacting with 
a configuration file, that is actually a sqlite database. 

Create and connect to a database file called `.\config.db` 
```
db := SQLight('config.db')
```
Create table in `.\config.db` 
```
db.Now('
(
CREATE TABLE "main settings" (
"name" TEXT UNIQUE, 
"value" TEXT UNIQUE, 
"description" TEXT, 
"icon" BLOB )
)')
```
Link this table to a `LightTable` and receive it in `tbl`. 
```
tbl := db.Link('main settings', 'name') 
```
The 1st parameter is the table name, the 2nd MUST be a column name either from a `UNIQUE` or `PRIMARY KEY` column. 
This column is used in subsequent operations to uniquely identify a specific row, its also called the key column. 

From this point on we can perform table operations that directly affect the 
underlying database table. Lets insert some rows. 
```
tbl[] := [ 'setting_1',  'set_1',  'This is setting 1.',  FileRead('icon.jpg',"RAW") ]
tbl[] := [ 'setting_2',  'set_2',  'This is setting 2.',  FileRead('icon.jpg',"RAW") ]
tbl[] := [ 'setting_3',  'set_3',  'This is setting 3.',  FileRead('icon.jpg',"RAW") ]

msgbox 'RowCount=' tbl.RowCount ', ColCount=' tbl.ColCount
```
As seen above, the `tbl[]` syntax can be used to insert rows. The order and size 
of the assigned array reflect the actual columns of the `main settings` table. 
The above could also be written as: 
```
tbl.Insert( 'setting_1',  'set_1',  'This is setting 1.',  FileRead('icon.jpg',"RAW") )
tbl.Insert( 'setting_2',  'set_2',  'This is setting 2.',  FileRead('icon.jpg',"RAW") )
tbl.Insert( 'setting_3',  'set_3',  'This is setting 3.',  FileRead('icon.jpg',"RAW") )
```
Delete a row like that. 
```
tbl['setting_2'] := 0

msgbox 'RowCount=' tbl.RowCount
```
Or the same like this. 
```
tbl.Delete('setting_2')
```
Note that we can only use a value from the `name` column as an argument to 
`Delete()` since we `Link()`'ed to that column as the key column. To use the `value` column for example, 
we have to switch. But again, it has to be either a `UNIQUE` or `PRIMARY KEY` column. 
```
tbl.Switch('main settings', 'value') 

; 'value' column is the new key column now

tbl.Delete('set_3')

; insert deleted again
tbl[] := [ 'setting_2',  'set_2',  'This is setting 2.',  FileRead('icon.jpg',"RAW") ]
tbl[] := [ 'setting_3',  'set_3',  'This is setting 3.',  FileRead('icon.jpg',"RAW") ]
```
Replace a row. 
```
; switch to `name` column again
tbl.Switch('main settings', 'name') 

; change column 2 and 3 at row 'setting_1' which is a value of the current 'name' key column

tbl['setting_1'] := [ 'setting_1',  'new_set_1',  'New description for setting 1.',  FileRead('icon.jpg',"RAW") ]
;		^				^
;		|				|
;		+---------------+-----< replace requires these values to match

tbl.Switch('main settings', 'value') 

; change column 1 and 3 at row 'new_set_1' which is a value of the current 'value' key column

tbl['new_set_1'] := [ 'setting_new_1',  'new_set_1',  'Newer description for setting 1.',  FileRead('icon.jpg',"RAW") ]	
;		^									^
;		|									|
;		+-----------------------------------+------< replace requires these values to match
```
> Note that a `Replace` operation must not change its key column value. 

## Getting, Setting 
Get some cell values. 
```
tbl.Switch('main settings', 'name') 

value := tbl['setting_2']['name']   ; returns 'setting_2'
value := tbl['setting_2']['value']  ; returns 'set_2'

row := tbl['setting_2']

value := row['description']  	; returns 'This is setting 2.'
value := row['icon']  		  	; returns Buffer() conatining blob
```
Set some cell values. 
```
tbl['setting_2']['name'] := 'new_setting_2' 

; tbl['setting_2']['value'] := 'new_set_2'   ; <--- this would fail since we changed to 'new_setting_2'
tbl['new_setting_2']['value'] := 'new_set_2'

row := tbl['new_setting_2']

row['description'] := 'This is new setting 2' 
row['icon'] := FileRead('icon.jpg',"RAW")	
```

Receive a temporary copy of a row; changes to that copy wont affect the underlying 
database table. 
```
tmp_row := tbl['setting_3'][]
; OR
tmp_row := tbl.GetRow('setting_3')

msgbox tmp_row['description']   ; 'This is setting 3.'
```

Thats it. For more information refer to
* `SQLight\SQLight.ahk` source, which provides extensive documentation, especially useful when it comes to calling conventions and return values
* `SQLight\tests\SQLight_test.ahk` test file, with a bunch of examples to dive into
* [SQLite](https://sqlite.org)




