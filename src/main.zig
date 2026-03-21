const std = @import("std");
const config = @import("bridge/config.zig");
const server = @import("server/router.zig");
const Bridge = @import("bridge/bridge.zig").Bridge;
const launcher = @import("chrome/launcher.zig");

pub fn main() !void {
    var gpa_impl: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    var cfg = config.load();

    std.log.info("kuri v0.1.0", .{});
    std.log.info("listening on {s}:{d}", .{ cfg.host, cfg.port });

    // Chrome lifecycle management
    var chrome = launcher.Launcher.init(gpa, cfg);
    defer chrome.deinit();

    if (cfg.cdp_url) |url| {
        std.log.info("connecting to existing Chrome at {s}", .{url});
    } else {
        std.log.info("launching managed Chrome instance", .{});
    }

    const cdp_port = chrome.start(cfg) catch |err| blk: {
        std.log.warn("Chrome launch failed: {s}, continuing without Chrome", .{@errorName(err)});
        break :blk @as(u16, 9222);
    };
    ensureRuntimeCdpUrl(gpa, &cfg, cdp_port) catch |err| {
        std.log.warn("failed to derive runtime CDP URL: {s}", .{@errorName(err)});
    };
    std.log.info("CDP port: {d}", .{cdp_port});

    // Initialize bridge (central state)
    var bridge = Bridge.init(gpa);
    defer bridge.deinit();

    // Start HTTP server
    try server.run(gpa, &bridge, cfg);
}

fn ensureRuntimeCdpUrl(allocator: std.mem.Allocator, cfg: *config.Config, cdp_port: u16) !void {
    if (cfg.cdp_url != null) return;
    cfg.cdp_url = try std.fmt.allocPrint(allocator, "ws://127.0.0.1:{d}", .{cdp_port});
}

test "ensureRuntimeCdpUrl backfills managed CDP URL" {
    var cfg = config.Config{
        .host = "127.0.0.1",
        .port = 8080,
        .cdp_url = null,
        .auth_secret = null,
        .state_dir = ".browdie",
        .stale_tab_interval_s = 30,
        .request_timeout_ms = 30_000,
        .navigate_timeout_ms = 30_000,
        .extensions = null,
        .headless = true,
    };
    try ensureRuntimeCdpUrl(std.testing.allocator, &cfg, 9333);
    defer std.testing.allocator.free(cfg.cdp_url.?);
    try std.testing.expectEqualStrings("ws://127.0.0.1:9333", cfg.cdp_url.?);
}

test "ensureRuntimeCdpUrl preserves explicit CDP URL" {
    var cfg = config.Config{
        .host = "127.0.0.1",
        .port = 8080,
        .cdp_url = "ws://127.0.0.1:9223",
        .auth_secret = null,
        .state_dir = ".browdie",
        .stale_tab_interval_s = 30,
        .request_timeout_ms = 30_000,
        .navigate_timeout_ms = 30_000,
        .extensions = null,
        .headless = true,
    };
    try ensureRuntimeCdpUrl(std.testing.allocator, &cfg, 9333);
    try std.testing.expectEqualStrings("ws://127.0.0.1:9223", cfg.cdp_url.?);
}

test {
    _ = @import("bridge/config.zig");
    _ = @import("bridge/bridge.zig");
    _ = @import("server/router.zig");
    _ = @import("server/response.zig");
    _ = @import("server/middleware.zig");
    _ = @import("cdp/protocol.zig");
    _ = @import("cdp/client.zig");
    _ = @import("cdp/websocket.zig");
    _ = @import("cdp/actions.zig");
    _ = @import("cdp/stealth.zig");
    _ = @import("cdp/har.zig");
    _ = @import("snapshot/a11y.zig");
    _ = @import("snapshot/diff.zig");
    _ = @import("snapshot/ref_cache.zig");
    _ = @import("crawler/validator.zig");
    _ = @import("crawler/markdown.zig");
    _ = @import("crawler/fetcher.zig");
    _ = @import("crawler/pipeline.zig");
    _ = @import("crawler/extractor.zig");
    _ = @import("util/json.zig");
    _ = @import("test/harness.zig");
    _ = @import("chrome/launcher.zig");
    _ = @import("test/integration.zig");
    _ = @import("storage/local.zig");
    _ = @import("util/tls.zig");
}
