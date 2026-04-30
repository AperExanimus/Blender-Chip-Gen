# 🎲 Blender-Chip-Gen
Initial draft to automatically generate a pocker chip with pre-aligned text in Blender. 

> **⚠️ Note:** This is currently a **test version** with a generic text template and alignment. Future updates are intended to provide a cleaner text curve and take inputs for text and SVGs. 

## Features
- **One-Click Generation:** Creates a cylinder base, a bevel curve, and text in a single operation.
- **Automatic Setup:** Applies a Curve modifier to wrap text around the circular rim.
- **Undo Support:** Fully supports Blender's undo stack (`bl_options = {'REGISTER', 'UNDO'}`).
- **Menu Integration:** Adds a "Generate Poker Chip (Test)" option to the **Object** menu.

## 📸 Preview
![Preview](./preview.png)

## 🛠️ Installation

1. Download the `poker_chip_gen.py` file from this repository.
2. Open **Blender**.
3. Determine add-on location with the following console commands:
```
import addon_utils
print(addon_utils.paths())
```
4. Go to **Edit** > **Preferences** > **Add-ons**.
5. Click the **Install...** button.
6. Navigate to and select `poker_chip_gen.py`.
7. Check the box next to **Object: Poker Chip Generator (Test)** to enable it.

## Usage

1. Ensure you are in the **Object Mode**.
2. Go to the top menu bar: **Object** > **Generate Poker Chip (Test)**.
   *(Alternatively, press `F3` and search for "Generate Poker Chip")*.
3. The addon will generate:
   - A **Cylinder** (Base)
   - A **Bezier Circle** (Rim guide)
   - A **Text Object** (Wrapped around the rim)

## 📂 File Structure
- `poker_chip_gen.py`: The main addon script.
- `README.md`: This documentation file.

## 🔧 Technical Details
- **Blender Version:** Compatible with Blender 2.80 and newer.
- **Category:** Object Tools.
- **Logic:**
  - Creates a cylinder at `(0, 0, -0.31)` with scaled dimensions.
  - Generates a Bezier circle and resizes it to act as a path.
  - Adds text "♦ Text ♦" and applies a **Curve Modifier** using the circle.

## 🚧 Roadmap / TODOs
- [ ] Add a UI Panel in the Sidebar (`N` panel) to adjust:
  - Text Content
  - Font Size
- [ ] Optimize the curve generation logic.

## 📄 License
This project is provided as-is for educational and testing purposes. Feel free to modify and distribute.

## 🤝 Contributing
Found a bug or have a feature request? Please open an **Issue** on GitHub!
