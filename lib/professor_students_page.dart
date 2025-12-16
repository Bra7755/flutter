import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfessorStudentsPage extends StatefulWidget {
  const ProfessorStudentsPage({super.key});

  @override
  State<ProfessorStudentsPage> createState() => _ProfessorStudentsPageState();
}

class _ProfessorStudentsPageState extends State<ProfessorStudentsPage> {
  final _supabase = Supabase.instance.client;
  List<String> classes = [];
  String? selectedClass;
  List<Map<String, dynamic>> students = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClassesAndStudents();
  }

  Future<void> _loadClassesAndStudents() async {
    setState(() => isLoading = true);
    try {
      final prof = _supabase.auth.currentUser;
      if (prof == null) return;

      final profData = await _supabase
          .from('professors')
          .select('classes_taught')
          .eq('id', prof.id)
          .single();
      final cls = List<String>.from(profData['classes_taught'] ?? []);
      classes = cls;
      selectedClass ??= classes.isNotEmpty ? classes.first : null;

      await _loadStudents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading classes: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadStudents() async {
    if (selectedClass == null) return;
    try {
      final rows = await _supabase
          .from('students')
          .select('name, email, class, xp')
          .eq('class', selectedClass!);
      setState(() {
        students = List<Map<String, dynamic>>.from(rows);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading students: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Students')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : classes.isEmpty
              ? const Center(child: Text('No classes assigned yet.'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Classes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: classes
                            .map(
                              (c) => ChoiceChip(
                                label: Text(c),
                                selected: selectedClass == c,
                                onSelected: (_) {
                                  setState(() {
                                    selectedClass = c;
                                  });
                                  _loadStudents();
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: students.isEmpty
                            ? const Center(child: Text('No students found for this class.'))
                            : ListView.builder(
                                itemCount: students.length,
                                itemBuilder: (context, index) {
                                  final s = students[index];
                                  return _StudentCard(student: s);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final xp = (student['xp'] ?? 0) as int;
    const maxXp = 300;
    final progress = xp <= 0 ? 0.0 : (xp / maxXp).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    (student['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'S',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] ?? 'Student',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        student['email'] ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('XP: $xp / $maxXp', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
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
        ),
      ),
    );
  }
}
