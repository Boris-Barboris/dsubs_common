module dsubs_common.lockmap;

import core.sync.mutex: Mutex;


final class LockMapMutex: Object.Monitor
{
	private
	{
		LockMap m_owner;
		Mutex m_mut;
		string m_key;
	}

	private this(LockMap owner, string key, Mutex sharedMut)
	{
		m_owner = owner;
		m_mut = sharedMut;
		m_key = key;
	}

	override void lock()
	{
		m_mut.lock();
	}

	override void unlock()
	{
		m_mut.unlock();
		synchronized(m_owner)
		{
			LockMap.KeyCounter* oldCounter = m_key in m_owner.m_map;
			assert(oldCounter);
			assert(oldCounter.count > 0);
			oldCounter.count--;
			if (oldCounter.count == 0)
				m_owner.m_map.remove(m_key);
		}
	}
}

class LockMap
{
	private struct KeyCounter
	{
		Mutex mut;
		int count;
	}

	private KeyCounter[string] m_map;

	LockMapMutex get(string key)
	{
		synchronized(this)
		{
			KeyCounter* counter = key in m_map;
			if (counter)
			{
				counter.count++;
				return new LockMapMutex(this, key, counter.mut);
			}
			KeyCounter newCounter = KeyCounter(new Mutex(), 1);
			m_map[key] = newCounter;
			return new LockMapMutex(this, key, newCounter.mut);
		}
	}
}