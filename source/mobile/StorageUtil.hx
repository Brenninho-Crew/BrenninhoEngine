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
    // root directory, used for handling the saved storage type and path
    public static final rootDir:String = LimeSystem.applicationStorageDirectory;

    // Valores padrão para evitar referências não encontradas
    private static var packageName:String = "me.funkin.brenninhoengine";
    private static var fileLocal:String = "BrenninhoEngine";

    public static function getStorageDirectory(?force:Bool = false):String
    {
        var daPath:String = '';

        #if android
        // Inicializa valores do Lime se disponível
        try {
            if (lime.app.Application.current != null && 
                lime.app.Application.current.meta != null) {
                packageName = lime.app.Application.current.meta.get('packageName');
                fileLocal = lime.app.Application.current.meta.get('file');
            }
        } catch(e:Dynamic) {
            // Usa valores padrão se falhar
        }

        // Verifica se ClientPrefs existe, caso contrário usa valor padrão
        var storageType:String = "EXTERNAL";
        try {
            if (FileSystem.exists(rootDir + 'storagetype.txt')) {
                storageType = File.getContent(rootDir + 'storagetype.txt');
            } else {
                #if (android && !macro)
                // Tenta acessar ClientPrefs se disponível
                if (ClientPrefs != null && ClientPrefs.storageType != null) {
                    storageType = ClientPrefs.storageType;
                }
                #end
                File.saveContent(rootDir + 'storagetype.txt', storageType);
            }
        } catch(e:Dynamic) {
            // Se falhar ao ler/escrever, continua com valor padrão
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

            #if (android && !macro)
            if (alert)
                showPopUp('$fileName has been saved.', "Success!");
            #elseif alert
            trace('$fileName has been saved.');
            #end
        }
        catch (e:Exception)
        {
            #if (android && !macro)
            if (alert)
                showPopUp('$fileName couldn\'t be saved.\n(${e.message})', "Error!");
            else
                trace('$fileName couldn\'t be saved. (${e.message})');
            #else
            trace('$fileName couldn\'t be saved. (${e.message})');
            #end
        }
    }

    // Método auxiliar para mostrar pop-up (evita dependência direta do CoolUtil)
    private static function showPopUp(message:String, title:String):Void
    {
        #if android
        android.Tools.showAlertDialog(title, message, "OK");
        #elseif sys
        Sys.println('$title: $message');
        #end
    }

    #if android
    public static function requestPermissions():Void
    {
        try {
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

            if ((VERSION.SDK_INT >= VERSION_CODES.TIRAMISU
                    && !Permissions.getGrantedPermissions().contains('android.permission.READ_MEDIA_IMAGES'))
                    || (VERSION.SDK_INT < VERSION_CODES.TIRAMISU
                            && !Permissions.getGrantedPermissions().contains('android.permission.READ_EXTERNAL_STORAGE')))
                showPopUp('If you accepted the permissions you are all good!\nIf you didn\'t then expect a crash\nPress OK to see what happens',
                        'Notice!');

            try
            {
                if (!FileSystem.exists(StorageUtil.getStorageDirectory()))
                    FileSystem.createDirectory(StorageUtil.getStorageDirectory());
            }
            catch (e:Dynamic)
            {
                showPopUp('Please create directory to\n' + StorageUtil.getStorageDirectory(true) + '\nPress OK to close the game', 'Error!');
                LimeSystem.exit(1);
            }
        } catch(e:Dynamic) {
            trace('Error requesting permissions: $e');
        }
    }

    public static function checkExternalPaths(?splitStorage = false):Array<String>
    {
        var paths:Array<String> = [];

        #if android
        try {
            var process = new sys.io.Process('grep -o "/storage/....-...." /proc/mounts');
            var output = process.stdout.readAll().toString();
            process.close();

            paths = output.split('\n');

            // Remove strings vazias
            paths = paths.filter(function(p) return p != "");

            if (splitStorage) {
                paths = paths.map(function(p) return p.replace('/storage/', ''));
            }
        } catch(e:Dynamic) {
            trace('Error checking external paths: $e');
        }
        #end

        return paths;
    }

    public static function getExternalDirectory(externalDir:String):String
    {
        var daPath:String = '';

        #if android
        for (path in checkExternalPaths(false))
        {
            if (path.contains(externalDir))
            {
                daPath = path;
                break;
            }
        }

        if (daPath != '') {
            daPath = daPath.endsWith("\n") ? daPath.substr(0, daPath.length - 1) : daPath;
            daPath = Path.addTrailingSlash(daPath);
        }
        #end

        return daPath;
    }
    #end
    #end
}

#if android
@:runtimeValue
enum abstract StorageType(String) from String to String
{
    // Constantes públicas para acesso externo
    public static final forcedPath = '/storage/emulated/0/';
    public static var packageNameLocal = 'me.funkin.brenninhoengine';
    public static var fileLocal = 'BrenninhoEngine';

    var EXTERNAL_DATA;
    var EXTERNAL_OBB;
    var EXTERNAL_MEDIA;
    var EXTERNAL;

    public static function fromStr(str:String):String
    {
        // Atualiza valores do pacote
        try {
            if (lime.app.Application.current != null && 
                lime.app.Application.current.meta != null) {
                packageNameLocal = lime.app.Application.current.meta.get('packageName');
                fileLocal = lime.app.Application.current.meta.get('file');
            }
        } catch(e:Dynamic) {}

        var result:String = '';

        try {
            result = switch (str)
            {
                case "EXTERNAL_DATA": Context.getExternalFilesDir();
                case "EXTERNAL_OBB": Context.getObbDir();
                case "EXTERNAL_MEDIA": Environment.getExternalStorageDirectory() + '/Android/media/' + packageNameLocal;
                case "EXTERNAL": Environment.getExternalStorageDirectory() + '/.' + fileLocal;
                default: StorageUtil.getExternalDirectory(str) + '.' + fileLocal;
            }
        } catch(e:Dynamic) {
            // Fallback para caminhos forçados em caso de erro
            result = fromStrForce(str);
        }

        return result;
    }

    public static function fromStrForce(str:String):String
    {
        final forcedExternalData = forcedPath + 'Android/data/' + packageNameLocal + '/files';
        final forcedExternalObb = forcedPath + 'Android/obb/' + packageNameLocal;
        final forcedExternalMedia = forcedPath + 'Android/media/' + packageNameLocal;
        final forcedExternal = forcedPath + '.' + fileLocal;

        return switch (str)
        {
            case "EXTERNAL_DATA": forcedExternalData;
            case "EXTERNAL_OBB": forcedExternalObb;
            case "EXTERNAL_MEDIA": forcedExternalMedia;
            case "EXTERNAL": forcedExternal;
            default: forcedPath + '.' + fileLocal;
        }
    }

    public static function getAvailableTypes():Array<String>
    {
        return ["EXTERNAL_DATA", "EXTERNAL_OBB", "EXTERNAL_MEDIA", "EXTERNAL"];
    }
}
#end