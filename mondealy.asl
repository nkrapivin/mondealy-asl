state("Mondealy", "UDP Splitter")
{
	// lol.
	byte doNothingPlzIgnore : "Mondealy.exe", 0x10000;
}

startup
{
	// -- ACTUAL MESSAGE HANDLERS: -- //
	Action<object, string, string, bool, double> onInitMessage =
	(dvars_, buildConfig, versionString, isDemo, osType) => {
		// ????
		dynamic dvars = dvars_;
		print("[mdly]: Got init message! version=" + versionString + ",config=" + buildConfig);
	};
	Action<object, double, double, double, double, string, string, string> onBeatMessage =
	(dvars_, storyStage, storyStagePrevious, chapter, playTime, roomName, roomPrevName, messageType) => {
		dynamic dvars = dvars_;
		dvars.oldChapterNum = dvars.chapterNum;
		dvars.chapterNum = chapter;
		dvars.roomPrevName = dvars.roomName;
		dvars.roomName = roomName;
		dvars.igt = playTime;
		dvars.prevStoryStage = dvars.storyStage;
		dvars.storyStage = storyStage;
		
		// hackfix: ignore these rooms entirely, bad bad bad!
		if (roomName == "r_pre_menu" || dvars.roomPrevName == "r_pre_menu" || roomName == "r_user_limbo") {
			print("[mdly]: Ignoring start rooms >:(");
			return /* lol */;
		}
		
		// -5 new_game_init story stage
		if (dvars.storyStage == -5.0 && dvars.prevStoryStage != -5.0) {
			dvars.startQueued = true;
			dvars.resetQueued = false;
			dvars.splitQueued = false;
			print("[mdly]: Start is queued!");
		}
		
		if (dvars.chapterNum != dvars.oldChapterNum) {
			dvars.splitQueued = true;
			print("[mdly]: Split is queued!");
		}
		
		if (messageType == "inputs_dont_matter_anymore") {
			dvars.splitQueued = true;
			print("[mdly]: Split (from last Riley dialogue) is queued!");
		}
		
		if (dvars.roomName == "r_menu" && dvars.roomPrevName != "r_menu") {
			dvars.resetQueued = true;
			print("[mdly]: Reset is queued! room=" + dvars.roomName + ", prev=" + dvars.roomPrevName);
		}
		print("[mdly]: Got beat message of type " + messageType);
	};
	
	uint[] tbl = new uint[256];
	uint poly = 0xEDB88320;
	for (uint idx = 0u; idx < 256; idx++) {
		uint val = idx;
		for (uint bit = 8u; bit != 0; bit--) {
			val = ((val & 1) == 0) ? (val >> 1) : ((val >> 1) ^ poly);
		}
		tbl[idx] = val;
	}
	
	Func<byte[], object, string> ReadCString = (bytes, dvars_) => {
		dynamic dvars = dvars_;
		int start = (int)dvars.pos;
		int end = start;
		while (bytes[end] != 0 && end < bytes.Length)
			++end;
		string str = System.Text.Encoding.UTF8.GetString(bytes, start, end - start);
		dvars.pos = end + 1;
		return str;
	};
	Func<byte[], int, int, object, uint> CalcCRC = (buffer, offset, size, dvars_) => {
		dynamic dvars = dvars_;
		print("[mdly]: Inside CalcCRC");
		uint[] table = (uint[])dvars.crcTable;
		uint crc = uint.MaxValue;
		if (size > 0) {
			if (offset < 0)
				offset = 0;
			int end = offset + size;
			if (end > buffer.Length)
				end = buffer.Length;
			for (int pos = offset; pos < end; ++pos) {
				crc = (crc >> 8) ^ table[(crc ^ buffer[pos]) & 0xFF];
			}
		}
		// GameMaker doesn't ~ by default, but Mondealy does
		// to keep it compatible with other CRC32 implementations...
		crc = ~crc;
		print("[mdly]: Packet CRC = 0x" + crc.ToString("X8"));
		return crc;
	};
	Action<byte[], object> onUdpBytes = (udpBytes, dvars_) => {
		dynamic dvars = dvars_;
		print("[mdly]: Inside onUdpBytes");
		// sanity checks:
		{
			if (udpBytes.Length < 14)
				throw new Exception("Too few bytes, expected at least 14 got " + udpBytes.Length.ToString());
			uint magic = BitConverter.ToUInt32(udpBytes, 0);
			if (magic != 0x594C444D)
				throw new Exception("Invalid magic, expected 0x594C444D got 0x" + magic.ToString("X8"));
			uint crc32 = BitConverter.ToUInt32(udpBytes, 4);
			uint sizeOfData = BitConverter.ToUInt32(udpBytes, 8);
			if (sizeOfData + 8 < udpBytes.Length)
				throw new Exception("Invalid size, expected at least " + (sizeOfData + 8).ToString() + " got " + udpBytes.Length.ToString());
			uint realCrc32 = CalcCRC(udpBytes, 8, udpBytes.Length - 8, dvars);
			if (crc32 != realCrc32)
				throw new Exception("Invalid CRC32, expected 0x" + crc32.ToString("X8") + " got 0x" + realCrc32.ToString("X8"));
		}
		
		dvars.pos = 12; // useful data starts at 12th byte
		string message = ReadCString(udpBytes, dvars);
		dvars.prevMessageType = dvars.messageType;
		dvars.messageType = message;
		if (message == "obj_core_create") {
			// init
			string buildConfig = ReadCString(udpBytes, dvars);
			string versionString = ReadCString(udpBytes, dvars);
			bool isDemo = BitConverter.ToDouble(udpBytes, (int)dvars.pos) > 0.5; dvars.pos += 8;
			double osType = BitConverter.ToDouble(udpBytes, (int)dvars.pos); dvars.pos += 8;
			dvars.onInitMessage(dvars, buildConfig, versionString, isDemo, osType);
		} else {
			// beat
			double storyStage = BitConverter.ToDouble(udpBytes, (int)dvars.pos); dvars.pos += 8;
			double storyStagePrevious = BitConverter.ToDouble(udpBytes, (int)dvars.pos); dvars.pos += 8;
			double chapter = BitConverter.ToDouble(udpBytes, (int)dvars.pos); dvars.pos += 8;
			double playTime = BitConverter.ToDouble(udpBytes, (int)dvars.pos); dvars.pos += 8;
			string roomName = ReadCString(udpBytes, dvars);
			string roomPrevName = ReadCString(udpBytes, dvars);
			dvars.onBeatMessage(dvars, storyStage, storyStagePrevious, chapter, playTime, roomName, roomPrevName, message);
		}
	};
	AsyncCallback asyncCallback = (IAsyncResult ar) => {
		object dvars_ = ar.AsyncState;
		dynamic dvars = dvars_;
		print("[mdly]: Inside IAR");
		System.Net.Sockets.UdpClient uc = (System.Net.Sockets.UdpClient)dvars.udpClient;
		if (uc == null) {
			print("[mdly]: Got cancelled inside IAR :'(");
			return /* lol */;
		}
		AsyncCallback ac = (AsyncCallback)dvars.asyncCallback;
		Action<byte[], object> cb = (Action<byte[], object>)dvars.handler;
		
		System.Net.IPEndPoint ipEndPoint = null;
		byte[] bytes = null;
		try {
			bytes = uc.EndReceive(ar, ref ipEndPoint);
		} catch {
			print("[mdly]: EndReceive threw, we're disposed");
			return /* lol */;
		}
		print("[mdly]: After EndReceive");
		cb(bytes, dvars);
		uc.BeginReceive(ac, dvars);
	};
	
	vars.udpClient = (System.Net.Sockets.UdpClient)null;
	vars.asyncCallback = asyncCallback;
	vars.handler = onUdpBytes;
	vars.crcTable = tbl;
	vars.onInitMessage = onInitMessage;
	vars.onBeatMessage = onBeatMessage;
	vars.pos = 12;
	
	
	vars.chapterNum = 0;
	vars.oldChapterNum = 0;
	vars.roomName = "";
	vars.roomPrevName = "";
	vars.igt = 0.0;
	vars.messageType = "";
	vars.prevMessageType = "";
	vars.storyStage = 0.0;
	vars.prevStoryStage = 0.0;
	
	vars.splitQueued = false;
	vars.startQueued = false;
	vars.resetQueued = false;
	print("[mdly]: Startup complete");
}

init
{
	print("[mdly]: Before init");
	if (((System.Net.Sockets.UdpClient)vars.udpClient) != null) {
		((System.Net.Sockets.UdpClient)vars.udpClient).Dispose();
		vars.udpClient = (System.Net.Sockets.UdpClient)null;
		print("[mdly]: Disposed old udpClient instance...");
	}
	
	System.Net.Sockets.UdpClient udpClient = new System.Net.Sockets.UdpClient(19780);
	vars.udpClient = udpClient;
	udpClient.BeginReceive((AsyncCallback)vars.asyncCallback, (object)vars);
	print("[mdly]: After init");
}

split
{
	if (vars.splitQueued) {
		vars.splitQueued = false;
		print("[mdly]: Split is handled!");
		return true;
	}
	
	return false;
}

start
{
	if (vars.startQueued) {
		vars.startQueued = false;
		print("[mdly]: Start is handled!");
		return true;
	}
	
	return false;
}

reset
{
	if (vars.resetQueued) {
		vars.resetQueued = false;
		print("[mdly]: Reset is handled!");
		return true;
	}
	
	return false;
}

exit
{
	print("[mdly]: Disposing udpClient");
	if (((System.Net.Sockets.UdpClient)vars.udpClient) != null) {
		((System.Net.Sockets.UdpClient)vars.udpClient).Dispose();
		vars.udpClient = (System.Net.Sockets.UdpClient)null;
		print("[mdly]: Disposed old udpClient instance...");
	}
	
	// reset these just in case...
	vars.chapterNum = 0;
	vars.oldChapterNum = 0;
	vars.roomName = "";
	vars.roomPrevName = "";
	vars.igt = 0.0;
	vars.messageType = "";
	vars.prevMessageType = "";
	vars.storyStage = 0.0;
	vars.prevStoryStage = 0.0;
	
	vars.splitQueued = false;
	vars.startQueued = false;
	vars.resetQueued = false;
	
	print("[mdly]: Exit complete");
	return true;
}

shutdown
{
	print("[mdly]: Disposing udpClient");
	if (((System.Net.Sockets.UdpClient)vars.udpClient) != null) {
		((System.Net.Sockets.UdpClient)vars.udpClient).Dispose();
		vars.udpClient = (System.Net.Sockets.UdpClient)null;
		print("[mdly]: Disposed old udpClient instance...");
	}
	
	print("[mdly]: Shutdown complete");
	return true;
}
