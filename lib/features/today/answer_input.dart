import 'package:flutter/widgets.dart' show StringCharacters;

int answerInputLimit(String snapshot) =>
    snapshot.characters.length > 200 ? snapshot.characters.length : 200;

bool acceptsAnswerInput(String answer, int limit) =>
    answer.characters.length <= limit;
