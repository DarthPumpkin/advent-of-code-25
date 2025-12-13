const std = @import("std");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;
const expect = std.testing.expect;

const Solution = u64;
const NodeID = [3]u8;
const AdjacencyMap = std.AutoHashMap(NodeID, []const NodeID);
const CacheEntry = struct {
    node: NodeID,
    through_dac: bool,
    through_fft: bool,
};
const Cache = std.AutoHashMap(CacheEntry, Solution);

// Low-level I/O settings
const max_size = math.maxInt(usize);
const stdout_buffersize = 1024;

fn solve(base_alloc: mem.Allocator, input_str: []u8) !Solution {
    var arena = std.heap.ArenaAllocator.init(base_alloc);
    defer arena.deinit();
    const al = arena.allocator();

    var adjacency_map = AdjacencyMap.init(al);
    defer adjacency_map.deinit();
    var lines = mem.tokenizeScalar(u8, input_str, '\n');
    while (lines.next()) |line| {
        var fromto = mem.tokenizeSequence(u8, line, ": ");
        const from = fromto.next().?;
        assert(from.len == 3);
        const edges_str = fromto.next().?;
        const n_edges = (edges_str.len + 1) / 4;
        var to = try al.alloc(NodeID, n_edges);
        for (0..n_edges) |i| {
            const offset = 4 * i;
            to[i] = edges_str[offset..][0..3].*;
        }
        try adjacency_map.put(from[0..3].*, to);
    }

    var cache = Cache.init(al);
    defer cache.deinit();
    return n_paths("svr".*, true, true, &cache, adjacency_map);
}

fn n_paths(from: NodeID, through_dac: bool, through_fft: bool, cache: *Cache, all_out_edges: AdjacencyMap) !Solution {
    const cache_key: CacheEntry = .{ .node = from, .through_dac = through_dac, .through_fft = through_fft };
    const cache_val = cache.get(cache_key);
    if (cache_val != null) {
        return cache_val.?;
    }
    if (mem.eql(u8, &from, "out")) {
        if (!through_dac and !through_fft)
            return 1;
        return 0;
    }
    const children = all_out_edges.get(from) orelse &.{};
    var sum: Solution = 0;
    for (children) |child| {
        if (mem.eql(u8, &child, "dac")) {
            if (through_dac) {
                sum += try n_paths(child, false, through_fft, cache, all_out_edges);
            }
        } else if (mem.eql(u8, &child, "fft")) {
            if (through_fft)
                sum += try n_paths(child, through_dac, false, cache, all_out_edges);
        } else {
            sum += try n_paths(child, through_dac, through_fft, cache, all_out_edges);
        }
    }
    try cache.put(cache_key, sum);
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
    const solution = 2;
    const example_file_name = "example2.txt";

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
