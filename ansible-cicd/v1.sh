# ================= 全局控制 =================
USE_DOCKER: false                     # 全局：是否使用 Docker 执行 Git / Build
DOCKER_IMAGE_GIT: "alpine/git"        # Git 使用的 Docker 镜像（如 USE_DOCKER=true）
DOCKER_IMAGE_PHP: "php:7.4-fpm"
DOCKER_IMAGE_NODE: "node:16-alpine"

# ================= 路径策略 =================
# 源码目录（固定规则，与环境无关）
SOURCECODE_ROOT: "/data/sourcecode"
# 制品目录 & 部署目录共用 PATH_MODE
PATH_MODE: "domain"                   # domain | project
BUILD_ROOT: "/data/deploycode"
DEPLOY_ROOT: "/data/www"

# domain 模式所需变量
DEPLOY_DOMAIN: "ims.example.com"
# project 模式所需变量（当 PATH_MODE=project 时使用，可从 GIT_REPO 自动解析）
# PROJECT_PATH: "ims/ims-management"   # 自动解析，不必手写

# ================= Git 源配置 =================
GIT_REPO: "https://codeup.aliyun.com/63d89ae93a/ims/ims-management.git"
GIT_BRANCH: "main"
GIT_COMMIT_ID: "a1b2c3d"              # 可选

# ================= 语言构建配置（前缀区分） =================
# PHP
php_build_enabled: true
php_version: "7.4"
php_build_command: >-
  composer config audit.block-insecure false &&
  composer config -g process-timeout 600 &&
  composer install --optimize-autoloader
php_build_excludes: []                 # 额外 rsync 排除项

# Node.js / Vue
node_build_enabled: false
node_version: "16"
node_build_command: "npm i && npm run build:prod"

# H5 (ZIP 静态包)
h5_enabled: false
h5_zip_need_unzip: true
h5_zip_file_path: "dist/dist.zip"     # 仓库内相对路径
h5_zip_unique_index_file: "index.html"

# ================= 部署策略 =================
DEPLOY_STRATEGY: "rsync"              # copy | rsync
DEPLOY_EXCLUDES:                      # 列表形式，比逗号好处理
  - "node_modules"
  - ".git"
  - "vendor"
# 如需追加语言特定排除，可在任务中合并 php_build_excludes