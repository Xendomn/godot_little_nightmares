# 素材与参考来源

新增角色、骨骼动画、2K 布料纹理、环境场景和合成声音均为本工程原创。保留 Blender 源文件与生成脚本，没有移植第三方角色、动画包或收费素材。

- [Noto Sans SC](https://github.com/notofonts/noto-cjk)：SIL Open Font License 1.1，许可证位于 assets/fonts/OFL.txt，发行包附 NotoSansSC-OFL.txt。
- [Godot](https://github.com/godotengine/godot)：MIT，发行包附官方 LICENSE 和 COPYRIGHT，包括引擎第三方声明。

实现前查看的技术参考，未复制其代码或素材：

- [Godot Plush Character](https://github.com/gtibo/Godot-Plush-Character)：MIT，角色与动画组织参考。
- [Godot 资源库 Third Person Controller](https://godotengine.org/asset-library/asset/3934)：动画状态机参考。
- [WiggleBone](https://github.com/detomon/wigglebone)：MIT，次级骨骼运动评估；最终使用原生 SpringBoneSimulator3D。
- [SpringBoneSimulator3D 官方文档](https://docs.godotengine.org/en/stable/classes/class_springbonesimulator3d.html)：布料链 API 依据。

原创音频由 tools/create_assets.py 和 tools/create_expansion_audio.py 合成，不含外部录音或音乐采样。当前角色报告为 character-v2-report.md；assets-report.md 是首版历史记录。

本次新增的 19 件机械道具、金属／木材／织物 PBR 贴图均由 `tools/create_mechanical_props.py` 原创生成，Blender 源文件位于 `assets/sources/props/`。新增铃声、阀门摩擦和棘轮声由 `tools/create_prop_audio.py` 合成，没有引入第三方素材。完整道具与面数清单见 `mechanical-assets.md`。

## Full campaign expansion

The additional Blender kit, CC0 Poly Haven wood and Kenney mechanical audio, reference-only Playdead screenshots, and interaction character variant are documented in [the expansion asset ledger](production/expansion-assets.md). Exact downloads and hashes are recorded with the source assets.
