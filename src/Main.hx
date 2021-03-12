package;
import hxmod.ModPlayer;
import js.Browser;

/**
 * ...
 * @author Tommy S.
 */
class Main 
{
	/////////////////////////////////////////////////////////////////////////////////////
	
	static function main() 
	{
		var m = new ModPlayer();
		m.load("mod.overload");
		//m.load("mod.livin_insanity");
		//m.load("mod.enigma");
		//m.load("SILENTS.MOD");
		
		Browser.document.getElementById("startButton").addEventListener("click", function()	{ m.play();	});
		Browser.document.getElementById("stopButton").addEventListener("click", function()	{ m.stop();	});
	}
	
	/////////////////////////////////////////////////////////////////////////////////////
	
}