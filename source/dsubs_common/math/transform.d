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
module dsubs_common.math.transform;

import std.algorithm;
import std.math;
import std.range;
import std.conv: to;

public import gfm.math.matrix;
public import gfm.math.vector;

import dsubs_common.containers.array;
import dsubs_common.math.angles;


/** Hierarchical transform.
Dsubs world is a 2D space. World X axis is directed to
the right, Y axis - up. Positive angle is counter-clockwise. Zero rotation
angle is aligned with Y axis - 0 rotation is directed to the North (up). */
class Transform2D
{
	private
	{
		// Individual components
		vec2d m_scale = vec2d(1.0, 1.0);
		double m_rotation = 0.0;	// radians
		vec2d m_position = vec2d(0.0, 0.0);

		mat3x3d m_localTransform;
		mat3x3d m_worldCache;		// cached value of world-coordinates transform
		mat3x3d m_inverseCache;		// inverted world matrix
		Transform2D m_parent;
		Transform2D[] m_children;
	}

	this() {}

	this(vec2d pos)
	{
		position = pos;
	}

	this(vec2d pos, double rot)
	{
		position = pos;
		rotation = rot;
	}

	protected
	{
		bool m_dirty = true;
		bool m_inverseDirty = true;
	}

	override string toString()
	{
		return "Transform2D: m_pos " ~ m_position.to!string ~
			" m_rot " ~ m_rotation.to!string ~ " m_scale " ~ m_scale.to!string ~
			" m_dirty " ~ m_dirty.to!string ~ " m_inverseDirty " ~ m_inverseDirty.to!string;
	}

	/// Propagate the `dirty` signal from parent
	protected void propagate()
	{
		m_dirty = true;
		m_inverseDirty = true;
		foreach (t; m_children)
			t.propagate();
	}

	void rebuild()
	{
		if (!m_dirty)
			return;
		m_localTransform = mat3x3d.scaling(m_scale);
		m_localTransform = mat3x3d.rotateZ(m_rotation) * m_localTransform;
		m_localTransform = mat3x3d.translation(m_position) * m_localTransform;
		if (m_parent)
			m_worldCache = m_parent.world * m_localTransform;
		else
			m_worldCache = m_localTransform;
		m_dirty = false;
	}

	private void calculateInverse()
	{
		m_inverseCache = world.inverse();
		m_inverseDirty = false;
	}

	final void addChild(Transform2D child)
	{
		assert(child !is this);
		m_children ~= child;
		child.m_parent = this;
		child.propagate();
	}

	final void removeChild(Transform2D kid)
	{
		if (m_children.removeFirstUnstable(kid))
		{
			kid.m_parent = null;
			kid.propagate();
		}
	}

	/// disconnects all children from this transform
	final void clearChildren()
	{
		foreach (kid; m_children)
		{
			kid.m_parent = null;
			kid.propagate();
		}
		m_children.length = 0;
	}

	final @property Transform2D parent() { return m_parent; }

	private final @property void parent(Transform2D val)
	{
		m_parent = val;
		propagate();
	}

	/// Eagerly rebuilds matrices from changed components
	final void ensureNotDirty()
	{
		if (m_dirty)
			rebuild();
		if (m_inverseDirty)
			calculateInverse();
	}

	/// transformation from local to parent (or world if no parent) reference frame
	final @property ref const(mat3x3d) local()
	{
		if (m_dirty)
			rebuild();
		return m_localTransform;
	}

	/// transformation from local to global(world) reference frame
	final @property ref const(mat3x3d) world()
	{
		// lazy world transform recalculation
		if (m_dirty)
			rebuild();
		return m_worldCache;
	}

	/// ditto
	final @property ref const(mat3x3d) world() const
	{
		assert(!m_dirty);
		return m_worldCache;
	}

	/// inverse world transformation
	final @property ref const(mat3x3d) iworld()
	{
		// Inverse is rarely needed, so we don't recalculate for all transforms,
		// only for those that use it.
		if (m_inverseDirty)
			calculateInverse();
		return m_inverseCache;
	}

	/// returns local scale
	final @property vec2d scale() const { return m_scale; }

	/// sets local scale
	final @property void scale(vec2d val)
	{
		assert(!isNaN(val.x));
		assert(!isNaN(val.y));
		m_scale = val;
		propagate();
	}

	/// returns local rotation
	final @property double rotation() const { return m_rotation; }

	/// sets local rotation
	final @property void rotation(double val)
	{
		assert(!isNaN(val));
		//m_rotation = clampAngle(val);
		m_rotation = val;
		propagate();
	}

	/// returns world-space rotation
	final @property double wrotation()
	{
		if (m_parent is null)
			return m_rotation;
		return m_parent.wrotation + m_rotation;
	}

	final @property double wrotation() const
	{
		if (m_parent is null)
			return m_rotation;
		return m_parent.wrotation + m_rotation;
	}

	/// returns local translation
	final @property vec2d position() const { return m_position; }

	/// sets local translation
	final @property void position(vec2d val)
	{
		assert(!isNaN(val.x));
		assert(!isNaN(val.y));
		m_position = val;
		propagate();
	}

	/// returns world translation
	final @property vec2d wposition()
	{
		if (m_parent is null)
			return m_position;
		return world.transformPoint(vec2d(0.0, 0.0));
	}

	/// ditto
	final @property vec2d wposition() const
	{
		if (m_parent is null)
			return m_position;
		return world.transformPoint(vec2d(0.0, 0.0));
	}

	/// world-space unit forward vector
	final @property vec2d wforward()
	{
		return world.transformDirection(vec2d(0.0, 1.0));
	}

	/// world-space unit left vector
	final @property vec2d wleft()
	{
		return world.transformDirection(vec2d(-1.0, 0.0));
	}

	final @property const(Transform2D[]) children() const { return m_children; }

	/// Initialize transform by individual components, applied in semantic order
	final void fromComponents(vec2d scale, double rotation, vec2d position)
	{
		assert(!isNaN(scale.x));
		assert(!isNaN(scale.y));
		assert(!isNaN(position.x));
		assert(!isNaN(position.y));
		assert(!isNaN(rotation));
		m_scale = scale;
		m_rotation = rotation;
		m_position = position;
		propagate();
	}

	/// Reset local transformation matrix to identity transform
	final void resetLocal()
	{
		fromComponents(vec2d(1.0, 1.0), 0.0, vec2d(0.0, 0.0));
	}
}


vec2d transformPoint()(auto ref const(mat3x3d) t, vec2d point)
{
	vec3d homog = vec3d(point[0], point[1], 1.0);
	vec3d res = t * homog;
	return vec2d(res[0] / res[2], res[1] / res[2]);
}

vec2d transformDirection()(auto ref const(mat3x3d) t, vec2d dir)
{
	vec3d homog = vec3d(dir[0], dir[1], 0.0);
	vec3d res = t * homog;
	return vec2d(res[0], res[1]).normalized;
}

double transformAngle()(auto ref const(mat3x3d) t, double angle)
{
	vec2d v2 = vec2d(-sin(angle), cos(angle));
	vec2d dir = transformDirection(t, v2);
	return courseAngle(dir);
}


unittest
{
	Transform2D parent = new Transform2D;
	Transform2D child = new Transform2D;
	parent.addChild(child);
	parent.addChild(child);
	assert(walkLength(parent.children[]) == 2);
	assert(child.parent is parent);
	parent.removeChild(child);
	assert(walkLength(parent.children[]) == 1);
	assert(child.parent is null);
	parent.removeChild(child);
	assert(walkLength(parent.children[]) == 0);
	assert(child.parent is null);
}

unittest
{
	Transform2D parent = new Transform2D;
	Transform2D child = new Transform2D;
	parent.addChild(child);
	assert(!isNaN(parent.wposition.x));
	assert(!isNaN(child.wposition.x));
}

unittest
{
	auto t = new Transform2D;
	t.rotation = -PI_2;
	assert(abs(t.world.transformAngle(0.0) + PI_2) < 1e-6);
	assert(abs(t.world.transformAngle(PI_2)) < 1e-6);
	assert(abs(t.iworld.transformAngle(-PI_2)) < 1e-6);
	assert(angleDist(t.world.transformAngle(-PI_2) + PI, 0.0) < 1e-6);
}

unittest
{
	//import std.stdio;

	auto t = new Transform2D;
	t.scale = vec2d(1.0, 1.0);
	const vec2d point = vec2d(1.0, 0.0);
	vec2d tpoint = t.world.transformPoint(point);
	assert(abs(tpoint.x - 1.0) < 1e-6);
	assert(abs(tpoint.y - 0.0) < 1e-6);
	t.rotation = PI_2;
	tpoint = t.world.transformPoint(point);
	assert(abs(tpoint.x - 0.0) < 1e-6);
	assert(abs(tpoint.y - 1.0) < 1e-6);
	t.position = vec2d(3.0, 3.0);
	tpoint = t.world.transformPoint(point);
	assert(abs(tpoint.x - 3.0) < 1e-6);
	assert(abs(tpoint.y - 4.0) < 1e-6);
	auto t_child = new Transform2D;
	t_child.position = vec2d(1.0, 0.0);
	t_child.rotation = PI_2;
	t.addChild(t_child);
	tpoint = t_child.world.transformPoint(point);
	vec2d wpospoint = t_child.wposition;
	vec2d wforward = t_child.wforward;
	assert(abs(tpoint.x - 2.0) < 1e-6);
	assert(abs(tpoint.y - 4.0) < 1e-6);
	assert(abs(wpospoint.x - 3.0) < 1e-6);
	assert(abs(wpospoint.y - 4.0) < 1e-6);
	assert(abs(angleDist(t_child.world.transformAngle(0.0), PI)) < 1e-6);
	assert(abs(angleDist(t_child.wrotation, PI)) < 1e-6);
	assert(abs(wforward.x - 0.0) < 1e-6);
	assert(abs(wforward.y + 1.0) < 1e-6);
	t.removeChild(t_child);
	tpoint = t_child.world.transformPoint(point);
	wpospoint = t_child.wposition;
	wforward = t_child.wforward;
	assert(abs(tpoint.x - 1.0) < 1e-6);
	assert(abs(tpoint.y - 1.0) < 1e-6);
	assert(abs(wpospoint.x - 1.0) < 1e-6);
	assert(abs(wpospoint.y - 0.0) < 1e-6);
	assert(abs(wforward.x + 1.0) < 1e-6);
	assert(abs(wforward.y - 0.0) < 1e-6);
}
