"""Generates the setup panels Theme from the Blender UI kit PNGs (see ui_kit.py).

Run (from the repo root):
    python tools/blender/make_theme.py assets/ui/setup/setup_theme.tres
"""
import sys
from pathlib import Path

DIR = "res://assets/ui/setup/"
PAD = 24  # transparent margin rendered around every kit element

ext: dict[str, str] = {}
subs: list[str] = []
props: list[str] = []


def tex(name: str) -> str:
    if name not in ext:
        ext[name] = f"{len(ext) + 1}_{name}"
    return f'ExtResource("{ext[name]}")'


def stylebox(name: str, tm: tuple[int, int], content: tuple[int, int, int, int]) -> str:
    """tm = texture margins (left/right, top/bottom), padding included.
    content = content margins (left, top, right, bottom) inside the control rect."""
    sid = f"sb_{name}"
    if any(s.startswith(f'[sub_resource type="StyleBoxTexture" id="{sid}"]') for s in subs):
        return f'SubResource("{sid}")'
    lr, tb = tm
    cl, ct, cr, cb = content
    subs.append(f'''[sub_resource type="StyleBoxTexture" id="{sid}"]
content_margin_left = {cl}.0
content_margin_top = {ct}.0
content_margin_right = {cr}.0
content_margin_bottom = {cb}.0
texture = {tex(name)}
texture_margin_left = {lr}.0
texture_margin_top = {tb}.0
texture_margin_right = {lr}.0
texture_margin_bottom = {tb}.0
expand_margin_left = {PAD}.0
expand_margin_top = {PAD}.0
expand_margin_right = {PAD}.0
expand_margin_bottom = {PAD}.0
''')
    return f'SubResource("{sid}")'


EMPTY = 'SubResource("sb_empty")'
subs.append('[sub_resource type="StyleBoxEmpty" id="sb_empty"]\n')

WHITE = "Color(1, 1, 1, 1)"
GOLD = "Color(1, 0.78, 0.25, 1)"
GREY = "Color(0.6, 0.6, 0.6, 0.6)"


def button(variation: str, normal: str, disabled: str, tm, content, font_size: int | None = 44,
           base: str = "Button") -> None:
    n = stylebox(normal, tm, content)
    d = stylebox(disabled, tm, content)
    props.append(f'{variation}/base_type = &"{base}"')
    for state in ("normal", "hover", "pressed", "hover_pressed"):
        props.append(f"{variation}/styles/{state} = {n}")
    props.append(f"{variation}/styles/disabled = {d}")
    props.append(f"{variation}/styles/focus = {EMPTY}")
    if font_size:
        props.append(f"{variation}/font_sizes/font_size = {font_size}")
        for c in ("font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"):
            if variation != "PillButtonActive":
                props.append(f"{variation}/colors/{c} = {WHITE}")
        props.append(f"{variation}/colors/font_disabled_color = {GREY}")
        props.append(f"{variation}/colors/font_outline_color = Color(0, 0, 0, 0.8)")
        props.append(f"{variation}/constants/outline_size = 6")


# Bottom bar pills (400x120 visual): no vertical stretch, ends stay round.
PILL = ((PAD + 60, PAD + 59), (40, 10, 40, 10))
button("PillButton", "pill_button_normal", "pill_button_disabled", *PILL)
button("PillButtonActive", "pill_button_active", "pill_button_disabled", *PILL)
for c in ("font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"):
    props.append(f"PillButtonActive/colors/{c} = {GOLD}")
button("PillButtonRed", "pill_button_red_normal", "pill_button_red_disabled", *PILL)

# Round buttons (88x88 visual), symbol baked in the texture.
ROUND = ((PAD + 43, PAD + 43), (0, 0, 0, 0))
for glyph, variation in (("minus", "RoundMinusButton"), ("plus", "RoundPlusButton"), ("left", "RoundLeftButton"),
                         ("right", "RoundRightButton"), ("question", "RoundHelpButton")):
    button(variation, f"round_button_{glyph}_normal", f"round_button_{glyph}_disabled", *ROUND, font_size=None)

# List rows (256x90 source, 9-slice horizontally).
button("RowButton", "row_plate_normal", "row_plate_normal", (PAD + 30, PAD + 44), (24, 6, 24, 6), font_size=40)

# Big panels (256x256 source, 9-slice).
props.append('SetupPanel/base_type = &"PanelContainer"')
props.append(f"SetupPanel/styles/panel = {stylebox('panel', (PAD + 56, PAD + 56), (48, 24, 48, 32))}")

# Title plaque (640x120 visual), title drawn by a Label child.
props.append('TitlePlaque/base_type = &"PanelContainer"')
props.append(f"TitlePlaque/styles/panel = {stylebox('title_plaque', (PAD + 50, PAD + 59), (40, 8, 40, 8))}")
props.append('SetupTitle/base_type = &"Label"')
props.append("SetupTitle/font_sizes/font_size = 52")
props.append(f"SetupTitle/colors/font_color = {WHITE}")
props.append(f"SetupTitle/colors/font_outline_color = {GOLD}")
props.append("SetupTitle/constants/outline_size = 4")
props.append("SetupTitle/colors/font_shadow_color = Color(0, 0, 0, 0.7)")
props.append("SetupTitle/constants/shadow_offset_x = 3")
props.append("SetupTitle/constants/shadow_offset_y = 3")

# Option group title (gold small caps style).
props.append('GroupTitle/base_type = &"Label"')
props.append("GroupTitle/font_sizes/font_size = 42")
props.append(f"GroupTitle/colors/font_color = {GOLD}")

# Recessed value display (240x80 visual) for enum values and the name edit field.
VALUE = ((PAD + 24, PAD + 39), (16, 4, 16, 4))
props.append('ValueDisplay/base_type = &"Label"')
props.append(f"ValueDisplay/styles/normal = {stylebox('value_display', *VALUE)}")
props.append("ValueDisplay/font_sizes/font_size = 40")
props.append(f"ValueDisplay/colors/font_color = {WHITE}")
props.append('NameEdit/base_type = &"LineEdit"')
for state in ("normal", "read_only"):
    props.append(f"NameEdit/styles/{state} = {stylebox('value_display', *VALUE)}")
props.append(f"NameEdit/styles/focus = {EMPTY}")
props.append(f"NameEdit/colors/font_color = {WHITE}")
props.append(f"NameEdit/colors/caret_color = {GOLD}")
props.append("NameEdit/colors/selection_color = Color(1, 0.78, 0.25, 0.35)")

# Toggle switch for boolean options.
for icon, name in (("checked", "toggle_on"), ("unchecked", "toggle_off"),
                   ("checked_disabled", "toggle_on_disabled"), ("unchecked_disabled", "toggle_off_disabled")):
    props.append(f"CheckButton/icons/{icon} = {tex(name)}")
for state in ("normal", "hover", "pressed", "hover_pressed", "disabled", "focus"):
    props.append(f"CheckButton/styles/{state} = {EMPTY}")

lines = [f'[gd_resource type="Theme" load_steps={len(ext) + len(subs) + 1} format=3]', ""]
for name, rid in ext.items():
    lines.append(f'[ext_resource type="Texture2D" path="{DIR}{name}.png" id="{rid}"]')
lines.append("")
lines += subs
lines.append("[resource]")
lines += sorted(props)
Path(sys.argv[1]).write_text("\n".join(lines) + "\n")
