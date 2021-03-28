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

module dsubs_common.api.constants;

/// Safety limit on message size (bytes)
enum int MAX_MSG_SIZE = 100000000;	// 100 Mb

/// Time type, microseconds (1e-6 seconds)
alias usecs_t = long;