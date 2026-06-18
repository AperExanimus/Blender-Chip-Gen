#!/bin/bash

INPUT_PNG="$1"
INPUT_STL="$2"
SCALE_FACTOR_INPUT="${3:-0.9}"  # Default to 0.9 (90%) if not provided

# Validate inputs
if [ -z "$INPUT_PNG" ] || [ -z "$INPUT_STL" ]; then 
    echo "Usage: $0 <image.png> <disk.stl> [scale_factor]"
    echo "Example: $0 logo.png disk.stl 0.8   (Scales to 80%)"
    exit 1
fi

BASENAME_PNG=$(basename "${INPUT_PNG%.*}")
BASENAME_STL=$(basename "${INPUT_STL%.*}")
OUTPUT_SVG="${BASENAME_PNG}.svg"
TEMP_PY="temp_blender_dynamic.py"

# Check Blender command
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

echo "=== Step 2: Processing with Scale: ${SCALE_FACTOR_INPUT} ==="

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

if len(sys.argv) < 4:
    print("Missing arguments!")
    sys.exit(1)

stl_path = sys.argv[-3]
svg_path = sys.argv[-2]
target_scale_input = float(sys.argv[-1])

print(f"Input Scale Factor: {target_scale_input}")

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
# FIX: Changed objects_active to objects.active
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

# 5. Calculate Final Scale Factor
base_scale = target_width / current_width if current_width > 0 else 1.0
final_scale = base_scale * target_scale_input

print(f"Base Scale (100%): {base_scale:.4f}")
print(f"Final Scale ({target_scale_input*100}%): {final_scale:.4f}")

# 6. Apply Scale
for obj in mesh_objs:
    obj.scale = (final_scale, final_scale, final_scale)
    # FIX: Changed objects_active to objects.active
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

expected_w = target_width * target_scale_input
print(f"--- FINAL CHECK ---")
print(f"Final SVG Width: {final_w:.4f}")
print(f"Expected Width:  {expected_w:.4f} (Target: {target_width:.4f} x Scale: {target_scale_input})")

# 9. Generate Combined Filename
stl_name = os.path.splitext(os.path.basename(stl_path))[0]
svg_name = os.path.splitext(os.path.basename(svg_path))[0]
output_filename = f"{stl_name}_{svg_name}.blend"

out_path = os.path.join(os.path.dirname(stl_path), output_filename)
bpy.ops.wm.save_as_mainfile(filepath=out_path)
print(f"Saved as: {os.path.basename(out_path)}")
PYTHON_EOF

$BLENDER_CMD --background --python "$TEMP_PY" -- "$INPUT_STL" "$OUTPUT_SVG" "$SCALE_FACTOR_INPUT"

RESULT=$?
rm -f "$TEMP_PY"

if [ $RESULT -eq 0 ]; then
    echo ""
    echo "=== SUCCESS ==="
    echo "Output: ${BASENAME_STL}_${BASENAME_PNG}.blend"
else
    echo "✗ Process failed."
    exit 1
fi
