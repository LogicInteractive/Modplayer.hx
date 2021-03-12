package hxmod.utils;

#if (js && !doc_gen)
#if haxe4
import js.lib.Float64Array as JSFloat64Array;
import js.lib.Uint8Array as JSUInt8Array;
#else
import js.html.Float64Array as JSFloat64Array;
import js.html.Uint8Array as JSUInt8Array;
#end
@:forward
abstract Float64Array(JSFloat64Array) from JSFloat64Array to JSFloat64Array
{
	@:to inline function toArrayBufferView ():ArrayBufferView return this;
	
	public inline static var BYTES_PER_ELEMENT:Int = 8;

	@:generic
	public inline function new<T>(?elements:Int, ?array:Array<T>, ?view:ArrayBufferView, ?buffer:ArrayBuffer,
			?byteoffset:Int = 0, ?len:Null<Int>)
	{
		if (elements != null)
		{
			this = new JSFloat64Array(elements);
		}
		else if (array != null)
		{
			this = new JSFloat64Array(untyped array);
		}
		else if (view != null)
		{
			this = new JSFloat64Array(untyped view);
		}
		else if (buffer != null)
		{
			if (len == null)
			{
				this = new JSFloat64Array(buffer, byteoffset);
			}
			else
			{
				this = new JSFloat64Array(buffer, byteoffset, len);
			}
		}
		else
		{
			this = null;
		}
	}

	@:arrayAccess @:extern inline function __set(idx:Int, val:Float):Float
		return this[idx] = val;

	@:arrayAccess @:extern inline function __get(idx:Int):Float
		return this[idx];

	// non spec haxe conversions
	inline public static function fromBytes(bytes:haxe.io.Bytes, ?byteOffset:Int = 0, ?len:Int):Float64Array
	{
		if (byteOffset == null) return new JSFloat64Array(cast bytes.getData());
		if (len == null) return new JSFloat64Array(cast bytes.getData(), byteOffset);
		return new JSFloat64Array(cast bytes.getData(), byteOffset, len);
	}

	inline public function toBytes():haxe.io.Bytes
	{
		return @:privateAccess new haxe.io.Bytes(cast new JSUInt8Array(this.buffer));
	}

	function toString()
		return this != null ? 'Float64Array [byteLength:${this.byteLength}, length:${this.length}]' : null;
}
#else
import hxmod.utils.ArrayBufferView;

@:forward
abstract Float64Array(ArrayBufferView) from ArrayBufferView to ArrayBufferView
{
	public inline static var BYTES_PER_ELEMENT:Int = 8;

	public var length(get, never):Int;

	@:generic
	public inline function new<T>(?elements:Int, ?buffer:ArrayBuffer, ?array:Array<T>, ?view:ArrayBufferView,
			?byteoffset:Int = 0, ?len:Null<Int>)
	{
		if (elements != null)
		{
			this = new ArrayBufferView(elements, Float64);
		}
		else if (array != null)
		{
			this = new ArrayBufferView(0, Float64).initArray(array);
		}
		else if (view != null)
		{
			this = new ArrayBufferView(0, Float64).initTypedArray(view);
		}
		else if (buffer != null)
		{
			this = new ArrayBufferView(0, Float64).initBuffer(buffer, byteoffset, len);
		}
		else
		{
			throw "Invalid constructor arguments for Float64Array";
		}
	}

	// Public API
	public inline function subarray(begin:Int, end:Null<Int> = null):Float64Array
		return this.subarray(begin, end);

	// non spec haxe conversions
	inline public static function fromBytes(bytes:haxe.io.Bytes, ?byteOffset:Int = 0, ?len:Int):Float64Array
	{
		return new Float64Array(bytes, byteOffset, len);
	}

	inline public function toBytes():haxe.io.Bytes
	{
		return this.buffer;
	}

	// Internal
	inline function get_length()
		return this.length;

	@:noCompletion
	@:arrayAccess @:extern
	public inline function __get(idx:Int):Float
	{
		return ArrayBufferIO.getFloat64(this.buffer, this.byteOffset + (idx * BYTES_PER_ELEMENT));
	}

	@:noCompletion
	@:arrayAccess @:extern
	public inline function __set(idx:Int, val:Float):Float
	{
		ArrayBufferIO.setFloat64(this.buffer, this.byteOffset + (idx * BYTES_PER_ELEMENT), val);
		return val;
	}

	inline function toString()
		return this != null ? 'Float64Array [byteLength:${this.byteLength}, length:${this.length}]' : null;
}
#end // !js
