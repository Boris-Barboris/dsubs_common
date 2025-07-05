/*
DSubs
Copyright (C) 2017-2025 Baranin Alexander

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
module dsubs_common.json;

import core.bitop: popcnt;

import std.conv: to;
import std.exception: enforce;
import std.json;
public import std.json: JSONValue, JSONOptions;
import std.traits;
import std.typecons: Nullable;
import std.meta;
import std.utf: validate;
import std.math: isNaN, isInfinity;

import gfm.math.vector: Vector, vec2f, isVector;

import dsubs_common.meta;
import dsubs_common.utils;


// from std docs:
// Any Object types will be serialized in a key-sorted order.


JSONValue toJson(T)(const ref T ptr)
	if (!is(T == struct) && !is(T == class) && (!isArray!T || isSomeString!T))
{
	static if (isBasicType!T && !hasIndirections!T &&
		!is(T == enum) || isSomeString!T)
	{
		return JSONValue(ptr);
	}
	else static if (is(T == enum))
	{
		JSONValue[] res;
		// bitmask handling code
		foreach (memb; EnumMembers!T)
		{
			// this enum is probably not a bitmask
			if (memb == ptr || popcnt(memb) != 1)
				return JSONValue(ptr.to!string);
			if (memb & ptr)
				res ~= JSONValue(memb.to!string);
		}
		if (res.length > 1)
			return JSONValue(res);	// return array
		else
			return res[0];
	}
	else
		static assert(0, "Unable to serialize " ~ T.stringof);
}

void deserializeJson(T)(ref T ptr, const JSONValue jv)
	if (!is(T == struct) && !is(T == class) && (!isArray!T || isSomeString!T))
{
	static if (isBasicType!T && !hasIndirections!T &&
		!is(T == enum) || isSomeString!T)
	{
		static if (isIntegral!T || isFloatingPoint!T)
		{
			switch (jv.type)
			{
				case (JSONType.integer):
					ptr = jv.integer.to!T;
					break;
				case (JSONType.uinteger):
					ptr = jv.uinteger.to!T;
					break;
				case (JSONType.float_):
					ptr = jv.floating.to!T;
					break;
				default:
					throw new Exception("json parse type mismatch, expected " ~
						T.stringof ~ ", got " ~ jv.toString);
			}
		}
		else static if (isSomeString!T)
		{
			switch (jv.type)
			{
				case (JSONType.null_):
					ptr = null;
					break;
				case (JSONType.string):
					ptr = jv.str;
					break;
				default:
					throw new Exception("json parse type mismatch, expected " ~
						T.stringof ~ ", got " ~ jv.toString);
			}
		}
		else static if (isBoolean!T)
		{
			switch (jv.type)
			{
				case (JSONType.false_):
				case (JSONType.true_):
					ptr = jv.boolean.to!T;
					break;
				default:
					throw new Exception("json parse type mismatch, expected " ~
						T.stringof ~ ", got " ~ jv.toString);
			}
		}
		else
			static assert (0, "unhandled deserialization for type " ~ T.stringof);
	}
	else static if (is(T == enum))
	{
		switch (jv.type)
		{
			case (JSONType.string):
				ptr = jv.str.to!T;
				break;
			case (JSONType.array):
				// not T.init because it is equal to first enum member, which may
				// not be desirable for bitmask types
				ptr = cast(T) 0;
				foreach (jav; jv.array)
					ptr |= jav.str.to!T;
				break;
			default:
				throw new Exception("json parse type mismatch, expected enum " ~
					"(string or array of strings), got " ~ jv.toString);
		}
	}
	else
		static assert(0, "Unable to deserialize " ~ T.stringof);
}

// gfm vector overload
JSONValue toJson(VecT)(const ref VecT ptr)
	if (isVector!VecT)
{
	return JSONValue(ptr.v);
}

JSONValue toJson(NullableVal)(const ref NullableVal val)
	if (isInstanceOf!(Nullable, NullableVal))
{
	if (val.isNull)
		return JSONValue(null);
	return toJson(val.get);
}

void deserializeJson(VecT: Vector!(Elt, N), Elt, int N)(
	ref VecT ptr, const JSONValue jv)
	//if (__traits(isSame, TemplateOf!VecT, Vector))
	if (isVector!VecT)
{
	foreach (i; 0 .. N)
		deserializeJson(ptr.v[i], jv.array[i]);
}

void deserializeJson(NullT: Nullable!ValT, ValT)(
		ref NullT ptr, const JSONValue jv)
	if (isInstanceOf!(Nullable, NullT))
{
	if (jv.isNull())
		ptr = NullT.init;
	else
	{
		ValT val;
		deserializeJson(val, jv);
		ptr = val;
	}
}

JSONValue[] toJson(ArrayT)(const ArrayT ptr)
	if (isArray!ArrayT && !isSomeString!ArrayT)
{
	JSONValue[] res;
	foreach (el; ptr)
		res ~= toJson(el);
	return res;
}

void deserializeJson(ArrayT: Elt[], Elt)(ref ArrayT ptr, const JSONValue jv)
	if (isArray!ArrayT && !isSomeString!ArrayT)
{
	static if (!isStaticArray!ArrayT)
	{
		ptr = new Elt[jv.array.length];
		// ptr.length = jv.array.length;	// this bugs out in multithreading
	}
	foreach (i, ref el; ptr)
		deserializeJson(el, jv.array[i]);
}

JSONValue toJson(StructT)(const ref StructT ptr)
	if (is(StructT == struct) && !isVector!StructT && !isInstanceOf!(Nullable, StructT))
{
	JSONValue[string] kvpairs;
	static foreach (field; FieldNames!StructT)
	{
		// skip pointer serialization
		static if (isPointer!(TypeOfMember!(StructT, field)))
		{}
		else
		{
			kvpairs[field] = toJson(__traits(getMember, ptr, field));
		}
	}
	return JSONValue(kvpairs);
}

JSONValue toJson(ClassT)(const ClassT ptr)
	if (is(ClassT == class))
{
	if (ptr is null)
		return JSONValue(null);
	JSONValue[string] kvpairs;
	// first serialize fields of current class
	static foreach (field; FieldNames!ClassT)
	{
		// skip pointer serialization
		static if (isPointer!(TypeOfMember!(ClassT, field)))
		{}
		else
		{
			kvpairs[field] = toJson(__traits(getMember, ptr, field));
		}
	}
	static if (BaseClassesTuple!ClassT.length)
	{
		// then all the fields of base classes
		JSONValue parentClassJson =
			toJson(cast(BaseClassesTuple!ClassT[0]) ptr);
		foreach (pair; parentClassJson.object.byKeyValue)
			kvpairs[pair.key] = pair.value;
	}
	return JSONValue(kvpairs);
}

void deserializeJson(StructT)(ref StructT ptr, const JSONValue jv)
	if (is(StructT == struct) && !isVector!StructT && !isInstanceOf!(Nullable, StructT))
{
	static foreach (field; FieldNames!StructT)
	{
		// skip pointer serialization
		static if (isPointer!(TypeOfMember!(StructT, field)))
		{}
		else
		{
			if (field in jv.object)
				deserializeJson(__traits(getMember, ptr, field), jv.object[field]);
		}
	}
}

void deserializeJson(ClassT)(ClassT ptr, const JSONValue jv)
	if (is(ClassT == class))
{
	assert(ptr !is null);
	if (jv.isNull)
		return;
	// start with base class fields
	static if (BaseClassesTuple!ClassT.length)
	{
		// then all the fields of base classes
		deserializeJson(cast(BaseClassesTuple!ClassT[0]) ptr, jv);
	}
	// then current class fields
	static foreach (field; FieldNames!ClassT)
	{
		// skip pointer serialization
		static if (isPointer!(TypeOfMember!(ClassT, field)))
		{}
		else
		{
			if (field in jv.object)
				deserializeJson(__traits(getMember, ptr, field), jv.object[field]);
		}
	}
}

void deserializeJson(ClassT)(ref ClassT ptr, const JSONValue jv)
	if (is(ClassT == class))
{
	if (ptr is null)
		ptr = new ClassT();
	assert(ptr !is null);
	if (jv.isNull)
		return;
	// start with base class fields
	static if (BaseClassesTuple!ClassT.length)
	{
		// then all the fields of base classes
		deserializeJson(cast(BaseClassesTuple!ClassT[0]) ptr, jv);
	}
	// then current class fields
	static foreach (field; FieldNames!ClassT)
	{
		// skip pointer serialization
		static if (isPointer!(TypeOfMember!(ClassT, field)))
		{}
		else
		{
			if (field in jv.object)
				deserializeJson(__traits(getMember, ptr, field), jv.object[field]);
		}
	}
}


unittest
{
	class A
	{
		int a = 2;
	}

	class B: A
	{
		int b = 3;
	}

	class C: B
	{
		string c = "asdf";
	}

	C c = new C();
	c.b = 4;
	c.a = 1;
	string serializationResult = c.toJson().toPrettyString();
	info(serializationResult);
	C c2 = new C();
	assert(c2.a != c.a);
	assert(c2.b != c.b);
	deserializeJson(c2, parseJSON(serializationResult));
	info(c2);
	assert(c2.a == c.a);
	assert(c2.b == c.b);
}

unittest
{
	enum EnumTestT
	{
		enum1 = 1,
		enum2 = 2,
		enum4 = 4
	}

	enum SimpleEnum
	{
		e1,
		e2
	}

	struct TestS
	{
		int a = 3;
		double b = 7.00000000000003;
		bool logical = true;
		string str = "asdf";
		float[] floatVec = [1.0f, -3.14f, 0.0f];
		float[3] staticArr = [-1.0f, 0.0f, 7.0f];
		vec2f someVector = vec2f(42.0f, 9.0f);
		EnumTestT enumField = EnumTestT.enum2 | EnumTestT.enum4;
		SimpleEnum simpleEnum = SimpleEnum.e1;
	}

	TestS t;
	string serializationResult = t.toJson().toPrettyString();
	info(serializationResult);

	t.a = 2;
	t.b = 6.0;
	t.logical = false;
	t.str = "sadsad";
	t.floatVec = [];
	t.someVector = vec2f.init;
	t.enumField = EnumTestT.enum1;
	t.simpleEnum = SimpleEnum.e2;
	t.staticArr = [0.0f, 0.0f, 0.0f];

	deserializeJson(t, parseJSON(serializationResult));
	info(t);
	string serializationResult2 = t.toJson().toPrettyString();
	info(serializationResult2);
	assert (serializationResult == serializationResult2);
}