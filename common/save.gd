class_name Save extends Object

## The magical automatic save/load system.
##
## This module uses reflection to try to save and load objects automatically.
##
## You need to mark all object fields you want to serialize with
## `@export_storage` or `@export`.
##
## All numbers are loaded as floats. They should get re-cast correctly in
## property fields and typed arrays, but if you have them in something that
## can't be type-parameterized like a Dictionary you might get ints converted
## to floats.
##
## Objects are stored as dictionaries identified with the magic key
## "__script_path__". Don't have actual properties with this name.

# TODO: Support multiple saves. Files go in user://saves/*, make savefile into
# an object? Add methods to list these, create a new one and just access a
# default one.

const SAVE_PATH := "user://save.json"

static func exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func delete():
	if exists():
		DirAccess.remove_absolute(SAVE_PATH)

## Write object into save file.
static func write(obj):
	var data = serialize(obj)
	var json = JSON.stringify(data)

	var save_file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	save_file.store_line(json)

## Read save contents into the input object.
static func read() -> Variant:
	if !exists():
		push_error("No save file to load")
		return null
	var data = _load_json(SAVE_PATH)
	if data == null:
		push_error("Error loading save")
	return deserialize(data)

static func _load_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file: ", path)
		return null

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("JSON Parse Error: ", json.get_error_message())
		return null

	return json.data

static func serialize(obj: Variant) -> Variant:
	match typeof(obj):
		# Primitives that can be expressed directly in JSON.
		TYPE_NIL, \
		TYPE_BOOL, \
		TYPE_INT, \
		TYPE_FLOAT:
			return obj
		# Complex-ish primitive types go through var_to_str.
		#
		# Note that string is here too, so string values in the serialization
		# will have extra quotations around them, "foo" -> "\"foo\"".
		TYPE_STRING, \
		TYPE_VECTOR2, \
		TYPE_VECTOR2I, \
		TYPE_RECT2, \
		TYPE_RECT2I, \
		TYPE_VECTOR3, \
		TYPE_VECTOR3I, \
		TYPE_TRANSFORM2D, \
		TYPE_VECTOR4, \
		TYPE_VECTOR4I, \
		TYPE_PLANE, \
		TYPE_QUATERNION, \
		TYPE_AABB, \
		TYPE_BASIS, \
		TYPE_TRANSFORM3D, \
		TYPE_PROJECTION, \
		TYPE_COLOR, \
		TYPE_STRING_NAME, \
		TYPE_NODE_PATH, \
		TYPE_RID:
			return var_to_str(obj)
		TYPE_ARRAY:
			var output_array = []
			for element in obj:
				output_array.append(serialize(element))
			return output_array
		TYPE_DICTIONARY:
			var output_dict = {}
			for key in obj.keys():
				output_dict[serialize(key)] = serialize(obj[key])
			return output_dict
		TYPE_PACKED_BYTE_ARRAY:
			# Use special encoding, save PackedByteArray as base64.

			var prefix := ":pba "
			var compressed = obj.compress(FileAccess.CompressionMode.COMPRESSION_DEFLATE)
			if compressed.size() < obj.size():
				obj = compressed
				prefix = ":pbz "

			var base64 = Marshalls.raw_to_base64(obj)
			return prefix + base64
		# TODO: Do the rest of the packed arrays similar to PBA
		TYPE_OBJECT:
			# Continued below
			pass
		_:
			assert(false, "Cannot serialize type " + str(typeof(obj)))

	# If we're here, we're doing an object.

	# Is it a resource stored in a file? Assume it's immutable and just save the file path.
	# This works because all actual strings are saved with extra quotes so we
	# can tell from the prefix being 'res:' instead of '"' that we're looking
	# at a special value.
	if "resource_path" in obj and obj.resource_path:
		return obj.resource_path

	# Script objects are instantiated using their script file path, so only
	# classes at the top level of the script file are good.
	assert(obj.get_script() and obj.get_script().resource_path, "serialize: Object " + str(obj) + " must have its own script file")

	var result = {
		# Write the magic object identifier field
		__script_path__ = obj.get_script().resource_path
	}

	# XXX: Find the index past the 'script' property. This is assuming that the
	# properties are in order and the ones from system classes we don't care
	# about are before 'script' and the ones from our class are after it.
	var props = obj.get_property_list()

	var start_idx := 0
	for i in props.size():
		if props[i].name == "script":
			start_idx = i + 1
			break

	for i in range(start_idx, props.size()):
		var prop = props[i]
		# Properties must be marked to be serialized with @export or @export_storage to be serialized.
		# We don't want to serialize all the random junk in objects.
		if not prop.usage & PROPERTY_USAGE_STORAGE:
			continue
		var name = prop.name
		var value = obj.get(name)
		result[name] = serialize(value)

	return result

static func deserialize(data: Variant) -> Variant:
	match typeof(data):
		TYPE_NIL, \
		TYPE_BOOL, \
		TYPE_INT, \
		TYPE_FLOAT:
			return data
		TYPE_STRING:
			# Check for special encodings.
			if data.begins_with("res:"):
				# Resource loaded from path.
				var res = ResourceLoader.load(data)
				if res == null:
					push_error("Failed to load resource at path: " + data)
				return res
			elif data.begins_with(":pba "):
				# PackedByteArray in base64.
				return Marshalls.base64_to_raw(data.substr(5))
			elif data.begins_with(":pbz "):
				# Compressed PackedByteArray in base64.
				var bytes = Marshalls.base64_to_raw(data.substr(5))
				var pba = bytes.decompress_dynamic(-1, FileAccess.CompressionMode.COMPRESSION_DEFLATE)
				return pba
			else:
				# Use standard conversion otherwise.
				return str_to_var(data)
		TYPE_ARRAY:
			var output_array = []
			for element in data:
				output_array.append(deserialize(element))
			return output_array
		TYPE_DICTIONARY:
			if "__script_path__" in data:
				# Magic path property found, it's an object.

				# TODO: Error handling when script can't be loaded.

				# Instantiate an object using the script resource.
				var script: Script = load(data.__script_path__)
				var obj = script.new()

				for key in data.keys():
					if key == "__script_path__":
						continue
					var value = deserialize(data[key])
					var target = obj.get(key)
					if target is Array:
						# It might be a typed array, construct our own typed array of the same type.
						var typed_array = target.duplicate()
						typed_array.clear()
						typed_array.assign(value)
						obj.set(key, typed_array)
					else:
						# Otherwise just set directly.
						obj.set(key, value)
				return obj
			else:
				# Otherwise assume it's a regular dictionary.
				var output_dict = {}
				for key in data.keys():
					output_dict[deserialize(key)] = deserialize(data[key])
				return output_dict
		_:
			assert(false, "Cannot deserialize type " + str(typeof(data)))
	return null
