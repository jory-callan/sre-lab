#!/bin/bash
set -euo pipefail

# 进入脚本所在目录
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"
NOW_TIME=$(date +'%Y-%m-%d %H:%M:%S')

# === 日志函数（中文输出）===
USE_COLOR=false  # 流水线日志建议关闭颜色

if [[ "$USE_COLOR" == true ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
  RED=''; GREEN=''; BLUE=''; YELLOW=''; NC=''
fi

log_raw() {
  local level="$1"; shift
  local color="$1"; shift
  local msg="$*"
  local now
  now=$(date +'%Y-%m-%d %H:%M:%S')
  if [[ "$USE_COLOR" == true ]]; then
    echo -e "${color}[${now}] [${level}]${NC} $msg" >&2
  else
    echo "[${now}] [${level}] $msg" >&2
  fi
}

log_info()    { log_raw "INFO"    "$BLUE"   "$@"; }
log_warn()    { log_raw "WARN"    "$YELLOW" "$@"; }
log_error()   { log_raw "ERROR"    "$RED"    "$@"; }
log_success() { log_raw "SUCCESS"    "$GREEN"  "$@"; }



# 从 Git 地址提取路径：git@xxx.com/hashxxxxx/groupA/projectA/api.git → groupA/projectA/api
extract_git_path() {
    local git_repo="$1"
    local path
    # 移除开头的协议部分（git@xxx.com: 或 https://xxx.com  /）
    # 然后移除末尾的 .git 和可能的斜杠
    if [[ "$git_repo" =~ (git@[^:]+:|https?://[^/]+/)(.+)$ ]]; then
        # 提取路径部分，然后移除 .git 后缀和末尾斜杠
        path="${BASH_REMATCH[2]}"
    else
        # 如果格式不匹配，则移除 .git 后缀和末尾斜杠后返回
        echo "${git_repo%.git}" | sed 's:/*$::'
    fi
    # 使用 sed 删除第一个斜杠之前的部分
    local result=$(echo "$path" | sed 's:^[^/]*/::')
    # 移除 .git 后缀和末尾斜杠
    echo "${result%.git}" | sed 's:/*$::'
}

# === 路径处理函数 ===
# 转换相对路径为绝对路径
resolve_path() {
    local path="$1"
    local base_dir="${2:-$SCRIPT_DIR}"
    
    if [[ "$path" == /* ]]; then
        # 绝对路径直接返回
        echo "$path"
    else
        # 相对路径基于 base_dir 转换
        echo "$(cd "$base_dir" && realpath "$path")"
    fi
}

# ========== 变量 ==========
# common
# GIT_REPO="${GIT_REPO:-}"
# GIT_BRANCH="${GIT_BRANCH:-test}"
# GIT_COMMIT_ID="${GIT_COMMIT_ID:-origin/$GIT_BRANCH}" # 如果是空白则默认是 origin/$GIT_BRANCH ,为了不报错，兼容性更强，需要执行 git fetch && git reset $GIT_COMMIT_ID 指令
# PROJECT_TYPE="${PROJECT_TYPE:-php}"  # php: php环境可选构建  |  vue nodejs 环境使用 nvm 构建  |  uniapp 使用git仓库里面的.zip压缩包
# PROJECT_PATH="${PROJECT_PATH:-}"     # 默认是一层,我们的风格是采用域名. 如果这个项目是需要放置在指定目录,那么这里填写多层路径即可
# SOURCE_ROOT_PATH="${SOURCE_ROOT_PATH:-/data/apps/sourcecode}"
# TARGET_ROOT_PATH="${TARGET_ROOT_PATH:-/data/apps/deploycode}"
# ENV="${ENV:-test}" # 环境 prod test   
# # php 项目
# PHP_VERSION="${PHP_VERSION:-7.4}" # 只需要两层，第三层不要写
# PHP_BUILD_CMD="${PHP_BUILD_CMD:-composer install --optimize-autoloader}" # 只需要两层，第三层不要写
# # nodejs 项目
# NODE_VERSION="${NODE_VERSION:-20}" # 采用 nvm 管理多 node 环境。自己制作的镜像
# NODE_BUILD_CMD="${NODE_BUILD_CMD:-npm build:test}" # 只需要两层，第三层不要写
# # uniapp 项目, 适用于任何提供, zip压缩包的部署方式
# UNIAPP_DIST="${UNIAPP_DIST:-dist/dist.zip}" # uniapp git仓库的压缩包的路径, 统一采用 zip 格式
# UNIAPP_INDEX="${UNIAPP_INDEX:-index.html}"   # 根目录存在且唯一的文件，也就是根目录文件。由于打包方式不同，因此需要确保以找到根路径文件为主
# # docker
# USE_DOCKER="${USE_DOCKER:-true}" # 默认采用 docker 模式进行操作，不论是 git 拉代码 还是 构建应用都采用docker完成，可以实现环境隔离。
# DOCKER_IMAGE_PHP_COMPOSER="${DOCKER_IMAGE_PHP_COMPOSER:-phpfpm:${PHP_VERSION}}"  # 配置文件 my-global-composer.json:/tmp/composer.json   程序路径  $(pwd):/app  缓存 ~/.composer:/tmp
# DOCKER_IMAGE_NODE="${DOCKER_IMAGE_NODE:-node:$NODE_VERSION-alpine}" # 只写前缀后缀就是下面的VERSION拼接
# DOCKER_IMAGE_GIT="${DOCKER_IMAGE_GIT:-alpine/git:latest}" # git 采用最新版本的git
# # hosts
# TARGET_HOSTS="${TARGET_HOSTS:-}" # 自己定义好的字符串, 通过 case 获取指定的数组存储的主机ip地址，然后批量 rsync 即可
# # 授权目录用户
# CHOWN_CMD="${CHOWN_CMD:-www-data:www-data}"

# === 可选变量默认值 ===
set_var() {
     # 如果 bash 版本小于 4.3, 则不支持名字引用, 直接返回
    if [[ "${BASH_VERSION%%.*}" -lt 4 || ( "${BASH_VERSION%%.*}" -eq 4 && "${BASH_VERSION##*.}" -lt 3 ) ]]; then
      local var_name="$1"
      local default_value="$2"
      # 如果为空则使用默认值
      local value="${!var_name:-$default_value}"
      # 去掉末尾的斜杠 /
      value="${value%/}"
      # 打印处理后的值
      echo "set env by eval => ${var_name} = \"${value}\""
      eval "${var_name}=\"\${value}\""
    fi
    # -n 表示 var_name 是一个“名字引用”, 相当于一个指向变量的指针, 需要 Bash 4.3+
    local -n var_name="$1"
    local default_value="$2"
    # 如果为空则使用默认值
    var_name="${var_name:-$default_value}"
    # 去掉末尾的斜杠 /
    var_name="${var_name%/}"
    # 打印处理后的值
    echo "set env by local -n => $1 = \"${var_name}\""
}
# --- 使用 set_var 函数进行配置 ---
set_var "GIT_REPO" ""
set_var "GIT_BRANCH" "test"
set_var "GIT_COMMIT_ID" "origin/$GIT_BRANCH"  # 注意：这里会使用上面 GIT_BRANCH 的值
set_var "PROJECT_TYPE" "php"
set_var "PROJECT_PATH" ""
set_var "SOURCE_ROOT_PATH" "/data/apps/sourcecode"
set_var "TARGET_ROOT_PATH" "/data/apps/deploycode"
set_var "PHP_VERSION" "7.4"
set_var "PHP_BUILD_CMD" "composer install --optimize-autoloader"
set_var "NODE_VERSION" "20"
set_var "NODE_BUILD_CMD" "npm build:test"
set_var "UNIAPP_DIST" "dist/dist.zip"
set_var "UNIAPP_INDEX" "index.html"
set_var "USE_DOCKER" "true"
set_var "DOCKER_IMAGE_PHP_COMPOSER" "phpfpm:${PHP_VERSION}"
set_var "DOCKER_IMAGE_NODE" "node:$NODE_VERSION-alpine"  # 注意：这里会使用上面 NODE_VERSION 的值
set_var "DOCKER_IMAGE_GIT" "alpine/git:latest"
set_var "TARGET_HOSTS" ""
set_var "CHOWN_CMD" "www-data:www-data"

# === 必填变量校验 ===
print_env_vars() {
required_vars=(
  "GIT_REPO"
  "GIT_BRANCH"
  "SOURCE_ROOT_PATH"
  "TARGET_ROOT_PATH"
  "PROJECT_TYPE"
  "PROJECT_PATH"
)

for var in "${required_vars[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    log_error "缺失必要环境变量: $var"
    exit 1
  fi
done
}
# 目标路径
SOURCE_DIR="${SOURCE_ROOT_PATH}/$(extract_git_path ${GIT_REPO})"   # xxxx是从 git 路径解析到的项目
TARGET_DIR="${TARGET_ROOT_PATH}/${PROJECT_PATH}"   # xxxx是 PROJECT_NAME
mkdir -p "${TARGET_DIR}" "${SOURCE_DIR}"
SOURCE_DIR=$(resolve_path "${SOURCE_DIR}")
TARGET_DIR=$(resolve_path "${TARGET_DIR}")
set_var "SOURCE_DIR" "${SOURCE_DIR}"
set_var "TARGET_DIR" "${TARGET_DIR}"


# 打印所有变量
# log_info "=== 所有环境变量 ==="
# for var in $(compgen -e); do
#     log_info "$var=${!var}"
# done

# Git 操作函数（支持 Docker）
git_operation() {
  local cmd="$1"
  shift
  local exit_code=0

  if [[ "${USE_DOCKER}" == "true" ]]; then
    # 使用 Docker 执行 Git 命令
    docker run  --rm \
      --cpus="2" -m="4g" \
      -v "${HOME}/.ssh:${HOME}/.ssh" \
      -v "${SOURCE_DIR}:${SOURCE_DIR}" \
      -w "${SOURCE_DIR}" \
      "${DOCKER_IMAGE_GIT}" \
      "${cmd}" "$@"
      exit_code=$?
  else
    # 使用本地 Git
    git "${cmd}" "$@"
    exit_code=$?
  fi

  return $exit_code
}

# Composer 操作函数（支持 Docker）
composer_operation() {
  local cmd="$1"
  shift
  local exit_code=0

  if [[ "$USE_DOCKER" == "true" ]]; then
    # 使用 Docker 执行 Composer 命令
    docker run  --rm \
      --cpus="2" -m="4g" \
      -v "${TARGET_DIR}:/app" \
      -v "${HOME}/.composer:${HOME}/.composer" \
      -v "${HOME}/.composer.json:${HOME}/.composer/config.json" \
      -w "/app" \
      "${DOCKER_IMAGE_PHP_COMPOSER}" \
      sh -c " set -e; $cmd"
      exit_code=$?
  else
    # 使用本地 Composer
    eval "$cmd"
    exit_code=$?
  fi

  return $exit_code
}
# Node 操作函数（支持 Docker）
node_operation() {
  local cmd="$1"
  shift
  local exit_code=0

  if [[ "$USE_DOCKER" == "true" ]]; then
    # 使用 Docker 执行 Node 命令
    docker run  --rm \
      --cpus="2" -m="4g" \
      -v "${HOME}/.npmrc:${HOME}/.npmrc" \
      -v "${HOME}/.npm:${HOME}/.npm" \
      -v "${SOURCE_DIR}:/app" \
      -w "/app" \
      "${DOCKER_IMAGE_NODE}" \
      sh -c " set -e; $cmd"
      exit_code=$?
  else
    # 使用本地 Node
    eval "$cmd"
    exit_code=$?
  fi

  return $exit_code
}

# uniapp 不一样, 无法构建 , 只能通过 git 仓库的 zip 压缩包进行部署
uniapp_operation() {
    local zipfile="$1"
    local target_dir="$2"
    local index="${3:-index.html}"  # 定义要检查的文件, 默认为 index.html
    
    # 校验 zipfile 是否存在
    if [[ ! -f "$zipfile" ]]; then
        log_error "zipfile 不存在: $zipfile"
        exit 1
    fi
    
    # 创建临时目录解压
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT # 确保临时目录被清理
    unzip -oq "$zipfile" -d "$temp_dir" || {
        log_error "解压失败"
        exit 1
    }
    local index_path=$(find "$temp_dir" -type f -name "$index")
    local count=$(echo "$index_path" | wc -l)
    if [[ "$count" -eq 0 ]]; then
        log_error "未找到 $index 文件"
        exit 1
    fi
    if [[ "$count" -gt 1 ]]; then
        log_error "发现 ${count} 个 $index 文件，结构不可靠，请检查压缩包"
        exit 1
    fi
    local source_dir=$(dirname "$index_path")
    mv "$source_dir"/*  "$target_dir"
    chown -R "$CHOWN_CMD" "$target_dir"
}


# rsync 同步代码到目标目录
rsync_code() {
  local source="$1"
  local target="$2"
  if [[ ! -d "$source" ]]; then
    log_error "源目录不存在: $source"
    exit 1
  fi
  # 如果 $1 $2 用 / 结尾则去掉
  source="${source%/}"
  target="${target%/}"

  if [[ -d ${PHP_BUILD_CMD} ]]; then
    rsync -a \
      --chmod=755 \
      --exclude=".git" \
      --exclude="*.log" \
      --exclude=".env" \
      --exclude="node_modules" \
      --exclude="vendor" \
      "${source}/" "${target}/"
  else
    rsync -a \
      --chmod=755 \
      --exclude=".git" \
      --exclude="*.log" \
      --exclude=".env" \
      --exclude="node_modules" \
      "${source}/" "${target}/"
  fi
  # log_info "rsync 完成"

}

# git 克隆/更新代码
git_pull_code() {
  if [[ -d "$SOURCE_DIR/.git" ]]; then
    log_info "更新已有仓库..."
    cd "$SOURCE_DIR"
    #git_operation fetch origin "$GIT_BRANCH"
    git_operation fetch origin 
    git_operation checkout -B  "${GIT_BRANCH}"  "origin/${GIT_BRANCH}"
    git_operation reset --hard ${GIT_COMMIT_ID}
  else
    log_info "克隆仓库 (分支: $GIT_BRANCH)..."
    git_operation clone --depth 1 --branch "$GIT_BRANCH" "$GIT_REPO" "$SOURCE_DIR"
  fi

  cd "$SOURCE_DIR"
  # 添加子仓库的支持
  git submodule update --init --recursive --force

}

# ==== 部署 php 代码 ====
build_php() {
  log_info "开始构建 PHP 代码..."
  git_pull_code
  log_info "开始同步代码到目录... ${SOURCE_DIR} -> ${TARGET_DIR}"
  cd ${SOURCE_DIR}
  rsync_code "${SOURCE_DIR}/" "${TARGET_DIR}/"
  cd ${TARGET_DIR}
  # # 如果 PHP_BUILD_CMD 为空, 则不安装依赖
  # if [[ -z "$PHP_BUILD_CMD" ]]; then
  #   log_info "PHP_BUILD_CMD 为空, 则不安装依赖..."
  # else
  # 如果 vendor 目录不存在, 则安装依赖
  if [[ ! -d "${TARGET_DIR}/vendor" ]]; then
    # 推荐的安装指令 composer install --optimize-autoloader
    log_info "目标文件夹 ${TARGET_DIR}/vendor 目录不存在, 开始安装依赖..."
    log_info "开始执行 Composer 安装: ${PHP_BUILD_CMD}..."
    composer_operation "${PHP_BUILD_CMD}"
    log_success "PHP 代码构建完成!, 目标目录: ${TARGET_DIR}"
  fi
  log_success "PHP vendor 目录存在，跳过构建。目标目录: ${TARGET_DIR}"
}
deploy_php() {
  local servers=("$@")
  log_info "开始部署 PHP 代码..."  
  # 校验主机数组是否为空
  if [[ -z "${servers[@]}" ]]; then
    log_error "主机数组为空, 请检查 TARGET_HOSTS 变量配置."
    exit 1
  fi
  cd "${TARGET_DIR}"
  echo "${servers[@]}"
  # 遍历主机数组, 并批量 rsync 部署
  for server in "${servers[@]}"; do
    log_info "开始部署到 $server... ${TARGET_DIR}/ -> $server:${TARGET_DIR}/"
    # 校验目标目录是否存在
    execute_remote_cmd "$server" "mkdir -p $TARGET_DIR"
    rsync_code "${TARGET_DIR}/" "$server:$TARGET_DIR/"
    execute_remote_cmd "$server" "chown -R ${CHOWN_CMD} $TARGET_DIR"
  done
  log_success "PHP 代码部署完成!, 目标服务器: ${servers[@]}"
  log_success "PHP 代码部署完成!, 目标目录: ${TARGET_DIR}"
}

# ==== 部署 node 代码 ====
build_node() {
  log_info "开始构建 Node 代码..."
  git_pull_code
  cd "${SOURCE_DIR}"
  log_info "开始执行 Node 构建: ${NODE_BUILD_CMD}... "
  node_operation " npm install && ${NODE_BUILD_CMD} "
  log_info "Node 构建完成!"
  # 校验 dist 目录是否存在
  if [[ ! -d "${SOURCE_DIR}/dist" ]]; then
    log_error "dist 目录不存在, 请检查 Node 构建是否成功."
    exit 1
  fi
  log_info "开始同步 Node 代码到目录... ${SOURCE_DIR}/dist -> ${TARGET_DIR}"
  cd ${SOURCE_DIR}
  rsync_code "${SOURCE_DIR}/dist/" "${TARGET_DIR}/"
  log_success "Node 代码构建完成!, 目标目录: ${TARGET_DIR}"
}
deploy_node() {
  log_info "开始部署 Node 代码..."
  local servers="$1"
  # 校验主机数组是否为空
  if [[ -z "${servers[@]}" ]]; then
    log_error "主机数组为空, 请检查 TARGET_HOSTS 变量配置."
    exit 1
  fi
  cd "${TARGET_DIR}"

  # 遍历主机数组, 并批量 rsync 部署
  for server in "${servers[@]}"; do
    log_info "开始部署到 $server..."
    # 校验目标目录是否存在
    execute_remote_cmd "$server" "mkdir -p $TARGET_DIR"
    rsync_code "${TARGET_DIR}/" "$server:$TARGET_DIR/"
    execute_remote_cmd "$server" "chown -R ${CHOWN_CMD} $TARGET_DIR"
  done

  log_success "Node 代码部署完成!, 目标服务器: ${servers[@]}"
  log_success "Node 代码部署完成!, 目标目录: ${TARGET_DIR}"
}

# ==== 部署 uniapp 代码 ====
build_uniapp() {
  log_info "开始构建 UniApp 代码..."
  
  # 创建临时目录解压
  local temp_dir=$(mktemp -d)
  trap "rm -rf $temp_dir" EXIT  # 确保临时目录被清理
  
  git_pull_code
  cd "${SOURCE_DIR}"
  log_info "开始执行 UniApp 构建:..."
  # 1: dist 文件路径 2: 构建输出目录 3: index.html 路径
  uniapp_operation "${SOURCE_DIR}/${UNIAPP_DIST}" "${temp_dir}" "${UNIAPP_INDEX}"
  log_info "UniApp 构建完成!"
  rsync_code "${temp_dir}/" "${TARGET_DIR}/"
  log_success "UniApp 代码构建完成!, 目标目录: ${TARGET_DIR}"
}

deploy_uniapp() {
  log_info "开始部署 UniApp 代码..."
  local servers="$1"
  # 校验主机数组是否为空
  if [[ -z "${servers[@]}" ]]; then
    log_error "主机数组为空, 请检查 TARGET_HOSTS 变量配置."
    exit 1
  fi
  cd "${TARGET_DIR}"

  # 遍历主机数组, 并批量 rsync 部署
  for server in "${servers[@]}"; do
    log_info "开始部署到 $server..."
    # 校验目标目录是否存在
    execute_remote_cmd "$server" "mkdir -p $TARGET_DIR"
    rsync_code "${TARGET_DIR}/" "$server:$TARGET_DIR/"
    execute_remote_cmd "$server" "chown -R ${CHOWN_CMD} $TARGET_DIR"
  done

  log_success "UniApp 代码部署完成!, 目标服务器: ${servers[@]}"
  log_success "UniApp 代码部署完成!, 目标目录: ${TARGET_DIR}"
}


# 主机组数组, 通过 TARGET_HOSTS 变量获取指定的主机组数组
jxsh_web_1=(
  "121.40.237.246"
)
jxsh_web_2=(
  "120.26.70.101"
)
jxsh_fz_bt=(
  "47.110.151.155"
)
jxsh_im=(
  "47.97.76.17"
)
jxsh_lottery=(
  "118.178.59.216"
)
jxsh_sns=(
  "121.41.94.80"
)
im_server=(
  "114.55.148.164"
)
bfa=(
  "120.55.242.59"
)
bfa_k3s_servers=(
  "121.43.27.82"
  "114.55.15.87"
  "120.26.181.99"
)

get_servers() {
  local group_name="$1"
  case "$group_name" in
    "jxsh_web_1")
      log_info "采用 jxsh_web_1"
      log_info "jxsh_web_1: ${jxsh_web_1[@]}"
      echo "${jxsh_web_1[@]}"
      ;;
    "jxsh_web_2")
      log_info "采用 jxsh_web_2"
      log_info "jxsh_web_2: ${jxsh_web_2[@]}"
      echo "${jxsh_web_2[@]}"
      ;;
    "jxsh_fz_bt")
      log_info "采用 jxsh_fz_bt"
      log_info "jxsh_fz_bt: ${jxsh_fz_bt[@]}"
      echo "${jxsh_fz_bt[@]}"
      ;;
    "jxsh_im")
      log_info "采用 jxsh_im" 
      log_info "jxsh_im: ${jxsh_im[@]}"
      echo "${jxsh_im[@]}"
      ;;
    "jxsh_lottery")
      log_info "采用 jxsh_lottery"
      log_info "jxsh_lottery: ${jxsh_lottery[@]}"
      echo "${jxsh_lottery[@]}"
      ;;
    "jxsh_sns")
      log_info "采用 jxsh_sns"
      log_info "jxsh_sns: ${jxsh_sns[@]}"
      echo "${jxsh_sns[@]}"
      ;;
    "im_server")
      log_info "采用 im_server"
      log_info "im_server: ${im_server[@]}"
      echo "${im_server[@]}"
      ;;
    "bfa")
      log_info "采用 bfa"
      log_info "bfa: ${bfa[@]}"
      echo "${bfa[@]}"
      ;;
    "bfa_k3s_servers")
      log_info "采用 bfa_k3s_servers"
      log_info "bfa_k3s_servers: ${bfa_k3s_servers[@]}"
      echo "${bfa_k3s_servers[@]}"
      ;;
    *)
      log_error "未知的主机组: $group_name"
      exit 1
      ;;
  esac
}




execute_remote_cmd() {
  local server="$1"
  local cmd="$2"
  # local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes -q"
  # local ssh_opts="-o ConnectTimeout=10 -o BatchMode=yes -q"

  # 校验主机是否为空
  if [[ -z "$server" ]]; then
    log_error "主机为空, 请检查 TARGET_HOSTS 变量配置."
    exit 1
  fi
  # 校验命令是否为空
  if [[ -z "$cmd" ]]; then
    log_error "命令为空, 请检查命令配置."
    exit 1
  fi
  log_info "开始执行命令 $cmd 到 $server..."
  # ssh $ssh_opts "$server" "bash -c \"$cmd\""
  ssh  "$server" "$cmd"
}


main() {
  print_env_vars
  case "${PROJECT_TYPE}" in
    "php")
      build_php
      server_list=($(get_servers "$TARGET_HOSTS"))
      deploy_php "${server_list[@]}"
      ;;
    "node")
      build_node
      server_list=($(get_servers "$TARGET_HOSTS"))
      deploy_node "${server_list[@]}"
      ;;
    "uniapp")
      build_uniapp
      server_list=($(get_servers "$TARGET_HOSTS"))
      deploy_uniapp "${server_list[@]}"
      ;;
    *)
      log_error "未知的项目类型: $PROJECT_TYPE"
      exit 1
      ;;
  esac
}

main
