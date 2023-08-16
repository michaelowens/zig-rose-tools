const std = @import("std");
const Allocator = std.mem.Allocator;

pub const NodeType = enum {
    File,
    Folder,
};
pub const NodeMeta = struct {
    offset: u32,
    size: u32,
};
pub const Node = struct {
    path: [:0]const u8,
    nodeType: NodeType,
    meta: ?NodeMeta,
    children: std.ArrayList(Node),
};

pub fn addPath(allocator: std.mem.Allocator, root: *Node, path: []const u8, nodeType: NodeType, meta: ?NodeMeta) !void {
    var node: *Node = root;

    var tokens = std.mem.tokenize(u8, path, "/");
    while (tokens.next()) |token| {
        // std.log.info("add token: {s}", .{token});
        const existingChildIndex = for (node.children.items, 0..) |n, index| {
            // std.log.info("is {s} == {s}? {any}", .{ n.path, token, std.mem.eql(u8, n.path, token) });
            if (std.mem.eql(u8, n.path, token)) break index;
        } else null;

        if (existingChildIndex == null) {
            // std.log.info("adding {s} to {s}", .{ token, node.path });

            var newNode = Node{
                .path = try allocator.dupeZ(u8, token),
                .nodeType = .Folder,
                .meta = undefined,
                .children = std.ArrayList(Node).init(allocator),
            };

            const next = tokens.peek() orelse null;
            if (next == null) {
                newNode.nodeType = nodeType;
                newNode.meta = meta;
            }

            try node.children.append(newNode);
            node = &newNode;
        } else {
            // std.log.info("child exists: {s}", .{token});
            node = &node.children.items[existingChildIndex.?];
        }
    }
}
