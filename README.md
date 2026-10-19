# 灵动岛 Pro / IslandPro

**V1.0.0 实验性源码，尚未证明可以编译安装。**

目标：iOS 16–17 Rootless / SpringBoard / SystemAperture。

## 已提交的实现
- SystemAperture 容器布局挂载（尚待真机验证）
- 静态图片导入：系统文件选择器、转换为 PNG、保存与通知刷新
- 图片缓存、透明度、缩放、水平和垂直偏移
- 青色光晕与实验性呼吸动画（尊重“减少动态效果”）
- 独立 Theos 工程及独立 GitHub Actions 工作流

## 尚未实现或尚未验证
- GIF、MP4、左右独立动画、粒子光效
- 音乐/录屏/通知场景的完整生命周期和兼容性
- 与其他动态岛插件的自动冲突检测
- **首次成功编译、DEB 安装及真机稳定性**

## 云端构建与诊断
打开 [Actions](https://github.com/tu134186/TUIIslandPro/actions)，运行 **IslandPro Rootless Build**。
- 编译成功：下载 `IslandPro-DEB` Artifact
- 编译失败：下载 `IslandPro-Build-Logs` Artifact（若构建已执行到日志生成阶段）
- 安装前建议备份环境；不要与 `ios16dao` 同时启用

仅包含独立编写源码，不包含第三方原始 dylib。所有构建配置只作用于此仓库。
