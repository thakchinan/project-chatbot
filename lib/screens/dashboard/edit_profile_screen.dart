import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final User user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _birthDateController;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  File? _selectedImage;
  String? _currentAvatarUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fullNameController =
        TextEditingController(text: widget.user.fullName ?? '');
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _birthDateController =
        TextEditingController(text: widget.user.birthDate ?? '');
    _currentAvatarUrl = widget.user.avatarUrl;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Image picking error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถเลือกรูปภาพได้: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Text(
                'เลือกรูปโปรไฟล์',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 20),

              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      Icon(Icons.photo_library, color: AppColors.primaryBlue),
                ),
                title: const Text('เลือกจากแกลเลอรี่'),
                subtitle: Text(
                  'เลือกรูปภาพที่มีอยู่แล้ว',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),

              const Divider(height: 8),

              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.green),
                ),
                title: const Text('ถ่ายรูปใหม่'),
                subtitle: Text(
                  'ถ่ายรูปจากกล้อง',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),

              if (_currentAvatarUrl != null ||
                  _selectedImage != null) ...[
                const Divider(height: 8),
                ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete, color: Colors.red),
                  ),
                  title: const Text(
                    'ลบรูปโปรไฟล์',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImage = null;
                      _currentAvatarUrl = null;
                    });
                  },
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    DateTime initialDate = DateTime(2000);
    if (_birthDateController.text.isNotEmpty) {
      try {
        final parts = _birthDateController.text.split('-');
        if (parts.length == 3) {
          initialDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      } catch (e) {
        debugPrint('Error parsing initial date: $e');
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthDateController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _currentAvatarUrl;

    setState(() => _isUploadingImage = true);

    final result = await ApiService.uploadAvatar(
      userId: widget.user.id,
      imageFile: _selectedImage!,
    );

    setState(() => _isUploadingImage = false);

    if (result['success'] == true) {
      return result['avatar_url'] as String;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'อัปโหลดรูปไม่สำเร็จ'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!_emailController.text.contains('@')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อีเมลต้องมีเครื่องหมาย @'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_phoneController.text.length != 10 ||
        !RegExp(r'^[0-9]+$').hasMatch(_phoneController.text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เบอร์โทรศัพท์ต้องเป็นตัวเลข 10 หลักเท่านั้น'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    String? avatarUrl = _currentAvatarUrl;
    if (_selectedImage != null) {
      avatarUrl = await _uploadImage();
    }

    final result = await ApiService.updateProfile(
      userId: widget.user.id,
      fullName: _fullNameController.text,
      phone: _phoneController.text,
      email: _emailController.text,
      birthDate: _birthDateController.text,
    );

    if (_currentAvatarUrl == null && widget.user.avatarUrl != null) {
      await ApiService.updateProfile(
        userId: widget.user.id,
      );
    }

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final updatedUser = widget.user.copyWith(
        fullName: _fullNameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        birthDate: _birthDateController.text,
        avatarUrl: avatarUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อัปเดตโปรไฟล์สำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, updatedUser);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'เกิดข้อผิดพลาด'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
          'แก้ไขโปรไฟล์',
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

            Center(
              child: GestureDetector(
                onTap: _showImagePickerOptions,
                child: Stack(
                  children: [

                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color:
                            AppColors.primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              AppColors.primaryBlue.withValues(alpha: 0.3),
                          width: 3,
                        ),
                        image: _getAvatarDecoration(),
                      ),
                      child: _getAvatarChild(),
                    ),

                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    if (_isUploadingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _showImagePickerOptions,
                child: Text(
                  'แก้ไขรูปโปรไฟล์',
                  style: TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            _buildLabel('ชื่อจริง-นามสกุล'),
            _buildTextField(
              controller: _fullNameController,
              hintText: 'ชื่อจริง นามสกุล',
            ),

            const SizedBox(height: 16),

            _buildLabel('เบอร์โทรศัพท์'),
            _buildTextField(
              controller: _phoneController,
              hintText: '0xxxxxxxxx',
              keyboardType: TextInputType.phone,
              maxLength: 10,
            ),

            const SizedBox(height: 16),

            _buildLabel('อีเมล'),
            _buildTextField(
              controller: _emailController,
              hintText: 'example@email.com',
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 16),

            _buildLabel('วัน/เดือน/ปีเกิด'),
            _buildTextField(
              controller: _birthDateController,
              hintText: 'เลือกวัน/เดือน/ปีเกิด',
              readOnly: true,
              onTap: _selectBirthDate,
              suffixIcon: Icon(
                Icons.calendar_today,
                color: AppColors.primaryBlue,
              ),
            ),

            const SizedBox(height: 30),

            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'บันทึกการเปลี่ยนแปลง',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DecorationImage? _getAvatarDecoration() {
    if (_selectedImage != null) {
      return DecorationImage(
        image: FileImage(_selectedImage!),
        fit: BoxFit.cover,
      );
    }
    if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      return DecorationImage(
        image: NetworkImage(_currentAvatarUrl!),
        fit: BoxFit.cover,
      );
    }
    return null;
  }

  Widget? _getAvatarChild() {
    if (_selectedImage != null || (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty)) {
      return null;
    }
    return Icon(
      Icons.person,
      size: 50,
      color: AppColors.primaryBlue,
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    int? maxLength,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        counterText: '',
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
