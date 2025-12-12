const std = @import("std");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;
const expect = std.testing.expect;

const Solution = u64;

const max_size = math.maxInt(usize);
const stdout_buffersize = 1024;
const max_ids_per_range = 64;

fn solve(n_boxes: comptime_int, input_str: []u8) !Solution {
    // var arena = std.heap.ArenaAllocator.init(base_alloc);
    // defer arena.deinit();
    // const arena_alloc = arena.allocator();

    var positions: [n_boxes]Position = undefined;
    var lines = mem.tokenizeScalar(u8, input_str, '\n');
    for (0..n_boxes) |i| {
        const line = lines.next().?;
        const pos = try Position.parse(line);
        positions[i] = pos;
    }

    const Matrix = StrictlyLowerTriangularMatrix(n_boxes);
    var sqdists = Matrix.init();
    for (1..n_boxes) |row| {
        for (0..row) |col| {
            const entry = sqdists.at(row, col);
            entry.* = sqdist(positions[row], positions[col]);
        }
    }
    var shortest_connections: [Matrix.numel]usize = undefined;
    for (0..Matrix.numel) |i| {
        shortest_connections[i] = i;
    }
    const lt = struct {
        fn lt(context: []const u64, i: usize, j: usize) bool {
            return context[i] < context[j];
        }
    }.lt;
    const context: []const u64 = &sqdists.data;
    mem.sortUnstable(usize, &shortest_connections, context, lt);

    var circuits: [n_boxes]usize = undefined;
    for (0..n_boxes) |i| {
        circuits[i] = i;
    }
    for (shortest_connections) |conn| {
        const boxes = Matrix.unlinearize(conn);
        const row_circuit = circuits[boxes.row];
        const col_circuit = circuits[boxes.col];
        if (row_circuit != col_circuit) {
            for (&circuits) |*c| {
                if (c.* == row_circuit) {
                    c.* = col_circuit;
                }
            }
            // Termination condition
            if (mem.allEqual(usize, &circuits, circuits[0])) {
                const x_row = positions[boxes.row].x;
                const x_col = positions[boxes.col].x;
                return x_row * x_col;
            }
        }
    }
    @panic("Did not terminate");
}

fn sqdist(p: Position, q: Position) u64 {
    return (sqdiff(p.x, q.x) +
        sqdiff(p.y, q.y) +
        sqdiff(p.z, q.z));
}

fn sqdiff(n: u64, m: u64) u64 {
    return (n * n + m * m) - (2 * n * m);
}

/// Return the indices of the `n` smallest items in a slice, where `n` is comptime.
/// The indices are in no particular order.
/// Does not use heap allocation.
fn argmin_n(comptime n: usize, slice: []const u64) [n]usize {
    assert(slice.len >= n);
    // Approach: maintain a max-heap of the n smallest items
    var membuf: [@sizeOf([n]usize)]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&membuf);
    const al = fba.allocator();
    const MaxHeap = std.PriorityQueue(usize, []const u64, greaterThan);
    var queue = MaxHeap.init(al, slice);
    queue.ensureTotalCapacityPrecise(n) catch unreachable("FBA cannot fail");
    for (0..n) |i| {
        queue.add(i) catch unreachable("FBA cannot fail");
    }
    for (n..slice.len) |i| {
        if (slice[queue.peek().?] > slice[i]) {
            _ = queue.remove();
            queue.add(i) catch unreachable;
        }
    }
    return @bitCast(membuf);
}

fn greaterThan(slice: []const u64, i: usize, j: usize) math.Order {
    return math.order(slice[j], slice[i]);
}

fn StrictlyLowerTriangularMatrix(n: comptime_int) type {
    assert(n >= 2);
    const numel_ = (n * (n - 1)) / 2;

    return struct {
        const numel = numel_;
        data: [numel]u64,

        pub fn init() @This() {
            return .{ .data = undefined };
        }

        pub fn at(self: *@This(), row: usize, col: usize) *u64 {
            assert(row >= 1);
            assert(row > col);
            assert(row < n);
            const idx = (row * (row - 1)) / 2 + col;
            return &self.data[idx];
        }

        pub fn unlinearize(linear: usize) struct { row: usize, col: usize } {
            assert(linear < numel);
            const row = (math.sqrt(8 * linear + 1) + 1) / 2;
            const row_offset = (row * (row - 1)) / 2;
            const col = linear - row_offset;
            return .{ .row = row, .col = col };
        }
    };
}

const Position = struct {
    x: u64,
    y: u64,
    z: u64,

    pub fn parse(str: []const u8) !@This() {
        var parts = mem.tokenizeScalar(u8, str, ',');
        const x = try std.fmt.parseInt(u64, parts.next().?, 10);
        const y = try std.fmt.parseInt(u64, parts.next().?, 10);
        const z = try std.fmt.parseInt(u64, parts.next().?, 10);
        assert(parts.peek() == null);
        return .{ .x = x, .y = y, .z = z };
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

    const n_positions = 1000;
    const solution = try solve(n_positions, fileContent);
    try printLn("Input answer: {d}", .{solution});
}

test "argmin_n" {
    const arr = [_]u64{ 10, 5, 7, 3, 8, 11, 1 };
    const slice = arr[0..];

    var indices = argmin_n(3, slice);
    mem.sortUnstable(usize, &indices, {}, _lessThan);
    const expected_indices = [_]usize{ 1, 3, 6 };

    try std.testing.expectEqualDeep(expected_indices, indices);
}

fn _lessThan(_: void, a: usize, b: usize) bool {
    return a < b;
}

test "unlinearize odd" {
    const n = 5;
    const Mat55 = StrictlyLowerTriangularMatrix(n);

    const T = @TypeOf(Mat55.unlinearize(0));
    try std.testing.expectEqualDeep(T{ .row = 1, .col = 0 }, Mat55.unlinearize(0));
    try std.testing.expectEqualDeep(T{ .row = 2, .col = 0 }, Mat55.unlinearize(1));
    try std.testing.expectEqualDeep(T{ .row = 2, .col = 1 }, Mat55.unlinearize(2));
    try std.testing.expectEqualDeep(T{ .row = 4, .col = 3 }, Mat55.unlinearize(9));
}

test "unlinearize even" {
    const n = 6;
    const Mat66 = StrictlyLowerTriangularMatrix(n);

    const T = @TypeOf(Mat66.unlinearize(0));
    try std.testing.expectEqualDeep(T{ .row = 1, .col = 0 }, Mat66.unlinearize(0));
    try std.testing.expectEqualDeep(T{ .row = 2, .col = 0 }, Mat66.unlinearize(1));
    try std.testing.expectEqualDeep(T{ .row = 2, .col = 1 }, Mat66.unlinearize(2));
    try std.testing.expectEqualDeep(T{ .row = 4, .col = 3 }, Mat66.unlinearize(9));
    try std.testing.expectEqualDeep(T{ .row = 5, .col = 4 }, Mat66.unlinearize(14));
}

test "Example" {
    const solution = 25272;
    const example_file_name = "example.txt";

    const n_positions = 20;

    const alloc = std.testing.allocator;
    const fileContent = try std.fs.cwd().readFileAlloc(alloc, example_file_name, max_size);
    defer alloc.free(fileContent);

    const sum = try solve(n_positions, fileContent);
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

    const n_positions = 1000;
    _ = try solve(n_positions, fileContent);
}
