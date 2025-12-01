const std = @import("std");
const expect = std.testing.expect;

const Solution = u64;

const max_size = std.math.maxInt(usize);
const stdout_buffersize = 1024;

fn solve(base_alloc: std.mem.Allocator, input_str: []u8) !Solution {
    // var arena = std.heap.ArenaAllocator.init(base_alloc);
    // defer arena.deinit();
    // const arena_alloc = arena.allocator();
    _ = base_alloc;

    var n_zeros: Solution = 0;
    var pos: i16 = 50;
    var lines = std.mem.tokenizeScalar(u8, input_str, '\n');
    while (lines.next()) |line| {
        const instruction = try Instruction.parse(line);
        pos += instruction.to_i16();
        pos = @mod(pos, 100);
        // debugPrintLn("{}", .{pos});
        if (pos == 0)
            n_zeros += 1;
    }
    return n_zeros;
}

const Instruction = struct {
    dir: Direction,
    val: u16,

    pub fn to_i16(self: @This()) i16 {
        var signed: i16 = @intCast(self.val);
        if (self.dir == .L) {
            signed *= -1;
        }
        return signed;
    }

    pub fn parse(str: []const u8) !@This() {
        const dir: Direction = switch (str[0]) {
            'L' => .L,
            'R' => .R,
            else => unreachable,
        };
        const val: u16 = try std.fmt.parseUnsigned(u16, str[1..], 10);
        return .{
            .dir = dir,
            .val = val,
        };
    }
};

const Direction = enum { L, R };

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
    const solution = 3;
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
