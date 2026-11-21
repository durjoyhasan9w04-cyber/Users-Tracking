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

kotlin_files = list(provider_path.rglob("UserHubWidgetProvider.kt")) + list(provider_path.rglob("WidgetQuickEntryActivity.kt"))
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

for path in (root / "res").rglob("*.xml"):
    ET.parse(path)

provider_info = root / "res/xml/user_hub_widget_info.xml"
info = ET.parse(provider_info).getroot()
android = "{http://schemas.android.com/apk/res/android}"
if info.get(android + "minHeight") != "500dp":
    raise SystemExit("Widget minimum height is not the full Design B height")
if info.get(android + "minResizeHeight") != "470dp":
    raise SystemExit("Widget minimum resize height is not tall enough for Design B")

if "ACTION_EDIT_AMOUNT" not in kotlin or "ACTION_EDIT_GOAL" not in kotlin:
    raise SystemExit("Manual coin entry and daily DP goal editors must both be implemented")
if "putFloat(WidgetStore.AMOUNT" not in kotlin or "putFloat(WidgetStore.DAILY_GOAL" not in kotlin:
    raise SystemExit("Manual amount and goal values are not persisted")
if "widget_amount_group" not in kotlin or "widget_goal_text" not in kotlin:
    raise SystemExit("Amount and goal controls are not wired to their editors")
print(f"Validated full Design B widget: {len(id_set)} unique views, {len(drawable_refs)} drawable references, manual amount + goal controls, all XML well formed.")
