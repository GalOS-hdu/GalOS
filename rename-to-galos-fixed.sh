#!/bin/bash
#
# 修复版：将项目从 StarryOS 重命名为 GalOS
#
# 使用方法：
#   ./rename-to-galos-fixed.sh [--dry-run]
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false
LOG_FILE="rename.log"

# 解析参数
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Usage: $0 [--dry-run]"
            exit 1
            ;;
    esac
done

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# 初始化日志
echo "=== Rename Script Log ===" > "$LOG_FILE"
echo "Date: $(date)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

info "开始项目重命名：StarryOS → GalOS"

if [ "$DRY_RUN" = true ]; then
    warning "运行在 DRY-RUN 模式，不会实际修改文件"
fi

# 检查是否在项目根目录
if [ ! -f "Cargo.toml" ] || [ ! -f "Dockerfile" ]; then
    error "请在项目根目录下运行此脚本"
    exit 1
fi

# 定义替换函数
replace_in_file() {
    local file=$1
    local old=$2
    local new=$3
    local description=$4

    if [ ! -f "$file" ]; then
        warning "文件不存在: $file"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        if grep -q "$old" "$file" 2>/dev/null; then
            info "[DRY-RUN] 将在 $file 中替换: $description"
            echo "  匹配的行："
            grep -n "$old" "$file" | head -3 | sed 's/^/    /'
        fi
    else
        if grep -q "$old" "$file" 2>/dev/null; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s|$old|$new|g" "$file"
            else
                sed -i "s|$old|$new|g" "$file"
            fi
            success "✓ 已修改 $file: $description"
        fi
    fi
}

info "开始替换文件内容..."
echo ""

# 1. Cargo.toml - 修改 package name
replace_in_file "Cargo.toml" \
    '^name = "starry"' \
    'name = "galos"' \
    "package name: starry → galos"

# 2. Docker Compose - 服务名、镜像名、容器名、路径
replace_in_file "docker-compose.yml" \
    'starryos-dev' \
    'galos-dev' \
    "Docker service name"

replace_in_file "docker-compose.yml" \
    'starryos-ci' \
    'galos-ci' \
    "Docker CI service name"

replace_in_file "docker-compose.yml" \
    '/workspace/StarryOS' \
    '/workspace/GalOS' \
    "workspace path"

# 3. Dockerfile - 标签和描述
replace_in_file "Dockerfile" \
    'StarryOS Development Environment' \
    'GalOS Development Environment' \
    "Dockerfile comment"

replace_in_file "Dockerfile" \
    'StarryOS Team' \
    'GalOS Team' \
    "maintainer label"

replace_in_file "Dockerfile" \
    'StarryOS Development Environment with' \
    'GalOS Development Environment with' \
    "description label"

# 4. GitHub Actions
replace_in_file ".github/workflows/docker-ci.yml" \
    'starryos-dev' \
    'galos-dev' \
    "CI container name"

replace_in_file ".github/workflows/docker-ci.yml" \
    'Build StarryOS' \
    'Build GalOS' \
    "CI job name"

# 5. 环境配置脚本
replace_in_file "setup-env.sh" \
    'StarryOS Environment Setup' \
    'GalOS Environment Setup' \
    "setup script title"

replace_in_file "setup-env.sh" \
    'starryos-dev' \
    'galos-dev' \
    "setup script container name"

# 6. README.md
if [ -f "README.md" ]; then
    replace_in_file "README.md" \
        '# Starry OS' \
        '# GalOS' \
        "README title"

    replace_in_file "README.md" \
        'StarryOS' \
        'GalOS' \
        "README content"
fi

# 7. 文档文件
for doc in docs/docker-guide.md docs/environment-requirements.md docs/x11.md; do
    if [ -f "$doc" ]; then
        replace_in_file "$doc" \
            'StarryOS' \
            'GalOS' \
            "documentation"

        replace_in_file "$doc" \
            'starryos-dev' \
            'galos-dev' \
            "container name in docs"

        replace_in_file "$doc" \
            'starryos-ci' \
            'galos-ci' \
            "CI container in docs"

        replace_in_file "$doc" \
            '/workspace/StarryOS' \
            '/workspace/GalOS' \
            "workspace path in docs"
    fi
done

# 8. 上传相关文档
for doc in UPLOAD_TO_ORGANIZATION.md QUICK_START_UPLOAD.md TEAM_UPLOAD_CHECKLIST.md DOCKER_MIGRATION_GUIDE.md; do
    if [ -f "$doc" ]; then
        replace_in_file "$doc" \
            'StarryOS' \
            'GalOS' \
            "$doc content"

        replace_in_file "$doc" \
            'starryos-dev' \
            'galos-dev' \
            "$doc container name"

        replace_in_file "$doc" \
            '/workspace/StarryOS' \
            '/workspace/GalOS' \
            "$doc workspace path"
    fi
done

# 验证修改
if [ "$DRY_RUN" = false ]; then
    echo ""
    info "验证修改结果..."

    # 检查 Cargo.toml
    if grep -q '^name = "galos"' Cargo.toml 2>/dev/null; then
        success "✓ Cargo.toml package name 已更新为 'galos'"
    else
        warning "⚠ Cargo.toml package name 可能未正确更新，请手动检查"
    fi

    # 检查 docker-compose.yml
    if grep -q 'galos-dev' docker-compose.yml 2>/dev/null; then
        success "✓ docker-compose.yml 已更新"
    else
        warning "⚠ docker-compose.yml 可能未正确更新"
    fi

    # 测试配置
    info "测试配置有效性..."

    if command -v docker-compose &> /dev/null; then
        if docker-compose config > /dev/null 2>&1; then
            success "✓ Docker Compose 配置有效"
        else
            error "✗ Docker Compose 配置无效"
        fi
    fi

    if command -v cargo &> /dev/null; then
        if cargo metadata --format-version 1 > /dev/null 2>&1; then
            success "✓ Cargo 配置有效"
            PACKAGE_NAME=$(cargo metadata --format-version 1 --no-deps 2>/dev/null | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
            info "  Package name: $PACKAGE_NAME"
        else
            warning "⚠ 无法验证 Cargo 配置"
        fi
    fi
fi

# 完成
echo ""
echo "=========================================="

if [ "$DRY_RUN" = true ]; then
    info "DRY-RUN 模式完成"
    echo ""
    info "要实际执行修改，请运行："
    echo "  ./rename-to-galos-fixed.sh"
else
    success "重命名完成！"
    echo ""
    info "修改摘要："
    echo "  - Cargo package: starry → galos"
    echo "  - Docker service: starryos-dev → galos-dev"
    echo "  - 工作目录: /workspace/StarryOS → /workspace/GalOS"
    echo "  - 所有文档已更新"
    echo ""
    info "下一步操作："
    echo "  1. 检查修改: git diff"
    echo "  2. 测试构建: cargo build"
    echo "  3. 测试 Docker: docker-compose build galos-dev"
    echo "  4. 重命名文件夹:"
    echo "       cd .."
    echo "       mv StarryOS GalOS"
    echo "       cd GalOS"
    echo "  5. 提交修改: git add . && git commit"
fi

echo "=========================================="
info "日志已保存到: $LOG_FILE"

exit 0
