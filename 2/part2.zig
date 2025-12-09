const std = @import("std");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;
const expect = std.testing.expect;

const Solution = u64;

const max_size = math.maxInt(usize);
const stdout_buffersize = 1024;
const max_ids_per_range = 64;

// const precompute_periods = 100_000;
// const periods: [precompute_periods]?Period = blk: {
//     @setEvalBranchQuota(std.math.maxInt(u32));
//     var periods_: [precompute_periods]?Period = undefined;
//     periods_[0] = null;
//     for (1..precompute_periods) |n| {
//         periods_[n] = find_period(n);
//     }
//     break :blk periods_;
// };

fn solve(base_alloc: mem.Allocator, input_str: []u8) !Solution {
    // var arena = std.heap.ArenaAllocator.init(base_alloc);
    // defer arena.deinit();
    // const arena_alloc = arena.allocator();
    _ = base_alloc;

    var sum: Solution = 0;
    var lines = mem.tokenizeScalar(u8, input_str, ',');
    while (lines.next()) |range_str| {
        const range = try RangeInclusive.parse(range_str);
        const solution = solve_single(range);
        debugPrintLn("{}-{}\t {}", .{ range.lo, range.hi, solution });
        sum += solution;
    }
    return sum;
}

fn solve_single(range: RangeInclusive) Solution {
    return method2(range);
}

fn method1(range: RangeInclusive) Solution {
    var sum: Solution = 0;
    for (range.lo..range.hi + 1) |n| {
        if (find_period(n) != null) {
            sum += n;
        }
    }
    return sum;
}

fn method2(range: RangeInclusive) Solution {
    var sum: Solution = 0;
    const l_len = ndigits(range.lo);
    const u_len = ndigits(range.hi);
    const max_prefix_len = @divFloor(u_len, 2);
    const max_prefix = math.powi(u64, 10, max_prefix_len) catch unreachable;
    for (1..max_prefix + 1) |prefix_| {
        if (find_period(prefix_) == null) {
            const postfix_len = ndigits(prefix_);
            const max_reps = @divFloor(u_len, postfix_len);
            const l_min_reps = math.divCeil(u64, l_len, postfix_len) catch unreachable;
            const min_reps = @max(l_min_reps, 2);
            for (min_reps..max_reps + 1) |reps| {
                const id = repeat(prefix_, reps);
                if (range.lo <= id and id <= range.hi) {
                    sum += id;
                }
            }
        }
    }
    return sum;
}

const Period = struct { prefix: u64, reps: u64 };

// fn find_period_cached(n: u64) ?Period {
//     if (n < precompute_periods)
//         return periods[n];
//     return find_period(n);
// }

fn find_period(n: u64) ?Period {
    const n_len = ndigits(n);
    const max_postfix_len = @divFloor(n_len, 2);
    postfix_len: for (1..max_postfix_len + 1) |postfix_len| {
        if (n_len % postfix_len != 0)
            continue;
        const postfix_ = postfix(n, postfix_len);
        var remainder = remove_postfix(n, postfix_len);
        const reps = @divExact(n_len, postfix_len);
        for (0..reps - 1) |_| {
            const remainder_postfix = postfix(remainder, postfix_len);
            if (postfix_ != remainder_postfix)
                continue :postfix_len;
            remainder = remove_postfix(remainder, postfix_len);
        }
        return .{ .prefix = postfix_, .reps = reps };
    }
    return null;
}

fn ndigits(n: u64) u64 {
    return math.log10_int(n) + 1;
}

fn prefix(n: u64, len: u64) u64 {
    const n_len = ndigits(n);
    assert(n_len >= len);
    const shift = math.powi(u64, 10, n_len - len) catch unreachable;
    return @divFloor(n, shift);
}

fn postfix(n: u64, len: u64) u64 {
    const pow10 = math.powi(u64, 10, len) catch unreachable;
    return n % pow10;
}

fn remove_postfix(n: u64, len: u64) u64 {
    const pow10 = math.powi(u64, 10, len) catch unreachable;
    assert(10 * n >= pow10);
    return @divFloor(n, pow10);
}

fn repeat(n: u64, times: u64) u64 {
    const n_len = math.log10_int(n) + 1;
    var total: u64 = n;
    for (1..times) |i| {
        const factor = math.powi(u64, 10, i * n_len) catch unreachable;
        total += n * factor;
    }
    return total;
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

test "find_period" {
    try std.testing.expectEqualDeep(Period{ .prefix = 3, .reps = 2 }, find_period(33).?);
    try std.testing.expectEqualDeep(Period{ .prefix = 9, .reps = 2 }, find_period(99).?);
    try std.testing.expectEqualDeep(Period{ .prefix = 100, .reps = 2 }, find_period(100100).?);
    try std.testing.expectEqualDeep(Period{ .prefix = 17, .reps = 3 }, find_period(171717).?);
    try std.testing.expectEqualDeep(Period{ .prefix = 1, .reps = 3 }, find_period(111).?);

    try std.testing.expect(find_period(1) == null);
    try std.testing.expect(find_period(9) == null);
    try std.testing.expect(find_period(42) == null);
    try std.testing.expect(find_period(121) == null);
}

test "ndigits" {
    try std.testing.expectEqual(1, ndigits(1));
    try std.testing.expectEqual(1, ndigits(9));
    try std.testing.expectEqual(2, ndigits(42));
    try std.testing.expectEqual(3, ndigits(123));
    try std.testing.expectEqual(4, ndigits(1000));
}

test "postfix" {
    try std.testing.expectEqual(3, postfix(123, 1));
    try std.testing.expectEqual(23, postfix(123, 2));
    try std.testing.expectEqual(123, postfix(123, 3));
    try std.testing.expectEqual(0, postfix(1000, 2));
}

test "remove_postfix" {
    try std.testing.expectEqual(12, remove_postfix(123, 1));
    try std.testing.expectEqual(1, remove_postfix(123, 2));
    try std.testing.expectEqual(0, remove_postfix(123, 3));
    try std.testing.expectEqual(1, remove_postfix(1000, 3));
}

test "repeat" {
    try std.testing.expectEqual(33, repeat(3, 2));
    try std.testing.expectEqual(171717, repeat(17, 3));
    try std.testing.expectEqual(100100, repeat(100, 2));
}

test "Example" {
    const solution = 4174379265;
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
