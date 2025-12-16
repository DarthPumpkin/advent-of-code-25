const std = @import("std");
const benchmark = @import("benchmark.zig");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;
const expect = std.testing.expect;

const Solution = u64;

// Low-level I/O settings
const max_size = math.maxInt(usize);
const stdout_buffersize = 1024;

fn solve(base_alloc: mem.Allocator, input_str: []const u8) !Solution {
    var arena = std.heap.ArenaAllocator.init(base_alloc);
    defer arena.deinit();
    const al = arena.allocator();
    // _ = base_alloc;

    const n_red_tiles = mem.count(u8, input_str, "\n") + 1;
    const red_tiles = try al.alloc(Tile, n_red_tiles);
    defer al.free(red_tiles);
    // const areas = try StrictlyLowerTriangularMatrix.initAlloc(al, n_red_tiles);
    var max_area: Solution = 0;
    var i: usize = 0;
    var lines = mem.tokenizeScalar(u8, input_str, '\n');
    while (lines.next()) |line| {
        var xy = mem.tokenizeScalar(u8, line, ',');
        const x = try std.fmt.parseInt(u64, xy.next().?, 10);
        const y = try std.fmt.parseInt(u64, xy.next().?, 10);
        assert(xy.peek() == null);
        const tile: Tile = .{ .x = x, .y = y };
        for (0..i) |j| {
            const other = red_tiles[j];
            const side_1 = @max(tile.x, other.x) - @min(tile.x, other.x) + 1;
            const side_2 = @max(tile.y, other.y) - @min(tile.y, other.y) + 1;
            const area = side_1 * side_2;
            max_area = @max(max_area, area);
        }
        red_tiles[i] = tile;
        i += 1;
    }
    return max_area;
}

const Tile = struct { x: u64, y: u64 };

// Modified from Day 8
const StrictlyLowerTriangularMatrix = struct {
    data: []u64,
    n: usize,

    pub fn initAlloc(al: mem.Allocator, n: usize) !@This() {
        const data = try al.alloc(u64, n);
        return .{ .data = data, .n = n };
    }

    pub fn deinit(self: @This(), al: mem.Allocator) void {
        al.free(self.data);
    }

    pub fn numel(self: @This()) usize {
        const n = self.n;
        return (n * (n - 1)) / 2;
    }

    pub fn at(self: *@This(), row: usize, col: usize) *u64 {
        const actual_row = @max(row, col);
        const actual_col = @min(row, col);
        assert(actual_row >= 1);
        assert(actual_row > actual_col);
        assert(actual_row < self.n);

        const idx = (actual_row * (actual_row - 1)) / 2 + actual_col;
        return &self.data[idx];
    }

    pub fn unlinearize(self: @This(), linear: usize) struct { row: usize, col: usize } {
        assert(linear < self.numel());
        const r = (math.sqrt(8 * linear + 1) + 1) / 2;
        const base = (r * (r - 1)) / 2;
        const c = linear - base;
        return .{ .row = r, .col = c };
    }
};

fn debugPrintLn(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}

fn printLn(comptime fmt: []const u8, args: anytype) !void {
    var stdout_buffer: [stdout_buffersize]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(fmt ++ "\n", args);
    try stdout.flush();
}

const SolveContext = struct {
    base_allocator: mem.Allocator,
    input_str: []const u8,
};

fn solve_timed(_: mem.Allocator, context: SolveContext, _: *std.time.Timer) !void {
    std.mem.doNotOptimizeAway(solve(context.base_allocator, context.input_str));
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        debugPrintLn("Memory check: {any}", .{deinit_status});
    }

    const fileContent = try std.fs.cwd().readFileAlloc(alloc, "input.txt", max_size);
    defer alloc.free(fileContent);

    const solution = try solve(alloc, fileContent);
    try printLn("Answer: {}", .{solution});
}

test "Example" {
    const solution = 50;
    const example_file_name = "example.txt";

    const alloc = std.testing.allocator;
    const fileContent = try std.fs.cwd().readFileAlloc(alloc, example_file_name, max_size);
    defer alloc.free(fileContent);

    const sum = try solve(alloc, fileContent);
    debugPrintLn("Example answer: {d}", .{sum});

    try std.testing.expectEqual(solution, sum);
}

test "Benchmark" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        debugPrintLn("Memory check: {any}", .{deinit_status});
    }

    const fileContent = try std.fs.cwd().readFileAlloc(alloc, "input.txt", max_size);
    defer alloc.free(fileContent);

    const context = SolveContext{
        .base_allocator = alloc,
        .input_str = fileContent,
    };
    const result = try benchmark.runC(context, solve_timed);
    result.print("solve");
}
