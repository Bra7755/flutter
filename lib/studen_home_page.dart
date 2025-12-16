import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'login_page.dart';
import 'messages_page.dart';
import 'quiz_page.dart';
import 'theme_controller.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  List<Map<String, dynamic>> professors = [];
  bool isLoading = true;
  Map<String, dynamic>? studentData;
  Map<String, dynamic> quizAttemptsByCourse = {};

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      // Get student data from database
      final studentResponse = await Supabase.instance.client
          .from('students')
          .select()
          .eq('id', user.id)
          .single();

      // Get courses for this student's class
      print('Student class: "${studentResponse['class']}" (type: ${studentResponse['class'].runtimeType})');
      final courseResponse = await Supabase.instance.client
          .from('courses')
          .select('id, title, description, file_url, file_type, file_name, professor_id, created_at, target_classes')
          .contains('target_classes', [studentResponse['class']]);

      print('Found ${courseResponse.length} courses for student');
      
      // Get professor info for each course
      List<Map<String, dynamic>> coursesWithProfessors = [];
      for (var course in courseResponse) {
        print('Course: ${course['title']} - Target classes: ${course['target_classes']}');
        final professor = await Supabase.instance.client
            .from('professors')
            .select('name, subject')
            .eq('id', course['professor_id'])
            .single();
        
        course['professor_name'] = professor['name'];
        course['professor_subject'] = professor['subject'];
        coursesWithProfessors.add(course);
      }

      // Get existing quiz attempts for this student
      final attempts = await Supabase.instance.client
          .from('quiz_attempts')
          .select('course_id, score')
          .eq('student_id', user.id);
      final attemptMap = <String, Map<String, dynamic>>{};
      for (final a in attempts) {
        final cid = a['course_id'] as String?;
        if (cid != null) {
          attemptMap[cid] = Map<String, dynamic>.from(a as Map);
        }
      }

      setState(() {
        studentData = studentResponse;
        professors = coursesWithProfessors;
        quizAttemptsByCourse = attemptMap;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
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
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Student Account Info Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.deepPurple,
                          child: Text(
                            studentData?['name']?.substring(0, 1).toUpperCase() ?? 'S',
                            style: const TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, ${studentData?['name'] ?? 'Student'}!',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Class: ${studentData?['class'] ?? 'N/A'}',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                              Text(
                                'Email: ${studentData?['email'] ?? 'N/A'}',
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text('Account Active', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildXpBar(),
            const SizedBox(height: 20),
            const Text(
              'Available Courses:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : professors.isEmpty
                  ? const Center(child: Text('No courses available for your class yet.'))
                  : ListView.builder(
                itemCount: professors.length,
                itemBuilder: (context, index) {
                  final course = professors[index];
                  final attempt = quizAttemptsByCourse[course['id']];
                  return CourseCard(
                    course: course,
                    attemptScore: attempt != null ? attempt['score'] as int : null,
                    onQuizTap: () async {
                      if (attempt != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('You already took this quiz.')),
                        );
                        return;
                      }
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuizPage(
                            courseId: course['id'],
                            courseTitle: course['title'] ?? 'Quiz',
                            currentXp: (studentData?['xp'] ?? 0) as int,
                          ),
                        ),
                      );
                      await _loadStudentData();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildXpBar() {
    final xp = (studentData?['xp'] ?? 0) as int;
    const maxXp = 300;
    final progress = xp <= 0 ? 0.0 : (xp / maxXp).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'XP Progress',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text('$xp / $maxXp'),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
        ),
      ],
    );
  }
}

class CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final int? attemptScore;
  final VoidCallback onQuizTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.attemptScore,
    required this.onQuizTap,
  });

  Future<void> _openCourse(BuildContext context) async {
    final url = course['file_url'] as String?;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file attached for this course.')),
      );
      return;
    }

    if (!await canLaunchUrlString(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open: $url')),
      );
      return;
    }

    await launchUrlString(url, mode: LaunchMode.externalApplication);
  }

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
    final professorName = course['professor_name'] ?? 'Unknown Professor';
    final professorSubject = course['professor_subject'] ?? 'N/A';

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
                        style: TextStyle(fontSize: 14, color: const Color.fromARGB(255, 117, 117, 117)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              course['description'] ?? 'No description',
              style: TextStyle(fontSize: 14, color: const Color.fromARGB(255, 97, 97, 97)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '$professorName - $professorSubject',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _openCourse(context),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  attemptScore != null ? 'Quiz taken: $attemptScore pts' : 'Quiz available',
                  style: TextStyle(
                    fontSize: 12,
                    color: attemptScore != null ? Colors.green[700] : Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ElevatedButton(
                  onPressed: attemptScore != null ? null : onQuizTap,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white ,
                    backgroundColor: attemptScore != null ? const Color.fromARGB(255, 158, 158, 158) : Colors.deepPurple,
                  ),
                  child: const Text('Take Quiz'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
