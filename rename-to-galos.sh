#!/bin/bash
#
# 自动化脚本：将项目从 StarryOS 重命名为 GalOS
#
# 使用方法：
#   ./rename-to-galos.sh [--dry-run] [--no-backup]
#
# 选项：
#   --dry-run      只显示将要修改的内容，不实际执行
#   --no-backup    不创建备份（不推荐）
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
OLD_NAME_UPPER="StarryOS"
NEW_NAME_UPPER="GalOS"
OLD_NAME_LOWER="starryos"
NEW_NAME_LOWER="galos"
OLD_NAME_PASCAL="Starry"  # 用于某些特殊情况

DRY_RUN=false
NO_BACKUP=false
BACKUP_DIR=""
LOG_FILE="rename.log"

# 解析参数
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-backup)
            NO_BACKUP=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Usage: $0 [--dry-run] [--no-backup]"
            exit 1
            ;;
    esac
done

# 日志函数
log() {
    echo "$@" | tee -a "$LOG_FILE"
}

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
echo "Dry Run: $DRY_RUN" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

info "开始项目重命名：$OLD_NAME_UPPER → $NEW_NAME_UPPER"

if [ "$DRY_RUN" = true ]; then
    warning "运行在 DRY-RUN 模式，不会实际修改文件"
fi

# 检查是否在项目根目录
if [ ! -f "Cargo.toml" ] || [ ! -f "Dockerfile" ]; then
    error "请在项目根目录下运行此脚本"
    exit 1
fi

# 创建备份
if [ "$NO_BACKUP" = false ] && [ "$DRY_RUN" = false ]; then
    BACKUP_DIR="../${OLD_NAME_UPPER}-backup-$(date +%Y%m%d-%H%M%S)"
    info "创建备份到: $BACKUP_DIR"

    if [ -d "$BACKUP_DIR" ]; then
        error "备份目录已存在: $BACKUP_DIR"
        exit 1
    fi

    cp -r . "$BACKUP_DIR"
    success "备份创建完成"
    log ""
fi

# 定义需要修改的文件列表
FILES_TO_MODIFY=(
    "Cargo.toml"
    "Dockerfile"
    "docker-compose.yml"
    "setup-env.sh"
    "README.md"
    "docs/docker-guide.md"
    "docs/environment-requirements.md"
    "docs/x11.md"
    "UPLOAD_TO_ORGANIZATION.md"
    "QUICK_START_UPLOAD.md"
    "TEAM_UPLOAD_CHECKLIST.md"
    "DOCKER_MIGRATION_GUIDE.md"
    ".github/workflows/docker-ci.yml"
    ".github/PULL_REQUEST_TEMPLATE.md"
    ".github/ISSUE_TEMPLATE/bug_report.md"
    ".github/ISSUE_TEMPLATE/feature_request.md"
)

# 添加可能存在的文件
if [ -f "CONTRIBUTING.md" ]; then
    FILES_TO_MODIFY+=("CONTRIBUTING.md")
fi

if [ -f ".github/ISSUE_TEMPLATE/config.yml" ]; then
    FILES_TO_MODIFY+=(".github/ISSUE_TEMPLATE/config.yml")
fi

# 执行替换
info "开始替换文件内容..."
log ""

MODIFIED_COUNT=0
SKIPPED_COUNT=0

for file in "${FILES_TO_MODIFY[@]}"; do
    if [ ! -f "$file" ]; then
        warning "文件不存在，跳过: $file"
        ((SKIPPED_COUNT++))
        continue
    fi

    # 检查文件是否包含需要替换的内容
    if ! grep -q -E "(${OLD_NAME_UPPER}|${OLD_NAME_LOWER})" "$file" 2>/dev/null; then
        info "文件无需修改，跳过: $file"
        ((SKIPPED_COUNT++))
        continue
    fi

    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] 将修改文件: $file"
        # 显示将要替换的内容
        echo "  变更预览:"
        grep -n -E "(${OLD_NAME_UPPER}|${OLD_NAME_LOWER})" "$file" | head -5 | sed 's/^/    /'
        if [ $(grep -c -E "(${OLD_NAME_UPPER}|${OLD_NAME_LOWER})" "$file") -gt 5 ]; then
            echo "    ... 以及其他 $(( $(grep -c -E "(${OLD_NAME_UPPER}|${OLD_NAME_LOWER})" "$file") - 5 )) 处"
        fi
    else
        info "修改文件: $file"

        # 使用 sed 进行替换（兼容 macOS 和 Linux）
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/${OLD_NAME_UPPER}/${NEW_NAME_UPPER}/g" "$file"
            sed -i '' "s/${OLD_NAME_LOWER}/${NEW_NAME_LOWER}/g" "$file"
        else
            # Linux
            sed -i "s/${OLD_NAME_UPPER}/${NEW_NAME_UPPER}/g" "$file"
            sed -i "s/${OLD_NAME_LOWER}/${NEW_NAME_LOWER}/g" "$file"
        fi

        success "✓ 已修改: $file"
    fi

    ((MODIFIED_COUNT++))
done

log ""
info "文件修改统计："
info "  - 已修改: $MODIFIED_COUNT 个文件"
info "  - 已跳过: $SKIPPED_COUNT 个文件"
log ""

# 特殊处理：Cargo.toml 中的 package name
if [ -f "Cargo.toml" ]; then
    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] 将修改 Cargo.toml 中的 package name"
        grep -n "^name = " Cargo.toml || true
    else
        info "确保 Cargo.toml 中的 package name 正确..."

        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' 's/^name = "starry"/name = "galos"/' Cargo.toml
        else
            sed -i 's/^name = "starry"/name = "galos"/' Cargo.toml
        fi

        if grep -q '^name = "galos"' Cargo.toml; then
            success "✓ Cargo.toml package name 已更新"
        else
            warning "请手动检查 Cargo.toml 中的 package name"
        fi
    fi
fi

# 验证修改
if [ "$DRY_RUN" = false ]; then
    log ""
    info "验证修改结果..."

    # 检查是否还有遗留的旧名称
    REMAINING_REFS=$(grep -r "${OLD_NAME_UPPER}" --include="*.toml" --include="*.yml" --include="*.yaml" --include="*.sh" --include="Dockerfile" . 2>/dev/null | grep -v ".git/" | grep -v "rename.log" | grep -v "RENAME_TO_GALOS.md" | wc -l || echo "0")

    if [ "$REMAINING_REFS" -gt 0 ]; then
        warning "发现 $REMAINING_REFS 处可能遗漏的引用（可能在注释或说明中）："
        grep -r "${OLD_NAME_UPPER}" --include="*.toml" --include="*.yml" --include="*.yaml" --include="*.sh" --include="Dockerfile" . 2>/dev/null | grep -v ".git/" | grep -v "rename.log" | grep -v "RENAME_TO_GALOS.md" | head -5
    else
        success "✓ 配置文件中未发现遗留的旧名称引用"
    fi

    # 测试 Docker Compose 配置
    info "验证 Docker Compose 配置..."
    if docker-compose config > /dev/null 2>&1; then
        success "✓ Docker Compose 配置有效"
    else
        error "✗ Docker Compose 配置无效，请检查 docker-compose.yml"
    fi

    # 测试 Cargo 配置
    info "验证 Cargo 配置..."
    if cargo metadata --format-version 1 > /dev/null 2>&1; then
        success "✓ Cargo 配置有效"

        # 检查 package name
        PACKAGE_NAME=$(cargo metadata --format-version 1 --no-deps 2>/dev/null | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ "$PACKAGE_NAME" = "$NEW_NAME_LOWER" ]; then
            success "✓ Package name 已更新为: $PACKAGE_NAME"
        else
            warning "Package name 是: $PACKAGE_NAME (预期: $NEW_NAME_LOWER)"
        fi
    else
        warning "无法验证 Cargo 配置（可能缺少依赖）"
    fi
fi

# 完成
log ""
log "=========================================="

if [ "$DRY_RUN" = true ]; then
    info "DRY-RUN 模式完成"
    info "要实际执行修改，请运行: $0"
else
    success "重命名完成！"
    log ""
    info "修改摘要："
    info "  - 项目名称: $OLD_NAME_UPPER → $NEW_NAME_UPPER"
    info "  - Docker 服务: ${OLD_NAME_LOWER}-dev → ${NEW_NAME_LOWER}-dev"
    info "  - Cargo package: $OLD_NAME_LOWER → $NEW_NAME_LOWER"

    if [ "$NO_BACKUP" = false ]; then
        log ""
        info "备份位置: $BACKUP_DIR"
        info "如需回滚，请运行:"
        info "  rm -rf $(pwd)"
        info "  mv $BACKUP_DIR $(pwd)"
    fi

    log ""
    info "下一步操作："
    echo "  1. 检查修改: git diff"
    echo "  2. 测试构建: cargo build"
    echo "  3. 测试 Docker: docker-compose build ${NEW_NAME_LOWER}-dev"
    echo "  4. 如果一切正常，提交修改:"
    echo "       git add ."
    echo "       git commit -m \"refactor: rename project from $OLD_NAME_UPPER to $NEW_NAME_UPPER\""
    log ""
fi

log "=========================================="
info "日志已保存到: $LOG_FILE"

# 询问是否重命名文件夹
if [ "$DRY_RUN" = false ]; then
    log ""
    echo -e "${YELLOW}提示：${NC}当前文件夹名称仍为 '${OLD_NAME_UPPER}'"
    echo "是否需要重命名文件夹？ (需要退出当前目录)"
    echo ""
    echo "手动重命名步骤："
    echo "  cd .."
    echo "  mv ${OLD_NAME_UPPER} ${NEW_NAME_UPPER}"
    echo "  cd ${NEW_NAME_UPPER}"
fi

exit 0
