/*
 * Copyright (C) 2024 Mobile Porting Team
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package mobile;

import lime.system.System as LimeSystem;
import haxe.io.Path;
import haxe.Exception;
#if android
import android.content.Context;
import android.os.Environment;
import android.Permissions;
import android.Settings;
import android.Tools;
import android.os.Build.VERSION;
import android.os.Build.VERSION_CODES;
#end
#if sys
import sys.io.File;
import sys.FileSystem;
#end

using StringTools;

/**
 * A storage class for mobile.
 * @author Karim Akra and Lily Ross (mcagabe19)
 */
class StorageUtil
{
	#if sys
	public static final rootDir:String = LimeSystem.applicationStorageDirectory;

	// Fallback values — updated at runtime from Application meta
	private static var packageName:String = "me.funkin.brenninhoengine";
	private static var fileLocal:String = "BrenninhoEngine";

	/** Tenta atualizar packageName e fileLocal a partir dos metadados do app. **/
	private static function refreshMeta():Void
	{
		try
		{
			var app = lime.app.Application.current;
			if (app != null && app.meta != null)
			{
				var pkg = app.meta.get('packageName');
				var fil = app.meta.get('file');
				if (pkg != null && pkg.length > 0) packageName = pkg;
				if (fil != null && fil.length > 0) fileLocal = fil;
			}
		}
		catch (e:Dynamic) {}
	}

	public static function getStorageDirectory(?force:Bool = false):String
	{
		var daPath:String = '';

		#if android
		refreshMeta();

		// Lê o tipo de armazenamento salvo; cria o arquivo com valor padrão se não existir
		var storageType:String = "EXTERNAL";
		var storageFile:String = rootDir + 'storagetype.txt';
		try
		{
			if (FileSystem.exists(storageFile))
				storageType = File.getContent(storageFile).trim();
			else
				File.saveContent(storageFile, storageType);
		}
		catch (e:Dynamic)
		{
			trace('StorageUtil: could not read/write storagetype.txt — $e');
		}

		daPath = force ? StorageType.fromStrForce(storageType) : StorageType.fromStr(storageType);
		daPath = Path.addTrailingSlash(daPath);

		#elseif ios
		daPath = LimeSystem.documentsDirectory;
		#else
		daPath = Sys.getCwd();
		#end

		return daPath;
	}

	public static function saveContent(fileName:String, fileData:String, ?alert:Bool = true):Void
	{
		try
		{
			if (!FileSystem.exists('saves'))
				FileSystem.createDirectory('saves');

			File.saveContent('saves/$fileName', fileData);

			if (alert)
				showPopUp('$fileName has been saved.', "Success!");
			else
				trace('$fileName has been saved.');
		}
		catch (e:Exception)
		{
			if (alert)
				showPopUp('$fileName couldn\'t be saved.\n(${e.message})', "Error!");
			else
				trace('$fileName couldn\'t be saved. (${e.message})');
		}
	}

	/** Exibe um diálogo (Android) ou imprime no console (outros sys). **/
	private static function showPopUp(message:String, title:String):Void
	{
		#if android
		Tools.showAlertDialog(title, message, {name: "OK", func: null});
		#else
		Sys.println('[$title] $message');
		#end
	}

	#if android
	public static function requestPermissions():Void
	{
		try
		{
			if (VERSION.SDK_INT >= VERSION_CODES.TIRAMISU)
				Permissions.requestPermissions(['READ_MEDIA_IMAGES', 'READ_MEDIA_VIDEO', 'READ_MEDIA_AUDIO']);
			else
				Permissions.requestPermissions(['READ_EXTERNAL_STORAGE', 'WRITE_EXTERNAL_STORAGE']);

			if (!Environment.isExternalStorageManager())
			{
				if (VERSION.SDK_INT >= VERSION_CODES.S)
					Settings.requestSetting('REQUEST_MANAGE_MEDIA');
				Settings.requestSetting('MANAGE_APP_ALL_FILES_ACCESS_PERMISSION');
			}

			var granted = Permissions.getGrantedPermissions();
			var missingPerm:Bool = VERSION.SDK_INT >= VERSION_CODES.TIRAMISU
				? !granted.contains('android.permission.READ_MEDIA_IMAGES')
				: !granted.contains('android.permission.READ_EXTERNAL_STORAGE');

			if (missingPerm)
				showPopUp('If you accepted the permissions you are all good!\nIf you didn\'t then expect a crash\nPress OK to see what happens', 'Notice!');

			var storageDir = StorageUtil.getStorageDirectory();
			try
			{
				if (!FileSystem.exists(storageDir))
					FileSystem.createDirectory(storageDir);
			}
			catch (e:Dynamic)
			{
				showPopUp('Please create directory:\n' + StorageUtil.getStorageDirectory(true) + '\nPress OK to close the game', 'Error!');
				LimeSystem.exit(1);
			}
		}
		catch (e:Dynamic)
		{
			trace('StorageUtil: error requesting permissions — $e');
		}
	}

	/**
	 * Retorna os caminhos de armazenamentos externos montados.
	 * @param splitStorage  Se true, remove o prefixo "/storage/" de cada entrada.
	 */
	public static function checkExternalPaths(?splitStorage:Bool = false):Array<String>
	{
		var paths:Array<String> = [];
		try
		{
			var process = new sys.io.Process('grep', ['-o', '/storage/....\\-....', '/proc/mounts']);
			var output = process.stdout.readAll().toString();
			process.close();

			paths = output.split('\n').filter(function(p) return p.trim() != '');

			if (splitStorage)
				paths = paths.map(function(p) return p.replace('/storage/', ''));
		}
		catch (e:Dynamic)
		{
			trace('StorageUtil: error checking external paths — $e');
		}
		return paths;
	}

	public static function getExternalDirectory(externalDir:String):String
	{
		var daPath:String = '';
		for (path in checkExternalPaths(false))
		{
			if (path.contains(externalDir))
			{
				daPath = path.trim();
				break;
			}
		}
		if (daPath.length > 0)
			daPath = Path.addTrailingSlash(daPath);
		return daPath;
	}
	#end // android
	#end // sys
}

#if android
@:runtimeValue
enum abstract StorageType(String) from String to String
{
	var EXTERNAL_DATA;
	var EXTERNAL_OBB;
	var EXTERNAL_MEDIA;
	var EXTERNAL;

	public static final forcedPath:String = '/storage/emulated/0/';

	// Helpers para obter meta em tempo de execução
	private static function getPkg():String
	{
		try
		{
			var app = lime.app.Application.current;
			if (app != null && app.meta != null)
			{
				var v = app.meta.get('packageName');
				if (v != null && v.length > 0) return v;
			}
		}
		catch (e:Dynamic) {}
		return 'me.funkin.brenninhoengine';
	}

	private static function getFile():String
	{
		try
		{
			var app = lime.app.Application.current;
			if (app != null && app.meta != null)
			{
				var v = app.meta.get('file');
				if (v != null && v.length > 0) return v;
			}
		}
		catch (e:Dynamic) {}
		return 'BrenninhoEngine';
	}

	public static function fromStr(str:String):String
	{
		var pkg  = getPkg();
		var file = getFile();

		try
		{
			return switch (str)
			{
				case "EXTERNAL_DATA":  Context.getExternalFilesDir();
				case "EXTERNAL_OBB":   Context.getObbDir();
				case "EXTERNAL_MEDIA": Environment.getExternalStorageDirectory() + '/Android/media/' + pkg;
				case "EXTERNAL":       Environment.getExternalStorageDirectory() + '/.' + file;
				default:               StorageUtil.getExternalDirectory(str) + '.' + file;
			}
		}
		catch (e:Dynamic)
		{
			trace('StorageType.fromStr: falling back to forced path — $e');
			return fromStrForce(str);
		}
	}

	public static function fromStrForce(str:String):String
	{
		var pkg  = getPkg();
		var file = getFile();

		return switch (str)
		{
			case "EXTERNAL_DATA":  forcedPath + 'Android/data/'  + pkg + '/files';
			case "EXTERNAL_OBB":   forcedPath + 'Android/obb/'   + pkg;
			case "EXTERNAL_MEDIA": forcedPath + 'Android/media/' + pkg;
			case "EXTERNAL":       forcedPath + '.' + file;
			default:               forcedPath + '.' + file;
		}
	}

	public static function getAvailableTypes():Array<String>
		return ["EXTERNAL_DATA", "EXTERNAL_OBB", "EXTERNAL_MEDIA", "EXTERNAL"];
}
#end