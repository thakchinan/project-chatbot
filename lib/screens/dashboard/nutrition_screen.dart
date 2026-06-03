import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _expandedIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.glassBackgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [

            _buildHeader(context),

            _buildTabBar(),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFoodTab(),
                  _buildVitaminTab(),
                  _buildDrinkTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textDark, size: 20),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'โภชนาการคลายเครียด',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'อาหารและวิตามินที่ช่วยลดระดับ cortisol',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: AppColors.primaryGreen, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'ลดเครียด',
                      style: TextStyle(color: AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: AppTheme.glassDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.orange, Color(0xFFFFD4B2)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.orange.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textGray,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.all(4),
        tabs: const [
          Tab(text: '🍽️ อาหาร'),
          Tab(text: '💊 วิตามิน'),
          Tab(text: '🥤 เครื่องดื่ม'),
        ],
      ),
    );
  }

  Widget _buildFoodTab() {
    final foods = [
      _NutritionItem(
        emoji: '🐟',
        name: 'ปลาแซลมอน',
        keyNutrient: 'โอเมก้า 3 (DHA & EPA)',
        benefit: 'ลดระดับ cortisol และลดการอักเสบในสมอง',
        detail: 'กรดไขมันโอเมก้า 3 ช่วยปรับสมดุลสารเคมีในสมอง ลดระดับฮอร์โมนความเครียด (cortisol) ได้ถึง 14% เมื่อรับประทานสม่ำเสมอ กระตุ้นการสร้าง serotonin ซึ่งเป็นสารสุขในสมอง ช่วยให้อารมณ์ดีขึ้นและนอนหลับได้ดี',
        portion: 'แนะนำ 2-3 ครั้ง/สัปดาห์',
        color: const Color(0xFF2196F3),
      ),
      _NutritionItem(
        emoji: '🥑',
        name: 'อะโวคาโด',
        keyNutrient: 'วิตามิน B6, แมกนีเซียม, โฟเลต',
        benefit: 'ช่วยสร้าง serotonin ลดความวิตกกังวล',
        detail: 'วิตามิน B6 เป็นส่วนสำคัญในการสังเคราะห์สาร serotonin และ GABA ซึ่งเป็นสารสื่อประสาทที่ช่วยทำให้สงบ แมกนีเซียมช่วยคลายกล้ามเนื้อและระบบประสาท ลดอาการนอนไม่หลับจากความเครียด',
        portion: 'แนะนำ ครึ่งลูก/วัน',
        color: const Color(0xFF4CAF50),
      ),
      _NutritionItem(
        emoji: '🫐',
        name: 'บลูเบอร์รี่',
        keyNutrient: 'แอนโทไซยานิน, วิตามิน C',
        benefit: 'ต้านอนุมูลอิสระ ปกป้องเซลล์สมองจากความเครียด',
        detail: 'สารแอนโทไซยานินในบลูเบอร์รี่ช่วยลดการอักเสบในสมองที่เกิดจากความเครียดเรื้อรัง วิตามิน C ช่วยลดระดับ cortisol ได้ถึง 25% งานวิจัยพบว่าการกินบลูเบอร์รี่สม่ำเสมอช่วยเพิ่ม BDNF (สารบำรุงเซลล์ประสาท)',
        portion: 'แนะนำ 1 ถ้วย/วัน',
        color: const Color(0xFF9C27B0),
      ),
      _NutritionItem(
        emoji: '🍫',
        name: 'ดาร์กช็อกโกแลต (70%+)',
        keyNutrient: 'ฟลาโวนอยด์, แมกนีเซียม, ทริปโตเฟน',
        benefit: 'ลดฮอร์โมนเครียด เพิ่มสาร endorphin',
        detail: 'ฟลาโวนอยด์ในช็อกโกแลตดำช่วยเพิ่มการไหลเวียนของเลือดไปเลี้ยงสมอง ทริปโตเฟนเป็นสารตั้งต้นของ serotonin ช่วยให้รู้สึกผ่อนคลาย งานวิจัยพบว่าการกิน 40 กรัม/วัน ลดระดับ cortisol ได้อย่างมีนัยสำคัญ',
        portion: 'แนะนำ 1-2 ชิ้น/วัน (20-40g)',
        color: const Color(0xFF795548),
      ),
      _NutritionItem(
        emoji: '🥚',
        name: 'ไข่',
        keyNutrient: 'โคลีน, วิตามิน D, ทริปโตเฟน',
        benefit: 'ช่วยการทำงานของสารสื่อประสาท ลดความเครียด',
        detail: 'โคลีนเป็นสารที่จำเป็นต่อการสร้าง acetylcholine ซึ่งเกี่ยวข้องกับอารมณ์และความจำ วิตามิน D ช่วยควบคุมอารมณ์ ผู้ที่ขาดวิตามิน D มีโอกาสเครียดสูงกว่าปกติมากกว่า 2 เท่า',
        portion: 'แนะนำ 1-2 ฟอง/วัน',
        color: const Color(0xFFFF9800),
      ),
      _NutritionItem(
        emoji: '🥦',
        name: 'บรอกโคลี',
        keyNutrient: 'ซัลโฟราเฟน, วิตามิน C, โฟเลต',
        benefit: 'ปกป้องระบบประสาท ลดอาการวิตกกังวล',
        detail: 'ซัลโฟราเฟนมีฤทธิ์ต้านการอักเสบในสมอง ช่วยปกป้องเซลล์ประสาทจากความเสียหายที่เกิดจากความเครียดเรื้อรัง วิตามิน C ในบรอกโคลีช่วยสนับสนุนการผลิตสาร serotonin และ norepinephrine',
        portion: 'แนะนำ 1 ถ้วย/วัน',
        color: const Color(0xFF388E3C),
      ),
    ];

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: foods.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildInfoCard(
            icon: Icons.psychology_rounded,
            title: 'ทำไมอาหารจึงสำคัญ?',
            description: 'ความเครียดเรื้อรังทำให้ร่างกายสูญเสียสารอาหารสำคัญ เช่น แมกนีเซียม วิตามิน B และ C การเลือกอาหารที่เหมาะสมจะช่วยเติมสารอาหารที่ขาดหายและปรับสมดุลฮอร์โมนความเครียด',
            gradientColors: [const Color(0xFFFF7E5F), const Color(0xFFFEB47B)],
          );
        }
        final food = foods[index - 1];
        return _buildExpandableFoodCard(food, index - 1);
      },
    );
  }

  Widget _buildVitaminTab() {
    final vitamins = [
      {
        'emoji': '🧡',
        'name': 'วิตามิน B Complex',
        'benefit': 'ช่วยสร้างสาร serotonin, dopamine ลดอาการเหนื่อยล้าจากเครียด',
        'source': 'ธัญพืชเต็มเมล็ด, ไข่, นม, ตับ',
        'color': const Color(0xFFFF9800),
      },
      {
        'emoji': '🍊',
        'name': 'วิตามิน C',
        'benefit': 'ลดระดับ cortisol ได้ถึง 25% เสริมภูมิคุ้มกัน',
        'source': 'ส้ม, ฝรั่ง, พริกหวาน, มะละกอ',
        'color': const Color(0xFFF57C00),
      },
      {
        'emoji': '☀️',
        'name': 'วิตามิน D',
        'benefit': 'ควบคุมอารมณ์ ลดความเสี่ยงภาวะความเครียดสะสม',
        'source': 'แสงแดด, ปลาทะเล, ไข่แดง, นมเสริม',
        'color': const Color(0xFFFFC107),
      },
      {
        'emoji': '💚',
        'name': 'แมกนีเซียม',
        'benefit': 'คลายกล้ามเนื้อ สงบระบบประสาท ช่วยนอนหลับ',
        'source': 'ผักใบเขียว, อัลมอนด์, กล้วย, ดาร์กช็อกโกแลต',
        'color': const Color(0xFF4CAF50),
      },
      {
        'emoji': '🔵',
        'name': 'ซิงค์ (สังกะสี)',
        'benefit': 'สนับสนุนระบบประสาท ลดอาการวิตกกังวล',
        'source': 'เนื้อสัตว์, ถั่ว, เมล็ดฟักทอง, หอยนางรม',
        'color': const Color(0xFF2196F3),
      },
      {
        'emoji': '🟣',
        'name': 'L-Theanine',
        'benefit': 'เพิ่มคลื่นสมอง Alpha ช่วยผ่อนคลายโดยไม่ง่วง',
        'source': 'ชาเขียว, ชามัทฉะ',
        'color': const Color(0xFF7E57C2),
      },
    ];

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: vitamins.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildInfoCard(
            icon: Icons.science_rounded,
            title: 'วิตามินและแร่ธาตุสำคัญ',
            description: 'เมื่อเครียด ร่างกายใช้วิตามินและแร่ธาตุมากขึ้น ทำให้ขาดสารอาหารที่สำคัญต่อระบบประสาท การเสริมสารอาหารเหล่านี้ช่วยฟื้นฟูสมดุลของสมอง',
            gradientColors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
          );
        }
        final v = vitamins[index - 1];
        return _buildVitaminCard(
          emoji: v['emoji'] as String,
          name: v['name'] as String,
          benefit: v['benefit'] as String,
          source: v['source'] as String,
          color: v['color'] as Color,
        );
      },
    );
  }

  Widget _buildDrinkTab() {
    final drinks = [
      {
        'emoji': '🍵',
        'name': 'ชาเขียว',
        'benefit': 'L-Theanine ช่วยเพิ่มคลื่น Alpha ในสมอง ให้ความผ่อนคลายแต่ยังตื่นตัว',
        'warning': 'ดื่มไม่เกิน 3-4 ถ้วย/วัน เพราะมีคาเฟอีน',
        'color': const Color(0xFF66BB6A),
      },
      {
        'emoji': '🥛',
        'name': 'นมอุ่น',
        'benefit': 'ทริปโตเฟนช่วยสร้าง melatonin เหมาะดื่มก่อนนอนเพื่อลดเครียดและช่วยนอนหลับ',
        'warning': '',
        'color': const Color(0xFF90CAF9),
      },
      {
        'emoji': '🌿',
        'name': 'ชาคาโมมายล์',
        'benefit': 'สาร apigenin จับกับ GABA receptors ในสมอง ช่วยลดความวิตกกังวลคล้ายยาคลายเครียดแบบธรรมชาติ',
        'warning': 'หลีกเลี่ยงหากแพ้พืชตระกูลเดซี่',
        'color': const Color(0xFFFDD835),
      },
      {
        'emoji': '💧',
        'name': 'น้ำเปล่า',
        'benefit': 'ภาวะขาดน้ำเพียง 1-2% ก็ทำให้ cortisol สูงขึ้น ดื่มน้ำเพียงพอช่วยลดเครียดง่ายที่สุด',
        'warning': 'แนะนำ 8-10 แก้ว/วัน',
        'color': const Color(0xFF42A5F5),
      },
      {
        'emoji': '🍋',
        'name': 'น้ำมะนาวน้ำผึ้ง',
        'benefit': 'วิตามิน C ลด cortisol, น้ำผึ้งให้พลังงานช้าไม่กระตุ้นน้ำตาล ช่วยรู้สึกสดชื่นและสงบ',
        'warning': 'ใช้น้ำอุ่น ไม่ใช่น้ำร้อน',
        'color': const Color(0xFFFFCA28),
      },
    ];

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: drinks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildInfoCard(
            icon: Icons.water_drop_rounded,
            title: 'เครื่องดื่มลดเครียด',
            description: 'เครื่องดื่มที่เลือกดื่มมีผลต่อระดับความเครียดโดยตรง ควรหลีกเลี่ยงกาแฟหลัง 14:00 น. และเลือกดื่มเครื่องดื่มที่ช่วยสงบจิตใจแทน',
            gradientColors: [const Color(0xFF11998e), const Color(0xFF38ef7d)],
          );
        }
        final d = drinks[index - 1];
        return _buildDrinkCard(
          emoji: d['emoji'] as String,
          name: d['name'] as String,
          benefit: d['benefit'] as String,
          warning: d['warning'] as String,
          color: d['color'] as Color,
        );
      },
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required List<Color> gradientColors,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassDecoration(
        color: gradientColors[0],
        opacity: 0.08,
        borderColor: gradientColors[0].withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gradientColors[0].withValues(alpha: 0.8), gradientColors[1].withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: gradientColors[0],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableFoodCard(_NutritionItem item, int index) {
    final isExpanded = _expandedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.glassDecoration(
        color: isExpanded ? item.color : Colors.white,
        opacity: isExpanded ? 0.08 : 0.55,
        borderColor: isExpanded ? item.color.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() {
              _expandedIndex = isExpanded ? -1 : index;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 28))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.keyNutrient,
                            style: TextStyle(fontSize: 12, color: item.color, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.benefit,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isExpanded ? item.color : Colors.grey[400],
                      ),
                    ),
                  ],
                ),

                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.grey[200],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.science_rounded, size: 16, color: item.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'สรรพคุณ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: item.color,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.detail,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.6),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.restaurant_menu_rounded, size: 16, color: item.color),
                            const SizedBox(width: 8),
                            Text(
                              item.portion,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: item.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVitaminCard({
    required String emoji,
    required String name,
    required String benefit,
    required String source,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  benefit,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco_rounded, size: 14, color: color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'แหล่งอาหาร: $source',
                          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrinkCard({
    required String emoji,
    required String name,
    required String benefit,
    required String warning,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  benefit,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
                ),
                if (warning.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            warning,
                            style: const TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionItem {
  final String emoji;
  final String name;
  final String keyNutrient;
  final String benefit;
  final String detail;
  final String portion;
  final Color color;

  const _NutritionItem({
    required this.emoji,
    required this.name,
    required this.keyNutrient,
    required this.benefit,
    required this.detail,
    required this.portion,
    required this.color,
  });
}
