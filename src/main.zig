const std = @import("std");
const assert = std.debug.assert;
const vec3 = @import("vec3.zig");
const color = @import("color.zig");
const ray = @import("ray.zig");
const objects = @import("objects.zig");
const Camera = @import("camera.zig").Camera;
const utils = @import("utils.zig");
const material = @import("material.zig");
const texture = @import("texture.zig");
const CheckerTexture = texture.CheckerTexture;

const Vec3 = vec3.Vec3;
const Point3 = vec3.Point3;
const Color = color.Color;
const Ray = ray.Ray;
const Allocator = std.mem.Allocator;
const Sphere = objects.Sphere;
const MovingSphere = objects.MovingSphere;
const BVHNode = objects.BVHNode;
const Lambertian = material.Lambertian;
const Metal = material.Metal;
const Dielectric = material.Dielectric;
const HittableList = objects.HittableList;

fn random_scene(allocator: *Allocator) !HittableList {
    var world = HittableList.init(allocator);

    const ground_texture = try allocator.create(CheckerTexture);
    ground_texture.* = try CheckerTexture.init(allocator, Color.new(0.2, 0.3, 0.1), Color.new(0.9, 0.9, 0.9));

    const ground_material = try allocator.create(Lambertian);
    ground_material.* = Lambertian.init_tex(&ground_texture.texture);

    const ground_sphere = try allocator.create(Sphere);
    ground_sphere.* = Sphere.init(Point3.new(0, -1000, 0), 1000, &ground_material.material);
    try world.add(&ground_sphere.hittable);

    var a: i8 = -11;
    while (a < 11) : (a += 1) {
        var b: i8 = -11;
        while (b < 11) : (b += 1) {
            const choose_mat = utils.rand_float();
            const center = Point3.new(@intToFloat(f32, a) + 0.9 * utils.rand_float(), 0.2, @intToFloat(f32, b) + 0.9 * utils.rand_float());

            if (center.sub(Point3.new(4, 0.2, 0)).length() > 0.9) {
                if (choose_mat < 0.8) {
                    const albedo = Color.random().mulv(Color.random());
                    const sphere_material = try allocator.create(Lambertian);
                    sphere_material.* = try Lambertian.init(allocator, albedo);
                    const center2 = center.add(Vec3.new(0, utils.rand_float_range(0, 0.5), 0));
                    const sphere = try allocator.create(MovingSphere);
                    sphere.* = MovingSphere.init(center, center2, 0, 1, 0.2, &sphere_material.material);
                    try world.add(&sphere.hittable);
                } else if (choose_mat < 0.95) {
                    const albedo = Color.random_range(0.5, 1);
                    const fuzz = utils.rand_float_range(0, 0.5);
                    const sphere_material = try allocator.create(Metal);
                    sphere_material.* = Metal.init(albedo, fuzz);
                    const sphere = try allocator.create(Sphere);
                    sphere.* = Sphere.init(center, 0.2, &sphere_material.material);
                    try world.add(&sphere.hittable);
                } else {
                    const sphere_material = try allocator.create(Dielectric);
                    sphere_material.* = Dielectric.init(1.5);
                    const sphere = try allocator.create(Sphere);
                    sphere.* = Sphere.init(center, 0.2, &sphere_material.material);
                    try world.add(&sphere.hittable);
                }
            }
        }
    }

    const material1 = try allocator.create(Dielectric);
    material1.* = Dielectric.init(1.5);
    const sphere1 = try allocator.create(Sphere);
    sphere1.* = Sphere.init(Point3.new(0, 1, 0), 1.0, &material1.material);
    try world.add(&sphere1.hittable);

    const material2 = try allocator.create(Lambertian);
    material2.* = try Lambertian.init(allocator, Color.new(0.4, 0.2, 0.1));
    const sphere2 = try allocator.create(Sphere);
    sphere2.* = Sphere.init(Point3.new(-4, 1, 0), 1.0, &material2.material);
    try world.add(&sphere2.hittable);

    const material3 = try allocator.create(Metal);
    material3.* = Metal.init(Color.new(0.7, 0.6, 0.5), 0.0);
    const sphere3 = try allocator.create(Sphere);
    sphere3.* = Sphere.init(Point3.new(4, 1, 0), 1.0, &material3.material);
    try world.add(&sphere3.hittable);

    return world;
}

fn two_spheres(allocator: *Allocator) !HittableList {
    const checker = try allocator.create(CheckerTexture);
    checker.* = try CheckerTexture.init(allocator, Color.new(0.2, 0.3, 0.1), Color.new(0.9, 0.9, 0.9));

    const mat = try allocator.create(Lambertian);
    mat.* = Lambertian.init_tex(&checker.texture);

    const sphere1 = try allocator.create(Sphere);
    sphere1.* = Sphere.init(Point3.new(0, -10, 0), 10, &mat.material);

    const sphere2 = try allocator.create(Sphere);
    sphere2.* = Sphere.init(Point3.new(0, 10, 0), 10, &mat.material);

    var list = HittableList.init(allocator);
    try list.add(&sphere1.hittable);
    try list.add(&sphere2.hittable);
    return list;
}

fn ray_color(r: Ray, world: *objects.Hittable, depth: u32) Color {
    if (depth <= 0) return Color.new(0, 0, 0);

    if (world.hit(r, 0.001, 1000)) |record| {
        if (record.material.scatter(r, record)) |mat| {
            return ray_color(mat.ray, world, depth - 1).mulv(mat.attenuation);
        }

        return Color.new(0, 0, 0);
    }

    const unit_direction = r.dir.unit();
    const t = 0.5 * (unit_direction.y + 1.0);
    const white = Color.new(1, 1, 1);
    const blueish = Color.new(0.5, 0.7, 1.0);
    return white.mul((1.0 - t)).add(blueish.mul(t));
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    const aspect_ratio = 16.0 / 9.0;
    const image_width = 400;
    const image_height = @floatToInt(u32, @intToFloat(f32, image_width) / aspect_ratio);
    const samples_per_pixel = 200;
    const max_depth = 50;

    var world_: HittableList = undefined;

    var lookfrom: Point3 = undefined;
    var lookat: Point3 = undefined;
    var vfov: f32 = 40.0;
    var aperture: f32 = 0.0;

    switch (0) {
        1 => {
            world_ = try random_scene(allocator);
            lookfrom = Point3.new(13, 2, 3);
            lookat = Point3.new(0, 0, 0);
            vfov = 20.0;
            aperture = 0.1;
        },
        else => {
            world_ = try two_spheres(allocator);
            lookfrom = Point3.new(13, 2, 3);
            lookat = Point3.new(0, 0, 0);
            vfov = 20.0;
        },
    }

    const vup = Vec3.new(0, 1, 0);
    const dist_to_focus = 10.0;
    const camera = Camera.init(
        lookfrom,
        lookat,
        vup,
        vfov,
        aspect_ratio,
        aperture,
        dist_to_focus,
        0,
        1,
    );

    var world = try BVHNode.init(allocator, world_, 0, 1);

    try stdout.print("P3\n{} {}\n255\n", .{ image_width, image_height });

    var j: isize = image_height - 1;
    while (j >= 0) : (j -= 1) {
        try stderr.print("Scanlines remaining: {}\n", .{j});

        var i: usize = 0;
        while (i < image_width) : (i += 1) {
            var pixel_color = Color.new(0, 0, 0);
            var s: usize = 0;
            while (s < samples_per_pixel) : (s += 1) {
                const ii = @intToFloat(f32, i) + utils.rand_float();
                const jj = @intToFloat(f32, j) + utils.rand_float();
                const u = ii / (@intToFloat(f32, image_width) - 1.0);
                const v = jj / (@intToFloat(f32, image_height) - 1.0);

                const r = camera.get_ray(u, v);
                pixel_color.add_(ray_color(r, &world.hittable, max_depth));
            }

            try color.write_color(&stdout, pixel_color, samples_per_pixel);
        }
    }

    try stderr.print("Done\n", .{});
}
