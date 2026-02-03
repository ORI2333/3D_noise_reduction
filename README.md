# 3D Noise Reduction FPGA Project

基于 FPGA 的 3D 降噪系统，采用多通道架构，使用 DDR3 作为帧缓存。


## 版本修订

### V0.2 (260202)
- 修复仿真脚本输出 txt 与 FPGA mem 不对应
- 修复仿真DDR3启动失败问题，需要仿真500us以上

### V0.1 (260201)
- 多通道综合不报错
- 

## 项目结构

```
3D_noise_reduction/
├── FPGA/
│   ├── rtl/                    # RTL 源代码
│   │   ├── 3DNR_8CH.sv        # 顶层模块
│   │   ├── TB_8CH_DDR.sv      # DDR 仿真 testbench
│   │   └── ...                # 其他模块
│   ├── pin/                    # 约束文件
│   │   └── ddr3.ucf           # DDR3 引脚约束
│   └── prj/                    # Vivado 项目（自动生成）
│       ├── create_project.tcl  # 项目创建脚本
│       └── 3DNR.srcs/
│           └── sources_1/ip/   # IP 核配置文件
├── script/
│   └── image_py/              # Python 图像处理脚本
│       ├── image_gen.py       # 图像生成
│       └── image_restoration.py  # 图像恢复
├── doc/                        # 文档
├── LICENSE                     # 许可证
└── README.md                   # 本文件
```

## 快速开始

### 前提条件

- **Vivado**: 2019.2 或更高版本
- **Python**: 3.7+ (用于图像处理脚本)
- **目标器件**: Artix-7 xc7a200tfbg484-2 (可在 TCL 脚本中修改)

### 克隆项目

```bash
git clone <repository-url>
cd 3D_noise_reduction
```

### 创建 Vivado 项目

项目使用 TCL 脚本自动创建，无需手动配置：

```bash
cd FPGA/prj
vivado -mode batch -source create_project.tcl
```

或在 Vivado TCL 控制台中：

```tcl
cd FPGA/prj
source create_project.tcl
```

### 打开项目

```bash
cd FPGA/prj
vivado 3DNR.xpr
```

### 运行仿真

1. 生成测试图像：
```bash
cd script/image_py
python image_gen.py
```

2. 在 Vivado 中：
   - Flow Navigator → Simulation → Run Simulation → Run Behavioral Simulation
   - 仿真完成后会在 `script/image_py/out/` 生成输出文件

3. 恢复输出图像：
```bash
python image_restoration.py --res 640x480
```

### 综合与实现

在 Vivado 中：
1. **Run Synthesis** (F11)
2. **Run Implementation**
3. **Generate Bitstream**

## Git 提交说明

### 包含的文件

本仓库包含以下文件（已配置 `.gitignore`）：

✅ **必须包含**：
- RTL 源代码 (`FPGA/rtl/*.sv`, `*.v`)
- 约束文件 (`FPGA/pin/*.ucf`, `*.xdc`)
- IP 核配置 (`FPGA/prj/3DNR.srcs/sources_1/ip/*/*.xci`)
- 项目创建脚本 (`FPGA/prj/create_project.tcl`)
- Python 脚本 (`script/`)
- 文档和说明文件

❌ **自动排除**（`.gitignore` 已配置）：
- Vivado 生成文件 (`.cache/`, `.gen/`, `.runs/`, `.sim/`)
- 日志文件 (`*.log`, `*.jou`)
- 综合实现结果 (`*.bit`, `*.dcp`)
- 仿真输出 (`script/image_py/out/`)

### 项目克隆后的设置

其他开发者克隆项目后，只需：

```bash
# 1. 克隆仓库
git clone <repository-url>
cd 3D_noise_reduction

# 2. 创建 Vivado 项目
cd FPGA/prj
vivado -mode batch -source create_project.tcl

# 3. 打开项目
vivado 3DNR.xpr
```

所有 IP 核和项目设置会自动配置完成。

## 系统参数

- **图像分辨率**: 640x480
- **像素格式**: RGB888 (24-bit)
- **通道数**: 8 并行通道
- **DDR 控制器**: AXI4 接口，256-bit 数据位宽
- **降噪算法**: 空间-时域混合降噪

## 模块说明

### 主要模块

- **DDD_Noise_8CH**: 顶层模块，集成所有子系统
- **U1_Mul_Channel_DDR**: 多通道 DDR 读写控制器
- **U2_MBDS_8CH**: 宏块差值求和
- **U4_METD_8CH**: 运动估计与阈值检测
- **U5_BRAM_Controller**: BRAM 缓存控制器
- **U6_Algorithm_Subsys**: 降噪算法子系统
- **U7_DDR_DMA**: DDR DMA 控制器

### IP 核

- **DDR_Controller**: MIG DDR3 控制器
- **True_DP_BRAM**: 双端口 Block RAM
- **FIFO_64_256**: 异步 FIFO
- **Divider_18Delays**: 18 周期除法器



## 常见问题

### Q: IP 核生成失败？
A: 确保使用正确的 Vivado 版本，IP 核需要重新生成：
```tcl
upgrade_ip [get_ips]
generate_target all [get_ips]
```

### Q: 仿真卡住在 DDR 初始化？
A: DDR3 校准需要时间，建议设置仿真超时：
```tcl
set_property -name {xsim.simulate.runtime} -value {100ms} -objects [get_filesets sim_1]
```

### Q: 如何修改目标器件？
A: 编辑 `FPGA/prj/create_project.tcl` 中的 `set_property part` 行。

## 许可证

详见 [LICENSE](LICENSE) 文件。

## 联系方式

- 作者: ori_zh
- 创建日期: 2026/02/01

