const std = @import("std");
const Allocator = std.mem.Allocator;

const vec3 = @import("vec3.zig");
const Point3 = vec3.Point3;
const Vec3 = vec3.Vec3;

const color = @import("color.zig");
const Color = color.Color;

const material = @import("material.zig");
const Material = material.Material;

const ray = @import("ray.zig");
const Ray = ray.Ray;

const aabb = @import("aabb.zig");
const AABB = aabb.AABB;

const utils = @import("utils.zig");

pub const Hittable = struct {
    hitFn: fn (self: *Hittable, r: Ray, t_min: f32, t_max: f32) ?HitRecord,
    _bounding_box: fn (self: *Hittable, time0: f32, time1: f32) ?AABB,
    pub fn hit(self: *Hittable, r: Ray, t_min: f32, t_max: f32) ?HitRecord {
        return self.hitFn(self, r, t_min, t_max);
    }
    pub fn bounding_box(self: *Hittable, time0: f32, time1: f32) ?AABB {
        return self._bounding_box(self, time0, time1);
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
            .hittable = Hittable{ .hitFn = hit, ._bounding_box = bounding_box },
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

    pub fn bounding_box(hittable: *Hittable, time0: f32, time1: f32) ?AABB {
        const self = @fieldParentPtr(Sphere, "hittable", hittable);

        return sphere_bounding_box(self.center, self.radius);
    }
};

fn sphere_bounding_box(center: Point3, radius: f32) AABB {
    return AABB{
        .minimum = center.sub(Vec3.new(radius, radius, radius)),
        .maximum = center.add(Vec3.new(radius, radius, radius)),
    };
}

pub const MovingSphere = struct {
    const Self = @This();

    hittable: Hittable,
    material: *Material,
    center0: Point3,
    center1: Point3,
    time0: f32,
    time1: f32,
    radius: f32,

    pub fn init(
        center0: Point3,
        center1: Point3,
        time0: f32,
        time1: f32,
        radius: f32,
        mat: *Material,
    ) Self {
        return Self{
            .hittable = Hittable{ .hitFn = hit, ._bounding_box = bounding_box },
            .material = mat,
            .center0 = center0,
            .center1 = center1,
            .time0 = time0,
            .time1 = time1,
            .radius = radius,
        };
    }

    fn center(self: *Self, t: f32) Point3 {
        const time_factor = (t - self.time0) / (self.time1 - self.time0);
        return self.center0.add(self.center1.sub(self.center0).mul(time_factor));
    }

    pub fn hit(hittable: *Hittable, r: Ray, t_min: f32, t_max: f32) ?HitRecord {
        const self = @fieldParentPtr(Self, "hittable", hittable);
        const oc = r.orig.sub(self.center(r.time));
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
        const outward_normal = (p.sub(self.center(r.time))).div(self.radius);
        const front_face = r.dir.dot(outward_normal) < 0;
        var rec: HitRecord = undefined;
        rec.t = root;
        rec.p = p;
        rec.normal = if (front_face) outward_normal else outward_normal.neg();
        rec.front_face = front_face;
        rec.material = self.material;
        return rec;
    }

    pub fn bounding_box(hittable: *Hittable, time0: f32, time1: f32) ?AABB {
        const self = @fieldParentPtr(Self, "hittable", hittable);

        const aabb0 = sphere_bounding_box(self.center(time0), self.radius);
        const aabb1 = sphere_bounding_box(self.center(time1), self.radius);
        return surrounding_box(aabb0, aabb1);
    }
};

fn surrounding_box(aabb0: AABB, aabb1: AABB) AABB {
    const bl = Point3{
        .x = std.math.min(aabb0.minimum.x, aabb1.minimum.x),
        .y = std.math.min(aabb0.minimum.y, aabb1.minimum.y),
        .z = std.math.min(aabb0.minimum.z, aabb1.minimum.z),
    };

    const tr = Point3{
        .x = std.math.max(aabb0.maximum.x, aabb1.maximum.x),
        .y = std.math.max(aabb0.maximum.y, aabb1.maximum.y),
        .z = std.math.max(aabb0.maximum.z, aabb1.maximum.z),
    };

    return AABB{ .minimum = bl, .maximum = tr };
}

pub const HittableList = struct {
    const Self = @This();

    hittable: Hittable,
    objects: std.ArrayList(*Hittable),

    pub fn init(allocator: *Allocator) Self {
        return Self{
            .hittable = Hittable{ .hitFn = hit, ._bounding_box = bounding_box },
            .objects = std.ArrayList(*Hittable).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.objects.deinit();
    }

    pub fn len(self: *Self) usize {
        return self.objects.items.len;
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

    pub fn add(self: *Self, hittable: *Hittable) !void {
        try self.objects.append(hittable);
    }

    pub fn bounding_box(hittable: *Hittable, time0: f32, time1: f32) ?AABB {
        const self = @fieldParentPtr(Self, "hittable", hittable);

        // if (self.objects.items.len == 0) return null;

        var output_box: ?AABB = null;
        for (self.objects.items) |item| {
            const box = item.bounding_box(time0, time1);
            if (box == null) return null;
            output_box = if (output_box == null) output_box else surrounding_box(output_box.?, box.?);
        }

        return output_box;
    }
};

fn choose_random_axis() []const u8 {
    const r = utils.rand_float();
    if (r < 0.33) {
        return "x";
    } else if (r < 0.67) {
        return "y";
    } else {
        return "z";
    }
}

fn box_compare(a: *Hittable, b: *Hittable, axis: u8) bool {
    const box_a = a.bounding_box(0, 0);
    const box_b = b.bounding_box(0, 0);

    // if (box_a == null or box_b == null) {}
    // print error

    return box_a.?.minimum.at(axis) < box_b.?.minimum.at(axis);
}

fn box_compare_axis(axis: u8, a: *Hittable, b: *Hittable) bool {
    return box_compare(a, b, axis);
}

pub const BVHNode = struct {
    const Self = @This();

    hittable: Hittable,
    left: *Hittable,
    right: *Hittable,
    box: AABB,

    pub fn init(allocator: *Allocator, list: HittableList, time0: f32, time1: f32) !Self {
        return try Self.build(allocator, list.objects.items, time0, time1);
    }

    pub fn build(allocator: *Allocator, src_objects: []*Hittable, time0: f32, time1: f32) Allocator.Error!Self {
        const axis = @intCast(u8, utils.rand_int(0, 2));
        const compare = box_compare_axis;

        const start: usize = 0;
        const end: usize = src_objects.len;

        const object_span = end - start;

        // copy objects into mutable array (for sorting)
        var objects: []*Hittable = try allocator.alloc(*Hittable, object_span);
        std.mem.copy(*Hittable, objects, src_objects);

        var left: *Hittable = undefined;
        var right: *Hittable = undefined;
        if (object_span == 1) {
            left = objects[start];
            right = objects[start];
        } else if (object_span == 2) {
            if (compare(axis, objects[start], objects[start + 1])) {
                left = objects[start];
                right = objects[start + 1];
            } else {
                left = objects[start + 1];
                right = objects[start];
            }
        } else {
            std.sort.sort(*Hittable, objects, axis, compare);
            const mid = start + object_span / 2;
            const left_bvh = try allocator.create(Self);
            left_bvh.* = try Self.build(allocator, objects[start..mid], time0, time1);
            left = &left_bvh.hittable;
            const right_bvh = try allocator.create(Self);
            right_bvh.* = try Self.build(allocator, objects[mid..end], time0, time1);
            right = &right_bvh.hittable;
        }

        const box_left = left.bounding_box(time0, time1);
        const box_right = right.bounding_box(time0, time1);
        if (box_left == null or box_right == null) {
            // print error
        }

        return Self{
            .hittable = Hittable{ .hitFn = hit, ._bounding_box = bounding_box },
            .left = left,
            .right = right,
            .box = surrounding_box(box_left.?, box_right.?),
        };
    }

    pub fn hit(hittable: *Hittable, r: Ray, t_min: f32, t_max: f32) ?HitRecord {
        const self = @fieldParentPtr(Self, "hittable", hittable);

        if (!self.box.hit(r, t_min, t_max)) return null;

        const hit_left = self.left.hit(r, t_min, t_max);
        const new_t_max = if (hit_left == null) t_max else hit_left.?.t;
        const hit_right = self.right.hit(r, t_min, new_t_max);

        if (hit_left) |left| {
            if (hit_right) |right| {
                if (left.t < right.t) {
                    return hit_left;
                } else {
                    return hit_right;
                }
            } else {
                return hit_left;
            }
        } else {
            return hit_right;
        }
    }

    pub fn bounding_box(hittable: *Hittable, time0: f32, time1: f32) ?AABB {
        const self = @fieldParentPtr(Self, "hittable", hittable);
        return self.box;
    }
};
