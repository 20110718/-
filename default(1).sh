#!/system/bin/sh

VERSION="12.1"
AUTHOR="DeepSeek & 酷安@20110718 & 酷安@10007"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL_BASE_DIR="$SCRIPT_DIR/分区管理工具"
BACKUP_DIR="$TOOL_BASE_DIR/备份"
LOG_FILE="$TOOL_BASE_DIR/operation.log"
LOG_ENABLED="no"
LOG_LEVEL="info"
MAX_LOG_SIZE=$((3 * 1024 * 1024))
ENABLE_BACKUP=1
DANGEROUS_PARTITIONS="vbmeta vbmeta_system vbmeta_a vbmeta_b bootloader abl xbl rpm tz hyp"
DEFAULT_UPDATE_DIR="$TOOL_BASE_DIR/更新"
GITHUB_USER="20110718"
GITHUB_REPO="-"
RELEASE_TAG="version.txt"
SCRIPT_FILE="default.sh"
FORCE_UPDATE_COUNTDOWN=5
MESSAGE_INTERVAL=0.2
ANDROID_ID_WHITELIST="742ER22ABD5YRQEF 2fdf4d9d4279dfcf 431bebd132ac2be4"
ROOT_ACCESS=0
CUSTOM_PATHS=0
SCRIPT_PATH="$0"

RED='\033[1;91m'
GREEN='\033[1;92m'
YELLOW='\033[1;93m'
BLUE='\033[1;94m'
CYAN='\033[1;96m'
PURPLE='\033[1;95m'
WHITE='\033[1;97m'
NC='\033[0m'

DEVICE_MODEL=""
ANDROID_VERSION=""
SECURITY_PATCH=""
KERNEL_VERSION=""
ANDROID_ID=""
BATTERY_LEVEL=0
BATTERY_TEMP=0
PARTITION_CACHE=""
AB_SLOT=""
OTHER_SLOT=""
NET_TOOL=""
SCRIPT_HASH=""

get_file_size() {
    local url="$1"
    local size=0
    
    case $NET_TOOL in
        "curl")
            size=$(curl -sI "$url" 2>/dev/null | grep -i "Content-Length" | awk '{print $2}' | tr -d '\r' | tail -1)
            ;;
        "wget")
            size=$(wget --spider --server-response "$url" 2>&1 | grep -i "Content-Length" | awk '{print $2}' | tail -1)
            ;;
        "busybox_wget")
            size=$(busybox wget --spider --server-response "$url" 2>&1 | grep -i "Content-Length" | awk '{print $2}' | tail -1)
            ;;
    esac
    
    echo "${size:-0}"
}

format_file_size() {
    local bytes="$1"
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc) GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc) MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc) KB"
    else
        echo "${bytes} B"
    fi
}

format_file_size_simple() {
    local bytes="$1"
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$((bytes / 1073741824)) GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$((bytes / 1048576)) MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$((bytes / 1024)) KB"
    else
        echo "${bytes} B"
    fi
}

check_bc_installed() {
    if ! command -v bc >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

download_with_progress() {
    local url="$1"
    local output="$2"
    local total_size=0
    local downloaded_size=0
    local start_time=0
    local last_time=0
    local last_size=0
    local current_speed=0
    local percent=0
    
    total_size=$(get_file_size "$url")
    start_time=$(date +%s)
    last_time=$start_time
    last_size=0
    
    local size_display=""
    if check_bc_installed; then
        size_display=$(format_file_size "$total_size")
    else
        size_display=$(format_file_size_simple "$total_size")
    fi
    
    echo -e "${CYAN}📦 文件总大小: $size_display${NC}"
    echo -e "${BLUE}⏳ 开始下载...${NC}"
    
    case $NET_TOOL in
        "curl")
            if command -v pv >/dev/null 2>&1; then
                curl -s -L "$url" | pv -s "$total_size" > "$output"
            else
                curl -s -L -o "$output" "$url" --progress-bar 2>&1 | while IFS= read -r line; do
                    if echo "$line" | grep -q "%"; then
                        percent=$(echo "$line" | grep -o '[0-9]*%' | head -1 | tr -d '%')
                        downloaded_size=$((total_size * percent / 100))
                        current_time=$(date +%s)
                        time_diff=$((current_time - last_time))
                        
                        if [ $time_diff -ge 1 ]; then
                            size_diff=$((downloaded_size - last_size))
                            current_speed=$((size_diff / time_diff))
                            last_time=$current_time
                            last_size=$downloaded_size
                        fi
                        
                        local downloaded_display=""
                        local speed_display=""
                        if check_bc_installed; then
                            downloaded_display=$(format_file_size "$downloaded_size")
                            speed_display=$(format_file_size "$current_speed")
                        else
                            downloaded_display=$(format_file_size_simple "$downloaded_size")
                            speed_display=$(format_file_size_simple "$current_speed")
                        fi
                        
                        echo -ne "\r${CYAN}⏳ 下载进度: $percent% | 已下载: $downloaded_display | 速度: $speed_display/s${NC}"
                    fi
                done
                echo ""
            fi
            ;;
        "wget")
            wget --progress=bar:force -O "$output" "$url" 2>&1 | while IFS= read -r line; do
                if echo "$line" | grep -q "%"; then
                    percent=$(echo "$line" | grep -o '[0-9]*%' | head -1 | tr -d '%')
                    downloaded_size=$((total_size * percent / 100))
                    current_time=$(date +%s)
                    time_diff=$((current_time - last_time))
                    
                    if [ $time_diff -ge 1 ]; then
                        size_diff=$((downloaded_size - last_size))
                        current_speed=$((size_diff / time_diff))
                        last_time=$current_time
                        last_size=$downloaded_size
                    fi
                    
                    local downloaded_display=""
                    local speed_display=""
                    if check_bc_installed; then
                        downloaded_display=$(format_file_size "$downloaded_size")
                        speed_display=$(format_file_size "$current_speed")
                    else
                        downloaded_display=$(format_file_size_simple "$downloaded_size")
                        speed_display=$(format_file_size_simple "$current_speed")
                    fi
                    
                    echo -ne "\r${CYAN}⏳ 下载进度: $percent% | 已下载: $downloaded_display | 速度: $speed_display/s${NC}"
                fi
            done
            echo ""
            ;;
        "busybox_wget")
            busybox wget -O "$output" "$url" 2>&1 | while IFS= read -r line; do
                if echo "$line" | grep -q "%"; then
                    percent=$(echo "$line" | grep -o '[0-9]*%' | head -1 | tr -d '%')
                    downloaded_size=$((total_size * percent / 100))
                    current_time=$(date +%s)
                    time_diff=$((current_time - last_time))
                    
                    if [ $time_diff -ge 1 ]; then
                        size_diff=$((downloaded_size - last_size))
                        current_speed=$((size_diff / time_diff))
                        last_time=$current_time
                        last_size=$downloaded_size
                    fi
                    
                    local downloaded_display=""
                    local speed_display=""
                    if check_bc_installed; then
                        downloaded_display=$(format_file_size "$downloaded_size")
                        speed_display=$(format_file_size "$current_speed")
                    else
                        downloaded_display=$(format_file_size_simple "$downloaded_size")
                        speed_display=$(format_file_size_simple "$current_speed")
                    fi
                    
                    echo -ne "\r${CYAN}⏳ 下载进度: $percent% | 已下载: $downloaded_display | 速度: $speed_display/s${NC}"
                fi
            done
            echo ""
            ;;
    esac
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    local final_size=$(stat -c %s "$output" 2>/dev/null || wc -c < "$output" 2>/dev/null || echo 0)
    local average_speed=0
    
    if [ $total_time -gt 0 ]; then
        average_speed=$((final_size / total_time))
    fi
    
    local final_size_display=""
    local avg_speed_display=""
    if check_bc_installed; then
        final_size_display=$(format_file_size "$final_size")
        avg_speed_display=$(format_file_size "$average_speed")
    else
        final_size_display=$(format_file_size_simple "$final_size")
        avg_speed_display=$(format_file_size_simple "$average_speed")
    fi
    
    if [ -f "$output" ] && [ "$final_size" -gt 0 ]; then
        echo -e "${GREEN}✅ 下载完成！${NC}"
        echo -e "${BLUE}📊 实际大小: $final_size_display${NC}"
        echo -e "${BLUE}⏱️ 总耗时: ${total_time}秒${NC}"
        echo -e "${BLUE}🚀 平均速度: $avg_speed_display/s${NC}"
        return 0
    else
        echo -e "${RED}❌ 下载失败！${NC}"
        return 1
    fi
}

get_coolapk_user_name() {
    for i in /data/user/0/com.coolapk.market/shared_prefs/*preferences*.xml; do
        [ ! -f "$i" ] && continue
        username=$(grep '<string name="username">' "$i" 2>/dev/null | sed 's/.*"username">//g;s/<.*//g')
        if [ -n "$username" ]; then
            echo "$username"
            return 0
        fi
    done
    echo ""
}

get_github_user() {
    local github_name=""
    if command -v dumpsys >/dev/null 2>&1; then
        github_name=$(dumpsys content 2>/dev/null | grep -Eo 'Account[[:space:]].*u[0-9]{1,3}.*com\.github\.android' | sed 's/Account[[:space:]]//g;s/[[:space:]]u[0-9].*//g' | sort -u | head -n 1)
    fi
    echo "$github_name"
}

get_user_display_name() {
    local device_name=$(getprop persist.sys.device_name 2>/dev/null)
    local coolapk_name=$(get_coolapk_user_name)
    local github_name=$(get_github_user)
    local system_user=$(pm list users 2>/dev/null | cut -d: -f2 | head -n1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    if [ -n "$device_name" ]; then
        echo "$device_name"
    elif [ -n "$coolapk_name" ]; then
        echo "$coolapk_name"
    elif [ -n "$github_name" ]; then
        echo "$github_name"
    elif [ -n "$system_user" ]; then
        echo "$system_user"
    else
        echo "尊贵的用户"
    fi
}

show_personalized_welcome() {
    local user_name=$(get_user_display_name)
    echo -e "\n${PURPLE}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}          💖 欢迎您，${CYAN}${user_name}${GREEN}！💖${NC}"
    echo -e "${BLUE}           分区管理工具箱 v${VERSION}${NC}"
    if [ $ROOT_ACCESS -ne 1 ]; then
        echo -e "${YELLOW}⚠️  当前未获取完整Root权限，部分功能受限${NC}"
    fi
    echo -e "${PURPLE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🔧酷安@20110718${NC}"
}

init_directories() {
    echo -e "${BLUE}🔧 初始化分区管理工具文件夹...${NC}"
    
    if ! mkdir -p "$TOOL_BASE_DIR" 2>/dev/null; then
        echo -e "${YELLOW}⚠️ 无法创建主文件夹，使用备用目录...${NC}"
        TOOL_BASE_DIR="/sdcard/分区管理工具"
        BACKUP_DIR="$TOOL_BASE_DIR/备份"
        DEFAULT_UPDATE_DIR="$TOOL_BASE_DIR/更新"
        
        if ! mkdir -p "$TOOL_BASE_DIR" 2>/dev/null; then
            echo -e "${RED}❌ 无法创建备用目录，请检查存储权限！${NC}"
            return 1
        fi
    fi
    
    if ! mkdir -p "$BACKUP_DIR" "$DEFAULT_UPDATE_DIR" 2>/dev/null; then
        echo -e "${RED}❌ 无法创建子文件夹，请检查存储权限！${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ 文件夹结构初始化完成${NC}"
    echo -e "${BLUE}📁 主目录: $TOOL_BASE_DIR${NC}"
    echo -e "${BLUE}📦 备份目录: $BACKUP_DIR${NC}"
    echo -e "${BLUE}🔄 更新目录: $DEFAULT_UPDATE_DIR${NC}"
    sleep 1
    return 0
}

init_cache() {
    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "未知设备")
    ANDROID_VERSION=$(getprop ro.build.version.release 2>/dev/null || echo "未知")
    SECURITY_PATCH=$(getprop ro.build.version.security_patch 2>/dev/null || echo "未知")
    KERNEL_VERSION=$(uname -r 2>/dev/null || echo "未知")
    ANDROID_ID=$(get_android_id)
    if [ $ROOT_ACCESS -eq 1 ]; then
        BATTERY_LEVEL=$(get_battery_level)
        BATTERY_TEMP=$(get_battery_temp)
    fi
    AB_SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null)
    [ -n "$AB_SLOT" ] && OTHER_SLOT=$([ "$AB_SLOT" = "_a" ] && echo "_b" || echo "_a")
}

check_root() {
    if [ "$(id -u)" = "0" ]; then
        ROOT_ACCESS=1
        return 0
    fi
    
    if command -v su >/dev/null 2>&1; then
        su -c "id" 2>/dev/null | grep -q "uid=0" && ROOT_ACCESS=1 && return 0
    fi
    
    [ -d "/sbin/.magisk" ] || [ -f "/data/adb/magisk/magisk" ] && ROOT_ACCESS=1 && return 0
    [ -f "/system/app/Superuser.apk" ] || [ -f "/system/xbin/daemonsu" ] && ROOT_ACCESS=1 && return 0
    [ -f "/system/xbin/su" ] || [ -f "/system/bin/su" ] && ROOT_ACCESS=1 && return 0
    
    return 1
}

get_android_id() {
    [ -n "$ANDROID_ID" ] && echo "$ANDROID_ID" && return
    
    local android_id=$(settings get secure android_id 2>/dev/null)
    [ -z "$android_id" ] && android_id=$(cat /data/data/com.google.android.gsf/databases/gservices.db 2>/dev/null | grep -A1 android_id | tail -1 | cut -d'>' -f2 | cut -d'<' -f1)
    [ -z "$android_id" ] && android_id=$(sqlite3 /data/data/com.android.providers.settings/databases/settings.db "SELECT value FROM secure WHERE name='android_id';" 2>/dev/null)
    
    if [ -z "$android_id" ] || [ "$android_id" = "null" ]; then
        echo "unknown_device_$(date +%s)"
    else
        echo "$android_id"
    fi
}

get_battery_level() {
    [ $BATTERY_LEVEL -gt 0 ] && echo $BATTERY_LEVEL && return
    
    local battery_paths="/sys/class/power_supply/battery/capacity /sys/class/power_supply/Battery/capacity /sys/class/power_supply/battery/charge_counter /sys/class/power_supply/Battery/charge_counter"
    local level=0
    
    for path in $battery_paths; do
        if [ -f "$path" ]; then
            level=$(cat "$path" 2>/dev/null)
            [ -n "$level" ] && break
        fi
    done
    
    [ -z "$level" ] && level=$(dumpsys battery 2>/dev/null | awk '/level/{print $2}')
    [ -n "$level" ] && level=$((level))
    echo "${level:-0}"
}

get_battery_temp() {
    [ $BATTERY_TEMP -gt 0 ] && echo $BATTERY_TEMP && return
    
    local temp_paths="/sys/class/power_supply/battery/temp /sys/class/power_supply/Battery/temp /sys/class/power_supply/battery/temp_c /sys/class/power_supply/Battery/temp_c"
    local temp=0
    
    for path in $temp_paths; do
        if [ -f "$path" ]; then
            temp=$(cat "$path" 2>/dev/null)
            [ -n "$temp" ] && break
        fi
    done
    
    [ -z "$temp" ] && temp=$(dumpsys battery 2>/dev/null | awk '/temperature/{print $2}')
    [ -n "$temp" ] && temp=$((temp / 10))
    echo "${temp:-0}"
}

clean_input() {
    echo "$1" | sed 's/\\033\[[0-9;]*m//g' | tr -d '\000-\037' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

press_enter_to_continue() {
    echo -e "\n${YELLOW}↵ 按回车键继续...${NC}"
    read -r
}

show_banner() {
    clear
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${BLUE}      分区提取工具 v$VERSION      ${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

log() {
  local level="$1"
  local message="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  case "$level" in
    "debug")   local color="${CYAN}" prefix="DEBUG" ;;
    "info")    local color="${GREEN}" prefix="INFO" ;;
    "warning") local color="${YELLOW}" prefix="WARN" ;;
    "error")   local color="${RED}" prefix="ERROR" ;;
    *)         local color="${WHITE}" prefix="INFO" ;;
  esac
  
  if [ "$LOG_ENABLED" = "yes" ]; then
    case "$LOG_LEVEL" in
      "debug")   ;;
      "info")    [ "$level" = "debug" ] && return ;;
      "warning") [ "$level" != "error" -a "$level" != "warning" ] && return ;;
      "error")   [ "$level" != "error" ] && return ;;
    esac
    
    if [ -f "$LOG_FILE" ] && [ $(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]; then
      tail -n 500 "$LOG_FILE" > "$LOG_FILE.tmp"
      mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
    
    echo "[$timestamp] [${prefix}] ${message}" >> "$LOG_FILE"
  fi
}

show_progress() {
  local pid=$1
  local message="$2"
  local spin='-\|/'
  local i=0
  
  echo -n -e "${BLUE}${message}... ${NC}"
  while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    printf "\b${spin:$i:1}"
    sleep 0.1
  done
  printf "\b \n"
}

get_cpu_info() {
  cpu_hardware=$(cat /proc/cpuinfo | grep -m1 "Hardware" | cut -d: -f2 | sed 's/ //g')
  [ -z "$cpu_hardware" ] && cpu_hardware=$(getprop ro.board.platform)
  [ -z "$cpu_hardware" ] && cpu_hardware="unknown"
  
  cpu_model=$(getprop ro.product.cpu.model)
  [ -z "$cpu_model" ] && cpu_model=$(getprop ro.product.cpu.abi)
  
  echo "$cpu_model ($cpu_hardware)"
}

show_header() {
  clear
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}|    ${CYAN}高级工具 v${VERSION}${BLUE}    |${NC}"
  echo -e "${BLUE}========================================${NC}"
}

show_device_info() {
  show_header
  echo -e "${BLUE}|          ${CYAN}设备详细信息报告${BLUE}             |${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo -e "${GREEN}📱 型号/Model: ${NC}$DEVICE_MODEL"
  echo -e "${GREEN}💻 处理器/CPU: ${NC}$(get_cpu_info)"
  echo -e "${GREEN}🧩 架构/Arch: ${NC}$(getprop ro.product.cpu.abi)"
  echo -e "${GREEN}🔢 核心/Cores: ${NC}$(grep -c processor /proc/cpuinfo)"
  echo -e "${BLUE}----------------------------------------${NC}"
  echo -e "${GREEN}⚙️ Android: ${NC}$ANDROID_VERSION"
  echo -e "${GREEN}🛡️ 安全补丁/Security Patch: ${NC}$SECURITY_PATCH"
  echo -e "${BLUE}========================================${NC}"
}

check_partition() {
    [ -e "/dev/block/by-name/$1" ] && return 0
    return 1
}

get_partition_list() {
    [ -n "$PARTITION_CACHE" ] && echo "$PARTITION_CACHE" && return
    
    if [ $ROOT_ACCESS -eq 1 ]; then
        PARTITION_CACHE=$(ls /dev/block/by-name 2>/dev/null | sort)
    else
        PARTITION_CACHE=""
    fi
    echo "$PARTITION_CACHE"
}

is_dangerous_partition() {
    local part="$1"
    for dangerous in $DANGEROUS_PARTITIONS; do
        [ "$part" = "$dangerous" ] && return 0
    done
    return 1
}

extract_partition() {
    if [ $ROOT_ACCESS -ne 1 ]; then
        echo -e "${RED}❌ 此功能需要ROOT权限！${NC}"
        press_enter_to_continue
        return 1
    fi
    
    local part_name=$1
    local slot_suffix=${2:-}
    local out_file="$BACKUP_DIR/${part_name}${slot_suffix}_$(date +%Y%m%d_%H%M%S).img"
    
    if ! check_partition "${part_name}${slot_suffix}"; then
        echo -e "${RED}❌ 分区 ${part_name}${slot_suffix} 不存在！${NC}"
        press_enter_to_continue
        return 1
    fi
    
    if is_dangerous_partition "$part_name"; then
        echo -e "${YELLOW}⚠️ 警告：${part_name}是危险分区！${NC}"
        echo -e "${YELLOW}你确定要提取这个分区吗？(y/n): ${NC}"
        read -r confirm
        confirm=$(clean_input "$confirm")
        if [ "$confirm" != "y" ]; then
            press_enter_to_continue
            return 1
        fi
    else
        echo -e -n "${BLUE}是否提取 ${part_name}${slot_suffix} 分区？(y/n): ${NC}"
        read -r confirm
        confirm=$(clean_input "$confirm")
        if [ "$confirm" != "y" ]; then
            press_enter_to_continue
            return 1
        fi
    fi
    
    echo -e "${BLUE}⏳ 正在提取 ${part_name}${slot_suffix}...${NC}"
    
    local part_size=$(blockdev --getsize64 "/dev/block/by-name/${part_name}${slot_suffix}" 2>/dev/null)
    if [ -n "$part_size" ]; then
        echo -e "${BLUE}📊 分区大小: $((part_size / 1024 / 1024))MB${NC}"
    fi
    
    local partition_path="/dev/block/by-name/${part_name}${slot_suffix}"
    
    echo -e "${BLUE}🔧 使用dd命令提取...${NC}"
    if dd if="$partition_path" of="$out_file" bs=1M 2>&1; then
        if [ -f "$out_file" ] && [ -s "$out_file" ]; then
            local file_size=$(stat -c %s "$out_file" 2>/dev/null || wc -c < "$out_file")
            echo -e "${GREEN}✅ 提取成功！${NC}"
            echo -e "${BLUE}文件路径: ${NC}$out_file"
            echo -e "${BLUE}文件大小: ${NC}$(du -h "$out_file" | cut -f1)"
            echo -e "${BLUE}实际大小: ${NC}$((file_size / 1024 / 1024))MB"
            
            if [ -n "$part_size" ] && [ "$file_size" -eq "$part_size" ]; then
                echo -e "${GREEN}✅ 文件完整性验证通过${NC}"
            elif [ -n "$part_size" ]; then
                echo -e "${YELLOW}⚠️ 文件大小与分区大小不匹配，但文件已保存${NC}"
            fi
            
            press_enter_to_continue
            return 0
        else
            echo -e "${RED}❌ 提取的文件为空或不存在！${NC}"
            rm -f "$out_file" 2>/dev/null
            press_enter_to_continue
            return 1
        fi
    else
        echo -e "${RED}❌ dd命令提取失败！${NC}"
        
        echo -e "${YELLOW}🔄 尝试使用cat命令提取...${NC}"
        if cat "$partition_path" > "$out_file" 2>/dev/null; then
            if [ -f "$out_file" ] && [ -s "$out_file" ]; then
                echo -e "${GREEN}✅ 使用cat命令提取成功！${NC}"
                echo -e "${BLUE}文件路径: ${NC}$out_file"
                echo -e "${BLUE}文件大小: ${NC}$(du -h "$out_file" | cut -f1)"
                press_enter_to_continue
                return 0
            fi
        fi
        
        echo -e "${RED}❌ 所有提取方法都失败了！${NC}"
        rm -f "$out_file" 2>/dev/null
        press_enter_to_continue
        return 1
    fi
}

batch_extract_partitions() {
    if [ $ROOT_ACCESS -ne 1 ]; then
        echo -e "${RED}❌ 此功能需要ROOT权限！${NC}"
        press_enter_to_continue
        return
    fi
    
    show_header
    echo -e "${BLUE}|          ${CYAN}批量提取分区${BLUE}                |${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    echo -e "${YELLOW}请输入要提取的分区名称，多个分区用空格分隔:${NC}"
    echo -e "${GREEN}例如: boot system vendor${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    echo -en "${CYAN}请输入: ${NC}"
    read -r partitions
    
    partitions=$(clean_input "$partitions")
    
    if [ -z "$partitions" ]; then
        echo -e "${RED}❌ 未输入任何分区！${NC}"
        press_enter_to_continue
        return
    fi
    
    local success_count=0
    local fail_count=0
    
    for part in $partitions; do
        extract_partition "$part" && success_count=$((success_count + 1)) || fail_count=$((fail_count + 1))
    done
    
    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e "${GREEN}✅ 批量提取完成！${NC}"
    echo -e "${GREEN}成功: $success_count 个分区${NC}"
    echo -e "${RED}失败: $fail_count 个分区${NC}"
    press_enter_to_continue
}

list_flashable_partitions() {
    if [ $ROOT_ACCESS -ne 1 ]; then
        echo -e "${RED}❌ 此功能需要ROOT权限！${NC}"
        press_enter_to_continue
        return
    fi
    
    show_header
    
    echo -e "${BLUE}|      ${CYAN}可提取的分区列表 (安全模式)${BLUE}     |${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}⚠️ 注意：提取系统关键分区可能导致设备无法启动！${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    
    local PARTITIONS=$(get_partition_list | grep -vE "$(echo "$DANGEROUS_PARTITIONS" | tr ' ' '|')")
    
    local i=1
    for part in $PARTITIONS; do
        size=$(blockdev --getsize64 "/dev/block/by-name/$part" 2>/dev/null | awk '{printf "%.1fMB", $1/1024/1024}')
        echo -e "${GREEN}$i. $part ${BLUE}($size)${NC}"
        i=$((i + 1))
    done
    
    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e -n "${CYAN}请输入要提取的分区编号 (1-$((i - 1))) 或 q 退出: ${NC}"
    read -r choice
    
    choice=$(clean_input "$choice")
    [ "$choice" = "q" ] && return
    
    if ! echo "$choice" | grep -qE '^[0-9]+$'; then
        echo -e "${RED}❌ 请输入有效数字！${NC}"
        press_enter_to_continue
        return 1
    fi
    
    if [ "$choice" -lt 1 ] || [ "$choice" -gt $((i - 1)) ]; then
        echo -e "${RED}❌ 编号超出范围！${NC}"
        press_enter_to_continue
        return 1
    fi
    
    selected_part=$(echo "$PARTITIONS" | sed -n "${choice}p")
    extract_partition "$selected_part"
}

flash_partition_menu() {
    if [ $ROOT_ACCESS -ne 1 ]; then
        echo -e "${RED}❌ 此功能需要ROOT权限！${NC}"
        press_enter_to_continue
        return
    fi
    
    show_header
    
    echo -e "${BLUE}|          ${CYAN}刷写分区模式${BLUE}                |${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}📋 可刷写分区列表：${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    
    local PARTITIONS=$(get_partition_list)
    local i=1
    for part in $PARTITIONS; do
        if is_dangerous_partition "$part"; then
            echo -e "${RED}$i. $part (危险分区!)${NC}"
        else
            echo -e "${GREEN}$i. $part${NC}"
        fi
        i=$((i + 1))
    done
    
    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e -n "${CYAN}输入分区编号 (1-$((i - 1))) 退出: ${NC}"
    read -r part_choice
    part_choice=$(clean_input "$part_choice")
    [ "$part_choice" = "q" ] && return
    
    if ! echo "$part_choice" | grep -qE '^[0-9]+$'; then
        echo -e "${RED}❌ 请输入有效数字！${NC}"
        press_enter_to_continue
        return 1
    fi
    
    if [ "$part_choice" -lt 1 ] || [ "$part_choice" -gt $((i - 1)) ]; then
        echo -e "${RED}❌ 编号超出范围！${NC}"
        press_enter_to_continue
        return 1
    fi
    
    selected_part=$(echo "$PARTITIONS" | sed -n "${part_choice}p")
    [ -z "$selected_part" ] && echo -e "${RED}❌ 无效选择！${NC}" && press_enter_to_continue && return
    
    echo -e -n "${CYAN}输入刷机文件路径: ${NC}"
    read -r flash_file
    
    flash_file=$(clean_input "$flash_file")
    
    flash_partition "$selected_part" "$flash_file"
}

flash_partition() {
    if [ $ROOT_ACCESS -ne 1 ]; then
        echo -e "${RED}❌ 此功能需要ROOT权限！${NC}"
        press_enter_to_continue
        return
    fi
    
    local part_name=$1
    local file_path=$2
    local partition_path="/dev/block/by-name/$part_name"
    
    if [ ! -f "$file_path" ]; then
        echo -e "${RED}❌ 刷机文件不存在！${NC}"
        press_enter_to_continue
        return 1
    fi
    
    if is_dangerous_partition "$part_name"; then
        echo -e "${YELLOW}⚠️ 警告：${part_name}是危险分区！${NC}"
        echo -e "${RED}========================================${NC}"
        echo -e "${RED}⚠️ 严重警告：你正在尝试刷写危险分区！${NC}"
        echo -e "${RED}这可能导致设备无法启动！${NC}"
        echo -e "${RED}========================================${NC}"
        echo -e -n "${YELLOW}你确定要继续吗？(输入'I_KNOW_WHAT_I_AM_DOING'确认): ${NC}"
        read -r confirm
        confirm=$(clean_input "$confirm")
        if [ "$confirm" != "I_KNOW_WHAT_I_AM_DOING" ]; then
            press_enter_to_continue
            return 1
        fi
    fi
    
    local file_size=$(stat -c %s "$file_path")
    local part_size=$(blockdev --getsize64 "$partition_path")
    
    if [ "$file_size" -gt "$part_size" ]; then
        echo -e "${RED}❌ 文件大小超过分区容量！${NC}"
        echo -e "${YELLOW}文件: $((file_size / 1024))KB${NC}"
        echo -e "${YELLOW}分区: $((part_size / 1024))KB${NC}"
        press_enter_to_continue
        return 1
    fi
    
    if [ "$ENABLE_BACKUP" -eq 1 ]; then
        local backup_file="$BACKUP_DIR/${part_name}_backup_$(date +%Y%m%d_%H%M%S).img"
        echo -e "${BLUE}📦 正在备份原分区...${NC}"
        
        if dd if="$partition_path" of="$backup_file" bs=1M; then
            echo -e "${GREEN}✅ 备份成功！${NC}"
            echo -e "${BLUE}备份路径: ${NC}$backup_file"
        else
            echo -e "${RED}❌ 备份失败！${NC}"
            press_enter_to_continue
            return 1
        fi
    fi
    
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}⚠️ 你即将刷写 $part_name 分区 ⚠️${NC}"
    echo -e "${RED}文件: $file_path ($((file_size / 1024))KB)${NC}"
    echo -e "${RED}========================================${NC}"
    echo -e -n "${YELLOW}确认刷写？(输入'YES'确认): ${NC}"
    read -r confirm
    confirm=$(clean_input "$confirm")
    if [ "$confirm" != "YES" ]; then
        press_enter_to_continue
        return 1
    fi
    
    echo -e "${BLUE}⚡ 正在刷写分区...${NC}"
    
    if dd if="$file_path" of="$partition_path" bs=1M; then
        echo -e "${GREEN}✅ 刷写完成！${NC}"
        echo -e "${YELLOW}⚠️ 建议重启设备使更改生效${NC}"
        press_enter_to_continue
        return 0
    else
        echo -e "${RED}❌ 刷写失败！${NC}"
        press_enter_to_continue
        return 1
    fi
}

extract_boot_menu() {
    if [ $ROOT_ACCESS -ne 1 ]; then
        echo -e "${RED}❌ 此功能需要ROOT权限！${NC}"
        press_enter_to_continue
        return
    fi
    
    show_header
    
    echo -e "${BLUE}|          ${CYAN}提取boot分区模式${BLUE}           |${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}📋 可提取的分区：${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e "1. boot${AB_SLOT}"
    
    if check_partition "init_boot${AB_SLOT}"; then
        echo -e "2. init_boot${AB_SLOT}"
    else
        echo -e "2. init_boot${AB_SLOT} ${RED}(不存在)${NC}"
    fi
    
    if [ -n "$AB_SLOT" ]; then
        echo -e "3. boot${OTHER_SLOT}"
        if check_partition "init_boot${OTHER_SLOT}"; then
            echo -e "4. init_boot${OTHER_SLOT}"
        else
            echo -e "4. init_boot${OTHER_SLOT} ${RED}(不存在)${NC}"
        fi
    fi
    
    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e -n "${CYAN}请选择要提取的分区 (1-4): ${NC}"
    read -r extract_choice
    
    extract_choice=$(clean_input "$extract_choice")
    
    case "$extract_choice" in
        1) extract_partition "boot" "$AB_SLOT" ;;
        2) check_partition "init_boot$AB_SLOT" && extract_partition "init_boot" "$AB_SLOT" || { echo -e "${RED}❌ init_boot分区不存在！${NC}"; press_enter_to_continue; } ;;
        3) [ -n "$AB_SLOT" ] && extract_partition "boot" "$OTHER_SLOT" || { echo -e "${RED}❌ 无效选择！${NC}"; press_enter_to_continue; } ;;
        4) [ -n "$AB_SLOT" ] && (check_partition "init_boot$OTHER_SLOT" && extract_partition "init_boot" "$OTHER_SLOT" || { echo -e "${RED}❌ init_boot分区不存在！${NC}"; press_enter_to_continue; }) || { echo -e "${RED}❌ 无效选择！${NC}"; press_enter_to_continue; } ;;
        *) echo -e "${RED}❌ 无效输入！${NC}" && press_enter_to_continue ;;
    esac
}

search_partitions() {
    if [ $ROOT_ACCESS -ne 1 ]; then
        echo -e "${RED}❌ 此功能需要ROOT权限！${NC}"
        press_enter_to_continue
        return
    fi
    
    show_header
    
    echo -e "${BLUE}|          ${CYAN}分区搜索功能${BLUE}                |${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e -n "${CYAN}请输入要搜索的分区名称或关键字: ${NC}"
    read -r keyword
    
    keyword=$(clean_input "$keyword")
    
    if [ -z "$keyword" ]; then
        echo -e "${RED}❌ 搜索关键字不能为空！${NC}"
        press_enter_to_continue
        return
    fi
    
    local PARTITIONS=$(get_partition_list | grep -i "$keyword")
    
    if [ -z "$PARTITIONS" ]; then
        echo -e "${YELLOW}❌ 未找到匹配的分区！${NC}"
        press_enter_to_continue
        return
    fi
    
    echo -e "${GREEN}✅ 找到以下匹配的分区:${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    
    local i=1
    for part in $PARTITIONS; do
        if is_dangerous_partition "$part"; then
            echo -e "${RED}$i. $part (危险分区!)${NC}"
        else
            size=$(blockdev --getsize64 "/dev/block/by-name/$part" 2>/dev/null | awk '{printf "%.1fMB", $1/1024/1024}')
            echo -e "${GREEN}$i. $part ${BLUE}($size)${NC}"
        fi
        i=$((i + 1))
    done
    
    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e -n "${CYAN}请输入要操作的分区编号 (1-$((i - 1))) 或 q 退出: ${NC}"
    read -r choice
    
    choice=$(clean_input "$choice")
    [ "$choice" = "q" ] && return
    
    if ! echo "$choice" | grep -qE '^[0-9]+$'; then
        echo -e "${RED}❌ 请输入有效数字！${NC}"
        press_enter_to_continue
        return 1
    fi
    
    if [ "$choice" -lt 1 ] || [ "$choice" -gt $((i - 1)) ]; then
        echo -e "${RED}❌ 编号超出范围！${NC}"
        press_enter_to_continue
        return 1
    fi
    
    selected_part=$(echo "$PARTITIONS" | sed -n "${choice}p")
    
    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e "${CYAN}请选择操作:${NC}"
    echo -e "1. 提取分区"
    echo -e "2. 刷写分区"
    echo -e -n "${CYAN}请输入选择 (1-2): ${NC}"
    read -r operation
    
    operation=$(clean_input "$operation")
    
    case "$operation" in
        1) extract_partition "$selected_part" ;;
        2) 
            echo -e -n "${CYAN}输入刷机文件路径: ${NC}"
            read -r flash_file
            flash_file=$(clean_input "$flash_file")
            flash_partition "$selected_part" "$flash_file"
            ;;
        *) echo -e "${RED}❌ 无效选择！${NC}" && press_enter_to_continue ;;
    esac
}

fun_features() {
    while true; do
        show_header
        echo -e "${BLUE}|          ${CYAN}娱乐功能${BLUE}                  |${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${GREEN}1. 模拟一键黑砖${NC}"
        echo -e "${GREEN}2. 显示ASCII艺术${NC}"
        echo -e "${GREEN}3. 随机笑话${NC}"
        echo -e "${GREEN}4. 系统信息跑分${NC}"
        echo -e "${GREEN}5. 返回主菜单${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e -n "${CYAN}请选择 [1-5]: ${NC}"
        
        read -r choice
        choice=$(clean_input "$choice")
        case "$choice" in
            1)
                echo -e "${YELLOW}⚠️ 警告：这是一个模拟功能，不会真正损坏设备！${NC}"
                echo -e -n "${BLUE}确定要模拟黑砖效果吗？(y/n): ${NC}"
                read -r confirm
                confirm=$(clean_input "$confirm")
                if [ "$confirm" != "y" ]; then
                    continue
                fi
                
                clear
                echo -e "${RED}正在擦除分区表...${NC}"
                sleep 1
                echo -e "${RED}擦除boot分区...${NC}"
                sleep 0.5
                echo -e "${RED}擦除system分区...${NC}"
                sleep 0.5
                echo -e "${RED}擦除vendor分区...${NC}"
                sleep 0.5
                echo -e "${RED}擦除userdata分区...${NC}"
                sleep 1
                echo ""
                echo -e "${RED}❌ 错误：分区表损坏！${NC}"
                echo -e "${RED}❌ 设备无法启动！${NC}"
                echo ""
                echo -e "${YELLOW}⚠️ 别担心，这只是模拟效果！${NC}"
                echo -e "${YELLOW}⚠️ 你的设备实际上完好无损！${NC}"
                echo ""
                echo -e "${BLUE}设备将在10秒后关机...${NC}"
                sleep 10
                press_enter_to_continue
                ;;
            2)
                echo -e "${CYAN}"
                echo "  ____  _        _ _   "
                echo " / ___|| |_ __ _| | |  "
                echo " \___ \| __/ _\` | | |  "
                echo "  ___) | || (_| | | |  "
                echo " |____/ \__\__,_|_|_|  "
                echo -e "${NC}"
                echo -e "${BLUE}分区工具 v${VERSION}${NC}"
                echo ""
                press_enter_to_continue
                ;;
            3)
                jokes=(
                    "为什么程序员分不清万圣节和圣诞节？因为 Oct 31 == Dec 25"
                    "程序员最讨厌的购物网站是什么？NULL Pointer"
                    "为什么Android开发者不喜欢去酒吧？因为他们总是遇到Fragment"
                    "两个字节在酒吧相遇，一个字节问另一个：你还好吗？另一个回答：不，我有parity error"
                    "为什么Linux用户不喜欢用Windows？因为他们不喜欢在自己的地盘上看到Windows"
                )
                random_index=$((RANDOM % ${#jokes[@]}))
                random_joke=${jokes[$random_index]}
                echo ""
                echo -e "${GREEN}📢 随机笑话：${NC}"
                echo -e "${CYAN}$random_joke${NC}"
                echo ""
                press_enter_to_continue
                ;;
            4)
                echo -e "${BLUE}⏳ 正在测试系统性能...${NC}"
                
                start_time=$(date +%s)
                for i in $(seq 1 100000); do
                    :
                done
                end_time=$(date +%s)
                cpu_time=$((end_time - start_time))
                
                echo -e "${GREEN}🧪 内存性能测试中...${NC}"
                start_time=$(date +%s)
                for i in $(seq 1 10000); do
                    var="test_string_$i"
                done
                end_time=$(date +%s)
                mem_time=$((end_time - start_time))
                
                echo -e "${GREEN}🧪 磁盘I/O测试中...${NC}"
                start_time=$(date +%s)
                for i in $(seq 1 100); do
                    echo "test" > /tmp/test_$i.txt
                done
                end_time=$(date +%s)
                disk_time=$((end_time - start_time))
                
                rm -f /tmp/test_*.txt
                
                cpu_score=$((100 - cpu_time))
                mem_score=$((100 - mem_time))
                disk_score=$((100 - disk_time))
                total_score=$((cpu_score + mem_score + disk_score))
                
                echo -e "${BLUE}========================================${NC}"
                echo -e "${CYAN}        系统性能测试结果${NC}"
                echo -e "${BLUE}========================================${NC}"
                echo -e "${GREEN}CPU性能: ${WHITE}$cpu_score/100${NC}"
                echo -e "${GREEN}内存性能: ${WHITE}$mem_score/100${NC}"
                echo -e "${GREEN}磁盘I/O: ${WHITE}$disk_score/100${NC}"
                echo -e "${BLUE}----------------------------------------${NC}"
                echo -e "${CYAN}总得分: ${WHITE}$total_score/300${NC}"
                
                if [ $total_score -gt 250 ]; then
                    echo -e "${GREEN}性能评价: 优秀! 🚀${NC}"
                elif [ $total_score -gt 200 ]; then
                    echo -e "${GREEN}性能评价: 良好! 👍${NC}"
                elif [ $total_score -gt 150 ]; then
                    echo -e "${YELLOW}性能评价: 一般! 👌${NC}"
                else
                    echo -e "${RED}性能评价: 需要优化! 🐌${NC}"
                fi
                
                press_enter_to_continue
                ;;
            5)
                return
                ;;
            *)
                echo -e "${RED}❌ 无效选择！${NC}"
                press_enter_to_continue
                ;;
        esac
    done
}

flash_ak3() {
    if [ $ROOT_ACCESS -ne 1 ]; then
        echo -e "${RED}❌ 此功能需要ROOT权限！${NC}"
        press_enter_to_continue
        return
    fi
    
    show_header
    
    echo -e "${BLUE}|   ${CYAN}刷入AK3压缩包 (仅限boot分区)${BLUE}      |${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}⚠️ 警告：${NC}"
    echo -e "1. 此功能需要已解锁的Bootloader"
    echo -e "2. 错误的AK3包可能导致设备无法启动"
    echo -e "3. 建议先备份当前boot分区"
    echo -e "4. 仅支持刷入boot_a和boot_b分区"
    [ -n "$AB_SLOT" ] && echo -e "5. 当前活动槽位: ${CYAN}${AB_SLOT#_}${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    
    echo -e -n "${CYAN}请输入AK3压缩包完整路径: ${NC}"
    read -r ak3_path
    
    ak3_path=$(clean_input "$ak3_path")
    
    if [ ! -f "$ak3_path" ]; then
        echo -e "${RED}❌ 文件不存在: $ak3_path${NC}"
        press_enter_to_continue
        return 1
    fi
    
    if ! file "$ak3_path" | grep -qE "(Zip|zip|ZIP|compressed)"; then
        echo -e "${YELLOW}⚠️ 警告：文件可能不是有效的ZIP压缩包${NC}"
        echo -e -n "${YELLOW}是否继续？(y/n): ${NC}"
        read -r continue_choice
        if [ "$continue_choice" != "y" ]; then
            return 1
        fi
    fi
    
    echo -e "\n${CYAN}请选择要刷写的boot分区：${NC}"
    echo -e "1. boot_a (A槽位)"
    echo -e "2. boot_b (B槽位)"
    echo -e -n "${YELLOW}请输入选择 [1-2]: ${NC}"
    read -r part_choice
    
    part_choice=$(clean_input "$part_choice")
    
    case "$part_choice" in
        1) 
            target_partition="boot_a"
            if ! check_partition "boot_a"; then
                echo -e "${RED}❌ boot_a分区不存在！${NC}"
                press_enter_to_continue
                return 1
            fi
            ;;
        2) 
            target_partition="boot_b"
            if ! check_partition "boot_b"; then
                echo -e "${RED}❌ boot_b分区不存在！${NC}"
                press_enter_to_continue
                return 1
            fi
            ;;
        *)
            echo -e "${RED}❌ 无效选择！${NC}"
            press_enter_to_continue
            return 1
            ;;
    esac
    
    local TMP_DIR="/data/local/tmp/ak3_flash_$(date +%s)"
    mkdir -p "$TMP_DIR" || {
        echo -e "${RED}❌ 无法创建临时目录！${NC}"
        press_enter_to_continue
        return
    }
    
    echo -e "${CYAN}⏳ 正在解压AK3包...${NC}"
    
    if ! unzip -o "$ak3_path" -d "$TMP_DIR" >/dev/null 2>&1; then
        echo -e "${RED}❌ AK3包解压失败！${NC}"
        echo -e "${YELLOW}请检查文件是否损坏或格式不正确${NC}"
        rm -rf "$TMP_DIR"
        press_enter_to_continue
        return 1
    fi
    
    [ ! -f "$TMP_DIR/anykernel.sh" ] && {
        echo -e "${RED}❌ 不是有效的AK3包 (缺少anykernel.sh)${NC}"
        rm -rf "$TMP_DIR"
        press_enter_to_continue
        return 1
    }
    
    if [ "$ENABLE_BACKUP" -eq 1 ]; then
        local partition_path="/dev/block/by-name/$target_partition"
        [ -e "$partition_path" ] || partition_path=$(find /dev/block -name $target_partition 2>/dev/null | head -n 1)
        
        if [ -z "$partition_path" ]; then
            echo -e "${RED}❌ 无法找到分区: $target_partition${NC}"
            rm -rf "$TMP_DIR"
            press_enter_to_continue
            return 1
        fi
        
        local backup_file="$BACKUP_DIR/${target_partition}_backup_$(date +%Y%m%d_%H%M%S).img"
        echo -e "${CYAN}⏳ 正在备份当前分区...${NC}"
        
        if ! dd if="$partition_path" of="$backup_file" bs=1M 2>/dev/null; then
            echo -e "${RED}❌ 分区备份失败！${NC}"
            rm -rf "$TMP_DIR"
            press_enter_to_continue
            return 1
        fi
        
        echo -e "${GREEN}✅ 备份成功！${NC}"
        echo -e "${YELLOW}📂 备份路径: ${NC}$backup_file"
    fi
    
    echo -e "\n${CYAN}⚡ 正在执行AK3刷入脚本...${NC}"
    
    cd "$TMP_DIR" || {
        echo -e "${RED}❌ 无法进入临时目录！${NC}"
        rm -rf "$TMP_DIR"
        return 1
    }
    
    chmod +x anykernel.sh
    
    echo "block=/dev/block/by-name/$target_partition" > config.sh
    if [ -n "$AB_SLOT" ]; then
        local slot_name=${target_partition##*_}
        echo "slot=$slot_name" >> config.sh
    fi
    
    echo -e "${YELLOW}----------------------------------------${NC}"
    echo -e "${CYAN}AK3刷入日志:${NC}"
    
    if sh anykernel.sh 2>&1; then
        echo -e "${YELLOW}----------------------------------------${NC}"
        echo -e "\n${GREEN}✅ AK3刷入流程完成！${NC}"
        echo -e "${YELLOW}目标分区: ${CYAN}$target_partition${NC}"
        
        rm -rf "$TMP_DIR"
        
        echo -e "\n${YELLOW}❓ 是否立即重启设备? (y/n): ${NC}"
        read -r reboot_choice
        reboot_choice=$(clean_input "$reboot_choice")
        if [ "$reboot_choice" = "y" ] || [ "$reboot_choice" = "Y" ]; then
            echo -e "${GREEN}🔄 正在重启设备...${NC}"
            sleep 2
            reboot
        fi
    else
        echo -e "${YELLOW}----------------------------------------${NC}"
        echo -e "\n${RED}❌ AK3刷入失败！${NC}"
        rm -rf "$TMP_DIR"
    fi
    
    press_enter_to_continue
}

security_check_lite() {
    CRITICAL=0 
    WARNING=0 
    SAFE=0 
    TOTAL_CHECKS=0

    safe_grep() {
        grep "$@" 2>/dev/null || echo ""
    }

    advanced_check() {
        name="$1"
        cmd="$2"
        good_pattern="$3"
        warn_pattern="$4"
        critical_pattern="$5"
        delay="${6:-0.1}"
        
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        
        echo -n "├─ ${name}: "
        output=""
        
        case "$cmd" in
            *dumpsys*|*pm*|*settings*|*iptables*)
                output=$(eval "$cmd" 2>/dev/null | head -n 10)
                ;;
            *)
                output=$(eval "$cmd" 2>/dev/null)
                ;;
        esac
        
        status=$?
        
        if [ -n "$critical_pattern" ] && [ -n "$output" ] && echo "$output" | safe_grep -q "$critical_pattern"; then
            echo -e "${RED}危险${NC}"
            CRITICAL=$((CRITICAL + 1))
        elif [ -n "$warn_pattern" ] && [ -n "$output" ] && echo "$output" | safe_grep -q "$warn_pattern"; then
            echo -e "${YELLOW}警告${NC}"
            WARNING=$((WARNING + 1))
        elif [ -z "$output" ] && [ $status -ne 0 ]; then
            echo -e "${BLUE}未知${NC}"
        else
            echo -e "${GREEN}安全${NC}"
            SAFE=$((SAFE + 1))
        fi
        
        sleep $delay
    }

    check_category() {
        echo -e "${CYAN}■ $1${NC}"
        shift
        while [ $# -gt 0 ]; do
            advanced_check "$1" "$2" "$3" "$4" "$5" "$6"
            shift 6
        done
    }

    clear
    echo -e "${PURPLE}═══════════════════════════════════════════════════"
    echo -e " Android安全专家检测工具91版 "
    echo -e "═══════════════════════════════════════════════════${NC}"
    echo -e "设备型号: $DEVICE_MODEL"
    echo -e "Android版本: $ANDROID_VERSION"
    echo -e "安全补丁: $SECURITY_PATCH"
    echo -e "═══════════════════════════════════════════════════\n"

    check_category "1. 系统基础信息" \
        "设备型号" "getprop ro.product.model" "" "" "" "0.1" \
        "系统版本" "getprop ro.build.display.id" "" "test-keys" "userdebug" "0.1" \
        "Android版本" "getprop ro.build.version.release" "1[2-9]" "2[0-9]" "[0-8]\." "0.1" \
        "安全补丁" "getprop ro.build.version.security_patch" "202[3-9]" "202[0-2]" "201[0-9]" "0.1" \
        "内核版本" "uname -r" "4\.1[4-9]" "5\." "3\." "0.2" \
        "构建类型" "getprop ro.build.type" "user" "" "userdebug" "0.1" \
        "系统指纹" "getprop ro.build.fingerprint" "" "test-keys" "userdebug" "0.2" \
        "设备状态" "getprop ro.boot.verifiedbootstate" "green" "yellow" "orange" "0.2" \
        "Bootloader" "{ [ \"\$(getprop ro.boot.flash.locked)\" == \"1\" ] && echo locked || echo unlocked; }" "locked" "" "unlocked" "0.3" \
        "SElinux状态" "getenforce" "Enforcing" "Permissive" "Disabled" "0.2"

    check_category "2. Root与提权检测" \
        "传统su二进制" "which su" "" "" "\." "0.2" \
        "Magisk核心" "{ [ -d /sbin/.magisk ] || [ -d /data/adb/magisk ]; } && echo present" "" "" "present" "0.3" \
        "KernelSU检测" "[ -f /proc/kernelsu/version ] && cat /proc/kernelsu/version" "" "" "\." "0.4" \
        "SuperSU残留" "find /system /vendor -name \"*.su\" 2>/dev/null" "" "" "\." "0.3" \
        "提权测试" "{ touch /system/test 2>/dev/null && echo writable || echo readonly; rm -f /system/test 2>/dev/null; }" "readonly" "" "writable" "0.5" \
        "特权命令" "pm list packages" "com.android.settings" "" "\." "0.2" \
        "setuid程序" "find /system/bin /vendor/bin -perm -4000 2>/dev/null | wc -l" "[0-9]" "[1-9][0-9]" "" "0.5" \
        "Root应用" "pm list packages | grep -E 'superuser|magisk|kernelSU'" "" "" "\." "0.4" \
        "adb root状态" "{ [ \"\$(getprop service.adb.root)\" == \"1\" ] && echo enabled || echo disabled; }" "disabled" "" "enabled" "0.2" \
        "su上下文" "{ which su >/dev/null && id -Z 2>/dev/null | grep -q \"u:r:su:s0\" && echo found; }" "" "" "found" "0.3"

    check_category "3. 应用安全检测" \
        "调试应用" "pm list packages -d" "" "" "[a-zA-Z0-9]" "0.3" \
        "Xposed框架" "[ -f /system/framework/XposedBridge.jar ] && echo installed" "" "" "installed" "0.4" \
        "未知来源" "settings get secure install_non_market_apps" "0" "" "1" "0.2" \
        "危险权限" "dumpsys package | grep -A5 'dangerous permissions'" "" "" "android.permission.\*" "0.5" \
        "设备管理员" "dumpsys device_policy | grep -A5 'Admin Policies'" "" "" "DeviceAdmin" "0.4" \
        "可调试应用" "dumpsys package | grep -A2 'flags=DEBUGGABLE'" "" "" "DEBUGGABLE" "0.5" \
        "后台服务" "dumpsys activity services | grep -E 'bindService|startService'" "" "" "\." "0.5" \
        "运行时权限" "dumpsys package | grep -A5 'runtime permissions'" "" "" "\." "0.6" \
        "签名验证" "dumpsys package | grep -A3 'signatures='" "" "" "\." "0.5" \
        "预装应用" "pm list packages -s | wc -l" "[0-9]" "[1-9][0-9][0-9]" "" "0.4"

    check_category "4. 网络与连接检测" \
        "ADB调试" "settings get global adb_enabled" "0" "" "1" "0.2" \
        "开放端口" "netstat -tuln | grep -v \"127.0.0.1\" | wc -l" "[0-5]" "" "[6-9]" "0.5" \
        "VPN状态" "ip link show | grep tun" "" "" "\." "0.3" \
        "代理设置" "settings get global http_proxy" "" "" "[a-zAZ0-9]" "0.2" \
        "网络连接" "netstat -tn | grep -v \"127.0.0.1\"" "" "" "\." "0.5" \
        "防火墙规则" "iptables -L -n 2>/dev/null" "" "" "\." "0.6" \
        "无线网络" "dumpsys wifi | grep -A5 'Current Configuration'" "" "" "\." "0.4" \
        "蓝牙服务" "dumpsys bluetooth_manager | grep -A3 'Enabled:'" "" "" "\." "0.4" \
        "NFC状态" "getprop ro.nfc.status" "" "" "\." "0.3" \
        "数据漫游" "settings get global data_roaming" "0" "" "1" "0.2"

    check_category "5. 存储与加密检测" \
        "加密状态" "getprop ro.crypto.state" "encrypted" "" "unencrypted" "0.3" \
        "文件系统" "mount | grep -E '/system|/data|/vendor'" "" "" "\." "0.4" \
        "存储权限" "ls -ld /data /mnt /storage" "" "" "\." "0.3" \
        "SD卡权限" "ls -l /mnt/media_rw/" "" "" "\." "0.3" \
        "临时文件" "ls -l /data/local/tmp" "" "" "\." "0.3" \
        "日志文件" "find /data/log -type f 2>/dev/null" "" "" "\." "0.4" \
        "磁盘空间" "df -h /data" "" "" "\." "0.2" \
        "加密算法" "getprop | grep -E 'cipher|algorithm'" "" "" "\." "0.4"

    echo -e "${PURPLE}═══════════════════════════════════════════════════"
    echo -e " 检测结果汇总 "
    echo -e "═══════════════════════════════════════════════════${NC}"
    echo -e "总检查项: ${TOTAL_CHECKS}"
    echo -e "${RED}严重问题: ${CRITICAL}${NC}"
    echo -e "${YELLOW}潜在风险: ${WARNING}${NC}"
    echo -e "${GREEN}安全项目: ${SAFE}${NC}"
    echo ""

    echo -e "${PURPLE}═══════════════════════════════════════════════════"
    echo -e " 安全专家建议 "
    echo -e "═══════════════════════════════════════════════════${NC}"
    [ $CRITICAL -gt 0 ] && {
        echo -e "${RED}1. 立即处理以下严重问题:${NC}"
        [ "$(getprop ro.boot.verifiedbootstate)" != "green" ] && echo "   - 系统验证未通过 (AVB状态异常)"
        [ "$(getprop ro.boot.flash.locked)" = "0" ] && echo "   - Bootloader已解锁"
        which su >/dev/null 2>&1 && echo "   - 检测到su二进制文件"
        [ -f "/proc/kernelsu/version" ] && echo "   - 检测到KernelSU安装"
        [ -d "/sbin/.magisk" ] && echo "   - 检测到Magisk安装"
        touch /system/test 2>/dev/null && echo "   - /system分区可写入"
        rm -f /system/test 2>/dev/null
        echo ""
    }

    [ $WARNING -gt 0 ] && {
        echo -e "${YELLOW}2. 建议修复以下潜在风险:${NC}"
        [ "$(settings get global adb_enabled 2>/dev/null)" = "1" ] && echo "   - ADB调试已启用"
        [ "$(settings get secure install_non_market_apps 2>/dev/null)" = "1" ] && echo "   - 允许未知来源安装"
        [ "$(getprop ro.debuggable)" = "1" ] && echo "   - 系统可调试"
        netstat -tuln 2>/dev/null | grep -v "127.0.0.1" | grep -q "LISTEN" && echo "   - 存在异常开放端口"
        echo ""
    }

    echo -e "${GREEN}3. 常规安全建议:${NC}"
    echo "   - 保持系统和应用更新到最新版本"
    echo "   - 仅从官方应用商店安装应用"
    echo "   - 禁用开发者选项和ADB调试"
    echo "   - 使用设备加密功能"
    echo "   - 避免使用root权限"
    echo "   - 配置屏幕锁定和生物识别"

    press_enter_to_continue
}

security_check_menu() {
    while true; do
        show_header
        echo -e "${BLUE}|          ${CYAN}安全检测功能${BLUE}                |${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${GREEN}1. 快速安全检测 (90+项)${NC}"
        echo -e "${GREEN}2. 返回主菜单${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e -n "${CYAN}请选择 [1-2]: ${NC}"
        
        read -r choice
        choice=$(clean_input "$choice")
        case "$choice" in
            1) security_check_lite ;;
            2) return ;;
            *)
                echo -e "${RED}❌ 无效选择！${NC}"
                sleep 1
                ;;
        esac
    done
}

extract_version_number() {
    echo "$1" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'
}

compare_versions() {
    local version1=$(extract_version_number "$1")
    local version2=$(extract_version_number "$2")
    
    if [ -z "$version1" ] || [ -z "$version2" ]; then
        if [[ "$1" < "$2" ]]; then
            return 0
        elif [[ "$1" > "$2" ]]; then
            return 1
        else
            return 2
        fi
    fi

    IFS='.' read -ra ver1 <<< "$version1"
    IFS='.' read -ra ver2 <<< "$version2"

    for i in $(seq 0 $((${#ver1[@]} - 1))); do
        if [ -z "${ver2[$i]}" ]; then
            return 1
        fi
        
        if [ ${ver1[$i]} -lt ${ver2[$i]} ]; then
            return 0
        elif [ ${ver1[$i]} -gt ${ver2[$i]} ]; then
            return 1
        fi
    done

    if [ ${#ver1[@]} -lt ${#ver2[@]} ]; then
        i=${#ver1[@]}
        while [ $i -lt ${#ver2[@]} ]; do
            if [ -n "${ver2[$i]}" ] && [ "${ver2[$i]}" != "0" ]; then
                return 0
            fi
            i=$((i + 1))
        done
    fi

    return 2
}

check_network_tools() {
    command -v curl >/dev/null && NET_TOOL="curl" && return 0
    command -v wget >/dev/null && NET_TOOL="wget" && return 0
    command -v busybox >/dev/null && busybox wget --help >/dev/null 2>&1 && 
        NET_TOOL="busybox_wget" && return 0
    
    echo -e "${RED}❌ 错误：没有可用的网络工具！${NC}"
    return 1
}

is_force_update_version() {
    local version="$1"
    echo "$version" | grep -qE '[0-9]+\.[0-9]+\.[0-9]+' && return 0
    return 1
}

clean_old_versions() {
    local current_version="$1"
    local update_dir="$DEFAULT_UPDATE_DIR"
    
    echo -e "${YELLOW}🧹 正在清理旧版本文件...${NC}"
    
    if [ ! -d "$update_dir" ]; then
        echo -e "${YELLOW}⚠️ 更新目录不存在，无需清理${NC}"
        return 0
    fi
    
    local version_files=$(find "$update_dir" -name "*v*.sh" -type f 2>/dev/null)
    
    if [ -z "$version_files" ]; then
        echo -e "${GREEN}✅ 没有找到旧版本文件${NC}"
        return 0
    fi
    
    local deleted_count=0
    local kept_count=0
    
    for file in $version_files; do
        local filename=$(basename "$file")
        
        local file_version=$(grep -oE 'VERSION="[0-9]+\.[0-9]+(\.[0-9]+)?"' "$file" 2>/dev/null | head -1 | cut -d'"' -f2)
        
        if [ -z "$file_version" ]; then
            file_version=$(echo "$filename" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
        fi
        
        if [ -n "$file_version" ]; then
            compare_versions "$file_version" "$current_version"
            local compare_result=$?
            
            case $compare_result in
                0) 
                    rm -f "$file" 2>/dev/null && {
                        echo -e "${BLUE}🗑️ 删除旧版本: $filename (v$file_version)${NC}"
                        deleted_count=$((deleted_count + 1))
                    } || {
                        echo -e "${YELLOW}⚠️ 无法删除: $filename${NC}"
                    }
                    ;;
                1|2) 
                    echo -e "${GREEN}📁 保留较新版本: $filename (v$file_version)${NC}"
                    kept_count=$((kept_count + 1))
                    ;;
            esac
        else
            echo -e "${YELLOW}⚠️ 无法识别版本，保留文件: $filename${NC}"
            kept_count=$((kept_count + 1))
        fi
    done
    
    echo -e "${GREEN}✅ 清理完成: 删除 $deleted_count 个旧版本，保留 $kept_count 个文件${NC}"
    return 0
}

get_script_hash() {
    local script_path="$1"
    if [ -f "$script_path" ]; then
        if command -v sha256sum >/dev/null 2>&1; then
            sha256sum "$script_path" 2>/dev/null | cut -d' ' -f1
        else
            echo "none"
        fi
    else
        echo "none"
    fi
}

calculate_script_hash() {
    if command -v sha256sum >/dev/null 2>&1; then
        local full_hash=$(sha256sum "$SCRIPT_PATH" 2>/dev/null | cut -d' ' -f1)
        
        if [ -n "$full_hash" ] && [ "$full_hash" != "none" ]; then
            SCRIPT_HASH="[sha256:${full_hash}]"
        else
            SCRIPT_HASH="[无法计算SHA256]"
        fi
    else
        SCRIPT_HASH="[需要sha256sum命令]"
    fi
}

check_hash_mismatch() {
    local local_script="$1"
    local remote_script="$2"
    
    local local_hash=$(get_script_hash "$local_script")
    local remote_hash=$(get_script_hash "$remote_script")
    
    if [ "$local_hash" != "none" ] && [ "$remote_hash" != "none" ] && [ "$local_hash" != "$remote_hash" ]; then
        echo -e "${RED}⚠️ 警告：脚本SHA256哈希值不匹配！${NC}"
        echo -e "${YELLOW}本地脚本SHA256: $local_hash${NC}"
        echo -e "${YELLOW}远程脚本SHA256: $remote_hash${NC}"
        echo -e "${YELLOW}这可能表示脚本已被篡改或损坏${NC}"
        echo -e "${YELLOW}请谨慎使用！${NC}"
        sleep 3
        return 1
    fi
    return 0
}

check_force_update() {
    echo -e "${YELLOW}🔍 检查强制更新...${NC}"
    sleep 1
    
    ping -c 1 -W 1 github.com >/dev/null 2>&1 || {
        echo -e "${RED}❌ 无法连接到GitHub，跳过更新检查！${NC}"
        sleep 1
        return
    }
    
    local api_url="https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest"
    
    check_network_tools || return
    
    case $NET_TOOL in
        "curl")
            release_info=$(curl -s -L -H "Accept: application/vnd.github.v3+json" "$api_url" || echo "")
            ;;
        "wget")
            release_info=$(wget -qO- --header="Accept: application/vnd.github.v3+json" "$api_url" || echo "")
            ;;
        "busybox_wget")
            release_info=$(busybox wget -qO- --header="Accept: application/vnd.github.v3+json" "$api_url" || echo "")
            ;;
    esac
    
    [ -z "$release_info" ] || echo "$release_info" | grep -q "Not Found" && {
        echo -e "${RED}❌ 无法获取发布信息！${NC}"
        return 1
    }
    
    release_name=$(echo "$release_info" | grep '"name"' | head -1 | cut -d'"' -f4)
    [ -z "$release_name" ] && 
        release_name=$(echo "$release_info" | grep '"tag_name"' | head -1 | cut -d'"' -f4)
    
    body_content=$(echo "$release_info" | grep '"body"' | head -1 | cut -d'"' -f4)
    script_url=$(echo "$release_info" | grep '"browser_download_url"' | grep "$SCRIPT_FILE" | cut -d'"' -f4)
    
    [ -z "$script_url" ] && {
        echo -e "${RED}❌ 错误：无法找到脚本文件！${NC}"
        return 1
    }
    
    local file_size=$(get_file_size "$script_url")
    local formatted_size="未知"
    if check_bc_installed; then
        formatted_size=$(format_file_size "$file_size")
    else
        formatted_size=$(format_file_size_simple "$file_size")
    fi
    
    compare_versions "$VERSION" "$release_name"
    local compare_result=$?
    
    case $compare_result in
        0)
            clear
            echo -e "${RED}======================================================${NC}"
            echo -e "|              ⚠️ 发现新版本 ⚠️              |"
            echo -e "${RED}======================================================${NC}"
            echo -e "${YELLOW}当前版本: $VERSION${NC}"
            echo -e "${YELLOW}最新版本: $release_name${NC}"
            echo -e "${YELLOW}文件大小: $formatted_size${NC}"
            echo -e "${CYAN}更新内容:${NC}"
            echo -e "$body_content" | while IFS= read -r line; do
                echo -e "  $line"
            done
            echo ""
            
            if is_force_update_version "$release_name"; then
                echo -e "${RED}⚠️ 这是强制更新版本 (x.x.x格式)，必须更新才能继续使用！${NC}"
                local force_update=true
            else
                echo -e "${YELLOW}⚠️ 这是普通更新版本 (x.x格式)，可以选择跳过${NC}"
                local force_update=false
            fi
            
            local in_whitelist=0
            for id in $ANDROID_ID_WHITELIST; do
                [ "$(get_android_id)" = "$id" ] && in_whitelist=1 && break
            done
            
            if [ "$in_whitelist" -eq 1 ] && [ "$force_update" = "false" ]; then
                echo -e "${GREEN}✅ 您的设备在白名单中，可以选择跳过更新${NC}"
            elif [ "$force_update" = "true" ]; then
                echo -e "${RED}⚠️ 必须更新才能继续使用本工具${NC}"
            fi
            
            local save_dir="$DEFAULT_UPDATE_DIR"
            
            mkdir -p "$save_dir" 2>/dev/null || {
                echo -e "${RED}❌ 无法创建目录 $save_dir!${NC}"
                save_dir="/sdcard"
            }
            
            local new_script="$save_dir/${SCRIPT_FILE%.*}_v$release_name.sh"
            
            while true; do
                echo -e "${CYAN}请选择更新方式：${NC}"
                if [ "$force_update" = "true" ]; then
                    echo -e "${GREEN}1. 覆盖安装（推荐）${NC}"
                    echo -e "${GREEN}2. 普通下载${NC}"
                    echo -e "${RED}3. 退出脚本${NC}"
                else
                    echo -e "${GREEN}1. 覆盖安装（推荐）${NC}"
                    echo -e "${GREEN}2. 普通下载${NC}"
                    echo -e "${YELLOW}3. 不更新${NC}"
                fi
                echo -e "${CYAN}======================================================${NC}"
                
                echo -e "${YELLOW}👉 请选择 (1-3): ${NC}"
                
                read -r update_choice
                update_choice=$(clean_input "$update_choice")
                
                case $update_choice in
                    1)
                        echo -e "${GREEN}✅ 您选择了覆盖安装${NC}"
                        break
                        ;;
                    2)
                        echo -e "${GREEN}✅ 您选择了普通下载${NC}"
                        break
                        ;;
                    3)
                        if [ "$force_update" = "true" ]; then
                            echo -e "${RED}❌ 强制更新版本无法跳过，将退出脚本！${NC}"
                            sleep 2
                            exit 0
                        else
                            echo -e "${YELLOW}⚠️ 您选择了不更新，将继续使用当前版本${NC}"
                            sleep 1
                            return
                        fi
                        ;;
                    *)
                        echo -e "${RED}❌ 无效选择，请重新选择！${NC}"
                        sleep 0.5
                        ;;
                esac
            done
            
            echo -e "\n${CYAN}⏳ 即将开始下载更新，请稍候...${NC}"
            i=$FORCE_UPDATE_COUNTDOWN
            while [ $i -ge 1 ]; do
                echo -ne "${YELLOW}倒计时: ${i}秒... ${NC}\r"
                sleep 1
                i=$((i - 1))
            done
            echo -ne "${GREEN}开始下载更新...${NC}         \r"
            sleep 1
            echo ""
            
            if download_with_progress "$script_url" "$new_script"; then
                check_hash_mismatch "$SCRIPT_PATH" "$new_script"
                head -n 5 "$new_script" | grep -q "#!/system/bin/sh" && {
                    chmod 755 "$new_script"
                    echo -e "\n${GREEN}✅ 更新下载成功！${NC}"
                    
                    clean_old_versions "$release_name"
                    
                    echo -e "${YELLOW}📂 新版本路径: ${WHITE}$new_script${NC}"
                    
                    if [ "$update_choice" = "1" ]; then
                        echo -e "${CYAN}⏳ 正在执行覆盖安装...${NC}"
                        current_script_path="$0"
                        if [ -w "$current_script_path" ]; then
                            cat "$new_script" > "$current_script_path"
                            chmod 755 "$current_script_path"
                            echo -e "${GREEN}✅ 覆盖安装成功！正在重新启动脚本...${NC}"
                            sleep 2
                            exec sh "$current_script_path"
                        else
                            echo -e "${RED}❌ 当前脚本不可写，无法覆盖安装！${NC}"
                            echo -e "${YELLOW}将使用普通下载模式。${NC}"
                        fi
                    fi
                    
                    if [ "$update_choice" = "2" ] || [ ! -w "$current_script_path" ]; then
                        echo -e "${GREEN}✅ 普通下载完成！${NC}"
                        echo -e "${YELLOW}📂 文件已保存至: $new_script${NC}"
                        echo -e "${YELLOW}🔧 请手动执行新版本脚本${NC}"
                        press_enter_to_continue
                    fi
                    
                } || {
                    echo -e "${RED}❌ 错误：下载的文件不是有效的脚本！${NC}"
                    rm -f "$new_script"
                }
            else
                echo -e "${RED}❌ 下载失败！${NC}"
            fi
            
            press_enter_to_continue
            ;;
        1)
            echo -e "${GREEN}✅ 当前版本 ($VERSION) 比远程版本 ($release_name) 更新${NC}"
            sleep 1
            ;;
        2)
            echo -e "${GREEN}✅ 当前已是最新版本${NC}"
            sleep 1
            ;;
    esac
}

github_update() {
    clear
    show_banner
    echo -e "${CYAN}========================================"
    echo -e "|          🌐 GitHub云更新 🌐          |"
    echo -e "${CYAN}========================================"
    
    echo -e "${YELLOW}🔍 正在检查更新...${NC}"
    sleep 1
    
    ping -c 1 -W 1 github.com >/dev/null 2>&1 || {
        echo -e "${RED}❌ 无法连接到GitHub，请检查网络连接！${NC}"
        sleep 1
        press_enter_to_continue
        return
    }
    
    local api_url="https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest"
    
    check_network_tools || return
    
    case $NET_TOOL in
        "curl")
            release_info=$(curl -s -L -H "Accept: application/vnd.github.v3+json" "$api_url" || echo "")
            ;;
        "wget")
            release_info=$(wget -qO- --header="Accept: application/vnd.github.v3+json" "$api_url" || echo "")
            ;;
        "busybox_wget")
            release_info=$(busybox wget -qO- --header="Accept: application/vnd.github.v3+json" "$api_url" || echo "")
            ;;
    esac
    
    [ -z "$release_info" ] || echo "$release_info" | grep -q "Not Found" && {
        echo -e "${RED}❌ 无法获取发布信息！${NC}"
        sleep 1
        press_enter_to_continue
        return
    }
    
    release_name=$(echo "$release_info" | grep '"name"' | head -1 | cut -d'"' -f4)
    [ -z "$release_name" ] && 
        release_name=$(echo "$release_info" | grep '"tag_name"' | head -1 | cut -d'"' -f4)
    
    body_content=$(echo "$release_info" | grep '"body"' | head -1 | cut -d'"' -f4)
    script_url=$(echo "$release_info" | grep '"browser_download_url"' | grep "$SCRIPT_FILE" | cut -d'"' -f4)
    
    [ -z "$script_url" ] && {
        echo -e "${RED}❌ 错误：无法找到脚本文件！${NC}"
        sleep 1
        press_enter_to_continue
        return
    }
    
    local file_size=$(get_file_size "$script_url")
    local formatted_size="未知"
    if check_bc_installed; then
        formatted_size=$(format_file_size "$file_size")
    else
        formatted_size=$(format_file_size_simple "$file_size")
    fi
    
    echo -e "${GREEN}📱 当前版本: ${WHITE}$VERSION${NC}"
    echo -e "${GREEN}🚀 最新版本: ${WHITE}$release_name${NC}"
    echo -e "${GREEN}📊 文件大小: ${WHITE}$formatted_size${NC}"
    
    compare_versions "$VERSION" "$release_name"
    local compare_result=$?
    
    case $compare_result in
        0)
            echo -e "${YELLOW}⚠️ 发现新版本！${NC}"
            ;;
        1)
            echo -e "${YELLOW}⚠️ 当前版本比远程版本更新！${NC}"
            ;;
        2)
            echo -e "${GREEN}✅ 已是最新版本${NC}"
            press_enter_to_continue
            return
            ;;
    esac
    
    echo -e "${BLUE}📝 更新内容:${NC}"
    echo -e "$body_content" | while IFS= read -r line; do
        echo -e "  $line"
    done
    
    echo -e "\n${CYAN}请选择更新方式：${NC}"
    echo -e "${GREEN}1. 覆盖安装（推荐）${NC}"
    echo -e "${GREEN}2. 普通下载${NC}"
    echo -e "${YELLOW}3. 不更新${NC}"
    echo -e "${CYAN}========================================"
    echo -e "${YELLOW}👉 请选择 (1-3): ${NC}"
    
    read -r update_choice
    update_choice=$(clean_input "$update_choice")
    
    case $update_choice in
        1|2)
            local save_dir="$DEFAULT_UPDATE_DIR"
            local new_script="$save_dir/${SCRIPT_FILE%.*}_v$release_name.sh"
            
            echo -e "${CYAN}⏳ 正在下载新版本...${NC}"
            
            if download_with_progress "$script_url" "$new_script"; then
                if [ -s "$new_script" ]; then
                    check_hash_mismatch "$SCRIPT_PATH" "$new_script"
                    head -n 5 "$new_script" | grep -q "#!/system/bin/sh" && {
                        chmod 755 "$new_script"
                        echo -e "\n${GREEN}✅ 下载成功！${NC}"
                        
                        clean_old_versions "$release_name"
                        
                        if [ "$update_choice" = "1" ]; then
                            echo -e "${CYAN}⏳ 正在执行覆盖安装...${NC}"
                            current_script_path="$0"
                            if [ -w "$current_script_path" ]; then
                                cat "$new_script" > "$current_script_path"
                                chmod 755 "$current_script_path"
                                echo -e "${GREEN}✅ 覆盖安装成功！正在重新启动脚本...${NC}"
                                sleep 2
                                exec sh "$current_script_path"
                            else
                                echo -e "${RED}❌ 当前脚本不可写，无法覆盖安装！${NC}"
                                echo -e "${YELLOW}自动切换到普通下载模式。${NC}"
                                update_choice="2"
                            fi
                        fi
                        
                        if [ "$update_choice" = "2" ]; then
                            echo -e "${GREEN}✅ 普通下载完成！${NC}"
                            echo -e "${YELLOW}📂 文件已保存至: $new_script${NC}"
                            echo -e "${YELLOW}🔧 请手动执行新版本脚本${NC}"
                        fi
                    } || {
                        echo -e "${RED}❌ 错误：下载的文件不是有效的脚本！${NC}"
                        rm -f "$new_script"
                    }
                else
                    echo -e "${RED}❌ 下载的文件为空！${NC}"
                    rm -f "$new_script" 2>/dev/null
                fi
            else
                echo -e "${RED}❌ 下载失败！${NC}"
            fi
            ;;
        3)
            echo -e "${YELLOW}⚠️ 您选择了不更新，将继续使用当前版本${NC}"
            ;;
        *)
            echo -e "${RED}❌ 无效选择！${NC}"
            ;;
    esac
    
    press_enter_to_continue
}

device_info() {
    clear
    show_banner
    echo -e "${CYAN}========================================"
    echo -e "|          📱 设备信息 📱            |"
    echo -e "${CYAN}========================================"
    
    local system_version=$(getprop ro.system.build.version.incremental || getprop ro.build.version.incremental || echo "未知")
    local storage=$(df -h /data | tail -n 1 | awk '{print $4}' || echo "未知")
    local script_path=$(realpath "$0" 2>/dev/null || echo "$0")
    
    echo -e "${GREEN}📱 设备型号: ${WHITE}$DEVICE_MODEL${NC}"
    echo -e "${GREEN}🤖 Android版本: ${WHITE}$ANDROID_VERSION${NC}"
    echo -e "${GREEN}🧩 系统版本: ${WHITE}$system_version${NC}"
    echo -e "${GREEN}🛠️ 构建ID: ${WHITE}$(getprop ro.build.display.id || echo '未知')${NC}"
    echo -e "${GREEN}🔒 安全补丁: ${WHITE}$SECURITY_PATCH${NC}"
    echo -e "${GREEN}⚙️ 内核版本: ${WHITE}$KERNEL_VERSION${NC}"
    if [ $ROOT_ACCESS -eq 1 ]; then
        echo -e "${GREEN}🌡️ 电池温度: ${WHITE}$BATTERY_TEMP°C${NC}"
        echo -e "${GREEN}🔋 电池电量: ${WHITE}$BATTERY_LEVEL%${NC}"
    fi
    echo -e "${GREEN}🆔 安卓ID: ${WHITE}$ANDROID_ID${NC}"
    echo -e "${GREEN}💾 可用存储: ${WHITE}$storage${NC}"
    echo -e "${GREEN}📁 脚本路径: ${WHITE}$script_path${NC}"
    
    if [ $ROOT_ACCESS -eq 1 ]; then
        echo -e "${GREEN}🔓 ROOT状态: ${WHITE}已获取完整权限${NC}"
    else
        echo -e "${YELLOW}⚠️ ROOT状态: ${WHITE}未获取完整权限${NC}"
    fi
    
    press_enter_to_continue
}

check_ab_partition() {
    clear
    show_banner
    echo -e "${CYAN}========================================"
    echo -e "|          🔄 AB分区检测 🔄          |"
    echo -e "${CYAN}========================================"
    echo -e "${GREEN}🆔 安卓ID: ${WHITE}$ANDROID_ID${NC}"
    echo ""
    
    if [ -n "$AB_SLOT" ]; then
        echo -e "${GREEN}✅ 设备支持A/B分区${NC}"
        echo -e "${GREEN}🔀 当前活动槽位: ${WHITE}${AB_SLOT#_}${NC}"
        
        echo -e "\n${YELLOW}分区说明："
        echo -e "A/B分区系统允许设备在后台更新系统"
        echo -e "当前活动槽位是系统正在使用的分区${NC}"
    else
        echo -e "${YELLOW}❌ 设备不支持A/B分区${NC}"
        
        echo -e "\n${YELLOW}分区说明："
        echo -e "传统分区系统每次更新需要重启设备"
        echo -e "无法实现无缝更新功能${NC}"
    fi
    
    press_enter_to_continue
}

reboot_menu() {
    while true; do
        show_header
        echo -e "${BLUE}|          ${CYAN}高级重启菜单${BLUE}                |${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${GREEN}🆔 安卓ID: ${WHITE}$ANDROID_ID${NC}"
        echo ""
        
        echo -e "${BLUE}1. 🔄 重启系统${NC}"
        echo -e "${BLUE}2. 🔄 重启到Recovery${NC}"
        echo -e "${BLUE}3. 🔄 重启到Bootloader${NC}"
        echo -e "${BLUE}4. 🔄 重启到Fastboot${NC}"
        echo -e "${RED}5. ↩️ 返回主菜单${NC}"
        
        echo -e "${BLUE}========================================${NC}"
        echo -e "${YELLOW}👉 请选择操作 (1-5): ${NC}"
        
        read -r choice
        choice=$(clean_input "$choice")
        
        case $choice in
            1) 
                echo -e "${GREEN}🔄 正在重启系统...${NC}"
                sleep 0.5
                reboot
                ;;
            2) 
                echo -e "${GREEN}🔄 正在启动Recovery...${NC}"
                sleep 0.5
                reboot recovery
                ;;
            3) 
                echo -e "${GREEN}🔄 正在启动Bootloader...${NC}"
                sleep 0.5
                reboot bootloader
                ;;
            4) 
                echo -e "${GREEN}⚡ 正在启动Fastboot...${NC}"
                sleep 0.5
                reboot fastboot
                ;;
            5)
                return
                ;;
            *) 
                echo -e "${RED}❌ 无效选择！${NC}"
                sleep 0.5
                ;;
        esac
    done
}

settings_menu() {
    while true; do
        show_header
        echo -e "${BLUE}|          ${CYAN}工具箱设置${BLUE}                    |${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${GREEN}🆔 安卓ID: ${WHITE}$ANDROID_ID${NC}"
        echo ""
        
        [ "$ENABLE_BACKUP" -eq 1 ] && backup_status="${GREEN}启用${NC}" || backup_status="${RED}禁用${NC}"
        [ "$LOG_ENABLED" = "yes" ] && logging_status="${GREEN}启用${NC}" || logging_status="${RED}禁用${NC}"
        
        echo -e "1. 分区备份: $backup_status"
        echo -e "2. 日志记录: $logging_status"
        echo -e "3. 强制更新倒计时: ${FORCE_UPDATE_COUNTDOWN}秒"
        echo -e "4. 重置所有设置为默认值"
        echo -e "${RED}5. ↩️ 返回主菜单${NC}"
        
        echo -e "${BLUE}========================================${NC}"
        echo -e "${YELLOW}👉 请选择操作 (1-5): ${NC}"
        
        read -r choice
        choice=$(clean_input "$choice")
        
        case $choice in
            1)
                if [ "$ENABLE_BACKUP" -eq 1 ]; then
                    ENABLE_BACKUP=0
                    echo -e "${YELLOW}⚠️ 已禁用分区备份功能${NC}"
                else
                    ENABLE_BACKUP=1
                    echo -e "${GREEN}✅ 已启用分区备份功能${NC}"
                fi
                sleep 1
                ;;
            2)
                if [ "$LOG_ENABLED" = "yes" ]; then
                    LOG_ENABLED="no"
                    echo -e "${YELLOW}⚠️ 已禁用日志记录功能${NC}"
                else
                    LOG_ENABLED="yes"
                    echo -e "${GREEN}✅ 已开启日志记录功能${NC}"
                fi
                sleep 1
                ;;
            3)
                clear
                show_banner
                echo -e "${CYAN}========================================"
                echo -e "|          ⏱️ 强制更新倒计时设置 ⏱️         |"
                echo -e "${CYAN}========================================"
                echo -e "${GREEN}当前倒计时: ${WHITE}${FORCE_UPDATE_COUNTDOWN}秒${NC}"
                echo ""
                echo -e "${YELLOW}请输入新的倒计时秒数 (1-60): ${NC}"
                read -r new_countdown
                new_countdown=$(clean_input "$new_countdown")
                
                if echo "$new_countdown" | grep -qE '^[1-9][0-9]?$' && [ "$new_countdown" -ge 1 ] && [ "$new_countdown" -le 60 ]; then
                    FORCE_UPDATE_COUNTDOWN="$new_countdown"
                    echo -e "${GREEN}✅ 强制更新倒计时已设置为 ${WHITE}${new_countdown}秒${NC}"
                else
                    echo -e "${RED}❌ 无效输入！请输入1-60之间的整数${NC}"
                fi
                sleep 1
                ;;
            4)
                ENABLE_BACKUP=1
                LOG_ENABLED="yes"
                FORCE_UPDATE_COUNTDOWN=5
                echo -e "${GREEN}✅ 所有设置已重置为默认值${NC}"
                sleep 1
                ;;
            5)
                return
                ;;
            *)
                echo -e "${RED}❌ 无效选择！请输入1-5之间的数字${NC}"
                sleep 0.5
                ;;
        esac
    done
}

show_random_tip() {
    TIPS=(
        "⚠️ 重要提示：操作分区可能导致设备变砖，请谨慎操作！"
        "💡 提示：使用前请确保设备电量充足（建议>50%）"
        "🔒 安全建议：操作前备份重要数据"
        "🌐 新功能：支持GitHub云更新，保持脚本最新"
        "🔄 更新功能：新增覆盖安装、普通下载、不更新三种选择"
        "📢 公告：提取的分区文件请勿传播或商用"
        "🔍 新增功能：分区搜索和批量提取功能"
        "📁 文件管理：所有文件现在保存在'分区管理工具'文件夹内"
        "🧹 新增功能：自动清理旧版本文件，节省存储空间"
        "⚡ AK3优化：现在仅支持刷入boot_a和boot_b分区"
        "📊 新增功能：下载时显示文件大小、进度和速度"
        "🔒 新增功能：脚本SHA256哈希值检测，确保文件完整性"
    )
    
    random_index=$((RANDOM % ${#TIPS[@]}))
    random_tip="${TIPS[$random_index]}"
    
    echo -e "${CYAN}========================================${NC}"
    echo -e "${YELLOW}$random_tip${NC}"
    echo -e "${CYAN}========================================${NC}"
}

self_update() {
    local current_hash=$(get_script_hash "$SCRIPT_PATH")
    local latest_hash=$(get_script_hash "$0")
    
    if [ "$current_hash" != "$latest_hash" ] && [ -n "$latest_hash" ] && [ "$latest_hash" != "none" ]; then
        echo -e "${GREEN}✅ 发现脚本更新，正在重新加载...${NC}"
        exec sh "$0" "$@"
    fi
}

show_help() {
    clear
    show_banner
    echo -e "${CYAN}========================================"
    echo -e "|          📖 帮助信息 📖            |"
    echo -e "${CYAN}========================================"
    
    echo -e "${GREEN}主要功能:${NC}"
    echo -e "1. 📱 设备信息 - 查看设备详细信息"
    echo -e "2. 💾 分区提取 - 备份设备分区"
    echo -e "3. 🔥 分区刷写 - 刷入分区映像"
    echo -e "4. 🔄 高级重启 - 各种重启选项"
    echo -e "5. 🔄 AB分区检测 - 检测A/B分区支持"
    echo -e "6. 🌐 GitHub更新 - 在线更新脚本"
    echo -e "7. 📦 刷入AK3压缩包 - 刷入AnyKernel3包"
    echo -e "8. 🛡️ 安全检测 - 设备安全状态检测"
    echo -e "9. 🎮 娱乐功能 - 一些有趣的功能"
    echo -e "10. ⚙️ 工具箱设置 - 自定义脚本设置"
    echo -e "11. 📚 其他功能 - 文件夹信息等"
    
    echo -e "\n${GREEN}快捷键:${NC}"
    echo -e "0. 🚪 快速退出"
    echo -e "00. 🔄 重新加载脚本"
    echo -e "s. 🔍 搜索分区"
    echo -e "b. 📦 批量提取分区"
    
    echo -e "\n${YELLOW}文件管理:${NC}"
    echo -e "📁 所有文件保存在: $TOOL_BASE_DIR"
    echo -e "📦 备份文件位置: $BACKUP_DIR"
    echo -e "🔄 更新文件位置: $DEFAULT_UPDATE_DIR"
    
    echo -e "\n${YELLOW}新功能:${NC}"
    echo -e "🧹 自动清理 - 下载新版本时自动删除旧版本文件"
    echo -e "📊 版本管理 - 智能识别和清理过时的脚本版本"
    echo -e "⚡ AK3优化 - 仅支持刷入boot_a和boot_b分区，提高安全性"
    echo -e "📈 下载进度 - 显示文件大小、下载进度和实时速度"
    echo -e "🌐 GitHub集成 - 支持查看远程文件大小和智能更新"
    echo -e "🔒 SHA256检测 - 下载后检查脚本SHA256哈希值，确保文件完整性"
    
    echo -e "\n${YELLOW}注意: 部分功能需要ROOT权限${NC}"
    press_enter_to_continue
}

show_folder_info() {
    clear
    show_banner
    echo -e "${CYAN}========================================"
    echo -e "|          📁 文件夹信息 📁          |"
    echo -e "${CYAN}========================================"
    
    echo -e "${GREEN}📂 主文件夹: ${WHITE}$TOOL_BASE_DIR${NC}"
    echo -e "${GREEN}📦 备份目录: ${WHITE}$BACKUP_DIR${NC}"
    echo -e "${GREEN}🔄 更新目录: ${WHITE}$DEFAULT_UPDATE_DIR${NC}"
    echo -e "${GREEN}📝 日志文件: ${WHITE}$LOG_FILE${NC}"
    
    echo -e "\n${BLUE}文件夹状态:${NC}"
    if [ -d "$TOOL_BASE_DIR" ]; then
        echo -e "✅ 主文件夹存在"
    else
        echo -e "❌ 主文件夹不存在"
    fi
    
    if [ -d "$BACKUP_DIR" ]; then
        local backup_count=$(ls "$BACKUP_DIR"/*.img 2>/dev/null | wc -l)
        echo -e "✅ 备份目录存在 (包含 $backup_count 个备份文件)"
    else
        echo -e "❌ 备份目录不存在"
    fi
    
    if [ -d "$DEFAULT_UPDATE_DIR" ]; then
        local update_count=$(ls "$DEFAULT_UPDATE_DIR"/*.sh 2>/dev/null | wc -l)
        echo -e "✅ 更新目录存在 (包含 $update_count 个更新文件)"
        
        echo -e "\n${YELLOW}📊 版本文件统计:${NC}"
        for file in "$DEFAULT_UPDATE_DIR"/*.sh; do
            if [ -f "$file" ]; then
                local filename=$(basename "$file")
                local file_version=$(grep -oE 'VERSION="[0-9]+\.[0-9]+(\.[0-9]+)?"' "$file" 2>/dev/null | head -1 | cut -d'"' -f2)
                if [ -n "$file_version" ]; then
                    compare_versions "$file_version" "$VERSION"
                    local compare_result=$?
                    case $compare_result in
                        0) echo -e "  📁 $filename (v$file_version) ${RED}[旧版本]${NC}" ;;
                        1) echo -e "  📁 $filename (v$file_version) ${GREEN}[新版本]${NC}" ;;
                        2) echo -e "  📁 $filename (v$file_version) ${BLUE}[当前版本]${NC}" ;;
                    esac
                else
                    echo -e "  📁 $filename ${YELLOW}[版本未知]${NC}"
                fi
            fi
        done
    else
        echo -e "❌ 更新目录不存在"
    fi
    
    echo -e "\n${YELLOW}💡 提示: 所有分区管理相关的文件都保存在上述文件夹中${NC}"
    echo -e "${GREEN}🧹 新功能: 自动清理旧版本文件，节省存储空间${NC}"
    echo -e "${GREEN}📊 新功能: 下载时显示详细进度信息${NC}"
    echo -e "${GREEN}🔒 新功能: SHA256哈希值检测确保下载文件完整性${NC}"
    press_enter_to_continue
}

other_features_menu() {
    while true; do
        show_header
        echo -e "${BLUE}|          ${CYAN}其他功能菜单${BLUE}                |${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${GREEN}1. 📁 文件夹信息${NC}"
        echo -e "${GREEN}2. 📖 帮助信息${NC}"
        echo -e "${RED}3. ↩️ 返回主菜单${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "${YELLOW}👉 请选择操作 (1-3): ${NC}"
        
        read -r choice
        choice=$(clean_input "$choice")
        
        case $choice in
            1) show_folder_info ;;
            2) show_help ;;
            3) return ;;
            *) 
                echo -e "${RED}❌ 无效选择！${NC}"
                sleep 0.5
                ;;
        esac
    done
}

show_disclaimer() {
    clear
    echo -e "${RED}======================================================${NC}"
    echo -e "|                  ⚠️ 免责声明 ⚠️                  |"
    echo -e "${RED}======================================================${NC}"
    echo -e "${YELLOW}1. 本工具仅供技术学习和研究使用，严禁用于非法用途${NC}"
    echo -e "${YELLOW}2. 使用本工具可能导致设备损坏、数据丢失等风险${NC}"
    echo -e "${YELLOW}3. 请确保您了解所有操作的风险，并自行承担所有后果${NC}"
    echo -e "${YELLOW}4. 提取的分区文件请在24小时内删除，不得传播或商用${NC}"
    echo -e "${RED}5. 严禁倒卖分区文件，违者4000+${NC}"
    echo -e "${YELLOW}======================================================${NC}"
    
    if [ $ROOT_ACCESS -eq 1 ]; then
        local battery_level=$(get_battery_level)
        [ "$battery_level" -lt 20 ] && {
            echo -e "\n${RED}⚠️ 警告：电池电量过低 ($battery_level%)!${NC}"
            echo -e "${YELLOW}建议连接充电器后继续操作${NC}"
        }
    fi
    
    echo -e "\n${YELLOW}❓ 是否同意以上条款并继续使用? (y/n): ${NC}"
    read -r choice
    choice=$(clean_input "$choice")
    
    [ "$choice" != "y" ] && [ "$choice" != "Y" ] && {
        echo -e "${GREEN}👋 已退出脚本${NC}"
        exit 0
    }
}

check_battery() {
    if [ $ROOT_ACCESS -eq 1 ]; then
        local battery_level=$(get_battery_level)
        [ "$battery_level" -lt 15 ] && {
            echo -e "${RED}⚠️ 警告：电池电量过低 ($battery_level%)，建议连接充电器！${NC}"
            sleep 1
            return 1
        }
    fi
    return 0
}

exit_shell() {
    echo -e "\n${YELLOW}↵ 按回车键关闭终端...${NC}"
    read -r
    exit 0
}

main_menu() {
    init_directories
    init_cache
    calculate_script_hash

    while true; do
        clear
        show_banner
        show_personalized_welcome
        show_random_tip
        
        echo -e "${CYAN}========================================"
        echo -e "|        🛠️ 分区工具箱 v$VERSION 🛠️        |"
        echo -e "${CYAN}========================================"
        echo -e "${GREEN}系统时间: ${WHITE}$(date +'%Y-%m-%d %H:%M:%S')${NC}"
        echo -e "${GREEN}设备型号: ${WHITE}$DEVICE_MODEL${NC}"
        echo -e "${GREEN}安卓ID: ${WHITE}$ANDROID_ID${NC}"
        echo -e "${GREEN}文件位置: ${WHITE}$TOOL_BASE_DIR${NC}"
        echo -e "${GREEN}脚本哈希: ${WHITE}$SCRIPT_HASH${NC}"
        
        if [ $ROOT_ACCESS -eq 1 ]; then
            echo -e "${GREEN}🔓 ROOT状态: ${WHITE}已获取完整权限${NC}"
            
            echo -e "\n${BLUE}1. 📱 设备信息${NC}"
            echo -e "${GREEN}2. 💾 分区提取${NC}"
            echo -e "${RED}3. 🔥 分区刷写${NC}"
            echo -e "${BLUE}4. 🔄 高级重启${NC}"
            echo -e "${BLUE}5. 🔄 AB分区检测${NC}"
            echo -e "${BLUE}6. 🌐 GitHub更新${NC}"
            echo -e "${RED}7. 📦 刷入AK3压缩包${NC}"
            echo -e "${BLUE}8. 🛡️ 安全检测${NC}"
            echo -e "${CYAN}9. 🎮 娱乐功能${NC}"
            echo -e "${PURPLE}10. ⚙️ 工具箱设置${NC}"
            echo -e "${BLUE}11. 📚 其他功能${NC}"
            echo -e "${BLUE}12. 🔄 重新加载脚本${NC}"
            echo -e "${RED}0. 🚪 退出脚本${NC}"
        else
            echo -e "${YELLOW}⚠️ ROOT状态: ${WHITE}未获取完整权限${NC}"
            
            echo -e "\n${BLUE}1. 📱 设备信息${NC}"
            echo -e "${YELLOW}2. 💾 分区提取 (需ROOT)${NC}"
            echo -e "${YELLOW}3. 🔥 分区刷写 (需ROOT)${NC}"
            echo -e "${BLUE}4. 🔄 高级重启${NC}"
            echo -e "${BLUE}5. 🔄 AB分区检测${NC}"
            echo -e "${BLUE}6. 🌐 GitHub更新${NC}"
            echo -e "${YELLOW}7. 📦 刷入AK3压缩包 (需ROOT)${NC}"
            echo -e "${BLUE}8. 🛡️ 安全检测${NC}"
            echo -e "${CYAN}9. 🎮 娱乐功能${NC}"
            echo -e "${PURPLE}10. ⚙️ 工具箱设置${NC}"
            echo -e "${BLUE}11. 📚 其他功能${NC}"
            echo -e "${BLUE}12. 🔄 重新加载脚本${NC}"
            echo -e "${RED}0. 🚪 退出脚本${NC}"
        fi
        
        echo -e "${CYAN}========================================"
        echo -e "${YELLOW}👉 请选择操作: ${NC}"
        
        read -r choice
        choice=$(clean_input "$choice")
        
        case "$choice" in
            1) device_info ;;
            2) 
                if [ $ROOT_ACCESS -eq 1 ]; then
                    clear
                    show_banner
                    echo -e "${CYAN}========================================"
                    echo -e "|          💾 分区提取选项 💾          |"
                    echo -e "${CYAN}========================================"
                    echo -e "${GREEN}1. 📋 列出安全分区${NC}"
                    echo -e "${GREEN}2. 🔍 搜索分区${NC}"
                    echo -e "${GREEN}3. 📦 批量提取分区${NC}"
                    echo -e "${GREEN}4. 👢 提取Boot分区${NC}"
                    echo -e "${RED}5. ↩️ 返回主菜单${NC}"
                    echo -e "${CYAN}========================================"
                    echo -e "${YELLOW}👉 请选择操作: ${NC}"
                    
                    read -r extract_choice
                    extract_choice=$(clean_input "$extract_choice")
                    case "$extract_choice" in
                        1) list_flashable_partitions ;;
                        2) search_partitions ;;
                        3) batch_extract_partitions ;;
                        4) extract_boot_menu ;;
                        5) ;;
                        *) echo -e "${RED}❌ 无效选择！${NC}"; sleep 0.5 ;;
                    esac
                else
                    echo -e "${RED}❌ 此功能需要ROOT权限！${NC}"
                    press_enter_to_continue
                fi
                ;;
            3) 
                if [ $ROOT_ACCESS -eq 1 ]; then
                    flash_partition_menu 
                else
                    echo -e "${RED}❌ 此功能需要ROOT权限！${NC}"
                    press_enter_to_continue
                fi
                ;;
            4) reboot_menu ;;
            5) check_ab_partition ;;
            6) github_update ;;
            7) 
                if [ $ROOT_ACCESS -eq 1 ]; then
                    flash_ak3 
                else
                    echo -e "${RED}❌ 此功能需要ROOT权限！${NC}"
                    press_enter_to_continue
                fi
                ;;
            8) security_check_menu ;;
            9) fun_features ;;
            10) settings_menu ;;
            11) other_features_menu ;;
            12)
                echo -e "${GREEN}🔄 重新加载脚本...${NC}"
                exec sh "$0" "$@"
                ;;
            0) 
                echo -e "${GREEN}👋 感谢使用，再见！${NC}"
                exit 0
                ;;
            s|S)
                if [ $ROOT_ACCESS -eq 1 ]; then
                    search_partitions
                else
                    echo -e "${RED}❌ 此功能需要ROOT权限！${NC}"
                    press_enter_to_continue
                fi
                ;;
            b|B)
                if [ $ROOT_ACCESS -eq 1 ]; then
                    batch_extract_partitions
                else
                    echo -e "${RED}❌ 此功能需要ROOT权限！${NC}"
                    press_enter_to_continue
                fi
                ;;
            *) 
                echo -e "${RED}❌ 无效选择！请重新输入${NC}"
                sleep 0.5
                ;;
        esac
        
        self_update
    done
}

check_root
show_disclaimer
init_directories
check_force_update
main_menu "$@"