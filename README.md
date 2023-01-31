README 
------

 Name: SQL Developer SQLcl
 Desc: Oracle SQL Developer Command Line (SQLcl) is a free command line 
       interface for Oracle Database. It allows you to interactively or 
       batch execute SQL and PL/SQL. SQLcl provides in-line editing, statement
       completion, and command recall for a feature-rich experience, all while
       also supporting your previously written SQL*Plus scripts.
 Version: 22.4.0.342.1212
 Build: 22.4.0.342.1215

# Release Notes 

Release 21.4.0
==============

This release has focused on stability closing over 100 issues in the last quarter, with other new features in development for future releases.

## Features
### ARGUMENT command
The Argument command in SQLcl allows for default values, prompts, and descriptions of positional parameters to sql scripts.
These arguments can be managed using the define command as usual.

Example(s):
Example: Set argument default.
```
@test
sql>REM test.sql
sql>argument 1 default arg1
sql>argument 2 default arg2
sql>>select '&1' , '&2' from dual;
'ARG1'    'ARG2'
______    ______
arg1      arg2
1 row selected.

sql> define
...
DEFINE 1 =  "arg1" (CHAR)
DEFINE 2 =  "arg2" (CHAR)
```
### LIQUIBASE Schema for DATABASECHANGELOG
ENH 34385737 introduced support for specifying a schema for Liquibase DATABASECHANGELOG TABLE with liquibase-schema-name parameter

## BUG FIXES
34150911 - LARGER SET LONG VALUES AND QUERYING CLOBS RESULTS IN MEMORY JAVA STACK JUMP
34280334 - SQLCL DO NOT DISPLAY THE FULL POSITION FOR ORA ERRORS
34718099 - "1 USER-DEFINED EXCEPTION" ERROR IN SQLCL FOR ANONYMOUS BLOCKS
34037876 - SQL.EXE GIVES unfriendly error when using JAVA 8
34796602 - Improved help examples for CS, OCI, & DATAPUMP commands
34690300 - APEX EXPORT -instance fails with SQL statement to execute cannot be empty or null
34801181 - LIQUIBASE changelog for queue table with plsql array payload results in SORT ORDER WRONG FOR TYPE AND ARRAY OF TYPE
34696971 - LIQUIBASE generate-schema fails with Unexpected internal error near index 1
34742696 - LIQUIBASE COMMANDS -DIFF-TYPES not being honor#End Region
34741854 - DATABASECHANGELOG_ACTIONS CAN BE INCOMPLETE DUE TO ORA-06502
34714807 - LIQUIBASE GENERATE-SCHEMA Illegal char <:> at index
34714868 - LIQUIBASE use -search-path parameter together with lb update/update-sql fails on Windows
34680167 - LIQUIBASE fails to parse valid PL/SQL object
34689522 - LIQUIBASE GENERATE-APEX-OBJECT -DIR OPTION IGNORES CAPITALS

Release 21.2
============

From Release 21.2, the console has been upgraded which has meant changes to several subsystems in SQLcl, namely
  * Multiline Editing
  * history
  * keymaps - Support for VI and EMACS (set editor, show keymap)
And we have built upon that to include several new features
  * Highlighting - set highlight on
  * Statusbar - set statusbar on
  * Completers - File, tns, net and argument
  * Extensions - API has been published for creating SQLcl extension. View them with "show extensions"

Some other things of note:
Memory settings:
  We've put the max memory settings to 2gb now to accommodate very large buffers 

Copy/Paste functionality:
  Paste will act differently on Mac vs Windows/Linux.
  On Windows/Linux, a paste will process all statements individually as they are read in.
  On Mac, a paste will process statements altogether at the end of the paste.
  All results are the same in each case. The printed output will differ if echo is on.

Scrolling on Windows Terminal:
  In some situations when using Windows Terminal, the terminal window scroll bar becomes deactivated when using status bar.
  This issue has not been observed when using either Command Prompt or PowerShell.

Status Bar and resize:
  Occasionally when using status bar and following a terminal window resize, unexpected characters have been seen in the terminal window.
  If this occurs, then control-L may be used to clear and redraw the terminal window.


Release 20.2
============

Ansiconsole as default SQLFormat
--------------------------------
From SQLcl 20.2, AnsiConsole Format is on by default.  This means that certain 
features will not work as expect until the format is set to default.

These include the SQL\*Plus features
  * HEADING
  * TTITLE
  * BREAK
  * COMPUTE

SQL> set sqlformat default. 

If you have extensive use of SQL\*Plus style reports, you need to unset
sqlformat via login.sql or add it to your reports
