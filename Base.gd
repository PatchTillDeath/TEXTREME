extends CanvasLayer

#visual effects for keypresses. Change exported variables in the inspector or else it wont work
export var keyoffother = 2
export var keyoffspace = 4
export var keyoffenter = 8
export var keyoffdelete = 4

export var keytimeother = 0.1
export var keytimespace = 0.2
export var keytimeenter = 0.4
export var keytimedelete = 0.2

export var flashtimeother = 0.1
export var flashtimespace = 0.2
export var flashtimeenter = 0.4
export var flashtimedelete = 0.2

#charactersize in pixels. If you use a non monospace font the locateCursor() function wont work at all
export var charsize = Vector2(8.0, 8.0)

#no toucch
var lineafter = ""
var lastlineheight = 0
var linebefore = ""
var y_was = 0
var queue_check = false
#basic colors for misc use. the only really important ones are black and white
const cyan = Color(0,1,1,1)
const magenta = Color(1,0,1,1)
const black = Color(0,0,0,1)
const white = Color(1,1,1,1)

#array of colors the screen can flash in, feel free to add more
var colors = ["cyan","magenta","orchid", "pink", "orangered", "dodgerblue", "orange", "turquoise", "violet", "teal"]

var savename = ""
var saved = false

onready var TextEditWindow = $UIBase/TextEdit
onready var LoadDialog = $UIBase/LoadDialog
onready var SaveDialog = $UIBase/SaveDialog
onready var StartTextPosition = $StartTextPosition

### Utility functions
## File Operations
func mkPath(a, b, c = "", d = ""):
	if c == "" and d == "":
		return a + "/" + b
	elif c != "" and d == "":
		return  a + "/" + b + "/" + c
	else:
		return a + "/" + b + "/" + c + "/" + d

#runs on boot up, basic setup
func _ready():
	TextEditWindow.grab_focus()
	loadSyntax()

#runs every frame
func _process(delta):
	if queue_check:
		lineafter = TextEditWindow.get_line(TextEditWindow.cursor_get_line())
		var removed = what_removed(linebefore)
		if(removed != ""):
			typejerk("delete")
			spawnLetter(locateCursor(), removed)
		analyzeInput(whatAdded(linebefore))
		queue_check = false
		linebefore = lineafter
	
	$StartTextPosition/Cursor.position = locateCursor()
	
	var cursorpos = Vector2(TextEditWindow.cursor_get_column()-TextEditWindow.get_child(0).value/charsize.x,TextEditWindow.cursor_get_line()-TextEditWindow.get_child(1).value)
	y_was = TextEditWindow.cursor_get_line()

func getColor(idx):
	return ColorN(colors[idx], 1)

func getRandomColor():
	return ColorN(colors[randi()%colors.size()], 1)

#loads syntax from file, replace the "/syntax.txt" by any other file name with syntax in it
#if you dont want the user to acces this file add it to the games folder and replace the OS.get_exec.. with a "res://" then add filename
func loadSyntax():
	var info = File.new()
	
	var baseExecFolder = OS.get_executable_path().get_base_dir()
	
	#In-editor load from project folder
	if OS.has_feature("debug"):
		baseExecFolder = "res://TEXTREME"
	
	info.open(mkPath(baseExecFolder, "syntax.txt"), info.READ)
	
	if !info.is_open():
		printerr("Failed to load custom syntax!")
		TextEditWindow.text = "Failed to load custom syntax!"
		return
	
	var infoarray = info.get_csv_line()
	
	# Clearly what he intended, also makes sense and fixes the debugger error!
	while not info.eof_reached():
		
		if infoarray.size() >= 2:
			TextEditWindow.add_keyword_color(infoarray[0], ColorN(infoarray[1],1))
		infoarray = info.get_csv_line()
	
	# CPP comment support.
	# Color info: https://docs.godotengine.org/uk/latest/classes/class_color.html#class-color
	TextEditWindow.add_color_region("/*", "*/", Color( 0.54, 0.17, 0.89, 1 ), false)
	TextEditWindow.add_color_region("//", "",   Color( 0.54, 0.17, 0.89, 1 ), true)
	
	# Clean up file resource, you should close this.
	info.close()


func _on_Load_pressed():
	LoadDialog.popup_centered()
	LoadDialog.get_node("LineEdit").grab_focus()

#saves given text to a given file
func save(text,fname):
	savename = fname
	var file = File.new()
	
	var baseFolder = mkPath(OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), "TEXTREME")
	
	Directory.new().make_dir(baseFolder)
	
	file.open(mkPath(baseFolder, fname + ".txt"), file.WRITE)
	
	if !file.is_open():
		printerr("Failed to save the file!")
		return
	
	file.store_string(text)
	file.close()

func lload(fname):
	var file = File.new()
	
	var baseFolder = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS) + "/TEXTREME"
	
	file.open(mkPath(baseFolder, fname + ".txt"), file.READ)
	var content = file.get_as_text()
	
	if !file.is_open():
		printerr("Failed to open the file!")
		return "Failed to open the file!"
	
	file.close()
	return content

#When save dialog is confirmed
func _on_SaveButton_pressed():
	SaveDialog.hide()
	savename = SaveDialog.get_node("LineEdit").text
	save(TextEditWindow.text, savename)
	saved = true
	TextEditWindow.grab_focus()

func _on_Save_AS_pressed():
	SaveDialog.popup_centered()
	SaveDialog.get_node("LineEdit").grab_focus()


func _on_Save_pressed():
	if saved:
		save(TextEditWindow.text,savename)
	else:
		SaveDialog.popup_centered()
		SaveDialog.get_node("LineEdit").grab_focus()

#When load dialog is confirmed
func _on_LoadButton_pressed():
	TextEditWindow.text = lload(LoadDialog.get_node("LineEdit").text)
	LoadDialog.hide()
	TextEditWindow.grab_focus()


func process_key(recoilAngle, keytime, keyoff, flashcolor, flashtime, sound, soundVolume, funcname, cursoroffset=Vector2()):
	$EffectManager.recoil(Vector2(1,0).rotated(recoilAngle),keytime,keyoff)
	$EffectManager.flash(flashcolor,black,flashtime)
	sound.volume_db = soundVolume
	sound.play()
	
	if funcname != "nofunc":
		funcref(self, funcname).call_func(locateCursor()+cursoroffset)

#Function used to organize all buttonpress effects, receives the name of the effect, then executes it
func typejerk(type):
	match type:
		"other":
			process_key(rand_range(0,TAU), keytimeother, keyoffother, 
						getRandomColor(), flashtimeother, $Keystroke, -8, "spawnSparks")
		"space":
			process_key(rand_range(0,TAU), keytimespace, keyoffspace, 
						getRandomColor(), flashtimespace, $Keystroke, -5, "nofunc")
		"enter":
			process_key(rand_range(-PI*0.25,PI*0.25), keytimeenter, keyoffenter, 
						getColor(6), flashtimeenter, $Ding, -5, "spawnFlash")
		"delete":
			process_key(rand_range(-PI*0.25,PI*0.25)+PI/2, keytimedelete, keyoffdelete, 
						getRandomColor(), flashtimedelete, $Keystroke, -8, "nofunc", charsize*Vector2(1,0))
		"repeat":
			process_key(rand_range(0,TAU), 0.05, 1, 
						getRandomColor(), 0.05, $Keystroke, -15, "spawnSparks")
		"dot":
			process_key(0.1,0.05,5, 
						getRandomColor(),0.2, $Keystroke, 0, "spawnDotEffects")
		"dash":
			process_key(rand_range(-PI*0.25,PI*0.25)-PI*0.5, 0.2, 4, 
						getRandomColor(), 0.2, $Keystroke, -5, "spawnDashEffects")
		"exclamation":
			process_key(0.2,0.05,8, 
						getRandomColor(), 0.2, $Keystroke, 0, "spawnExclamation")
		"question":
			process_key(0.2,0.05,8, 
						getRandomColor(), 0.2, $Keystroke, 0, "spawnQuestion")

#input handler, all events are read top to bottom, please avoid triggering 2 effects in a single frame
#btw, no adequate human types 2 characters per frame, dont worry about it
#custom names for keys presses or combos of such are made in [project > input map]
func _input(event):
	if (event is InputEventKey && event.pressed && TextEditWindow.has_focus()):
		if event.is_action("enter"):
			typejerk("enter")
		else:
			queue_check = true

func analyzeInput(input):
	if input != "":
		match input:
			".": typejerk("dot")
			"-": typejerk("dash")
			"!": typejerk("exclamation")
			"?": typejerk("question")
			" ": typejerk("space")
			_: typejerk("other")

# The previous locate cursor was not impervious from being tricked with tabs
# Neither is this, but it is far less intensive for minimal accuracy tradeoff
# Note to future self, for more accuracy tally the tabs and then shift pos by
# fixed formula
func locateCursor():
	var cursorpos = Vector2(9 * TextEditWindow.cursor_get_column(), 13 * TextEditWindow.cursor_get_line())
	var linetext = TextEditWindow.get_line(TextEditWindow.cursor_get_line())
	
	linetext = linetext.left(TextEditWindow.cursor_get_column())

	#"\t" is basically TAB, this is a fix that counts tab as 4 characters instead of 1
	while linetext.find("\t", 0) != -1:
		linetext.erase(linetext.find("\t", 0), 1)
		cursorpos.x += 27 # 9 * 3, since 1 character = 9, and so tab = 4 (minus 1)

	return cursorpos

#to keep the effects function clean and neat all of the function that spawn in a node with and effects are stored here

func spawnFlash(position):
	var flash = preload("res://Effects/flash.tscn").instance()
	StartTextPosition.add_child(flash);
	position.y += charsize.y*1.5
	flash.rect_size.x = StartTextPosition.global_position.x + $UIBase.rect_size.x
	flash.rect_position.y = position.y - StartTextPosition.global_position.y
	flash.rect_position.x = -StartTextPosition.global_position.x

func spawnSparks(position):
	var sparkler = preload("res://Effects/sparkler.tscn").instance()
	StartTextPosition.add_child(sparkler)
	position.x += charsize.x*1.5
	position.y += charsize.y
	sparkler.global_position = position + StartTextPosition.global_position

func spawnDotEffects(position):
	var explosion = preload("res://Effects/dot.tscn").instance()
	StartTextPosition.add_child(explosion)
	position.y += charsize.y*0.75
	position.x += charsize.x*0.5
	explosion.global_position = position + StartTextPosition.global_position

func spawnDashEffects(position):
	var dash = preload("res://Effects/dash.tscn").instance()
	StartTextPosition.add_child(dash)
	position.y += charsize.y*0.5
	position.x += charsize.x*0.5
	dash.global_position = position + StartTextPosition.global_position

func spawnExclamation(position):
	var exclamation = preload("res://Effects/exclamationmark.tscn").instance()
	StartTextPosition.add_child(exclamation)
	position.y += charsize.y*0.5
	position.x += charsize.x*0.5
	exclamation.global_position = position + StartTextPosition.global_position

func spawnQuestion(position):
	var question = preload("res://Effects/questionmark.tscn").instance()
	StartTextPosition.add_child(question)
	position.y += charsize.y*0.5
	position.x += charsize.x*0.5
	question.global_position = position + StartTextPosition.global_position

func spawnLetter(position, text):
	var cross = preload("res://Effects/cross.tscn").instance()
	StartTextPosition.add_child(cross)
	position.y += charsize.y*0.5
	position.x += -charsize.x*0.5
	cross.letter = text
	cross.global_position = position + StartTextPosition.global_position

func whatAdded(linebefore):
	var cursorpos = Vector2(TextEditWindow.cursor_get_column()-TextEditWindow.get_child(0).value/charsize.x,TextEditWindow.cursor_get_line()-TextEditWindow.get_child(1).value)
	
	if linebefore.is_subsequence_of(lineafter) && !lineafter.is_subsequence_of(linebefore) && y_was == TextEditWindow.cursor_get_line():
		if lineafter.length() <= 0:
			print("i fucked up")
			return ""
		elif lineafter.length() == 1:
			return lineafter
		else:
			return lineafter[TextEditWindow.cursor_get_column()-1]
	else:
		return ""
		

func what_removed(linebefore):
	var cursorpos = Vector2(TextEditWindow.cursor_get_column()-TextEditWindow.get_child(0).value/charsize.x,TextEditWindow.cursor_get_line()-TextEditWindow.get_child(1).value)
	
	if lineafter.is_subsequence_of(linebefore) && !linebefore.is_subsequence_of(lineafter) && y_was == TextEditWindow.cursor_get_line():
		if linebefore.length() == 1:
			return linebefore
		else:
			return linebefore[TextEditWindow.cursor_get_column()]
		print("DETECTO DELETUS")
	else:
		return ""
	
	