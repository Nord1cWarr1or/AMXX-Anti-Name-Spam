#include <amxmodx>
#include <reapi>

public stock const PluginName[]        = "Anti Name Spam";
public stock const PluginVersion[]     = "1.2.0";
public stock const PluginAuthor[]      = "Nordic Warrior";
public stock const PluginURL[]          = "";
public stock const PluginDescription[]  = "Sample text";

#define check_bit(%0,%1)    (%0 &   (1 << (%1 - 1)))
#define set_bit(%0,%1)      (%0 |=  (1 << (%1 - 1)))
#define clear_bit(%0,%1)    (%0 &= ~(1 << (%1 - 1)))
#define toggle_bit(%0,%1)   (%0 ^=  (1 << (%1 - 1)))

const ABSOLUTE_MAX_CHANGES = 15;

new Float: change_timestamps[MAX_PLAYERS + 1][ABSOLUTE_MAX_CHANGES];
new current_index[MAX_PLAYERS + 1];

new banned_players_bitsum;
new HookChain: hook_set_username_pre;

new antinamespam_max_allowed_changes,
    antinamespam_ban_time,
    Float: antinamespam_time_window,
    antinamespam_ban_reason[64];

public plugin_init() {
    hook_set_username_pre = RegisterHookChain(RG_CBasePlayer_SetClientUserInfoName, "on_set_username_pre", .post = false);
    DisableHookChain(hook_set_username_pre);

    RegisterHookChain(RG_CBasePlayer_SetClientUserInfoName, "on_set_username_post", .post = true);

    create_cvars();
    AutoExecConfig();
}

public client_putinserver(player) {
    reset_player_data(player);
}

public client_disconnected(player) {
    // Если игрок был помечен как забаненный
    if (check_bit(banned_players_bitsum, player)) {
        clear_bit(banned_players_bitsum, player);
        
        // Если забаненных больше нет - выключаем хук блокировки
        if (banned_players_bitsum == 0) {
            DisableHookChain(hook_set_username_pre);
        }
    }
    
    reset_player_data(player);
}

// Вызывается ТОЛЬКО если есть хотя бы 1 забаненный игрок на сервере
public on_set_username_pre(const player, infobuffer[], new_name[]) {
    if (check_bit(banned_players_bitsum, player)) {
        return HC_SUPERCEDE; // Блокируем смену ника
    }

    return HC_CONTINUE;
}

public on_set_username_post(const player, infobuffer[], new_name[]) {
    // Если игрок уже забанен, не считаем
    if (check_bit(banned_players_bitsum, player)) {
        return;
    }

    new limit = antinamespam_max_allowed_changes;
    new index = current_index[player];

    // Корректировка, если админ уменьшил квар во время игры
    if (index >= limit) {
        index = limit - 1;
        current_index[player] = index;
    }

    new Float: current_time = get_gametime();
    new Float: oldest_time = change_timestamps[player][index];

    if (oldest_time > 0.0 && (current_time - oldest_time) <= antinamespam_time_window) {
        ban_player(player);
        return;
    }

    change_timestamps[player][index] = current_time;
    current_index[player] = (index + 1) % limit;
}

reset_player_data(const player) {
    current_index[player] = 0;
    
    // На всякий случай очищаем бит при входе (защита от ghost-данных)
    clear_bit(banned_players_bitsum, player);

    for (new i = 0; i < ABSOLUTE_MAX_CHANGES; i++) {
        change_timestamps[player][i] = 0.0;
    }
}

ban_player(const player) {
    // Помечаем игрока как забаненного и включаем хук блокировки
    set_bit(banned_players_bitsum, player);
    EnableHookChain(hook_set_username_pre);

    server_cmd("fb_ban %d #%d ^"%s^"", antinamespam_ban_time, get_user_userid(player), antinamespam_ban_reason);

    log_amx("Player <%N> was banned for name spamming.", player);
}

create_cvars() {
    new cvar_pointer;

    cvar_pointer = create_cvar("amx_antinamespam_max_allowed_changes", "5", 
        FCVAR_NONE, "Максимальное количество смены ников", true, 2.0, true, float(ABSOLUTE_MAX_CHANGES));
    bind_pcvar_num(cvar_pointer, antinamespam_max_allowed_changes);

    cvar_pointer = create_cvar("amx_antinamespam_ban_time", "1440", 
        FCVAR_NONE, "Время бана за спам ников (в минутах)", true, 0.0);
    bind_pcvar_num(cvar_pointer, antinamespam_ban_time);

    cvar_pointer = create_cvar("amx_antinamespam_time_window", "60.0", 
        FCVAR_NONE, "Окно времени для проверки спама ников (в секундах)", true, 10.0);
    bind_pcvar_float(cvar_pointer, antinamespam_time_window);

    cvar_pointer = create_cvar("amx_antinamespam_ban_reason", "Name spam", 
        FCVAR_NONE, "Причина бана за спам ников");
    bind_pcvar_string(cvar_pointer, antinamespam_ban_reason, charsmax(antinamespam_ban_reason));
}
