#!/bin/sh

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# 版本号（格式：YY.MM.DD）
readonly SCRIPT_VERSION="v26.04.16"

export TZ=Asia/Shanghai

# 配置项（按需修改）

# 代理核心配置
# 代理运行的用户和用户组
readonly DEFAULT_CORE_USER_GROUP="root:net_admin"
# 代理流量标记
readonly DEFAULT_ROUTING_MARK=""
readonly DEFAULT_FORCE_MARK_BYPASS=0
# 代理端口（透明代理监听端口）
readonly DEFAULT_PROXY_TCP_PORT="1536"
readonly DEFAULT_PROXY_UDP_PORT="1536"

# 代理模式：0=自动（检测TPROXY支持），1=强制TPROXY，2=强制REDIRECT
readonly DEFAULT_PROXY_MODE=0

# 性能模式（0=普通，1=性能优化）
# 启用后可能会开启某些功能（如 conntrack）以提升速度
readonly DEFAULT_PERFORMANCE_MODE=0

# DNS 配置
# DNS 劫持方式（0：禁用，1：tproxy，2：redirect）
readonly DEFAULT_DNS_HIJACK_ENABLE=1
# DNS 监听端口
readonly DEFAULT_DNS_PORT="1053"

# 接口定义
# 移动数据接口
readonly DEFAULT_MOBILE_INTERFACE="rmnet_data+"
# WiFi 接口
readonly DEFAULT_WIFI_INTERFACE="wlan0"
# 热点接口
readonly DEFAULT_HOTSPOT_INTERFACE="wlan2"
# USB 共享网络接口
readonly DEFAULT_USB_INTERFACE="rndis+"

# 其他需要绕过或代理的接口，多个接口用空格分隔
readonly DEFAULT_OTHER_BYPASS_INTERFACES=""
readonly DEFAULT_OTHER_PROXY_INTERFACES=""

# 代理开关
readonly DEFAULT_PROXY_MOBILE=1
readonly DEFAULT_PROXY_WIFI=1
readonly DEFAULT_PROXY_HOTSPOT=0
readonly DEFAULT_PROXY_USB=0
readonly DEFAULT_PROXY_TCP=1
readonly DEFAULT_PROXY_UDP=1

# IPv6 代理控制：
#  0 = 禁用代理（但 IPv6 协议栈保持激活）
#  1 = 启用代理（正常 IPv6 代理）
# -1 = 强制完全禁用 IPv6 协议栈（对所有接口设置 disable_ipv6=1）
readonly DEFAULT_PROXY_IPV6=0

# 使用 100.0.0.0/8 而非 100.64.0.0/10 纯属中国电信运营商的失误，可自行改回
readonly DEFAULT_BYPASS_IPv4_LIST="0.0.0.0/8 10.0.0.0/8 100.0.0.0/8 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 192.168.0.0/16 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4 255.255.255.255/32"
readonly DEFAULT_BYPASS_IPv6_LIST="::/128 ::1/128 ::ffff:0:0/96 100::/64 64:ff9b::/96 2001::/32 2001:10::/28 2001:20::/28 2001:db8::/32 2002::/16 fe80::/10 ff00::/8"
readonly DEFAULT_PROXY_IPv4_LIST=""
readonly DEFAULT_PROXY_IPv6_LIST=""

# WiFi 与热点共用同一接口时的热点子网（旧设备上较常见）
# 仅在 HOTSPOT_INTERFACE == WIFI_INTERFACE 时生效
readonly DEFAULT_HOTSPOT_SUBNET_IPV4="192.168.43.0/24"
readonly DEFAULT_HOTSPOT_SUBNET_IPV6="fe80::/10"

# 标记值
readonly DEFAULT_MARK_VALUE=20
readonly DEFAULT_MARK_VALUE6=25

# 路由表 ID
readonly DEFAULT_TABLE_ID=2025

# 按应用代理（包名之间用空格分隔，支持 用户:包名 格式）
readonly DEFAULT_APP_PROXY_ENABLE=0
readonly DEFAULT_PROXY_APPS_LIST=""
# 示例："com.example.app com.other"
readonly DEFAULT_BYPASS_APPS_LIST=""
# 示例："com.android.shell"
readonly DEFAULT_APP_PROXY_MODE="blacklist"
# "blacklist"（黑名单）或 "whitelist"（白名单）

# 国内 IP 绕过配置
readonly DEFAULT_BYPASS_CN_IP=0
# 国内 IP 列表文件名
readonly DEFAULT_CN_IP_FILE="cn.zone"
readonly DEFAULT_CN_IPV6_FILE="cn_ipv6.zone"
# 国内 IP 来源 URL
readonly DEFAULT_CN_IP_URL="https://raw.githubusercontent.com/Hackl0us/GeoIP2-CN/release/CN-ip-cidr.txt"
readonly DEFAULT_CN_IPV6_URL="https://ispip.clang.cn/all_cn_ipv6.txt"

# MAC 地址黑名单/白名单配置（热点模式）
readonly DEFAULT_MAC_FILTER_ENABLE=0
# MAC 地址黑名单/白名单（多个地址用空格分隔）
readonly DEFAULT_PROXY_MACS_LIST=""
# 示例："AA:BB:CC:DD:EE:FF 11:22:33:44:55:66"
readonly DEFAULT_BYPASS_MACS_LIST=""
# 示例："FF:EE:DD:CC:BB:AA"
readonly DEFAULT_MAC_PROXY_MODE="blacklist"
# "blacklist"（黑名单）或 "whitelist"（白名单）

# 阻断 QUIC
readonly DEFAULT_BLOCK_QUIC=0

# 是否在日志中包含时间戳（0=禁用，1=启用）
# 禁用可避免每条日志 fork 进程，提升性能
readonly DEFAULT_LOG_TIMESTAMP=1

# 模拟运行模式（默认禁用）
readonly DEFAULT_DRY_RUN=0

log() {
    local level="$1"
    local message="$2"
    local color_code

    case "$level" in
        Debug) color_code="\033[0;36m" ;;
        Info) color_code="\033[1;32m" ;;
        Warn) color_code="\033[1;33m" ;;
        Error) color_code="\033[1;31m" ;;
        *)
            level="Unknown"
            color_code="\033[0m"
            ;;
    esac

    local should_print=0

    if [ "$DRY_RUN" -eq 1 ]; then
        if [ "$VERBOSE" -eq 1 ]; then
            should_print=1
        elif [ "$level" = "Debug" ] && case "$message" in "[EXEC] "*) true ;; *) false ;; esac then
            should_print=1
        fi
    else
        if [ "$level" = "Info" ] || [ "$level" = "Warn" ] || [ "$level" = "Error" ]; then
            should_print=1
        elif [ "$VERBOSE" -eq 1 ] && [ "$level" = "Debug" ]; then
            should_print=1
        fi
    fi

    [ "$should_print" -eq 0 ] && return 0

    local timestamp=""
    if [ "$LOG_TIMESTAMP" -eq 1 ]; then
        timestamp="$(date +"%Y-%m-%d %H:%M:%S") "
    fi

    if [ -t 2 ]; then
        printf "%b\n" "${color_code}${timestamp}[${level}]: ${message}\033[0m" >&2
    else
        printf "%s\n" "${timestamp}[${level}]: ${message}" >&2
    fi
}

load_config() {
    if [ -z "$CONFIG_DIR" ]; then
        CONFIG_DIR="$SCRIPT_DIR"
        log Warn "未指定 CONFIG_DIR，回退到脚本所在目录：$CONFIG_DIR"
    fi

    if [ -f "$CONFIG_DIR/tproxy.conf" ]; then
        log Info "正在加载配置文件：$CONFIG_DIR/tproxy.conf"
        . "$CONFIG_DIR/tproxy.conf"
    else
        log Info "在 $CONFIG_DIR 中未找到 tproxy.conf，使用脚本默认值和环境变量"
    fi

    log Info "正在从环境变量或默认值加载配置..."

    DRY_RUN="${DRY_RUN:-$DEFAULT_DRY_RUN}"
    CORE_USER_GROUP="${CORE_USER_GROUP:-$DEFAULT_CORE_USER_GROUP}"
    ROUTING_MARK="${ROUTING_MARK:-$DEFAULT_ROUTING_MARK}"
    FORCE_MARK_BYPASS="${FORCE_MARK_BYPASS:-$DEFAULT_FORCE_MARK_BYPASS}"
    PROXY_TCP_PORT="${PROXY_TCP_PORT:-$DEFAULT_PROXY_TCP_PORT}"
    PROXY_UDP_PORT="${PROXY_UDP_PORT:-$DEFAULT_PROXY_UDP_PORT}"
    PROXY_MODE="${PROXY_MODE:-$DEFAULT_PROXY_MODE}"
    PERFORMANCE_MODE="${PERFORMANCE_MODE:-$DEFAULT_PERFORMANCE_MODE}"
    DNS_HIJACK_ENABLE="${DNS_HIJACK_ENABLE:-$DEFAULT_DNS_HIJACK_ENABLE}"
    DNS_PORT="${DNS_PORT:-$DEFAULT_DNS_PORT}"
    MOBILE_INTERFACE="${MOBILE_INTERFACE:-$DEFAULT_MOBILE_INTERFACE}"
    WIFI_INTERFACE="${WIFI_INTERFACE:-$DEFAULT_WIFI_INTERFACE}"
    HOTSPOT_INTERFACE="${HOTSPOT_INTERFACE:-$DEFAULT_HOTSPOT_INTERFACE}"
    USB_INTERFACE="${USB_INTERFACE:-$DEFAULT_USB_INTERFACE}"
    OTHER_BYPASS_INTERFACES="${OTHER_BYPASS_INTERFACES:-$DEFAULT_OTHER_BYPASS_INTERFACES}"
    OTHER_PROXY_INTERFACES="${OTHER_PROXY_INTERFACES:-$DEFAULT_OTHER_PROXY_INTERFACES}"
    PROXY_MOBILE="${PROXY_MOBILE:-$DEFAULT_PROXY_MOBILE}"
    PROXY_WIFI="${PROXY_WIFI:-$DEFAULT_PROXY_WIFI}"
    PROXY_HOTSPOT="${PROXY_HOTSPOT:-$DEFAULT_PROXY_HOTSPOT}"
    PROXY_USB="${PROXY_USB:-$DEFAULT_PROXY_USB}"
    PROXY_TCP="${PROXY_TCP:-$DEFAULT_PROXY_TCP}"
    PROXY_UDP="${PROXY_UDP:-$DEFAULT_PROXY_UDP}"
    PROXY_IPV6="${PROXY_IPV6:-$DEFAULT_PROXY_IPV6}"
    MARK_VALUE="${MARK_VALUE:-$DEFAULT_MARK_VALUE}"
    MARK_VALUE6="${MARK_VALUE6:-$DEFAULT_MARK_VALUE6}"
    TABLE_ID="${TABLE_ID:-$DEFAULT_TABLE_ID}"
    PROXY_IPv4_LIST="${PROXY_IPv4_LIST:-$DEFAULT_PROXY_IPv4_LIST}"
    PROXY_IPv6_LIST="${PROXY_IPv6_LIST:-$DEFAULT_PROXY_IPv6_LIST}"
    BYPASS_IPv4_LIST="${BYPASS_IPv4_LIST:-$DEFAULT_BYPASS_IPv4_LIST}"
    BYPASS_IPv6_LIST="${BYPASS_IPv6_LIST:-$DEFAULT_BYPASS_IPv6_LIST}"
    HOTSPOT_SUBNET_IPV4="${HOTSPOT_SUBNET_IPV4:-$DEFAULT_HOTSPOT_SUBNET_IPV4}"
    HOTSPOT_SUBNET_IPV6="${HOTSPOT_SUBNET_IPV6:-$DEFAULT_HOTSPOT_SUBNET_IPV6}"
    APP_PROXY_ENABLE="${APP_PROXY_ENABLE:-$DEFAULT_APP_PROXY_ENABLE}"
    PROXY_APPS_LIST="${PROXY_APPS_LIST:-$DEFAULT_PROXY_APPS_LIST}"
    BYPASS_APPS_LIST="${BYPASS_APPS_LIST:-$DEFAULT_BYPASS_APPS_LIST}"
    APP_PROXY_MODE="${APP_PROXY_MODE:-$DEFAULT_APP_PROXY_MODE}"
    BYPASS_CN_IP="${BYPASS_CN_IP:-$DEFAULT_BYPASS_CN_IP}"
    CN_IP_FILE="${CN_IP_FILE:-$DEFAULT_CN_IP_FILE}"
    CN_IPV6_FILE="${CN_IPV6_FILE:-$DEFAULT_CN_IPV6_FILE}"
    CN_IP_URL="${CN_IP_URL:-$DEFAULT_CN_IP_URL}"
    CN_IPV6_URL="${CN_IPV6_URL:-$DEFAULT_CN_IPV6_URL}"
    MAC_FILTER_ENABLE="${MAC_FILTER_ENABLE:-$DEFAULT_MAC_FILTER_ENABLE}"
    PROXY_MACS_LIST="${PROXY_MACS_LIST:-$DEFAULT_PROXY_MACS_LIST}"
    BYPASS_MACS_LIST="${BYPASS_MACS_LIST:-$DEFAULT_BYPASS_MACS_LIST}"
    MAC_PROXY_MODE="${MAC_PROXY_MODE:-$DEFAULT_MAC_PROXY_MODE}"
    BLOCK_QUIC="${BLOCK_QUIC:-$DEFAULT_BLOCK_QUIC}"
    LOG_TIMESTAMP="${LOG_TIMESTAMP:-$DEFAULT_LOG_TIMESTAMP}"
    SKIP_CHECK_FEATURE="${SKIP_CHECK_FEATURE:-0}"

    if [ "$VERBOSE" -eq 1 ]; then
        for _var in DRY_RUN CORE_USER_GROUP ROUTING_MARK FORCE_MARK_BYPASS \
            PROXY_TCP_PORT PROXY_UDP_PORT PROXY_MODE PERFORMANCE_MODE \
            DNS_HIJACK_ENABLE DNS_PORT \
            MOBILE_INTERFACE WIFI_INTERFACE HOTSPOT_INTERFACE USB_INTERFACE \
            OTHER_BYPASS_INTERFACES OTHER_PROXY_INTERFACES \
            PROXY_MOBILE PROXY_WIFI PROXY_HOTSPOT PROXY_USB \
            PROXY_TCP PROXY_UDP PROXY_IPV6 \
            MARK_VALUE MARK_VALUE6 TABLE_ID \
            PROXY_IPv4_LIST PROXY_IPv6_LIST BYPASS_IPv4_LIST BYPASS_IPv6_LIST \
            HOTSPOT_SUBNET_IPV4 HOTSPOT_SUBNET_IPV6 \
            APP_PROXY_ENABLE PROXY_APPS_LIST BYPASS_APPS_LIST APP_PROXY_MODE \
            BYPASS_CN_IP CN_IP_FILE CN_IPV6_FILE CN_IP_URL CN_IPV6_URL \
            MAC_FILTER_ENABLE PROXY_MACS_LIST BYPASS_MACS_LIST MAC_PROXY_MODE \
            BLOCK_QUIC LOG_TIMESTAMP SKIP_CHECK_FEATURE; do
            eval "log Debug \"$_var: \$$_var\""
        done
    fi

    log Info "配置加载完成"
}

save_runtime_config() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "跳过保存运行时配置"
        return 0
    fi

    local runtime_file="$CONFIG_DIR/runtime_tproxy.conf"
    log Info "正在保存运行时配置到 $runtime_file"

    {
        echo "# 运行时配置（仅用于停止/清理，自动生成于 $(date))"
        echo "CONFIG_DIR=$CONFIG_DIR"
        echo "CORE_USER_GROUP=$CORE_USER_GROUP"
        echo "PROXY_TCP=$PROXY_TCP"
        echo "PROXY_UDP=$PROXY_UDP"
        echo "PROXY_IPV6=$PROXY_IPV6"
        echo "PROXY_MODE=$PROXY_MODE"
        echo "OTHER_PROXY_INTERFACES=$OTHER_PROXY_INTERFACES"
        echo "BYPASS_CN_IP=$BYPASS_CN_IP"
        echo "BLOCK_QUIC=$BLOCK_QUIC"
        echo "DNS_HIJACK_ENABLE=$DNS_HIJACK_ENABLE"
        echo "TABLE_ID=$TABLE_ID"
        echo "MARK_VALUE=$MARK_VALUE"
        echo "MARK_VALUE6=$MARK_VALUE6"
        echo "USE_TPROXY=$USE_TPROXY"
    } > "$runtime_file" || {
        log Warn "保存运行时配置到 $runtime_file 失败"
    }
}

load_runtime_config() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "跳过加载运行时配置"
        return 0
    fi

    local runtime_file="$CONFIG_DIR/runtime_tproxy.conf"
    if [ -f "$runtime_file" ]; then
        log Info "正在从 $runtime_file 加载运行时配置以进行清理"
        . "$runtime_file" || {
            log Warn "从 $runtime_file 加载运行时配置失败，使用当前配置"
            return 1
        }
    else
        log Warn "未找到运行时配置文件 $runtime_file，使用当前配置进行清理"
        return 1
    fi
}

init_tmpdir() {
    for d in /tmp /data/local/tmp "$CONFIG_DIR/tmp"; do
        if [ -d "$d" ] && [ -w "$d" ]; then
            export TMPDIR="$d"
            log Debug "使用临时目录：$TMPDIR"
            return 0
        fi
    done

    if mkdir -p "$CONFIG_DIR/tmp" 2> /dev/null && [ -w "$CONFIG_DIR/tmp" ]; then
        export TMPDIR="$CONFIG_DIR/tmp"
        log Debug "已创建备用临时目录：$TMPDIR"
        return 0
    else
        log Error "未找到可写的临时目录，且创建失败"
        exit 1
    fi
}

init_kernel_config_cache() {
    [ "$DRY_RUN" -eq 1 ] && return 0
    [ "$SKIP_CHECK_FEATURE" = "1" ] && return 0

    if [ -f /proc/config.gz ]; then
        if zcat /proc/config.gz > "$TMPDIR/kernel_config.cache" 2> /dev/null; then
            log Debug "内核配置已缓存到 $TMPDIR/kernel_config.cache"
        else
            log Warn "缓存 /proc/config.gz 失败"
            rm -f "$TMPDIR/kernel_config.cache" 2> /dev/null
        fi
    fi
}

# 辅助函数：检查值是否为正整数（不 fork 进程）
is_positive_integer() {
    case "$1" in
        '' | *[!0-9]*) return 1 ;;
    esac
    return 0
}

validate_config() {
    log Debug "正在验证配置..."

    if ! is_positive_integer "$PROXY_TCP_PORT" || [ "$PROXY_TCP_PORT" -lt 1 ] || [ "$PROXY_TCP_PORT" -gt 65535 ]; then
        log Error "无效的 PROXY_TCP_PORT：$PROXY_TCP_PORT"
        return 1
    fi

    if ! is_positive_integer "$PROXY_UDP_PORT" || [ "$PROXY_UDP_PORT" -lt 1 ] || [ "$PROXY_UDP_PORT" -gt 65535 ]; then
        log Error "无效的 PROXY_UDP_PORT：$PROXY_UDP_PORT"
        return 1
    fi

    case "$PROXY_MODE" in
        0 | 1 | 2) ;;
        *)
            log Error "无效的 PROXY_MODE：$PROXY_MODE（必须为 0=自动，1=强制TPROXY，2=强制REDIRECT）"
            return 1
            ;;
    esac

    case "$DNS_HIJACK_ENABLE" in
        0 | 1 | 2) ;;
        *)
            log Error "无效的 DNS_HIJACK_ENABLE：$DNS_HIJACK_ENABLE（必须为 0=禁用，1=tproxy，2=redirect）"
            return 1
            ;;
    esac

    if ! is_positive_integer "$DNS_PORT" || [ "$DNS_PORT" -lt 1 ] || [ "$DNS_PORT" -gt 65535 ]; then
        log Error "无效的 DNS_PORT：$DNS_PORT"
        return 1
    fi

    if ! is_positive_integer "$MARK_VALUE" || [ "$MARK_VALUE" -lt 1 ] || [ "$MARK_VALUE" -gt 2147483647 ]; then
        log Error "无效的 MARK_VALUE：$MARK_VALUE"
        return 1
    fi

    if ! is_positive_integer "$MARK_VALUE6" || [ "$MARK_VALUE6" -lt 1 ] || [ "$MARK_VALUE6" -gt 2147483647 ]; then
        log Error "无效的 MARK_VALUE6：$MARK_VALUE6"
        return 1
    fi

    if ! is_positive_integer "$TABLE_ID" || [ "$TABLE_ID" -lt 1 ] || [ "$TABLE_ID" -gt 65535 ]; then
        log Error "无效的 TABLE_ID：$TABLE_ID"
        return 1
    fi

    case "$CORE_USER_GROUP" in
        *:*)
            CORE_USER="${CORE_USER_GROUP%%:*}"
            CORE_GROUP="${CORE_USER_GROUP#*:}"
            log Debug "已解析 user:group 为 '$CORE_USER:$CORE_GROUP'"
            ;;
    esac

    if [ -z "$CORE_USER" ] || [ -z "$CORE_GROUP" ]; then
        log Warn "检测到空用户或空用户组，使用默认值 'root:net_admin'"
        CORE_USER="root"
        CORE_GROUP="net_admin"
    fi

    case "$APP_PROXY_MODE" in
        blacklist | whitelist) ;;
        *)
            log Error "无效的 APP_PROXY_MODE：$APP_PROXY_MODE"
            return 1
            ;;
    esac

    case "$MAC_PROXY_MODE" in
        blacklist | whitelist) ;;
        *)
            log Error "无效的 MAC_PROXY_MODE：$MAC_PROXY_MODE"
            return 1
            ;;
    esac

    log Debug "配置验证通过"
    return 0
}

check_root() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "跳过 root 权限检查"
        return 0
    fi
    if [ "$(id -u 2> /dev/null || echo 1)" != "0" ]; then
        log Error "必须以 root 权限运行"
        exit 1
    fi
}

check_dependencies() {
    export PATH="$PATH:/data/data/com.termux/files/usr/bin"

    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "跳过依赖检查"
        return 0
    fi

    local missing=""
    local required_commands="ip iptables"
    local cmd

    for cmd in $required_commands; do
        if ! command -v "$cmd" > /dev/null 2>&1; then
            missing="$missing $cmd"
        fi
    done

    if [ -n "$missing" ]; then
        log Error "缺少必要命令：$missing"
        log Error "请检查 PATH：$PATH"
        exit 1
    fi
}

setup_busybox() {
    if command -v busybox > /dev/null 2>&1; then
        log Debug "BusyBox 已在 PATH 中找到：$(command -v busybox)"
        return 0
    fi

    log Debug "PATH 中未找到 BusyBox，开始检测..."

    local bb_paths="
        /data/adb/ksu/bin/busybox
        /data/adb/ap/bin/busybox
        /data/adb/magisk/busybox
    "

    local found_bb=""
    for bb in $bb_paths; do
        if [ -f "$bb" ] && [ -x "$bb" ]; then
            found_bb="$bb"
            break
        fi
    done

    if [ -n "$found_bb" ]; then
        local bb_dir=$(dirname "$found_bb")
        export PATH="$PATH:$bb_dir"
        log Info "已检测到 BusyBox 并加入 PATH：$found_bb"
    else
        log Warn "在常用 root 路径中未找到 BusyBox"
    fi
}

check_kernel_feature() {
    local feature="$1"
    local config_name="CONFIG_${feature}"

    # 检查编译时配置（/proc/config.gz）
    if [ -f "$TMPDIR/kernel_config.cache" ]; then
        if grep -qE "^${config_name}=[ym]$" "$TMPDIR/kernel_config.cache" 2> /dev/null; then
            log Debug "内核功能 $feature 已启用（配置文件）"
            return 0
        fi
    fi

    # 检查运行时已加载模块（/sys/module/）
    local module_name=""
    case "$feature" in
        IP_SET)                       module_name="ip_set" ;;
        NETFILTER_XT_SET)             module_name="xt_set" ;;
        NETFILTER_XT_MATCH_ADDRTYPE)  module_name="xt_addrtype" ;;
        NETFILTER_XT_TARGET_TPROXY)   module_name="xt_TPROXY" ;;
    esac
    if [ -n "$module_name" ] && [ -d "/sys/module/$module_name" ]; then
        log Debug "内核功能 $feature 已启用（已加载模块）"
        return 0
    fi

    log Warn "内核功能 $feature 已禁用或未找到"
    return 1
}

init_feature_flags() {
    if [ "$SKIP_CHECK_FEATURE" = "1" ] || [ "$DRY_RUN" -eq 1 ]; then
        log Warn "已跳过内核功能检测"
        HAS_TPROXY=1
        HAS_CONNTRACK=1
        HAS_OWNER=1
        HAS_MARK_MT=1
        HAS_MARK_TG=1
        HAS_SOCKET=1
        HAS_ADDRTYPE=1
        HAS_MAC=1
        HAS_IPSET=1
        HAS_XT_SET=1
        HAS_NAT6=1
        HAS_REDIRECT6=1
        return 0
    fi

    log Info "正在检测内核功能..."
    check_kernel_feature "NETFILTER_XT_TARGET_TPROXY" && HAS_TPROXY=1
    check_kernel_feature "NETFILTER_XT_MATCH_CONNTRACK" && HAS_CONNTRACK=1
    check_kernel_feature "NETFILTER_XT_MATCH_OWNER" && HAS_OWNER=1
    check_kernel_feature "NETFILTER_XT_MATCH_MARK" && HAS_MARK_MT=1
    check_kernel_feature "NETFILTER_XT_TARGET_MARK" && HAS_MARK_TG=1
    check_kernel_feature "NETFILTER_XT_MATCH_SOCKET" && HAS_SOCKET=1
    check_kernel_feature "NETFILTER_XT_MATCH_ADDRTYPE" && HAS_ADDRTYPE=1
    check_kernel_feature "NETFILTER_XT_MATCH_MAC" && HAS_MAC=1
    check_kernel_feature "IP_SET" && HAS_IPSET=1
    check_kernel_feature "NETFILTER_XT_SET" && HAS_XT_SET=1
    check_kernel_feature "IP6_NF_NAT" && HAS_NAT6=1
    check_kernel_feature "IP6_NF_TARGET_REDIRECT" && HAS_REDIRECT6=1
}

check_tproxy_support() {
    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "已跳过 TPROXY 支持检测"
        return 0
    fi

    if [ "$HAS_TPROXY" -eq 1 ]; then
        log Info "内核 TPROXY 支持已确认"
        return 0
    else
        log Warn "内核不支持 TPROXY"
        return 1
    fi
}

# 统一命令封装函数
run_ipt_command() {
    local cmd="$1"
    shift

    log Debug "[EXEC] $cmd -w 100 $*"

    [ "$DRY_RUN" -eq 1 ] && return 0

    command "$cmd" -w 100 "$@"
}

iptables() {
    run_ipt_command iptables "$@"
}

ip6tables() {
    run_ipt_command ip6tables "$@"
}

ip_rule() {
    log Debug "[EXEC] ip rule $*"
    [ "$DRY_RUN" -eq 1 ] && return 0
    command ip rule "$@"
}

ip6_rule() {
    log Debug "[EXEC] ip -6 rule $*"
    [ "$DRY_RUN" -eq 1 ] && return 0
    command ip -6 rule "$@"
}

ip_route() {
    log Debug "[EXEC] ip route $*"
    [ "$DRY_RUN" -eq 1 ] && return 0
    command ip route "$@"
}

ip6_route() {
    log Debug "[EXEC] ip -6 route $*"
    [ "$DRY_RUN" -eq 1 ] && return 0
    command ip -6 route "$@"
}

find_packages_uid() {
    [ $# -eq 0 ] && return 0

    awk -v tokens="$*" '
    BEGIN {
        n = split(tokens, t_arr, " ")
        for (i = 1; i <= n; i++) {
            t = t_arr[i]
            if (t ~ /:/) {
                split(t, parts, ":")
                pfx = parts[1]; pkg = parts[2]
            } else {
                pfx = 0; pkg = t
            }
            # 记录我们需要的包及其前缀
            wanted[pkg] = 1
            # 同一个包可能有多个前缀
            pfxs[pkg] = (pkg in pfxs) ? pfxs[pkg] " " pfx : pfx
        }
    }
    ($1 in wanted) {
        base_uid = ""
        if ($2 ~ /^[0-9]+$/) base_uid = $2
        else if ($(NF-1) ~ /^[0-9]+$/) base_uid = $(NF-1)
        
        if (base_uid != "") {
            m = split(pfxs[$1], p_arr, " ")
            for (j = 1; j <= m; j++) {
                # 以包名和前缀为键存储结果，以便后续按顺序输出
                res[$1, p_arr[j]] = (p_arr[j] * 100000 + base_uid)
            }
        }
    }
    END {
        final_out = ""
        for (i = 1; i <= n; i++) {
            t = t_arr[i]
            if (t ~ /:/) {
                split(t, parts, ":")
                pfx = parts[1]; pkg = parts[2]
            } else {
                pfx = 0; pkg = t
            }
            
            if ((pkg, pfx) in res) {
                final_out = (final_out == "") ? res[pkg, pfx] : final_out " " res[pkg, pfx]
            }
        }
        print final_out
    }
    ' /data/system/packages.list
}

safe_chain_create() {
    local family="$1"
    local table="$2"
    local chain="$3"
    local cmd="iptables"

    [ "$family" = "6" ] && cmd="ip6tables"

    $cmd -t "$table" -N "$chain" 2> /dev/null || true
    $cmd -t "$table" -F "$chain"
}

download_file() {
    local url="$1"
    local output="$2"

    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "[EXEC] download $url -> $output（已跳过，模拟运行模式）"
        return 0
    fi

    if command -v curl > /dev/null 2>&1; then
        log Debug "[EXEC] curl -fsSL --connect-timeout 10 --retry 3 $url -o $output"
        curl -fsSL --connect-timeout 10 --retry 3 "$url" -o "$output"
    else
        log Debug "[EXEC] busybox wget -q -T 10 -t 3 -O $output $url"
        busybox wget -q -T 10 -t 3 -O "$output" "$url"
    fi
}

download_cn_ip_list() {
    if [ "$BYPASS_CN_IP" -eq 0 ]; then
        log Debug "已禁用国内 IP 绕过，跳过下载"
        return 0
    fi

    log Info "正在检查/下载中国大陆 IP 列表到 $CONFIG_DIR/$CN_IP_FILE"

    # 文件不存在或超过 7 天则重新下载
    if [ ! -f "$CONFIG_DIR/$CN_IP_FILE" ] || [ "$(find "$CONFIG_DIR/$CN_IP_FILE" -mtime +7 2> /dev/null)" ]; then
        log Info "正在从 $CN_IP_URL 获取最新中国 IP 列表"

        if ! download_file "$CN_IP_URL" "$CONFIG_DIR/$CN_IP_FILE.tmp"; then
            log Error "下载中国 IP 列表失败"
            log Debug "[EXEC] rm -f $CONFIG_DIR/$CN_IP_FILE.tmp"
            rm -f "$CONFIG_DIR/$CN_IP_FILE.tmp"
            return 1
        fi

        log Debug "[EXEC] mv $CONFIG_DIR/$CN_IP_FILE.tmp $CONFIG_DIR/$CN_IP_FILE"
        if [ "$DRY_RUN" -eq 0 ]; then
            mv "$CONFIG_DIR/$CN_IP_FILE.tmp" "$CONFIG_DIR/$CN_IP_FILE"
        fi
        log Info "中国 IP 列表已保存到 $CONFIG_DIR/$CN_IP_FILE"
    else
        log Debug "使用已有的中国 IP 列表：$CONFIG_DIR/$CN_IP_FILE"
    fi

    if [ "$PROXY_IPV6" -eq 1 ]; then
        log Info "正在检查/下载中国大陆 IPv6 列表到 $CONFIG_DIR/$CN_IPV6_FILE"

        if [ ! -f "$CONFIG_DIR/$CN_IPV6_FILE" ] || [ "$(find "$CONFIG_DIR/$CN_IPV6_FILE" -mtime +7 2> /dev/null)" ]; then
            log Info "正在从 $CN_IPV6_URL 获取最新中国 IPv6 列表"

            if ! download_file "$CN_IPV6_URL" "$CONFIG_DIR/$CN_IPV6_FILE.tmp"; then
                log Error "下载中国 IPv6 列表失败"
                log Debug "[EXEC] rm -f $CONFIG_DIR/$CN_IPV6_FILE.tmp"
                rm -f "$CONFIG_DIR/$CN_IPV6_FILE.tmp"
                return 1
            fi

            log Debug "[EXEC] mv $CONFIG_DIR/$CN_IPV6_FILE.tmp $CONFIG_DIR/$CN_IPV6_FILE"
            if [ "$DRY_RUN" -eq 0 ]; then
                mv "$CONFIG_DIR/$CN_IPV6_FILE.tmp" "$CONFIG_DIR/$CN_IPV6_FILE"
            fi
            log Info "中国 IPv6 列表已保存到 $CONFIG_DIR/$CN_IPV6_FILE"
        else
            log Debug "使用已有的中国 IPv6 列表：$CONFIG_DIR/$CN_IPV6_FILE"
        fi
    fi
}

setup_cn_ipset() {
    if [ "$BYPASS_CN_IP" -eq 0 ]; then
        log Debug "已禁用国内 IP 绕过，跳过 ipset 设置"
        return 0
    fi

    if ! command -v ipset > /dev/null 2>&1; then
        log Error "未找到 ipset 命令，无法绕过国内 IP"
        return 1
    fi

    log Info "正在为中国大陆 IP 设置 ipset"

    log Debug "[EXEC] ipset destroy cnip"
    log Debug "[EXEC] ipset destroy cnip6"
    if [ "$DRY_RUN" -eq 0 ]; then
        ipset destroy cnip 2> /dev/null || true
        ipset destroy cnip6 2> /dev/null || true
    fi

    local ipv4_count
    local ipv6_count

    if [ -f "$CONFIG_DIR/$CN_IP_FILE" ]; then
        log Debug "正在从 $CONFIG_DIR/$CN_IP_FILE 加载 IPv4 CIDR"

        ipv4_count=$(wc -l < "$CONFIG_DIR/$CN_IP_FILE" 2> /dev/null || echo "0")

        log Debug "[EXEC] ipset create cnip hash:net family inet hashsize 8192 maxelem 65536"
        log Debug "[EXEC] Generating temporary ipset restore file with $ipv4_count entries（生成含 $ipv4_count 条记录的临时 ipset 恢复文件）"

        if [ "$DRY_RUN" -eq 0 ]; then
            temp_file=$(mktemp) || {
                log Error "创建 ipset 恢复临时文件失败"
                return 1
            }
            {
                echo "create cnip hash:net family inet hashsize 8192 maxelem 65536"
                awk '!/^[[:space:]]*#/ && NF > 0 {printf "add cnip %s\n", $0}' "$CONFIG_DIR/$CN_IP_FILE"
            } > "$temp_file" || {
                log Error "写入临时文件失败：$temp_file"
                rm -f "$temp_file"
                return 1
            }
        else
            log Debug "[EXEC] Would create temporary file and add $ipv4_count entries to cnip（将创建临时文件并添加 $ipv4_count 条记录到 cnip）"
        fi

        log Debug "[EXEC] ipset restore -f \"$temp_file\""

        if [ "$DRY_RUN" -eq 0 ]; then
            if ipset restore -f "$temp_file" 2> /dev/null; then
                log Info "已成功将 $ipv4_count 条 IPv4 CIDR 记录加载到 ipset 'cnip'"
            else
                log Error "创建 ipset 'cnip' 或加载 IPv4 CIDR 记录失败"
                rm -f "$temp_file" 2> /dev/null
                return 1
            fi
            log Debug "[EXEC] rm -f $temp_file"
            rm -f "$temp_file"
        else
            log Debug "[EXEC] Would load $ipv4_count IPv4 CIDR entries via ipset restore（将通过 ipset restore 加载 $ipv4_count 条 IPv4 CIDR 记录）"
        fi

    else
        log Error "未找到国内 IP 文件：$CONFIG_DIR/$CN_IP_FILE"
        return 1
    fi
    log Info "ipset 'cnip' 已加载中国大陆 IP"

    if [ "$PROXY_IPV6" -eq 1 ]; then
        if [ -f "$CONFIG_DIR/$CN_IPV6_FILE" ]; then
            log Debug "正在从 $CONFIG_DIR/$CN_IPV6_FILE 加载 IPv6 CIDR"

            ipv6_count=$(wc -l < "$CONFIG_DIR/$CN_IPV6_FILE" 2> /dev/null || echo "0")

            log Debug "[EXEC] ipset create cnip6 hash:net family inet6 hashsize 8192 maxelem 65536"
            log Debug "[EXEC] Generating temporary ipset restore file with $ipv6_count entries（生成含 $ipv6_count 条记录的临时 ipset 恢复文件）"

            if [ "$DRY_RUN" -eq 0 ]; then
                temp_file6=$(mktemp) || {
                    log Error "创建 ipset 恢复临时文件失败"
                    return 1
                }
                {
                    echo "create cnip6 hash:net family inet6 hashsize 8192 maxelem 65536"
                    awk '!/^[[:space:]]*#/ && NF > 0 {printf "add cnip6 %s\n", $0}' "$CONFIG_DIR/$CN_IPV6_FILE"
                } > "$temp_file6" || {
                    log Error "写入临时文件失败：$temp_file6"
                    rm -f "$temp_file6"
                    return 1
                }
            else
                log Debug "[EXEC] Would create temporary file and add $ipv6_count entries to cnip6（将创建临时文件并添加 $ipv6_count 条记录到 cnip6）"
            fi

            log Debug "[EXEC] ipset restore -f \"$temp_file6\""

            if [ "$DRY_RUN" -eq 0 ]; then
                if ipset restore -f "$temp_file6" 2> /dev/null; then
                    log Info "已成功将 $ipv6_count 条 IPv6 CIDR 记录加载到 ipset 'cnip6'"
                else
                    log Error "创建 ipset 'cnip6' 或加载 IPv6 CIDR 记录失败"
                    rm -f "$temp_file6" 2> /dev/null
                    return 1
                fi
                log Debug "[EXEC] rm -f $temp_file6"
                rm -f "$temp_file6"
            else
                log Debug "[EXEC] Would load $ipv6_count IPv6 CIDR entries via ipset restore（将通过 ipset restore 加载 $ipv6_count 条 IPv6 CIDR 记录）"
            fi

        else
            log Error "未找到国内 IPv6 文件：$CONFIG_DIR/$CN_IPV6_FILE"
            return 1
        fi

        log Info "ipset 'cnip6' 已加载中国大陆 IPv6 地址"
    fi
}

# 辅助函数：添加子链跳转规则，可选的性能模式 conntrack 优化
# 使用调用函数的动态作用域中的 $cmd 和 $table
_add_chain_jumps() {
    local parent="$1" perf="$2"
    shift 2
    local target
    for target in "$@"; do
        if [ "$perf" -eq 1 ]; then
            $cmd -t "$table" -A "$parent" -p tcp --syn -j "$target"
            $cmd -t "$table" -A "$parent" -p udp -m conntrack --ctstate NEW,RELATED -j "$target"
        else
            $cmd -t "$table" -A "$parent" -j "$target"
        fi
    done
}

setup_proxy_chain() {
    local family="$1"
    local mode="$2" # tproxy or redirect
    local suffix=""
    local mark="$MARK_VALUE"
    local cmd="iptables"

    if [ "$family" = "6" ]; then
        suffix="6"
        mark="$MARK_VALUE6"
        cmd="ip6tables"
    fi

    # 设置模式名称（用于日志输出）
    local mode_name="$mode"
    if [ "$mode" = "tproxy" ]; then
        mode_name="TPROXY"
    else
        mode_name="REDIRECT"
    fi

    log Info "正在为 IPv${family} 设置 $mode_name 链"

    # 根据协议族定义链名
    local chains=""
    chains="PROXY_PREROUTING$suffix PROXY_OUTPUT$suffix DIVERT$suffix PROXY_IP$suffix BYPASS_IP$suffix BYPASS_INTERFACE$suffix PROXY_INTERFACE$suffix DNS_HIJACK_PRE$suffix DNS_HIJACK_OUT$suffix APP_CHAIN$suffix MAC_CHAIN$suffix"

    local table="mangle"
    if [ "$mode" = "redirect" ]; then
        table="nat"
    fi

    # 创建链
    for c in $chains; do
        safe_chain_create "$family" "$table" "$c"
    done

    if [ "$PERFORMANCE_MODE" -eq 1 ] && [ "$HAS_MARK_TG" -eq 1 ] && [ "$HAS_SOCKET" -eq 1 ]; then
        $cmd -t "$table" -A DIVERT$suffix -j MARK --set-mark "$mark"
        $cmd -t "$table" -A DIVERT$suffix -j ACCEPT

        $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -p tcp -m socket --transparent -j DIVERT$suffix
    fi

    if [ "$HAS_CONNTRACK" -eq 1 ]; then
        $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -m conntrack --ctdir REPLY -j ACCEPT
        $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -m conntrack --ctdir REPLY -j ACCEPT
        log Info "已添加回程连接方向绕过"
    fi

    local bypass_success=0
    if [ "$FORCE_MARK_BYPASS" -eq 1 ] && [ "$HAS_MARK_MT" -eq 1 ] && [ -n "$ROUTING_MARK" ]; then
        $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -m mark --mark "$ROUTING_MARK" -j ACCEPT
        $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -m mark --mark "$ROUTING_MARK" -j ACCEPT
        log Info "已为带有核心标记 $ROUTING_MARK 的流量添加绕过规则（强制）"
        bypass_success=1
    elif [ "$HAS_OWNER" -eq 1 ]; then
        $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -m owner --uid-owner "$CORE_USER" --gid-owner "$CORE_GROUP" -j ACCEPT
        log Info "已为核心用户 $CORE_USER:$CORE_GROUP 添加绕过规则"
        bypass_success=1
    elif [ "$HAS_MARK_MT" -eq 1 ] && [ -n "$ROUTING_MARK" ]; then
        $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -m mark --mark "$ROUTING_MARK" -j ACCEPT
        log Info "已为带有核心标记 $ROUTING_MARK 的流量添加绕过规则"
        bypass_success=1
    fi
    if [ "$bypass_success" -eq 0 ]; then
        log Error "核心流量绕过未配置，可能导致流量回环"
    fi

    # 预检性能模式下的 conntrack
    local _perf_ct=0
    if [ "$PERFORMANCE_MODE" -eq 1 ] && [ "$HAS_CONNTRACK" -eq 1 ]; then
        _perf_ct=1
    fi

    _add_chain_jumps "PROXY_PREROUTING$suffix" "$_perf_ct" \
        "PROXY_IP$suffix" "BYPASS_IP$suffix" "PROXY_INTERFACE$suffix" "MAC_CHAIN$suffix" "DNS_HIJACK_PRE$suffix"

    _add_chain_jumps "PROXY_OUTPUT$suffix" "$_perf_ct" \
        "PROXY_IP$suffix" "BYPASS_IP$suffix" "BYPASS_INTERFACE$suffix" "APP_CHAIN$suffix" "DNS_HIJACK_OUT$suffix"

    local subnet4
    local subnet6
    if [ "$family" = "6" ]; then
        if [ -n "$PROXY_IPv6_LIST" ]; then
            for subnet6 in $PROXY_IPv6_LIST; do
                $cmd -t "$table" -A "PROXY_IP$suffix" -d "$subnet6" -j RETURN
            done
            log Info "已为代理 IPv6 范围添加代理规则"
        fi
    else
        if [ -n "$PROXY_IPv4_LIST" ]; then
            for subnet4 in $PROXY_IPv4_LIST; do
                $cmd -t "$table" -A "PROXY_IP$suffix" -d "$subnet4" -j RETURN
            done
            log Info "已为代理 IPv4 范围添加代理规则"
        fi
    fi

    if [ "$HAS_ADDRTYPE" -eq 1 ]; then
        $cmd -t "$table" -A "BYPASS_IP$suffix" -m addrtype --dst-type LOCAL -p udp ! --dport 53 -j ACCEPT
        $cmd -t "$table" -A "BYPASS_IP$suffix" -m addrtype --dst-type LOCAL ! -p udp -j ACCEPT
        log Info "已添加本地地址类型绕过规则"
    fi

    if [ "$family" = "6" ]; then
        for subnet6 in $BYPASS_IPv6_LIST; do
            $cmd -t "$table" -A "BYPASS_IP$suffix" -d "$subnet6" -p udp ! --dport 53 -j ACCEPT
            $cmd -t "$table" -A "BYPASS_IP$suffix" -d "$subnet6" ! -p udp -j ACCEPT
        done
        log Info "已为绕过 IPv6 范围添加绕过规则"
    else
        for subnet4 in $BYPASS_IPv4_LIST; do
            $cmd -t "$table" -A "BYPASS_IP$suffix" -d "$subnet4" -p udp ! --dport 53 -j ACCEPT
            $cmd -t "$table" -A "BYPASS_IP$suffix" -d "$subnet4" ! -p udp -j ACCEPT
        done
        log Info "已为绕过 IPv4 范围添加绕过规则"
    fi

    if [ "$BYPASS_CN_IP" -eq 1 ]; then
        local ipset_name="cnip"
        if [ "$family" = "6" ]; then
            ipset_name="cnip6"
        fi
        if command -v ipset > /dev/null 2>&1 && ipset list "$ipset_name" > /dev/null 2>&1; then
            $cmd -t "$table" -A "BYPASS_IP$suffix" -m set --match-set "$ipset_name" dst -p udp ! --dport 53 -j ACCEPT
            $cmd -t "$table" -A "BYPASS_IP$suffix" -m set --match-set "$ipset_name" dst ! -p udp -j ACCEPT
            log Info "已添加基于 ipset 的国内 IP 绕过规则"
        else
            log Warn "ipset '$ipset_name' 不可用，跳过国内 IP 绕过"
        fi
    fi

    log Info "正在配置接口代理规则"
    $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i lo -j RETURN
    if [ "$PROXY_MOBILE" -eq 1 ]; then
        $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$MOBILE_INTERFACE" -j RETURN
        log Info "移动数据接口 $MOBILE_INTERFACE 将走代理"
    else
        $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$MOBILE_INTERFACE" -j ACCEPT
        $cmd -t "$table" -A "BYPASS_INTERFACE$suffix" -o "$MOBILE_INTERFACE" -j ACCEPT
        log Info "移动数据接口 $MOBILE_INTERFACE 将绕过代理"
    fi

    local subnet
    if [ "$family" = "6" ]; then
        subnet="$HOTSPOT_SUBNET_IPV6"
    else
        subnet="$HOTSPOT_SUBNET_IPV4"
    fi

    if [ "$HOTSPOT_INTERFACE" = "$WIFI_INTERFACE" ]; then
        if [ "$PROXY_HOTSPOT" -eq 1 ]; then
            $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$HOTSPOT_INTERFACE" -s "$subnet" -j RETURN
            log Info "热点接口 $HOTSPOT_INTERFACE 将走代理"
        else
            $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$HOTSPOT_INTERFACE" -s "$subnet" -j ACCEPT
            log Info "热点接口 $HOTSPOT_INTERFACE 将绕过代理"
        fi

        if [ "$PROXY_WIFI" -eq 1 ]; then
            $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$WIFI_INTERFACE" ! -s "$subnet" -j RETURN
            log Info "WiFi 接口 $WIFI_INTERFACE 将走代理"
        else
            $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$WIFI_INTERFACE" ! -s "$subnet" -j ACCEPT
            $cmd -t "$table" -A "BYPASS_INTERFACE$suffix" -o "$WIFI_INTERFACE" -j ACCEPT
            log Info "WiFi 接口 $WIFI_INTERFACE 将绕过代理"
        fi
    else
        if [ "$PROXY_WIFI" -eq 1 ]; then
            $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$WIFI_INTERFACE" -j RETURN
            log Info "WiFi 接口 $WIFI_INTERFACE 将走代理"
        else
            $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$WIFI_INTERFACE" -j ACCEPT
            $cmd -t "$table" -A "BYPASS_INTERFACE$suffix" -o "$WIFI_INTERFACE" -j ACCEPT
            log Info "WiFi 接口 $WIFI_INTERFACE 将绕过代理"
        fi

        if [ "$PROXY_HOTSPOT" -eq 1 ]; then
            $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$HOTSPOT_INTERFACE" -j RETURN
            log Info "热点接口 $HOTSPOT_INTERFACE 将走代理"
        else
            $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$HOTSPOT_INTERFACE" -j ACCEPT
            $cmd -t "$table" -A "BYPASS_INTERFACE$suffix" -o "$HOTSPOT_INTERFACE" -j ACCEPT
            log Info "热点接口 $HOTSPOT_INTERFACE 将绕过代理"
        fi
    fi

    if [ "$PROXY_USB" -eq 1 ]; then
        $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$USB_INTERFACE" -j RETURN
        log Info "USB 接口 $USB_INTERFACE 将走代理"
    else
        $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$USB_INTERFACE" -j ACCEPT
        $cmd -t "$table" -A "BYPASS_INTERFACE$suffix" -o "$USB_INTERFACE" -j ACCEPT
        log Info "USB 接口 $USB_INTERFACE 将绕过代理"
    fi

    local interface
    if [ -n "$OTHER_PROXY_INTERFACES" ]; then
        for interface in $OTHER_PROXY_INTERFACES; do
            $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$interface" -j RETURN
        done
        log Info "其他接口 $OTHER_PROXY_INTERFACES 将走代理"
    fi

    if [ -n "$OTHER_BYPASS_INTERFACES" ]; then
        for interface in $OTHER_BYPASS_INTERFACES; do
            $cmd -t "$table" -A "PROXY_INTERFACE$suffix" -i "$interface" -j ACCEPT
            $cmd -t "$table" -A "BYPASS_INTERFACE$suffix" -o "$interface" -j ACCEPT
        done
        log Info "其他接口 $OTHER_BYPASS_INTERFACES 将绕过代理"
    fi

    log Info "接口代理规则配置完成"

    local mac
    if [ "$MAC_FILTER_ENABLE" -eq 1 ] && [ "$PROXY_HOTSPOT" -eq 1 ] && [ -n "$HOTSPOT_INTERFACE" ]; then
        if [ "$HAS_MAC" -eq 1 ]; then
            log Info "正在为接口 $HOTSPOT_INTERFACE 设置 MAC 地址过滤规则"
            case "$MAC_PROXY_MODE" in
                blacklist)
                    if [ -n "$BYPASS_MACS_LIST" ]; then
                        for mac in $BYPASS_MACS_LIST; do
                            if [ -n "$mac" ]; then
                                $cmd -t "$table" -A "MAC_CHAIN$suffix" -m mac --mac-source "$mac" -i "$HOTSPOT_INTERFACE" -j ACCEPT
                                log Info "已添加 MAC 绕过规则：$mac"
                            fi
                        done
                    else
                        log Warn "已启用 MAC 黑名单模式，但未配置绕过的 MAC 地址"
                    fi
                    $cmd -t "$table" -A "MAC_CHAIN$suffix" -i "$HOTSPOT_INTERFACE" -j RETURN
                    ;;
                whitelist)
                    if [ -n "$PROXY_MACS_LIST" ]; then
                        for mac in $PROXY_MACS_LIST; do
                            if [ -n "$mac" ]; then
                                $cmd -t "$table" -A "MAC_CHAIN$suffix" -m mac --mac-source "$mac" -i "$HOTSPOT_INTERFACE" -j RETURN
                                log Info "已添加 MAC 代理规则：$mac"
                            fi
                        done
                    else
                        log Warn "已启用 MAC 白名单模式，但未配置代理的 MAC 地址"
                    fi
                    $cmd -t "$table" -A "MAC_CHAIN$suffix" -i "$HOTSPOT_INTERFACE" -j ACCEPT
                    ;;
            esac
        else
            log Warn "MAC 过滤需要内核功能 NETFILTER_XT_MATCH_MAC，但该功能不可用"
        fi
    fi

    local uids
    local uid
    if [ "$APP_PROXY_ENABLE" -eq 1 ]; then
        if [ "$HAS_OWNER" -eq 1 ]; then
            log Info "正在以 $APP_PROXY_MODE 模式配置应用过滤规则"
            case "$APP_PROXY_MODE" in
                blacklist)
                    if [ -n "$BYPASS_APPS_LIST" ]; then
                        uids=$(find_packages_uid $BYPASS_APPS_LIST)
                        if [ $? -eq 0 ] && [ -n "$uids" ]; then
                            for uid in $uids; do
                                if [ -n "$uid" ]; then
                                    $cmd -t "$table" -A "APP_CHAIN$suffix" -m owner --uid-owner "$uid" -j ACCEPT
                                    log Info "已为 UID $uid 添加绕过规则"
                                fi
                            done
                        fi
                    else
                        log Warn "已启用应用黑名单模式，但未配置绕过的应用"
                    fi
                    $cmd -t "$table" -A "APP_CHAIN$suffix" -j RETURN
                    ;;
                whitelist)
                    if [ -n "$PROXY_APPS_LIST" ]; then
                        uids=$(find_packages_uid $PROXY_APPS_LIST)
                        if [ $? -eq 0 ] && [ -n "$uids" ]; then
                            for uid in $uids; do
                                if [ -n "$uid" ]; then
                                    $cmd -t "$table" -A "APP_CHAIN$suffix" -m owner --uid-owner "$uid" -j RETURN
                                    log Info "已为 UID $uid 添加代理规则"
                                fi
                            done
                        fi
                    else
                        log Warn "已启用应用白名单模式，但未配置代理的应用"
                    fi
                    $cmd -t "$table" -A "APP_CHAIN$suffix" -j ACCEPT
                    ;;
            esac
        else
            log Warn "应用过滤需要内核功能 NETFILTER_XT_MATCH_OWNER，但该功能不可用"
        fi
    fi

    if [ "$DNS_HIJACK_ENABLE" -ne 0 ]; then
        if [ "$mode" = "redirect" ]; then
            setup_dns_hijack "$family" "redirect"
        else
            if [ "$DNS_HIJACK_ENABLE" -eq 2 ]; then
                setup_dns_hijack "$family" "redirect2"
            else
                setup_dns_hijack "$family" "tproxy"
            fi
        fi
    fi

    if [ "$_perf_ct" -eq 1 ]; then
        if [ "$mode" = "tproxy" ]; then
            $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -m conntrack --ctstate NEW,RELATED -j CONNMARK --set-mark "$mark"
            $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -p tcp -m connmark --mark "$mark" -j TPROXY --on-port "$PROXY_TCP_PORT" --tproxy-mark "$mark"
            $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -p udp -m connmark --mark "$mark" -j TPROXY --on-port "$PROXY_UDP_PORT" --tproxy-mark "$mark"

            $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -m conntrack --ctstate NEW,RELATED -j CONNMARK --set-mark "$mark"
            $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -m connmark --mark "$mark" -j MARK --set-mark "$mark"
            log Info "已添加 TPROXY 模式规则"
        else
            $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -m conntrack --ctstate NEW,RELATED -j CONNMARK --set-mark "$mark"
            $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -m connmark --mark "$mark" -j REDIRECT --to-ports "$PROXY_TCP_PORT"

            $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -m conntrack --ctstate NEW,RELATED -j CONNMARK --set-mark "$mark"
            $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -m connmark --mark "$mark" -j REDIRECT --to-ports "$PROXY_TCP_PORT"
            log Info "已添加 REDIRECT 模式规则"
        fi
    else
        if [ "$mode" = "tproxy" ]; then
            $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -p tcp -j TPROXY --on-port "$PROXY_TCP_PORT" --tproxy-mark "$mark"
            $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -p udp -j TPROXY --on-port "$PROXY_UDP_PORT" --tproxy-mark "$mark"
            $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -j MARK --set-mark "$mark"
            log Info "已添加 TPROXY 模式规则"
        else
            $cmd -t "$table" -A "PROXY_PREROUTING$suffix" -j REDIRECT --to-ports "$PROXY_TCP_PORT"
            $cmd -t "$table" -A "PROXY_OUTPUT$suffix" -j REDIRECT --to-ports "$PROXY_TCP_PORT"
            log Info "已添加 REDIRECT 模式规则"
        fi
    fi

    # 向主链添加规则
    if [ "$PROXY_UDP" -eq 1 ] || [ "$mode" = "redirect" ]; then
        $cmd -t "$table" -I PREROUTING -p udp -j "PROXY_PREROUTING$suffix"
        $cmd -t "$table" -I OUTPUT -p udp -j "PROXY_OUTPUT$suffix"
        log Info "已向 PREROUTING 和 OUTPUT 链添加 UDP 规则"
    fi
    if [ "$PROXY_TCP" -eq 1 ]; then
        $cmd -t "$table" -I PREROUTING -p tcp -j "PROXY_PREROUTING$suffix"
        $cmd -t "$table" -I OUTPUT -p tcp -j "PROXY_OUTPUT$suffix"
        log Info "已向 PREROUTING 和 OUTPUT 链添加 TCP 规则"
    fi

    log Info "IPv${family} 的 $mode_name 链配置完成"
}

setup_dns_hijack() {
    local family="$1"
    local mode="$2"
    local suffix=""
    local mark="$MARK_VALUE"
    local cmd="iptables"

    if [ "$family" = "6" ]; then
        suffix="6"
        mark="$MARK_VALUE6"
        cmd="ip6tables"
    fi

    case "$mode" in
        tproxy)
            # 在 PREROUTING 链处理来自接口的 DNS（DNS_HIJACK_PRE）
            $cmd -t mangle -A "DNS_HIJACK_PRE$suffix" -j RETURN
            # 在 OUTPUT 链处理本地 DNS 劫持（DNS_HIJACK_OUT）
            $cmd -t mangle -A "DNS_HIJACK_OUT$suffix" -j RETURN

            log Info "DNS 劫持已启用（TPROXY 模式）"
            ;;
        redirect)
            # 使用 REDIRECT 方式处理 DNS
            $cmd -t nat -A "PROXY_PREROUTING$suffix" -p tcp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"
            $cmd -t nat -A "PROXY_PREROUTING$suffix" -p udp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"
            $cmd -t nat -A "PROXY_OUTPUT$suffix" -p tcp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"
            $cmd -t nat -A "PROXY_OUTPUT$suffix" -p udp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"
            log Info "DNS 劫持已启用（REDIRECT 模式，重定向到端口 $DNS_PORT）"
            ;;
        redirect2)
            # 使用 REDIRECT 方式处理 DNS
            if [ "$family" = "6" ] && {
                [ "$HAS_NAT6" -eq 0 ] || [ "$HAS_REDIRECT6" -eq 0 ]
            }; then
                log Warn "IPv6：内核不支持 IPv6 NAT 或 REDIRECT，已跳过 IPv6 DNS 劫持"
                return 0
            fi
            safe_chain_create "$family" "nat" "NAT_DNS_HIJACK$suffix"
            $cmd -t nat -A "NAT_DNS_HIJACK$suffix" -p tcp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"
            $cmd -t nat -A "NAT_DNS_HIJACK$suffix" -p udp --dport 53 -j REDIRECT --to-ports "$DNS_PORT"

            [ "$PROXY_MOBILE" -eq 1 ] && $cmd -t nat -A PREROUTING -i "$MOBILE_INTERFACE" -j "NAT_DNS_HIJACK$suffix"
            [ "$PROXY_WIFI" -eq 1 ] && $cmd -t nat -A PREROUTING -i "$WIFI_INTERFACE" -j "NAT_DNS_HIJACK$suffix"
            [ "$PROXY_USB" -eq 1 ] && $cmd -t nat -A PREROUTING -i "$USB_INTERFACE" -j "NAT_DNS_HIJACK$suffix"
            local interface
            if [ -n "$OTHER_PROXY_INTERFACES" ]; then
                for interface in $OTHER_PROXY_INTERFACES; do
                    $cmd -t nat -A PREROUTING -i "$interface" -j "NAT_DNS_HIJACK$suffix"
                done
            fi

            $cmd -t nat -A OUTPUT -p udp --dport 53 -m owner --uid-owner "$CORE_USER" --gid-owner "$CORE_GROUP" -j ACCEPT
            $cmd -t nat -A OUTPUT -p tcp --dport 53 -m owner --uid-owner "$CORE_USER" --gid-owner "$CORE_GROUP" -j ACCEPT
            $cmd -t nat -A OUTPUT -j "NAT_DNS_HIJACK$suffix"

            log Info "DNS 劫持已启用（REDIRECT 模式，重定向到端口 $DNS_PORT）"
            ;;
    esac
}

setup_tproxy_chain4() {
    setup_proxy_chain 4 "tproxy"
}

setup_redirect_chain4() {
    log Warn "REDIRECT 模式仅支持 TCP"
    setup_proxy_chain 4 "redirect"
}

setup_tproxy_chain6() {
    setup_proxy_chain 6 "tproxy"
}

setup_redirect_chain6() {
    if [ "$HAS_NAT6" -eq 0 ] || [ "$HAS_REDIRECT6" -eq 0 ]; then
        log Warn "IPv6：内核不支持 IPv6 NAT 或 REDIRECT，已跳过 IPv6 代理设置"
        return 0
    fi
    log Warn "REDIRECT 模式仅支持 TCP"
    setup_proxy_chain 6 "redirect"
}

setup_routing4() {
    log Info "正在设置 IPv4 路由规则"

    ip_rule add fwmark "$MARK_VALUE" table "$TABLE_ID" pref "$TABLE_ID" || {
        log Error "添加 IPv4 路由规则失败"
        return 1
    }
    ip_route add local 0.0.0.0/0 dev lo table "$TABLE_ID" || {
        log Error "添加 IPv4 路由失败"
        return 1
    }

    log Debug "[EXEC] echo 1 > /proc/sys/net/ipv4/ip_forward"
    [ "$DRY_RUN" -eq 0 ] && echo 1 > /proc/sys/net/ipv4/ip_forward

    log Info "IPv4 路由设置完成"
}

setup_routing6() {
    log Info "正在设置 IPv6 路由规则"

    ip6_rule add fwmark "$MARK_VALUE6" table "$TABLE_ID" pref "$TABLE_ID" || {
        log Error "添加 IPv6 路由规则失败"
        return 1
    }
    ip6_route add local ::/0 dev lo table "$TABLE_ID" || {
        log Error "添加 IPv6 路由失败"
        return 1
    }

    log Debug "[EXEC] echo 1 > /proc/sys/net/ipv6/conf/all/forwarding"
    [ "$DRY_RUN" -eq 0 ] && echo 1 > /proc/sys/net/ipv6/conf/all/forwarding

    log Info "IPv6 路由设置完成"
}

cleanup_chain() {
    local family="$1"
    local mode="$2"
    local suffix=""
    local cmd="iptables"

    if [ "$family" = "6" ]; then
        suffix="6"
        cmd="ip6tables"
    fi

    local mode_name="$mode"
    if [ "$mode" = "tproxy" ]; then
        mode_name="TPROXY"
    else
        mode_name="REDIRECT"
    fi

    log Info "正在清理 IPv${family} 的 $mode_name 链"

    local table="mangle"
    if [ "$mode" = "redirect" ]; then
        table="nat"
    fi

    # 从主链中移除规则（与设置时对称）
    if [ "$PROXY_TCP" -eq 1 ]; then
        $cmd -t "$table" -D PREROUTING -p tcp -j "PROXY_PREROUTING$suffix" 2> /dev/null || true
        $cmd -t "$table" -D OUTPUT -p tcp -j "PROXY_OUTPUT$suffix" 2> /dev/null || true
    fi
    if [ "$PROXY_UDP" -eq 1 ] || [ "$mode" = "redirect" ]; then
        $cmd -t "$table" -D PREROUTING -p udp -j "PROXY_PREROUTING$suffix" 2> /dev/null || true
        $cmd -t "$table" -D OUTPUT -p udp -j "PROXY_OUTPUT$suffix" 2> /dev/null || true
    fi

    # 根据协议族定义链名
    local chains="PROXY_PREROUTING$suffix PROXY_OUTPUT$suffix DIVERT$suffix PROXY_IP$suffix BYPASS_IP$suffix BYPASS_INTERFACE$suffix PROXY_INTERFACE$suffix DNS_HIJACK_PRE$suffix DNS_HIJACK_OUT$suffix APP_CHAIN$suffix MAC_CHAIN$suffix"

    # 清理链
    for c in $chains; do
        $cmd -t "$table" -F "$c" 2> /dev/null || true
        $cmd -t "$table" -X "$c" 2> /dev/null || true
    done

    # 如有需要，移除 DNS 规则
    if [ "$mode" = "tproxy" ] && [ "$DNS_HIJACK_ENABLE" -eq 2 ]; then
        $cmd -t nat -D PREROUTING -i "$MOBILE_INTERFACE" -j "NAT_DNS_HIJACK$suffix" 2> /dev/null || true
        $cmd -t nat -D PREROUTING -i "$WIFI_INTERFACE" -j "NAT_DNS_HIJACK$suffix" 2> /dev/null || true
        $cmd -t nat -D PREROUTING -i "$USB_INTERFACE" -j "NAT_DNS_HIJACK$suffix" 2> /dev/null || true
        local interface
        if [ -n "$OTHER_PROXY_INTERFACES" ]; then
            for interface in $OTHER_PROXY_INTERFACES; do
                $cmd -t nat -D PREROUTING -i "$interface" -j "NAT_DNS_HIJACK$suffix" 2> /dev/null || true
            done
        fi
        $cmd -t nat -D OUTPUT -p udp --dport 53 -m owner --uid-owner "$CORE_USER" --gid-owner "$CORE_GROUP" -j ACCEPT 2> /dev/null || true
        $cmd -t nat -D OUTPUT -p tcp --dport 53 -m owner --uid-owner "$CORE_USER" --gid-owner "$CORE_GROUP" -j ACCEPT 2> /dev/null || true
        $cmd -t nat -D OUTPUT -j "NAT_DNS_HIJACK$suffix" 2> /dev/null || true
        $cmd -t nat -F "NAT_DNS_HIJACK$suffix" 2> /dev/null || true
        $cmd -t nat -X "NAT_DNS_HIJACK$suffix" 2> /dev/null || true
    fi

    log Info "IPv${family} 的 $mode_name 链清理完成"
}

cleanup_tproxy_chain4() {
    cleanup_chain 4 "tproxy"
}

cleanup_tproxy_chain6() {
    cleanup_chain 6 "tproxy"
}

cleanup_redirect_chain4() {
    cleanup_chain 4 "redirect"
}

cleanup_redirect_chain6() {
    if [ "$HAS_NAT6" -eq 0 ] || [ "$HAS_REDIRECT6" -eq 0 ]; then
        log Warn "IPv6：内核不支持 IPv6 NAT 或 REDIRECT，已跳过 IPv6 清理"
        return 0
    fi
    cleanup_chain 6 "redirect"
}

cleanup_routing4() {
    log Info "正在清理 IPv4 路由规则"

    ip_rule del fwmark "$MARK_VALUE" table "$TABLE_ID" pref "$TABLE_ID"
    ip_route del local 0.0.0.0/0 dev lo table "$TABLE_ID"

    log Debug "[EXEC] echo 0 > /proc/sys/net/ipv4/ip_forward"
    [ "$DRY_RUN" -eq 0 ] && echo 0 > /proc/sys/net/ipv4/ip_forward

    log Info "IPv4 路由清理完成"
}

cleanup_routing6() {
    log Info "正在清理 IPv6 路由规则"

    ip6_rule del fwmark "$MARK_VALUE6" table "$TABLE_ID" pref "$TABLE_ID"
    ip6_route del local ::/0 dev lo table "$TABLE_ID"

    log Debug "[EXEC] echo 0 > /proc/sys/net/ipv6/conf/all/forwarding"
    [ "$DRY_RUN" -eq 0 ] && echo 0 > /proc/sys/net/ipv6/conf/all/forwarding

    log Info "IPv6 路由清理完成"
}

cleanup_ipset() {
    if [ "$BYPASS_CN_IP" -eq 0 ]; then
        log Debug "已禁用国内 IP 绕过，跳过 ipset 清理"
        return 0
    fi

    log Debug "[EXEC] ipset destroy cnip"
    log Debug "[EXEC] ipset destroy cnip6"
    if [ "$DRY_RUN" -eq 0 ]; then
        ipset destroy cnip 2> /dev/null || true
        ipset destroy cnip6 2> /dev/null || true
        log Info "ipset 'cnip' 和 'cnip6' 已销毁"
    fi
}

detect_proxy_mode() {
    USE_TPROXY=0
    case "$PROXY_MODE" in
        0)
            if check_tproxy_support; then
                USE_TPROXY=1
                log Info "内核支持 TPROXY，使用 TPROXY 模式（自动）"
            else
                log Warn "内核不支持 TPROXY，回退到 REDIRECT 模式（自动）"
            fi
            ;;
        1)
            if check_tproxy_support; then
                USE_TPROXY=1
                log Info "使用 TPROXY 模式（由配置强制指定）"
            else
                log Error "已强制指定 TPROXY 模式，但内核不支持 TPROXY"
                exit 1
            fi
            ;;
        2)
            log Info "使用 REDIRECT 模式（由配置强制指定）"
            ;;
    esac
}

start_proxy() {
    log Info "正在启动代理设置..."
    if [ "$BYPASS_CN_IP" -eq 1 ]; then
        if [ "$HAS_IPSET" -eq 0 ] || [ "$HAS_XT_SET" -eq 0 ]; then
            log Error "内核不支持 ipset（CONFIG_IP_SET、CONFIG_NETFILTER_XT_SET），无法绕过国内 IP"
            BYPASS_CN_IP=0
        else
            download_cn_ip_list || log Warn "下载国内 IP 列表失败，继续运行（不使用该列表）"
            if ! setup_cn_ipset; then
                log Error "ipset 设置失败，已禁用国内 IP 绕过"
                BYPASS_CN_IP=0
            fi
        fi
    fi

    if [ "$USE_TPROXY" -eq 1 ]; then
        setup_tproxy_chain4
        setup_routing4
        if [ "$PROXY_IPV6" -eq 1 ]; then
            setup_tproxy_chain6
            setup_routing6
        fi
    else
        setup_redirect_chain4
        if [ "$PROXY_IPV6" -eq 1 ]; then
            setup_redirect_chain6
        fi
    fi
    log Info "代理设置完成"
    block_loopback_traffic enable
    [ "$BLOCK_QUIC" -eq 1 ] && block_quic enable
    if [ "$PROXY_IPV6" -eq -1 ]; then
        manage_ipv6 disable || log Warn "禁用 IPv6 协议栈失败"
    fi
    save_runtime_config
}

stop_proxy() {
    log Info "正在停止代理..."
    if load_runtime_config; then
        log Info "使用运行时配置进行清理"
    else
        log Warn "使用当前配置进行清理（运行时配置不可用）"
    fi
    if [ "$USE_TPROXY" -eq 1 ]; then
        log Info "正在清理 TPROXY 链"
        cleanup_tproxy_chain4
        cleanup_routing4
        if [ "$PROXY_IPV6" -eq 1 ]; then
            cleanup_tproxy_chain6
            cleanup_routing6
        fi
    else
        log Info "正在清理 REDIRECT 链"
        cleanup_redirect_chain4
        if [ "$PROXY_IPV6" -eq 1 ]; then
            cleanup_redirect_chain6
        fi
    fi
    cleanup_ipset
    log Info "代理已停止"
    block_loopback_traffic disable
    block_quic disable
    if [ "$PROXY_IPV6" -eq -1 ]; then
        manage_ipv6 restore || log Warn "恢复 IPv6 设置失败"
    fi
    [ "$DRY_RUN" -eq 1 ] || rm -f "$CONFIG_DIR/runtime_tproxy.conf" 2> /dev/null
}

# 此规则阻止对 tproxy 端口的本地访问，防止流量回环。
block_loopback_traffic() {
    case "$1" in
        enable)
            ip6tables -t filter -A OUTPUT -d ::1 -p tcp -m owner --uid-owner "$CORE_USER" --gid-owner "$CORE_GROUP" -m tcp --dport "$PROXY_TCP_PORT" -j REJECT
            iptables -t filter -A OUTPUT -d 127.0.0.1 -p tcp -m owner --uid-owner "$CORE_USER" --gid-owner "$CORE_GROUP" -m tcp --dport "$PROXY_TCP_PORT" -j REJECT
            ;;
        disable)
            ip6tables -t filter -D OUTPUT -d ::1 -p tcp -m owner --uid-owner "$CORE_USER" --gid-owner "$CORE_GROUP" -m tcp --dport "$PROXY_TCP_PORT" -j REJECT 2> /dev/null || true
            iptables -t filter -D OUTPUT -d 127.0.0.1 -p tcp -m owner --uid-owner "$CORE_USER" --gid-owner "$CORE_GROUP" -m tcp --dport "$PROXY_TCP_PORT" -j REJECT 2> /dev/null || true
            ;;
    esac
}

block_quic() {
    case "$1" in
        enable)
            iptables -N BLOCK_QUIC 2> /dev/null || true
            iptables -F BLOCK_QUIC
            if [ "$BYPASS_CN_IP" -eq 1 ]; then
                iptables -A BLOCK_QUIC -p udp --dport 443 -m set ! --match-set cnip dst -j REJECT
            else
                iptables -A BLOCK_QUIC -p udp --dport 443 -j REJECT
            fi
            iptables -I INPUT -j BLOCK_QUIC
            iptables -I FORWARD -j BLOCK_QUIC
            iptables -I OUTPUT -j BLOCK_QUIC

            if [ "$PROXY_IPV6" -eq 1 ]; then
                ip6tables -N BLOCK_QUIC6 2> /dev/null || true
                ip6tables -F BLOCK_QUIC6
                if [ "$BYPASS_CN_IP" -eq 1 ]; then
                    ip6tables -A BLOCK_QUIC6 -p udp --dport 443 -m set ! --match-set cnip6 dst -j REJECT
                else
                    ip6tables -A BLOCK_QUIC6 -p udp --dport 443 -j REJECT
                fi
                ip6tables -I INPUT -j BLOCK_QUIC6
                ip6tables -I FORWARD -j BLOCK_QUIC6
                ip6tables -I OUTPUT -j BLOCK_QUIC6
            fi
            log Info "QUIC 流量已阻断"
            ;;
        disable)
            local chain
            for chain in INPUT FORWARD OUTPUT; do
                iptables -D "$chain" -j BLOCK_QUIC 2> /dev/null || true
                ip6tables -D "$chain" -j BLOCK_QUIC6 2> /dev/null || true
            done
            iptables -F BLOCK_QUIC 2> /dev/null || true
            iptables -X BLOCK_QUIC 2> /dev/null || true
            ip6tables -F BLOCK_QUIC6 2> /dev/null || true
            ip6tables -X BLOCK_QUIC6 2> /dev/null || true
            log Info "QUIC 流量阻断已禁用"
            ;;
    esac
}

manage_ipv6() {
    local action="$1"
    local ipv6_backup_file="$CONFIG_DIR/ipv6_backup.conf"

    case "$action" in
        backup | disable | restore) ;;
        *)
            log Error "manage_ipv6 的操作参数无效：$action（必须为 backup、disable 或 restore）"
            return 1
            ;;
    esac

    if [ "$DRY_RUN" -eq 1 ]; then
        log Debug "将 $action IPv6 设置"
        return 0
    fi

    if [ "$action" = "backup" ] || [ "$action" = "disable" ]; then
        log Info "正在将当前 IPv6 设置备份到 $ipv6_backup_file"

        {
            echo "# IPv6 设置备份（自动生成于 $(date)）"
            echo "accept_ra=$(cat /proc/sys/net/ipv6/conf/all/accept_ra 2> /dev/null || echo unknown)"
            echo "autoconf=$(cat /proc/sys/net/ipv6/conf/all/autoconf 2> /dev/null || echo unknown)"
            echo "forwarding=$(cat /proc/sys/net/ipv6/conf/all/forwarding 2> /dev/null || echo unknown)"

            for iface in /proc/sys/net/ipv6/conf/*; do
                if [ -f "$iface/disable_ipv6" ]; then
                    iface_name=$(basename "$iface")
                    current=$(cat "$iface/disable_ipv6" 2> /dev/null || echo unknown)
                    echo "$iface_name=$current"
                fi
            done
        } > "$ipv6_backup_file" || {
            log Warn "备份 IPv6 设置失败"
            return 1
        }

        log Debug "IPv6 备份完成"
    fi

    if [ "$action" = "disable" ]; then
        log Info "正在强制禁用 IPv6 协议栈（disable_ipv6=1）"

        echo 0 > /proc/sys/net/ipv6/conf/all/accept_ra 2> /dev/null || true
        echo 0 > /proc/sys/net/ipv6/conf/all/autoconf 2> /dev/null || true
        echo 0 > /proc/sys/net/ipv6/conf/all/forwarding 2> /dev/null || true

        for iface in /proc/sys/net/ipv6/conf/*; do
            if [ -f "$iface/disable_ipv6" ]; then
                echo 1 > "$iface/disable_ipv6" 2> /dev/null || true
            fi
        done

        log Info "IPv6 协议栈已完全禁用"
    fi

    if [ "$action" = "restore" ]; then
        if [ ! -f "$ipv6_backup_file" ]; then
            log Warn "未找到 IPv6 备份文件：$ipv6_backup_file，跳过恢复"
            return 0
        fi

        log Info "正在从 $ipv6_backup_file 恢复 IPv6 设置"

        while IFS='=' read -r key value; do
            # 跳过注释和空行
            case "$key" in
                \#* | "") continue ;;
            esac

            case "$key" in
                accept_ra)
                    echo "$value" > /proc/sys/net/ipv6/conf/all/accept_ra 2> /dev/null || true
                    ;;
                autoconf)
                    echo "$value" > /proc/sys/net/ipv6/conf/all/autoconf 2> /dev/null || true
                    ;;
                forwarding)
                    echo "$value" > /proc/sys/net/ipv6/conf/all/forwarding 2> /dev/null || true
                    ;;
                *)
                    if [ -f "/proc/sys/net/ipv6/conf/$key/disable_ipv6" ]; then
                        echo "$value" > "/proc/sys/net/ipv6/conf/$key/disable_ipv6" 2> /dev/null || true
                    fi
                    ;;
            esac
        done < "$ipv6_backup_file"

        rm -f "$ipv6_backup_file" 2> /dev/null
        log Info "IPv6 设置已恢复"
    fi

    return 0
}

is_func() {
    command -v "$1" > /dev/null 2>&1
}

call_func() {
    local func="$1"
    shift
    if is_func "$func"; then
        log Info "正在调用用户钩子：$func"
        "$func" "$@"
    else
        log Debug "未定义用户钩子：$func"
    fi
}

show_usage() {
    local script_name
    script_name=$(basename "$0")

    cat << EOF
用法：$script_name {start|stop|restart} [选项]

本脚本用于配置/清理透明代理（TPROXY 或 REDIRECT）规则，
支持 TCP/UDP 流量重定向、DNS 劫持、按应用代理、国内 IP 绕过等功能。

命令：
  start     应用代理规则、路由表、ipset、sysctl 修改
  stop      移除所有添加的规则、路由、ipset 集合，恢复 sysctl
  restart   等同于 stop → 短暂延迟 → start

选项：
  -v, --version              显示版本号并退出

  -d DIR, --dir DIR
      指定配置目录。
      默认值：脚本所在目录。

      该目录下可能读取或写入的文件：
      • tproxy.conf          （可选）用户配置覆盖
      • runtime_tproxy.conf  （运行时生成/使用，用于清理）
      • cn.zone              （中国大陆 IPv4 CIDR 列表，缺失或过期时自动下载）
      • cn_ipv6.zone         （中国大陆 IPv6 CIDR 列表，启用 IPv6 时自动下载）
      • tmp/                 （用于 mktemp 文件、下载等的临时子目录）

      要求：
      - 该目录必须存在且对脚本可写（通常为 root）。
      - 若使用自定义路径（如 /data/adb/modules/xxx），请确保 root 有
        读/写/执行权限，且该路径在重启后持久存在，以便下载的列表和运行
        时配置得以保留。

  --dry-run
      模拟所有操作，不实际修改：
      • iptables / ip6tables 规则
      • ip 规则 / 路由
      • ipset 集合
      • sysctl 设置（/proc/sys/...）
      • 文件系统写入（下载、临时文件、运行时配置）
      适合预览将要执行的更改。

  --verbose
      增加日志详细程度：
      • 与 --dry-run 配合：显示所有日志级别（Info、Warn、Error、Debug、[EXEC]）
      • 不使用 --dry-run 时：显示正常输出 + Debug 级别消息
      • 不使用此标志时：仅显示 Info、Warn、Error（安静模式）

  -h, --help
      显示此帮助信息并退出

示例：
  $script_name start --dry-run
      # 预览更改而不实际应用

  $script_name start --dry-run --verbose
      # 非常详细的模拟（显示将运行的每个命令）

  $script_name start -d /data/adb/myproxy
      # 使用自定义配置目录

  $script_name restart --verbose
      # 以额外调试输出重启

  $script_name stop -d /sdcard/myproxy
      # 使用指定配置目录停止

注意：
  • 几乎所有操作都需要 root 权限。
  • 某些功能（TPROXY、ipset、owner 匹配等）取决于内核支持。
EOF
}

parse_args() {
    MAIN_CMD=""
    VERBOSE=0
    while [ $# -gt 0 ]; do
        case "$1" in
            start | stop | restart)
                if [ -n "$MAIN_CMD" ]; then
                    log Error "指定了多个命令。"
                    exit 1
                fi
                MAIN_CMD="$1"
                ;;
            --dry-run)
                DRY_RUN=1
                ;;
            --verbose)
                VERBOSE=1
                ;;
            -v | --version)
                echo "$SCRIPT_VERSION"
                exit 0
                ;;
            -d | --dir)
                shift
                if [ $# -eq 0 ] || [ -z "$1" ]; then
                    log Error "选项 -d/--dir 需要一个目录参数"
                    show_usage
                    exit 1
                fi
                if [ ! -d "$1" ]; then
                    log Error "目录不存在或不是一个目录：$1"
                    show_usage
                    exit 1
                fi
                CONFIG_DIR="$(cd "$1" 2> /dev/null && pwd -P)" || {
                    log Error "无法解析目录的绝对路径：$1"
                    exit 1
                }
                ;;
            -h | --help)
                show_usage
                exit 0
                ;;
            *)
                log Error "无效的参数：$1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
    if [ -z "$MAIN_CMD" ]; then
        log Error "未指定命令"
        show_usage
        exit 1
    fi
}

main() {
    local script_name
    script_name=$(basename "$0")
    log Debug "正在启动 ${script_name} ${SCRIPT_VERSION}"

    load_config

    if [ "$DRY_RUN" -eq 1 ]; then
        if [ "$VERBOSE" -eq 1 ]; then
            log Info "模拟运行模式 + 详细模式：显示所有日志"
        else
            log Info "模拟运行模式：仅显示将要执行的命令"
        fi
    elif [ "$VERBOSE" -eq 1 ]; then
        log Info "详细模式：显示调试信息"
    fi

    if ! validate_config; then
        log Error "配置验证失败"
        exit 1
    fi

    check_root
    check_dependencies
    setup_busybox

    init_tmpdir
    init_kernel_config_cache
    init_feature_flags

    detect_proxy_mode

    case "$MAIN_CMD" in
        start)
            call_func pre_start_hook
            start_proxy
            ;;
        stop)
            stop_proxy
            call_func post_stop_hook
            ;;
        restart)
            log Info "正在重启代理..."
            stop_proxy
            call_func post_stop_hook
            sleep 2
            call_func pre_start_hook
            start_proxy
            log Info "代理已重启"
            ;;
        *)
            log Error "无效的命令：$MAIN_CMD"
            show_usage
            exit 1
            ;;
    esac
}

# 预初始化变量，确保 set -u 安全
DRY_RUN=0
VERBOSE=0
CONFIG_DIR=""
USE_TPROXY=0
HAS_TPROXY=0
HAS_CONNTRACK=0
HAS_OWNER=0
HAS_MARK_MT=0
HAS_MARK_TG=0
HAS_SOCKET=0
HAS_ADDRTYPE=0
HAS_MAC=0
HAS_IPSET=0
HAS_XT_SET=0
HAS_NAT6=0
HAS_REDIRECT6=0

parse_args "$@"

main
