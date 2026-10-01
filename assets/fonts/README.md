# 界面字体

工程随附 Noto Sans CJK SC Regular（简体中文与英文）和 Noto Sans CJK JP Regular（日文），由语言 manifest 指定字体资源。新语言可以复用覆盖其字符的字体，或添加有明确许可证的新字体。

来源是 [notofonts/noto-cjk 官方仓库](https://github.com/notofonts/noto-cjk)，固定 revision `f8d157532fbfaeda587e826d4cd5b21a49186f7c`。原始 OTF 未修改或裁剪；每份约 16 MB，以保留新增翻译时的完整字符覆盖。逐文件下载地址、字节数和 SHA-256 见 `sources.json`。

字体按照原仓库的 [SIL Open Font License 1.1](https://github.com/notofonts/noto-cjk/blob/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/LICENSE) 随软件分发；完整许可证保留在 `OFL.txt`，字体自身含版权元数据。新增或替换字体时一并维护来源与许可，不把本机系统 fallback 当作跨机器字体保证。

自动验收检查当前全部目录文字的 Font.has_char()；实际图形运行另检查三语菜单、HUD 与帮助截图。字符覆盖不等于翻译质量或正式字体美术验收。
