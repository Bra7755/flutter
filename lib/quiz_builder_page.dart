import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuizBuilderPage extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const QuizBuilderPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<QuizBuilderPage> createState() => _QuizBuilderPageState();
}

class _QuizBuilderPageState extends State<QuizBuilderPage> {
  final _supabase = Supabase.instance.client;
  final List<_QuizQuestionModel> _questions = List.generate(
    3,
    (_) => _QuizQuestionModel.empty(),
  );
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final data = await _supabase
          .from('quiz_questions')
          .select(
              'id, question_text, option_a, option_b, option_c, option_d, correct_option')
          .eq('course_id', widget.courseId)
          .order('created_at');

      for (int i = 0; i < data.length && i < 3; i++) {
        final q = data[i];
        _questions[i] = _QuizQuestionModel(
          id: q['id'] as String?,
          question: (q['question_text'] ?? '') as String,
          optionA: (q['option_a'] ?? '') as String,
          optionB: (q['option_b'] ?? '') as String,
          optionC: (q['option_c'] ?? '') as String,
          optionD: (q['option_d'] ?? '') as String,
          correct: (q['correct_option'] ?? 'A') as String,
        );
      }
    } catch (_) {
      // keep empty if load fails
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _saveQuiz() async {
    // Validate all 3 questions filled
    for (final q in _questions) {
      if (q.question.trim().isEmpty ||
          q.optionA.trim().isEmpty ||
          q.optionB.trim().isEmpty ||
          q.optionC.trim().isEmpty ||
          q.optionD.trim().isEmpty ||
          q.correct.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fill all fields for all 3 questions.')),
        );
        return;
      }
    }

    setState(() => isSaving = true);
    try {
      // remove existing and insert fresh set
      await _supabase
          .from('quiz_questions')
          .delete()
          .eq('course_id', widget.courseId);

      final rows = _questions
          .map((q) => {
                'course_id': widget.courseId,
                'question_text': q.question.trim(),
                'option_a': q.optionA.trim(),
                'option_b': q.optionB.trim(),
                'option_c': q.optionC.trim(),
                'option_d': q.optionD.trim(),
                'correct_option': q.correct,
              })
          .toList();

      await _supabase.from('quiz_questions').insert(rows);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz saved (3 questions).')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving quiz: $e')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz • ${widget.courseTitle}'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        return _QuestionCard(
                          index: index + 1,
                          model: _questions[index],
                          onChanged: (updated) {
                            setState(() {
                              _questions[index] = updated;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _saveQuiz,
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Quiz (3 questions)'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final _QuizQuestionModel model;
  final ValueChanged<_QuizQuestionModel> onChanged;

  const _QuestionCard({
    required this.index,
    required this.model,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question $index',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: model.question,
              decoration: const InputDecoration(
                labelText: 'Question text',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => onChanged(model.copyWith(question: v)),
            ),
            const SizedBox(height: 12),
            _optionField('A', model.optionA, (v) => onChanged(model.copyWith(optionA: v))),
            const SizedBox(height: 8),
            _optionField('B', model.optionB, (v) => onChanged(model.copyWith(optionB: v))),
            const SizedBox(height: 8),
            _optionField('C', model.optionC, (v) => onChanged(model.copyWith(optionC: v))),
            const SizedBox(height: 8),
            _optionField('D', model.optionD, (v) => onChanged(model.copyWith(optionD: v))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: model.correct,
              decoration: const InputDecoration(
                labelText: 'Correct option',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'A', child: Text('A')),
                DropdownMenuItem(value: 'B', child: Text('B')),
                DropdownMenuItem(value: 'C', child: Text('C')),
                DropdownMenuItem(value: 'D', child: Text('D')),
              ],
              onChanged: (v) => onChanged(model.copyWith(correct: v ?? 'A')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionField(String label, String initial, ValueChanged<String> onChanged) {
    return TextFormField(
      initialValue: initial,
      decoration: InputDecoration(
        labelText: 'Option $label',
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    );
  }
}

class _QuizQuestionModel {
  final String? id;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correct;

  _QuizQuestionModel({
    this.id,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correct,
  });

  factory _QuizQuestionModel.empty() => _QuizQuestionModel(
        id: null,
        question: '',
        optionA: '',
        optionB: '',
        optionC: '',
        optionD: '',
        correct: 'A',
      );

  _QuizQuestionModel copyWith({
    String? question,
    String? optionA,
    String? optionB,
    String? optionC,
    String? optionD,
    String? correct,
  }) {
    return _QuizQuestionModel(
      id: id,
      question: question ?? this.question,
      optionA: optionA ?? this.optionA,
      optionB: optionB ?? this.optionB,
      optionC: optionC ?? this.optionC,
      optionD: optionD ?? this.optionD,
      correct: correct ?? this.correct,
    );
  }
}
