package hxmod;

import hxmod.Protracker;
import hxmod.utils.Float32Array;
import hxmod.utils.UInt8Array;
import js.html.XMLHttpRequest;
import js.html.audio.AudioContext;
import js.html.audio.AudioProcessingEvent;
import js.html.audio.BiquadFilterNode;

/**
 * ...
 * @author Tommy S. - Ported from firehawk/tda
 */
class ModPlayer 
{
	/////////////////////////////////////////////////////////////////////////////////////
	
	//===================================================================================
	// Properties
	//-----------------------------------------------------------------------------------
	
	var supportedformats	: Array<String>			= ['mod', 's3m', 'xm'];

	var url					: String				= "";
	var format				: String				= "s3m";

	var state(default, set)	: String				= "initializing..";
	var request				: XMLHttpRequest;

	var loading				: Bool					= false;
	var playing				: Bool					= false;
	var paused				: Bool					= false;
	var repeat				: Bool					= false;

	var separation			: Null<Int>				= 1;
	var mixval				: Float					= 8.0;

	var amiga500			: Bool					= false;

	var filter				: Bool					= false;
	var endofsong			: Bool					= false;

	var autostart			: Bool					= false;
	var bufferstodelay		: Int					= 4; // adjust this if you get stutter after loading new song
	var delayfirst			: Float					= 0;
	var delayload			: Float					= 0;

	var buffer				: Int					= 0;
	var mixerNode			: Dynamic;
	var context				: AudioContext;
	var samplerate			: Float					= 44100;
	var bufferlen			: Int					= 4096;
	var row					: Int;

	// format-specific player
	var player				: Protracker			= null;
	//var player				: Dynamic			= null;

	// read-only data from player class
	var title				: String				= "";
	var signature			: String				= "....";
	var songlen				: Int					= 0;
	var channels			: Int					= 0;
	var patterns			: Int					= 0;
	var samplenames			: Array<String>			= [];		
	var lowpassNode			: BiquadFilterNode;
	var filterNode			: BiquadFilterNode;
	var position			: Int;
	
	public var speed		: Int;
	public var bpm			: Int;
	public var chvu			: Float32Array			= new Float32Array(32);

	// Event callbacks //////////////////////////////////////////////////////////////////
	
	public var onReady		: ()->Void;
	public var onPlay		: ()->Void;
	public var onStop		: ()->Void;

	/////////////////////////////////////////////////////////////////////////////////////
	
	public function new()
	{
	}
	
	/////////////////////////////////////////////////////////////////////////////////////
	
	//===================================================================================
	// Load module from url into local buffer
	//-----------------------------------------------------------------------------------
	
	public function load(url:String):Bool
	{
		// try to identify file format from url and create a new
		// player class for it
		this.url=url;
		var ext=StringTools.trim(url.split('.').pop().toLowerCase());
		if (supportedformats.indexOf(ext) ==-1)
		{
			// unknown extension, maybe amiga-style prefix?
			ext=StringTools.trim(url.split('/').pop().split('.').shift().toLowerCase());
			if (supportedformats.indexOf(ext) ==-1)
			{
				// ok, give up
				return false;
			}
		}
		format=ext;

		switch (ext)
		{
			case 'mod':
				player=new Protracker();
			//case 's3m':
				//player==new Screamtracker();
			//case 'xm':
				//player==new Fasttracker();
			default:
		}

		//player.onReady=loadSuccess;

		state="loading..";
		var request = new XMLHttpRequest();
		request.open("GET", url, true);
		request.responseType = cast "arraybuffer";
		loading = true;
		
		request.onprogress = function(oe)
		{
			state="loading ("+Math.floor(100*oe.loaded/oe.total)+"%)..";
		};
		
		request.onload = function()
		{
			var buffer=new UInt8Array(request.response);
			state="parsing..";
			if (player.parse(buffer))
			{
				// copy static data from player
				title = player.title;
				signature=player.signature;
				songlen=player.songlen;
				channels=player.channels;
				patterns=player.patterns;
				filter=player.filter;
				
				if (context!=null)
					setfilter(filter);
				
				mixval=player.mixval; // usually 8.0, though
				samplenames.resize(32);
				
				for (i in 0...32) 
					samplenames[i]="";
				
				for (i in 0...32) 
				{
					if (format == 'xm' || format == 'it')
					{
						//for (p in 0...player.instrument.length) 
							//samplenames[p] = player.instrument[i].name;
							
						//Not supported yet...only mod for now
					}
					else
					{
						for (p in 0...player.sample.length)
						{
							if (player.sample[i]!=null)
								samplenames[p] = player.sample[i].name;
						}
					}
				}
				
				state="ready.";
				loading = false;
				
				if (onReady!=null)
					onReady();
			
				if (autostart)
					play();
			}
			else
			{
				state="error!";
				loading=false;
			}
		}
		request.send();
		return true;
	}
	
	/////////////////////////////////////////////////////////////////////////////////////
	
	//===================================================================================
	// Play loaded and parsed module with webaudio context
	//-----------------------------------------------------------------------------------
	
	public function play():Bool
	{
		if (loading) 
			return false;
			
		if (player != null)
		{
			if (context == null) 
				createContext();
				
			player.samplerate=samplerate;
			if (context != null)
				setfilter(player.filter);

			if (player.paused)
			{
				player.paused=false;
				return true;
			}

			endofsong=false;
			player.endofsong=false;
			player.paused=false;
			player.initialize();
			player.flags=1+2;
			player.playing=true;
			playing = true;
			
			chvu = new Float32Array(player.channels);
			
			for (i in 0...player.channels) 
				chvu[i]=0.0;
			
			if (onPlay!=null)
				onPlay();

			player.delayfirst=bufferstodelay;
			return true;
		} 
		else
			return false;
	}
	
	// Playback functions ///////////////////////////////////////////////////////////////
	
	// pause playback
	public function pause()
	{
		if (player!=null)
		{
			if (player.paused)
			{
				player.paused=true;
			}
			else
			{
				player.paused=false;
			}
		}
	}

	// stop playback
	public function stop()
	{
		paused=false;
		playing=false;
		if (player != null)
		{
			player.paused=false;
			player.playing=false;
			player.delayload=1;
		}
		
		if (onStop!=null)
			onStop();
	}

	// stop playing but don't call callbacks
	public function stopaudio(st:Bool)
	{
		if (player!=null)
			player.playing=st;
	}


	// jump positions forward/back
	public function jump(step:Int)
	{
		if (player!=null)
		{
			player.tick=0;
			player.row=0;
			player.position+=step;
			player.flags = 1 + 2;
			
			if (player.position < 0)
				player.position=0;
			if (player.position >= player.songlen)
				stop();
		}
		position=player.position;
		row=player.row;
	}

	// set whether module repeats after songlen
	public function setrepeat(rep:Bool)
	{
		repeat=rep;
		if (player!=null) 
			player.repeat=rep;
	}

	// set stereo separation mode (0=standard, 1=65/35 mix, 2=mono)
	public function setseparation(sep:Int)
	{
		separation=sep;
		if (player != null)
			player.separation=sep;
	}

	// set autostart to play immediately after loading
	public function setautostart(st:Bool)
	{
		autostart=st;
	}

	// Effect functions /////////////////////////////////////////////////////////////////

	// set amiga model - changes lowpass filter state
	public function setamigamodel(amiga:String)
	{
		if (amiga == "600" || amiga == "1200" || amiga == "4000")
		{
			amiga500=false;
			if (filterNode != null)
				filterNode.frequency.value=22050;
		}
		else
		{
			amiga500=true;
			if (filterNode != null)
				filterNode.frequency.value=6000;
		}
	}

	// amiga "LED" filter
	public function setfilter(f:Bool)
	{
		if (f)
			lowpassNode.frequency.value = 3275;
		else
			lowpassNode.frequency.value = 24000;//28867;
		
		filter=f;
		if (player != null)
			player.filter=f;
	}

	// are there E8x sync events queued?
	public function hassyncevents()
	{
		if (player!=null) 
			return player.syncqueue.length != 0;
			
		return false;
	}

	// pop oldest sync event nybble from the FIFO queue
	public function popsyncevent()
	{
		if (player!=null)
			return player.syncqueue.pop();
			
		return null;
	}
	
	/////////////////////////////////////////////////////////////////////////////////////
	
	//===================================================================================
	// Get patterndata info
	//-----------------------------------------------------------------------------------
	
	// get current pattern number
	public function currentpattern()
	{
		if (player != null)
			return player.patterntable[player.position];
			
		return null;
	}
	
	// get current pattern in standard unpacked format (note, sample, volume, command, data)
	// note: 254=noteoff, 255=no note
	// sample: 0=no instrument, 1..255=sample number
	// volume: 255=no volume set, 0..64=set volume, 65..239=ft2 volume commands
	// command: 0x2e=no command, 0..0x24=effect command
	// data: 0..255
	public function patterndata(pn:Int)
	{
		var i:Int = 0;
		var c:Int = 0;
		var patt:UInt8Array = null;
		
		if (format == 'mod')
		{
			patt = new UInt8Array(player.pattern_unpack[pn]);
			
			for (i in 0...64)
			{
				for (c in 0...player.channels) 
				{
					if (patt[i * 5 * channels + c * 5 + 3] == 0 && patt[i * 5 * channels + c * 5 + 4] == 0)
					{
						patt[i*5*channels+c*5+3]=0x2e;
					}
					else
					{
						patt[i*5*channels+c*5+3]+=0x37;
						if (patt[i * 5 * channels + c * 5 + 3] < 0x41) 
							patt[i*5*channels+c*5+3]-=0x07;
					}
				}
			}
		}
		else if (format == 's3m')
		{
			patt = new UInt8Array(player.pattern[pn]);
			
			for (i in 0...64) 
			{
				for(c in 0...player.channels) 
				{
					if (patt[i * 5 * channels + c * 5 + 3] == 255)
						patt[i*5*channels+c*5+3]=0x2e;
					else
						patt[i*5*channels+c*5+3]+=0x40;
				}
			}
			
		}
		else if (format == 'xm')
		{
			patt=new UInt8Array(player.pattern[pn]);
			
			for (i in 0...player.patternlen[pn]) 
			{
				for (c in 0...player.channels) 
				{
					if (patt[i*5*channels+c*5+0]<97)
						patt[i*5*channels+c*5+0]=(patt[i*5*channels+c*5+0]%12)|(Math.floor(patt[i*5*channels+c*5+0]/12)<<4);
						
					if (patt[i * 5 * channels + c * 5 + 3] == 255) 
						patt[i*5*channels+c*5+3]=0x2e;
					else
					{
						if (patt[i * 5 * channels + c * 5 + 3] < 0x0a)
							patt[i*5*channels+c*5+3]+=0x30;
						else
							patt[i*5*channels+c*5+3]+=0x41-0x0a;
					}
				}
			}
		}
		return patt;  
	}

	// check if a channel has a note on
	public function noteon(ch:Int):Int
	{
		if (ch >= channels)
			return 0;
			
		return player.channel[ch].noteon;
	}

	// get currently active sample on channel
	public function currentsample(ch:Int):Float
	{
		if (ch >= channels)
			return 0;
	  
		if (format == "xm" || this.format == "it") 
			return player.channel[ch].voiceperiod;
		
		return player.channel[ch].sample;
	}

	// get length of currently playing pattern
	public function currentpattlen():Int
	{
		if (format == "mod" || format == "s3m")
			return 64;
		
		return player.patternlen[player.patterntable[player.position]];
	}

	/////////////////////////////////////////////////////////////////////////////////////
	
	//===================================================================================
	// Setup WebAudio - create the web audio context
	//-----------------------------------------------------------------------------------
	
	public function createContext()
	{
		//if ( untyped __js__("typeof AudioContext !== 'undefined'") )
			context = new AudioContext();
		//else
			//context = untyped __js__("new webkitAudioContext()");
		
		samplerate=context.sampleRate;
		bufferlen=(samplerate > 44100) ? 4096 : 2048;

		// Amiga 500 fixed filter at 6kHz. WebAudio lowpass is 12dB/oct, whereas
		// older Amigas had a 6dB/oct filter at 4900Hz.
		filterNode=context.createBiquadFilter();
		
		if (amiga500)
			filterNode.frequency.value=6000;
		else
			filterNode.frequency.value=22050;

		// "LED filter" at 3275kHz - off by default
		lowpassNode=context.createBiquadFilter();
		setfilter(filter);

		// mixer
		//if ( untyped __js__("typeof this.context.createJavaScriptNode === 'function'"))
			//mixerNode = untyped __js__("context.createJavaScriptNode(bufferlen, 1, 2)");
		//else
		mixerNode = context.createScriptProcessor(bufferlen, 1, 2);
			
		mixerNode.module=this;
		mixerNode.onaudioprocess = mix;

		// patch up some cables :)
		mixerNode.connect(filterNode);
		filterNode.connect(lowpassNode);
		lowpassNode.connect(context.destination);

		mixerNode.onaudioprocess = mix;
	}

	/////////////////////////////////////////////////////////////////////////////////////
	
	//===================================================================================
	// Mix - scriptnode callback - pass through to player class
	//-----------------------------------------------------------------------------------

	public function mix(ape:AudioProcessingEvent)
	{
		var mod:ModPlayer=null;

		if (untyped ape.srcElement)
			mod=untyped ape.srcElement.module;
		//else
		//{
			////untyped __js__("mod=module");// 
		//}

		if (mod.player!=null && mod.delayfirst == 0)
		{
			mod.player.repeat=mod.repeat;

			var bufs=[ape.outputBuffer.getChannelData(0), ape.outputBuffer.getChannelData(1)];//Float32Array
			var buflen=ape.outputBuffer.length;
			mod.player.mix(mod.player, bufs, buflen);

			// apply stereo separation and soft clipping
			var outp:Float32Array = new Float32Array(2);
			
			for (s in 0...buflen)
			{
				outp[0]=bufs[0][s];
				outp[1]=bufs[1][s];

				// a more headphone-friendly stereo separation
				if (cast mod.separation)
				{
					var t=outp[0];
					if (mod.separation == 2)
					{ 	// mono
						outp[0]=outp[0]*0.5 + outp[1]*0.5;
						outp[1]=outp[1]*0.5 + t*0.5;
					}
					else
					{ 	// narrow stereo
						outp[0]=outp[0]*0.65 + outp[1]*0.35;
						outp[1]=outp[1]*0.65 + t*0.35;
					}
				}
				// scale down and soft clip
				outp[0] /= mod.mixval; 
				outp[0]=0.5*(Math.abs(outp[0]+0.975)-Math.abs(outp[0]-0.975));
				
				outp[1] /= mod.mixval; 
				outp[1]=0.5*(Math.abs(outp[1]+0.975)-Math.abs(outp[1]-0.975));

				bufs[0][s]=outp[0];
				bufs[1][s]=outp[1];
			}

			mod.row=mod.player.row;
			mod.position=mod.player.position;
			mod.speed=mod.player.speed;
			mod.bpm=mod.player.bpm;
			mod.endofsong=mod.player.endofsong;

			if (mod.player.filter != mod.filter)
				mod.setfilter(mod.player.filter);

			if (mod.endofsong && mod.playing)
				mod.stop();

			if (mod.delayfirst > 0)
				mod.delayfirst--;
				
			mod.delayload=0;

			// update this.chvu from player channel vu
			
			for (i in 0...mod.player.channels)
			{
				mod.chvu[i]=mod.chvu[i]*0.25 + mod.player.chvu[i]*0.75;    
				mod.player.chvu[i]=0.0;
			}
		}	
		
	}
	
	// Debug ////////////////////////////////////////////////////////////////////////////
	
	function set_state(value:String):String 
	{
		trace(value);
		return state = value;
	}
	
	/////////////////////////////////////////////////////////////////////////////////////
}