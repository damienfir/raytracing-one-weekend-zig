const std = @import("std");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const utils = @import("utils.zig");

const Point3 = vec3.Point3;
const Vec3 = vec3.Vec3;
const Ray = ray.Ray;

pub const Camera = struct {
    origin: Point3,
    lower_left_corner: Point3,
    horizontal: Vec3,
    vertical: Vec3,
    u: Vec3,
    v: Vec3,
    w: Vec3,
    lens_radius: f32,
    time0: f32,
    time1: f32,

    pub fn init(
        lookfrom: Point3,
        lookat: Point3,
        vup: Vec3,
        vfov: f32,
        aspect_ratio: f32,
        aperture: f32,
        focus_dist: f32,
        time0: f32,
        time1: f32,
    ) Camera {
        const theta = utils.degrees_to_radians(vfov);
        const h = std.math.tan(theta / 2.0);
        const viewport_height = 2.0 * h;
        const viewport_width = aspect_ratio * viewport_height;

        const w = lookfrom.sub(lookat).unit();
        const u = vup.cross(w).unit();
        const v = w.cross(u);

        const focal_length = 1.0;

        var camera: Camera = undefined;
        camera.origin = lookfrom;
        camera.horizontal = u.mul(viewport_width * focus_dist);
        camera.vertical = v.mul(viewport_height * focus_dist);
        camera.lower_left_corner = camera.origin.sub(camera.horizontal.div(2)).sub(camera.vertical.div(2)).sub(w.mul(focus_dist));
        camera.u = u;
        camera.v = v;
        camera.w = w;
        camera.lens_radius = aperture / 2.0;
        camera.time0 = time0;
        camera.time1 = time1;
        return camera;
    }

    pub fn get_ray(self: Camera, s: f32, t: f32) Ray {
        const rd = vec3.random_in_unit_disk().mul(self.lens_radius);
        const offset = self.u.mul(rd.x).add(self.v.mul(rd.y));
        return Ray{
            .orig = self.origin.add(offset),
            .dir = self.lower_left_corner.add(self.horizontal.mul(s)).add(self.vertical.mul(t)).sub(self.origin).sub(offset),
            .time = utils.rand_float_range(self.time0, self.time1),
        };
    }
};
