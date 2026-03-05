## HTTP-backed adapter for PublishStorePort.
## Targets the custom cloud API and keeps networking out of application/domain layers.
class_name HttpPublishStore
extends PublishStorePort

var _base_url: String = ""
var _timeout_msec: int = 5000
var _api_token: String = ""


func setup(base_url: String, api_token: String = "", timeout_msec: int = 5000) -> HttpPublishStore:
	_base_url = base_url.strip_edges().trim_suffix("/")
	_api_token = api_token
	_timeout_msec = maxi(1000, timeout_msec)
	return self


func save_request(request: PublishRequest) -> bool:
	if request == null:
		return false
	if request.request_id.strip_edges().is_empty():
		return false
	if _base_url.is_empty():
		return false

	var payload := _serialize_request(request)
	var response := _request_json("POST", "/v1/publish/requests", payload)
	return int(response.get("status", 0)) >= 200 and int(response.get("status", 0)) < 300


func load_request(request_id: String) -> PublishRequest:
	if request_id.strip_edges().is_empty() or _base_url.is_empty():
		return null

	var response := _request_json("GET", "/v1/publish/requests/%s" % request_id)
	if int(response.get("status", 0)) != 200:
		return null
	var body: Variant = response.get("body", null)
	if not (body is Dictionary):
		return null
	return _deserialize_request(body as Dictionary)


func list_requests_for_project(project_id: String) -> Array:
	if project_id.strip_edges().is_empty() or _base_url.is_empty():
		return []
	var response := _request_json("GET", "/v1/publish/projects/%s/requests" % project_id)
	if int(response.get("status", 0)) != 200:
		return []
	return _deserialize_request_list(response.get("body", []))


func list_published() -> Array:
	if _base_url.is_empty():
		return []
	var response := _request_json("GET", "/v1/publish/requests/published")
	if int(response.get("status", 0)) != 200:
		return []
	return _deserialize_request_list(response.get("body", []))


func _request_json(method: String, path: String, payload: Dictionary = {}) -> Dictionary:
	var client := HTTPClient.new()
	var parsed := _parse_base_url(_base_url)
	if parsed.is_empty():
		return {"status": 0, "body": {}}

	var host := str(parsed.get("host", ""))
	var port := int(parsed.get("port", 443))
	var use_tls := bool(parsed.get("tls", true))
	var err := client.connect_to_host(host, port, use_tls)
	if err != OK:
		return {"status": 0, "body": {}}

	var deadline := Time.get_ticks_msec() + _timeout_msec
	while client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		client.poll()
		if Time.get_ticks_msec() > deadline:
			return {"status": 0, "body": {}}

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"status": 0, "body": {}}

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
	])
	if not _api_token.is_empty():
		headers.append("Authorization: Bearer %s" % _api_token)

	var body := ""
	if method != "GET":
		body = JSON.stringify(payload)
	var method_code := _http_method_code(method)
	err = client.request(method_code, path, headers, body)
	if err != OK:
		return {"status": 0, "body": {}}

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		if Time.get_ticks_msec() > deadline:
			return {"status": 0, "body": {}}

	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		if Time.get_ticks_msec() > deadline:
			return {"status": 0, "body": {}}

	var status := client.get_response_code()
	var chunks := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_CONNECTED and client.has_response():
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.is_empty():
			break
		chunks.append_array(chunk)

	var text := chunks.get_string_from_utf8().strip_edges()
	if text.is_empty():
		return {"status": status, "body": {}}
	var parsed_body: Variant = JSON.parse_string(text)
	if parsed_body == null:
		return {"status": status, "body": {}}
	return {"status": status, "body": parsed_body}


func _parse_base_url(url: String) -> Dictionary:
	var normalized := url.strip_edges()
	if normalized.is_empty():
		return {}
	var tls := true
	var host_port := normalized
	if normalized.begins_with("https://"):
		host_port = normalized.trim_prefix("https://")
		tls = true
	elif normalized.begins_with("http://"):
		host_port = normalized.trim_prefix("http://")
		tls = false
	var slash_idx := host_port.find("/")
	if slash_idx >= 0:
		host_port = host_port.substr(0, slash_idx)
	var host := host_port
	var port := 443 if tls else 80
	var colon_idx := host_port.rfind(":")
	if colon_idx > 0:
		host = host_port.substr(0, colon_idx)
		port = int(host_port.substr(colon_idx + 1))
	return {"host": host, "port": port, "tls": tls}


func _http_method_code(method: String) -> int:
	match method.to_upper():
		"GET":
			return HTTPClient.METHOD_GET
		"POST":
			return HTTPClient.METHOD_POST
		"PUT":
			return HTTPClient.METHOD_PUT
		"PATCH":
			return HTTPClient.METHOD_PATCH
		"DELETE":
			return HTTPClient.METHOD_DELETE
		_:
			return HTTPClient.METHOD_GET


func _serialize_request(request: PublishRequest) -> Dictionary:
	var moderation_rows: Array = []
	for result_variant in request.moderation_results:
		if result_variant is ModerationResult:
			var result: ModerationResult = result_variant
			moderation_rows.append({
				"verdict": int(result.verdict),
				"reason": result.reason,
				"category": result.category,
				"confidence": result.confidence,
				"safe_alternative": result.safe_alternative,
			})
	return {
		"request_id": request.request_id,
		"project_id": request.project_id,
		"world_id": request.world_id,
		"state": int(request.state),
		"visibility": int(request.visibility),
		"requester_id": request.requester_id,
		"reviewer_id": request.reviewer_id,
		"moderation_results": moderation_rows,
		"rejection_reason": request.rejection_reason,
		"created_at": request.created_at,
		"published_at": request.published_at,
		"unpublished_at": request.unpublished_at,
		"revision_count": request.revision_count,
	}


func _deserialize_request(data: Dictionary) -> PublishRequest:
	var req := PublishRequest.new(str(data.get("project_id", "")), str(data.get("world_id", "")))
	req.request_id = str(data.get("request_id", ""))
	req.state = int(data.get("state", PublishRequest.PublishState.DRAFT))
	req.visibility = int(data.get("visibility", PublishRequest.Visibility.PRIVATE))
	req.requester_id = str(data.get("requester_id", ""))
	req.reviewer_id = str(data.get("reviewer_id", ""))
	req.rejection_reason = str(data.get("rejection_reason", ""))
	req.created_at = str(data.get("created_at", ""))
	req.published_at = str(data.get("published_at", ""))
	req.unpublished_at = str(data.get("unpublished_at", ""))
	req.revision_count = int(data.get("revision_count", 0))
	req.moderation_results = []
	var moderation_rows: Variant = data.get("moderation_results", [])
	if moderation_rows is Array:
		for row in moderation_rows:
			if row is Dictionary:
				var result := ModerationResult.new(
					int(row.get("verdict", ModerationResult.Verdict.PASS)),
					str(row.get("reason", ""))
				)
				result.category = str(row.get("category", ""))
				result.confidence = float(row.get("confidence", 1.0))
				result.safe_alternative = str(row.get("safe_alternative", ""))
				req.moderation_results.append(result)
	return req


func _deserialize_request_list(body: Variant) -> Array:
	var rows: Array = []
	if body is Array:
		rows = body
	elif body is Dictionary and body.has("items") and body["items"] is Array:
		rows = body["items"]
	else:
		return []

	var requests: Array = []
	for row in rows:
		if row is Dictionary:
			requests.append(_deserialize_request(row))
	return requests
