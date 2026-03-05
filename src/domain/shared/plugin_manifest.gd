## Plugin manifest value object.
## Declares which ports and tools a plugin intends to use.
## Supports cryptographic signing via ManifestSignature for tamper detection.
class_name PluginManifest
extends RefCounted

var plugin_id: String
var name: String
var version: String
var declared_ports: Array[String]
var declared_tools: Array[String]
var signature: ManifestSignature

func _init(plugin_id: String, name: String, version: String, declared_ports: Array[String], declared_tools: Array[String]):
	self.plugin_id = plugin_id
	self.name = name
	self.version = version
	self.declared_ports = declared_ports.duplicate()
	self.declared_tools = declared_tools.duplicate()
	self.signature = null

func has_declared_port(port_name: String) -> bool:
	return declared_ports.has(port_name)

func has_declared_tool(tool_name: String) -> bool:
	return declared_tools.has(tool_name)


## Returns a deterministic JSON string of the signable fields.
## Used as the payload for HMAC-SHA256 signing/verification.
func to_signable_json() -> String:
	var ports_copy := declared_ports.duplicate()
	ports_copy.sort()
	var tools_copy := declared_tools.duplicate()
	tools_copy.sort()
	var data := {
		"plugin_id": plugin_id,
		"name": name,
		"version": version,
		"declared_ports": ports_copy,
		"declared_tools": tools_copy,
	}
	return JSON.stringify(data, "", false)


## Whether this manifest has a signature attached.
func is_signed() -> bool:
	return signature != null and signature.is_valid()


## Signs this manifest with the given secret key. Attaches signature in-place.
func sign_manifest(
	secret_key: PackedByteArray,
	signer_id: String = "engine",
	signed_at: String = ""
) -> void:
	signature = ManifestSignature.sign(
		to_signable_json(), secret_key, signer_id, signed_at
	)


## Verifies the attached signature against the given secret key.
func verify_signature(secret_key: PackedByteArray) -> bool:
	if not is_signed():
		return false
	return ManifestSignature.verify(to_signable_json(), secret_key, signature)