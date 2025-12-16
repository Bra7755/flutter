import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class ProfessorHomePage extends StatefulWidget {
  final String professorName;
  final String subject;
  final List<String> classesTaught;

  const ProfessorHomePage({
    super.key,
    required this.professorName,
    required this.subject,
    required this.classesTaught,
  });

  @override
  State<ProfessorHomePage> createState() => _ProfessorHomePageState();
}

class _ProfessorHomePageState extends State<ProfessorHomePage> {
  // List of uploaded files (store their file paths)
  List<PlatformFile> uploadedFiles = [];

  // Pick a file from PC
  Future<void> _pickFile(List<String> allowedExtensions) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );

    if (result != null) {
      setState(() {
        uploadedFiles.addAll(result.files);
      });
    }
  }

  void _uploadVideo() => _pickFile(['mp4', 'mov', 'avi']);
  void _uploadPDF() => _pickFile(['pdf']);
  void _uploadImage() => _pickFile(['jpg', 'png', 'jpeg']);

  void _openMessagingPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MessagingPage(),
      ),
    );
  }

  // Get the last 3 uploaded files for "What's New"
  List<PlatformFile> get whatsNew {
    if (uploadedFiles.isEmpty) return [];
    return uploadedFiles.reversed.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Professor Home')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Professor Info
              Center(
                child: Column(
                  children: [
                    Text(
                      'Welcome, ${widget.professorName}!',
                      style: const TextStyle(fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Subject: ${widget.subject}',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Classes Taught:',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...widget.classesTaught
                        .map((c) => Text(c, style: const TextStyle(fontSize: 18))),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Upload Buttons
              const Text('Upload Content:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _uploadVideo,
                    child: const Text('Add Video'),
                  ),
                  ElevatedButton(
                    onPressed: _uploadPDF,
                    child: const Text('Add PDF'),
                  ),
                  ElevatedButton(
                    onPressed: _uploadImage,
                    child: const Text('Add Image'),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // What's New Section
              const Text("What's New:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              whatsNew.isEmpty
                  ? const Text('No recent uploads.')
                  : Column(
                children: whatsNew
                    .map((file) => ListTile(
                  leading: const Icon(Icons.new_releases),
                  title: Text(file.name),
                  subtitle: Text(file.path ?? ''),
                ))
                    .toList(),
              ),

              const SizedBox(height: 30),

              // Uploaded Files Section
              const Text('Uploaded Files:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              uploadedFiles.isEmpty
                  ? const Text('No files uploaded yet.')
                  : Column(
                children: uploadedFiles
                    .map((file) => ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(file.name),
                  subtitle: Text(file.path ?? ''),
                ))
                    .toList(),
              ),

              const SizedBox(height: 30),

              // Messaging button
              Center(
                child: ElevatedButton(
                  onPressed: _openMessagingPage,
                  child: const Text('Message Students'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder Messaging Page
class MessagingPage extends StatelessWidget {
  const MessagingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messaging')),
      body: const Center(
        child: Text('Messaging feature coming soon!'),
      ),
    );
  }
}
