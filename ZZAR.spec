import sys
import os
import glob

block_cipher = None

# When building for Flatpak, skip bundling GStreamer/Qt system plugins —
# the Flatpak runtime provides them instead.
is_flatpak_build = os.environ.get('ZZAR_FLATPAK_BUILD') == '1'

added_files = [
    ('src/gui/qml', 'gui/qml'),
    ('src/gui/assets', 'gui/assets'),
    ('src/gui/components', 'gui/components'),
    ('src/gui/translations', 'gui/translations'),
    ('src/resources', 'resources'),
    ('setup_wwise.py', '.'),
    ('setup_windows_audio_tools.py', '.'),
]

extra_binaries = []

if sys.platform.startswith('win'):

    extra_binaries = []
    try:
        import PyQt5
        pyqt5_dir = os.path.dirname(PyQt5.__file__)
        qt_qml_dir = os.path.join(pyqt5_dir, 'Qt5', 'qml')
        qt_plugins_dir = os.path.join(pyqt5_dir, 'Qt5', 'plugins')
        qt_bin_dir = os.path.join(pyqt5_dir, 'Qt5', 'bin')

        if os.path.isdir(qt_qml_dir):
            added_files.append((qt_qml_dir, 'PyQt5/Qt5/qml'))
            print(f"INFO: Bundled Qt QML modules from {qt_qml_dir}")
        else:
            print("WARNING: Qt QML directory not found — QML will fail to load")

        # Bundle QtMultimedia plugin DLLs (needed for QML QtMultimedia module)
        for plugin_subdir in ('mediaservice', 'playbackdevices', 'audio'):
            plugin_path = os.path.join(qt_plugins_dir, plugin_subdir)
            if os.path.isdir(plugin_path):
                added_files.append((plugin_path, f'PyQt5/Qt5/plugins/{plugin_subdir}'))
                print(f"INFO: Bundled Qt plugin: {plugin_subdir}")

        # Bundle Qt5Multimedia*.dll from Qt5/bin
        if os.path.isdir(qt_bin_dir):
            for dll in glob.glob(os.path.join(qt_bin_dir, 'Qt5Multimedia*.dll')):
                extra_binaries.append((dll, '.'))
                print(f"INFO: Bundled {os.path.basename(dll)}")

    except ImportError:
        print("WARNING: PyQt5 not found, skipping QML bundling")

else:

    lib_search_paths = [
        '/usr/lib',
        '/usr/lib/x86_64-linux-gnu',
    ]

    if is_flatpak_build:
        print("INFO: Flatpak build — skipping GStreamer/Qt system plugin bundling")
        print("INFO: These will be provided by the Flatpak runtime instead")
    else:
        # Bundle GStreamer plugins for standalone binary
        gst_search_paths = [
            '/usr/lib/gstreamer-1.0',
            '/usr/lib/x86_64-linux-gnu/gstreamer-1.0',
        ]

        gst_plugin_dir = next((p for p in gst_search_paths if os.path.exists(p)), None)

        if gst_plugin_dir:
            print(f"INFO: Found GStreamer plugins at {gst_plugin_dir}")
            extra_binaries.append((gst_plugin_dir, 'gstreamer-1.0/'))

            for lib_dir in lib_search_paths:
                found_libs = glob.glob(os.path.join(lib_dir, 'libgst*.so*'))
                for lib_path in found_libs:
                    extra_binaries.append((lib_path, '.'))
        else:
            print("WARNING: GStreamer path not found. Build might fail to play audio.")

    try:
        import PyQt5
        pyqt5_dir = os.path.dirname(PyQt5.__file__)
        qt_plugins_dir = os.path.join(pyqt5_dir, 'Qt5', 'plugins')
        qt_qml_dir = os.path.join(pyqt5_dir, 'Qt5', 'qml')

        qt_plugin_search = [qt_plugins_dir, '/usr/lib/qt/plugins', '/usr/lib/x86_64-linux-gnu/qt5/plugins']
        qt_qml_search = [qt_qml_dir, '/usr/lib/qt/qml', '/usr/lib/x86_64-linux-gnu/qt5/qml']

        if not is_flatpak_build:
            # Bundle Qt Wayland/platform plugins for standalone binary
            wayland_plugin_dirs = [
                ('platforms', 'PyQt5/Qt5/plugins/platforms/'),
                ('wayland-shell-integration', 'PyQt5/Qt5/plugins/wayland-shell-integration/'),
                ('wayland-graphics-integration-client', 'PyQt5/Qt5/plugins/wayland-graphics-integration-client/'),
                ('wayland-decoration-client', 'PyQt5/Qt5/plugins/wayland-decoration-client/'),
            ]

            for subdir, dest in wayland_plugin_dirs:
                for search_dir in qt_plugin_search:
                    plugin_path = os.path.join(search_dir, subdir)
                    if os.path.isdir(plugin_path):
                        for f in glob.glob(os.path.join(plugin_path, '*.so*')):
                            extra_binaries.append((f, dest))
                        print(f"INFO: Bundled Wayland plugins from {plugin_path}")
                        break

            for search_dir in qt_plugin_search:
                imageformats_path = os.path.join(search_dir, 'imageformats')
                if os.path.isdir(imageformats_path):
                    for f in glob.glob(os.path.join(imageformats_path, '*.so*')):
                        extra_binaries.append((f, 'PyQt5/Qt5/plugins/imageformats/'))
                    print(f"INFO: Bundled imageformats from {imageformats_path}")
                    break
            else:
                print("WARNING: imageformats plugin dir not found")

        # Always bundle QtGraphicalEffects — it must match the bundled PyQt5 version
        for search_dir in qt_qml_search:
            gfx_path = os.path.join(search_dir, 'QtGraphicalEffects')
            if os.path.isdir(gfx_path):
                added_files.append((gfx_path, 'PyQt5/Qt5/qml/QtGraphicalEffects'))
                print(f"INFO: Bundled QtGraphicalEffects from {gfx_path}")
                break
        else:
            print("WARNING: QtGraphicalEffects QML module not found")

        if not is_flatpak_build:
            # NOTE: Do NOT bundle libwayland-*.so - they must come from the user's
            # system to match the compositor and EGL stack. Bundling them from the
            # build machine causes ABI mismatches (e.g. Ubuntu 1.22 vs Arch 1.24)
            # that break EGL initialization and force software rendering.
            for lib_dir in lib_search_paths:
                for lib_path in glob.glob(os.path.join(lib_dir, 'libxkbcommon*.so*')):
                    extra_binaries.append((lib_path, '.'))
    except ImportError:
        print("WARNING: PyQt5 not found, skipping plugin bundling")

a = Analysis(
    ['ZZAR.py'],
    pathex=['.', 'src'],
    binaries=extra_binaries,
    datas=added_files,
    hiddenimports=[
        'gui.main_qml',
        'gui.backend.audio_browser_bridge',
        'gui.backend.audio_conversion_bridge',
        'gui.backend.import_worker',
        'gui.backend.mod_manager_bridge',
        'gui.backend.native_dialogs',
        'gui.backend.gamebanana_bridge',
        'gui.backend.update_manager_bridge',
        'PIL',
        'PIL.Image',
        'PyQt5.QtMultimedia',
        'PyQt5.QtMultimediaWidgets',
        'PyQt5.QtNetwork',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

# On Linux, exclude system libraries that MUST come from the user's system.
# Bundling them from the CI build machine (Ubuntu) causes ABI mismatches on
# other distros:
#   - libwayland-*: version mismatch breaks EGL init, forcing software rendering
#     where QtGraphicalEffects (ColorOverlay, OpacityMask) silently fail
# NOTE: libssl/libcrypto are intentionally NOT excluded here. Qt's network
# module uses dlopen() to load OpenSSL at runtime using the bare filename
# (e.g. "libssl.so.1.1"). If we exclude these from the bundle, Qt cannot find
# them inside the _MEI temp dir and TLS fails ("TLS initialization failed").
# Bundling the CI's OpenSSL 1.x alongside the CI's Qt5Network is correct —
# they were built together. The bundled copies live in the _MEI dir and are
# found before any system OpenSSL via LD_LIBRARY_PATH set by the PyInstaller
# bootloader, so there is no conflict with the user's system OpenSSL 3.x.
if not sys.platform.startswith('win'):
    exclude_prefixes = ('libwayland-',)
    a.binaries = [
        b for b in a.binaries
        if not os.path.basename(b[0]).startswith(exclude_prefixes)
        and not os.path.basename(b[1]).startswith(exclude_prefixes)
    ]

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

icon_file = 'src/gui/assets/ZZAR-Logo2.ico' if sys.platform.startswith('win') else None

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='ZZAR',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,  # TEMP: enable to see QML errors on Windows
    icon=icon_file,
)