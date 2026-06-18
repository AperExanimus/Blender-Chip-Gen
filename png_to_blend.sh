#!/bin/bash

INPUT_PNG="$1"
INPUT_STL="$2"

if [ -z "$INPUT_PNG" ] || [ -z "$INPUT_STL" ]; then 
    echo "Usage: $0 <image.png> <disk.stl>"
    exit 1
fi

BASENAME=$(basename "${INPUT_PNG%.*}")
STL_BASENAME=$(basename "${INPUT_STL%.*}")
OUTPUT_SVG="${BASENAME}.svg"
TEMP_PY="temp_blender.py"

if command -v blender &> /dev/null; then
    BLENDER_CMD="blender"
fi

echo "=== Step 1: Converting PNG to SVG ==="
./convert_png_svg.sh "$INPUT_PNG"

if [ $? -ne 0 ] || [ ! -f "$OUTPUT_SVG" ]; then
    echo "✗ PNG conversion failed."
    exit 1
fi
echo "✓ SVG created: $OUTPUT_SVG"
echo ""

echo "=== Step 2: Loading STL, Importing SVG, Scaling SVG to 90% of STL, Placing SVG on Top ==="

cat > "$TEMP_PY" << 'PYTHON_EOF'
import bpy
import sys
import os
import struct
import bmesh
from mathutils import Vector

def load_stl_manually(filepath):
    filename = os.path.basename(filepath).replace('.stl', '')
    mesh_data = bpy.data.meshes.new(name=f"{filename}_mesh")
    obj = bpy.data.objects.new(filename, mesh_data)
    bpy.context.collection.objects.link(obj)
    
    vertices = []
    faces = []
    try:
        with open(filepath, 'rb') as f:
            f.read(80)
            num_faces = struct.unpack('<I', f.read(4))[0]
            for _ in range(num_faces):
                f.read(12)
                v1 = struct.unpack('<fff', f.read(12))
                vertices.append(v1)
                v2 = struct.unpack('<fff', f.read(12))
                vertices.append(v2)
                v3 = struct.unpack('<fff', f.read(12))
                vertices.append(v3)
                f.read(2)
                base_idx = len(vertices) - 3
                faces.append((base_idx, base_idx+1, base_idx+2))
        
        bm = bmesh.new()
        for v in vertices:
            bm.verts.new(v)
        bm.verts.ensure_lookup_table()
        for f_indices in faces:
            verts_list = [bm.verts[i] for i in f_indices]
            bm.faces.new(verts_list)
        bm.normal_update()
        bm.to_mesh(mesh_data)
        bm.free()
        mesh_data.update()
        return obj
    except Exception as e:
        print(f"Error loading STL: {e}")
        return None

# --- 0. CLEANUP ---
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
print("Scene cleaned.")

if len(sys.argv) < 3:
    sys.exit(1)

stl_path = sys.argv[-2]
svg_path = sys.argv[-1]

# 1. Load STL
stl_obj = load_stl_manually(stl_path)
if not stl_obj:
    sys.exit(1)

bpy.context.view_layer.objects.active = stl_obj
stl_obj.select_set(True)
bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

target_width = max(stl_obj.dimensions.x, stl_obj.dimensions.y)
print(f"Target Width (Disk): {target_width:.4f}")

# 2. Import SVG
try:
    bpy.ops.import_curve.svg(filepath=svg_path)
    svg_objs = [o for o in bpy.data.objects if o.type == 'CURVE']
except Exception as e:
    print(f"SVG Error: {e}")
    sys.exit(1)

if not svg_objs:
    print("No SVG curves found.")
    sys.exit(1)

print(f"Found {len(svg_objs)} curves. Converting to Mesh...")

# 3. Convert Curves to Meshes
for obj in svg_objs:
    obj.select_set(True)
bpy.context.view_layer.objects.active = svg_objs[0]
bpy.ops.object.convert(target='MESH')

mesh_objs = [o for o in bpy.data.objects if o.type == 'MESH' and o != stl_obj]
print(f"Converted to {len(mesh_objs)} meshes.")

# 4. Calculate Current Size
all_verts = []
for obj in mesh_objs:
    for v in obj.data.vertices:
        global_co = obj.matrix_world @ v.co
        all_verts.append(global_co)

min_x = min(v[0] for v in all_verts)
max_x = max(v[0] for v in all_verts)
min_y = min(v[1] for v in all_verts)
max_y = max(v[1] for v in all_verts)
current_width = max(max_x - min_x, max_y - min_y)

print(f"Current SVG Width: {current_width:.4f}")

# 5. Calculate Scale Factor (90%)
# Calculate base scale first, then multiply by 0.9
base_scale = target_width / current_width if current_width > 0 else 1.0
scale_factor = base_scale * 0.9  # <-- THIS MAKES IT 90%

print(f"Base Scale: {base_scale:.4f} | Final Scale (90%): {scale_factor:.4f}")

# 6. Apply Scale
for obj in mesh_objs:
    obj.scale = (scale_factor, scale_factor, scale_factor)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(scale=True, location=False, rotation=False)

# 7. Reposition to TOP
new_verts = []
for obj in mesh_objs:
    for v in obj.data.vertices:
        new_verts.append(obj.matrix_world @ v.co)

new_min_x = min(v[0] for v in new_verts)
new_max_x = max(v[0] for v in new_verts)
new_min_y = min(v[1] for v in new_verts)
new_max_y = max(v[1] for v in new_verts)
new_min_z = min(v[2] for v in new_verts)
new_max_z = max(v[2] for v in new_verts)

center_x = (new_min_x + new_max_x) / 2
center_y = (new_min_y + new_max_y) / 2
center_z = (new_min_z + new_max_z) / 2

# Lift to the TOP of the disk 
# Previous was (height/2) which puts it in the middle.
# New is (height) which puts it on top.
lift_height = stl_obj.dimensions.z 

offset_x = stl_obj.location.x - center_x
offset_y = stl_obj.location.y - center_y
offset_z = lift_height - center_z

for obj in mesh_objs:
    obj.location = (obj.location.x + offset_x, obj.location.y + offset_y, obj.location.z + offset_z)

# 8. Final Verification
final_verts = []
for obj in mesh_objs:
    for v in obj.data.vertices:
        final_verts.append(obj.matrix_world @ v.co)
        
f_min_x = min(v[0] for v in final_verts)
f_max_x = max(v[0] for v in final_verts)
f_min_y = min(v[1] for v in final_verts)
f_max_y = max(v[1] for v in final_verts)
final_w = max(f_max_x - f_min_x, f_max_y - f_min_y)

print(f"--- FINAL CHECK ---")
print(f"Final SVG Width: {final_w:.4f} (Target was {target_width:.4f}, so 90% should be ~{target_width*0.9:.4f})")
print(f"Final SVG Z-High: {max(v[2] for v in final_verts):.4f} | Disk Top: {stl_obj.location.z + stl_obj.dimensions.z:.4f}")

out_name = stl_path.replace('.stl', '_with_svg.blend')
bpy.ops.wm.save_as_mainfile(filepath=out_name)
print("Saved.")
PYTHON_EOF

$BLENDER_CMD --background --python "$TEMP_PY" -- "$INPUT_STL" "$OUTPUT_SVG"

RESULT=$?
rm -f "$TEMP_PY"

if [ $RESULT -eq 0 ]; then
    echo ""
    echo "=== ALL DONE SUCCESSFULLY ==="
    echo "Output: ${STL_BASENAME}_with_svg.blend"
else
    echo "✗ Process failed."
    exit 1
fi
