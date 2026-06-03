import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class CaretakerScreen extends StatelessWidget {
  const CaretakerScreen({super.key});

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
          'ผู้ดูแล',
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
                  Icon(Icons.people, size: 48, color: AppColors.primaryBlue),
                  const SizedBox(height: 12),
                  Text(
                    'ทีมดูแลสุขภาพจิต',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ผู้เชี่ยวชาญที่พร้อมให้คำปรึกษา',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'ผู้เชี่ยวชาญ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),

            _buildCaretakerCard(
              icon: Icons.person,
              name: 'นพ.สมชาย ใจดี',
              role: 'จิตแพทย์',
              specialty: 'เชี่ยวชาญด้านความเครียดและวิตกกังวล',
              phone: '02-123-4567',
            ),
            _buildCaretakerCard(
              icon: Icons.person_outline,
              name: 'คุณสมหญิง เยี่ยมยอด',
              role: 'นักจิตวิทยา',
              specialty: 'ให้คำปรึกษาด้านสุขภาพจิต CBT',
              phone: '02-987-6543',
            ),

            const SizedBox(height: 24),

            Text(
              'สายด่วนฉุกเฉิน',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),

            _buildEmergencyCard(
              icon: Icons.emergency,
              iconColor: Colors.red,
              title: 'สายด่วนสุขภาพจิต',
              number: '1323',
              description: 'ให้บริการ 24 ชั่วโมง',
            ),
            _buildEmergencyCard(
              icon: Icons.local_hospital,
              iconColor: Colors.green,
              title: 'สายด่วนสุขภาพ',
              number: '1669',
              description: 'บริการฉุกเฉินทางการแพทย์',
            ),
            _buildEmergencyCard(
              icon: Icons.shield,
              iconColor: Colors.blue,
              title: 'สมาริตันส์แห่งประเทศไทย',
              number: '02-713-6793',
              description: 'รับฟังปัญหาทุกเรื่อง',
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCaretakerCard({
    required IconData icon,
    required String name,
    required String role,
    required String specialty,
    required String phone,
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
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
            child: Icon(icon, color: AppColors.primaryBlue, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(role, style: TextStyle(fontSize: 13, color: AppColors.primaryBlue, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(specialty, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _launchUrl('tel:$phone'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.phone, color: Colors.green, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String number,
    required String description,
  }) {
    return GestureDetector(
      onTap: () => _launchUrl('tel:$number'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: iconColor.withValues(alpha: 0.2)),
        ),
        child: Row(
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
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            Text(
              number,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
