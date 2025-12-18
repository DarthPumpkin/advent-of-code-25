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
    // _ = input_str;

    var lines = mem.tokenizeScalar(u8, input_str, '\n');
    var sum: Solution = 0;
    while (lines.next()) |line| {
        const machine = try Machine.parse(al, line);
        const initial_state = try al.alloc(bool, machine.indicators.len);
        defer al.free(initial_state);
        sum += (try least_presses(al, initial_state, machine)).?;
    }
    return sum;
}

fn least_presses(al: mem.Allocator, state: []const bool, machine: Machine) !?Solution {
    const buttons = machine.buttons;
    // Terminating condition
    if (buttons.len == 0) {
        return if (mem.eql(bool, state, machine.indicators)) 0 else null;
    }
    const pressed_button = buttons[buttons.len - 1];
    var pressed_state = try al.alloc(bool, state.len);
    defer al.free(pressed_state);
    assert(pressed_button.len == state.len);
    for (pressed_button, state, 0..) |b, s, i| {
        pressed_state[i] = (b != s);
    }
    var sub_machine = machine;
    sub_machine.buttons = buttons[0 .. buttons.len - 1];
    var result_press = try least_presses(al, pressed_state, sub_machine);
    const result_nopress = try least_presses(al, state, sub_machine);
    if (result_press) |_| {
        result_press.? += 1;
    }
    const result = @min(
        result_nopress orelse math.maxInt(Solution),
        result_press orelse math.maxInt(Solution),
    );
    return if (result < math.maxInt(Solution)) result else null;
}

const Machine = struct {
    indicators: []bool,
    buttons: [][]bool,

    pub fn parse(al: mem.Allocator, str: []const u8) !@This() {
        var parts = mem.tokenizeScalar(u8, str, ' ');
        const ind_str = parts.next().?;
        var indicators = try al.alloc(bool, ind_str.len - 2);
        for (ind_str[1 .. ind_str.len - 1], 0..) |c, i| {
            if (c == '#') {
                indicators[i] = true;
            } else if (c == '.') {
                indicators[i] = false;
            } else unreachable;
        }
        var buttons = try std.ArrayList([]bool).initCapacity(al, 13);
        while (parts.next()) |part| {
            if (part[0] == '{') {
                break;
            }
            var button = try al.alloc(bool, indicators.len);
            var indices = mem.tokenizeScalar(u8, part[1 .. part.len - 1], ',');
            for (0..button.len) |i| {
                button[i] = false;
            }
            while (indices.next()) |i_str| {
                const i = try std.fmt.parseInt(usize, i_str, 10);
                button[i] = true;
            }
            try buttons.append(al, button);
        }
        return .{
            .indicators = indicators,
            .buttons = buttons.items,
        };
    }

    pub fn deinit(self: @This(), al: mem.Allocator) !void {
        al.free(self.indicators);
        for (self.buttons) |button| {
            al.free(button);
        }
        al.free(self.buttons);
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
    const solution = 7;
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
