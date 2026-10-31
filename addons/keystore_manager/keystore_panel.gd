@tool
extends ScrollContainer

## Android Keystore Manager for Godot
## Author: Toplayrs
## License: MIT

signal keystore_created(path: String, alias_name: String, password: String)

# UI Node References
var _keytool_path_input: LineEdit
var _keytool_status_label: Label
var _keystore_path_input: LineEdit
var _keystore_password_input: LineEdit
var _keystore_confirm_password_input: LineEdit
var _alias_input: LineEdit
var _same_pass_checkbox: CheckBox
var _alias_password_input: LineEdit
var _alias_confirm_password_input: LineEdit
var _validity_spinbox: SpinBox
var _name_input: LineEdit
var _org_unit_input: LineEdit
var _org_input: LineEdit
var _city_input: LineEdit
var _state_input: LineEdit
var _country_input: LineEdit
var _apply_preset_checkbox: CheckBox
var _status_label: Label
var _output_box: TextEdit
var _generate_btn: Button
var _file_dialog: EditorFileDialog

var _resolved_keytool_path: String = ""

func _ready() -> void:
	name = "Keystore"
	custom_minimum_size = Vector2(480, 520)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	_detect_keytool()
	_update_same_password_state()

## Detects Java keytool binary across platforms (Windows, Linux, macOS)
func _detect_keytool() -> void:
	_resolved_keytool_path = ""
	var is_win: bool = OS.get_name() == "Windows"
	var binary_name: String = "keytool.exe" if is_win else "keytool"
	
	# 1. Check EditorSettings
	if Engine.is_editor_hint():
		var settings = EditorInterface.get_editor_settings()
		if settings:
			var java_sdk: String = settings.get_setting("export/android/java_sdk_path")
			if not java_sdk.is_empty():
				var candidate1: String = java_sdk.path_join("bin").path_join(binary_name)
				var candidate2: String = java_sdk.path_join(binary_name)
				if FileAccess.file_exists(candidate1):
					_resolved_keytool_path = candidate1
				elif FileAccess.file_exists(candidate2):
					_resolved_keytool_path = candidate2

	# 2. Check JAVA_HOME environment variable
	if _resolved_keytool_path.is_empty():
		var java_home: String = OS.get_environment("JAVA_HOME")
		if not java_home.is_empty():
			var candidate: String = java_home.path_join("bin").path_join(binary_name)
			if FileAccess.file_exists(candidate):
				_resolved_keytool_path = candidate

	# 3. Check system PATH
	if _resolved_keytool_path.is_empty():
		var cmd: String = "where" if is_win else "which"
		var output: Array = []
		var code: int = OS.execute(cmd, [binary_name], output, true)
		if code == 0 and output.size() > 0:
			var lines: PackedStringArray = output[0].strip_edges().split("\n")
			if lines.size() > 0:
				var found: String = lines[0].strip_edges()
				if FileAccess.file_exists(found):
					_resolved_keytool_path = found

	if not _resolved_keytool_path.is_empty():
		_keytool_status_label.text = "✓ Found keytool: " + _resolved_keytool_path
		_keytool_status_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.35))
		_keytool_path_input.text = _resolved_keytool_path
	else:
		_keytool_status_label.text = "⚠ keytool not found automatically. Please configure Java SDK in Editor Settings or browse keytool binary manually."
		_keytool_status_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.2))

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	# Title / Header
	var header := VBoxContainer.new()
	var title := Label.new()
	title.text = "Android Keystore Manager"
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Create and manage Android release signing keys for your project."
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	header.add_child(subtitle)
	root_vbox.add_child(header)

	# Section: Java keytool
	var keytool_box := _create_section(root_vbox, "Java keytool Executable")
	_keytool_status_label = Label.new()
	_keytool_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keytool_box.add_child(_keytool_status_label)

	var keytool_row := HBoxContainer.new()
	_keytool_path_input = LineEdit.new()
	_keytool_path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keytool_path_input.placeholder_text = "Path to keytool executable (auto-detected)"
	keytool_row.add_child(_keytool_path_input)

	var browse_keytool_btn := Button.new()
	browse_keytool_btn.text = "Browse..."
	browse_keytool_btn.pressed.connect(_on_browse_keytool_pressed)
	keytool_row.add_child(browse_keytool_btn)
	keytool_box.add_child(keytool_row)

	# Section: Keystore File
	var ks_box := _create_section(root_vbox, "Keystore Destination & Credentials")
	var ks_grid := GridContainer.new()
	ks_grid.columns = 2
	ks_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ks_grid.add_theme_constant_override("h_separation", 10)
	ks_grid.add_theme_constant_override("v_separation", 8)
	ks_box.add_child(ks_grid)

	# Destination Path
	ks_grid.add_child(_create_field_label("File Destination:"))
	var path_row := HBoxContainer.new()
	path_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keystore_path_input = LineEdit.new()
	_keystore_path_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keystore_path_input.text = "res://my-release-key.keystore"
	path_row.add_child(_keystore_path_input)

	var browse_ks_btn := Button.new()
	browse_ks_btn.text = "Save To..."
	browse_ks_btn.pressed.connect(_on_browse_keystore_pressed)
	path_row.add_child(browse_ks_btn)
	ks_grid.add_child(path_row)

	# Keystore Password
	ks_grid.add_child(_create_field_label("Keystore Password:"))
	_keystore_password_input = LineEdit.new()
	_keystore_password_input.secret = true
	_keystore_password_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keystore_password_input.placeholder_text = "Minimum 6 characters"
	_keystore_password_input.text_changed.connect(func(_val): _update_same_password_state())
	ks_grid.add_child(_create_secret_input_row(_keystore_password_input))

	# Confirm Keystore Password
	ks_grid.add_child(_create_field_label("Confirm Password:"))
	_keystore_confirm_password_input = LineEdit.new()
	_keystore_confirm_password_input.secret = true
	_keystore_confirm_password_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_keystore_confirm_password_input.text_changed.connect(func(_val): _update_same_password_state())
	ks_grid.add_child(_create_secret_input_row(_keystore_confirm_password_input))

	# Section: Key (Alias)
	var alias_box := _create_section(root_vbox, "Key Alias")
	var alias_grid := GridContainer.new()
	alias_grid.columns = 2
	alias_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alias_grid.add_theme_constant_override("h_separation", 10)
	alias_grid.add_theme_constant_override("v_separation", 8)
	alias_box.add_child(alias_grid)

	# Alias Name
	alias_grid.add_child(_create_field_label("Alias Name:"))
	_alias_input = LineEdit.new()
	_alias_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alias_input.text = "release"
	alias_grid.add_child(_alias_input)

	# Same Password Checkbox
	alias_grid.add_child(Control.new())
	_same_pass_checkbox = CheckBox.new()
	_same_pass_checkbox.text = "Use same password as Keystore (Recommended)"
	_same_pass_checkbox.button_pressed = true
	_same_pass_checkbox.toggled.connect(func(_val): _update_same_password_state())
	alias_grid.add_child(_same_pass_checkbox)

	# Key Password
	alias_grid.add_child(_create_field_label("Key Password:"))
	_alias_password_input = LineEdit.new()
	_alias_password_input.secret = true
	_alias_password_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_alias_password_input.placeholder_text = "Minimum 6 characters"
	alias_grid.add_child(_create_secret_input_row(_alias_password_input))

	# Confirm Key Password
	alias_grid.add_child(_create_field_label("Confirm Key Password:"))
	_alias_confirm_password_input = LineEdit.new()
	_alias_confirm_password_input.secret = true
	_alias_confirm_password_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alias_grid.add_child(_create_secret_input_row(_alias_confirm_password_input))

	# Section: Certificate Details
	var cert_box := _create_section(root_vbox, "Certificate Details (Distinguished Name)")
	var cert_grid := GridContainer.new()
	cert_grid.columns = 2
	cert_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cert_grid.add_theme_constant_override("h_separation", 10)
	cert_grid.add_theme_constant_override("v_separation", 8)
	cert_box.add_child(cert_grid)

	# Validity
	cert_grid.add_child(_create_field_label("Validity (Years):"))
	_validity_spinbox = SpinBox.new()
	_validity_spinbox.min_value = 1
	_validity_spinbox.max_value = 100
	_validity_spinbox.value = 30
	cert_grid.add_child(_validity_spinbox)

	# First & Last Name
	cert_grid.add_child(_create_field_label("First and Last Name (CN):"))
	_name_input = LineEdit.new()
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.text = "Developer"
	cert_grid.add_child(_name_input)

	# Organization Unit
	cert_grid.add_child(_create_field_label("Organizational Unit (OU):"))
	_org_unit_input = LineEdit.new()
	_org_unit_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_org_unit_input.text = "Games"
	cert_grid.add_child(_org_unit_input)

	# Organization
	cert_grid.add_child(_create_field_label("Organization (O):"))
	_org_input = LineEdit.new()
	_org_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_org_input.text = "Studio"
	cert_grid.add_child(_org_input)

	# City / Locality
	cert_grid.add_child(_create_field_label("City / Locality (L):"))
	_city_input = LineEdit.new()
	_city_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_city_input.text = "City"
	cert_grid.add_child(_city_input)

	# State / Province
	cert_grid.add_child(_create_field_label("State / Province (ST):"))
	_state_input = LineEdit.new()
	_state_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_state_input.text = "State"
	cert_grid.add_child(_state_input)

	# Country Code
	cert_grid.add_child(_create_field_label("Country Code (C, 2-letter):"))
	_country_input = LineEdit.new()
	_country_input.max_length = 2
	_country_input.text = "US"
	cert_grid.add_child(_country_input)

	# Section: Auto-Fill Option
	var opt_box := _create_section(root_vbox, "Preset Automation")
	_apply_preset_checkbox = CheckBox.new()
	_apply_preset_checkbox.text = "Auto-fill credentials into active Android Export Preset (Release Keystore)"
	_apply_preset_checkbox.button_pressed = true
	opt_box.add_child(_apply_preset_checkbox)

	# Action Buttons
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)

	_generate_btn = Button.new()
	_generate_btn.text = "Create Keystore"
	_generate_btn.custom_minimum_size = Vector2(170, 40)
	_generate_btn.pressed.connect(_on_generate_pressed)
	btn_row.add_child(_generate_btn)
	root_vbox.add_child(btn_row)

	# Status Message
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_status_label)

	# Detailed Output Box (Hidden by default, shown if error occurs)
	_output_box = TextEdit.new()
	_output_box.custom_minimum_size = Vector2(0, 100)
	_output_box.editable = false
	_output_box.visible = false
	root_vbox.add_child(_output_box)

func _create_section(parent: Node, title: String) -> VBoxContainer:
	var section_panel := PanelContainer.new()
	section_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	section_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	parent.add_child(section_panel)
	return vbox

func _create_field_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(170, 0)
	return l

func _create_secret_input_row(input: LineEdit) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)

	var toggle_btn := Button.new()
	toggle_btn.text = "👁"
	toggle_btn.tooltip_text = "Show/Hide Password"
	toggle_btn.pressed.connect(func():
		input.secret = not input.secret
	)
	row.add_child(toggle_btn)
	return row

func _update_same_password_state() -> void:
	var is_same: bool = _same_pass_checkbox.button_pressed
	_alias_password_input.editable = not is_same
	_alias_confirm_password_input.editable = not is_same
	if is_same:
		_alias_password_input.text = _keystore_password_input.text
		_alias_confirm_password_input.text = _keystore_confirm_password_input.text

func _on_browse_keytool_pressed() -> void:
	if not _file_dialog:
		_file_dialog = EditorFileDialog.new()
		add_child(_file_dialog)
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["keytool.exe, keytool ; Java Keytool Binary"])
	_file_dialog.file_selected.connect(func(path: String):
		_keytool_path_input.text = path
		_resolved_keytool_path = path
		_keytool_status_label.text = "✓ Keytool selected: " + path
		_keytool_status_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.35))
	, CONNECT_ONE_SHOT)
	_file_dialog.popup_file_dialog()

func _on_browse_keystore_pressed() -> void:
	if not _file_dialog:
		_file_dialog = EditorFileDialog.new()
		add_child(_file_dialog)
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.keystore ; Android Keystore (*.keystore)"])
	_file_dialog.current_file = "my-release-key.keystore"
	_file_dialog.file_selected.connect(func(path: String):
		_keystore_path_input.text = path
	, CONNECT_ONE_SHOT)
	_file_dialog.popup_file_dialog()

func _show_error(msg: String, details: String = "") -> void:
	_status_label.text = "❌ " + msg
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	if not details.is_empty():
		_output_box.text = details
		_output_box.visible = true
	else:
		_output_box.visible = false

func _show_success(msg: String) -> void:
	_status_label.text = "✓ " + msg
	_status_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	_output_box.visible = false

func _on_generate_pressed() -> void:
	var keytool_bin: String = _keytool_path_input.text.strip_edges()
	if keytool_bin.is_empty():
		keytool_bin = _resolved_keytool_path
	if keytool_bin.is_empty() or not FileAccess.file_exists(keytool_bin):
		_show_error("Java keytool binary not found! Please check Java SDK Path in Editor Settings.")
		return

	var ks_path: String = _keystore_path_input.text.strip_edges()
	if ks_path.is_empty():
		_show_error("Please specify a keystore destination path.")
		return

	if not ks_path.ends_with(".keystore"):
		ks_path += ".keystore"
		_keystore_path_input.text = ks_path

	var ks_pass: String = _keystore_password_input.text
	var ks_conf: String = _keystore_confirm_password_input.text
	if ks_pass.length() < 6:
		_show_error("Keystore password must be at least 6 characters.")
		return
	if ks_pass != ks_conf:
		_show_error("Keystore passwords do not match.")
		return

	var alias_name: String = _alias_input.text.strip_edges()
	if alias_name.is_empty():
		_show_error("Please specify a Key Alias name.")
		return

	var alias_pass: String = ks_pass
	if not _same_pass_checkbox.button_pressed:
		alias_pass = _alias_password_input.text
		var alias_conf: String = _alias_confirm_password_input.text
		if alias_pass.length() < 6:
			_show_error("Key password must be at least 6 characters.")
			return
		if alias_pass != alias_conf:
			_show_error("Key passwords do not match.")
			return

	var validity_years: int = int(_validity_spinbox.value)
	var validity_days: int = validity_years * 365

	# Construct DName
	var cn: String = _clean_dname_val(_name_input.text, "Developer")
	var ou: String = _clean_dname_val(_org_unit_input.text, "Games")
	var o: String = _clean_dname_val(_org_input.text, "Studio")
	var l: String = _clean_dname_val(_city_input.text, "City")
	var st: String = _clean_dname_val(_state_input.text, "State")
	var c: String = _clean_dname_val(_country_input.text, "US")

	var dname: String = "CN=%s, OU=%s, O=%s, L=%s, ST=%s, C=%s" % [cn, ou, o, l, st, c]

	# Global path conversion
	var global_ks_path: String = ks_path
	if global_ks_path.begins_with("res://"):
		global_ks_path = ProjectSettings.globalize_path(global_ks_path)
	global_ks_path = global_ks_path.replace("/", "\\")

	# Ensure parent directory exists
	var parent_dir: String = global_ks_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_dir):
		DirAccess.make_dir_recursive_absolute(parent_dir)

	# If file already exists, overwrite cleanly
	if FileAccess.file_exists(global_ks_path):
		var dir = DirAccess.open(parent_dir)
		if dir:
			dir.remove(global_ks_path)

	# Execute keytool
	var args := PackedStringArray([
		"-genkeypair",
		"-v",
		"-keystore", global_ks_path,
		"-alias", alias_name,
		"-keyalg", "RSA",
		"-keysize", "2048",
		"-validity", str(validity_days),
		"-storepass", ks_pass,
		"-keypass", alias_pass,
		"-dname", dname
	])

	var output: Array = []
	var code: int = OS.execute(keytool_bin, args, output, true)
	var output_str: String = "\n".join(output)

	if code != 0 or not FileAccess.file_exists(global_ks_path):
		_show_error("Failed to generate keystore (Exit code %d)." % code, output_str)
		return

	# Auto-fill export presets
	var applied_msg: String = ""
	if _apply_preset_checkbox.button_pressed:
		var apply_ok: bool = _apply_to_export_presets(ks_path, alias_name, alias_pass)
		if apply_ok:
			applied_msg = "\n✓ Automatically applied to Android Export Preset!"

	# Refresh FileSystem in editor
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

	_show_success("Keystore successfully generated at:\n" + ks_path + applied_msg)
	keystore_created.emit(ks_path, alias_name, alias_pass)

func _clean_dname_val(val: String, fallback: String) -> String:
	var clean: String = val.strip_edges().replace(",", " ").replace("\"", "")
	if clean.is_empty():
		return fallback
	return clean

func _apply_to_export_presets(keystore_path: String, alias_name: String, password: String) -> bool:
	var cfg_path: String = "res://export_presets.cfg"
	var config := ConfigFile.new()
	var err: Error = config.load(cfg_path)
	if err != OK:
		return false

	var target_options: String = ""
	for section in config.get_sections():
		if section.ends_with(".options"):
			var base_section: String = section.trim_suffix(".options")
			if config.get_value(base_section, "platform", "") == "Android":
				target_options = section
				break

	if target_options.is_empty():
		if config.has_section("preset.0.options"):
			target_options = "preset.0.options"
		else:
			return false

	config.set_value(target_options, "keystore/release", keystore_path)
	config.set_value(target_options, "keystore/release_user", alias_name)
	config.set_value(target_options, "keystore/release_password", password)
	
	err = config.save(cfg_path)
	return err == OK
