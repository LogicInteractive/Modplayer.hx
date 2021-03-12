package hxmod;

import hxmod.utils.ArrayBuffer;
import hxmod.utils.Float32Array;
import hxmod.utils.UInt8Array;
import js.html.audio.AudioContext;
import js.html.audio.BiquadFilterNode;

/**
 * ...
 * @author Tommy S. - Ported from firehawk/tda
 */
class Protracker 
{
	/////////////////////////////////////////////////////////////////////////////////////
	
	//===================================================================================
	// Protracker .mod player
	//-----------------------------------------------------------------------------------
	
	// Properties ///////////////////////////////////////////////////////////////////////

	
	public var playing			: Bool					= false;
	public var paused			: Bool					= false;
	public var repeat			: Bool					= false;

	public var filter			: Bool					= false;
	public var mixval			: Float					= 4.0;
	public var syncqueue		: Array<Dynamic>		= [];
	public var samplerate		: Float					= 44100;
	public var delayfirst		: Int;
	public var delayload		: Int;
	public var separation		: Int;
	public var patternlen		: Dynamic;
	
	// paula period values
	var baseperiodtable			: Float32Array			= new Float32Array([
		856,808,762,720,678,640,604,570,538,508,480,453,
		428,404,381,360,339,320,302,285,269,254,240,226,
		214,202,190,180,170,160,151,143,135,127,120,113
	]);

	// finetune multipliers
	var finetunetable			: Float32Array			= new Float32Array(16);

	// calc tables for vibrato waveforms
	var vibratotable			: Array<Float32Array>	= [];
	
	// effect jumptables
	var effects_t0				: Array<(mod:Protracker, ch:Int)->Void>;
	var effects_t0_e			: Array<(mod:Protracker, ch:Int)->Void>;
	var effects_t1				: Array<(mod:Protracker, ch:Int)->Void>;
	var effects_t1_e			: Array<(mod:Protracker, ch:Int)->Void>;

	public var title			: String;
	public var signature		: String;
	public var songlen			: Int;
	public var repeatpos		: Int;
	public var patterntable		: Dynamic				= new ArrayBuffer(128);
	public var channels			: Int;
	public var sample			: Array<Dynamic>;
	public var patterns			: Int;
	public var pattern			: Array<Dynamic>;
	public var pattern_unpack	: Array<Dynamic>;
	public var tick				: Null<Int>;
	public var position			: Int;
	public var row				: Int;
	public var flags			: Int;
	public var speed			: Int;
	public var bpm				: Int;
	public var endofsong		: Bool;
	public var channel			: Array<PTChannel>;
	public var chvu				: Float32Array;

	var context					: AudioContext;
	var lowpassNode				: BiquadFilterNode;
	var samples					: Int;
	var note					: Array<Dynamic>;
	var looprow					: Int;
	var loopstart				: Int;
	var loopcount				: Int;
	var patterndelay			: Int;
	var patternwait				: Int;
	var offset					: Int;
	var breakrow				: Int;
	var patternjump				: Int;

	/////////////////////////////////////////////////////////////////////////////////////

	public function new()
	{
		effects_t0		= [ effect_t0_0, effect_t0_1, effect_t0_2, effect_t0_3, effect_t0_4, effect_t0_5, effect_t0_6, effect_t0_7, effect_t0_8, effect_t0_9, effect_t0_a, effect_t0_b, effect_t0_c, effect_t0_d, effect_t0_e, effect_t0_f];
		effects_t0_e	= [	effect_t0_e0, effect_t0_e1, effect_t0_e2, effect_t0_e3, effect_t0_e4, effect_t0_e5, effect_t0_e6, effect_t0_e7, effect_t0_e8, effect_t0_e9, effect_t0_ea, effect_t0_eb, effect_t0_ec, effect_t0_ed, effect_t0_ee, effect_t0_ef];
		effects_t1		= [	effect_t1_0, effect_t1_1, effect_t1_2, effect_t1_3, effect_t1_4, effect_t1_5, effect_t1_6, effect_t1_7, effect_t1_8, effect_t1_9, effect_t1_a, effect_t1_b, effect_t1_c, effect_t1_d, effect_t1_e, effect_t1_f];
		effects_t1_e	= [	effect_t1_e0, effect_t1_e1, effect_t1_e2, effect_t1_e3, effect_t1_e4, effect_t1_e5, effect_t1_e6, effect_t1_e7, effect_t1_e8, effect_t1_e9, effect_t1_ea, effect_t1_eb, effect_t1_ec, effect_t1_ed, effect_t1_ee, effect_t1_ef];

		clearsong();
		initialize();
	
		for (t in 0...16)
			finetunetable[t]=Math.pow(2, (t-8)/12/8);		
	
		for (t in 0...4)
		{
			vibratotable[t] = new Float32Array(64);
			
			for (i in 0...64)
			{
				switch (t)
				{
					case 0:
						vibratotable[t][i]=127*Math.sin(Math.PI*2*(i/64));
					case 1:
						vibratotable[t][i]=127-4*i;
					case 2:
						vibratotable[t][i]=(i<32)?127:-127;
					case 3:
						vibratotable[t][i]=(1-2*Math.random())*127;
					default:
				}
			}
		}
	}

		// clear song data
	function clearsong()
	{
		title="";
		signature="";

		songlen=1;
		repeatpos=0;
		patterntable = new ArrayBuffer(128);
		
		for (i in 0...128)
			patterntable[i]=0;

		channels=4;

		sample=new Array();
		samples = 31;
		
		for (i in 0...31)
		{
			sample[i] = {};
			sample[i].name="";
			sample[i].length=0;
			sample[i].finetune=0;
			sample[i].volume=64;
			sample[i].loopstart=0;
			sample[i].looplength=0;
			sample[i].data=0;
		}

		patterns=0;
		pattern = [];
		note = [];
		pattern_unpack = [];

		looprow=0;
		loopstart=0;
		loopcount=0;

		patterndelay=0;
		patternwait=0;
	}
	
	// initialize all player variables
	public function initialize()
	{
		syncqueue=[];

		tick=0;
		position=0;
		row=0;
		offset=0;
		flags=0;

		speed=6;
		bpm=125;
		breakrow=0;
		patternjump=0;
		patterndelay=0;
		patternwait=0;
		endofsong=false;

		channel = [];
		for (i in 0...channels)
			channel[i] = { sample:0, period:214, voiceperiod:214, note:24, volume:64, command:0, data:0, samplepos:0, samplespeed:0, flags:0, noteon:0, slidespeed:0, slideto:214, slidetospeed:0, arpeggio:0, semitone:12, vibratospeed:0, vibratodepth:0, vibratopos:0, vibratowave:0, instrument:0 };
	}
	
	// parse the module from local buffer
	public function parse(buffer:UInt8Array)
	{
		var i:Int;
		var j:Int;
		var c:Int;

		for (i in 0...4) 
			signature+=String.fromCharCode(buffer[1080+i]);

		switch (this.signature)
		{
			case "M.K." | "M!K!" | "4CHN" | "FLT4":
			{}

			case "6CHN":
				channels=6;

			case "8CHN" | "FLT8":
				channels=8;

			case "28CH":
				channels=28;

			default:
				return false;
		}
	  
		chvu = new Float32Array(128);
		
		for (i in 0...channels)
			chvu[i]=0.0;

		i=0;
		while(buffer[i]!=null && i<20)
			title=title+String.fromCharCode(buffer[i++]);
		for (i in 0...samples)
		{
			var st=20+i*30;
			j = 0;
			
			while (buffer[st+j]!=null && j<22)
			{
				sample[i].name+= ((buffer[st+j]>0x1f) && (buffer[st+j]<0x7f)) ? (String.fromCharCode(buffer[st+j])) : (" ");
				j++;
			}

			sample[i].length=2*(buffer[st+22]*256 + buffer[st+23]);
			sample[i].finetune=buffer[st+24];
		
			if (sample[i].finetune > 7)
				sample[i].finetune = sample[i].finetune-16;
				
			sample[i].volume=buffer[st+25];
			sample[i].loopstart=2*(buffer[st+26]*256 + buffer[st+27]);
			sample[i].looplength=2*(buffer[st+28]*256 + buffer[st+29]);
		
			if (sample[i].looplength == 2)
				sample[i].looplength = 0;
				
			if (sample[i].loopstart > sample[i].length)
			{
				sample[i].loopstart=0;
				sample[i].looplength=0;
			}
		}

		songlen = buffer[950];
		
		if (buffer[951] != 127)
			repeatpos=buffer[951];
	  
		for (i in 0...128) 
		{
			patterntable[i]=buffer[952+i];
			if (patterntable[i] > patterns) 
				patterns=patterntable[i];
		}
		
		patterns+=1;
		var patlen=4*64*channels;

		pattern = [];
		note = [];
	  
		pattern_unpack = [];
		
		for (i in 0...patterns) 
		{
			pattern[i]=new UInt8Array(patlen);
			note[i]=new UInt8Array(channels*64);
			pattern_unpack[i] = new UInt8Array(channels * 64 * 5);
			
			for (j in 0...patlen) 
				pattern[i][j]=buffer[1084+i*patlen+j];
		
			for (j in 0...64)
			{
				for (c in 0...channels)
				{
					note[i][j*channels+c]=0;
					var n = (pattern[i][j * 4 * channels + c * 4] & 0x0f) << 8 | pattern[i][j * 4 * channels + c * 4 + 1];
					
					for(np in 0...baseperiodtable.length)
						if (n == baseperiodtable[np]) 
							note[i][j*channels+c]=np;
				}
			}
			
			for (j in 0...64)
			{
				for (c in 0...channels)
				{
					var pp= j*4*channels+c*4;
					var ppu=j*5*channels+c*5;
					var n = (pattern[i][pp] & 0x0f) << 8 | pattern[i][pp + 1];
					
					if (n!=null)
					{
						n = note[i][j * channels + c]; 
						n=(n%12)|(Math.floor(n/12)+2)<<4;
					}
					pattern_unpack[i][ppu+0]=(n!=null)?n:255;
					pattern_unpack[i][ppu+1]=pattern[i][pp+0]&0xf0 | pattern[i][pp+2]>>4;
					pattern_unpack[i][ppu+2]=255;
					pattern_unpack[i][ppu+3]=pattern[i][pp+2]&0x0f;
					pattern_unpack[i][ppu+4]=pattern[i][pp+3];
				}
			}
		}

		var sst=1084+patterns*patlen;
  
		for (i in 0...samples)
		{
			sample[i].data=new Float32Array(sample[i].length);
	
			for (j in 0...sample[i].length)
			{
				var q:Float=buffer[sst+j];
				if (q < 128)
				{
					q=q/128.0;
				}
				else
				{
					q=((q-128)/128.0)-1.0;
				}
				sample[i].data[j]=q;
			}
			sst+=sample[i].length;
		}

		// look ahead at very first row to see if filter gets enabled
		filter = false;
		
		for(ch in 0...channels)
		{
			var p=patterntable[0];
			var pp=ch*4;
			var cmd = pattern[p][pp + 2] & 0x0f;
			var data:Dynamic=pattern[p][pp+3];
			
			if (cmd==0x0e && ((data&0xf0)==0x00))
			{
				if (! ((data&0x01)!=null))
				{
					filter=true;
				}
				else
				{
					filter=false;
				}
			}
		}

		// set lowpass cutoff
		if (context!=null)
		{
			if (filter!=null)
			{
				lowpassNode.frequency.value=3275;
			}
			else
			{
				lowpassNode.frequency.value=28867;
			}
		}

		chvu=new Float32Array(channels);
		for (i in 0...channels)
			chvu[i] = 0.0;
			
		return true;
	}
		
	


	// advance player
	public function advance(mod:Protracker)
	{
		var spd=(((mod.samplerate*60)/mod.bpm)/4)/6;

		// advance player
		if (mod.offset > spd)
		{
			mod.tick++; 
			mod.offset = 0; 
			mod.flags|=1;
		}
		if (mod.tick >= mod.speed)
		{
			if (cast mod.patterndelay) // delay pattern
			{ 
				if (mod.tick < ((mod.patternwait + 1) * mod.speed))
				{
					mod.patternwait++;
				} 
				else
				{
					mod.row++; 
					mod.tick = 0; 
					mod.flags |= 2; 
					mod.patterndelay=0;
				}
			}
			else
			{
				if (cast mod.flags&(16+32+64))
				{
					if (cast mod.flags&64)
					{
						// loop pattern?
						mod.row=mod.looprow;
						mod.flags&=0xa1;
						mod.flags|=2;
					}
					else
					{
						if (cast mod.flags&16)
						{
							// pattern jump/break?
							mod.position=mod.patternjump;
							mod.row=mod.breakrow;
							mod.patternjump=0;
							mod.breakrow=0;
							mod.flags&=0xe1;
							mod.flags|=2;
						}
					}
					mod.tick=0;
				} 
				else
				{
					mod.row++; 
					mod.tick = 0; 
					mod.flags|=2;
				}
			}
		}
		if (mod.row >= 64)
		{
			mod.position++; 
			mod.row = 0; 
			mod.flags|=4;
		}
		if (mod.position >= mod.songlen)
		{
			if (mod.repeat)
				mod.position=0;
			else
				this.endofsong=true;
				//mod.stop();
			return;
		}
	}

	// mix an audio buffer with data
	public function mix(mod:Protracker, bufs:Array<Float32Array>, buflen:Int)
	{
		var f	: Null<Float>;
		var p	: Null<Int>;
		var pp	: Null<Int>;
		var n	: Null<Int>;
		var nn	: Null<Int>;

		var outp = new Float32Array(2);
		
		for(s in 0...buflen)
		{
			outp[0]=0.0;
			outp[1]=0.0;
			

			if (!mod.paused && !mod.endofsong && mod.playing)
			{
				mod.advance(mod);

				var och:Int=0;
				for(ch in 0...mod.channels)
				{
					// calculate playback position
					p=mod.patterntable[mod.position];
					pp=mod.row*4*mod.channels + ch*4;
					
					if (cast mod.flags&2) // new row
					{ 
						mod.channel[ch].command=mod.pattern[p][pp+2]&0x0f;
						mod.channel[ch].data=mod.pattern[p][pp+3];

						if (!(mod.channel[ch].command==0x0e && (mod.channel[ch].data&0xf0)==0xd0))
						{
							n=(mod.pattern[p][pp]&0x0f)<<8 | mod.pattern[p][pp+1];
							if (cast n)
							{
								// noteon, except if command=3 (porta to note)
								if ((mod.channel[ch].command != 0x03) && (mod.channel[ch].command != 0x05))
								{
									mod.channel[ch].period=n;
									mod.channel[ch].samplepos=0;
									
									if (mod.channel[ch].vibratowave > 3) 
										mod.channel[ch].vibratopos=0;
									
									mod.channel[ch].flags|=3; // recalc speed
									mod.channel[ch].noteon=1;
								}
								// in either case, set the slide to note target
								mod.channel[ch].slideto=n;
							}
							nn=mod.pattern[p][pp+0]&0xf0 | mod.pattern[p][pp+2]>>4;
							
							if (cast nn)
							{
								mod.channel[ch].sample = nn - 1;
								mod.channel[ch].volume=mod.sample[nn-1].volume;
								
								if (untyped n && (mod.channel[ch].samplepos > mod.sample[nn-1].length))
									mod.channel[ch].samplepos=0;
							}
						}
					}
					mod.channel[ch].voiceperiod=mod.channel[ch].period;
					
					// kill empty samples
					if (!mod.sample[mod.channel[ch].sample].length)
						mod.channel[ch].noteon=0;

					// effects
					if (cast mod.flags&1)
					{
						if (untyped !mod.tick)
							mod.effects_t0[mod.channel[ch].command](mod, ch); // process only on tick 0
						else
							mod.effects_t1[mod.channel[ch].command](mod, ch);
					}
					
					// recalc note number from period
					if (cast mod.channel[ch].flags&2)
					{
						for (np in 0...mod.baseperiodtable.length)
						{
							if (mod.baseperiodtable[np] >= mod.channel[ch].period)
								mod.channel[ch].note = np;
						}
				  
						mod.channel[ch].semitone=7;
				  
						if (mod.channel[ch].period>=120)
							mod.channel[ch].semitone=mod.baseperiodtable[mod.channel[ch].note]-mod.baseperiodtable[mod.channel[ch].note+1];
					}

					// recalc sample speed and apply finetune
					if ((untyped mod.channel[ch].flags&1 || cast mod.flags&2) && cast mod.channel[ch].voiceperiod)
						mod.channel[ch].samplespeed=7093789.2/(mod.channel[ch].voiceperiod*2) * mod.finetunetable[mod.sample[mod.channel[ch].sample].finetune+8] / mod.samplerate;

					// advance vibrato on each new tick
					if (cast mod.flags&1)
					{
						mod.channel[ch].vibratopos+=mod.channel[ch].vibratospeed;
						mod.channel[ch].vibratopos&=0x3f;
					}
					
					// mix channel to output
					och=och^(ch&1);
					f=0.0;
				
					if (cast mod.channel[ch].noteon)
					{
						if (cast mod.sample[mod.channel[ch].sample] && mod.sample[mod.channel[ch].sample].length > mod.channel[ch].samplepos)
							f=(mod.sample[mod.channel[ch].sample].data[Math.floor(mod.channel[ch].samplepos)]*mod.channel[ch].volume)/64.0;
						
						outp[och]+=f;
						mod.channel[ch].samplepos+=mod.channel[ch].samplespeed;
					}
					mod.chvu[ch]=Math.max(mod.chvu[ch], Math.abs(f));
					
					// loop or end samples
					if (cast mod.channel[ch].noteon)
					{
						if (mod.sample[mod.channel[ch].sample].loopstart || mod.sample[mod.channel[ch].sample].looplength)
						{
							if (mod.channel[ch].samplepos >= (mod.sample[mod.channel[ch].sample].loopstart + mod.sample[mod.channel[ch].sample].looplength))
								mod.channel[ch].samplepos-=mod.sample[mod.channel[ch].sample].looplength;
						}
						else
						{
							if (mod.channel[ch].samplepos >= mod.sample[mod.channel[ch].sample].length)
								mod.channel[ch].noteon=0;
						}
					}

					// clear channel flags
					mod.channel[ch].flags=0;
				}
				mod.offset++;
				mod.flags&=0x70;
			}
			
			// done - store to output buffer
			bufs[0][s]=outp[0];
			bufs[1][s]=outp[1];
		}
		
		
	}
	
	//
	// tick 0 effect functions
	//
	function effect_t0_0(mod:Protracker, ch:Int)
	{
		// 0 arpeggio
		mod.channel[ch].arpeggio=mod.channel[ch].data;
	}
	
	function effect_t0_1(mod:Protracker, ch:Int)
	{
		// 1 slide up
		if (cast mod.channel[ch].data) 
			mod.channel[ch].slidespeed=mod.channel[ch].data;
	}
	
	function effect_t0_2(mod:Protracker, ch:Int)
	{
		// 2 slide down
		if (cast mod.channel[ch].data) 
			mod.channel[ch].slidespeed=mod.channel[ch].data;
	}
	
	function effect_t0_3(mod:Protracker, ch:Int)
	{
		// 3 slide to note
		if (cast mod.channel[ch].data)
			mod.channel[ch].slidetospeed=mod.channel[ch].data;
	}
	
	function effect_t0_4(mod:Protracker, ch:Int)
	{
		// 4 vibrato
		if (untyped mod.channel[ch].data&0x0f && untyped mod.channel[ch].data&0xf0)
		{
			mod.channel[ch].vibratodepth=(mod.channel[ch].data&0x0f);
			mod.channel[ch].vibratospeed=(mod.channel[ch].data&0xf0)>>4;
		}
		mod.effects_t1[4](mod, ch);
	}
	
	function effect_t0_5(mod:Protracker, ch:Int) {} // 5
	function effect_t0_6(mod:Protracker, ch:Int) {} // 6
	function effect_t0_7(mod:Protracker, ch:Int) {} // 7
	
	function effect_t0_8(mod:Protracker, ch:Int)
	{
		// 8 unused, used for syncing
		mod.syncqueue.unshift(mod.channel[ch].data&0x0f);
	}
	
	function effect_t0_9(mod:Protracker, ch:Int)
	{
		// 9 set sample offset
		mod.channel[ch].samplepos=mod.channel[ch].data*256;
	}
	
	function effect_t0_a(mod:Protracker, ch:Int){} // a
	
	function effect_t0_b(mod:Protracker, ch:Int)
	{
		// b pattern jump
		mod.breakrow=0;
		mod.patternjump=mod.channel[ch].data;
		mod.flags|=16;
	}
	
	function effect_t0_c(mod:Protracker, ch:Int)
	{
		// c set volume
		mod.channel[ch].volume=mod.channel[ch].data;
	}
	
	function effect_t0_d(mod:Protracker, ch:Int)
	{
		// d pattern break
		mod.breakrow=((mod.channel[ch].data&0xf0)>>4)*10 + (mod.channel[ch].data&0x0f);
		
		if (untyped !(mod.flags&16))
			mod.patternjump=mod.position+1;
		
		mod.flags|=16;
	}
	
	function effect_t0_e(mod:Protracker, ch:Int)
	{
		// e
		var i=(mod.channel[ch].data&0xf0)>>4;
		mod.effects_t0_e[i](mod, ch);
	}
	
	function effect_t0_f(mod:Protracker, ch:Int)
	{
		// f set speed
		if (mod.channel[ch].data > 32)
			mod.bpm=mod.channel[ch].data;
		else
		{
			if (cast mod.channel[ch].data) 
				mod.speed=mod.channel[ch].data;
		}
	}

	//
	// tick 0 effect e functions
	//
	function effect_t0_e0(mod:Protracker, ch:Int)
	{
		// e0 filter on/off
		if (mod.channels > 4) 
			return; // use only for 4ch amiga tunes
		
		if (cast mod.channel[ch].data&0x01)
			mod.filter=false;
		else
			mod.filter=true;
	}

	function effect_t0_e1(mod:Protracker, ch:Int)
	{
		// e1 fine slide up
		mod.channel[ch].period -= mod.channel[ch].data & 0x0f;
		
		if (mod.channel[ch].period < 113)
			mod.channel[ch].period=113;
	}

	function effect_t0_e2(mod:Protracker, ch:Int)
	{
		// e2 fine slide down
		mod.channel[ch].period+=mod.channel[ch].data&0x0f;
		
		if (mod.channel[ch].period > 856) 
			mod.channel[ch].period = 856;
			
		mod.channel[ch].flags|=1;
	}

	function effect_t0_e3(mod:Protracker, ch:Int) {} // e3 set glissando

	function effect_t0_e4(mod:Protracker, ch:Int)
	{
		// e4 set vibrato waveform
		mod.channel[ch].vibratowave=mod.channel[ch].data&0x07;
	}
	
	function effect_t0_e5(mod:Protracker, ch:Int) {} // e5 set finetune

	function effect_t0_e6(mod:Protracker, ch:Int)
	{
		// e6 loop pattern
		if (cast mod.channel[ch].data&0x0f)
		{
			if (mod.loopcount!=null)
				mod.loopcount--;
			else
				mod.loopcount = mod.channel[ch].data&0x0f;
				
			if (mod.loopcount!=null) 
				mod.flags|=64;
		} 
		else
			mod.looprow=mod.row;
	}

	function effect_t0_e7(mod:Protracker, ch:Int) {} // e7

	function effect_t0_e8(mod:Protracker, ch:Int)
	{
		// e8, use for syncing
		mod.syncqueue.unshift(mod.channel[ch].data&0x0f);
	}
	
	function effect_t0_e9(mod:Protracker, ch:Int) {} // e9

	function effect_t0_ea(mod:Protracker, ch:Int)
	{
		// ea fine volslide up
		mod.channel[ch].volume+=mod.channel[ch].data&0x0f;
		if (mod.channel[ch].volume > 64) 
			mod.channel[ch].volume=64;
	}
	
	function effect_t0_eb(mod:Protracker, ch:Int)
	{
		// eb fine volslide down
		mod.channel[ch].volume-=mod.channel[ch].data&0x0f;
		if (mod.channel[ch].volume < 0) 
			mod.channel[ch].volume=0;
	}

	function effect_t0_ec(mod:Protracker, ch:Int) {} // ec

	function effect_t0_ed(mod:Protracker, ch:Int)
	{
		// ed delay sample
		if (mod.tick == (mod.channel[ch].data&0x0f))
		{
			// start note
			var p:Int=mod.patterntable[mod.position];
			var pp:Int=mod.row*4*mod.channels + ch*4;
			var n=(mod.pattern[p][pp]&0x0f)<<8 | mod.pattern[p][pp+1];
			
			if (cast n)
			{
				mod.channel[ch].period=n;
				mod.channel[ch].voiceperiod=mod.channel[ch].period;
				mod.channel[ch].samplepos = 0;
				
				if (mod.channel[ch].vibratowave > 3) 
					mod.channel[ch].vibratopos = 0;
					
				mod.channel[ch].flags|=3; // recalc speed
				mod.channel[ch].noteon=1;
			}
			
			n=mod.pattern[p][pp+0]&0xf0 | mod.pattern[p][pp+2]>>4;
			
			if (cast n)
			{
				mod.channel[ch].sample=n-1;
				mod.channel[ch].volume=mod.sample[n-1].volume;
			}
		}
	}
	
	function effect_t0_ee(mod:Protracker, ch:Int)
	{
		// ee delay pattern
		mod.patterndelay=mod.channel[ch].data&0x0f;
		mod.patternwait=0;
	}

	function effect_t0_ef(mod:Protracker, ch:Int) {} // ef

	//
	// tick 1+ effect functions
	//
	function effect_t1_0(mod:Protracker, ch:Int)
	{
		// 0 arpeggio
		if (cast mod.channel[ch].data)
		{
			var apn=mod.channel[ch].note;
			
			if ((mod.tick % 3) == 1)
				apn+=mod.channel[ch].arpeggio>>4;
			
			if ((mod.tick % 3) == 2)
				apn+=mod.channel[ch].arpeggio&0x0f;
			
			if (apn>=0 && apn <= mod.baseperiodtable.length)
				mod.channel[ch].voiceperiod = mod.baseperiodtable[apn];
			
			mod.channel[ch].flags|=1;
		}
	}
	
	function effect_t1_1(mod:Protracker, ch:Int)
	{
		// 1 slide up
		mod.channel[ch].period -= mod.channel[ch].slidespeed;
		
		if (mod.channel[ch].period < 113) 
			mod.channel[ch].period=113;
		
		mod.channel[ch].flags|=3; // recalc speed
	}
	
	function effect_t1_2(mod:Protracker, ch:Int)
	{
		// 2 slide down
		mod.channel[ch].period+=mod.channel[ch].slidespeed;
		
		if (mod.channel[ch].period > 856) 
			mod.channel[ch].period=856;
		
		mod.channel[ch].flags|=3; // recalc speed
	}
	
	function effect_t1_3(mod:Protracker, ch:Int)
	{
		// 3 slide to note
		if (mod.channel[ch].period < mod.channel[ch].slideto)
		{
			mod.channel[ch].period+=mod.channel[ch].slidetospeed;
			
			if (mod.channel[ch].period > mod.channel[ch].slideto)
				mod.channel[ch].period=mod.channel[ch].slideto;
		}
		
		if (mod.channel[ch].period > mod.channel[ch].slideto)
		{
			mod.channel[ch].period-=mod.channel[ch].slidetospeed;
			
			if (mod.channel[ch].period<mod.channel[ch].slideto)
				mod.channel[ch].period=mod.channel[ch].slideto;
		}
		mod.channel[ch].flags|=3; // recalc speed
	}
	
	function effect_t1_4(mod:Protracker, ch:Int)
	{
		// 4 vibrato
		var waveform:Float=mod.vibratotable[mod.channel[ch].vibratowave&3][mod.channel[ch].vibratopos]/63.0; //127.0;

		// two different implementations for vibrato
		//  var a:Float=(mod.channel[ch].vibratodepth/32)*mod.channel[ch].semitone*waveform; // non-linear vibrato +/- semitone
		var a:Float=mod.channel[ch].vibratodepth*waveform; // linear vibrato, depth has more effect high notes

		mod.channel[ch].voiceperiod+=a;
		mod.channel[ch].flags|=1;
	}
	
	function effect_t1_5(mod:Protracker, ch:Int)
	{
		// 5 volslide + slide to note
		mod.effect_t1_3(mod, ch); // slide to note
		mod.effect_t1_a(mod, ch); // volslide
	}
	
	function effect_t1_6(mod:Protracker, ch:Int)
	{
		// 6 volslide + vibrato
		mod.effect_t1_4(mod, ch); // vibrato
		mod.effect_t1_a(mod, ch); // volslide
	}
	
	function effect_t1_7(mod:Protracker, ch:Int) {} // 7
	function effect_t1_8(mod:Protracker, ch:Int) {} // 8 unused
	function effect_t1_9(mod:Protracker, ch:Int) {} // 9 set sample offset
	
	function effect_t1_a(mod:Protracker, ch:Int)
	{
		// a volume slide
		if (untyped !(mod.channel[ch].data&0x0f))
		{
			// y is zero, slide up
			mod.channel[ch].volume+=(mod.channel[ch].data>>4);
			
			if (mod.channel[ch].volume > 64)
				mod.channel[ch].volume=64;
		}

		if (untyped !(mod.channel[ch].data&0xf0))
		{
			// x is zero, slide down
			mod.channel[ch].volume-=(mod.channel[ch].data&0x0f);
			
			if (mod.channel[ch].volume < 0) 
				mod.channel[ch].volume=0;
		}
	}
	
	function effect_t1_b(mod:Protracker, ch:Int) {} // b pattern jump
	function effect_t1_c(mod:Protracker, ch:Int) {} // c set volume
	function effect_t1_d(mod:Protracker, ch:Int) {} // d pattern break

	function effect_t1_e(mod:Protracker, ch:Int)
	{
		// e
		var i=(mod.channel[ch].data&0xf0)>>4;
		mod.effects_t1_e[i](mod, ch);
	}
	
	function effect_t1_f(mod:Protracker, ch:Int) {} // f

	//
	// tick 1+ effect e functions
	//
	function effect_t1_e0(mod:Protracker, ch:Int) {} // e0
	function effect_t1_e1(mod:Protracker, ch:Int) {} // e1
	function effect_t1_e2(mod:Protracker, ch:Int) {} // e2
	function effect_t1_e3(mod:Protracker, ch:Int) {} // e3
	function effect_t1_e4(mod:Protracker, ch:Int) {} // e4
	function effect_t1_e5(mod:Protracker, ch:Int) {} // e5
	function effect_t1_e6(mod:Protracker, ch:Int) {} // e6
	function effect_t1_e7(mod:Protracker, ch:Int) {} // e7
	function effect_t1_e8(mod:Protracker, ch:Int) {} // e8
	
	function effect_t1_e9(mod:Protracker, ch:Int)
	{
		// e9 retrig sample
		if (mod.tick%(mod.channel[ch].data&0x0f)==0)
			mod.channel[ch].samplepos=0;
	}
	
	function effect_t1_ea(mod:Protracker, ch:Int) {} // ea
	function effect_t1_eb(mod:Protracker, ch:Int) {} // eb
		
	function effect_t1_ec(mod:Protracker, ch:Int)
	{
		// ec cut sample
		if (mod.tick==(mod.channel[ch].data&0x0f))
			mod.channel[ch].volume=0;
	}
	
	function effect_t1_ed(mod:Protracker, ch:Int)
	{
		// ed delay sample
		mod.effect_t0_ed(mod, ch);
	}
	
	function effect_t1_ee(mod:Protracker, ch:Int) {} // ee
	function effect_t1_ef(mod:Protracker, ch:Int) {} // ef
	
	/////////////////////////////////////////////////////////////////////////////////////
}

	//===================================================================================
	// Channel
	//-----------------------------------------------------------------------------------
	
	typedef PTChannel =
	{
		sample:Null<Int>,
		period:Null<Int>,
		voiceperiod:Null<Float>,
		note:Null<Int>,
		volume:Null<Int>,
		command:Null<Int>,
		data:Null<Int>,
		samplepos:Null<Float>,
		samplespeed:Null<Float>,
		flags:Null<Int>,
		noteon:Null<Int>,
		slidespeed:Null<Int>,
		slideto:Null<Int>,
		slidetospeed:Null<Int>,
		arpeggio:Null<Int>,
		semitone:Null<Float>,
		vibratospeed:Null<Int>,
		vibratodepth:Null<Int>,
		vibratopos:Null<Int>,
		vibratowave:Null<Int>,	
		instrument:Null<Int>,	
	}

	/////////////////////////////////////////////////////////////////////////////////////
