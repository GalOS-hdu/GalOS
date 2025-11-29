#!/bin/bash
# GalOS项目状态检查脚本
# 快速查看项目文件组织状况

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              GalOS 项目状态检查                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# 检查根目录脚本
echo "📂 根目录脚本文件："
ls -1 *.sh 2>/dev/null | while read f; do
    echo "  ✓ $f"
done || echo "  (无)"
echo ""

# 检查文档目录
echo "📂 文档目录结构："
if [ -d "docs" ]; then
    tree docs/ -L 2 2>/dev/null || find docs/ -type d | head -10
else
    echo "  ⚠️  docs/ 目录不存在"
fi
echo ""

# 检查归档目录
echo "📦 归档目录 (archive/)："
if [ -d "archive" ]; then
    echo "  ✓ 归档目录存在"
    echo "  脚本归档: $(ls archive/scripts/*.sh 2>/dev/null | wc -l) 个"
    echo "  文档归档: $(ls archive/docs/*.md 2>/dev/null | wc -l) 个"
else
    echo "  - 归档目录不存在"
fi
echo ""

# 检查.gitignore
echo "🔒 Git忽略配置："
if grep -q "^archive/" .gitignore 2>/dev/null; then
    echo "  ✓ archive/ 已在 .gitignore 中"
else
    echo "  ⚠️  archive/ 未在 .gitignore 中"
fi
echo ""

# 统计
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 项目统计："
echo "  核心文档: $(find docs/learning docs/usage -name "*.md" 2>/dev/null | wc -l) 个"
echo "  归档文件: $(find archive -type f 2>/dev/null | wc -l) 个"
echo "  根目录脚本: $(ls -1 *.sh 2>/dev/null | wc -l) 个"
echo ""

echo "✅ 项目状态检查完成"
echo ""
