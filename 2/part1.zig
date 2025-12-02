const std = @import("std");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;
const expect = std.testing.expect;

const Solution = u64;

const max_size = math.maxInt(usize);
const stdout_buffersize = 1024;

fn solve(base_alloc: mem.Allocator, input_str: []u8) !Solution {
    // var arena = std.heap.ArenaAllocator.init(base_alloc);
    // defer arena.deinit();
    // const arena_alloc = arena.allocator();
    _ = base_alloc;

    var sum: Solution = 0;
    var lines = mem.tokenizeScalar(u8, input_str, ',');
    while (lines.next()) |range_str| {
        const range = try RangeInclusive.parse(range_str);
        sum += solve_single(range);
    }
    return sum;
}

fn solve_single(range: RangeInclusive) Solution {
    // const lo_ndigits = blk: {
    //     var ndigits = math.log10_int(range.lo);
    //     const floor10 = math.powi(u64, 10, ndigits)!unreachable;
    //     if (range.lo > floor10)
    //         ndigits += 1;
    //     break :blk ndigits;
    // };
    // debugPrintLn(".{}", .{range});
    const lo_ndigits = math.log10_int(range.lo) + 1;
    var id_part: Solution = undefined;
    if (lo_ndigits % 2 == 1) {
        const id_ndigits = math.divCeil(u64, lo_ndigits, 2) catch unreachable;
        id_part = math.powi(u64, 10, id_ndigits - 1) catch unreachable;
    } else {
        const id_ndigits = math.divExact(u64, lo_ndigits, 2) catch unreachable;
        const truncate_ndigits = lo_ndigits - id_ndigits;
        const truncate_div = math.powi(u64, 10, truncate_ndigits) catch unreachable;
        id_part = range.lo / truncate_div;
        if (twice(id_part) < range.lo)
            id_part += 1;
    }
    var sum: Solution = 0;
    while (twice(id_part) <= range.hi) {
        sum += twice(id_part);
        id_part += 1;
        // debugPrintLn("{}\tNext ID part: {}", .{ sum, id_part });
    }
    // debugPrintLn("Answer:\t {}", .{sum});
    return sum;
}

fn twice(n: u64) u64 {
    const ndigits = math.log10_int(n) + 1;
    // const floor10 = math.powi(u64, 10, ndigits) catch unreachable;
    // if (n > floor10)
    //     ndigits += 1;
    const ceil10 = math.powi(u64, 10, ndigits) catch unreachable;
    const first = ceil10 * n;
    return first + n;
}

const RangeInclusive = struct {
    lo: u64,
    hi: u64,

    pub fn init(lo: u64, hi: u64) @This() {
        assert(lo < hi);
        return .{ .lo = lo, .hi = hi };
    }

    pub fn parse(str: []const u8) !@This() {
        var parts = mem.tokenizeScalar(u8, str, '-');
        const lo = try std.fmt.parseInt(u64, parts.next().?, 10);
        const hi = try std.fmt.parseInt(u64, parts.next().?, 10);
        assert(parts.peek() == null);
        return .init(lo, hi);
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
    try printLn("Input answer: {d}", .{solution});
}

test "twice" {
    try std.testing.expectEqual(33, twice(3));
    try std.testing.expectEqual(1717, twice(17));
    try std.testing.expectEqual(100100, twice(100));
}

// test "solve_single" {
//     const range1: RangeInclusive = .{ .lo = 11, .hi = 22 };
// }

test "Example" {
    const solution = 1227775554;
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

    const tic = std.time.microTimestamp();
    const fileContent = try std.fs.cwd().readFileAlloc(alloc, "input.txt", max_size);
    defer alloc.free(fileContent);

    const tac = std.time.microTimestamp();
    defer {
        const toc = std.time.microTimestamp();
        printLn("readFile took {d}μs", .{tac - tic}) catch {
            debugPrintLn("Failed to print to stdout", .{});
        };
        printLn("solve took {d}μs", .{toc - tac}) catch {
            debugPrintLn("Failed to print to stdout", .{});
        };
    }

    _ = try solve(alloc, fileContent);
}
