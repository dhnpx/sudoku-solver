const std = @import("std");

pub const Pair = struct { row: u4, col: u4 };
pub const Triple = struct { row: u4, col: u4, cardinality: u4 };
pub const UnitType = enum { Row, Column, Block };

var debug = std.heap.DebugAllocator(.{}){};
const alloc_debug = debug.allocator();


pub const Sudoku = struct {
    filename: [:0]const u8,
    puzzle: [10][10]u4 = std.mem.zeroes([10][10]u4),
    constraints: [11][10]std.bit_set.IntegerBitSet(9),
    non_assigned_cells: std.ArrayList(Pair),

    pub fn print(self: *const Sudoku) void {
        for (1..10) |row| {
            for (1..10) |col| {
                if (col == self.puzzle[row].len - 1) {
                    std.debug.print("{}\n", .{self.puzzle[row][col]});
                } else {
                    std.debug.print("{} ", .{self.puzzle[row][col]});
                }
            }
        }
    }

    pub fn init(filename: [:0]const u8, puzzle: [10][10]u4) !Sudoku {
        var constraints: [11][10]std.bit_set.IntegerBitSet(9) = undefined;
        var non_assigned_cells: std.ArrayList(Pair) = .empty;
        for (0..constraints.len) |row| {
            for (0..constraints[row].len) |col| {
                constraints[row][col] = std.bit_set.IntegerBitSet(9).initEmpty();
            }
        }
        for (1..10) |row| {
            for (1..10) |col| {
                if (puzzle[row][col] == 0) {
                    constraints[row][col] = std.bit_set.IntegerBitSet(9).initFull();
                    try non_assigned_cells.append(alloc_debug, .{ .row = @intCast(row), .col = @intCast(col) });
                } else {
                    constraints[row][col].set(puzzle[row][col] - 1);
                    constraints[row][0].set(puzzle[row][col] - 1);
                    constraints[0][col].set(puzzle[row][col] - 1);
                    constraints[10][getBlockIndex(@intCast(row), @intCast(col))].set(puzzle[row][col] - 1);
                }
            }
        }
        return Sudoku{
            .filename = filename,
            .puzzle = puzzle,
            .constraints = constraints,
            .non_assigned_cells = non_assigned_cells,
        };
    }

    pub fn deinit(self: *Sudoku) void {
        self.non_assigned_cells.deinit(alloc_debug);
    }

    pub fn clone(self: *const Sudoku) !Sudoku {
        var sudoku_new = try Sudoku.init(self.filename, self.puzzle);
        sudoku_new.constraints = self.constraints;
        sudoku_new.non_assigned_cells = .empty;
        try sudoku_new.non_assigned_cells.appendSlice(alloc_debug, self.non_assigned_cells.items);

        return sudoku_new;
    }

    pub fn isSolved(self: *const Sudoku) bool {
        for (1..10) |i| {
            if (self.constraints[i][0].count() != 9 or self.constraints[0][i].count() != 9 or self.constraints[10][i].count() != 9) {
                return false;
            }
        }
        return true;
    }

    pub fn getBlockIndex(row: u4, col: u4) u4 {
        const left_corner_row = ((row - 1) / 3) * 3 + 1;
        const left_corner_col = ((col - 1) / 3) * 3 + 1;
        return (left_corner_row - 1) / 3 * 3 + left_corner_col / 3 + 1;
    }

    pub fn isLegalAssignment(self: *Sudoku, row: u4, col: u4, val: u4) bool {
        return (!self.constraints[row][0].isSet(val - 1) and !self.constraints[0][col].isSet(val - 1) and !self.constraints[10][getBlockIndex(row, col)].isSet(val - 1));
    }

    pub fn getNonAssignedCellsWithCardinality(self: *const Sudoku) !?std.ArrayList(Triple) {
        var non_assigned_cells_with_cardinality: std.ArrayList(Triple) = .empty;
        for (self.non_assigned_cells.items) |cell| {
            if (self.constraints[cell.row][cell.col].mask == 0) {
                return null;
            }
            const triple: Triple = .{ .row = cell.row, .col = cell.col, .cardinality = @intCast(self.constraints[cell.row][cell.col].count()) };
            try non_assigned_cells_with_cardinality.append(alloc_debug, triple);
        }
        return non_assigned_cells_with_cardinality;
    }

    pub fn removeCellCandidate(self: *Sudoku, row: u4, col: u4, val: u4) void {
        self.constraints[row][col].unset(val - 1);
    }

    pub fn setCellCandidates(self: *Sudoku, row: u4, col: u4, vals: std.ArrayList(u4)) void {
        self.constraints[row][col] = std.bit_set.IntegerBitSet(9).initEmpty();
        for (vals.items) |val| {
            self.constraints[row][col].set(val - 1);
        }
    }

    pub fn getCellCandidates(self: *const Sudoku, row: u4, col: u4) !std.ArrayList(u4) {
        var vals: std.ArrayList(u4) = .empty;
        var constraints = self.constraints[row][col].iterator(.{});
        while (constraints.next()) |i| {
            try vals.append(alloc_debug, @intCast(i + 1));
        }
        return vals;
    }

    pub fn setCellValue(self: *Sudoku, row: u4, col: u4, val: u4) void {
        self.puzzle[row][col] = val;
        self.constraints[row][col] = std.bit_set.IntegerBitSet(9).initEmpty();
        self.constraints[row][col].set(val - 1);

        self.constraints[row][0].set(val - 1);
        self.constraints[0][col].set(val - 1);
        self.constraints[10][getBlockIndex(row, col)].set(val - 1);

        for (self.non_assigned_cells.items, 0..) |cell, i| {
            if (cell.row == row and cell.col == col) {
                _ = self.non_assigned_cells.swapRemove(i);
            }
        }
    }

    pub fn getBlockLeftCorner(row: u4, col: u4) Pair {
        const corner_row = ((row - 1) / 3) * 3 + 1;
        const corner_col = ((col - 1) / 3) * 3 + 1;
        return .{ .row = corner_row, .col = corner_col };
    }

    pub fn getUnitCells(self: *const Sudoku, row: u4, col: u4, unit: UnitType) !std.ArrayList(Pair) {
        _ = self;
        var cells: std.ArrayList(Pair) = .empty;
        switch (unit) {
            UnitType.Row => {
                for (1..10) |i| {
                    if (i != col) {
                        try cells.append(alloc_debug, .{ .row = row, .col = @intCast(i) });
                    }
                }
            },
            UnitType.Column => {
                for (1..10) |i| {
                    if (i != row) {
                        try cells.append(alloc_debug, .{ .row = @intCast(i), .col = col });
                    }
                }
            },
            UnitType.Block => {
                const block_corner = getBlockLeftCorner(row, col);
                const r = block_corner.row;
                for (r..(r + 3)) |row_block| {
                    const c = block_corner.col;
                    for (c..(c + 3)) |col_block| {
                        if (row_block != row or col_block != col) {
                            try cells.append(alloc_debug, .{ .row = @intCast(row_block), .col = @intCast(col_block) });
                        }
                    }
                }
            },
        }
        return cells;
    }

    pub fn isConstraintEmpty(self: *Sudoku, row: u4, col: u4) bool {
        return self.constraints[row][col].mask == 0;
    }
};
