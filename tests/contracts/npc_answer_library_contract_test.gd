class_name NPCAnswerLibraryContractTest
extends PortContractTest

const LIBRARY_SERVICE := preload("res://src/application/npc_answer_library_service.gd")


func run() -> Dictionary:
	_reset()

	var service := LIBRARY_SERVICE.new()
	_assert_has_method(service, "load_library")
	_assert_has_method(service, "save_new_answer")

	# Verify it runs a basic loading flow correctly
	var lines := {"greeting": "Hej!"}
	var library := service.load_library("npc_contract_test_char", lines)
	_assert_true(library.size() == 1, "library should load static lines")
	_assert_true(library[0]["text"] == "Hej!", "should load greeting text")

	return _build_result("NPCAnswerLibrary")
