extends SceneTree

func _init():
	var test := TemplateLoaderTest.new()
	var result := test.run()
	print("Test result: ", result)
	quit(0)