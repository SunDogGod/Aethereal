@tool
extends AcceptDialog
## Shows docs/customizing.md inside the editor, lightly formatted (headings, bold, code, lists,
## tables). "Open in text editor" opens the file itself, to read it side by side or edit it.

const GUIDE := "res://docs/customizing.md"
const ACCENT := "#ffc266"
const CODE := "#a9c4ff"  # file names and commands

var _text: RichTextLabel


func _init() -> void:
	title = "Aethereal: customizing guide"
	ok_button_text = "Close"
	add_button("Open in text editor", true, "open_file")
	custom_action.connect(_on_action)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.selection_enabled = true
	_text.custom_minimum_size = Vector2(760, 560)
	add_child(_text)


func show_guide(scale: float) -> void:
	_text.custom_minimum_size = Vector2(760, 560) * scale
	_text.text = to_bbcode(FileAccess.get_file_as_string(GUIDE), _text.get_theme_font_size("normal_font_size"))
	if _text.text.is_empty():
		_text.text = "Couldn't read " + GUIDE
	popup_centered()


func _on_action(action: StringName) -> void:
	if action == "open_file":
		OS.shell_open(ProjectSettings.globalize_path(GUIDE))


## Markdown, the little of it the guide uses, into RichTextLabel BBCode.
static func to_bbcode(md: String, base_size := 16) -> String:
	var out := PackedStringArray()
	var in_code := false
	var bold := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	var code := RegEx.create_from_string("`([^`]+)`")
	var link := RegEx.create_from_string("\\[lb\\]([^\\]]+?)\\]\\(([^)]+)\\)")
	for raw in md.split("\n"):
		var line := raw.replace("[", "[lb]")
		if line.strip_edges().begins_with("```"):
			in_code = not in_code
			continue
		if in_code:
			out.append("[color=%s][code]    %s[/code][/color]" % [CODE, line])
			continue
		if line.begins_with("|") and line.replace("|", "").replace("-", "").replace(" ", "").replace(":", "").is_empty():
			continue  # a table's |---|---| row
		line = link.sub(line, "$1", true)
		line = bold.sub(line, "[b]$1[/b]", true)
		line = code.sub(line, "[color=%s][code]$1[/code][/color]" % CODE, true)
		if line.begins_with("# "):
			line = "[font_size=%d][b]%s[/b][/font_size]" % [roundi(base_size * 1.6), line.substr(2)]
		elif line.begins_with("## "):
			line = "\n[font_size=%d][b][color=%s]%s[/color][/b][/font_size]" % [roundi(base_size * 1.3), ACCENT, line.substr(3)]
		elif line.begins_with("### "):
			line = "[b]%s[/b]" % line.substr(4)
		elif line.begins_with("- ") or line.begins_with("* "):
			line = "  •  " + line.substr(2)
		elif line.begins_with("  - "):
			line = "        –  " + line.substr(4)
		elif line.begins_with("|"):
			line = "  " + line.trim_prefix("|").trim_suffix("|").replace("|", "  ·  ")
		out.append(line)
	return "\n".join(out)
