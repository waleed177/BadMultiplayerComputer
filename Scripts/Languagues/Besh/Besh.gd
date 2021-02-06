extends Reference
class_name Besh

signal variable_changed

var _code: String
var _code_i: int
var _parsers: Array = [] #Currently will not use here, only for users.
var _parser_last_item
var _parser_next_item
var _expression_parse_cache = {}
var _func_dict: Dictionary = {}
var _bindings_backup: Dictionary = {}
var _compiled: Array
var _peek_i: Array = []
var _tree: SceneTree
var _running_id = 0
var _variables = {}
var _labels = {}
var _const_operations = ["+=", "-=", "/=", "*=", "="]
var _args = {}
var _local_vars = {}

func _init():
	bind("const", funcref(self, "make_constant"), 2)
	bind("sleep", funcref(self, "_bind_sleep"), 1)
	bind("str1", funcref(self, "_bind_str1"), 1, [], ["token"])
	bind("forever", funcref(self, "_bind_forever"), 1)
	bind("break", funcref(self, "_bind_break"), 0)
	bind("return", funcref(self, "_bind_return"), 1)
	bind("if", funcref(self, "_bind_if"), 2)
	bind("not", funcref(self, "_bind_not"), 1)
	bind("arg", funcref(self, "_bind_arg"), 1, [], ["token"])
	bind("lset", funcref(self, "_bind_local_set"), 2, [], ["token", "expression"])
	bind("lget", funcref(self, "_bind_local_get"), 1, [], ["token"])
	bind("connect", funcref(self, "_bind_connect"), 1)
	bind("rpc0", funcref(self, "_bind_rpc"), 2).parameters_passed_as_array = true
	bind("rpc1", funcref(self, "_bind_rpc"), 3).parameters_passed_as_array = true
	bind("rpc2", funcref(self, "_bind_rpc"), 4).parameters_passed_as_array = true
	bind("rpc3", funcref(self, "_bind_rpc"), 5).parameters_passed_as_array = true
	bind("rpc4", funcref(self, "_bind_rpc"), 6).parameters_passed_as_array = true
	bind("rpc5", funcref(self, "_bind_rpc"), 7).parameters_passed_as_array = true
	bind("strcat", funcref(self, "_bind_strcat"), 2)
	bind("to_char", funcref(self, "char"), 1)
	
func setup(tree: SceneTree):
	_bindings_backup = _func_dict.duplicate()
	_tree = tree

func _bind_sleep(amount: float):
	yield(_tree.create_timer(amount), "timeout")

func _bind_str1(val: String):
	return val

func _bind_forever(program: Dictionary):
	var id = _running_id
	while id == _running_id:
		var res = _evaluate_program(program)
		
		if res is GDScriptFunctionState:
			res = yield(res, "completed")	
		if res is Dictionary and "___break" in res:
			break

func _bind_break():
	return {___break = true}
	
func _bind_return(data):
	return {___break = true, ___data = data}

func _bind_if(condition, iftrue):
	if condition != 0:
		return _evaluate_program(iftrue)

func _bind_not(boolean):
	return 0 if boolean != 0 else 1

func _bind_arg(arg: String):
	return _args[arg]

func _bind_call_function(parameter_names: Array, func_body: Dictionary, params: Array):
	var args_bk = _args.duplicate()
	_args = {}
	for i in len(parameter_names):
		_args[parameter_names[i]] = params[i]
	var res = _evaluate_program(func_body)
	if res is GDScriptFunctionState:
		yield(res, "completed")
	_args = args_bk
	if res is Dictionary and "___break" in res:
		return res.___data if "___data" in res else null

func _bind_local_set(name, value):
	_local_vars[name] = value
	return value

func _bind_local_get(name):
	return _local_vars[name]

func _bind_connect(name):
	return _tree.current_scene.get_node(name).besh

func _bind_rpc(params: Array):
	var connection = params.pop_front()
	var function_name = params.pop_front()
	return connection._evaluate_func({
		type = "function_call",
		function_name = function_name,
		parameters = params
	}, false)

func _bind_strcat(str1, str2):
	return str(str1) + str(str2)

func compile(code: String):
	_running_id += 1 # To stop the code from running
	_code = code.replace("\r\n", "\n")
	_code_i = 0
	_func_dict = _bindings_backup.duplicate()
	_parsers.clear()
	_labels = {}
	_expression_parse_cache.clear()
	
	var len_code = len(_code)
	_compiled = []
	while _code_i < len_code:
		var res = _parse_expression()
		if res != null:
			_compiled.append(res)
		else:
			if _peek_token() == "":
				break


func _evaluate_func(func_call_data: Dictionary, evaluate_params: bool = true): 
	var func_data: Dictionary = _func_dict[func_call_data.function_name]
	var func_ref: FuncRef = func_data.function_ref
	var evaluated_params: Array = []
	if evaluate_params:
		for param in func_call_data.parameters:
			if param.type == "program":
				evaluated_params.append(param) # Do not evaluate programs
			else:
				var res = _evaluate_expression(param)
				if res is GDScriptFunctionState:
					yield(res, "completed")
				evaluated_params.append(res)
	else:
		evaluated_params = func_call_data.parameters
	if func_data.parameters_passed_as_array:
		return func_ref.call_funcv(func_data.append_parameters + [evaluated_params])
	else:
		return func_ref.call_funcv(func_data.append_parameters + evaluated_params)

func _evaluate_expression(expression: Dictionary):
	if expression.type == "constant":
		return expression.value
	elif expression.type == "function_call":
		var res = _evaluate_func(expression)
		if res is GDScriptFunctionState:
			yield(res, "completed")
		return res
	elif expression.type == "operation":
		var right_operand = _evaluate_expression(expression.right_operand)
		if right_operand is GDScriptFunctionState:
			yield(right_operand, "completed")
		var var_val = get_variable(expression.variable_name) if expression.operation != "=" else null
		match expression.operation:
			"=":
				var_val = right_operand
			"+=":
				var_val += right_operand
			"-=":
				var_val -= right_operand
			"*=":
				var_val *= right_operand
			"/=":
				var_val /= right_operand
		set_variable(expression.variable_name, var_val)
		return get_variable(expression.variable_name)
	elif expression.type == "program":
		return expression
	return null

func _evaluate_program(prog: Dictionary):
	var id = _running_id
	var local_vars_bk = _local_vars.duplicate()
	for i in len(prog.value):
		if id == _running_id:
			var res = _evaluate_expression(prog.value[i])
			if res is GDScriptFunctionState:
				yield(res, "completed")
			if res is Dictionary and "___break" in res:
				_local_vars = local_vars_bk
				return res
	_local_vars = local_vars_bk
	return null

func execute():
	_running_id += 1
	_variables = {}
	return _evaluate_program({
		type = "program",
		value = _compiled
	})

func _parse_expression():
	var code_i = _code_i
	if _code_i in _expression_parse_cache:
		var res = _expression_parse_cache[_code_i]
		_code_i = res.code_i
		return res.result
	var peek:String = _peek_token()
	if peek == "": return null
	
	var result = null
	
	if peek == "parser":
		return _parse_custom_parser()
	elif peek == "{":
		_next_token()
		var res = []
		while _peek_token() != "}":
			res.append(_parse_expression())
		_next_token()
		result = {
			type = "program",
			value = res
		}
	elif _is_operator():
		result = _parse_operator()
	else:
		var parsers_result = _parse_using_custom_parser()
		if parsers_result.success:
			result = parsers_result.result
	
	if not result:
		if peek.is_valid_float():
			_next_token()
			result = {
				type = "constant",
				value = float(peek)
			}
		elif peek == "func":
			_next_token()
			var func_name = _next_token()
			var func_parameters = []
			while _peek_token() != "{":
				func_parameters.append(_next_token()) 
			var func_body = _parse_expression()
			var func_data = bind(func_name, funcref(self, "_bind_call_function"), len(func_parameters), [func_parameters, func_body])
			func_data.parameters_passed_as_array = true
			result = null
		else:
			result = _parse_function_call()
	_expression_parse_cache[code_i] = {result = result, code_i = _code_i}
	return result

func _is_operator(): 
	var is_operator: bool = false
	_peek_start()
	var a = _next_token()
	var possible_operator = _next_token()
	if possible_operator in _const_operations:
		is_operator = true
	_peek_end()
	return is_operator

func _parse_operator():
	var expression = {
		type = "operation",
		variable_name = _next_token(),
		operation = _next_token(),
		right_operand = _parse_expression()
	}
	if not expression.variable_name in _func_dict:
		make_variable(expression.variable_name, 0)
	return expression

func _parse_custom_parser():
	assert(_next_token() == "parser")
	var parser = {
		parser = [],
		program = {},
		func_name = "$$$$PARSER_FUNC$$" + str(len(_parsers)),
		enabled = true
	}
	var parameter_names = []
	while _peek_token() != "{":
		var item = {
			function_name = _next_token(),
			parameter = _next_token()
		}
		parser.parser.append(item)
		if item.function_name == "CHRS" or item.function_name == "TOK" or item.function_name == "EXP":
			parameter_names.append(item.parameter)
	parser.program = _parse_expression()
	_parsers.append(parser)
	var func_data = bind(parser.func_name, funcref(self, "_bind_call_function"), 0, [parameter_names, parser.program])
	func_data.parameters_passed_as_array = true
	return null

func _parse_using_custom_parser() -> Dictionary:
	var res = {success = false, result = {}}
	var collected_tokens = []
	for parser in _parsers:
		if not parser.enabled: continue
		_peek_start()
		_skip_whitespace()
		collected_tokens.clear()
		var satisifed = true
		for i in len(parser.parser):
			var item = parser.parser[i]

			match item.function_name:
				"CHRS":
					var string = ""
					var next_item = parser.parser[i+1]
					while _peek_char() != "" and not _custom_parser_does_satisfy(next_item, true):
						string += _next_char()
					if string == "":
						satisifed = false
						break
					collected_tokens.append({type="constant", value=string})
				"TOK":
					var token = _next_token()
					if token == "":
						satisifed = false
						break
					collected_tokens.append({type="constant", value=token})
				"EXP":
					var next_item = parser.parser[i+1]
					_parser_next_item = next_item
					parser.enabled = i != 0
					var expression = _parse_expression()
					_parser_next_item = null
					parser.enabled = true
					if expression.type == "error":
						satisifed = false
						break
					else:
						collected_tokens.append(expression)
				_:
					if not _custom_parser_does_satisfy(item):
						satisifed = false
						break
		if satisifed:
			_peek_commit()
			res.success = true
			res.result = {
				type = "function_call",
				function_name = parser.func_name,
				parameters = collected_tokens
			}
			break
		else:
			_peek_end()
	return res

func _custom_parser_does_satisfy(item, peek=false):
	if peek: _peek_start()
	var res = true
	match item.function_name:
		"TOK=":
			res = _next_token(true) == item.parameter
		"CHR=":
			res = _next_char() == item.parameter
	if peek: _peek_end()
	return res
		

func _parse_function_call():
	var func_name = _next_token()
	if not func_name in _func_dict:
		return {type = "error"}
	var func_data = _func_dict[func_name]
	var func_parameters = []
	
	if func_data.parameter_types.size() > 0:
		for i in func_data.parameter_count:
			if func_data.parameter_types[i] == "token":
				func_parameters.append({
					type = "constant",
					value = _next_token()
				})
			elif func_data.parameter_types[i] == "expression":
				func_parameters.append(_parse_expression())
	else:
		for i in func_data.parameter_count:
			func_parameters.append(_parse_expression())
	
	return {
		type = "function_call",
		function_name = func_name,
		parameters = func_parameters
	}

func _next_token(no_satisfy_test = false) -> String:
	var res = ""
	if len(_code) <= _code_i: return ""
	print((no_satisfy_test or not _parser_next_item or not _custom_parser_does_satisfy(_parser_next_item, true)))
	while res == "" and _code_i < len(_code) and (no_satisfy_test or not _parser_next_item or not _custom_parser_does_satisfy(_parser_next_item, true)):
		while _code_i < len(_code) and _code[_code_i] != " " and _code[_code_i] != "\n" and _code[_code_i] != "\t" and (no_satisfy_test or not _parser_next_item or not _custom_parser_does_satisfy(_parser_next_item, true)):
			res += _code[_code_i]
			_code_i += 1
		_code_i += 1
	return res

func _skip_whitespace():
	while true:
		var chr = _next_char()
		if chr != " " and chr != "\n" and chr != "\t":
			_code_i -= 1
			break

func _next_char() -> String:
	if len(_code) <= _code_i: return ""
	var _code_i_bk = _code_i
	_code_i += 1
	return _code[_code_i_bk]

func _peek_char() -> String:
	_peek_start()
	var res = _next_char()
	_peek_end()
	return res

func _peek_token() -> String:
	_peek_start()
	var res = _next_token()
	_peek_end()
	return res

func _peek_start():
	_peek_i.push_back(_code_i)

func _peek_end():
	_code_i = _peek_i.pop_back()

func _peek_commit():
	_peek_i.pop_back()

func get_variable(variable_name: String):
	return _evaluate_func({
			type = "function_call",
			function_name = variable_name,
			parameters = []
		})

func set_variable(variable_name: String, variable_value):
	return _evaluate_func({
			type = "function_call",
			function_name = variable_name + ".set",
			parameters = [{
				type = "constant",
				value = variable_value
			}]
		})

## Binding functions
func bind(func_name: String, func_ref: FuncRef, parameter_count: int, append_parameters: Array = [], parameter_types: Array = []) -> Dictionary:
	_func_dict[func_name] = {
		parameter_count = parameter_count,
		function_ref = func_ref,
		append_parameters = append_parameters,
		parameter_types = parameter_types,
		parameters_passed_as_array = false
	}
	return _func_dict[func_name]

func make_constant(const_name: String, const_value):
	bind(const_name, funcref(self, "_constant"), 0, [const_value])
	
func _constant(const_value):
	return const_value

func make_variable(var_name: String, var_value):
	_variables[var_name] = var_value
	bind(var_name, funcref(self, "_variable_get"), 0, [var_name])
	bind(var_name + ".set", funcref(self, "_variable_set"), 1, [var_name])

func bind_property(var_name: String, obj: Node, property_name: String, rset: bool = false):
	bind(var_name, funcref(self, "_property_get"), 0, [obj, property_name])
	bind(var_name + ".set", funcref(self, "_property_set"), 1, [obj, property_name, rset])

func bind_color_property(var_name: String, obj: Node, property_name: String, rset: bool = false):
	for channel in ['r','g','b']:
		bind(var_name + "." + channel, funcref(self, "_deep_property_get"), 0, [obj, property_name, channel])
		bind(var_name + "." + channel + ".set", funcref(self, "_color_property_set"), 1, [obj, property_name, channel, rset])

func bind_vector2_property(var_name: String, obj: Node, property_name: String, rset: bool = false):
	for component in ['x','y']:
		bind(var_name + "." + component, funcref(self, "_deep_property_get"), 0, [obj, property_name, component])
		bind(var_name + "." + component + ".set", funcref(self, "_vector2_property_set"), 1, [obj, property_name, component, rset])

func _variable_get(var_name):
	return _variables[var_name] if var_name in _variables else null

func _variable_set(var_name, var_value):
	var prev_value = _variables[var_name] if var_name in _variables else null
	_variables[var_name] = var_value
	emit_signal("variable_changed", var_name, prev_value, var_value)
	return var_value

func _property_get(obj: Node, property_name: String):
	return obj.get(property_name)
	
func _property_set(obj: Node, property_name: String, rset: bool, new_value):
	if rset:
		obj.rset(property_name, new_value)
	else:
		obj.set(property_name, new_value)
	return obj.get(property_name)

func _color_property_set(obj: Node, property_name: String, channel: String, rset: bool, new_value):
	var set_val: Color
	
	match channel:
		"*":
			set_val = Color(new_value)
		"r":
			var color: Color = obj.get(property_name)
			set_val = Color(new_value, color.g, color.b, color.a)
		"g":
			var color: Color = obj.get(property_name)
			set_val = Color(color.r, new_value, color.b, color.a)
		"b":
			var color: Color = obj.get(property_name)
			set_val = Color(color.r, color.g, new_value, color.a)
	
	if rset:
		obj.rset(property_name, set_val)
	else:
		obj.set(property_name, set_val)
	return new_value

func _vector2_property_set(obj: Node, property_name: String, component: String, rset: bool, new_value):
	var set_val: Vector2
	
	match component:
		"x":
			var vector: Vector2 = obj.get(property_name)
			set_val = Vector2(new_value, vector.y)
		"y":
			var vector: Vector2 = obj.get(property_name)
			set_val = Vector2(vector.x, new_value)
	
	if rset:
		obj.rset(property_name, set_val)
	else:
		obj.set(property_name, set_val)
	return new_value

func _deep_property_get(obj: Node, property_name: String, sub_property_name: String):
	return obj.get(property_name)[sub_property_name]
