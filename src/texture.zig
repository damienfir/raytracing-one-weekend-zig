const std = @import("std");
const vec3 = @import("vec3.zig");
const Point3 = vec3.Point3;
const color = @import("color.zig");
const Color = color.Color;

const Allocator = std.mem.Allocator;

// Texture interface

pub const Texture = struct {
    _value: fn (self: *Texture, u: f32, v: f32, p: Point3) Color,
    pub fn value(self: *Texture, u: f32, v: f32, p: Point3) Color {
        return self._value(self, u, v, p);
    }
};

pub const SolidColor = struct {
    const Self = @This();

    texture: Texture,
    color_value: Color,

    pub fn init(r: f32, g: f32, b: f32) Self {
        return Self{
            .texture = Texture{ ._value = value },
            .color_value = Color.new(r, g, b),
        };
    }

    pub fn value(texture: *Texture, u: f32, v: f32, p: Point3) Color {
        const self = @fieldParentPtr(Self, "texture", texture);
        return self.color_value;
    }
};

pub const CheckerTexture = struct {
    const Self = @This();

    texture: Texture,
    even: *Texture,
    odd: *Texture,

    pub fn init(allocator: *Allocator, c1: Color, c2: Color) !Self {
        const color1 = try allocator.create(SolidColor);
        color1.* = SolidColor.init(c1.x, c1.y, c1.z);
        const color2 = try allocator.create(SolidColor);
        color2.* = SolidColor.init(c2.x, c2.y, c2.z);
        return Self.init_tex(&color1.texture, &color2.texture);
    }

    pub fn init_tex(even: *Texture, odd: *Texture) Self {
        return Self{
            .texture = Texture{ ._value = value },
            .even = even,
            .odd = odd,
        };
    }

    pub fn value(texture: *Texture, u: f32, v: f32, p: Point3) Color {
        const self = @fieldParentPtr(Self, "texture", texture);
        const sines = @sin(10 * p.x) * @sin(10 * p.y) * @sin(10 * p.z);
        if (sines < 0) {
            return self.odd.value(u, v, p);
        } else {
            return self.even.value(u, v, p);
        }
    }
};
