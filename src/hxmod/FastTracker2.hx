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
class FastTracker2 
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
	public var trackerversion	: UInt;
	public var pattern			: Array<Dynamic>;
	public var instrument		: Array<Dynamic>;
	
	var ramplen					: Float					= 64.0;

	// volume column effect jumptable for 0x50..0xef
	var periodtable				: Float32Array			= new Float32Array([
	//ft -8     -7     -6     -5     -4     -3     -2     -1
	//    0      1      2      3      4      5      6      7
      907.0, 900.0, 894.0, 887.0, 881.0, 875.0, 868.0, 862.0,  // B-3
      856.0, 850.0, 844.0, 838.0, 832.0, 826.0, 820.0, 814.0,  // C-4
      808.0, 802.0, 796.0, 791.0, 785.0, 779.0, 774.0, 768.0,  // C#4
      762.0, 757.0, 752.0, 746.0, 741.0, 736.0, 730.0, 725.0,  // D-4
      720.0, 715.0, 709.0, 704.0, 699.0, 694.0, 689.0, 684.0,  // D#4
      678.0, 675.0, 670.0, 665.0, 660.0, 655.0, 651.0, 646.0,  // E-4
      640.0, 636.0, 632.0, 628.0, 623.0, 619.0, 614.0, 610.0,  // F-4
      604.0, 601.0, 597.0, 592.0, 588.0, 584.0, 580.0, 575.0,  // F#4
      570.0, 567.0, 563.0, 559.0, 555.0, 551.0, 547.0, 543.0,  // G-4
      538.0, 535.0, 532.0, 528.0, 524.0, 520.0, 516.0, 513.0,  // G#4
      508.0, 505.0, 502.0, 498.0, 494.0, 491.0, 487.0, 484.0,  // A-4
      480.0, 477.0, 474.0, 470.0, 467.0, 463.0, 460.0, 457.0,  // A#4
      453.0, 450.0, 447.0, 445.0, 442.0, 439.0, 436.0, 433.0,  // B-4
      428.0
	]);
  
	var pan						: Float32Array			= new Float32Array(32);
	var finalpan				: Float32Array			= new Float32Array(32);
	
	var voleffects_t0			: Array<(mod:FastTracker2, ch:Int)->Void>;
	var voleffects_t1			: Array<(mod:FastTracker2, ch:Int)->Void>;
	var effects_t0				: Array<(mod:FastTracker2, ch:Int)->Void>;
	var effects_t0_e			: Array<(mod:FastTracker2, ch:Int)->Void>;
	var effects_t1				: Array<(mod:FastTracker2, ch:Int)->Void>;
	var effects_t1_e			: Array<(mod:FastTracker2, ch:Int)->Void>;
	var initBPM					: Int;
	var initSpeed				: Int;
	var amigaperiods			: Int;
	var instruments				: Int;
	var channels				: Int;
	var repeatpos				: Int;
	public var pattern			: Array<Dynamic>;
	public var patternlen		: Array<Dynamic>;
	
	public var chvu				: Float32Array;
	public var channel			: Array<FT2Channel>;


	/*	public var delayfirst		: Int;
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
	var patternjump				: Int;*/

	/////////////////////////////////////////////////////////////////////////////////////

	public function new()
	{
		voleffects_t0	= [effect_vol_t0_f0,effect_vol_t0_60, effect_vol_t0_70, effect_vol_t0_80, effect_vol_t0_90, effect_vol_t0_a0,effect_vol_t0_b0, effect_vol_t0_c0, effect_vol_t0_d0, effect_vol_t0_e0];
		voleffects_t1	= [effect_vol_t1_f0,effect_vol_t1_60, effect_vol_t1_70, effect_vol_t1_80, effect_vol_t1_90, effect_vol_t1_a0,effect_vol_t1_b0, effect_vol_t1_c0, effect_vol_t1_d0, effect_vol_t1_e0];
		effects_t0		= [effect_t0_0, effect_t0_1, effect_t0_2, effect_t0_3, effect_t0_4, effect_t0_5, effect_t0_6, effect_t0_7,effect_t0_8, effect_t0_9, effect_t0_a, effect_t0_b, effect_t0_c, effect_t0_d, effect_t0_e, effect_t0_f,effect_t0_g, effect_t0_h, effect_t0_i, effect_t0_j, effect_t0_k, effect_t0_l, effect_t0_m, effect_t0_n,effect_t0_o, effect_t0_p, effect_t0_q, effect_t0_r, effect_t0_s, effect_t0_t, effect_t0_u, effect_t0_v,effect_t0_w, effect_t0_x, effect_t0_y, effect_t0_z];
		effects_t0_e	= [effect_t0_e0, effect_t0_e1, effect_t0_e2, effect_t0_e3, effect_t0_e4, effect_t0_e5, effect_t0_e6, effect_t0_e7,effect_t0_e8, effect_t0_e9, effect_t0_ea, effect_t0_eb, effect_t0_ec, effect_t0_ed, effect_t0_ee, effect_t0_ef];
		effects_t1		= [effect_t1_0, effect_t1_1, effect_t1_2, effect_t1_3, effect_t1_4, effect_t1_5, effect_t1_6, effect_t1_7,effect_t1_8, effect_t1_9, effect_t1_a, effect_t1_b, effect_t1_c, effect_t1_d, effect_t1_e, effect_t1_f,effect_t1_g, effect_t1_h, effect_t1_i, effect_t1_j, effect_t1_k, effect_t1_l, effect_t1_m, effect_t1_n,effect_t1_o, effect_t1_p, effect_t1_q, effect_t1_r, effect_t1_s, effect_t1_t, effect_t1_u, effect_t1_v,effect_t1_w, effect_t1_x, effect_t1_y, effect_t1_z];
		effects_t1_e	= [effect_t1_e0, effect_t1_e1, effect_t1_e2, effect_t1_e3, effect_t1_e4, effect_t1_e5, effect_t1_e6, effect_t1_e7,effect_t1_e8, effect_t1_e9, effect_t1_ea, effect_t1_eb, effect_t1_ec, effect_t1_ed, effect_t1_ee, effect_t1_ef];

		clearsong();
		initialize();
	
		for (i in 0...32)
			pan[i]=finalpan[i]=0.5;		
	
		for (i in 0...4)
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
		trackerversion=0x0104;
		
		songlen=1;
		repeatpos=0;
		channels = 0;
		instruments=32;
		amigaperiods=0;	
		
		initSpeed=6;
		initBPM=125;		
		
		patterntable = new ArrayBuffer(256);
		for (i in 0...256)
			patterntable[i]=0;

		pattern=new Array();
		instrument=new Array(instruments);
		
		for (i in 0...32)
		{
			instrument[i] = {};
			instrument[i].name="";
			instrument[i].samples = [];
		}

		chvu=new Float32Array(2);
	}
	
	// initialize all player variables
	public function initialize()
	{
		syncqueue=[];

		tick=-1;
		position=0;
		row=0;
		flags=0;

		volume=64;
		if (cast initSpeed)
			speed = initSpeed;
			
		if (cast initBPM)
			bpm = initBPM;
			
		stt=0; //this.samplerate/(this.bpm*0.4);
		breakrow=0;
		patternjump=0;
		patterndelay=0;
		patternwait=0;
		endofsong=false;
		looprow=0;
		loopstart=0;
		loopcount=0;

		globalvolslide=0;

		channel = [];
		for (i in 0...channels)
			channel[i] = {
				instrument=0,
				sampleindex=0,
				note:36,
				command=0,
				data=0,
				samplepos=0,
				samplespeed=0,
				flags=0,
				noteon=0,
				volslide=0,
				slidespeed=0,
				slideto=0,
				slidetospeed=0,
				arpeggio=0,
				period=640,
				frequency=8363,
				volume=64,
				voiceperiod=0,
				voicevolume=0,
				finalvolume=0,
				semitone=12,
				vibratospeed=0,
				vibratodepth=0,
				vibratopos=0,
				vibratowave=0,
				volramp=1.0,
				volrampfrom=0,
				volenvpos=0,
				panenvpos=0,
				fadeoutpos=0,
				playdir=1,
				volramp=0,
				volrampfrom=0,
				trigramp=0,
				trigrampfrom=0.0,
				currentsample=0.0,
				lastsample=0.0,
				oldfinalvolume=0.0,				
			};
	}
	
	// parse the module from local buffer
	public function parse(buffer:UInt8Array):Bool
	{
		if (buffer == null)
			return false;

		var i:Int;
		var j:Int;
		var c:Int;
		var offset:Int;
		var datalen:Int;
		var hdrlen:Int;
		

		// check xm signature, type and tracker version
		for (i in 0...17)
			signature+=String.fromCharCode(buffer[i]);
  
		if (signature != "Extended Module: ")
			return false;
  
		if (buffer[37] != 0x1a)
			return false;
  
		signature="X.M.";
		trackerversion=le_word(buffer, 58);
  
		if (trackerversion < 0x0104)
			return false; // older versions not currently supported

		// song title
		i=0;
		while (buffer[i] && i < 20)
			title+=dos2utf(buffer[17+i++]);		

		offset=60;
		hdrlen=le_dword(buffer, offset);
		songlen=le_word(buffer, offset+4);
		repeatpos=le_word(buffer, offset+6);
		channels=le_word(buffer, offset+8);
		patterns=le_word(buffer, offset+10);
		instruments=le_word(buffer, offset+12);

		amigaperiods=(!le_word(buffer, offset+14))&1;

		initSpeed=le_word(buffer, offset+16);
		initBPM=le_word(buffer, offset+18);			
			
		var maxpatt:Int=0;
		for (i in 0...256)
		{
			patterntable[i]=buffer[offset+20+i];
			if (patterntable[i] > maxpatt)
				maxpatt=patterntable[i];
		}
		maxpatt++;

		// allocate arrays for pattern data
		pattern=new Array(maxpatt);
		patternlen=new Array(maxpatt);			
			
		

		for (i in 0...maxpatt)
		{
			// initialize the pattern to defaults prior to unpacking
			patternlen[i]=64;
			pattern[i]=new UInt8Array(channelspatternlen[i]*5);
			for (row in 0...patternlen[i])
			{
				for (ch in 0...channels)
				{
					pattern[i][row*channels*5 + ch*5 + 0]=255; // note (255=no note)
					pattern[i][row*channels*5 + ch*5 + 1]=0; // instrument
					pattern[i][row*channels*5 + ch*5 + 2]=255 // volume
					pattern[i][row*channels*5 + ch*5 + 3]=255; // command
					pattern[i][row*channels*5 + ch*5 + 4]=0; // parameter
				}
			}
		}		
		
		// load and unpack patterns
		offset+=hdrlen; // initial offset for patterns
		i=0;
		while (i < this.patterns)
		{
			this.patternlen[i]=le_word(buffer, offset+5);
			this.pattern[i]=new UInt8Array(this.channels*this.patternlen[i]*5);

			// initialize pattern to defaults prior to unpacking
			for (k in 0...patternlen[i]*channels)
			{
				pattern[i][k*5 + 0]=0; // note
				pattern[i][k*5 + 1]=0; // instrument
				pattern[i][k*5 + 2]=0; // volume
				pattern[i][k*5 + 3]=0; // command
				pattern[i][k*5 + 4]=0; // parameter
			}    
			
			datalen=le_word(buffer, offset+7);
			offset+=le_dword(buffer, offset); // jump over header
			
			j=0; 
			k=0;
			
			while (j < datalen)
			{
				c=buffer[offset+j++];
				
				if (c&128)
				{
				// first byte is a bitmask
				if (cast c& 1)
					pattern[i][k+0]=buffer[offset+j++];
				
				if (cast c&2)
					pattern[i][k+1]=buffer[offset+j++];
				
				if (cast c&4)
					pattern[i][k+2]=buffer[offset+j++];
				
				if (cast c&8)
					pattern[i][k+3]=buffer[offset+j++];
				
				if (cast c&16)
					pattern[i][k+4]=buffer[offset+j++];
				} 
				else
				{
					// first byte is note -> all columns present sequentially
					pattern[i][k+0]=c;
					pattern[i][k+1]=buffer[offset+j++];
					pattern[i][k+2]=buffer[offset+j++];
					pattern[i][k+3]=buffer[offset+j++];
					pattern[i][k+4]=buffer[offset+j++];
				}
				
				k+=5;
			}

		while (k < 0...this.patternlen[i]*channels*5)
		{      
			// remap note to st3-style, 255=no note, 254=note off
			if (pattern[i][k+0]>=97)
				pattern[i][k+0]=254;
			else if (pattern[i][k+0]==0)
				pattern[i][k+0]=255;
			else
				pattern[i][k + 0]--;
				
			k += 5;
		}

		// command 255=no command
		if (pattern[i][k+3]==0 && pattern[i][k+4]==0) 
			pattern[i][k+3]=255;

		// remap volume column setvol to 0x00..0x40, tone porta to 0x50..0x5f and 0xff for nop
		if (pattern[i][k+2]<0x10)
			pattern[i][k+2]=0xff;
			
		else if (pattern[i][k+2]>=0x10 && pattern[i][k+2]<=0x50)
			pattern[i][k+2]-=0x10;
		else if (pattern[i][k+2]>=0xf0) 
			pattern[i][k+2]-=0xa0;
    }
    
    // unpack next pattern
    offset+=j;
    i++;
	
	}
	patterns=maxpatt;			
			
	// instruments
	instrument=new Array(instruments);
	i = 0;
	
	while(i<instruments)
	{
		hdrlen=le_dword(buffer, offset);
		instrument[i] = {};
		instrument[i].sample=new Array();
		instrument[i].name="";
		j=0;
		
		while(buffer[offset+4+j]!=null && j<22)
		{
			instrument[i].name+=dos2utf(buffer[offset+4+j++]);
		}
		
		instrument[i].samples=le_word(buffer, offset+27);

		// initialize to defaults
		instrument[i].samplemap=new UInt8Array(96);
		for (j in 0...96) 
			instrument[i].samplemap[j]=0;
		
		instrument[i].volenv=new Float32Array(325);
		instrument[i].panenv=new Float32Array(325);
		instrument[i].voltype=0;
		instrument[i].pantype=0;
		
		for(j in 0...instrument[i].samples)
		{
			instrument[i].sample[j]={ bits:8, stereo:0, bps:1, length:0, loopstart:0, looplength:0, loopend:0, looptype:0, volume:64, finetune:0, relativenote:0, panning:128, name:"", data:new Float32Array(0) };
		}

		if (this.instrument[i].samples)
		{
			var smphdrlen=le_dword(buffer, offset+29);

			
			
			
			
			
			
			
			
			
			
			for(j=0;j<96;j++) this.instrument[i].samplemap[j]=buffer[offset+33+j];

			// envelope points. the xm specs say 48 bytes per envelope, but while that may
			// technically be correct, what they don't say is that it means 12 pairs of
			// little endian words. first word is the x coordinate, second is y. point
			// 0 always has x=0.
			var tmp_volenv=new Array(12);
			var tmp_panenv=new Array(12);
			for(j=0;j<12;j++) {
			tmp_volenv[j]=new Uint16Array([le_word(buffer, offset+129+j*4), le_word(buffer, offset+129+j*4+2)]);
			tmp_panenv[j]=new Uint16Array([le_word(buffer, offset+177+j*4), le_word(buffer, offset+177+j*4+2)]);
			}

      // are envelopes enabled?
      this.instrument[i].voltype=buffer[offset+233]; // 1=enabled, 2=sustain, 4=loop
      this.instrument[i].pantype=buffer[offset+234];

      // pre-interpolate the envelopes to arrays of [0..1] float32 values which
      // are stepped through at a rate of one per tick. max tick count is 0x0144.

      // volume envelope
      for(j=0;j<325;j++) this.instrument[i].volenv[j]=1.0;
      if (this.instrument[i].voltype&1) {
        for(j=0;j<325;j++) {
          var p, delta;
          p=1;
          while(tmp_volenv[p][0]<j && p<11) p++;
          if (tmp_volenv[p][0] == tmp_volenv[p-1][0]) { delta=0; } else {
            delta=(tmp_volenv[p][1]-tmp_volenv[p-1][1]) / (tmp_volenv[p][0]-tmp_volenv[p-1][0]);
          }
          this.instrument[i].volenv[j]=(tmp_volenv[p-1][1] + delta*(j-tmp_volenv[p-1][0]))/64.0;
        }
        this.instrument[i].volenvlen=tmp_volenv[Math.max(0, buffer[offset+225]-1)][0];
        this.instrument[i].volsustain=tmp_volenv[buffer[offset+227]][0];
        this.instrument[i].volloopstart=tmp_volenv[buffer[offset+228]][0];
        this.instrument[i].volloopend=tmp_volenv[buffer[offset+229]][0];
      }

      // pan envelope
      for(j=0;j<325;j++) this.instrument[i].panenv[j]=0.5;
      if (this.instrument[i].pantype&1) {
        for(j=0;j<325;j++) {
          var p, delta;
          p=1;
          while(tmp_panenv[p][0]<j && p<11) p++;
          if (tmp_panenv[p][0] == tmp_panenv[p-1][0]) { delta=0; } else {
            delta=(tmp_panenv[p][1]-tmp_panenv[p-1][1]) / (tmp_panenv[p][0]-tmp_panenv[p-1][0]);
          }
          this.instrument[i].panenv[j]=(tmp_panenv[p-1][1] + delta*(j-tmp_panenv[p-1][0]))/64.0;
        }
        this.instrument[i].panenvlen=tmp_panenv[Math.max(0, buffer[offset+226]-1)][0];
        this.instrument[i].pansustain=tmp_panenv[buffer[offset+230]][0];
        this.instrument[i].panloopstart=tmp_panenv[buffer[offset+231]][0];
        this.instrument[i].panloopend=tmp_panenv[buffer[offset+232]][0];
      }

      // vibrato
      this.instrument[i].vibratotype=buffer[offset+235];
      this.instrument[i].vibratosweep=buffer[offset+236];
      this.instrument[i].vibratodepth=buffer[offset+237];
      this.instrument[i].vibratorate=buffer[offset+238];

      // volume fade out
      this.instrument[i].volfadeout=le_word(buffer, offset+239);

      // sample headers
      offset+=hdrlen;
      this.instrument[i].sample=new Array(this.instrument[i].samples);
      for(j=0;j<this.instrument[i].samples;j++) {
        datalen=le_dword(buffer, offset+0);

        this.instrument[i].sample[j]=new Object();
        this.instrument[i].sample[j].bits=(buffer[offset+14]&16)?16:8;
        this.instrument[i].sample[j].stereo=0;
        this.instrument[i].sample[j].bps=(this.instrument[i].sample[j].bits==16)?2:1; // bytes per sample

        // sample length and loop points are in BYTES even for 16-bit samples!
        this.instrument[i].sample[j].length=datalen / this.instrument[i].sample[j].bps;
        this.instrument[i].sample[j].loopstart=le_dword(buffer, offset+4) / this.instrument[i].sample[j].bps;
        this.instrument[i].sample[j].looplength=le_dword(buffer, offset+8) / this.instrument[i].sample[j].bps;
        this.instrument[i].sample[j].loopend=this.instrument[i].sample[j].loopstart+this.instrument[i].sample[j].looplength;
        this.instrument[i].sample[j].looptype=buffer[offset+14]&0x03;

        this.instrument[i].sample[j].volume=buffer[offset+12];

        // finetune and seminote tuning
        if (buffer[offset+13]<128) {
          this.instrument[i].sample[j].finetune=buffer[offset+13];
        } else {
          this.instrument[i].sample[j].finetune=buffer[offset+13]-256;
        }
        if (buffer[offset+16]<128) {
          this.instrument[i].sample[j].relativenote=buffer[offset+16];
        } else {
          this.instrument[i].sample[j].relativenote=buffer[offset+16]-256;
        }

        this.instrument[i].sample[j].panning=buffer[offset+15];

        k=0; this.instrument[i].sample[j].name="";
        while(buffer[offset+18+k] && k<22) this.instrument[i].sample[j].name+=dos2utf(buffer[offset+18+k++]);

        offset+=smphdrlen;
      }

      // sample data (convert to signed float32)
      for(j=0;j<this.instrument[i].samples;j++) {
        this.instrument[i].sample[j].data=new Float32Array(this.instrument[i].sample[j].length);
        c=0;
        if (this.instrument[i].sample[j].bits==16) {
          for(k=0;k<this.instrument[i].sample[j].length;k++) {
            c+=s_le_word(buffer, offset+k*2);
            if (c<-32768) c+=65536;
            if (c>32767) c-=65536;
            this.instrument[i].sample[j].data[k]=c/32768.0;
          }
        } else {
          for(k=0;k<this.instrument[i].sample[j].length;k++) {
            c+=s_byte(buffer, offset+k);
            if (c<-128) c+=256;
            if (c>127) c-=256;
            this.instrument[i].sample[j].data[k]=c/128.0;
          }
        }
        offset+=this.instrument[i].sample[j].length * this.instrument[i].sample[j].bps;
      }
    } else {
      offset+=hdrlen;
    }
    i++;
  }

  this.mixval=4.0-2.0*(this.channels/32.0);

  this.chvu=new Float32Array(this.channels);
  for(i=0;i<this.channels;i++) this.chvu[i]=0.0;

  return true;
}
			
			
	
		
/*		for (i in 0...4) 
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
			
*/		return true;
	}

	
	// calculate period value for note
	public function calcperiod(mod:FastTracker2, note:Int, finetune:Float):Float
	{
		var pv:Float;
		if (cast mod.amigaperiods)
		{
			var ft=Math.floor(finetune/16.0); // = -8 .. 7
			var p1=mod.periodtable[ 8 + (note%12)*8 + ft ];
			var p2=mod.periodtable[ 8 + (note%12)*8 + ft + 1];
			ft=(finetune/16.0) - ft;
			pv=((1.0-ft)*p1 + ft*p2)*( 16.0/Math.pow(2, Math.floor(note/12)-1) );
		}
		else
		{
			pv=7680.0 - note*64.0 - finetune/2;
		}
		return pv;
	}
	

	// advance player
	public function advance(mod:FastTracker2)
	{
		mod.stt=Math.floor((125.0/mod.bpm) * (1/50.0)*mod.samplerate); // 50Hz

		// advance player
		mod.tick++;
		mod.flags|=1;		
/*		
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
	*/
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
	
	typedef FT2Channel =
	{
		instrument:Int,
		sampleindex:Int,
		note:Int,
		command:Int,
		data:Int,
		samplepos:Int,
		samplespeed:Int,
		flags:Int,
		noteon:Int,
		volslide:Int,
		slidespeed:Int,
		slideto:Int,
		slidetospeed:Int,
		arpeggio:Int,
		period:Int,
		frequency:Int,
		volume:Int,
		voiceperiod:Int,
		voicevolume:Int,
		finalvolume:Int,
		semitone:Int,
		vibratospeed:Int,
		vibratodepth:Int,
		vibratopos:Int,
		vibratowave:Int,
		volramp:Float,
		volrampfrom:Int,
		volenvpos:Int,
		panenvpos:Int,
		fadeoutpos:Int,
		playdir:Int,
		volramp:Int,
		volrampfrom:Int,
		trigramp:Int,
		trigrampfrom:Float,
		currentsample:Float,
		lastsample:Float,
		oldfinalvolume:Float,				
	}

	/////////////////////////////////////////////////////////////////////////////////////
