extends Node

signal inventory_changed
signal main_house_door_state_changed(is_unlocked: bool)
signal night_time_changed(elapsed_minutes: int)
signal night_time_expired

const NIGHT_FAILURE_SCREEN = preload("res://scripts/night_failure_screen.gd")
const NIGHT_RETRY_PATH := "res://scenes/ExteriorHouseScene.tscn"
const NIGHT_MENU_PATH := "res://scenes/StartMenu.tscn"
const CHECKPOINT_FILE := "user://investigation_checkpoint.cfg"
const PRESENTATION_SETTINGS_FILE := "user://presentation_settings.cfg"
const CHECKPOINT_VERSION := 1
const WEST_WING_CHECKPOINT := "west_wing"
const DEPARTURE_CHECKPOINT := "west_wing_departure"
const APPROACH_HALL_OBJECTIVE := "前往王氏正堂"
const CHECKPOINT_SCENES := {
	"hall": "res://scenes/InteriorPlaceholder.tscn",
	WEST_WING_CHECKPOINT: "res://scenes/HangingSideRoom.tscn",
	DEPARTURE_CHECKPOINT: "res://scenes/HangingSideRoom.tscn",
}
const CHECKPOINT_FLAGS := [
	"main_house_door_unlocked", "hall_side_door_broken", "study_door_broken",
	"study_genealogy_read", "study_book_dropped", "study_torn_page_found",
	"study_drawer_attempted", "study_drawer_open", "study_letter_read", "study_old_key_taken",
	"study_distant_door_ajar", "sealed_bedroom_unlocked", "bedroom_hairpin_examined",
	"bedroom_mirror_inspected", "bedroom_mirror_uncovered", "bedroom_drawer_open", "bedroom_letter_read",
	"bedroom_mirror_event_seen", "bedroom_hidden_note_found", "bedroom_mirror_warning_played",
	"bedroom_bed_box_open", "bedroom_photo_found", "bedroom_photo_inscription_revealed",
	"bedroom_embroidery_examined", "bedroom_exit_event_done", "bedroom_mirror_recovered",
	"bedroom_identity_confirmed", "final_chapter_started", "final_chapter_objective_revealed",
	"final_chapter_sequence_complete", "final_chapter_rain_restored",
	"main_hall_final_investigation_started", "main_hall_ordinary_tablet_examined",
	"main_hall_wang_chengan_examined", "main_hall_empty_tablet_spot_examined",
	"main_hall_altar_seam_examined", "main_hall_secret_compartment_opened",
	"main_hall_burned_letter_examined", "main_hall_lock_plate_examined",
	"main_hall_rope_segment_examined", "main_hall_confession_read", "main_hall_truth_revealed",
	"main_hall_cry_source_located", "main_hall_pillar_cry_finished", "main_hall_pillar_figure_seen",
	"main_hall_yuelan_footprints_available", "main_hall_yuelan_footprints_examined",
	"yuelan_trail_door_heard", "yuelan_trail_room_reached", "hanging_return_entry_complete",
]

const MAIN_HOUSE_KEY_ID := "main_house_key"
const NIGHT_START_MINUTES := 22 * 60
const NIGHT_LENGTH_MINUTES := 8 * 60
const MARRIAGE_SEASON := "民国十六年秋"
const PHOTO_WEDDING_INSCRIPTION := MARRIAGE_SEASON + "，承安与月兰成婚。"
const ITEM_DEFINITIONS := {
	"wang_warning_talisman": {
		"name": "受潮的禁忌黄纸",
		"category": "文件",
		"description": "从吊绳房间的纸钱间拾得。上半截仍有褪色符纹，下半截写着四句禁忌，最后一句是：‘王氏旧事，不可再问。’",
		"icon": "res://assets/ui/hud_warning_talisman_icon.svg",
		"can_expand": true,
		"document_title": "残 破 黄 符",
		"document_text": "绳下莫立，香灭即退。\n\n子时之后，勿呼其名。\n\n若闻门后有步声，切莫回头。\n\n王氏旧事，不可再问。",
	},
	"old_hammer": {
		"name": "旧木柄铁锤",
		"category": "关键道具",
		"description": "在主堂左回廊的矮桌上找到。锤头已经生锈，木柄尚且结实，可以砸断回廊房门上腐朽的封条。",
		"icon": "res://assets/ui/hud_old_hammer_icon.svg",
	},
	MAIN_HOUSE_KEY_ID: {
		"name": "主屋铜钥匙",
		"category": "关键道具",
		"description": "从左侧厢房供桌旁取得。钥齿沾着潮湿的香灰，能够打开庭院尽头的主屋大门。",
		"icon": "res://assets/ui/hud_old_key_icon.svg",
	},
	"wang_genealogy": {
		"name": "《王氏家谱》",
		"category": "文件",
		"description": "书房桌上的旧式线装家谱。封面受潮起翘，某一代成员的记录被浓墨反复涂毁。",
		"icon": "res://assets/ui/hud_wang_genealogy_icon.svg",
		"can_expand": true,
		"document_title": "王 氏 家 谱",
		"document_text": "王氏第七房录\n\n王承安，生年字迹残缺。\n" + MARRIAGE_SEASON + "，娶妻。\n妻——　　　　\n\n此处姓名并非褪色，\n而是被人以浓墨覆盖后刮去。\n\n页边仅余两个小字：\n\n‘除名。’",
	},
	"torn_genealogy_page": {
		"name": "家谱残页",
		"category": "文件",
		"description": "从掉落书册下发现的残页，纸边与家谱缺口吻合。被删除的人确实曾经存在。",
		"icon": "res://assets/ui/hud_torn_page_icon.svg",
		"can_expand": true,
		"document_title": "残 缺 家 谱 页",
		"document_text": "……氏，生年残缺。\n\n于" + MARRIAGE_SEASON + "入王宅，\n后迁西厢……\n\n子时禁出，族中不得问。\n\n余下姓名与年月，\n已被整块撕去。",
	},
	"old_servant_letter": {
		"name": "无署名旧信",
		"category": "文件",
		"description": "藏在书桌卡死的抽屉里。信纸沾着陈年墨渍，记录与吊绳房说法完全不同的一夜。",
		"icon": "res://assets/ui/hud_old_letter_icon.svg",
		"can_expand": true,
		"document_title": "王 宅 旧 仆 留",
		"document_text": "那夜门从外面锁着。\n\n她一直在里面哭。\n老爷不让我们过去。\n\n第二日天亮，\n他们说她是在梁上自己寻了短见。\n\n可我记得，\n那条绳子前一晚就已经备好了。\n\n若有人后来看到此信，\n莫信他们说的。",
	},
	"study_old_copper_key": {
		"name": "旧铜钥匙",
		"category": "关键道具",
		"description": "一把已经氧化的老宅长柄钥匙，齿口仍然完整。能够打开主大堂右回廊尽头的旧卧房。",
		"icon": "res://assets/ui/hud_study_copper_key_icon.svg",
	},
	"broken_silver_hairpin": {
		"name": "断裂银簪",
		"category": "关键道具",
		"description": "在旧卧房梳妆台上发现的半截旧银簪。簪花仍在，簪身氧化发黑，断口却异常整齐。",
		"icon": "res://assets/ui/hud_broken_hairpin_icon.svg",
	},
	"altar_silver_hairpin_fragment": {
		"name": "银簪残片",
		"category": "关键道具",
		"description": "从王氏正堂供台副暗格中取出的半截旧银簪。簪身受潮发黑，断口形状像是在等待另一半。",
		"icon": "res://assets/ui/hud_broken_hairpin_icon.svg",
	},
	"complete_silver_hairpin": {
		"name": "完整银簪",
		"category": "关键道具",
		"description": "一支完整的旧银簪。\n两截断口完全吻合，证明旧卧房中的断簪与正堂暗格中的残片原本属于同一件物品。",
		"icon": "res://assets/ui/hud_broken_hairpin_icon.svg",
	},
	"bedroom_unsent_letter": {
		"name": "未寄出的信",
		"category": "文件",
		"description": "从梳妆台抽屉里找到。写信的人预先看见西边空房梁上挂好了绳子，最后只留下‘我没有疯’。",
		"icon": "res://assets/ui/hud_old_letter_icon.svg",
		"can_expand": true,
		"document_title": "未 寄 出 的 信",
		"document_text": "阿姐：\n他们不许我再进祠堂。\n老爷说，那几页东西本就不该让我看到。\n昨夜有人在门外站了一整夜，我没有开门。\n今晨他们又让我搬去西边那间空房。\n我不想去。\n那里梁上已经挂好了绳子。\n如果这封信还能送出去，告诉娘——\n我没有疯。\n\n兰",
	},
	"lan_no_register_note": {
		"name": "镜背残纸",
		"category": "文件",
		"description": "封镜背面唯一一张褪色黄符压着的残纸。字很少，却说明有人不愿她留在王氏家谱上。",
		"icon": "res://assets/ui/hud_torn_page_icon.svg",
		"can_expand": true,
		"document_title": "镜 背 残 纸",
		"document_text": "兰娘不得入谱。",
	},
	"scratched_family_photo": {
		"name": "刮损的旧合影",
		"category": "文件",
		"description": "床底木盒中的王家合影。一位女性的脸与身形被刮去，手边却残留着与断裂银簪相似的发饰。",
		"icon": "res://assets/ui/hud_old_photo_icon.svg",
		"document_image": "res://assets/art/bedroom_scratched_photo.png",
		"can_expand": true,
		"document_title": "刮 损 的 合 影",
		"document_text": "王宅旧日合影。\n\n一个人的位置被反复刮损。\n她手边残留的银簪纹样，\n与梳妆台上的断簪几乎一样。\n\n照片背面的墨痕已经受潮，\n似乎还压着一行极淡的旧字。",
	},
	"old_embroidery_cloth": {
		"name": "旧绣布",
		"category": "关键道具",
		"description": "与旧合影一起藏在床底木盒里。翻过常年折叠的布角，背面只残着一个‘沈’字；与合影题记中的‘月兰’正好相合。",
		"icon": "res://assets/ui/hud_old_embroidery_icon.svg",
		"can_expand": true,
		"document_text": "布面受潮发硬，原有的针脚几乎全被拆去。\n\n翻到折角背面，\n只剩一个没有拆净的姓氏：\n\n‘沈’。",
	},
	"wang_chengan_confession": {
		"name": "王承安留下的供词",
		"category": "文件",
		"description": "藏在正堂供台暗格中的手写供词。纸张受潮发脆，墨迹却完整记录了西厢门被锁上的那一夜。",
		"icon": "res://assets/ui/hud_old_letter_icon.svg",
		"can_expand": true,
		"document_text": "月兰发现祠中旧账。\n她执意要将事情告诉外人。\n父亲说，王家的名声不能毁在一个外姓女人手里。\n\n那夜，他们让我备好绳子。\n西厢的门也是我锁的。\n\n第二日，我们只说她疯病发作，自缢而亡。\n\n父亲让我烧掉她留下的信，\n从家谱里划去她的名字，\n也不许为她立位。\n\n可这些年……\n每到子时，\n我仍听见她在门外问：\n\n“为什么不开门？”",
	},
	"burned_yuelan_letter_scraps": {
		"name": "烧残的旧信",
		"category": "关键道具",
		"description": "暗格里整齐叠放的焦黑纸片。残存笔迹与月兰未寄出的信相同，说明有人按命令焚毁了她留下的话。",
		"icon": "res://assets/ui/hud_torn_page_icon.svg",
	},
	"west_wing_old_lock_plate": {
		"name": "西厢旧锁扣",
		"category": "关键道具",
		"description": "从供台暗格中取出的旧铜锁扣。内侧磨痕与西厢门锁的位置吻合，锁舌曾从外侧反复开合。",
		"icon": "res://assets/ui/hud_study_copper_key_icon.svg",
	},
	"old_hemp_rope_segment": {
		"name": "旧麻绳残段",
		"category": "关键道具",
		"description": "从王氏正堂暗格中找到的一截旧麻绳。\n与西厢房梁上的麻绳材质一致。",
		"icon": "res://assets/ui/hud_rope_fragment_icon.svg",
	},
}

var inventory: Dictionary = {}
var completed_documents: Dictionary = {}
var night_elapsed_minutes := 0
var night_clock_running := false
var night_clock_remainder := 0.0
var night_timed_out := false
var night_failure_screen: CanvasLayer
var night_clock_holds: Dictionary = {}
var dawn_warning_shown := false
var flashlight_enabled := true
var reduced_flashes := false
var ambience_volume := 1.0
var thunder_volume := 1.0
var main_house_door_unlocked := false
var hall_side_door_broken := false
var return_to_hall_side_door := false
var study_door_broken := false
var return_to_hall_study_door := false
var study_genealogy_read := false
var study_book_dropped := false
var study_torn_page_found := false
var study_drawer_attempted := false
var study_drawer_open := false
var study_letter_read := false
var study_old_key_taken := false
var study_distant_door_ajar := false
var sealed_bedroom_unlocked := false
var return_to_hall_sealed_door := false
var bedroom_hairpin_examined := false
var bedroom_mirror_inspected := false
var bedroom_mirror_uncovered := false
var bedroom_drawer_open := false
var bedroom_letter_read := false
var bedroom_mirror_event_seen := false
var bedroom_hidden_note_found := false
var bedroom_mirror_warning_played := false
var bedroom_bed_box_open := false
var bedroom_photo_found := false
var bedroom_photo_inscription_revealed := false
var bedroom_photo_inspections := 0
var bedroom_embroidery_examined := false
var bedroom_exit_event_done := false
var bedroom_mirror_recovered := false
var bedroom_identity_confirmed := false
var final_chapter_started := false
var final_chapter_objective_revealed := false
var final_chapter_sequence_complete := false
var final_chapter_rain_restored := false
var main_hall_final_investigation_started := false
var main_hall_ordinary_tablet_examined := false
var main_hall_wang_chengan_examined := false
var main_hall_empty_tablet_spot_examined := false
var main_hall_altar_seam_examined := false
var main_hall_secret_compartment_opened := false
var main_hall_burned_letter_examined := false
var main_hall_lock_plate_examined := false
var main_hall_rope_segment_examined := false
var main_hall_confession_read := false
var main_hall_truth_revealed := false
var main_hall_cry_source_located := false
var main_hall_pillar_cry_finished := false
var main_hall_pillar_figure_seen := false
var main_hall_yuelan_footprints_available := false
var main_hall_yuelan_footprints_examined := false
var yuelan_trail_door_heard := false
var yuelan_trail_room_reached := false
var hanging_return_entry_complete := false
var hanging_return_rope_examined := false
var hanging_return_stool_examined := false
var hanging_return_final_sob_complete := false
enum HangingDoorStage { WAITING, PLAYING, INSPECT, OPEN, LATCH, AFTERMATH, COMPLETE }
var hanging_door_stage: HangingDoorStage = HangingDoorStage.WAITING
enum HangingTruthStage { ARRIVAL, INVESTIGATING, REVIEW, SOB, RESPONSE, READY }
var hanging_truth_stage: HangingTruthStage = HangingTruthStage.ARRIVAL
var hanging_truth_resume_beat := 0
enum HangingCodaStage { WAITING, PLAYING, COMPLETE }
const HANGING_CODA_OBJECTIVE := "在吊绳下留下真相"
const RETURN_HOME_OBJECTIVE := "带着真相离开王宅"
var hanging_coda_stage: HangingCodaStage = HangingCodaStage.WAITING
var hanging_coda_beat := 0
var hanging_coda_rope_down := false
var hanging_coda_yuelan_seen := false
var return_to_courtyard_from_hall := false
var return_to_courtyard_from_left_wing := false
enum WangEstateExitStage { WAITING, DEPARTING, COMPLETE }
var wang_estate_exit_stage := WangEstateExitStage.WAITING
var wang_estate_last_look_seen := false
var yuelan_trail_fade_seconds := -1.0

func can_place_final_confession() -> bool:
	return hanging_coda_stage == HangingCodaStage.WAITING \
		and hanging_door_stage == HangingDoorStage.COMPLETE \
		and hanging_truth_stage == HangingTruthStage.READY \
		and hanging_return_rope_examined and hanging_return_stool_examined \
		and has_item("wang_chengan_confession") \
		and (has_completed_document("wang_chengan_confession") or main_hall_confession_read)

func has_hanging_coda_completed() -> bool:
	return hanging_coda_stage == HangingCodaStage.COMPLETE


func can_leave_wang_estate() -> bool:
	return has_hanging_coda_completed() and wang_estate_exit_stage == WangEstateExitStage.WAITING \
		and not night_timed_out and night_elapsed_minutes < NIGHT_LENGTH_MINUTES


func try_begin_wang_estate_departure() -> bool:
	if not can_leave_wang_estate():
		return false
	# The player met the deadline before handing control to the exit cutscene.
	wang_estate_exit_stage = WangEstateExitStage.DEPARTING
	stop_night_clock()
	return true


func begin_yuelan_trail_fade() -> void:
	if has_hanging_coda_completed() and yuelan_trail_fade_seconds < 0.0:
		yuelan_trail_fade_seconds = 0.0


func preserve_final_evidence() -> void:
	# The offering is a display prop. Only recover a missing confession when
	# the existing reading record proves the player already acquired it.
	if main_hall_confession_read or has_completed_document("wang_chengan_confession"):
		add_item("wang_chengan_confession")
	# The optional hairpin never leaves inventory during the offering.

func hanging_door_objective() -> String:
	if has_hanging_coda_completed():
		return RETURN_HOME_OBJECTIVE
	match hanging_door_stage:
		HangingDoorStage.INSPECT: return "调查西厢房门"
		HangingDoorStage.OPEN, HangingDoorStage.LATCH, HangingDoorStage.AFTERMATH: return "调查房门外侧的旧门闩"
		HangingDoorStage.COMPLETE:
			return HANGING_CODA_OBJECTIVE if hanging_truth_stage == HangingTruthStage.READY else "还原当年的真相"
		_: return ""


func estate_investigation_objective() -> String:
	var west_wing_objective := hanging_door_objective()
	if not west_wing_objective.is_empty():
		return west_wing_objective
	if yuelan_trail_room_reached:
		return "调查吊绳房的异常"
	if main_hall_yuelan_footprints_examined:
		return "沿着脚印寻找女人"
	if main_hall_yuelan_footprints_available:
		return "调查木柱旁的潮湿脚印"
	if main_hall_truth_revealed:
		return "王氏旧事的真相已经揭开" if main_hall_pillar_figure_seen else "寻找正堂中哭声的来源"
	if main_hall_secret_compartment_opened:
		return "查看暗格中的供词"
	if main_hall_altar_seam_examined:
		return "调查供台下方"
	if bedroom_identity_confirmed:
		return "调查王氏正堂"
	return ""


func _ready() -> void:
	var file := ConfigFile.new()
	if file.load(PRESENTATION_SETTINGS_FILE) == OK:
		reduced_flashes = file.get_value("accessibility", "reduced_flashes", false) == true
		ambience_volume = clampf(float(file.get_value("audio", "ambience", 1.0)), 0.0, 1.0)
		thunder_volume = clampf(float(file.get_value("audio", "thunder", 1.0)), 0.0, 1.0)
	_apply_mix_levels()


func apply_presentation_settings(ambience: float, thunder: float, reduce_flashes: bool) -> void:
	ambience_volume = ambience
	thunder_volume = thunder
	reduced_flashes = reduce_flashes
	_apply_mix_levels()
	var file := ConfigFile.new()
	file.set_value("accessibility", "reduced_flashes", reduced_flashes)
	file.set_value("audio", "ambience", ambience_volume)
	file.set_value("audio", "thunder", thunder_volume)
	file.save(PRESENTATION_SETTINGS_FILE)


func _apply_mix_levels() -> void:
	for channel in [["Ambience", ambience_volume], ["Thunder", thunder_volume]]:
		var index := AudioServer.get_bus_index(channel[0])
		if index >= 0:
			var gain: float = channel[1]
			AudioServer.set_bus_mute(index, gain <= 0.0)
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(gain, 0.0001)))


func _process(delta: float) -> void:
	advance_night_clock(delta)
	if yuelan_trail_fade_seconds >= 0.0 and yuelan_trail_fade_seconds < 14.0:
		yuelan_trail_fade_seconds = minf(14.0, yuelan_trail_fade_seconds + delta)


func start_night_clock() -> void:
	night_clock_running = not night_timed_out and night_elapsed_minutes < NIGHT_LENGTH_MINUTES \
		and wang_estate_exit_stage == WangEstateExitStage.WAITING


func stop_night_clock() -> void:
	night_clock_running = false


func set_night_clock_hold(owner: Node, held: bool) -> void:
	if held:
		night_clock_holds[owner.get_instance_id()] = weakref(owner)
	else:
		night_clock_holds.erase(owner.get_instance_id())


func advance_night_clock(real_seconds: float) -> void:
	if not night_clock_running or real_seconds <= 0.0:
		return
	for key in night_clock_holds.keys():
		var holder := (night_clock_holds[key] as WeakRef).get_ref() as Node
		if holder != null and holder.is_inside_tree():
			return
		night_clock_holds.erase(key)
	night_clock_remainder += real_seconds
	var whole_minutes := int(floor(night_clock_remainder))
	if whole_minutes < 1:
		return
	night_clock_remainder -= whole_minutes
	night_elapsed_minutes = mini(night_elapsed_minutes + whole_minutes, NIGHT_LENGTH_MINUTES)
	if night_elapsed_minutes == NIGHT_LENGTH_MINUTES:
		night_clock_running = false
		night_clock_remainder = 0.0
	night_time_changed.emit(night_elapsed_minutes)
	if night_elapsed_minutes == NIGHT_LENGTH_MINUTES and not night_timed_out:
		_expire_night()


func _expire_night() -> void:
	if wang_estate_exit_stage != WangEstateExitStage.WAITING:
		return
	night_timed_out = true
	night_time_expired.emit()
	var host := get_tree().current_scene
	if host == null:
		return
	var gameplay := host.get("current_scene") as Node if "current_scene" in host else host
	if gameplay != null:
		# The HUD receives inventory input even when the tree is paused.
		for control in gameplay.find_children("*", "Control", true, false):
			var script := control.get_script() as Script
			if script != null and script.resource_path == "res://scripts/exterior_hud.gd":
				control.set_process_input(false)
	night_failure_screen = NIGHT_FAILURE_SCREEN.new()
	night_failure_screen.name = "NightTimeout"
	add_child(night_failure_screen)
	night_failure_screen.action_chosen.connect(_leave_night_failure)
	get_tree().paused = true


func _leave_night_failure(retry: bool) -> void:
	var host := get_tree().current_scene
	night_failure_screen.queue_free()
	night_failure_screen = null
	get_tree().paused = false
	var path := NIGHT_RETRY_PATH if retry else NIGHT_MENU_PATH
	if retry:
		var checkpoint_path := restore_checkpoint()
		if checkpoint_path.is_empty():
			reset_run()
		else:
			path = checkpoint_path
	if host != null and host.has_method("change_scene"):
		host.call("change_scene", path)
	else:
		get_tree().change_scene_to_file(path)


func save_checkpoint(anchor: String) -> void:
	if not CHECKPOINT_SCENES.has(anchor) or night_timed_out:
		return
	if not final_chapter_sequence_complete:
		return
	if anchor in [WEST_WING_CHECKPOINT, DEPARTURE_CHECKPOINT] and (not hanging_return_entry_complete or not main_hall_confession_read):
		return
	if anchor == DEPARTURE_CHECKPOINT and not (
		can_leave_wang_estate() and hanging_coda_rope_down
		and hanging_door_stage == HangingDoorStage.COMPLETE and hanging_truth_stage == HangingTruthStage.READY
		and hanging_return_rope_examined and hanging_return_stool_examined
		and has_item("wang_chengan_confession")
	):
		return
	var file := ConfigFile.new()
	file.set_value("checkpoint", "version", CHECKPOINT_VERSION)
	file.set_value("checkpoint", "anchor", anchor)
	file.set_value("checkpoint", "inventory", inventory.keys())
	file.set_value("checkpoint", "documents", completed_documents.keys())
	# Resume with at least 90 playable seconds. This does not change the live run.
	file.set_value("checkpoint", "minutes", mini(night_elapsed_minutes, NIGHT_LENGTH_MINUTES - 90))
	file.set_value("checkpoint", "photo_inspections", bedroom_photo_inspections)
	file.set_value("checkpoint", "flashlight", flashlight_enabled)
	for flag in CHECKPOINT_FLAGS:
		file.set_value("progress", flag, get(flag))
	var error := file.save(CHECKPOINT_FILE)
	if error != OK:
		push_warning("Could not save the investigation checkpoint: %s" % error_string(error))


func _load_checkpoint() -> ConfigFile:
	var file := ConfigFile.new()
	if file.load(CHECKPOINT_FILE) != OK or file.get_value("checkpoint", "version", 0) != CHECKPOINT_VERSION:
		return null
	var anchor := str(file.get_value("checkpoint", "anchor", ""))
	if not CHECKPOINT_SCENES.has(anchor) or file.get_value("progress", "final_chapter_sequence_complete", false) != true:
		return null
	if anchor in [WEST_WING_CHECKPOINT, DEPARTURE_CHECKPOINT] and (
		file.get_value("progress", "hanging_return_entry_complete", false) != true
		or file.get_value("progress", "main_hall_confession_read", false) != true
	):
		return null
	for field in ["inventory", "documents"]:
		if not file.get_value("checkpoint", field, []) is Array:
			return null
	if anchor == DEPARTURE_CHECKPOINT and not ("wang_chengan_confession" in file.get_value("checkpoint", "inventory", [])):
		return null
	return file


func has_checkpoint() -> bool:
	return _load_checkpoint() != null


func restore_checkpoint() -> String:
	var file := _load_checkpoint()
	if file == null:
		return ""
	var anchor := str(file.get_value("checkpoint", "anchor"))
	reset_run()
	for flag in CHECKPOINT_FLAGS:
		set(flag, file.get_value("progress", flag, false) == true)
	for item_id in file.get_value("checkpoint", "inventory", []):
		if item_id is String and ITEM_DEFINITIONS.has(item_id):
			inventory[item_id] = true
	for item_id in file.get_value("checkpoint", "documents", []):
		if item_id is String and inventory.has(item_id):
			completed_documents[item_id] = true
	if anchor == DEPARTURE_CHECKPOINT:
		# This milestone resumes after the farewell, never inside its cutscene.
		hanging_door_stage = HangingDoorStage.COMPLETE
		hanging_truth_stage = HangingTruthStage.READY
		hanging_return_rope_examined = true
		hanging_return_stool_examined = true
		hanging_return_final_sob_complete = true
		hanging_coda_stage = HangingCodaStage.COMPLETE
		hanging_coda_rope_down = true
		hanging_coda_yuelan_seen = true
	bedroom_photo_inspections = clampi(int(file.get_value("checkpoint", "photo_inspections", 0)), 0, 3)
	flashlight_enabled = file.get_value("checkpoint", "flashlight", true) == true
	night_elapsed_minutes = clampi(int(file.get_value("checkpoint", "minutes", 0)), 0, NIGHT_LENGTH_MINUTES - 90)
	night_time_changed.emit(night_elapsed_minutes)
	inventory_changed.emit()
	main_house_door_state_changed.emit(main_house_door_unlocked)
	return CHECKPOINT_SCENES[anchor]


func clear_checkpoint() -> void:
	if FileAccess.file_exists(CHECKPOINT_FILE):
		DirAccess.remove_absolute(CHECKPOINT_FILE)


func get_night_time_text() -> String:
	var clock_minutes := (NIGHT_START_MINUTES + night_elapsed_minutes) % (24 * 60)
	return "%02d:%02d" % [clock_minutes / 60, clock_minutes % 60]


func is_after_midnight() -> bool:
	return night_elapsed_minutes >= 120


func mark_document_completed(item_id: String) -> void:
	if has_item(item_id):
		completed_documents[item_id] = true


func has_completed_document(item_id: String) -> bool:
	return completed_documents.has(item_id)


func break_hall_side_door() -> bool:
	if not has_item("old_hammer"):
		return false
	hall_side_door_broken = true
	return true


func break_study_door() -> bool:
	if not has_item("old_hammer"):
		return false
	study_door_broken = true
	return true


func unlock_sealed_bedroom() -> bool:
	if sealed_bedroom_unlocked:
		return true
	if not has_item("study_old_copper_key"):
		return false
	sealed_bedroom_unlocked = true
	return true


func add_item(item_id: String) -> bool:
	if not ITEM_DEFINITIONS.has(item_id) or inventory.has(item_id):
		return false
	if item_id in ["broken_silver_hairpin", "altar_silver_hairpin_fragment"] \
		and inventory.has("complete_silver_hairpin"):
		return false
	inventory[item_id] = true
	_try_merge_silver_hairpin()
	inventory_changed.emit()
	return true


func _try_merge_silver_hairpin() -> bool:
	if not inventory.has("broken_silver_hairpin") \
		or not inventory.has("altar_silver_hairpin_fragment"):
		return false
	inventory.erase("broken_silver_hairpin")
	inventory.erase("altar_silver_hairpin_fragment")
	inventory["complete_silver_hairpin"] = true
	return true


func has_item(item_id: String) -> bool:
	return inventory.has(item_id)


func can_unlock_main_house() -> bool:
	return main_house_door_unlocked or has_item(MAIN_HOUSE_KEY_ID)


func unlock_main_house() -> bool:
	if main_house_door_unlocked:
		return true
	if not has_item(MAIN_HOUSE_KEY_ID):
		return false
	main_house_door_unlocked = true
	main_house_door_state_changed.emit(true)
	return true


func is_main_house_door_unlocked() -> bool:
	return main_house_door_unlocked


func get_item_definition(item_id: String) -> Dictionary:
	return ITEM_DEFINITIONS.get(item_id, {}) as Dictionary


func get_inventory_items() -> Array[String]:
	var items: Array[String] = []
	for item_id in inventory.keys():
		items.append(str(item_id))
	return items


func clear_inventory() -> void:
	inventory.clear()
	inventory_changed.emit()


func reset_run() -> void:
	inventory.clear()
	completed_documents.clear()
	night_elapsed_minutes = 0
	night_clock_remainder = 0.0
	night_clock_running = false
	night_timed_out = false
	night_clock_holds.clear()
	dawn_warning_shown = false
	flashlight_enabled = true
	night_time_changed.emit(night_elapsed_minutes)
	hall_side_door_broken = false
	return_to_hall_side_door = false
	study_door_broken = false
	return_to_hall_study_door = false
	study_genealogy_read = false
	study_book_dropped = false
	study_torn_page_found = false
	study_drawer_attempted = false
	study_drawer_open = false
	study_letter_read = false
	study_old_key_taken = false
	study_distant_door_ajar = false
	sealed_bedroom_unlocked = false
	return_to_hall_sealed_door = false
	bedroom_hairpin_examined = false
	bedroom_mirror_inspected = false
	bedroom_mirror_uncovered = false
	bedroom_drawer_open = false
	bedroom_letter_read = false
	bedroom_mirror_event_seen = false
	bedroom_hidden_note_found = false
	bedroom_mirror_warning_played = false
	bedroom_bed_box_open = false
	bedroom_photo_found = false
	bedroom_photo_inscription_revealed = false
	bedroom_photo_inspections = 0
	bedroom_embroidery_examined = false
	bedroom_exit_event_done = false
	bedroom_mirror_recovered = false
	bedroom_identity_confirmed = false
	final_chapter_started = false
	final_chapter_objective_revealed = false
	final_chapter_sequence_complete = false
	final_chapter_rain_restored = false
	main_hall_final_investigation_started = false
	main_hall_ordinary_tablet_examined = false
	main_hall_wang_chengan_examined = false
	main_hall_empty_tablet_spot_examined = false
	main_hall_altar_seam_examined = false
	main_hall_secret_compartment_opened = false
	main_hall_burned_letter_examined = false
	main_hall_lock_plate_examined = false
	main_hall_rope_segment_examined = false
	main_hall_confession_read = false
	main_hall_truth_revealed = false
	main_hall_cry_source_located = false
	main_hall_pillar_cry_finished = false
	main_hall_pillar_figure_seen = false
	main_hall_yuelan_footprints_available = false
	main_hall_yuelan_footprints_examined = false
	yuelan_trail_door_heard = false
	yuelan_trail_room_reached = false
	hanging_return_entry_complete = false
	hanging_return_rope_examined = false
	hanging_return_stool_examined = false
	hanging_return_final_sob_complete = false
	hanging_door_stage = HangingDoorStage.WAITING
	hanging_truth_stage = HangingTruthStage.ARRIVAL
	hanging_truth_resume_beat = 0
	hanging_coda_stage = HangingCodaStage.WAITING
	hanging_coda_beat = 0
	hanging_coda_rope_down = false
	hanging_coda_yuelan_seen = false
	return_to_courtyard_from_hall = false
	return_to_courtyard_from_left_wing = false
	wang_estate_exit_stage = WangEstateExitStage.WAITING
	wang_estate_last_look_seen = false
	yuelan_trail_fade_seconds = -1.0
	main_house_door_unlocked = false
	inventory_changed.emit()
	main_house_door_state_changed.emit(false)
