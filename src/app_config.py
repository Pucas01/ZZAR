BUILD_TARGET = "SRAR"  

if BUILD_TARGET == "ZZAR":

    APP_NAME            = "ZZAR"
    APP_FULL_NAME       = "Zenless Zone Zero Audio Replacer"
    APP_VERSION         = "1.2.0"

    GAME_NAME           = "Zenless Zone Zero"
    GAME_SHORT          = "ZZZ"
    GAME_DATA_FOLDER    = "ZenlessZoneZero_Data"

    MOD_FILE_EXT        = ".zzar"
    MOD_FILE_EXT_UPPER  = "ZZAR"

    GAMEBANANA_GAME_ID  = 19567

    CONFIG_DIR_NAME     = "ZZAR"

    FLATPAK_ENV_VAR       = "ZZAR_FLATPAK"
    FLATPAK_BUILD_ENV_VAR = "ZZAR_FLATPAK_BUILD"

    GAME_INSTALL_SUBDIRS = [
        "Program Files/HoYoPlay/games/ZenlessZoneZero Game",
        "Program Files (x86)/HoYoPlay/games/ZenlessZoneZero Game",
    ]
    GAME_INSTALL_HOME_SUBDIR = "Games/ZenlessZoneZero Game"

    GAME_DATA_FOLDER_SEARCH = "ZenlessZoneZero_Data"

    ACCENT_COLOR        = "#d8fa00"
    ACCENT_COLOR_LIGHT  = "#e8ff33"
    ACCENT_COLOR_DARK   = "#a8c800"

    ASSETS_DIR = "ZZAR"
    LOGO_PNG   = "ZZAR-Logo2.png"
    LOGO_ICO   = "ZZAR-Logo2.ico"
    LOGO_256   = "ZZAR-Logo2-256.png"

elif BUILD_TARGET == "SRAR":

    APP_NAME            = "SRAR"
    APP_FULL_NAME       = "Honkai Star Rail Audio Replacer"
    APP_VERSION         = "1.2.2"

    GAME_NAME           = "Honkai Star Rail"
    GAME_SHORT          = "HSR"
    GAME_DATA_FOLDER    = "StarRail_Data"

    MOD_FILE_EXT        = ".srar"
    MOD_FILE_EXT_UPPER  = "SRAR"

    GAMEBANANA_GAME_ID  = 18366

    CONFIG_DIR_NAME     = "SRAR"

    FLATPAK_ENV_VAR       = "SRAR_FLATPAK"
    FLATPAK_BUILD_ENV_VAR = "SRAR_FLATPAK_BUILD"

    GAME_INSTALL_SUBDIRS = [
        "Program Files/HoYoPlay/games/Honkai Star Rail Game",
        "Program Files (x86)/HoYoPlay/games/Honkai Star Rail Game",
    ]
    GAME_INSTALL_HOME_SUBDIR = "Games/Honkai Star Rail Game"

    GAME_DATA_FOLDER_SEARCH = "StarRail_Data"

    ACCENT_COLOR        = "#3f9ec3"
    ACCENT_COLOR_LIGHT  = "#62b8d8"
    ACCENT_COLOR_DARK   = "#2d7a99"

    ASSETS_DIR = "SRAR"
    LOGO_PNG   = "SRAR-Logo2.png"
    LOGO_ICO   = "SRAR-Logo2.ico"
    LOGO_256   = "SRAR-Logo2-256.png"

else:
    raise ValueError(f"Unknown BUILD_TARGET: {BUILD_TARGET!r}. Must be 'ZZAR' or 'SRAR'.")

# Derived — always matches APP_NAME
DATA_SUBDIR = APP_NAME
