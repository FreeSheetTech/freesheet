# freesheet

## Technical Overview

Freesheet is a really simple functional programming language.  
It is intended to be easy enough to be usable by people without programming experience,
but also powerful enough to use in a wide range of applications.

A Freesheet program is just a list of function names and definitions.
Functions with no arguments are called 'named values', and they are evaluated continuously.
Functions with arguments are only evaluated when they are used in the definitions of other functions.

A function definition is an expression which can use:

- literals for simple types, lists and objects
- arithmetic and logical operators
- function calls

Freesheet can be written as plain text, but the simple 'name = expression' format
means it can also be displayed in a table.  
The associated freesheet-web project provides tools for editing Freesheet programs in a spreadsheet-like table, 
which also displays the current value of each named value.

A Freesheet application would probably be organised into multiple separate worksheets to make it easier to understand.
A worksheet can reference values in other worksheets.

As well as functions defined in the worksheet by the user, the worksheet can provide pre-defined functions.
Freesheet provides a number of generally useful functions, but an application can easily add new pre-defined functions (written in JavaScript).

### Reactivity

A really important point about Freesheet programs is that they don't just run and then stop.
When started, they wait for inputs and continuously update all their named values as new inputs arrive.
They also update named values if function definitions are changed while the program is running.
Named values and changes are available to any observer by a standard callback mechanism.

 
### Implementation
 
Freesheet is written in Coffeescript.  It uses many open source libraries, notably Pegjs for parsing and Rx JS for the reactive functionality.
  
The core freesheet project can parse individual function definitions or entire worksheet scripts from text, and run a set of worksheets.  

### Suitability for non-technical users
- Spreadsheet-like
- Functions and expressions
- Continuous evaluation of code while running
- Continuous updates from inputs while running



