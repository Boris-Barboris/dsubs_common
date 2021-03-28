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
module dsubs_common.api.encryption;

import crypto.rsa;
public import crypto.rsa: RSAKeyInfo, RSA;


// Public key for vanilla Boris-Barboris server (borisbarboris.duckdns.org).
// Used only to ensure that cleartext password does not hit the network.
// Does not ensure authencity of backend server, but fake server will not be able
// to decode the password.
private immutable string backendPubKey = `AAAAQIhNNOl1mtHa10rEmT2cNlHRPpPnRZjbcKDVkxQ632xXvalu5FR+TBVntVprWNSWdU8+8eU9NEZTQM2J2+XCzwH+mw==`;

private RSAKeyInfo backendPubKeyInfo;
private bool pubKeyInited = false;

immutable(ubyte)[] encrypt(string data)
{
	if (!pubKeyInited)
	{
		// TLS
		backendPubKeyInfo = RSA.decodeKey(backendPubKey);
		pubKeyInited = true;
	}
	return cast(immutable(ubyte)[]) RSA.encrypt(backendPubKeyInfo, cast(ubyte[]) data);
}

string decrypt(ubyte[] data, RSAKeyInfo* privKeyInfo)
{
	return cast(string) RSA.decrypt(*privKeyInfo, data);
}

unittest
{
	import std.stdio;
	import std.conv: to;

	RSAKeyPair pair = RSA.generateKeyPair(512);
	writeln(pair);
	auto puk = RSA.decodeKey(pair.publicKey);
	auto prk = RSA.decodeKey(pair.privateKey);

	for(int i = 0; i < 16; i++)
	{
		string data = backendPubKey;
		ubyte[] en = RSA.encrypt(puk, cast(ubyte[]) data);
		ubyte[] de = RSA.decrypt(prk, en);
		if (!(cast(string) de == data))
		{
			writeln("crashed on iteration ", i);
			writeln(cast(string) de);
			assert(0);
		}
	}
}
