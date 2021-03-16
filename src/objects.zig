const std = @import("std");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const color = @import("color.zig");
const material = @import("material.zig");
const Point3 = vec3.Point3;
const Vec3 = vec3.Vec3;
const Ray = ray.Ray;
const Color = color.Color;
const Material = material.Material;
const Allocator = std.mem.Allocator;

pub const Hittable = struct {
    hitFn: fn (self: *Hittable, r: Ray, t_min: f32, t_max: f32) ?HitRecord,
    pub fn hit(self: *Hittable, r: Ray, t_min: f32, t_max: f32) ?HitRecord {
        return self.hitFn(self, r, t_min, t_max);
    }
};

pub const HitRecord = struct {
    p: Point3,
    normal: Vec3,
    t: f32,
    front_face: bool,
    material: *Material,

    pub fn new(r: Ray, outward_normal: Vec3, root: f32) HitRecord {
        const p = r.at(root);
        const front_face = r.dir.dot(outward_normal) < 0;
        return HitRecord{
            .p = p,
            .normal = if (front_face) outward_normal else outward_normal.neg(),
            .t = root,
            .front_face = front_face,
        };
    }
};

pub const Sphere = struct {
    hittable: Hittable,
    material: *Material,
    center: Point3,
    radius: f32,

    pub fn init(center: Point3, radius: f32, mat: *Material) Sphere {
        return Sphere{
            .hittable = Hittable{ .hitFn = hit },
            .material = mat,
            .center = center,
            .radius = radius,
        };
    }

    pub fn hit(hittable: *Hittable, r: Ray, t_min: f32, t_max: f32) ?HitRecord {
        const self = @fieldParentPtr(Sphere, "hittable", hittable);
        const oc = r.orig.sub(self.center);
        const a = r.dir.length_squared();
        const half_b = oc.dot(r.dir);
        const c = oc.length_squared() - self.radius * self.radius;
        const discriminant = half_b * half_b - a * c;
        if (discriminant < 0) {
            return null;
        }
        const sqrtd = @sqrt(discriminant);

        var root = (-half_b - sqrtd) / a;
        if (root < t_min or root > t_max) {
            // try other solution
            root = (-half_b + sqrtd) / a;
            if (root < t_min or root > t_max) {
                return null;
            }
        }

        const p = r.at(root);
        const outward_normal = (p.sub(self.center)).div(self.radius);
        const front_face = r.dir.dot(outward_normal) < 0;
        var rec: HitRecord = undefined;
        rec.t = root;
        rec.p = p;
        rec.normal = if (front_face) outward_normal else outward_normal.neg();
        rec.front_face = front_face;
        rec.material = self.material;
        return rec;
    }
};

    const test_allocator = std.testing.allocator;

pub const HittableList = struct {
    const Self = @This();

    hittable: Hittable,
    objects: std.ArrayList(*Hittable),

    pub fn init(allocator: *Allocator) HittableList {
        return HittableList{
            .hittable = Hittable{ .hitFn = hit },
            .objects = std.ArrayList(*Hittable).init(allocator),
        };
    }

    pub fn deinit(self: *HittableList) void {
        self.objects.deinit();
    }

    pub fn hit(hittable: *Hittable, r: Ray, t_min: f32, t_max: f32) ?HitRecord {
        const self = @fieldParentPtr(Self, "hittable", hittable);
        var closest: ?HitRecord = null;
        var min_distance: f32 = t_max;

        for (self.objects.items) |object| {
            if (object.hit(r, t_min, min_distance)) |record| {
                closest = record;
                min_distance = record.t;
            }
        }

        return closest;
    }

    pub fn add(self: *HittableList, hittable: *Hittable) !void {
        try self.objects.append(hittable);
    }
};
