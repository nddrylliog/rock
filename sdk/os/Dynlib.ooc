
use sdk-dynlib // so we get -ldl on platforms that require it

/**
 * Cross-platform dynamic library loading code.
 *
 * Allows one to load a library from a .so (Linux), .dylib (OSX),
 * or .dll (Windows) file, and retrieve symbol addresses so that they
 * might be called.
 *
 * @author Amos Wenger (nddrylliog)
 */
Dynlib: abstract class {

    suffix: static String = ""
    path: String

    /**
     * Open a dynamic library.
     *
     * @param a path like 'somelib.so', 'somelib.dylib' or 'somelib.dll'.
     * If the platform-specific file extension is missing, it will be added
     * automatically.
     */
    new: static func (path: String) -> This {
        version (windows) {
            return DynlibWin32 new(path)
        }

        version (!windows) {
            return DynlibUnix new(path)
        }

        raise("Dynamic library loading not supported on your system.")
        null
    }

    /**
     * @return the address of the symbol with a given name.
     */
    symbol: abstract func (name: String) -> Pointer

    /**
     * Close this dynamic library and free the associated resources.
     * This must be the last called method on a given instance.
     *
     * If a Dynlib is not closed explicitly, it will be freed when the
     * application exits.
     *
     * @return true if the library was successfully closed, false otherwise.
     */
    close: abstract func -> Bool

}

/* Initialize suffix */
{
    version (windows) {
        Dynlib suffix = ".dll"
    }

    version (!windows) {
        version (apple) {
            Dynlib suffix = ".dylib"
        }
        version (!apple) {
            Dynlib suffix = ".so"
        }
    }
}

/* Errors */

DynlibException: class extends Exception {

    init: func (.origin, .message) {
        super(origin, message)
    }

}

/* Windows implementation */

version (windows) {
    include windows

    HModule: cover from HMODULE
    LoadLibraryA: extern func (path: CString) -> HModule
    GetProcAddress: extern func (module: HModule, name: CString) -> Pointer
    FreeLibrary: extern func (module: HModule) -> Bool

    DynlibWin32: class extends Dynlib {
        handle: HModule

        init: func (=path) {
            handle = LoadLibraryA(path)
            if (!handle) {
                // try adding ".dll" to see if it was a universal path
                handle = LoadLibraryA(path + suffix)
            }

            if (!handle) {
                DynlibException new(This, "Could not load dynamic library %s" \
                    format(path)) throw()
            }
        }

        symbol: func (name: String) -> Pointer {
            addr := GetProcAddress(handle, name)
            if (!addr) {
                DynlibException new(This, "Could not find symbol %s in %s" \
                    format(name, path)) throw()
            }
            addr
        }

        close: func -> Bool {
            FreeLibrary(handle)
        }
    }
}

/* Unix implementation */

version (!windows) {
    include dlfcn

    // flags modes
    RTLD_LAZY, RTLD_NOW, RTLD_GLOBAL, RTLD_LOCAL: extern Int

    dlopen: extern func (path: CString, flag: Int) -> Pointer
    dlsym: extern func (handle: Pointer, name: CString) -> Pointer
    dlclose: extern func (handle: Pointer) -> Int

    /**
     * Dynamic library code for *nix
     */
    DynlibUnix: class extends Dynlib {
        handle: Pointer

        init: func (=path) {
            handle = dlopen(path, RTLD_LAZY)
            if (!handle) {
                // try adding ".so" or ".dylib"
                handle = dlopen(path + suffix, RTLD_LAZY)
            }

            if (!handle) {
                DynlibException new(This, "Could not load dynamic library %s" \
                    format(path)) throw()
            }
        }

        symbol: func (name: String) -> Pointer {
            addr := dlsym(handle, name)
            if (!addr) {
                DynlibException new(This, "Could not find symbol %s in %s" \
                    format(name, path)) throw()
            }
            addr
        }

        close: func -> Bool {
            dlclose(handle) == 0
        }
    }
}

