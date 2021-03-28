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
module dsubs_common.proftimer;

import core.time;
import std.stdio;

import dsubs_common.utils;


/// Simple cooperative profiling struct
struct ProfTimer
{
	alias TimeT = typeof(MonoTime.currTime());

	struct Interval
	{
		string name;
		TimeT start;
		TimeT end;
	}

	private
	{
		Interval total;
		Interval[] subStack;
		Interval[] m_readySubIntervals;
		int lastUnclosed = -1;
	}

	void start()
	{
		total.start = MonoTime.currTime();
		m_readySubIntervals.length = 0;
	}

	void start(string name)
	{
		Interval newInt = Interval(name, MonoTime.currTime());
		subStack ~= newInt;
	}

	void stopLast()
	{
		assert (subStack.length > 0);
		subStack[$-1].end = MonoTime.currTime();
		m_readySubIntervals ~= subStack[$-1];
		subStack.length--;
	}

	void stop()
	{
		total.end = MonoTime.currTime();
		subStack.length = 0;
	}

	void printResult()
	{
		foreach (pair; m_readySubIntervals)
		{
			trace("ProfTimer: ", pair.name, " ",
				(pair.end - pair.start).total!"usecs", "usecs");
		}
		trace("ProfTimer total: ", (total.end - total.start).total!"usecs", "usecs");
	}

	const(Interval)[] readySubIntervals() const
	{
		return m_readySubIntervals;
	}

	auto getTotalUsecs() const
	{
		return (total.end - total.start).total!"usecs";
	}
}