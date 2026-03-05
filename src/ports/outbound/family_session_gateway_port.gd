## Outbound port for private family online session backend integration.
class_name FamilySessionGatewayPort
extends RefCounted


func create_invite(payload: Dictionary) -> Dictionary:
	push_error("FamilySessionGatewayPort.create_invite() not implemented")
	return {}


func join_session(payload: Dictionary) -> Dictionary:
	push_error("FamilySessionGatewayPort.join_session() not implemented")
	return {}


func close_session(payload: Dictionary) -> bool:
	push_error("FamilySessionGatewayPort.close_session() not implemented")
	return false
