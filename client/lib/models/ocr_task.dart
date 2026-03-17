class OcrTask {
  final String taskId;
  final String status;
  final String? progressMsg;
  final String? error;
  final int questionCount;
  final String? resultFolderId;

  OcrTask({
    required this.taskId,
    required this.status,
    this.progressMsg,
    this.error,
    this.questionCount = 0,
    this.resultFolderId,
  });

  factory OcrTask.fromJson(Map<String, dynamic> json) {
    return OcrTask(
      taskId: json['task_id'],
      status: json['status'],
      progressMsg: json['progress_msg'],
      error: json['error'],
      questionCount: json['question_count'] ?? 0,
      resultFolderId: json['result_folder_id'],
    );
  }

  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing' || status == 'pending';
}

class QuestionResult {
  final int index;
  final String markdown;
  final String? cropFileId;
  final String? mdFileId;
  final String? pdfFileId;

  QuestionResult({
    required this.index,
    required this.markdown,
    this.cropFileId,
    this.mdFileId,
    this.pdfFileId,
  });

  factory QuestionResult.fromJson(Map<String, dynamic> json) {
    return QuestionResult(
      index: json['index'],
      markdown: json['markdown'] ?? '',
      cropFileId: json['crop_file_id'],
      mdFileId: json['md_file_id'],
      pdfFileId: json['pdf_file_id'],
    );
  }
}

class OcrResult {
  final String taskId;
  final String status;
  final String? originalFileId;
  final String? resultFolderId;
  final List<QuestionResult> questions;

  OcrResult({
    required this.taskId,
    required this.status,
    this.originalFileId,
    this.resultFolderId,
    this.questions = const [],
  });

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    return OcrResult(
      taskId: json['task_id'],
      status: json['status'],
      originalFileId: json['original_file_id'],
      resultFolderId: json['result_folder_id'],
      questions: (json['questions'] as List?)
              ?.map((q) => QuestionResult.fromJson(q))
              .toList() ??
          [],
    );
  }
}
