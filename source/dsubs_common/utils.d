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
module dsubs_common.utils;

public import std.experimental.logger: info, trace, error, warning;

import std.math: isNaN, isInfinity;
import std.exception: enforce;


/// Standard std-like exception constructors
mixin template ExceptionConstructors()
{
	@safe pure nothrow this(string message,
							Throwable next,
							string file =__FILE__,
							size_t line = __LINE__)
	{
		super(message, next, file, line);
	}

	@safe pure nothrow this(string message,
							string file =__FILE__,
							size_t line = __LINE__,
							Throwable next = null)
	{
		super(message, file, line, next);
	}
}


auto validateFloat(T)(const T val)
	if (is(T == float) || is(T == double))
{
	enforce(!isNaN(val), "NaN poisoning");
	enforce(!isInfinity(val), "infinity poisoning");
	return val;
}