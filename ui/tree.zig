const std = @import("std");
const mem = std.mem;

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

/// Add a path to a tree, creating parent nodes if they don't already exist
pub fn addPath(allocator: mem.Allocator, root: *Node, path: []const u8, nodeType: NodeType, meta: ?NodeMeta) !void {
    var node: *Node = root;

    var tokens = mem.tokenize(u8, path, "/");
    while (tokens.next()) |token| {
        const existingChildIndex = for (node.children.items, 0..) |n, index| {
            if (mem.eql(u8, n.path, token)) break index;
        } else null;

        if (existingChildIndex == null) {
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
            node = &node.children.items[node.children.items.len - 1];
        } else {
            node = &node.children.items[existingChildIndex.?];
        }
    }
}
