module util::JSONConverter


import List;
import Node;
import IO;



data JsonNode
	= object(map[str, JsonNode] fields)
	| dictionary(JsonNode keyType, JsonNode valueType)
	| array(JsonNode itemType)
	| integer()
	| string()
	| float()
	| \bool()
	| \tuple(list[JsonNode] members)
	;
	
map[str, value] convertJSON(map[str, value] elements, object(fields)) {
	return (key: convertJSON(elements[key], fields[key]) | key <- elements);
}
map[str, value] convertJSON(list[list[value]] elements, object(fields)) {
	map[str, value] result = ();
	for (element <- elements) {
		if (size(element) != 2) {
			throw "Cannot convert list to map";
		}
		result[element[0]] = convertJSON(element[1], fields[element[0]]);
	}
	return result;
}
map[str, value] convertJSON(node T, JsonNode typ) {
	return convertJSON(getKeywordParameters(T), typ);
}


map[value, value] convertJSON(map[str, value] elements, dictionary(keyType, valueType)) {
	return (convertJSON(key, keyType): convertJSON(elements[key], valueType) | key <- elements);
}
map[value, value] convertJSON(list[list[value]] elements, dictionary(keyType, valueType)) {
	map[value, value] result = ();
	for (element <- elements) {
		if (size(element) != 2) {
			throw "Cannot convert list to map";
		}
		result[convertJSON(element[0], keyType)] = convertJSON(element[1], valueType);
	}
	return result;
}


list[value] convertJSON(list[value] items, array(itemType)) {
	return [convertJSON(item, itemType) | item <- items];
}

str convertJSON(str v, string()) = v;
int convertJSON(int v, integer()) = v;
real convertJSON(real v, float()) = v;
bool convertJSON(bool v, \bool()) = v;

list[value] convertJSON(list[value] items, \tuple(members)) {
	if (size(items) != size(members)) {
		throw "Cannot convert list to tuple";
	}
	return [convertJSON(x, typ) | <x, typ> <- zip(items, members)];
}
