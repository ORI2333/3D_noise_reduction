# image_py

用于 `FPGA/rtl/TB_8CH_DDR.sv` 仿真输入/输出图片的辅助脚本（替代原 MATLAB 流程）。

## 1) 生成输入 `Bmp_2_rgb888.txt`

```powershell
python script/image_py/image_gen.py -i <你的图片.bmp>
```

默认输出到 `script/image_py/out/Bmp_2_rgb888.txt`，格式为：**RGB888，1 字节/行，HEX**（可被 `$readmemh` 读取）。

可选指定分辨率（会按该分辨率缩放输出）：

```powershell
python script/image_py/image_gen.py -i <你的图片.bmp> --res 640x480
```

## 2) 从仿真输出 `rgb888_output.txt` 复原图片

```powershell
python script/image_py/image_restoration.py
```

默认读取 `script/image_py/out/rgb888_output.txt`，输出 `script/image_py/out/rgb888_output.png`。

可选指定分辨率（必须与你仿真输出对应）：

```powershell
python script/image_py/image_restoration.py --res 640x480
```

## 3) TB 文件路径说明

`FPGA/rtl/TB_8CH_DDR.sv` 默认从仓库内读取/写出：

- 输入：`script/image_py/out/Bmp_2_rgb888.txt`
- 输出：`script/image_py/out/rgb888_output.txt`

也可以在仿真启动参数里覆盖：

- `+IMG_IN=<path>`
- `+IMG_OUT=<path>`
