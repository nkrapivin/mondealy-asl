state("Mondealy")
{
	// Release build
}

state("Runner")
{
	// Development in-editor build
}

startup
{
	print("[mdly]: From startup");
	return true;
}

init
{
	print("[mdly]: From init");
	
	// -+=*(&!@#$%^Mondealy^%$#@!&)*=+-
	// generated at runtime from a GML array of doubles to prevent
	// accidental constant search or overlap...
	var pattern = new byte[] {45,43,61,42,40,38,33,64,35,36,37,94,77,111,110,100,101,97,108,121,94,37,36,35,64,33,38,41,42,61,43,45};
	var scanTarget = new SigScanTarget(pattern);
	
	print("[mdly]: Init before scan");
	
	Func<bool> scanIteration = () => {
		foreach (var page in game.MemoryPages()) {
			var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
			// should be aligned by 16 or 32 bytes...
			var bufferPtr = scanner.Scan(scanTarget, 16);
			if (bufferPtr == IntPtr.Zero) {
				continue;
			}
			
			print("[mdly]: Found magic buffer at address " + bufferPtr.ToString());
			
			vars.pMagic = new StringWatcher(new DeepPointer(bufferPtr), ReadStringType.UTF8, 32);
			vars.pVersion = new StringWatcher(new DeepPointer(bufferPtr + 32), ReadStringType.UTF8, 32);
			vars.pConfig = new StringWatcher(new DeepPointer(bufferPtr + 64), ReadStringType.UTF8, 32);
			vars.pStoryStage = new MemoryWatcher<double>(new DeepPointer(bufferPtr + 96));
			vars.pChapter = new MemoryWatcher<double>(new DeepPointer(bufferPtr + 104));
			vars.pPlayTime = new MemoryWatcher<double>(new DeepPointer(bufferPtr + 112));
			vars.pFpsSetting = new MemoryWatcher<double>(new DeepPointer(bufferPtr + 120));
			vars.pRoomName = new StringWatcher(new DeepPointer(bufferPtr + 128), ReadStringType.UTF8, 64);
			
			vars.watchers = new MemoryWatcherList() {
				vars.pMagic,
				vars.pVersion,
				vars.pConfig,
				vars.pStoryStage,
				vars.pChapter,
				vars.pPlayTime,
				vars.pFpsSetting,
				vars.pRoomName
			};
			
			print("[mdly]: Initialized pointers to magic stuff");
			return true;
		}

		print("[mdly]: Scan iteration failed");
		return false;
	};
	
	vars.scanOk = false;
	var attempt = 0;
	while (!scanIteration()) {
		// ???
		++attempt;
		if (attempt > 1000) {
			print("[mdly]: Init failed, no --livesplit launch parameter?");
			return false;
		}
	}
	
	print("[mdly]: Init done in " + attempt.ToString() + " attempts");
	refreshRate = 60; // default fps refresh rate
	// that will be updated in update action when the game fully loads
	// (either stays at 60 or sets to Mondealy's value)
	vars.scanOk = true;
	return true;
}

exit
{
	print("[mdly]: From exit");
	// currently we don't really need any shutdown logic for a process
	timer.IsGameTimePaused = true; // this should pause the timer if the game crashed I hope?
	return true;
}

shutdown
{
	print("[mdly]: From shutdown");
	// same applies for this action
	return true;
}

update
{
	if (!vars.scanOk) {
		return false;
	}
	
	vars.watchers.UpdateAll(game);
	
	// config and version never change at all
	// but all memwatch vars shall only be accessed in update...
	
	if (vars.pConfig.Changed) {
		print("[mdly]: Build Config = " + vars.pConfig.Current);
	}
	
	if (vars.pVersion.Changed) {
		print("[mdly]: Game Version = " + vars.pVersion.Current);
	}
	
	// make sure refreshrate is set to Mondealy's fps for more accurate results
	if (vars.pFpsSetting.Current != (double)refreshRate) {
		refreshRate = (int)vars.pFpsSetting.Current;
		print("[mdly]: Set new refresh rate = " + refreshRate);
	}
	
	// just for debugging...
	if (vars.pRoomName.Changed) {
		print("[mdly]: New room name = " + vars.pRoomName.Current);
	}
	
	return true;
}

split
{
		// split on chapter change or when entering the r_credits room
	return
		(vars.pChapter.Changed && vars.pChapter.Current > 0.0) ||
		(vars.pRoomName.Changed && vars.pRoomName.Current == "r_credits");
}

start
{
		// story stage is -5 (new game init) or we are in r_mondealy_intro (forest tavern)
	return
		(vars.pStoryStage.Current == -5.0 || vars.pRoomName.Current == "r_mondealy_intro");
}

reset
{
		// we're in the menu, IGT isn't running anyway
	return
		(vars.pRoomName.Current == "r_menu");
}

isLoading
{
		// ATTENTION: DO WE REALLY REALLY NEED THIS????
		// THIS WILL FORCE LIVESPLIT TO ALWAYS USE MONDEALY'S TIMER (which may not be accurate!)
		// Maybe make this a setting?
	return true;
}

gameTime
{
		// pulls directly from the current global IGT
	return
		(TimeSpan.FromSeconds(vars.pPlayTime.Current));
}

