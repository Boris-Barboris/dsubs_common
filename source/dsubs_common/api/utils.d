/*
DSubs
Copyright (C) 2017-2021 Baranin Alexander

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
module dsubs_common.api.utils;

import std.conv: to;

import dsubs_common.utils: ExceptionConstructors;


@safe:


/// UDA to decorate arrays and specify upper length limit.
struct MaxLenAttr
{
	int maxLength = 4096;
}

/// UDA to decorade mesages that are transparently compressed.
struct Compressed {}

class ProtocolException: Exception
{
	mixin ExceptionConstructors;
}

/// Thrown on marshalling\demarshalling of messages that violate array
/// length restrictions.
class MaxLenExceeded: ProtocolException
{
	int actualLength;
	int maxLength;

	private static string getMsg(int actual, int max)
	{
		return "max length " ~ max.to!string ~ ", actual " ~ actual.to!string;
	}

	this(int actual, int max, string file = __FILE__,
		size_t line = __LINE__, Throwable next = null)
	{
		super(getMsg(actual, max), file, line, next);
		actualLength = actual;
		maxLength = max;
	}

	this(int actual, int max, Throwable next, string file = __FILE__,
		size_t line = __LINE__)
	{
		super(getMsg(actual, max), file, line, next);
		actualLength = actual;
		maxLength = max;
	}
}