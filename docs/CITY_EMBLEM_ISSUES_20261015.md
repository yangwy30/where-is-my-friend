# 城市徽章问题清单（2026-10-15）

审查对象：`WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems/` 下全部 211 个徽章（分支 `ui/1.0.7-polish`，提交 a1b3db9）。浅色底 `#FDFBF2`、深色底 `#112217` 各看一遍。截图在 [city_emblem_issues_20261015/](city_emblem_issues_20261015/)。

文件本身没有问题：每个徽章都有 @1x/@2x/@3x 三张图，@3x 都是 512×512，四角全透明，没有内容贴边被裁掉。问题都出在画面上，按优先级排列如下。

---

## 1. 深色模式下底座下沿被"撕坏"（最严重，必须修）

**现象：** 在深色模式里，很多徽章的白色底座下半圈参差不齐：有阶梯状锯齿、横向断层，有的整层底座不见了，还剩零星白色碎片悬在下面。浅色模式下看不出来。

**原因：** 10 月 13 日的去地面反光脚本（`scripts/emblem_floor_cleanup/run.sh`，提交 c764f09）按列扫描判断"地面"。底座最下面一圈也是浅色、低饱和的，被误判成了地面，改成了深色半透明阴影。这些阴影在白底上看起来跟原来一样，在深色底上就消失了，于是底座缺了一块。

对比图：
- 修之前（728cbe3）：底座完整，但下面有一大片白色反光 → [before-cleanup-728cbe3.jpg](city_emblem_issues_20261015/before-cleanup-728cbe3.jpg)
- 现在：反光没了，底座下沿也被啃掉了 → [torn-plinth-1.jpg](city_emblem_issues_20261015/torn-plinth-1.jpg)、[torn-plinth-2.jpg](city_emblem_issues_20261015/torn-plinth-2.jpg)
- 正常的参照（paris、amsterdam、sydney、tokyo、new_york）→ [clean-reference.jpg](city_emblem_issues_20261015/clean-reference.jpg)

**已确认明显受损（23 个）：**
phoenix, raleigh, stockholm, tel_aviv, milwaukee, kyoto, utrecht, copenhagen, oklahoma_city, halifax, oxford, providence, macau, cairo, chicago, cusco, lucerne, new_orleans, savannah, christchurch, prague, reykjavik, santiago

**大概率也受损，需逐个确认：**
charlotte, denver, incheon, ithaca, los_angeles, memphis, osaka, princeton, split, st_louis, archetype_silicon_valley, asheville, basel, charlottesville, dallas, generic_block, glasgow, guadalajara, jeju, lima, manila, medellin, milan, minneapolis, monterrey, munich, suzhou, toronto, victoria, washington, seattle, fukuoka

（这份名单是用 `scripts/emblem_review/jag.mjs` 按"深色底上底边锯齿程度"排序，再人工看图得出的，不保证完整。修完后请把 211 个全部在深色底上过一遍。）

**怎么修：**
- 不要在现在这批图上继续打补丁。请从去反光之前的原图重新处理（`git show 728cbe3:WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems/City_<名字>.imageset/City_<名字>@3x.png`）。
- 所有徽章用的是同一种圆角方形底座，可以先做底座轮廓的遮罩，把轮廓以内的像素全部保留，只去掉轮廓外面的地面反光。不要再按颜色或亮度去猜哪里是地面。另一个办法是用原来的生成工具重新导出透明背景的版本。
- 底座下面的投影可以保留，但要能在深色底上看得出底座边缘：深色模式下底座下沿必须完整、平滑。
- 修完后 @2x（341 px）和 @1x（170 px）要从新的 @3x 重新缩小，用预乘透明度的方式缩放（现有脚本里有现成做法）。文件名和 `Contents.json` 都不要改。

**顺带：** 约 45 个徽章底座下面还有零散的小块深色阴影碎片，跟主体不相连（比如 suzhou 10 块、san_antonio 14 块、calgary 7 块）。深色底上基本看不见，浅色底上很淡。重新处理时一起清掉即可。

---

## 2. 大小和位置不统一（建议修，网格里很显眼）

同样是 512×512 的画布，徽章（含底座）实际占的高度在 275 px 到 456 px 之间，相差 1.66 倍。底座离画布底边的距离从 12 px 到 110 px 不等，水平方向最多偏离中心 42 px。App 里的 `CityEmblemView` 只是把整张图等比缩放进方框（`CityEmblem.swift` 约 587 行），不做任何补偿，所以在好友网格里会有的大、有的小，有的高、有的低。

- **明显偏小 / 偏高**（底座离底边远，看起来"飘着"）：kyoto, brisbane, chapel_hill, princeton, anchorage, cape_town, sydney, adelaide, irvine, cleveland
- **明显偏大 / 顶到上边**（离上边不到 40 px）：austin, archetype_silicon_valley, archetype_historic_brick, berkeley, krakow, warsaw, hong_kong, chicago, dubai, porto, auckland, geneva
- **左右偏得多**（超过 25 px）：prague, portland, london, shanghai, houston, reykjavik, liverpool, lima, savannah, utrecht, venice, santiago, tokyo

**建议统一规则**（数值可以再商量）：
- 底座宽度统一（例如约 400 px）。
- 底座底边对齐到同一条线（例如 y = 460）。
- 底座水平居中。
- 高的地标可以往上长，但离上边至少留 24 px。
- 这一步最好和第 1 项一起做，同一遍重新导出。

---

## 3. 地标画错、可能有版权问题（需要人判断）

- **fukuoka（福冈）画错了。** 现在是一座红白相间的铁塔，跟 tokyo 的东京塔几乎一样。福冈塔实际是银色的三角形玻璃高塔。需要重画。
- **orlando（奥兰多）用的是迪士尼的灰姑娘城堡。** 这是迪士尼的知识产权，放进上架的 App 有被投诉或审核卡住的风险（App Store 审核指南 5.2）。建议换成不涉及品牌的图，比如湖景、棕榈树或 Lake Eola 喷泉。
- **值得核实一下：** seattle 的太空针塔和 sydney 的悉尼歌剧院，所有方对外形的商业使用都有商标主张。是否需要处理，请你们自己决定。我没有法律结论，只是提示。
- **小问题：** `archetype_historic_brick` 名字叫"砖房"，画的却是石头房子，要么改图要么改名。

---

## 4. 风格不统一（可选，属于设计决定）

底座有好几种做法：单层薄金属板（atlanta, boston, houston, berlin）、双层磨砂（anchorage, antwerp, amsterdam）、三层台阶（tokyo），还有顶面整片是水的（busan, sydney, geneva）。主体比例也差很多：有的地标只是底座上一个小东西（houston 的火箭、new_york、washington），有的铺满整个底座（busan, abu_dhabi, honolulu）。

是否统一由设计决定。如果决定统一，建议定一个底座模板，所有城市只换上面的地标。这样第 1、2 项的问题以后也不会再出现。

---

## 5. 同国同名城市会用错图（低优先级，代码问题）

`CityEmblem.resolve` 只检查国家，不检查州。Portland, Maine 会拿到俄勒冈 Portland 的 St. Johns 桥，Durham, NH 会拿到北卡 Durham 的杜克教堂，Columbus, GA 也一样。只有登记在 `CityRegionCatalog` 里的城市才有州级区分。跨国同名（Cambridge MA vs 英国剑桥、Birmingham AL vs 英国伯明翰）已经正确处理了，不受影响。

---

## 验收方式

1. 重新生成全部 211 个的对照图（左浅右深，带基线辅助线）：

   ```bash
   NODE_PATH=<装了 sharp 的目录>/node_modules node scripts/emblem_review/sheet.mjs WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems /tmp/emblem-sheets
   ```

2. 深色底锯齿评分（数值越大越可能有问题；修好后应接近 0）：

   ```bash
   NODE_PATH=<同上> node scripts/emblem_review/jag.mjs WhereIsMyFriend/Resources/Assets.xcassets/CityEmblems /tmp/jag.json
   ```

3. 大小和位置统计：`scripts/emblem_review/metrics.mjs`（参数：素材目录、输出 json）。

4. 最后在 App 里切到深色模式（Night Jade），看好友网格、行程页和城市徽章画廊（`CityEmblemGalleryView`）。
