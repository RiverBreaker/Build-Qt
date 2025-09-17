install_ver_pkgs() {
  # 没有参数就报错
  ((${#@} == 0)) && { echo "Usage: install_ver_pkgs pkg1 pkg2 ..." >&2; return 1; }

  sudo apt-get update || return

  # 收集所有匹配到的包（去重）
  local -A seen          # 关联数组，用来去重
  for full in "$@"; do
    local suffix=${full##*-[0-9]}
    local prefix=${full%%[0-9]*}
    [ -z "$suffix" ] && suffix=""
    local regex="^${prefix}[0-9]+${suffix}$"

    # 把本次搜到的包加入 seen
    while read -r pkg; do
      [[ $pkg ]] && seen[$pkg]=1
    done < <(apt-cache search "$regex" | awk '{print $1}')
  done

  ((${#seen[@]} == 0)) && { echo "No packages found for templates: $*" >&2; return 1; }

  # 排序 + 安装
  local pkgs=($(printf '%s\n' "${!seen[@]}" | sort -V))
  echo "Going to install:"
  printf '  %s\n' "${pkgs[@]}"
  sudo apt-get install "${pkgs[@]}"
}