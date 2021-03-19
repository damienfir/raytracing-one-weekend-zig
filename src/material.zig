const std = @import("std");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const Color = @import("color.zig").Color;
const Ray = ray.Ray;

const objects = @import("objects.zig");
const HitRecord = objects.HitRecord;
const utils = @import("utils.zig");

const texture = @import("texture.zig");
const Texture = texture.Texture;
const SolidColor = texture.SolidColor;
const Allocator = std.mem.Allocator;

pub const Material = struct {
    scatterFn: fn (self: *Material, r: Ray, hit: HitRecord) ?MaterialRecord,
    pub fn scatter(self: *Material, r: Ray, hit: HitRecord) ?MaterialRecord {
        return self.scatterFn(self, r, hit);
    }
};

pub const MaterialRecord = struct {
    ray: Ray,
    attenuation: Color,
};

pub const Lambertian = struct {
    material: Material,
    albedo: *Texture,

    pub fn init(allocator: *Allocator, albedo: Color) !Lambertian {
        const color = try allocator.create(SolidColor);
        color.* = SolidColor.init(albedo.x, albedo.y, albedo.z);
        return Lambertian.init_tex(&color.texture);
    }

    pub fn init_tex(albedo: *Texture) Lambertian {
        return Lambertian{
            .material = Material{ .scatterFn = scatter },
            .albedo = albedo,
        };
    }

    fn scatter(material: *Material, r: Ray, record: HitRecord) ?MaterialRecord {
        const self = @fieldParentPtr(Lambertian, "material", material);

        const direction = vec3.random_in_hemisphere(record.normal);
        const new_ray = Ray{ .orig = record.p, .dir = direction, .time = r.time };
        return MaterialRecord{
            .ray = new_ray,
            .attenuation = self.albedo.value(record.u, record.v, record.p),
        };
    }
};

pub const Metal = struct {
    material: Material,
    albedo: Color,
    fuzz: f32,

    pub fn init(albedo: Color, f: f32) Metal {
        return Metal{
            .material = Material{ .scatterFn = scatter },
            .albedo = albedo,
            .fuzz = if (f < 1) f else 1,
        };
    }

    fn scatter(material: *Material, r: Ray, record: HitRecord) ?MaterialRecord {
        const self = @fieldParentPtr(Metal, "material", material);

        const reflected = vec3.reflect(r.dir.unit(), record.normal);
        const fuzzed = reflected.add(vec3.random_in_unit_sphere().mul(self.fuzz));

        if (fuzzed.dot(record.normal) > 0) {
            return MaterialRecord{
                .ray = Ray{ .orig = record.p, .dir = fuzzed, .time = r.time },
                .attenuation = self.albedo,
            };
        } else {
            return null;
        }
    }
};

pub const Dielectric = struct {
    material: Material,
    ir: f32,

    pub fn init(index_of_refraction: f32) Dielectric {
        return Dielectric{
            .material = Material{ .scatterFn = scatter },
            .ir = index_of_refraction,
        };
    }

    fn scatter(material: *Material, r: Ray, record: HitRecord) ?MaterialRecord {
        const self = @fieldParentPtr(Dielectric, "material", material);

        const refraction_ratio = if (record.front_face) (1.0 / self.ir) else self.ir;

        const unit_direction = r.dir.unit();
        const cos_theta = std.math.min(unit_direction.neg().dot(record.normal), 1.0);
        const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

        const cannot_refract = refraction_ratio * sin_theta > 1.0;
        var direction: vec3.Vec3 = undefined;
        if (cannot_refract or reflectance(cos_theta, refraction_ratio) > utils.rand_float()) {
            direction = vec3.reflect(unit_direction, record.normal);
        } else {
            direction = vec3.refract(unit_direction, record.normal, refraction_ratio);
        }

        const refracted = Ray{
            .orig = record.p,
            .dir = direction,
            .time = r.time,
        };

        return MaterialRecord{
            .ray = refracted,
            .attenuation = Color.new(1, 1, 1),
        };
    }
};

fn reflectance(cosine: f32, ref_idx: f32) f32 {
    // Schlick's approximation for reflectance
    var r0 = (1 - ref_idx) / (1 + ref_idx);
    r0 = r0 * r0;
    return r0 + (1 - r0) * std.math.pow(f32, 1 - cosine, 5);
}
