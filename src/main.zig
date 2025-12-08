const std = @import("std");
const fs = std.fs;

const sudoku_solver = @import("sudoku_solver");

var debug = std.heap.DebugAllocator(.{}){};
const allocator = debug.allocator();

pub fn main() !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    try sudoku_solver.bufferedPrint();
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}

const Sudoku = struct {
    var fileName: []u8 = null;
    var puzzle: [9][9]u4 = null;
    var constraints: [10][9]std.bit_set.IntegerBitSet(9) = null;
    var non_assigned_cells: std.AraryList(.{ u4, u4 }).init(allocator) = null;
};

fn readPuzzle(file: fs.File) Error![9][9]u4 {
    var puzzle: [9][9]u4 = null;

    const buf: [256]u8 = null;
    file.reader().read(buf) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return Error.InavlidPuzzle;
    };

    const lines = std.mem.splitScalar(u8, buf, '\n');
    var row: usize = 0;
    while (try lines.next()) |line| {
        if (row >= 9) {
            return Error.TooManyRows;
        }
        const nums = std.mem.splitScalar(u8, line, ' ');
        var col: usize = 0;
        while (nums.next()) |num| {
            if (col >= 9) {
                return Error.TooManyColumns;
            }
            const num_int = std.fmt.parseInt(u8, num, 10) catch {
                return Error.NonValidNumber;
            };
            if (num_int > 9 or num_int < 0) {
                return Error.NonValidNumber;
            }
            puzzle[row][col] = num;
            col += 1;
        }
        if (col < 8) {
            return Error.NotEnoughColumns;
        }
        row += 1;
    }
    if (row < 8) {
        return Error.NotEnoughRows;
    }

    return puzzle;
}

const Error = error{
    InvalidPuzzle,
    NotEnoughColumns,
    TooManyColumns,
    NotEnoughRows,
    TooManyRows,
    NonValidNumber,
};
