install_ver_pkgs() {
  ((${#@} == 0)) && { echo "Usage: install_ver_pkgs pkg1 pkg2 ..." >&2; return 1; }
  sudo apt-get update || return

  local -A seen
  for full in "$@"; do
    # 如果模板里本身没有数字，就当成“前后缀”已给全
    if [[ $full != *[0-9]* ]]; then
      # 找到最后一个 "-" 位置，把前面当前缀，后面当后缀
      local prefix=${full%-*} suffix=${full##*-}
      # 如果根本没有 "-"，就整个当前缀，后缀置空
      [[ $prefix == "$full" ]] && { prefix=$full; suffix=""; }
      regex="^${prefix}-[0-9]+${suffix:+-}${suffix}$"
    else
      # 原来逻辑：模板里含数字，按老办法拆
      local suffix=${full##*-[0-9]} prefix=${full%%[0-9]*}
      [[ -z $suffix ]] && suffix=""
      regex="^${prefix}[0-9]+${suffix}$"
    fi

    while read -r pkg; do
      [[ $pkg ]] && seen[$pkg]=1
    done < <(apt-cache search "$regex" | awk '{print $1}' | sort -Vr | head -n 5)
  done

  ((${#seen[@]} == 0)) && { echo "No packages found for templates: $*" >&2; return 1; }
  local pkgs=($(printf '%s\n' "${!seen[@]}" | sort -V))
  echo "Going to install:"
  printf '  %s\n' "${pkgs[@]}"
  sudo apt-get install "${pkgs[@]}"
  sudo apt-get clean
}