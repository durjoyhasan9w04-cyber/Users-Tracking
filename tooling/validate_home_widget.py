#!/usr/bin/env python3
"""Validate the generated native UserHub home-screen widget before Android compilation."""
from collections import Counter
from pathlib import Path
import re
import xml.etree.ElementTree as ET

root = Path("android/app/src/main")
layout_path = root / "res/layout/widget_user_hub.xml"
provider_path = root / "kotlin"
if not layout_path.exists():
    raise SystemExit("Widget layout was not generated")

ET.parse(layout_path)
layout = layout_path.read_text()
ids = re.findall(r"@\+id/([A-Za-z0-9_]+)", layout)
duplicates = sorted(name for name, count in Counter(ids).items() if count > 1)
if duplicates:
    raise SystemExit("Duplicate widget view IDs: " + ", ".join(duplicates))
id_set = set(ids)

kotlin_files = list(provider_path.rglob("UserHubWidgetProviderV2.kt")) + list(provider_path.rglob("WidgetQuickEntryActivity.kt"))
if len(kotlin_files) != 2:
    raise SystemExit("Expected both native widget Kotlin source files")
kotlin = "\n".join(path.read_text() for path in kotlin_files)
referenced_ids = set(re.findall(r"R\.id\.([A-Za-z0-9_]+)", kotlin))
missing_ids = sorted(referenced_ids - id_set)
if missing_ids:
    raise SystemExit("Kotlin references missing widget views: " + ", ".join(missing_ids))

drawable_refs = set(re.findall(r"(?<!android\.)R\.drawable\.([A-Za-z0-9_]+)", kotlin))
drawable_files = {path.stem for path in (root / "res/drawable").glob("*.xml")}
missing_drawables = sorted(drawable_refs - drawable_files)
if missing_drawables:
    raise SystemExit("Kotlin references missing widget drawables: " + ", ".join(missing_drawables))

required = {
    "widget_goal_ring", "widget_goal_ring_text", "widget_goal_text", "widget_mode_dp", "widget_mode_bonus",
    "widget_recent_avatar_1", "widget_recent_avatar_2", "widget_recent_avatar_3",
    "widget_recent_name_1", "widget_recent_name_2", "widget_recent_name_3",
    "widget_quick_add_user", "widget_selected_detail", "widget_amount_group", "widget_amount",
    "widget_amount_unit", "widget_minus", "widget_plus", "widget_preset_1", "widget_preset_5",
    "widget_preset_10", "widget_preset_25", "widget_add", "widget_undo", "widget_refresh",
}
missing_required = sorted(required - id_set)
if missing_required:
    raise SystemExit("Required Design B controls missing: " + ", ".join(missing_required))

# The three recent-user avatars and both amount steppers must be visually uniform.
root_node = ET.parse(layout_path).getroot()
by_id = {node.get("{http://schemas.android.com/apk/res/android}id", "").split("/")[-1]: node for node in root_node.iter()}
def dims(view_id):
    node = by_id.get(view_id)
    if node is None:
        raise SystemExit("Missing size-checked widget view: " + view_id)
    return (node.get("{http://schemas.android.com/apk/res/android}layout_width"),
            node.get("{http://schemas.android.com/apk/res/android}layout_height"))
avatar_sizes = {dims("widget_recent_avatar_" + str(i)) for i in range(1, 4)}
if len(avatar_sizes) != 1:
    raise SystemExit("Recent-user avatar sizes are inconsistent")
if dims("widget_minus") != dims("widget_plus"):
    raise SystemExit("Amount minus/plus controls must have identical dimensions")
if dims("widget_quick_add_user") != dims("widget_recent_avatar_1"):
    raise SystemExit("Add-user icon must match recent-user avatar dimensions")

for path in (root / "res").rglob("*.xml"):
    ET.parse(path)

provider_info = root / "res/xml/user_hub_widget_info.xml"
info = ET.parse(provider_info).getroot()
android = "{http://schemas.android.com/apk/res/android}"
if info.get(android + "minHeight") != "350dp":
    raise SystemExit("Widget minimum height is not the requested 4x5 footprint")
if info.get(android + "minResizeHeight") != "280dp":
    raise SystemExit("Widget minimum resize height must preserve the requested 5-row footprint")

if "ACTION_EDIT_AMOUNT" not in kotlin or "ACTION_EDIT_GOAL" not in kotlin:
    raise SystemExit("Manual coin entry and daily DP goal editors must both be implemented")
if "putFloat(WidgetStore.AMOUNT" not in kotlin or "WidgetStore.DAILY_GOAL" not in kotlin or "putFloat(if (isGoal)" not in kotlin:
    raise SystemExit("Manual amount and goal values are not persisted")
if "widget_amount_group" not in kotlin or "widget_goal_text" not in kotlin:
    raise SystemExit("Amount and goal controls are not wired to their editors")
if info.get(android + "targetCellHeight") != "5" or info.get(android + "targetCellWidth") != "4":
    raise SystemExit("Widget default launcher footprint must reserve 4 columns by 5 rows")
print(f"Validated 4x5 Design B widget: {len(id_set)} unique views, {len(drawable_refs)} drawable references, manual amount + goal controls, all XML well formed.")
