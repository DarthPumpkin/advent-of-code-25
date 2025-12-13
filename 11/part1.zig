const std = @import("std");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;
const expect = std.testing.expect;

const Solution = u64;
const NodeID = [3]u8;
const AdjacencyMap = std.AutoArrayHashMap(NodeID, []const NodeID);

const max_size = math.maxInt(usize);
const stdout_buffersize = 1024;

fn solve(base_alloc: mem.Allocator, input_str: []u8) !Solution {
    var arena = std.heap.ArenaAllocator.init(base_alloc);
    defer arena.deinit();
    const al = arena.allocator();

    // var all_nodes = std.ArrayList(NodeID).initCapacity(al, input_str.len / 16);
    var all_out_edges = AdjacencyMap.init(al);
    var lines = std.mem.tokenizeScalar(u8, input_str, '\n');
    while (lines.next()) |line| {
        var fromto = std.mem.tokenizeSequence(u8, line, ": ");
        const from_slice = fromto.next().?;
        assert(from_slice.len == 3);
        const from = from_slice[0..3];
        const to_str = fromto.next().?;
        const n_edges = (to_str.len + 1) / 4;
        var to = try al.alloc(NodeID, n_edges);
        // var edges = std.mem.tokenizeScalar(u8, to_str, ' ');
        for (0..n_edges) |i| {
            const offset = 4 * i;
            // @memcpy(&to[i], to_str[offset..][0..3]);
            to[i] = to_str[offset..][0..3].*;
        }
        try all_out_edges.put(from.*, to);
    }

    return n_paths("you".*, &all_out_edges);
}

fn n_paths(from: NodeID, all_out_edges: *const AdjacencyMap) Solution {
    if (mem.eql(u8, &from, "out")) {
        return 1;
    }
    const children = all_out_edges.get(from) orelse &.{};
    var sum: Solution = 0;
    for (children) |child| {
        sum += n_paths(child, all_out_edges);
    }
    return sum;
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

test "Example" {
    const solution = 5;
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
