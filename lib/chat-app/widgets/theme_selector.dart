import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart'; // 假设 FlexScheme 在这里定义

// 假设这些是您提供的Scheme映射和中文名称映射
final Map<String, FlexScheme> schemeMap = {
  "material": FlexScheme.material,
  "materialHc": FlexScheme.materialHc,
  "blue": FlexScheme.blue,
  "indigo": FlexScheme.indigo,
  "hippieBlue": FlexScheme.hippieBlue,
  "aquaBlue": FlexScheme.aquaBlue,
  "brandBlue": FlexScheme.brandBlue,
  "deepBlue": FlexScheme.deepBlue,
  "sakura": FlexScheme.sakura,
  "mandyRed": FlexScheme.mandyRed,
  "red": FlexScheme.red,
  "redWine": FlexScheme.redWine,
  "purpleBrown": FlexScheme.purpleBrown,
  "green": FlexScheme.green,
  "money": FlexScheme.money,
  "jungle": FlexScheme.jungle,
  "greyLaw": FlexScheme.greyLaw,
  "wasabi": FlexScheme.wasabi,
  "gold": FlexScheme.gold,
  "mango": FlexScheme.mango,
  "amber": FlexScheme.amber,
  "vesuviusBurn": FlexScheme.vesuviusBurn,
  "deepPurple": FlexScheme.deepPurple,
  "ebonyClay": FlexScheme.ebonyClay,
  "barossa": FlexScheme.barossa,
  "shark": FlexScheme.shark,
  "bigStone": FlexScheme.bigStone,
  "damask": FlexScheme.damask,
  "bahamaBlue": FlexScheme.bahamaBlue,
  "mallardGreen": FlexScheme.mallardGreen,
  "espresso": FlexScheme.espresso,
  "outerSpace": FlexScheme.outerSpace,
  "blueWhale": FlexScheme.blueWhale,
  "sanJuanBlue": FlexScheme.sanJuanBlue,
  "rosewood": FlexScheme.rosewood,
  "blumineBlue": FlexScheme.blumineBlue,
  "flutterDash": FlexScheme.flutterDash,
  "materialBaseline": FlexScheme.materialBaseline,
  "verdunHemlock": FlexScheme.verdunHemlock,
  "dellGenoa": FlexScheme.dellGenoa,
  "redM3": FlexScheme.redM3,
  "pinkM3": FlexScheme.pinkM3,
  "purpleM3": FlexScheme.purpleM3,
  "indigoM3": FlexScheme.indigoM3,
  "blueM3": FlexScheme.blueM3,
  "cyanM3": FlexScheme.cyanM3,
  "tealM3": FlexScheme.tealM3,
  "greenM3": FlexScheme.greenM3,
  "limeM3": FlexScheme.limeM3,
  "yellowM3": FlexScheme.yellowM3,
  "orangeM3": FlexScheme.orangeM3,
  "deepOrangeM3": FlexScheme.deepOrangeM3,
  "blackWhite": FlexScheme.blackWhite,
  "greys": FlexScheme.greys,
  "sepia": FlexScheme.sepia,
  "custom": FlexScheme.custom
};

final Map<String, String> schemeChineseNames = {
  "material": "Material主题",
  "materialHc": "高对比度",
  "blue": "水鸭蓝",
  "indigo": "靛青",
  "hippieBlue": "嬉皮蓝",
  "aquaBlue": "水族蓝",
  "brandBlue": "品牌蓝",
  "deepBlue": "深海蓝",
  "sakura": "樱花粉",
  "mandyRed": "曼迪红",
  "red": "经典红",
  "redWine": "勃艮第",
  "purpleBrown": "紫棕",
  "green": "丛林绿",
  "money": "招财绿",
  "jungle": "野林绿",
  "greyLaw": "律政灰",
  "wasabi": "芥末绿",
  "gold": "落日金",
  "mango": "芒果黄",
  "amber": "琥珀",
  "vesuviusBurn": "维苏威",
  "deepPurple": "深紫",
  "ebonyClay": "乌木灰",
  "barossa": "巴罗萨",
  "shark": "鲨鱼灰",
  "bigStone": "巨石",
  "damask": "大马士革",
  "bahamaBlue": "巴哈马蓝",
  "mallardGreen": "野鸭绿",
  "espresso": "意式浓缩",
  "outerSpace": "外太空",
  "blueWhale": "蓝鲸",
  "sanJuanBlue": "圣胡安蓝",
  "rosewood": "红木",
  "blumineBlue": "花水蓝",
  "flutterDash": "Flutter Dash",
  "materialBaseline": "Material基线",
  "verdunHemlock": "凡尔登铁杉",
  "dellGenoa": "戴尔热那亚",
  "redM3": "M3红",
  "pinkM3": "M3粉",
  "purpleM3": "M3紫",
  "indigoM3": "M3靛青",
  "blueM3": "M3蓝",
  "cyanM3": "M3青",
  "tealM3": "M3水鸭",
  "greenM3": "M3绿",
  "limeM3": "M3青柠",
  "yellowM3": "M3黄",
  "orangeM3": "M3橙",
  "deepOrangeM3": "M3深橙",
  "blackWhite": "黑白",
  "greys": "灰度",
  "sepia": "深褐色",
  "custom": "自定义"
};

/// 一个现代化主题选择器
class ThemeSelector extends StatefulWidget {
  /// 选择主题后调用的回调函数，参数为选中的主题字符串
  final ValueChanged<String> onThemeSelected;
  final String initialValue; // 初始值

  const ThemeSelector({Key? key, required this.initialValue, required this.onThemeSelected}) : super(key: key);

  @override
  _ThemeSelectorState createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<ThemeSelector> {
  String? _selectedTheme; // 存储当前选中的主题字符串

  @override
  void initState() {
    super.initState();
    // 初始设置一个默认主题，例如第一个主题或者 'material'
    _selectedTheme = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: '选择主题',

        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      ),
      value: _selectedTheme,
      items: schemeMap.keys.map<DropdownMenuItem<String>>((String key) {
        return DropdownMenuItem<String>(
          value: key,
          child: Text(schemeChineseNames[key] ?? key), // 显示中文名称，如果不存在则显示英文key
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedTheme = newValue;
        });
        if (newValue != null) {
          widget.onThemeSelected(newValue); // 调用回调函数，传递选中的字符串
        }
      },
      hint: const Text('请选择一个主题'),
      isExpanded: true, // 使下拉菜单占据可用宽度
      menuMaxHeight: MediaQuery.of(context).size.height * 0.5, // 限制下拉菜单的最大高度
    );
  }
}