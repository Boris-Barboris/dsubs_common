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
module dsubs_common.network.listener;

import std.socket;

import dsubs_common.utils;


struct TcpServer
{
	string listenAddr;
	ushort port;
	// TODO: encryption and cert stuff
}

/// Create TCP listener socket
Socket listenTcp(TcpServer settings)
{
	Address addr = parseAddress(settings.listenAddr, settings.port);
	Socket listenSock = new Socket(AddressFamily.INET, SocketType.STREAM, ProtocolType.IP);
	scope(failure) listenSock.close();
	listenSock.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, false);
	listenSock.bind(addr);
	listenSock.listen(16);
	info("Serving TCP on ", addr);
	return listenSock;
}

/// Serve Tcp connection requests in caller thread. To abort the infinite loop, close
/// the listenSocket.
void serveTcp(Socket listenSock, scope void delegate(Socket) onAccept)
{
	scope(exit) listenSock.close();
	try
	{
		while (true)
		{
			Socket s = listenSock.accept();
			info("TCP peer connected from ", s.remoteAddress.toAddrString());
			onAccept(s);
		}
	}
	catch (SocketAcceptException) {}
}