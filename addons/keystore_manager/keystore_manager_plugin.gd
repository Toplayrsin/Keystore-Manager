@tool
extends EditorPlugin

const KeystorePanelScript = preload("res://addons/keystore_manager/keystore_panel.gd")

var _popup_dialog: AcceptDialog = null
var _export_tab_panel: Control = null
var _poll_timer: Timer = null

func _enter_tree() -> void:
	# Add shortcut under Project > Tools / Editor Tools menu
	add_tool_menu_item("Android Keystore Manager", _open_standalone_dialog)
	
	# Start polling for Export dialog
	_setup_export_dialog_detector()

func _exit_tree() -> void:
	remove_tool_menu_item("Android Keystore Manager")
	
	if _poll_timer:
		_poll_timer.stop()
		_poll_timer.queue_free()
		_poll_timer = null
		
	if _export_tab_panel and is_instance_valid(_export_tab_panel):
		_export_tab_panel.queue_free()
		_export_tab_panel = null

	if _popup_dialog and is_instance_valid(_popup_dialog):
		_popup_dialog.queue_free()
		_popup_dialog = null

func _setup_export_dialog_detector() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = 0.8
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_check_export_dialog)
	add_child(_poll_timer)
	_check_export_dialog()

func _check_export_dialog() -> void:
	var base = EditorInterface.get_base_control()
	if not base:
		return

	# Search in base control tree and windows
	var tab_container = _find_export_tab_container(base)
	if not tab_container:
		# Also check root windows in case it is an unparented Window
		var root = base.get_tree().root
		tab_container = _find_export_tab_container(root)

	if tab_container:
		if not tab_container.has_node("Keystore"):
			_export_tab_panel = KeystorePanelScript.new()
			_export_tab_panel.name = "Keystore"
			tab_container.add_child(_export_tab_panel)

func _find_export_tab_container(node: Node) -> TabContainer:
	if node is TabContainer:
		var has_options = false
		var has_scripts = false
		for i in node.get_tab_count():
			var title = node.get_tab_title(i)
			if title == "Options":
				has_options = true
			elif title == "Scripts":
				has_scripts = true
		if has_options and has_scripts:
			return node

	for child in node.get_children():
		var res = _find_export_tab_container(child)
		if res:
			return res
	return null

func _open_standalone_dialog() -> void:
	if not _popup_dialog or not is_instance_valid(_popup_dialog):
		_popup_dialog = AcceptDialog.new()
		_popup_dialog.title = "Android Keystore Manager"
		_popup_dialog.size = Vector2i(540, 700)
		_popup_dialog.unresizable = false
		_popup_dialog.ok_button_text = "Close"
		
		var panel = KeystorePanelScript.new()
		panel.name = "Panel"
		_popup_dialog.add_child(panel)
		
		EditorInterface.get_base_control().add_child(_popup_dialog)
		
	_popup_dialog.popup_centered()

