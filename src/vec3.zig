const std = @import("std");
const utils = @import("utils.zig");

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn new(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }

    pub fn neg(v: Vec3) Vec3 {
        return Vec3{
            .x = -v.x,
            .y = -v.y,
            .z = -v.z,
        };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return Vec3{
            .x = a.x + b.x,
            .y = a.y + b.y,
            .z = a.z + b.z,
        };
    }

    pub fn add_(a: *Vec3, b: Vec3) void {
        a.x += b.x;
        a.y += b.y;
        a.z += b.z;
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return Vec3{
            .x = a.x - b.x,
            .y = a.y - b.y,
            .z = a.z - b.z,
        };
    }

    pub fn mul(a: Vec3, t: f32) Vec3 {
        return Vec3{
            .x = a.x * t,
            .y = a.y * t,
            .z = a.z * t,
        };
    }

    pub fn mulv(a: Vec3, b: Vec3) Vec3 {
        return Vec3{
            .x = a.x * b.x,
            .y = a.y * b.y,
            .z = a.z * b.z,
        };
    }

    pub fn div(a: Vec3, t: f32) Vec3 {
        return Vec3{
            .x = a.x / t,
            .y = a.y / t,
            .z = a.z / t,
        };
    }

    pub fn length_squared(v: Vec3) f32 {
        return v.dot(v);
    }

    pub fn length(v: Vec3) f32 {
        return @sqrt(v.length_squared());
    }

    pub fn unit(v: Vec3) Vec3 {
        return v.div(v.length());
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return Vec3{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn random() Vec3 {
        return Vec3{
            .x = utils.rand_float(),
            .y = utils.rand_float(),
            .z = utils.rand_float(),
        };
    }

    pub fn random_range(min: f32, max: f32) Vec3 {
        return Vec3{
            .x = utils.rand_float_range(min, max),
            .y = utils.rand_float_range(min, max),
            .z = utils.rand_float_range(min, max),
        };
    }

    pub fn at(self: Vec3, axis: u8) f32 {
        return switch(axis) {
            0 => self.x,
            1 => self.y,
            2 => self.z,
            else => unreachable
        };
    }
};

pub const Point3 = Vec3;

pub fn random_in_unit_sphere() Vec3 {
    while (true) {
        const p = Vec3.random_range(-1, 1);
        if (p.length_squared() >= 1) continue;
        return p;
    }
}

pub fn random_unit_vector() Vec3 {
    return random_in_unit_sphere().unit();
}

pub fn random_in_hemisphere(normal: Vec3) Vec3 {
    const in_unit_sphere = random_in_unit_sphere();
    if (in_unit_sphere.dot(normal) > 0) {
        return in_unit_sphere;
    } else {
        return in_unit_sphere.neg();
    }
}

pub fn random_in_unit_disk() Vec3 {
    while (true) {
        const p = Vec3.new(utils.rand_float_range(-1, 1), utils.rand_float_range(-1, 1), 0);
        if (p.length_squared() >= 1) continue;
        return p;
    }
}

pub fn reflect(v: Vec3, n: Vec3) Vec3 {
    return v.sub(n.mul(2 * v.dot(n)));
}

pub fn refract(uv: Vec3, n: Vec3, etai_over_etat: f32) Vec3 {
    const cos_theta = std.math.min(uv.neg().dot(n), 1.0);
    const r_out_perp = uv.add(n.mul(cos_theta)).mul(etai_over_etat);
    const r_out_parallel = n.mul(@sqrt(1.0 - std.math.fabs(r_out_perp.length_squared()))).neg();
    return r_out_perp.add(r_out_parallel);
}
