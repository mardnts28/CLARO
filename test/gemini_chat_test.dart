import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:claro/services/gemini_service.dart';

void main() {
  group('Gemini scoped product chat', () {
    tearDown(() {
      GeminiService.chatRequestOverride = null;
    });

    http.Response responseFor({
      required bool inScope,
      required String topic,
      required String answer,
    }) => http.Response(
      jsonEncode({
        'candidates': [
          {
            'finishReason': 'STOP',
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'in_scope': inScope,
                    'topic': topic,
                    'answer': answer,
                  }),
                },
              ],
            },
          },
        ],
      }),
      200,
    );

    Future<ChatReply> ask(String question) => GeminiService.instance.askChat(
      question: question,
      appLanguage: 'en',
      productData: '{"name":"Sample product","allergens":["Soy"]}',
      history: const [],
    );

    test('refuses arithmetic locally without calling Gemini', () async {
      var calls = 0;
      GeminiService.chatRequestOverride = (_, _, _) async {
        calls++;
        return responseFor(inScope: true, topic: 'product', answer: '2');
      };

      final reply = await ask('1+1');

      expect(calls, 0);
      expect(reply.inScope, isFalse);
      expect(reply.answer, contains('I can only help with this product'));
    });

    test(
      'refuses obvious general knowledge locally without calling Gemini',
      () async {
        var calls = 0;
        GeminiService.chatRequestOverride = (_, _, _) async {
          calls++;
          return responseFor(inScope: true, topic: 'app', answer: 'Unexpected');
        };

        final reply = await ask("What's the capital of France?");

        expect(calls, 0);
        expect(reply.answer, contains('Try asking about its ingredients'));
      },
    );

    test(
      'routes product questions to Gemini with product data and recent history',
      () async {
        var calls = 0;
        Map<String, dynamic>? request;
        GeminiService.chatRequestOverride = (_, _, body) async {
          calls++;
          request = jsonDecode(body) as Map<String, dynamic>;
          return responseFor(
            inScope: true,
            topic: 'product',
            answer: 'This product lists soy as an allergen.',
          );
        };

        final history = List.generate(
          8,
          (index) => ChatTurn(
            role: index.isEven ? 'user' : 'model',
            text: 'turn $index',
          ),
        );
        final reply = await GeminiService.instance.askChat(
          question: 'Any allergens?',
          appLanguage: 'en',
          productData: '{"name":"Sample product"}',
          history: history,
        );

        expect(calls, 1);
        expect(reply.inScope, isTrue);
        expect(reply.answer, 'This product lists soy as an allergen.');
        final contents = request!['contents'] as List;
        expect(contents, hasLength(7));
        final last = contents.last as Map<String, dynamic>;
        final userText =
            ((last['parts'] as List).single as Map<String, dynamic>)['text']
                as String;
        expect(userText, contains('PRODUCT DATA\n{"name":"Sample product"}'));
        expect(userText, endsWith('Question: "Any allergens?"'));
        expect(((contents.first as Map)['parts'] as List).single, {
          'text': 'turn 2',
        });
        expect(((contents[5] as Map)['parts'] as List).single, {
          'text': 'turn 7',
        });
      },
    );

    test(
      'uses the fixed local refusal when the model reports off topic',
      () async {
        GeminiService.chatRequestOverride = (_, _, _) async => responseFor(
          inScope: false,
          topic: 'off_topic',
          answer: 'Model-generated refusal text should not be shown.',
        );

        final reply = await ask('Tell me a joke');

        expect(reply.answer, contains('I can only help with this product'));
        expect(reply.answer, isNot(contains('Model-generated')));
      },
    );

    test('returns a local fallback when Gemini fails', () async {
      GeminiService.chatRequestOverride = (_, _, _) async =>
          throw Exception('simulated network error');

      final reply = await ask('Does this have soy?');

      expect(reply.inScope, isFalse);
      expect(reply.answer, "Sorry, I couldn't answer that. Please try again.");
    });
  });
}
