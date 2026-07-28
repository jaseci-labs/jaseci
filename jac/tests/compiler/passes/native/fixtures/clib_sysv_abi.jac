"""Test fixture: System V AMD64 ABI lowering for foreign structs (Phase 1).

Declares C structs spanning every eightbyte classification case and extern
functions that pass/return them by value. The native backend must emit the
platform psABI form clang/gcc produce: SSE eightbytes as float/double/
<2 x float>, INTEGER eightbytes as iN, MEMORY aggregates via byval/sret.
"""

import from "/usr/lib/libm.so.6" {
    obj V2 {
        has x: f32,
            y: f32;
    }  obj V3 {  # 8B  -> <2 x float>
        has x: f32,
            y: f32,
            z: f32;
    }  obj V4 {  # 12B -> <2 x float>, float
        has x: f32,
            y: f32,
            z: f32,
            w: f32;
    }  obj Col {  # 16B -> <2 x float>, <2 x float>
        has r: u8,
            g: u8,
            b: u8,
            a: u8;
    }  obj FI {  # 4B  -> i32
        has f: f32,
            i: i32;
    }  obj DD {  # 8B  -> i64 (SSE+INT merge -> INTEGER)
        has a: f64,
            b: f64;
    }  obj Cam {  # 16B -> double, double
        has pos: V3,
            tgt: V3,
            up: V3,
            fovy: f32,
            proj: i32;
    }  def v2_sum(v: V2) -> f32;  def v3_scale(v: V3, s: f32) -> V3;  def v4_sum(  # 44B -> MEMORY
        v: V4
    ) -> f32;  def col_sum(c: Col) -> i32;  def fi_mix(s: FI) -> f32;  def dd_sum(
        d: DD
    ) -> f64;  def cam_fovy(c: Cam) -> f32;  def cam_mk(fovy: f32, proj: i32) -> Cam;
}

def use_all {
    v2_sum(V2(x=1.0, y=2.0));
    cam_fovy(cam_mk(45.0, 1));
}
