const std = @import("std");


pub const Board = struct {
    cells: [9][9]u4,

    /// Create a randomized and valid solved Sudoku board.
    pub fn initRandom() Board {
        var board = Board.initBaseSolved();

        var seed: u64 = 0;
        std.crypto.random.bytes(std.mem.asBytes(&seed));

        var prng = std.Random.DefaultPrng.init(seed);
        const random = prng.random();

        board.randomizeDigits(random);
        board.randomizeRowsWithinBands(random);
        board.randomizeColsWithinStacks(random);
        board.randomizeBands(random);
        board.randomizeStacks(random);

        return board;
    }

    pub fn toSudokuPuzzle(self: *const Board) [10][10]u4 {
        var puzzle: [10][10]u4 = std.mem.zeroes([10][10]u4);

        var r: usize = 0;
        while (r < 9) : (r += 1) {
            var c: usize = 0;
            while (c < 9) : (c += 1) {
                // shift puzzle into [1..9][1..9]
                puzzle[r + 1][c + 1] = self.cells[r][c];
            }
        }

        return puzzle;
   }

    // Print the board to the terminal using std.debug.print
    pub fn print(self: *const Board) void {
        for (self.cells, 0..) |row, r| {
            if (r != 0 and r % 3 == 0) {
                std.debug.print("------+-------+------\n", .{});
            }
            for (row, 0..) |val, c| {
                if (c != 0 and c % 3 == 0) {
                    std.debug.print("| ", .{});
                }

                if (val == 0) {
                    // Empty cell
                    std.debug.print(". ", .{});
                }

                else {

                std.debug.print("{d} ", .{val});
                }
            }
            std.debug.print("\n", .{});
        }
    }

        pub fn initRandomPuzzle(hole_count: usize) Board {
        // Start from a fully solved random board
        var board = Board.initRandom();

        var seed: u64 = 0;
        std.crypto.random.bytes(std.mem.asBytes(&seed));

        var prng = std.Random.DefaultPrng.init(seed);
        const random = prng.random();

        var holes = hole_count;
        if (holes > 81) holes = 81;

        board.makeBlanks(random, holes);
        return board;
    }

    // ---------- internal helpers ----------

    fn initBaseSolved() Board {
        // Simple valid solved Sudoku pattern.
        const base: [9][9]u4 = .{
            .{ 1, 2, 3, 4, 5, 6, 7, 8, 9 },
            .{ 4, 5, 6, 7, 8, 9, 1, 2, 3 },
            .{ 7, 8, 9, 1, 2, 3, 4, 5, 6 },

            .{ 2, 3, 4, 5, 6, 7, 8, 9, 1 },
            .{ 5, 6, 7, 8, 9, 1, 2, 3, 4 },
            .{ 8, 9, 1, 2, 3, 4, 5, 6, 7 },

            .{ 3, 4, 5, 6, 7, 8, 9, 1, 2 },
            .{ 6, 7, 8, 9, 1, 2, 3, 4, 5 },
            .{ 9, 1, 2, 3, 4, 5, 6, 7, 8 },
        };
        return .{ .cells = base };
    }

        fn makeBlanks(self: *Board, random: std.Random, hole_count: usize) void {
        var remaining = hole_count;

        // Keep picking random positions until its cleared enough cells.
        while (remaining > 0) {
            const r = random.uintLessThan(usize, 9);
            const c = random.uintLessThan(usize, 9);

            if (self.cells[r][c] != 0) {
                self.cells[r][c] = 0;
                remaining -= 1;
            }
        }
    }

    fn randomizeDigits(self: *Board, random: std.Random) void {
        // mapping[d] = new digit for d
        var mapping: [10]u4 = undefined;
        mapping[0] = 0; // if you ever use 0 for empty later

        var digits = [_]u4{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };

        // Fisher–Yates shuffle for digits
        var i: usize = digits.len;
        while (i > 1) {
            i -= 1;
            const j = random.uintLessThan(usize, i + 1);
            const tmp = digits[i];
            digits[i] = digits[j];
            digits[j] = tmp;
        }

        // Build mapping: original digit -> shuffled digit
        var d: usize = 0;
        while (d < 9) : (d += 1) {
            mapping[d + 1] = digits[d];
        }

        // Apply mapping to all cells
        var r: usize = 0;
        while (r < 9) : (r += 1) {
            var c: usize = 0;
            while (c < 9) : (c += 1) {
                const v = self.cells[r][c];
                self.cells[r][c] = mapping[@intCast(v)];
            }
        }
    }

    fn randomizeRowsWithinBands(self: *Board, random: std.Random) void {
        // Swap rows within each band (0–2, 3–5, 6–8)
        var band: usize = 0;
        while (band < 3) : (band += 1) {
            const base_row = band * 3;

            // do a few swaps per band
            var k: usize = 0;
            while (k < 4) : (k += 1) {
                const r1 = base_row + random.uintLessThan(usize, 3);
                const r2 = base_row + random.uintLessThan(usize, 3);
                if (r1 != r2) self.swapRows(r1, r2);
            }
        }
    }

    fn randomizeColsWithinStacks(self: *Board, random: std.Random) void {
        // Swap columns within each stack (0–2, 3–5, 6–8)
        var stack: usize = 0;
        while (stack < 3) : (stack += 1) {
            const base_col = stack * 3;

            var k: usize = 0;
            while (k < 4) : (k += 1) {
                const c1 = base_col + random.uintLessThan(usize, 3);
                const c2 = base_col + random.uintLessThan(usize, 3);
                if (c1 != c2) self.swapCols(c1, c2);
            }
        }
    }

    fn randomizeBands(self: *Board, random: std.Random) void {
        var order = [_]usize{ 0, 1, 2 };
        Board.shuffleThree(random, &order);
        self.applyBandOrder(order);
    }

    fn randomizeStacks(self: *Board, random: std.Random) void {
        var order = [_]usize{ 0, 1, 2 };
        Board.shuffleThree(random, &order);
        self.applyStackOrder(order);
    }

    fn swapRows(self: *Board, r1: usize, r2: usize) void {
        const tmp = self.cells[r1];
        self.cells[r1] = self.cells[r2];
        self.cells[r2] = tmp;
    }

    fn swapCols(self: *Board, c1: usize, c2: usize) void {
        var r: usize = 0;
        while (r < 9) : (r += 1) {
            const tmp = self.cells[r][c1];
            self.cells[r][c1] = self.cells[r][c2];
            self.cells[r][c2] = tmp;
        }
    }

    fn shuffleThree(random: std.Random, order: *[3]usize) void {
        var i: usize = order.len;
        while (i > 1) {
            i -= 1;
            const j = random.uintLessThan(usize, i + 1);
            const tmp = order[i];
            order[i] = order[j];
            order[j] = tmp;
        }
    }

    fn applyBandOrder(self: *Board, order: [3]usize) void {
        var new_cells: [9][9]u4 = undefined;

        var dest_band: usize = 0;
        while (dest_band < 3) : (dest_band += 1) {
            const src_band = order[dest_band];
            const dest_base = dest_band * 3;
            const src_base = src_band * 3;

            var i: usize = 0;
            while (i < 3) : (i += 1) {
                new_cells[dest_base + i] = self.cells[src_base + i];
            }
        }

        self.cells = new_cells;
    }

    fn applyStackOrder(self: *Board, order: [3]usize) void {
        var new_cells: [9][9]u4 = undefined;

        var dest_stack: usize = 0;
        while (dest_stack < 3) : (dest_stack += 1) {
            const src_stack = order[dest_stack];
            const dest_base = dest_stack * 3;
            const src_base = src_stack * 3;

            var r: usize = 0;
            while (r < 9) : (r += 1) {
                var i: usize = 0;
                while (i < 3) : (i += 1) {
                    new_cells[r][dest_base + i] = self.cells[r][src_base + i];
                }
            }
        }

        self.cells = new_cells;
    }
};

