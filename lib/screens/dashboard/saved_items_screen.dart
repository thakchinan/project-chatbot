import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// SavedItemsScreen คือหน้าจอรายการบทความและข้อมูลการดูแลสมองที่ผู้ใช้เลือกบันทึกเก็บไว้
/// ทำงานแสดงผลการ์ดแนะนำสุขภาพจิต โภชนาการ และการผ่อนคลายที่บันทึกไว้ในบุ๊กมาร์ก (Bookmarked Articles)
class SavedItemsScreen extends StatelessWidget {
  const SavedItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'บันทึกไว้',
          style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryBlue.withValues(alpha: 0.1),
                    AppColors.primaryBlue.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Icon(Icons.bookmark, size: 48, color: AppColors.primaryBlue),
                  const SizedBox(height: 12),
                  Text(
                    'รายการที่บันทึกไว้',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'บทความและข้อมูลที่คุณบันทึกไว้อ่านภายหลัง',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'บทความสุขภาพจิต',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),

            _buildSavedCard(
              icon: Icons.article,
              iconColor: Colors.blue,
              title: '5 วิธีลดความเครียดในชีวิตประจำวัน',
              description: 'เทคนิคง่ายๆ ที่ช่วยลดความเครียดได้อย่างมีประสิทธิภาพ ตั้งแต่การหายใจลึก ออกกำลังกาย ไปจนถึงการทำสมาธิ',
              category: 'สุขภาพจิต',
            ),
            _buildSavedCard(
              icon: Icons.psychology,
              iconColor: Colors.purple,
              title: 'ทำความเข้าใจคลื่นสมอง EEG',
              description: 'รู้จักคลื่นสมองแต่ละประเภท Alpha, Beta, Theta, Delta และ Gamma ว่ามีผลต่อร่างกายอย่างไร',
              category: 'ความรู้',
            ),

            const SizedBox(height: 24),

            Text(
              'อาหารบำรุงสมอง',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),

            _buildSavedCard(
              icon: Icons.restaurant,
              iconColor: Colors.green,
              title: 'อาหารบำรุงสมอง Top 5',
              description: 'ปลาแซลมอน ถั่ว เบอร์รี่ ไข่ และผักใบเขียว อาหารที่ช่วยเสริมการทำงานของสมอง',
              category: 'โภชนาการ',
            ),

            const SizedBox(height: 24),

            Text(
              'เทคนิคการดูแลสมอง',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),

            _buildSavedCard(
              icon: Icons.self_improvement,
              iconColor: Colors.teal,
              title: 'เทคนิคการหายใจ 4-7-8',
              description: 'หายใจเข้า 4 วินาที กลั้น 7 วินาที หายใจออก 8 วินาที ช่วยลดความเครียดและเพิ่มสมาธิ',
              category: 'สมาธิ',
            ),
            _buildSavedCard(
              icon: Icons.bedtime,
              iconColor: Colors.indigo,
              title: 'นอนหลับให้มีคุณภาพ',
              description: 'เทคนิคการนอนหลับที่ดี หลีกเลี่ยงหน้าจอก่อนนอน ตั้งเวลานอนให้สม่ำเสมอ',
              category: 'การนอน',
            ),
            _buildSavedCard(
              icon: Icons.fitness_center,
              iconColor: Colors.orange,
              title: 'ออกกำลังกายเพื่อสมอง',
              description: 'การออกกำลังกายแบบแอโรบิก 30 นาทีต่อวัน ช่วยเพิ่มเลือดไปเลี้ยงสมองและสร้างเซลล์ใหม่',
              category: 'ออกกำลังกาย',
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String category,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(fontSize: 10, color: iconColor, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.bookmark, color: AppColors.primaryBlue, size: 20),
        ],
      ),
    );
  }
}
