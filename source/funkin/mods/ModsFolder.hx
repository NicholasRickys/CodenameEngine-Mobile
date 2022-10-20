package funkin.mods;

import openfl.utils.Assets;
import openfl.utils.AssetManifest;
import openfl.utils.AssetLibrary;
import flixel.graphics.FlxGraphic;

#if MOD_SUPPORT
import sys.FileSystem;
#end

import flixel.FlxG;
import flixel.FlxState;
import haxe.io.Path;

using StringTools;

class ModsFolder {
    #if MOD_SUPPORT
    /**
     * Last time the folder was modified.
     */
    public static var lastFolderEditTime:Date = null;
    #end

    /**
     * Current mod folder. Will affect `Paths`.
     */
    public static var currentModFolder:String = null;
    /**
     * Array of all loaded mods' folder names.
     */
    public static var loadedMods:Array<String> = [];
    /**
     * Path to the `mods` folder.
     */
    public static var modsPath:String = "./mods/";

    /**
     * Initialises `mods` folder by adding callbacks and such.
     */
    public static function init() {
        FlxG.signals.preStateCreate.add(onStateSwitch);
    }

    /**
     * Loads a mod with the specified name.
     * @param modName Name of the mod
     * @param force Whenever the mod should be reloaded if it has already been loaded
     */
    public static function loadMod(mod:String, force:Bool = false) {
        var e = loadLibraryFromFolder('mods/$mod'.toLowerCase(), '${modsPath}$mod', force);
        loadedMods.push(mod);
        return e;
    }

    public static function loadLibraryFromFolder(libName:String, folder:String, force:Bool = false) {
        if (Assets.hasLibrary(libName)) {
            if (force)
                Assets.unloadLibrary(libName);
            else
                return null;
        }
        
        var assets:AssetManifest = new AssetManifest();
        assets.name = libName;
        assets.libraryType = 'funkin.mods.ModsAssetLibrary';
        assets.version = 2;
        assets.libraryArgs = [];
        assets.rootPath = folder;
        assets.assets = [];

        var lib = AssetLibrary.fromManifest(assets);
        @:privateAccess
        lib.__proxy = new ModsAssetLibrary(assets.rootPath, assets.name);
        Assets.registerLibrary(libName, lib);
        return lib;
    }

    /**
     * Gets all assets in folders and put them in the `assets` array.
     * @param assets Array of assets
     * @param rootPath Root path
     * @param path Path inside of the rootPath (ex: `root path/path/path2/`)
     * @param libraryName Name of the library (ex: `mods/my mod/`)
     * @param prefix Prefix for the asset names (ex: `assets/mods/my mod/`)
     * @param addRoot Whenever the root should be added to the paths. Defaults to false
     */
    public static function getAssetFiles(assets:Array<Dynamic>, rootPath:String, path:String, libraryName:String, prefix:String = "", addRoot:Bool = false) {
        #if sys
        for(f in FileSystem.readDirectory('$rootPath$path')) {
            if (FileSystem.isDirectory('$rootPath$path$f')) {
                // fuck you git
                if (f.toLowerCase() != ".git")
                    getAssetFiles(assets, rootPath, '$path$f/', libraryName);
            } else {
                var type = "BINARY";
                var useExt:Bool = true;
                switch(Path.extension(f).toLowerCase()) {
                    case "txt" | "xml" | "json" | "hx" | "hscript" | "hsc" | "lua" | "frag" | "vert":
                        type = "TEXT";
                    case "png":
                        type = "IMAGE";
                    case "ogg":
                        type = path.toLowerCase().startsWith("music") ? "MUSIC" : "SOUND";
                    case "ttf":
                        type = "FONT";
                        useExt = false;

                }
                var stat = FileSystem.stat('$rootPath$path$f');
                assets.push({
                    type: type,
                    id: ('assets/$libraryName/$prefix$path${useExt ? f : Path.withoutExtension(f)}').toLowerCase(), // for case sensitive shit & correct linux support
                    path: (addRoot ? rootPath : '') + '$path$f',
                    size: stat.size,
                    edited: stat.mtime.getTime() / 1000
                });
            }
        }
        #end
    }

    private static function onStateSwitch(newState:FlxState) {
        Assets.cache.clear();
        lime.utils.Assets.cache.clear();

        #if MOD_SUPPORT
            if (currentModFolder == null) return;
            var bmapsToRemove:Array<FlxGraphic> = [];
            @:privateAccess
            for(bmap in FlxG.bitmap._cache) {
                if (bmap.assetsKey != null) {
                    var e = new LimeLibrarySymbol(bmap.assetsKey);
                    if (e.library is openfl.utils.AssetLibrary) {
                        @:privateAccess
                        e.library = cast(e.library, openfl.utils.AssetLibrary).__proxy;
                    }
                    if (e.library is ModsAssetLibrary) {
                        var lib = cast(e.library, ModsAssetLibrary);
                        if (!lib.__parseAsset(e.symbolName)) continue;
                        if (!lib.__isCacheValid(lib.cachedImages, lib._parsedAsset)) {
                            lib.cachedImages.remove(lib._parsedAsset);
                            bmapsToRemove.push(bmap);
                        }
                    }
                }
            }

            // TODO: add setting for cache clearing
            @:privateAccess
            for(libName=>lib in lime.utils.Assets.libraries) {
                var library = lib;
                if (library is openfl.utils.AssetLibrary) {
                    var flLib = cast(library, openfl.utils.AssetLibrary);
                    @:privateAccess
                    if (flLib.__proxy != null) library = flLib.__proxy;
                }
                if (library is ModsAssetLibrary) {
                    var modLib = cast(library, ModsAssetLibrary);
                    @:privateAccess
                    modLib.cachedBytes = [];
                    @:privateAccess
                    for(sound in modLib.cachedAudioBuffers)
                        sound.dispose();
                    
                }
            }
            for(e in bmapsToRemove)
                FlxG.bitmap.remove(e);
        #end
    }
}