#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
TARGET="$PWD/build/PreviewIINAController.app/Contents/MacOS/PreviewIINAController"
while read -r pid command; do
  if [[ "$command" == "$TARGET" ]]; then
    printf '%s\n' '请先在活动监视器退出本项目的 PreviewIINAController，再运行此脚本。' >&2
    exit 1
  fi
done < <(ps -axo pid=,comm=)
# Remove only known generated files. Preserve source, Git history and unknown files.
rm -f -- "$TARGET" build/PreviewIINAController.app/Contents/Info.plist \
  build/PreviewIINAController.app/Contents/_CodeSignature/CodeResources \
  build/filter-tests build/ui-tests dist/PreviewIINAController-arm64.zip
for dir in build/PreviewIINAController.app/Contents/_CodeSignature \
  build/PreviewIINAController.app/Contents/MacOS build/PreviewIINAController.app/Contents \
  build/PreviewIINAController.app build dist; do
  rmdir -- "$dir" 2>/dev/null || true
done
printf '%s\n' '已清理已知构建产物；源码、Git 历史、IINA 和系统授权未修改。'
