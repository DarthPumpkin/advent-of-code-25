const std = @import("std");
const benchmark = @import("benchmark.zig");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;
const expect = std.testing.expect;

const Solution = u64;
const Bounds = struct {
    yes: u64,
    no: u64,
    maybe: u64,
};

// Low-level I/O settings
const max_size = math.maxInt(usize);
const stdout_buffersize = 1024;

fn solve(base_alloc: mem.Allocator, input_str: []const u8) !Solution {
    const bounds = try solve_bounds(base_alloc, input_str);
    return bounds.yes;
}

fn solve_bounds(base_alloc: mem.Allocator, input_str: []const u8) !Bounds {
    var arena = std.heap.ArenaAllocator.init(base_alloc);
    defer arena.deinit();
    const al = arena.allocator();
    // _ = base_alloc;

    const split_idx = mem.lastIndexOf(u8, input_str, "\n\n").?;

    var present_areas = try std.ArrayList(u64).initCapacity(al, 5);
    var present_strs = mem.tokenizeSequence(u8, input_str[0..split_idx], "\n\n");
    while (present_strs.next()) |present_str| {
        const present_area = mem.count(u8, present_str, "#");
        try present_areas.append(al, present_area);
    }

    var yes: u64 = 0;
    var no: u64 = 0;
    var maybe: u64 = 0;
    var case_strs = mem.tokenizeScalar(u8, input_str[split_idx..], '\n');
    while (case_strs.next()) |case_str| {
        var sides = mem.tokenizeSequence(u8, case_str, ": ");
        const lhs = sides.next().?;
        const rhs = sides.next().?;
        assert(sides.peek() == null);
        var dims = mem.tokenizeScalar(u8, lhs, 'x');
        const w_str = dims.next().?;
        const h_str = dims.next().?;
        assert(dims.peek() == null);
        const w = try std.fmt.parseInt(u64, w_str, 10);
        const h = try std.fmt.parseInt(u64, h_str, 10);
        const region_area = w * h;
        var counts = mem.tokenizeScalar(u8, rhs, ' ');
        var lb: u64 = 0;
        var ub: u64 = 0;
        var i: usize = 0;
        while (counts.next()) |count_str| {
            defer i += 1;
            const count = try std.fmt.parseInt(u64, count_str, 10);
            lb += count * present_areas.items[i];
            ub += count * 9;
        }
        if (region_area < lb) {
            no += 1;
        } else if (region_area <= ub) {
            maybe += 1;
        } else {
            yes += 1;
        }
    }
    return .{ .yes = yes, .no = no, .maybe = maybe };
}

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

    const bounds = try solve_bounds(alloc, fileContent);
    try printLn("[{}, {}]", .{ bounds.yes, bounds.yes + bounds.maybe });
}

test "Example" {
    const solution = 2;
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
