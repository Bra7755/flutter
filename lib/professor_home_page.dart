import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'login_page.dart';
import 'messages_page.dart';
import 'quiz_builder_page.dart';
import 'professor_students_page.dart';
import 'theme_controller.dart';

class ProfessorHomePage extends StatefulWidget {
  const ProfessorHomePage({super.key});

  @override
  State<ProfessorHomePage> createState() => _ProfessorHomePageState();
}

class _ProfessorHomePageState extends State<ProfessorHomePage> {
  Map<String, dynamic>? professorData;
  List<Map<String, dynamic>> courses = [];
  bool isLoading = true;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfessorData();
  }

  Future<void> _loadProfessorData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      final professorResponse = await Supabase.instance.client
          .from('professors')
          .select()
          .eq('id', user.id)
          .single();

      final coursesResponse = await Supabase.instance.client
          .from('courses')
          .select()
          .eq('professor_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        professorData = professorResponse;
        courses = List<Map<String, dynamic>>.from(coursesResponse);
        isLoading = false;
      });
    } catch (e) {
      print('Error loading professor data: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  Future<void> _addCourse() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddCourseDialog(),
    );

    if (result != null) {
      await _uploadCourse(result);
    }
  }

  Future<void> _uploadCourse(Map<String, dynamic> courseData) async {
    setState(() => isUploading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      
      print('Creating course with target_classes: ${courseData['target_classes']}');
      await Supabase.instance.client.from('courses').insert({
        'professor_id': user!.id,
        'title': courseData['title'],
        'description': courseData['description'],
        'file_url': courseData['file_url'],
        'file_type': courseData['file_type'],
        'file_name': courseData['file_name'],
        'target_classes': courseData['target_classes'],
        'created_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course published successfully!')),
      );
      
      _loadProfessorData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error publishing course: $e')),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _editCourse(Map<String, dynamic> course) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddCourseDialog(
        existingCourse: course,
        isEditing: true,
      ),
    );

    if (result != null) {
      await _updateCourse(course['id'], result);
    }
  }

  Future<void> _updateCourse(String courseId, Map<String, dynamic> courseData) async {
    try {
      await Supabase.instance.client.from('courses').update({
        'title': courseData['title'],
        'description': courseData['description'],
        'file_url': courseData['file_url'],
        'file_type': courseData['file_type'],
        'file_name': courseData['file_name'],
        'target_classes': courseData['target_classes'],
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', courseId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course updated successfully!')),
      );
      
      _loadProfessorData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating course: $e')),
      );
    }
  }

  Future<void> _deleteCourse(String courseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: const Text('Are you sure you want to delete this course?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client.from('courses').delete().eq('id', courseId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course deleted successfully!')),
        );
        
        _loadProfessorData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting course: $e')),
        );
      }
    }
  }

  void _openQuizBuilder(Map<String, dynamic> course) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizBuilderPage(
          courseId: course['id'],
          courseTitle: course['title'] ?? 'Course Quiz',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Professor Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MessagesPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: 'Toggle theme',
            onPressed: ThemeController.toggle,
          ),
          IconButton(
            icon: const Icon(Icons.group),
            tooltip: 'My Students',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfessorStudentsPage()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Text(
                              professorData?['name']?.substring(0, 1).toUpperCase() ?? 'P',
                              style: const TextStyle(color: Colors.white, fontSize: 20),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  professorData?['name'] ?? 'Professor',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Subject: ${professorData?['subject'] ?? 'N/A'}',
                                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                ),
                                Text(
                                  'Classes: ${(professorData?['classes_taught'] as List?)?.join(', ') ?? 'N/A'}',
                                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Courses',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      ElevatedButton.icon(
                        onPressed: isUploading ? null : _addCourse,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Course'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: courses.isEmpty
                        ? const Center(child: Text('No courses published yet.'))
                        : ListView.builder(
                            itemCount: courses.length,
                            itemBuilder: (context, index) {
                              final course = courses[index];
                              return CourseCard(
                                course: course,
                                onEdit: () => _editCourse(course),
                                onDelete: () => _deleteCourse(course['id']),
                                onAddQuiz: () => _openQuizBuilder(course),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddQuiz;

  const CourseCard({
    super.key,
    required this.course,
    required this.onEdit,
    required this.onDelete,
    required this.onAddQuiz,
  });

  IconData _getFileIcon(String? fileType) {
    switch (fileType?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileType = course['file_type'] ?? '';
    final fileName = course['file_name'] ?? 'Unknown file';
    final targetClasses = (course['target_classes'] as List?)?.join(', ') ?? 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getFileIcon(fileType),
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course['title'] ?? 'Untitled Course',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        fileName,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Text('Edit'),
                      onTap: onEdit,
                    ),
                    PopupMenuItem(
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      onTap: onDelete,
                    ),
                    PopupMenuItem(
                      child: const Text('Manage Quiz'),
                      onTap: onAddQuiz,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              course['description'] ?? 'No description',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Target Classes: $targetClasses',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class AddCourseDialog extends StatefulWidget {
  final Map<String, dynamic>? existingCourse;
  final bool isEditing;

  const AddCourseDialog({
    super.key,
    this.existingCourse,
    this.isEditing = false,
  });

  @override
  State<AddCourseDialog> createState() => _AddCourseDialogState();
}

class _AddCourseDialogState extends State<AddCourseDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _fileUrlController = TextEditingController();
  String? _fileUrl;
  String? _fileType;
  String? _fileName;
  List<String> _selectedClasses = [];
  bool _isUploading = false;

  final List<String> _availableClasses = [
    '1ere GLSI',
    '2eme GLSI',
    '3eme GLSI',
    'Cycle Ingenieur',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.existingCourse != null) {
      _titleController.text = widget.existingCourse!['title'] ?? '';
      _descriptionController.text = widget.existingCourse!['description'] ?? '';
      _fileUrl = widget.existingCourse!['file_url'];
      _fileUrlController.text = widget.existingCourse!['file_url'] ?? '';
      _fileType = widget.existingCourse!['file_type'];
      _fileName = widget.existingCourse!['file_name'];
      _selectedClasses = List<String>.from(widget.existingCourse!['target_classes'] ?? []);
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'mp4', 'avi', 'mov', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _fileName = result.files.single.name;
          _fileType = result.files.single.extension?.toLowerCase();
          // Ask user to paste/upload a real link; we do not auto-upload files here.
          _fileUrl = _fileUrlController.text;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit Course' : 'Add New Course'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Course Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) => value?.isEmpty ?? true ? 'Description is required' : null,
            ),
            const SizedBox(height: 16),
            
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: Text(_fileName ?? 'Choose a file'),
              subtitle: const Text('PDF, Video, or Image files'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _pickFile,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fileUrlController,
              decoration: const InputDecoration(
                labelText: 'File URL (Supabase Storage or public link)',
                border: OutlineInputBorder(),
                hintText: 'https://your-bucket.supabase.co/storage/v1/object/public/...',
              ),
              onChanged: (value) => _fileUrl = value.trim(),
            ),
            const SizedBox(height: 16),
            
            const Text('Target Classes:', style: TextStyle(fontWeight: FontWeight.bold)),
            ..._availableClasses.map((className) => CheckboxListTile(
              title: Text(className),
              value: _selectedClasses.contains(className),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedClasses.add(className);
                  } else {
                    _selectedClasses.remove(className);
                  }
                });
              },
            )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _submitCourse,
          child: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.isEditing ? 'Update' : 'Publish'),
        ),
      ],
    );
  }

  void _submitCourse() {
    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _fileName == null ||
        (_fileUrlController.text.trim().isEmpty && (_fileUrl == null || _fileUrl!.isEmpty)) ||
        _selectedClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields, select a file, and provide a valid file URL')),
      );
      return;
    }

    final courseData = {
      'title': _titleController.text,
      'description': _descriptionController.text,
      'file_url': _fileUrlController.text.trim().isNotEmpty ? _fileUrlController.text.trim() : _fileUrl,
      'file_type': _fileType,
      'file_name': _fileName,
      'target_classes': _selectedClasses,
    };

    Navigator.of(context).pop(courseData);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _fileUrlController.dispose();
    super.dispose();
  }
}
