const std = @import("std");
const fs = std.fs;

const Sudoku = @import("sudoku.zig").Sudoku;
const UnitType = @import("sudoku.zig").UnitType;
const Pair = @import("sudoku.zig").Pair;
const Triple = @import("sudoku.zig").Triple;
const Board_Setup = @import("board_setup.zig");

const sudoku_solver = @import("sudoku_solver");

var backtrack_count: u64 = 0;
var guess_count: u64 = 0;
var failed_guess_count: u64 = 0;

var debug = std.heap.DebugAllocator(.{}){};

const alloc_debug = debug.allocator();


pub fn main() !void {
    // Generate a puzzle (remove amount of cells given by parameter)
    var board = Board_Setup.Board.initRandomPuzzle(40);

    std.debug.print("Generated puzzle:\n", .{});
    board.print();

    
    const puzzle = board.toSudokuPuzzle();

    
    const filename: [:0]const u8 = "generated\n";

    var timer = try std.time.Timer.start();

    // Use const for simple solve, var for efficient solve with heuristics
    var sudoku = Sudoku.init(filename, puzzle) catch {
        std.debug.print("Error: failed initializing sudoku puzzle\n", .{});
        return;
    };

    // Uncomment the solver you want to use
    const sudoku_solved = solve(&sudoku);
    //const sudoku_solved = solveSimple(sudoku);

    const elapsed_ns = timer.read();

    const elapsed_ms = @as(f64, @floatFromInt (elapsed_ns)) / 1_000_000.0;

    std.debug.print("\nSolve time: {d:.3} ms\n", .{elapsed_ms});


    if (sudoku_solved) |solved| {
        std.debug.print("\nSolved puzzle:\n", .{});
        printSudokuGrid(solved.puzzle);
        std.debug.print("\nGuesses: {}\nFailed Guesses: {}\nBacktracking steps: {}\n", .{ guess_count, failed_guess_count, backtrack_count });
    } else {
        std.debug.print("No Solution\n", .{});
    }
}

fn printSudokuGrid(grid: [10][10]u4) void {
    for (1..10) |r| {
        if (r != 1 and (r - 1) % 3 == 0) {
            std.debug.print("------+-------+------\n", .{});
        }
        for (1..10) |c| {
            if (c != 1 and (c - 1) % 3 == 0) {
                std.debug.print("| ", .{});
            }

            const val = grid[r][c];
            std.debug.print("{d} ", .{val});
        }
        std.debug.print("\n", .{});
    }
}

fn reduceCandidates(sudoku: *Sudoku) bool {
    var non_stable = true;
    while (non_stable) {
        non_stable = false;
        const non_assigned_cells = sudoku.non_assigned_cells;

        if (non_assigned_cells.items.len == 0) {
            return true;
        }

        for (non_assigned_cells.items) |cell| {
            const row = cell.row;
            const col = cell.col;
            for (std.enums.values(UnitType)) |unit| {
                const unit_cells = sudoku.getUnitCells(row, col, unit) catch {
                    return false;
                };
                for (unit_cells.items) |unit_cell| {
                    if (sudoku.puzzle[unit_cell.row][unit_cell.col] != 0) {
                        sudoku.removeCellCandidate(row, col, sudoku.puzzle[unit_cell.row][unit_cell.col]);
                    }
                }
            }
            if (sudoku.isConstraintEmpty(row, col)) {
                return false;
            } else {
                const vals = sudoku.getCellCandidates(row, col) catch {
                    return false;
                };
                if (vals.items.len == 1) {
                    sudoku.setCellValue(row, col, vals.items[0]);
                    non_stable = true;
                }
            }
        }
    }
    return true;
}

fn uniqueCandidate(sudoku: *Sudoku) bool {
    var non_stable = true;
    while (non_stable) {
        non_stable = false;
        const non_assigned_cells = sudoku.non_assigned_cells;

        if (non_assigned_cells.items.len == 0) {
            return true;
        }

        for (non_assigned_cells.items) |cell| {
            const row = cell.row;
            const col = cell.col;
            const vals = sudoku.getCellCandidates(row, col) catch {
                return false;
            };
            for (vals.items) |val| {
                for (std.enums.values(UnitType)) |unit| {
                    const unit_cells = sudoku.getUnitCells(row, col, unit) catch {
                        return false;
                    };
                    var contained = false;
                    for (unit_cells.items) |unit_cell| {
                        if (!contained and sudoku.constraints[unit_cell.row][unit_cell.col].isSet(val - 1)) {
                            contained = true;
                        }
                    }
                    if (!contained) {
                        sudoku.setCellValue(row, col, val);
                        non_stable = true;
                        break;
                    }
                }
            }
        }
        if (non_stable) {
            if (!reduceCandidates(sudoku)) {
                return false;
            }
        }
    }
    return true;
}

fn hiddenPair(sudoku: *Sudoku) bool {
    var non_stable = true;
    const non_asssigned_cells = sudoku.getNonAssignedCellsWithCardinality() catch {
        return false;
    } orelse return false;
    if (non_asssigned_cells.items.len == 0) {
        return true;
    }

    for (non_asssigned_cells.items) |cell| {
        const row = cell.row;
        const col = cell.col;
        const vals = sudoku.getCellCandidates(row, col) catch {
            return false;
        };

        if (vals.items.len < 3) {
            continue;
        }

        for (0..vals.items.len - 1) |i| {
            for (i + 1..vals.items.len) |j| {
                const val1 = vals.items[i];
                const val2 = vals.items[j];

                for (std.enums.values(UnitType)) |unit| {
                    const unit_cells = sudoku.getUnitCells(row, col, unit) catch {
                        return false;
                    };
                    var val1_count: u4 = 0;
                    var val2_count: u4 = 0;
                    var pair_count: u4 = 0;
                    var unit_cells_with_pairs: std.ArrayList(Pair) = .empty;
                    defer unit_cells_with_pairs.deinit(alloc_debug);

                    for (unit_cells.items) |unit_cell| {
                        if (sudoku.constraints[unit_cell.row][unit_cell.col].isSet(val1 - 1) and sudoku.constraints[unit_cell.row][unit_cell.col].isSet(val2 - 1)) {
                            val1_count += 1;
                            val2_count += 1;
                            pair_count += 1;
                            unit_cells_with_pairs.append(alloc_debug, unit_cell) catch {
                                return false;
                            };
                        } else if (sudoku.constraints[row][col].isSet(val1 - 1)) {
                            val1_count += 1;
                        } else if (sudoku.constraints[row][col].isSet(val2 - 1)) {
                            val2_count += 1;
                        }
                    }
                    if (val1_count == 1 and val2_count == 1 and pair_count == 1) {
                        var candidates: std.ArrayList(u4) = .empty;
                        defer candidates.deinit(alloc_debug);
                        candidates.append(alloc_debug, val1) catch {
                            return false;
                        };
                        candidates.append(alloc_debug, val2) catch {
                            return false;
                        };
                        sudoku.setCellCandidates(row, col, candidates);

                        const pair = unit_cells_with_pairs.items[0];
                        sudoku.setCellCandidates(pair.row, pair.col, candidates);
                        non_stable = true;
                    }
                }
            }
        }
    }
    if (non_stable) {
        if (!reduceCandidates(sudoku)) {
            return false;
        }
    }
    return true;
}

fn nakedPair(sudoku: *Sudoku) bool {
    var non_stable = false;
    const non_assigned_cells = sudoku.non_assigned_cells;
    if (non_assigned_cells.items.len == 0) {
        return true;
    }

    for (non_assigned_cells.items) |cell| {
        const row = cell.row;
        const col = cell.col;
        const vals = sudoku.getCellCandidates(row, col) catch {
            return false;
        };
        if (vals.items.len != 2) {
            continue;
        }
        const val1 = vals.items[0];
        const val2 = vals.items[1];

        for (std.enums.values(UnitType)) |unit| {
            const unit_cells = sudoku.getUnitCells(row, col, unit) catch {
                return false;
            };
            var naked_pair_found = false;
            var unit_cells_with_pair: std.ArrayList(Pair) = .empty;
            for (unit_cells.items) |unit_cell| {
                if (sudoku.constraints[unit_cell.row][unit_cell.col].isSet(val1 - 1) and sudoku.constraints[unit_cell.row][unit_cell.col].isSet(val2 - 1)) {
                    const candidates = sudoku.getCellCandidates(unit_cell.row, unit_cell.col) catch {
                        return false;
                    };
                    if (candidates.items.len == 2) {
                        naked_pair_found = true;
                    } else {
                        unit_cells_with_pair.append(alloc_debug, unit_cell) catch {
                            return false;
                        };
                    }
                }
            }
            if (naked_pair_found) {
                for (unit_cells_with_pair.items) |unit_cell| {
                    sudoku.removeCellCandidate(unit_cell.row, unit_cell.col, val1);
                    sudoku.removeCellCandidate(unit_cell.row, unit_cell.col, val2);
                }
                non_stable = true;
            }
        }
    }
    if (non_stable) {
        if (!reduceCandidates(sudoku)) {
            return false;
        }
    }
    return true;
}

fn solve(sudoku: *Sudoku) ?Sudoku {
    if (sudoku.isSolved()) {
        return sudoku.*;
    }
    if (reduceCandidates(sudoku) and sudoku.isSolved()) {
        return sudoku.*;
    }
    if (uniqueCandidate(sudoku) and sudoku.isSolved()) {
        return sudoku.*;
    }
    if (hiddenPair(sudoku) and sudoku.isSolved()) {
        return sudoku.*;
    }
    if (nakedPair(sudoku) and sudoku.isSolved()) {
        return sudoku.*;
    }

    const non_assigned_cells = sudoku.getNonAssignedCellsWithCardinality() catch {
        return null;
    } orelse return null;

    std.mem.sort(Triple, non_assigned_cells.items, {}, compareCellsByCardinality);

    for (non_assigned_cells.items) |cell| {
        const vals = sudoku.getCellCandidates(cell.row, cell.col) catch {
            return null;
        };
        for (vals.items) |val| {
            if (sudoku.isLegalAssignment(cell.row, cell.col, val)) {
                var sudoku_new = sudoku.clone() catch {
                    return null;
                };

                sudoku_new.setCellValue(cell.row, cell.col, val);

                guess_count += 1;
                const solved = solve(&sudoku_new);

                if (solved == null) {
                    failed_guess_count += 1;
                }

                if (solved) |solution| {
                    var solution_mut = solution;
                    if (solution_mut.isSolved()) {
                        return solution_mut;
                    }
                }
            }
        }
        backtrack_count += 1;
        return null;
    }
    return null;
}

fn readPuzzle(file: fs.File) Error![10][10]u4 {
    var puzzle: [10][10]u4 = std.mem.zeroes([10][10]u4);

    var buf: [256]u8 = undefined;
    const bytes_read = file.read(&buf) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return Error.FileIO;
    };

    const data = buf[0..bytes_read];

    var lines = std.mem.splitScalar(u8, data, '\n');
    var row: usize = 1;
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (row > 9) {
            return Error.TooManyRows;
        }
        var nums = std.mem.splitScalar(u8, line, ' ');
        var col: usize = 1;
        while (nums.next()) |num| {
            if (col > 9) {
                return Error.TooManyColumns;
            }
            const num_int = std.fmt.parseInt(u4, num, 10) catch {
                return Error.NonValidNumber;
            };
            if (num_int > 9 or num_int < 0) {
                return Error.NonValidNumber;
            }
            puzzle[row][col] = num_int;
            col += 1;
        }
        if (col <= 9) {
            return Error.NotEnoughColumns;
        }
        row += 1;
    }
    if (row <= 9) {
        return Error.NotEnoughRows;
    }

    return puzzle;
}

fn compareCellsByCardinality(context: void, a: Triple, b: Triple) bool {
    _ = context;
    return a.cardinality < b.cardinality;
}
fn solveSimple(sudoku2: Sudoku) ?Sudoku {
    // If already solved, just return it.

    var sudoku = sudoku2;
    if (sudoku.isSolved()) {
        return sudoku;
    }

    // Find the first empty cell (value == 0)
    var row_empty: u4 = 0;
    var col_empty: u4 = 0;
    var found_empty = false;

    for (1..10) |r| {
        for (1..10) |c| {
            const row: u4 = @intCast(r);
            const col: u4 = @intCast(c);
            if (sudoku.puzzle[row][col] == 0) {
                row_empty = row;
                col_empty = col;
                found_empty = true;
                break;
            }
        }
        if (found_empty) break;
    }

    // No empty cells -> either solved or invalid
    if (!found_empty) {
        return if (sudoku.isSolved()) sudoku else null;
    }

    // Try all values 1..9 for this cell
    const row = row_empty;
    const col = col_empty;

    // We work on a *copy* per branch so we don't need to undo
    var val: u4 = 1;
    while (val <= 9) : (val += 1) {
        if (sudoku.isLegalAssignment(row, col, val)) {
            // Clone the current sudoku
            var sudoku_new = sudoku.clone() catch {
                // Treat OOM as "no solution"
                return null;
            };

            // Assign the value
            sudoku_new.setCellValue(row, col, val);

            guess_count += 1;

            // Recurse
            const solved = solveSimple(sudoku_new);

            if (solved == null) {
                failed_guess_count += 1;
            }

            if (solved) |solution| {
                // Double-check
                var solution_mut = solution;
                if (solution_mut.isSolved()) {
                    return solution_mut;
                }
            }
        }
    }

    // None of the values worked -> backtrack
    backtrack_count += 1;
    return null;
}
const Error = error{
    InvalidPuzzle,
    NotEnoughColumns,
    TooManyColumns,
    NotEnoughRows,
    TooManyRows,
    NonValidNumber,
    FileIO,
};
