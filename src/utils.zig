const std = @import("std");

pub fn degrees_to_radians(deg: f32) f32 {
    return deg * std.math.pi / 180.0;
}

var rand = std.rand.DefaultPrng.init(0);

pub fn rand_float() f32 {
    return rand.random.float(f32);
}

pub fn rand_float_range(min: f32, max: f32) f32 {
    return min + (max - min) * rand_float();
}

pub fn clamp(x: f32, min: f32, max: f32) f32 {
    if (x < min) return min;
    if (x > max) return max;
    return x;
}
