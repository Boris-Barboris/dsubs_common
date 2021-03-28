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
module dsubs_common.containers.circqueue;


/// Fixed-capacity circular buffer
struct CircQueue(T, bool canOverwrite = false)
{
	private
	{
		T[] arr;
		size_t ifront = 0;
		size_t len = 0;
	}

	this(size_t size)
	{
		assert(size > 0);
		arr.length = size;
	}

	/// Number of elements waiting in the queue
	@property size_t length() const { return len; }

	@property size_t capacity() const { return arr.length; }

	/// Oldest element in the queue
	@property ref T front()
	{
		assert(len > 0);
		return arr[ifront];
	}

	void popFront()
	{
		assert(len > 0);
		arr[ifront] = T.init;
		ifront = (ifront + 1) % capacity;
		len--;
	}

	/// returns reference to the inserted value
	ref T pushBack(T val)
	{
		static if (!canOverwrite)
			assert(len < capacity);
		size_t backIdx = (ifront + len) % capacity;
		arr[backIdx] = val;
		if (len < arr.length)
			len++;
		else
			ifront = (ifront + 1) % capacity;	// front is evicted
		return arr[backIdx];
	}

	/// Get reference to idx'th element, counting from the back of the queue
	@property ref T fromBack(size_t idx)
	{
		assert(idx < len);
		assert(ifront + len >= idx + 1);
		idx = (ifront + len - idx - 1) % capacity;
		return arr[idx];
	}
}