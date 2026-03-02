package flixel.system;

import openfl.events.Event;
import openfl.events.IEventDispatcher;
import openfl.media.Sound;
import openfl.media.SoundChannel;
import openfl.media.SoundTransform;
import openfl.net.URLRequest;
import flixel.FlxBasic;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxSoundAsset;
import flixel.tweens.FlxTween;
import flixel.util.FlxStringUtil;
import openfl.Assets;
#if flash11
import flash.utils.ByteArray;
#end
#if (openfl >= "8.0.0")
import openfl.utils.AssetType;
#end

/**
 * Versão modernizada do FlxSound para Haxe 4.3.6
 * Compatível com as últimas versões do OpenFL e Lime
 */
class FlxSound extends FlxBasic
{
	// ============================================================================
	// PROPRIEDADES PÚBLICAS
	// ============================================================================
	
	public var x:Float;
	public var y:Float;
	public var persist:Bool;
	public var name(default, null):String;
	public var artist(default, null):String;
	public var amplitude(default, null):Float;
	public var amplitudeLeft(default, null):Float;
	public var amplitudeRight(default, null):Float;
	public var autoDestroy:Bool;
	public var onComplete:Void->Void;
	public var onPlay:Void->Void;
	public var onPause:Void->Void;
	public var onResume:Void->Void;
	public var onStop:Void->Void;
	public var onLoop:Void->Void;
	public var looped:Bool;
	public var loopTime:Float = 0;
	public var endTime:Null<Float>;
	public var fadeTween:FlxTween;
	public var group(default, set):FlxSoundGroup;
	
	// ============================================================================
	// NOVAS PROPRIEDADES (Haxe 4.3.6 compatíveis)
	// ============================================================================
	
	/** Playback rate (velocidade de reprodução) */
	public var playbackRate(get, set):Float;
	
	/** Stereo pan (esquerda/direita) */
	public var pan(get, set):Float;
	
	/** Volume atual */
	public var volume(get, set):Float;
	
	/** Posição atual em ms */
	public var time(get, set):Float;
	
	/** Duração total em ms */
	public var length(get, never):Float;
	
	/** Se está tocando */
	public var playing(get, never):Bool;
	
	/** Se está pausado */
	public var paused(get, never):Bool;
	
	/** Volume normalizado (0-1) */
	public var normalizedVolume(get, never):Float;
	
	/** Fade direction */
	public var fadeDirection:Int = 0;
	
	/** Crossfade target */
	private var crossfadeTarget:FlxSound;
	
	/** Crossfade duration */
	private var crossfadeDuration:Float = 0;
	
	/** Crossfade progress */
	private var crossfadeProgress:Float = 0;
	
	/** Tags para categorização */
	public var tags:Array<String> = [];
	
	/** Prioridade (para gerenciamento de canais) */
	public var priority:Int = 0;
	
	/** Categoria do som (SFX, MUSIC, VOICE, etc) */
	public var category:SoundCategory = SoundCategory.SFX;
	
	/** Metadados personalizados */
	public var metadata:Map<String, Dynamic> = [];

	// ============================================================================
	// PROPRIEDADES PRIVADAS
	// ============================================================================
	
	var _sound:Sound;
	var _channel:SoundChannel;
	var _transform:SoundTransform;
	var _paused:Bool;
	var _volume:Float;
	var _time:Float = 0;
	var _length:Float = 0;
	var _pitch:Float = 1.0;
	var _volumeAdjust:Float = 1.0;
	var _target:FlxObject;
	var _radius:Float;
	var _proximityPan:Bool;
	var _alreadyPaused:Bool = false;
	var _fadeFrom:Float = 0;
	var _fadeTo:Float = 0;
	var _fadeDuration:Float = 0;
	var _fadeElapsed:Float = 0;
	var _playTime:Float = 0;
	var _loopCount:Int = 0;
	var _maxLoops:Int = 0;

	// ============================================================================
	// CONSTRUTOR E MÉTODOS BASE
	// ============================================================================
	
	public function new()
	{
		super();
		reset();
	}
	
	function reset():Void
	{
		destroy();
		
		x = 0;
		y = 0;
		_time = 0;
		_paused = false;
		_volume = 1.0;
		_pitch = 1.0;
		_volumeAdjust = 1.0;
		looped = false;
		loopTime = 0.0;
		endTime = 0.0;
		_target = null;
		_radius = 0;
		_proximityPan = false;
		visible = false;
		amplitude = 0;
		amplitudeLeft = 0;
		amplitudeRight = 0;
		autoDestroy = false;
		_loopCount = 0;
		_maxLoops = 0;
		tags = [];
		priority = 0;
		category = SoundCategory.SFX;
		metadata = [];
		
		if (_transform == null)
			_transform = new SoundTransform();
		_transform.pan = 0;
	}
	
	override public function destroy():Void
	{
		_transform = null;
		_target = null;
		name = null;
		artist = null;
		onComplete = null;
		onPlay = null;
		onPause = null;
		onResume = null;
		onStop = null;
		onLoop = null;
		crossfadeTarget = null;
		
		if (_channel != null)
		{
			_channel.removeEventListener(Event.SOUND_COMPLETE, stopped);
			_channel.stop();
			_channel = null;
		}
		
		if (_sound != null)
		{
			_sound.removeEventListener(Event.ID3, gotID3);
			_sound = null;
		}
		
		super.destroy();
	}
	
	override public function update(elapsed:Float):Void
	{
		if (!playing)
			return;
			
		_playTime += elapsed;
		_time = _channel.position;
		
		// Atualizar fade manual (alternativa ao FlxTween)
		updateFade(elapsed);
		
		// Atualizar crossfade
		updateCrossfade(elapsed);
		
		// Proximidade/pan
		updateProximity();
		
		// Amplitude
		updateAmplitude();
		
		// Verificar endTime
		if (endTime != null && _time >= endTime)
			stop();
			
		// Verificar maxLoops
		if (_maxLoops > 0 && _loopCount >= _maxLoops)
			stop();
			
		// Callback de update
		if (onUpdate != null)
			onUpdate(elapsed);
	}
	
	// ============================================================================
	// MÉTODOS DE CARREGAMENTO
	// ============================================================================
	
	public function loadEmbedded(EmbeddedSound:FlxSoundAsset, Looped:Bool = false, AutoDestroy:Bool = false, ?OnComplete:Void->Void):FlxSound
	{
		if (EmbeddedSound == null)
			return this;
			
		cleanup(true);
		
		if (Std.isOfType(EmbeddedSound, Sound))
		{
			_sound = cast EmbeddedSound;
		}
		else if (Std.isOfType(EmbeddedSound, Class))
		{
			_sound = Type.createInstance(cast EmbeddedSound, []);
		}
		else if (Std.isOfType(EmbeddedSound, String))
		{
			var path:String = cast EmbeddedSound;
			if (Assets.exists(path, AssetType.SOUND) || Assets.exists(path, AssetType.MUSIC))
				_sound = Assets.getSound(path);
			else
				FlxG.log.error('Could not find a Sound asset with an ID of \'$path\'.');
		}
		
		return init(Looped, AutoDestroy, OnComplete);
	}
	
	public function loadStream(SoundURL:String, Looped:Bool = false, AutoDestroy:Bool = false, ?OnComplete:Void->Void, ?OnLoad:Void->Void):FlxSound
	{
		cleanup(true);
		
		_sound = new Sound();
		_sound.addEventListener(Event.ID3, gotID3);
		
		var loadCallback:Event->Void = null;
		loadCallback = function(e:Event)
		{
			(e.target : IEventDispatcher).removeEventListener(e.type, loadCallback);
			if (_sound == e.target)
			{
				_length = _sound.length;
				if (OnLoad != null)
					OnLoad();
			}
		}
		
		_sound.addEventListener(Event.COMPLETE, loadCallback, false, 0, true);
		_sound.load(new URLRequest(SoundURL));
		
		return init(Looped, AutoDestroy, OnComplete);
	}
	
	#if flash11
	public function loadByteArray(Bytes:ByteArray, Looped:Bool = false, AutoDestroy:Bool = false, ?OnComplete:Void->Void):FlxSound
	{
		cleanup(true);
		
		_sound = new Sound();
		_sound.addEventListener(Event.ID3, gotID3);
		_sound.loadCompressedDataFromByteArray(Bytes, Bytes.length);
		
		return init(Looped, AutoDestroy, OnComplete);
	}
	#end
	
	function init(Looped:Bool = false, AutoDestroy:Bool = false, ?OnComplete:Void->Void):FlxSound
	{
		looped = Looped;
		autoDestroy = AutoDestroy;
		updateTransform();
		exists = true;
		onComplete = OnComplete;
		_length = (_sound == null) ? 0 : _sound.length;
		endTime = _length;
		return this;
	}
	
	// ============================================================================
	// MÉTODOS DE CONTROLE
	// ============================================================================
	
	public function play(ForceRestart:Bool = false, StartTime:Float = 0.0, ?EndTime:Float):FlxSound
	{
		if (!exists)
			return this;
			
		if (ForceRestart)
			cleanup(false, true);
		else if (playing)
			return this;
			
		if (_paused)
			resume();
		else
			startSound(StartTime);
			
		endTime = EndTime;
		_playTime = 0;
		_loopCount = 0;
		
		if (onPlay != null)
			onPlay();
			
		return this;
	}
	
	public function resume():FlxSound
	{
		if (_paused)
		{
			startSound(_time);
			if (onResume != null)
				onResume();
		}
		return this;
	}
	
	public function pause():FlxSound
	{
		if (!playing)
			return this;
			
		_time = _channel.position;
		_paused = true;
		cleanup(false, false);
		
		if (onPause != null)
			onPause();
			
		return this;
	}
	
	public function stop():FlxSound
	{
		cleanup(autoDestroy, true);
		
		if (onStop != null)
			onStop();
			
		return this;
	}
	
	public function fadeOut(Duration:Float = 1, ?To:Float = 0, ?onComplete:FlxTween->Void):FlxSound
	{
		if (fadeTween != null)
			fadeTween.cancel();
			
		fadeTween = FlxTween.num(volume, To, Duration, 
			{onComplete: onComplete}, 
			volumeTween
		);
		
		fadeDirection = -1;
		return this;
	}
	
	public function fadeIn(Duration:Float = 1, From:Float = 0, To:Float = 1, ?onComplete:FlxTween->Void):FlxSound
	{
		if (!playing)
			play();
			
		if (fadeTween != null)
			fadeTween.cancel();
			
		fadeTween = FlxTween.num(From, To, Duration, 
			{onComplete: onComplete}, 
			volumeTween
		);
		
		fadeDirection = 1;
		return this;
	}
	
	public function crossfade(target:FlxSound, duration:Float = 1.0):FlxSound
	{
		if (target == null || target == this)
			return this;
			
		crossfadeTarget = target;
		crossfadeDuration = duration;
		crossfadeProgress = 0;
		
		// Iniciar fade out deste som
		fadeOut(duration, 0, function(_) {
			stop();
		});
		
		// Iniciar fade in do target
		if (!target.playing)
			target.play();
		target.fadeIn(duration, 0, 1);
		
		return this;
	}
	
	// ============================================================================
	// MÉTODOS DE POSICIONAMENTO
	// ============================================================================
	
	public function proximity(X:Float, Y:Float, TargetObject:FlxObject, Radius:Float, Pan:Bool = true):FlxSound
	{
		x = X;
		y = Y;
		_target = TargetObject;
		_radius = Radius;
		_proximityPan = Pan;
		return this;
	}
	
	public function setPosition(X:Float = 0, Y:Float = 0):Void
	{
		x = X;
		y = Y;
	}
	
	// ============================================================================
	// MÉTODOS DE UTILIDADE
	// ============================================================================
	
	public function addTag(tag:String):FlxSound
	{
		if (!tags.contains(tag))
			tags.push(tag);
		return this;
	}
	
	public function removeTag(tag:String):FlxSound
	{
		tags.remove(tag);
		return this;
	}
	
	public function hasTag(tag:String):Bool
	{
		return tags.contains(tag);
	}
	
	public function setMetadata(key:String, value:Dynamic):FlxSound
	{
		metadata.set(key, value);
		return this;
	}
	
	public function getMetadata(key:String):Dynamic
	{
		return metadata.get(key);
	}
	
	public function setLoopCount(loops:Int):FlxSound
	{
		_maxLoops = loops;
		return this;
	}
	
	public function getPlayTime():Float
	{
		return _playTime;
	}
	
	public function getRemainingTime():Float
	{
		if (!playing)
			return 0;
		return _length - _time;
	}
	
	public function getProgress():Float
	{
		if (_length <= 0)
			return 0;
		return _time / _length;
	}
	
	public function getActualVolume():Float
	{
		return _volume * _volumeAdjust;
	}
	
	// ============================================================================
	// MÉTODOS INTERNOS
	// ============================================================================
	
	function startSound(StartTime:Float):Void
	{
		if (_sound == null)
			return;
			
		_time = StartTime;
		_paused = false;
		_channel = _sound.play(_time, 0, _transform);
		
		if (_channel != null)
		{
			#if (sys && openfl_legacy)
			pitch = _pitch;
			#end
			_channel.addEventListener(Event.SOUND_COMPLETE, stopped);
			active = true;
		}
		else
		{
			exists = false;
			active = false;
		}
	}
	
	function stopped(?_):Void
	{
		_loopCount++;
		
		if (onLoop != null && looped)
			onLoop();
			
		if (onComplete != null)
			onComplete();
			
		if (looped && (_maxLoops <= 0 || _loopCount < _maxLoops))
		{
			cleanup(false);
			play(false, loopTime, endTime);
		}
		else
		{
			cleanup(autoDestroy);
		}
	}
	
	function cleanup(destroySound:Bool, resetPosition:Bool = true):Void
	{
		if (destroySound)
		{
			reset();
			return;
		}
		
		if (_channel != null)
		{
			_channel.removeEventListener(Event.SOUND_COMPLETE, stopped);
			_channel.stop();
			_channel = null;
		}
		
		active = false;
		
		if (resetPosition)
		{
			_time = 0;
			_paused = false;
		}
	}
	
	function gotID3(_):Void
	{
		name = _sound.id3.songName;
		artist = _sound.id3.artist;
		_sound.removeEventListener(Event.ID3, gotID3);
	}
	
	function updateTransform():Void
	{
		if (_transform == null)
			return;
			
		_transform.volume = #if FLX_SOUND_SYSTEM 
			(FlxG.sound.muted ? 0 : 1) * FlxG.sound.volume * 
			#end
			(group != null ? group.volume : 1) * _volume * _volumeAdjust;
			
		if (_channel != null)
		{
			_channel.soundTransform = _transform;
			
			@:privateAccess
			if (_channel.__source != null)
			{
				#if cpp
				@:privateAccess
				_channel.__source.__backend.setPitch(_pitch);
				#end
			}
		}
	}
	
	function volumeTween(f:Float):Void
	{
		volume = f;
	}
	
	function updateFade(elapsed:Float):Void
	{
		// Fade manual (se não estiver usando FlxTween)
		if (_fadeDuration > 0)
		{
			_fadeElapsed += elapsed;
			var progress = Math.min(_fadeElapsed / _fadeDuration, 1);
			volume = _fadeFrom + (_fadeTo - _fadeFrom) * progress;
			
			if (progress >= 1)
			{
				_fadeDuration = 0;
				if (_fadeTo <= 0 && fadeDirection == -1)
					stop();
			}
		}
	}
	
	function updateCrossfade(elapsed:Float):Void
	{
		if (crossfadeTarget != null)
		{
			crossfadeProgress += elapsed / crossfadeDuration;
			if (crossfadeProgress >= 1)
			{
				crossfadeTarget = null;
				crossfadeDuration = 0;
			}
		}
	}
	
	function updateProximity():Void
	{
		if (_target == null)
			return;
			
		var targetPos = _target.getPosition();
		var distance = targetPos.distanceTo(FlxPoint.weak(x, y));
		targetPos.put();
		
		var radialMultiplier = 1 - FlxMath.bound(distance / _radius, 0, 1);
		
		if (_proximityPan)
		{
			var d:Float = (x - _target.x) / _radius;
			_transform.pan = FlxMath.bound(d, -1, 1);
		}
		
		_volumeAdjust = radialMultiplier;
		updateTransform();
	}
	
	function updateAmplitude():Void
	{
		if (_transform.volume > 0)
		{
			amplitudeLeft = _channel.leftPeak / _transform.volume;
			amplitudeRight = _channel.rightPeak / _transform.volume;
			amplitude = (amplitudeLeft + amplitudeRight) * 0.5;
		}
		else
		{
			amplitudeLeft = 0;
			amplitudeRight = 0;
			amplitude = 0;
		}
	}
	
	// ============================================================================
	// GETTERS E SETTERS
	// ============================================================================
	
	function set_group(group:FlxSoundGroup):FlxSoundGroup
	{
		if (this.group != group)
		{
			var oldGroup = this.group;
			this.group = group;
			
			if (oldGroup != null)
				oldGroup.remove(this);
				
			if (group != null)
				group.add(this);
				
			updateTransform();
		}
		return group;
	}
	
	inline function get_playing():Bool return _channel != null;
	inline function get_paused():Bool return _paused;
	inline function get_volume():Float return _volume;
	inline function get_normalizedVolume():Float return getActualVolume();
	inline function get_pitch():Float return _pitch;
	inline function get_pan():Float return _transform.pan;
	inline function get_time():Float return _time;
	inline function get_length():Float return _length;
	inline function get_playbackRate():Float return _pitch;
	
	function set_volume(Volume:Float):Float
	{
		_volume = FlxMath.bound(Volume, 0, 1);
		updateTransform();
		return Volume;
	}
	
	function set_pitch(v:Float):Float
	{
		_pitch = v;
		updateTransform();
		return v;
	}
	
	function set_pan(pan:Float):Float
	{
		_transform.pan = pan;
		updateTransform();
		return pan;
	}
	
	function set_time(time:Float):Float
	{
		if (playing)
		{
			cleanup(false, true);
			startSound(time);
		}
		return _time = time;
	}
	
	function set_playbackRate(rate:Float):Float
	{
		return pitch = rate;
	}
	
	// ============================================================================
	// EVENTOS DE FOCO
	// ============================================================================
	
	#if FLX_SOUND_SYSTEM
	@:allow(flixel.system.frontEnds.SoundFrontEnd)
	function onFocus():Void
	{
		if (!_alreadyPaused)
			resume();
	}
	
	@:allow(flixel.system.frontEnds.SoundFrontEnd)
	function onFocusLost():Void
	{
		_alreadyPaused = _paused;
		pause();
	}
	#end
	
	// ============================================================================
	// OVERRIDES
	// ============================================================================
	
	override public function toString():String
	{
		return FlxStringUtil.getDebugString([
			"playing" => playing,
			"paused" => paused,
			"time" => time,
			"length" => length,
			"volume" => volume,
			"pitch" => pitch,
			"looped" => looped,
			"category" => category
		]);
	}
}

// ============================================================================
// ENUMS E TIPOS AUXILIARES
// ============================================================================

enum SoundCategory
{
	SFX;
	MUSIC;
	VOICE;
	AMBIENT;
	UI;
}

typedef ReverbParams = {
	decay:Float,
	density:Float,
	diffusion:Float,
	gain:Float,
	highCut:Float,
	lowCut:Float,
	roomSize:Float
}