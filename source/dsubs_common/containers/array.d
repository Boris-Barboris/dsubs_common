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
module dsubs_common.containers.array;

import std.functional : unaryFun;
import std.algorithm: equal;

@safe:

/// Remove first element wich satisfies predicate 'pred' in array 'arr'.
/// Returns true if it was found.
bool removeFirst(alias pred, T)(ref T[] arr)
{
	for (size_t i = 0; i < arr.length; i++)
		if (unaryFun!pred(arr[i]))
		{
			for (size_t j = i + 1; j < arr.length; j++)
				arr[j - 1] = arr[j];
			arr.length -= 1;
			return true;
		}
	return false;
}

/// Remove first occurence of 'el' in array 'arr'.
/// Returns true it was found. This version uses 'is' comparator.
bool removeFirst(T)(ref T[] arr, T el)
{
	for (size_t i = 0; i < arr.length; i++)
		if (arr[i] is el)
		{
			for (size_t j = i + 1; j < arr.length; j++)
				arr[j - 1] = arr[j];
			arr.length -= 1;
			return true;
		}
	return false;
}

unittest
{
	int[] a = [2, 3, 4];
	assert(a.removeFirst(3));
	assert(a.equal([2, 4]));
}

/// Remove first occurence of 'el' in array 'arr', return true if
/// it was found. This version uses 'is' comparator and does not preserve
/// element relative order.
bool removeFirstUnstable(T)(ref T[] arr, T el)
{
	for (size_t i = 0; i < arr.length; i++)
		if (arr[i] is el)
		{
			arr[i] = arr[$-1];
			arr.length -= 1;
			return true;
		}
	return false;
}
