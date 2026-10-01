enum MuffinMode { learn, practice, quiz }

enum MuffinAction {
  askMuffin,
  explainSimply,
  translate,
  anotherExample,
  stillConfused,
  smallHint,
  explainConcept,
  generateSimilarQuestion,
  identifyPattern,
  guideQuestion,
}

enum MuffinResponseType {
  explanation,
  translation,
  example,
  hint,
  guidance,
  generatedQuestion,
  refusal,
  error,
}

class MuffinTurn {
  const MuffinTurn({
    required this.id,
    required this.type,
    required this.sourceText,
    required this.sourceLanguage,
    required this.displayLanguage,
    required this.translations,
    required this.contextKey,
    this.exampleIndex,
    this.generatedQuestion,
  });

  final String id;
  final MuffinResponseType type;
  final String sourceText;
  final String sourceLanguage;
  final String displayLanguage;
  final Map<String, String> translations;
  final String contextKey;
  final int? exampleIndex;
  final MuffinGeneratedQuestion? generatedQuestion;

  MuffinTurn copyWith({
    String? displayLanguage,
    Map<String, String>? translations,
  }) {
    return MuffinTurn(
      id: id,
      type: type,
      sourceText: sourceText,
      sourceLanguage: sourceLanguage,
      displayLanguage: displayLanguage ?? this.displayLanguage,
      translations: translations ?? this.translations,
      contextKey: contextKey,
      exampleIndex: exampleIndex,
      generatedQuestion: generatedQuestion,
    );
  }
}

class MuffinContext {
  const MuffinContext({
    this.studentProfileId,
    this.preferredLanguage,
    this.subjectId,
    this.subjectTitle,
    this.chapterId,
    this.chapterTitle,
    required this.mode,
    this.currentScreen,
    this.lessonHeading,
    this.lessonBody,
    this.questionId,
    this.cardId,
    this.displayedLanguage,
    this.currentQuestion,
    this.answerOptions,
    this.selectedStudentAnswer,
    this.relevantNotes,
    this.relevantFlashcards,
    this.practiceBestScore,
    this.quizBestScore,
    this.quizPassed,
    this.masteredFlashcardCount,
    this.targetLanguage,
    this.originalScreenContent,
    this.contextKey,
    this.currentMuffinContent,
    this.previousMuffinResponse,
    this.currentAction,
    this.previousExampleIds,
  });

  final String? studentProfileId;
  final String? preferredLanguage;
  final String? subjectId;
  final String? subjectTitle;
  final String? chapterId;
  final String? chapterTitle;
  final MuffinMode mode;
  final String? currentScreen;
  final String? lessonHeading;
  final String? lessonBody;
  final String? questionId;
  final String? cardId;
  final String? displayedLanguage;
  final String? currentQuestion;
  final List<String>? answerOptions;
  final String? selectedStudentAnswer;
  final List<String>? relevantNotes;
  final List<String>? relevantFlashcards;
  final int? practiceBestScore;
  final int? quizBestScore;
  final bool? quizPassed;
  final int? masteredFlashcardCount;
  final String? targetLanguage;
  final String? originalScreenContent;
  final String? contextKey;
  final String? currentMuffinContent;
  final String? previousMuffinResponse;
  final String? currentAction;
  final List<String>? previousExampleIds;

  MuffinContext copyWith({
    String? targetLanguage,
    String? selectedStudentAnswer,
    String? originalScreenContent,
    String? contextKey,
    String? currentMuffinContent,
    String? previousMuffinResponse,
    String? currentAction,
    List<String>? previousExampleIds,
  }) {
    return MuffinContext(
      studentProfileId: studentProfileId,
      preferredLanguage: preferredLanguage,
      subjectId: subjectId,
      subjectTitle: subjectTitle,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      mode: mode,
      currentScreen: currentScreen,
      lessonHeading: lessonHeading,
      lessonBody: lessonBody,
      questionId: questionId,
      cardId: cardId,
      displayedLanguage: displayedLanguage,
      currentQuestion: currentQuestion,
      answerOptions: answerOptions,
      selectedStudentAnswer:
          selectedStudentAnswer ?? this.selectedStudentAnswer,
      relevantNotes: relevantNotes,
      relevantFlashcards: relevantFlashcards,
      practiceBestScore: practiceBestScore,
      quizBestScore: quizBestScore,
      quizPassed: quizPassed,
      masteredFlashcardCount: masteredFlashcardCount,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      originalScreenContent:
          originalScreenContent ?? this.originalScreenContent,
      contextKey: contextKey ?? this.contextKey,
      currentMuffinContent: currentMuffinContent ?? this.currentMuffinContent,
      previousMuffinResponse:
          previousMuffinResponse ?? this.previousMuffinResponse,
      currentAction: currentAction ?? this.currentAction,
      previousExampleIds: previousExampleIds ?? this.previousExampleIds,
    );
  }

  Map<String, Object?> toJson() {
    return {
      if (studentProfileId != null) 'studentProfileId': studentProfileId,
      if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
      if (subjectId != null) 'subjectId': subjectId,
      if (subjectTitle != null) 'subjectTitle': subjectTitle,
      if (chapterId != null) 'chapterId': chapterId,
      if (chapterTitle != null) 'chapterTitle': chapterTitle,
      'mode': mode.name,
      if (currentScreen != null) 'currentScreen': currentScreen,
      if (lessonHeading != null) 'lessonHeading': _truncate(lessonHeading),
      if (lessonBody != null) 'lessonBody': _truncate(lessonBody, limit: 900),
      if (questionId != null) 'questionId': questionId,
      if (cardId != null) 'cardId': cardId,
      if (displayedLanguage != null) 'displayedLanguage': displayedLanguage,
      if (currentQuestion != null)
        'currentQuestion': _truncate(currentQuestion),
      if (answerOptions != null)
        'answerOptions': answerOptions!
            .map((option) => _truncate(option, limit: 240))
            .toList(),
      if (selectedStudentAnswer != null)
        'selectedStudentAnswer': _truncate(selectedStudentAnswer),
      if (relevantNotes != null)
        'relevantNotes':
            relevantNotes!.map((note) => _truncate(note, limit: 500)).toList(),
      if (relevantFlashcards != null)
        'relevantFlashcards': relevantFlashcards!
            .map((flashcard) => _truncate(flashcard, limit: 240))
            .toList(),
      if (practiceBestScore != null) 'practiceBestScore': practiceBestScore,
      if (quizBestScore != null) 'quizBestScore': quizBestScore,
      if (quizPassed != null) 'quizPassed': quizPassed,
      if (masteredFlashcardCount != null)
        'masteredFlashcardCount': masteredFlashcardCount,
      if (targetLanguage != null) 'targetLanguage': targetLanguage,
      if (originalScreenContent != null)
        'originalScreenContent': _truncate(originalScreenContent, limit: 900),
      if (contextKey != null) 'contextKey': contextKey,
      if (currentMuffinContent != null)
        'currentMuffinContent': _truncate(currentMuffinContent, limit: 900),
      if (previousMuffinResponse != null)
        'previousMuffinResponse': _truncate(previousMuffinResponse),
      if (currentAction != null) 'currentAction': currentAction,
      if (previousExampleIds != null) 'previousExampleIds': previousExampleIds,
    };
  }

  static String _truncate(String? value, {int limit = 700}) {
    final text = (value ?? '').trim();
    if (text.length <= limit) return text;
    return '${text.substring(0, limit).trimRight()}...';
  }
}

class MuffinRequest {
  const MuffinRequest({
    required this.mode,
    required this.action,
    required this.context,
    this.expectCached = false,
  });

  final MuffinMode mode;
  final MuffinAction action;
  final MuffinContext context;
  final bool expectCached;

  Map<String, Object?> toJson() {
    return {
      'mode': mode.name,
      'action': action.name,
      'context': context.toJson(),
      if (expectCached) 'expectCached': true,
    };
  }
}

class MuffinAvailabilityRequest {
  const MuffinAvailabilityRequest({
    required this.mode,
    required this.context,
    required this.actions,
  });

  final MuffinMode mode;
  final MuffinContext context;
  final List<MuffinAction> actions;

  Map<String, Object?> toJson() {
    return {
      'mode': mode.name,
      'context': context.toJson(),
      'actions': actions.map((action) => action.name).toList(growable: false),
    };
  }
}

class MuffinActionAvailability {
  const MuffinActionAvailability({
    required this.cached,
    required this.biteCost,
  });

  final bool cached;
  final int biteCost;

  factory MuffinActionAvailability.fromJson(Map<String, dynamic> data) {
    return MuffinActionAvailability(
      cached: data['cached'] == true,
      biteCost: (data['biteCost'] as num?)?.toInt() ?? 1,
    );
  }
}

class MuffinAvailabilityResponse {
  const MuffinAvailabilityResponse({required this.actions});

  final Map<MuffinAction, MuffinActionAvailability> actions;

  factory MuffinAvailabilityResponse.fromJson(Map<String, dynamic> data) {
    final rawActions = data['actions'];
    final parsed = <MuffinAction, MuffinActionAvailability>{};
    if (rawActions is Map<String, dynamic>) {
      for (final entry in rawActions.entries) {
        final action = _actionByName(entry.key);
        final value = entry.value;
        if (action != null && value is Map<String, dynamic>) {
          parsed[action] = MuffinActionAvailability.fromJson(value);
        }
      }
    }
    return MuffinAvailabilityResponse(actions: parsed);
  }
}

MuffinAction? _actionByName(String name) {
  for (final action in MuffinAction.values) {
    if (action.name == name) return action;
  }
  return null;
}

class MuffinGeneratedQuestion {
  const MuffinGeneratedQuestion({
    required this.question,
    required this.options,
    required this.difficulty,
    required this.topic,
    required this.generatedByMuffin,
    this.correctOptionIndex,
    this.explanation,
  });

  final String question;
  final List<String> options;
  final String difficulty;
  final String topic;
  final bool generatedByMuffin;
  final int? correctOptionIndex;
  final String? explanation;

  factory MuffinGeneratedQuestion.fromJson(Map<String, dynamic> data) {
    return MuffinGeneratedQuestion(
      question: (data['question'] ?? '').toString(),
      options: (data['options'] as List<dynamic>? ?? const [])
          .map((option) => option.toString())
          .toList(growable: false),
      difficulty: (data['difficulty'] ?? 'easy').toString(),
      topic: (data['topic'] ?? '').toString(),
      generatedByMuffin: data['generatedByMuffin'] == true,
      correctOptionIndex: (data['correctOptionIndex'] as num?)?.toInt(),
      explanation: data['explanation']?.toString(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'question': question,
      'options': options,
      'difficulty': difficulty,
      'topic': topic,
      'generatedByMuffin': generatedByMuffin,
      if (correctOptionIndex != null) 'correctOptionIndex': correctOptionIndex,
      if (explanation != null) 'explanation': explanation,
    };
  }
}

class MuffinResponse {
  const MuffinResponse({
    required this.responseType,
    required this.message,
    this.detectedLanguage,
    this.translatedText,
    this.generatedQuestion,
    this.suggestedNextAction,
    this.resultSource,
    this.biteCharged,
    this.currentBites,
  });

  final MuffinResponseType responseType;
  final String message;
  final String? detectedLanguage;
  final String? translatedText;
  final MuffinGeneratedQuestion? generatedQuestion;
  final String? suggestedNextAction;
  final String? resultSource;
  final int? biteCharged;
  final int? currentBites;

  factory MuffinResponse.fromJson(Map<String, dynamic> data) {
    final typeName = (data['responseType'] ?? 'error').toString();
    final generatedQuestion = data['generatedQuestion'];
    return MuffinResponse(
      responseType: MuffinResponseType.values.firstWhere(
        (type) => type.name == typeName,
        orElse: () => MuffinResponseType.error,
      ),
      message: (data['message'] ?? '').toString(),
      detectedLanguage: data['detectedLanguage']?.toString(),
      translatedText: data['translatedText']?.toString(),
      generatedQuestion: generatedQuestion is Map<String, dynamic>
          ? MuffinGeneratedQuestion.fromJson(generatedQuestion)
          : null,
      suggestedNextAction: data['suggestedNextAction']?.toString(),
      resultSource: data['resultSource']?.toString(),
      biteCharged: (data['biteCharged'] as num?)?.toInt(),
      currentBites: (data['currentBites'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'success': responseType != MuffinResponseType.error,
      'responseType': responseType.name,
      'message': message,
      if (detectedLanguage != null) 'detectedLanguage': detectedLanguage,
      if (translatedText != null) 'translatedText': translatedText,
      if (generatedQuestion != null)
        'generatedQuestion': generatedQuestion!.toJson(),
      if (suggestedNextAction != null)
        'suggestedNextAction': suggestedNextAction,
      if (resultSource != null) 'resultSource': resultSource,
      if (biteCharged != null) 'biteCharged': biteCharged,
      if (currentBites != null) 'currentBites': currentBites,
    };
  }
}
