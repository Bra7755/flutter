import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizPage extends StatefulWidget {
  final String courseId;
  final String courseTitle;
  final int currentXp;

  const QuizPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.currentXp,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> questions = [];
  Map<String, String> selectedOptions = {};
  bool isLoading = true;
  bool isSubmitting = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final data = await _supabase
          .from('quiz_questions')
          .select('id, question_text, option_a, option_b, option_c, option_d, correct_option')
          .eq('course_id', widget.courseId)
          .order('created_at');

      setState(() {
        questions = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorText = 'Error loading quiz: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _submitQuiz() async {
    if (questions.isEmpty) return;
    if (selectedOptions.length != questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions.')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      int correctCount = 0;
      for (final q in questions) {
        final selected = selectedOptions[q['id']] ?? '';
        if (selected.toLowerCase() == (q['correct_option'] as String).toLowerCase()) {
          correctCount++;
        }
      }

      final score = correctCount * 30;

      // Prevent duplicate attempts (one lifetime)
      final existing = await _supabase
          .from('quiz_attempts')
          .select('id')
          .eq('course_id', widget.courseId)
          .eq('student_id', user.id)
          .maybeSingle();
      if (existing != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already took this quiz.')),
        );
        if (mounted) Navigator.of(context).pop();
        return;
      }

      await _supabase.from('quiz_attempts').insert({
        'course_id': widget.courseId,
        'student_id': user.id,
        'score': score,
      });

      // Update XP on students table
      final newXp = widget.currentXp + score;
      await _supabase
          .from('students')
          .update({'xp': newXp})
          .eq('id', user.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quiz submitted! +$score XP')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting quiz: $e')),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courseTitle} Quiz'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorText != null
              ? Center(child: Text(errorText!))
              : questions.isEmpty
                  ? const Center(child: Text('Quiz not available for this course yet.'))
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: questions.length,
                              itemBuilder: (context, index) {
                                final q = questions[index];
                                final opts = {
                                  'A': q['option_a'] ?? '',
                                  'B': q['option_b'] ?? '',
                                  'C': q['option_c'] ?? '',
                                  'D': q['option_d'] ?? '',
                                };

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Q${index + 1}. ${q['question_text'] ?? ''}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ...opts.entries.map(
                                          (entry) => RadioListTile<String>(
                                            value: entry.key,
                                            groupValue: selectedOptions[q['id']],
                                            onChanged: (val) {
                                              setState(() {
                                                selectedOptions[q['id']] = val!;
                                              });
                                            },
                                            title: Text('${entry.key}) ${entry.value}'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isSubmitting ? null : _submitQuiz,
                              child: isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Submit Quiz'),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
