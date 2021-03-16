const std = @import("std");
const vec3 = @import("vec3.zig");
const clamp = @import("utils.zig").clamp;

pub const Color = vec3.Vec3;

pub fn write_color(out: *const std.fs.File.Writer, color: Color, samples_per_pixel: u32) !void {
    var r = color.x;
    var g = color.y;
    var b = color.z;

    const scale = 1.0 / @intToFloat(f32, samples_per_pixel);
    r = @sqrt(r * scale);
    g = @sqrt(g * scale);
    b = @sqrt(b * scale);

    const ir: u32 = @floatToInt(u32, 255.999 * clamp(r, 0, 0.999));
    const ig: u32 = @floatToInt(u32, 255.999 * clamp(g, 0, 0.999));
    const ib: u32 = @floatToInt(u32, 255.999 * clamp(b, 0, 0.999));
    try out.print("{} {} {}\n", .{ ir, ig, ib });
}
