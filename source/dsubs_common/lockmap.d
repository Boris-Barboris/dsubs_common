module dsubs_common.lockmap;

import core.sync.mutex: Mutex;


private final class LockMapMutex
{
	private
	{
		LockMap m_owner;
		string m_key;
	}

	private this(LockMap owner, string key)
	{
		m_owner = owner;
		m_key = key;
	}
}


/// Map of string keys that can be locked on using synchronized statement
class LockMap
{
	private LockMapMutex[string] m_map;

	LockMapMutex get(string key)
	{
		assert(m_map.length < 10000, "unexpected load on m_map");
		synchronized(this)
		{
			LockMapMutex* mut = key in m_map;
			if (mut)
				return *mut;
			LockMapMutex newMut = new LockMapMutex(this, key);
			m_map[key] = newMut;
			return newMut;
		}
	}
}