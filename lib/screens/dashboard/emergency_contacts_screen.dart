import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  final User user;

  const EmergencyContactsScreen({super.key, required this.user});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<dynamic> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getEmergencyContacts(widget.user.id);
    if (result['success'] == true) {
      setState(() {
        _contacts = result['contacts'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteContact(int contactId) async {
    final result = await ApiService.deleteEmergencyContact(contactId);
    if (result['success'] == true) {
      _loadContacts();
    }
  }

  void _showAddContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('เพิ่มผู้ติดต่อฉุกเฉิน', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'ชื่อ-นามสกุล',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'เบอร์โทรศัพท์',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: relController,
                    decoration: InputDecoration(
                      labelText: 'ความสัมพันธ์ (เช่น ลูก, หลาน)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (nameController.text.isEmpty || phoneController.text.isEmpty) return;
                  setDialogState(() => isSaving = true);
                  final result = await ApiService.addEmergencyContact(
                    userId: widget.user.id,
                    contactName: nameController.text.trim(),
                    phoneNumber: phoneController.text.trim(),
                    relationship: relController.text.trim(),
                  );
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    if (result['success'] == true) {
                      _loadContacts();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('บันทึก', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ผู้ติดต่อฉุกเฉิน', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddContactDialog,
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('เพิ่มผู้ติดต่อ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.contact_phone_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('ยังไม่มีผู้ติดต่อฉุกเฉิน', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, color: AppColors.primaryBlue),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contact['contact_name']?.toString() ?? '-',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  contact['phone_number']?.toString() ?? '-',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                if (contact['relationship'] != null && contact['relationship'].toString().isNotEmpty)
                                  Text(
                                    contact['relationship'].toString(),
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('ลบผู้ติดต่อ'),
                                  content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบผู้ติดต่อรายนี้?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deleteContact(contact['contact_id'] ?? contact['id']);
                                      },
                                      child: const Text('ลบ', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
