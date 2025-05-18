import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MedicineReminderScreen extends StatefulWidget {
  const MedicineReminderScreen({super.key});

  @override
  State<MedicineReminderScreen> createState() => _MedicineReminderScreenState();
}

class _MedicineReminderScreenState extends State<MedicineReminderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Color Scheme
  final Color primaryDark = const Color(0xFF03045E);
  final Color primary = const Color(0xFF03045E);
  final Color primaryLight = const Color(0xFF00B4D8);
  final Color accentLight = const Color(0xFF90E0EF);
  final Color secondaryDark = const Color(0xFF05668D);
  final Color secondary = const Color(0xFF028090);
  final Color highlight = const Color(0xFFF0F3BD);
  final Color accent = const Color(0xFF02C39A);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _medicineNameController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<TimeOfDay> _reminderTimes = [];
  List<String> _selectedDays = [];
  bool _isLoading = false;
  bool _isEditing = false;
  String? _editingDocId;

  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _loadDataIfEditing();
  }

  void _loadDataIfEditing() {
    if (_isEditing && _editingDocId != null) {
      _firestore.collection('medicine_reminders').doc(_editingDocId).get().then(
        (doc) {
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            _medicineNameController.text = data['name'] ?? '';
            _dosageController.text = data['dosage'] ?? '';
            _notesController.text = data['notes'] ?? '';

            final times = List<String>.from(data['times'] ?? []);
            _reminderTimes = times.map((time) => _stringToTime(time)).toList();

            _selectedDays = List<String>.from(data['days'] ?? []);

            setState(() {});
          }
        },
      );
    }
  }

  Future<void> _saveMedicineReminder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_reminderTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one reminder time'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one day'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final medicineData = {
        'name': _medicineNameController.text.trim(),
        'dosage': _dosageController.text.trim(),
        'notes': _notesController.text.trim(),
        'times': _reminderTimes.map((time) => _timeToString(time)).toList(),
        'days': _selectedDays,
        'userId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing && _editingDocId != null) {
        await _firestore
            .collection('medicine_reminders')
            .doc(_editingDocId)
            .update(medicineData);
      } else {
        medicineData['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('medicine_reminders').add(medicineData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Reminder updated!' : 'Reminder added!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );

      _resetForm();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _timeToString(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat.jm().format(dt); // Changed to 12-hour format with AM/PM
  }

  TimeOfDay _stringToTime(String timeString) {
    final format = DateFormat.jm(); // Changed to 12-hour format with AM/PM
    final dt = format.parse(timeString);
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && !_reminderTimes.contains(picked)) {
      setState(() => _reminderTimes.add(picked));
    }
  }

  void _removeTime(int index) {
    setState(() => _reminderTimes.removeAt(index));
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _medicineNameController.clear();
    _dosageController.clear();
    _notesController.clear();
    setState(() {
      _reminderTimes = [];
      _selectedDays = [];
      _isEditing = false;
      _editingDocId = null;
    });
  }

  void _editReminder(String docId) {
    setState(() {
      _isEditing = true;
      _editingDocId = docId;
    });
    _loadDataIfEditing();
    // Scroll to form
    Future.delayed(const Duration(milliseconds: 300), () {
      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _deleteReminder(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Delete Reminder',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Are you sure you want to delete this reminder?',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),

                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('medicine_reminders').doc(docId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder deleted successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
        if (_isEditing && _editingDocId == docId) {
          _resetForm();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _medicineNameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Medicine Reminder'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accentLight.withOpacity(0.2), Colors.white],
                  stops: [0.1, 0.9],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form Section
                    Card(
                      color: Colors.white,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isEditing
                                    ? 'Edit Reminder'
                                    : 'Add New Reminder',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primaryDark,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Medicine Name
                              TextFormField(
                                controller: _medicineNameController,
                                decoration: InputDecoration(
                                  labelText: 'Medicine Name',
                                  prefixIcon: Icon(
                                    Icons.medical_services,
                                    color: primary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: primary,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                validator:
                                    (value) =>
                                        value!.isEmpty
                                            ? 'Please enter medicine name'
                                            : null,
                              ),
                              const SizedBox(height: 16),

                              // Dosage
                              TextFormField(
                                controller: _dosageController,
                                decoration: InputDecoration(
                                  labelText: 'Dosage (e.g., 1 tablet, 5ml)',
                                  prefixIcon: Icon(
                                    Icons.medication,
                                    color: primary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: primary,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                validator:
                                    (value) =>
                                        value!.isEmpty
                                            ? 'Please enter dosage'
                                            : null,
                              ),
                              const SizedBox(height: 16),

                              // Reminder Times
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Reminder Times',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_reminderTimes.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'No times added yet',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  if (_reminderTimes.isNotEmpty)
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children:
                                          _reminderTimes.asMap().entries.map((
                                            entry,
                                          ) {
                                            final index = entry.key;
                                            final time = entry.value;
                                            return Chip(
                                              label: Text(
                                                time.format(context),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                              backgroundColor: primaryLight
                                                  .withOpacity(0.2),
                                              deleteIcon: const Icon(
                                                Icons.close,
                                                size: 16,
                                              ),
                                              onDeleted:
                                                  () => _removeTime(index),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              side: BorderSide.none,
                                            );
                                          }).toList(),
                                    ),
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    onPressed: () => _selectTime(context),
                                    icon: const Icon(
                                      Icons.access_time,
                                      size: 20,
                                    ),
                                    label: const Text('Add Reminder Time'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryLight,
                                      foregroundColor: primaryDark,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Days of Week
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Days to Repeat',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children:
                                        _daysOfWeek
                                            .map(
                                              (day) => FilterChip(
  label: Text(day),
  selected: _selectedDays.contains(day),
  onSelected: (_) => _toggleDay(day),
  selectedColor: primary,
  checkmarkColor: Colors.white,
  labelStyle: TextStyle(
    color: _selectedDays.contains(day) ? Colors.white : Colors.black,
    fontWeight: FontWeight.w500,
  ),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
  ),
  showCheckmark: true,
  backgroundColor: Colors.white,  // Set the background color to white
),

                                            )
                                            .toList(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Additional Notes
                              TextFormField(
                                controller: _notesController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Additional Notes (optional)',
                                  alignLabelWithHint: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: primary,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Save/Cancel Buttons
                              Row(
                                children: [
                                  if (_isEditing)
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _resetForm,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey,
                                          side: const BorderSide(
                                            color: Colors.grey,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                    ),
                                  if (_isEditing) const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed:
                                          _isLoading
                                              ? null
                                              : _saveMedicineReminder,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            _isEditing ? accent : accent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 3,
                                      ),
                                      child:
                                          _isLoading
                                              ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                              : Text(
                                                _isEditing
                                                    ? 'Update Reminder'
                                                    : 'Save Reminder',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                ),
                                              ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Saved Reminders Section
                    Text(
                      'Your Reminders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream:
                          _firestore
                              .collection('medicine_reminders')
                              .where(
                                'userId',
                                isEqualTo: _auth.currentUser?.uid ?? '',
                              )
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Card(
                            color: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.notifications_off,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No reminders saved yet',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final doc = snapshot.data!.docs[index];
                            final data = doc.data() as Map<String, dynamic>;

                            final times = List<String>.from(
                              data['times'] ?? [],
                            );
                            final days = List<String>.from(data['days'] ?? []);

                            return Card(
                              color: Colors.white,
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            data['name'] ?? 'No name',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: primaryDark,
                                            ),
                                          ),
                                        ),
                                        PopupMenuButton(
                                          icon: Icon(
                                            Icons.more_vert,
                                            color: Colors.grey[600],
                                          ),
                                          itemBuilder:
                                              (context) => [
                                                PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.edit,
                                                        color: primary,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Text('Edit'),
                                                    ],
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.delete,
                                                        color: Colors.red,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Text('Delete'),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _editReminder(doc.id);
                                            } else if (value == 'delete') {
                                              _deleteReminder(doc.id);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.medication,
                                          size: 16,
                                          color: primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Dosage: ${data['dosage'] ?? 'Not specified'}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (data['notes'] != null &&
                                        data['notes'].isNotEmpty)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.notes,
                                                size: 16,
                                                color: primary,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Notes:',
                                                style: TextStyle(fontSize: 14),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            data['notes'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children:
                                          days
                                              .map(
                                                (day) => Chip(
                                                  label: Text(
                                                    day,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  backgroundColor: accentLight
                                                      .withOpacity(0.3),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  side: BorderSide.none,
                                                ),
                                              )
                                              .toList(),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children:
                                          times
                                              .map(
                                                (time) => Chip(
                                                  label: Text(
                                                    time,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  avatar: Icon(
                                                    Icons.access_time,
                                                    size: 16,
                                                    color: primary,
                                                  ),
                                                  backgroundColor: highlight
                                                      .withOpacity(0.3),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  side: BorderSide.none,
                                                ),
                                              )
                                              .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
