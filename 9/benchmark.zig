// This file is modified from https://github.com/karlseguin/benchmark.zig
const std = @import("std");

const Timer = std.time.Timer;
const Allocator = std.mem.Allocator;

// calculate statistics from the last N samples
pub const SAMPLE_SIZE = 10_000;

// roughly how long to run the benchmark for
pub var RUN_TIME: u64 = 3 * std.time.ns_per_s;

pub const Result = struct {
    total: u64,
    iterations: u64,
    requested_bytes: usize,
    // sorted, use samples()
    _samples: [SAMPLE_SIZE]u64,

    pub fn print(self: *const Result, name: []const u8) void {
        std.debug.print("{s}\n", .{name});
        const mean_ns = self.mean();
        const per_iter_bytes = @as(f64, @floatFromInt(self.requested_bytes)) / @as(f64, @floatFromInt(self.iterations));

        const dur_mean = scaleDuration(mean_ns);
        const dur_worst = scaleDuration(@as(f64, @floatFromInt(self.worst())));
        const dur_median = scaleDuration(@as(f64, @floatFromInt(self.median())));
        const dur_std = scaleDuration(self.stdDev());

        const bytes_scaled = scaleBytes(per_iter_bytes);

        std.debug.print("  {d} iterations\t{d:.2}{s} per iteration\n", .{ self.iterations, dur_mean.v, dur_mean.unit });
        std.debug.print("  {d:.2} {s} per iteration\n", .{ bytes_scaled.v, bytes_scaled.unit });
        std.debug.print("  worst: {d:.2}{s}\tmedian: {d:.2}{s}\tstddev: {d:.2}{s}\n\n", .{ dur_worst.v, dur_worst.unit, dur_median.v, dur_median.unit, dur_std.v, dur_std.unit });
    }

    pub fn samples(self: *const Result) []const u64 {
        return self._samples[0..@min(self.iterations, SAMPLE_SIZE)];
    }

    pub fn worst(self: *const Result) u64 {
        const s = self.samples();
        return s[s.len - 1];
    }

    pub fn mean(self: *const Result) f64 {
        const s = self.samples();

        var total: u64 = 0;
        for (s) |value| {
            total += value;
        }
        return @as(f64, @floatFromInt(total)) / @as(f64, @floatFromInt(s.len));
    }

    pub fn median(self: *const Result) u64 {
        const s = self.samples();
        return s[s.len / 2];
    }

    pub fn stdDev(self: *const Result) f64 {
        const m = self.mean();
        const s = self.samples();

        var total: f64 = 0.0;
        for (s) |value| {
            const t = @as(f64, @floatFromInt(value)) - m;
            total += t * t;
        }
        const variance = total / @as(f64, @floatFromInt(s.len - 1));
        return std.math.sqrt(variance);
    }
};

pub fn run(func: TypeOfBenchmark(void)) !Result {
    return runC({}, func);
}

pub fn runC(context: anytype, func: TypeOfBenchmark(@TypeOf(context))) !Result {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .enable_memory_limit = true }){};
    const allocator = gpa.allocator();

    var total: u64 = 0;
    var iterations: usize = 0;
    var timer = try Timer.start();
    var samples = std.mem.zeroes([SAMPLE_SIZE]u64);

    while (true) {
        iterations += 1;
        timer.reset();

        if (@TypeOf(context) == void) {
            try func(allocator, &timer);
        } else {
            try func(allocator, context, &timer);
        }
        const elapsed = timer.lap();

        total += elapsed;
        samples[@mod(iterations, SAMPLE_SIZE)] = elapsed;
        if (total > RUN_TIME) break;
    }

    std.sort.heap(u64, samples[0..@min(SAMPLE_SIZE, iterations)], {}, resultLessThan);

    return .{
        .total = total,
        ._samples = samples,
        .iterations = iterations,
        .requested_bytes = gpa.total_requested_bytes,
    };
}

fn TypeOfBenchmark(comptime C: type) type {
    return switch (C) {
        void => *const fn (Allocator, *Timer) anyerror!void,
        else => *const fn (Allocator, C, *Timer) anyerror!void,
    };
}

fn resultLessThan(context: void, lhs: u64, rhs: u64) bool {
    _ = context;
    return lhs < rhs;
}

const Scaled = struct {
    v: f64,
    unit: []const u8,
};

fn scaleDuration(ns: f64) Scaled {
    // ns up to ms: ns (<1_000), µs (<1_000_000), ms otherwise
    if (ns < 1_000.0) {
        return .{ .v = ns, .unit = "ns" };
    } else if (ns < 1_000_000.0) {
        return .{ .v = ns / 1_000.0, .unit = "µs" };
    } else {
        return .{ .v = ns / 1_000_000.0, .unit = "ms" };
    }
}

fn scaleBytes(b: f64) Scaled {
    // bytes up to megabytes: B (<1024), KB (<1024*1024), MB otherwise
    if (b < 1024.0) {
        return .{ .v = b, .unit = "B" };
    } else if (b < 1024.0 * 1024.0) {
        return .{ .v = b / 1024.0, .unit = "KB" };
    } else {
        return .{ .v = b / (1024.0 * 1024.0), .unit = "MB" };
    }
}
