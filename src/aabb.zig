const std = @import("std");

const objects = @import("objects.zig");
const Hittable = objects.Hittable;
const HitRecord = objects.HitRecord;

const vec3 = @import("vec3.zig");
const Point3 = vec3.Point3;

const ray = @import("ray.zig");
const Ray = ray.Ray;

pub const AABB = struct {
    const Self = @This();

    minimum: Point3,
    maximum: Point3,

    pub fn hit(self: *Self, r: Ray, t_min: f32, t_max: f32) bool {
        const fields = @typeInfo(Point3).Struct.fields;
        inline for (fields) |f| {
            const xmin = @field(self.minimum, f.name);
            const xmax = @field(self.maximum, f.name);
            const ax = @field(r.orig, f.name);
            const bx = @field(r.dir, f.name);

            var t0 = std.math.min((xmin - ax) / bx, (xmax - ax) / bx);
            var t1 = std.math.max((xmin - ax) / bx, (xmax - ax) / bx);

            t0 = std.math.max(t0, t_min);
            t1 = std.math.min(t1, t_max);

            if (t1 <= t0)
                return false;
        }

        return true;
    }
};
