bl_info = {
    "name": "Poker Chip Generator (Test)",
    "blender": (2, 80, 0),
    "category": "Object",  # Category doesn't matter much if not in menu
}

import bpy


class PokerChipGen(bpy.types.Operator):
    bl_idname = "object.poker_chip_gen"
    bl_label = "Generate Poker Chip (Test)"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        # 1. Create Cylinder
        bpy.ops.mesh.primitive_cylinder_add(
            radius=1.7,
            depth=2,
            enter_editmode=False,
            align='WORLD',
            location=(0, 0, -0.31),
            scale=(2, 2, 0.3)
        )
        base_obj = context.active_object

        # 2. Create Bezier Circle
        bpy.ops.curve.primitive_bezier_circle_add(
            radius=1,
            enter_editmode=False,
            align='WORLD',
            location=(0, 0, 0.5),
            scale=(2, 2, 1)
        )
        curve_obj = context.active_object

        # Resize Curve
        bpy.ops.transform.resize(
            value=(2.20542, 2.20542, 1),
            orient_type='GLOBAL',
            orient_matrix=((1, 0, 0), (0, 1, 0), (0, 0, 1)),
            orient_matrix_type='GLOBAL',
            constraint_axis=(True, True, False),
            mirror=False,
            use_proportional_edit=False,
            proportional_edit_falloff='SMOOTH',
            proportional_size=1,
            use_proportional_connected=False,
            use_proportional_projected=False,
            snap=False,
            snap_elements={'INCREMENT'},
            use_snap_project=False,
            snap_target='CLOSEST',
            use_snap_self=True,
            use_snap_edit=True,
            use_snap_nonedit=True,
            use_snap_selectable=False,
            release_confirm=True
        )

        # 3. Add Text
        bpy.ops.object.text_add(
            enter_editmode=False,
            align='WORLD',
            location=(0, 0, 0),
            scale=(1, 1, 1)
        )
        text_obj = context.active_object

        # Set Text Content
        text = "♦ Text ♦"
        text_obj.data.body = text

        # 4. Add Curve Modifier
        mod = text_obj.modifiers.new(name="Curve", type='CURVE')
        mod.object = curve_obj

        bpy.ops.object.mode_set(mode='OBJECT')

        # Cleanup
        bpy.ops.object.select_all(action='DESELECT')
        base_obj.select_set(True)
        context.view_layer.objects.active = base_obj

        return {'FINISHED'}

def menu_func(self, context):
    self.layout.operator(PokerChipGen.bl_idname)

# Only register the class, NO menu appending
def register():
    bpy.utils.register_class(PokerChipGen)
    bpy.types.VIEW3D_MT_object.append(menu_func)  # Adds the new operator to an existing menu.

def unregister():
    bpy.utils.unregister_class(PokerChipGen)


if __name__ == "__main__":
    register()