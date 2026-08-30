//! Bootstrap seed for the jac build: materialize the pinned typeshed stdlib
//! stubs into the checkout.
//!
//!     fetch_typeshed <vendor-dir>
//!
//! Type inference is on the critical path of every compilation, so these stubs
//! are a build input on exactly the same footing as the pbs CPython: they must
//! be on disk before the first `.jac` file is compiled. Compiling the Jac
//! payload tool IS a compilation, so the fetch cannot live there -- the tool
//! that fetches typeshed would need typeshed to exist before it could run.
//! That is why this is Zig, next to `fetch_pbs.zig`, on the one rung of the
//! bootstrap that runs before any Python does.
//!
//! `<vendor-dir>` is `jaclang/vendor/typeshed`, which carries the pin (`PIN`, a
//! typeshed commit) and the SHA256 of that commit's tarball
//! (`TARBALL_SHA256`) -- the same two files `jaclang.dist.payload`'s own
//! `fetch-typeshed` reads, so the two fetchers can never disagree. Idempotent:
//! a no-op once `stdlib/.typeshed-sha` names the pinned commit.

const std = @import("std");

test "vendorPath keeps the stdlib stubs and the license, drops the rest" {
    const root = "typeshed-bbbf7530a987e59c8458127351cacad2e57f04bf/";
    try std.testing.expectEqualStrings("stdlib/typing.pyi", vendorPath(root ++ "stdlib/typing.pyi").?);
    try std.testing.expectEqualStrings("stdlib/asyncio/tasks.pyi", vendorPath(root ++ "stdlib/asyncio/tasks.pyi").?);
    try std.testing.expectEqualStrings("stdlib/VERSIONS", vendorPath(root ++ "stdlib/VERSIONS").?);
    try std.testing.expectEqualStrings("LICENSE", vendorPath(root ++ "LICENSE").?);

    try std.testing.expect(vendorPath(root ++ "stdlib/@tests/test_cases/check_re.py") == null);
    try std.testing.expect(vendorPath(root ++ "stdlib/asyncio/@tests/check_task.py") == null);
    try std.testing.expect(vendorPath(root ++ "stubs/six/six/__init__.pyi") == null);
    try std.testing.expect(vendorPath(root ++ "README.md") == null);
    try std.testing.expect(vendorPath(root ++ "stdlib/") == null);
    try std.testing.expect(vendorPath(root ++ "stdlib/../../escape.pyi") == null);
    try std.testing.expect(vendorPath("stdlib/typing.pyi") == null);
    try std.testing.expect(vendorPath("no-root-component") == null);
}

test "install materializes the stdlib tree with no Jac compile in the loop" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const commit = "bbbf7530a987e59c8458127351cacad2e57f04bf";
    const tar = try testTarball(gpa, commit);
    defer gpa.free(tar);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try std.testing.expect(!upToDate(io, gpa, tmp.dir, commit));
    try install(io, gpa, tmp.dir, tar, commit);
    try std.testing.expect(upToDate(io, gpa, tmp.dir, commit));

    try expectFile(io, gpa, tmp.dir, "stdlib/typing.pyi", "class Any: ...\n");
    try expectFile(io, gpa, tmp.dir, "stdlib/asyncio/tasks.pyi", "def sleep(): ...\n");
    try expectFile(io, gpa, tmp.dir, "stdlib/VERSIONS", "typing: 3.0-\n");
    try expectFile(io, gpa, tmp.dir, "LICENSE", "Apache-2.0\n");
    try expectFile(io, gpa, tmp.dir, "stdlib/.typeshed-sha", commit);

    try std.testing.expect(!exists(io, tmp.dir, "stdlib/@tests/test_cases/check_re.py"));
    try std.testing.expect(!exists(io, tmp.dir, "stubs/six/six/__init__.pyi"));
    try std.testing.expect(!exists(io, tmp.dir, "README.md"));
}

test "a re-install for another pin replaces the tree instead of merging into it" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const commit = "bbbf7530a987e59c8458127351cacad2e57f04bf";
    const tar = try testTarball(gpa, commit);
    defer gpa.free(tar);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try install(io, gpa, tmp.dir, tar, commit);
    try tmp.dir.writeFile(io, .{ .sub_path = "stdlib/dropped_upstream.pyi", .data = "stale\n" });
    try std.testing.expect(!upToDate(io, gpa, tmp.dir, "0000000000000000000000000000000000000000"));

    try install(io, gpa, tmp.dir, tar, commit);
    try std.testing.expect(!exists(io, tmp.dir, "stdlib/dropped_upstream.pyi"));
    try expectFile(io, gpa, tmp.dir, "stdlib/typing.pyi", "class Any: ...\n");
}

test "a tarball with no stdlib is rejected rather than half-installed" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const tar = try makeTar(gpa, &.{
        .{ "typeshed-deadbeef/LICENSE", "Apache-2.0\n" },
        .{ "typeshed-deadbeef/stubs/six/six/__init__.pyi", "x: int\n" },
    });
    defer gpa.free(tar);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try std.testing.expectError(error.NoStdlib, install(io, gpa, tmp.dir, tar, "deadbeef"));
    try std.testing.expect(!upToDate(io, gpa, tmp.dir, "deadbeef"));
}

fn testTarball(gpa: std.mem.Allocator, commit: []const u8) ![]u8 {
    const root = try std.fmt.allocPrint(gpa, "typeshed-{s}/", .{commit});
    defer gpa.free(root);
    var names: [7][]u8 = undefined;
    const rels = [_][]const u8{
        "LICENSE",
        "README.md",
        "stdlib/VERSIONS",
        "stdlib/typing.pyi",
        "stdlib/asyncio/tasks.pyi",
        "stdlib/@tests/test_cases/check_re.py",
        "stubs/six/six/__init__.pyi",
    };
    const bodies = [_][]const u8{
        "Apache-2.0\n",
        "not vendored\n",
        "typing: 3.0-\n",
        "class Any: ...\n",
        "def sleep(): ...\n",
        "assert False\n",
        "x: int\n",
    };
    var rows: [rels.len][2][]const u8 = undefined;
    var made: usize = 0;
    errdefer for (names[0..made]) |n| gpa.free(n);
    for (rels, 0..) |rel, i| {
        names[i] = try std.fmt.allocPrint(gpa, "{s}{s}", .{ root, rel });
        made += 1;
        rows[i] = .{ names[i], bodies[i] };
    }
    defer for (names[0..made]) |n| gpa.free(n);
    return makeTar(gpa, &rows);
}

fn makeTar(gpa: std.mem.Allocator, rows: []const [2][]const u8) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(gpa);
    errdefer aw.deinit();
    var tw: std.tar.Writer = .{ .underlying_writer = &aw.writer };
    for (rows) |row| try tw.writeFileBytes(row[0], row[1], .{ .mode = 0o644, .mtime = 0 });
    var list = aw.toArrayList();
    return list.toOwnedSlice(gpa);
}

fn exists(io: std.Io, dir: std.Io.Dir, sub_path: []const u8) bool {
    const f = dir.openFile(io, sub_path, .{}) catch return false;
    f.close(io);
    return true;
}

fn expectFile(
    io: std.Io,
    gpa: std.mem.Allocator,
    dir: std.Io.Dir,
    sub_path: []const u8,
    want: []const u8,
) !void {
    const got = try dir.readFileAlloc(io, sub_path, gpa, .limited(4096));
    defer gpa.free(got);
    try std.testing.expectEqualStrings(want, got);
}
