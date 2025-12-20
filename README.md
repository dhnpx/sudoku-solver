This program generates a random sudoku puzzle, solves it, and the number of steps it takes. 

It is written in Zig. 
Get the compiler: https://ziglang.org/download/
Or, install a distribution package. 

The data folder has 3 puzzles used to test function during development.
Compile using. `zig build` or run at the same time using `zig build run`.
Go to zig-out/bin directory to find the binary. Run using `./sudoku_solver`.

src/main.zig contains main and logic for solving the puzzle.  
src/sudoku.zig contains the struct, data structures, and functions related to it. 
build.zig contains the build steps. 
build.zig.zon contains the version, name, and min zig version required: 0.15.1. 

