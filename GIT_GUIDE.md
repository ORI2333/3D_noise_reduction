# Git 提交和协作指南

## 第一次提交

如果这是新仓库的第一次提交：

```bash
# 1. 初始化 Git（如果还没有）
git init

# 2. 添加远程仓库
git remote add origin <你的GitHub仓库URL>

# 3. 添加文件（.gitignore 会自动过滤不需要的文件）
git add .

# 4. 提交
git commit -m "Initial commit: 3D noise reduction FPGA project"

# 5. 推送到 GitHub
git push -u origin main
# 或者如果分支是 master
git push -u origin master
```

## 日常开发流程

```bash
# 1. 查看修改状态
git status

# 2. 添加修改的文件
git add FPGA/rtl/modified_file.sv
# 或添加所有修改
git add .

# 3. 提交修改
git commit -m "描述你的修改"

# 4. 推送到远程仓库
git push
```

## 提交信息规范

建议使用清晰的提交信息：

```bash
git commit -m "feat: 添加新的降噪算法模块"
git commit -m "fix: 修复 DDR 初始化问题"
git commit -m "docs: 更新 README 文档"
git commit -m "refactor: 重构 BRAM 控制器"
git commit -m "perf: 优化 FIFO 时序"
```

## 验证提交内容

在提交前，检查将要提交的文件：

```bash
# 查看将要提交的文件列表
git status

# 查看具体修改内容
git diff

# 查看已暂存的修改
git diff --cached
```

## 确认 .gitignore 正常工作

```bash
# 查看被忽略的文件
git status --ignored

# 确保大文件被忽略
du -sh FPGA/prj/3DNR.cache  # 应该不存在或被忽略
du -sh FPGA/prj/3DNR.runs   # 应该不存在或被忽略
```

## 仓库克隆后的使用（其他开发者）

```bash
# 1. 克隆仓库
git clone <仓库URL>
cd 3D_noise_reduction

# 2. 检查文件
ls -la FPGA/rtl/        # 源文件应该存在
ls -la FPGA/prj/        # 只有 create_project.tcl 和 IP 配置

# 3. 创建 Vivado 项目
cd FPGA/prj
vivado -mode batch -source create_project.tcl

# 4. 打开项目
vivado 3DNR.xpr
```

## 仓库大小估算

提交后的仓库大小大约：
- RTL 源代码: ~1-5 MB
- IP 核配置 (.xci): ~10-50 MB
- 文档和脚本: ~1-10 MB
- **总计**: 约 20-70 MB（合理范围）

如果仓库 > 100 MB，检查是否有不必要的文件被提交。

## 删除已提交的大文件

如果不小心提交了生成文件：

```bash
# 从 Git 历史中移除文件，但保留工作区
git rm -r --cached FPGA/prj/3DNR.cache
git rm -r --cached FPGA/prj/3DNR.runs

# 提交删除
git commit -m "chore: 移除自动生成的文件"

# 推送
git push
```

## 分支管理（可选）

```bash
# 创建开发分支
git checkout -b develop

# 切换回主分支
git checkout main

# 合并分支
git merge develop
```
