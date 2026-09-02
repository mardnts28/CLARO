import 'package:flutter_test/flutter_test.dart';
import 'package:claro/models/product_model.dart';
import 'package:claro/services/voice_assistant_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Voice Compare Navigation Tests', () {
    test('latestScanProductNotifier stores active product for comparison', () {
      final sampleProduct = Product(
        id: 'test-can-001',
        name: 'Century Tuna Flakes in Oil',
        brand: 'Century',
        category: 'canned_goods',
        variant: '155g',
        fdaStatus: 'Registered',
        ingredients: ['Tuna', 'Water', 'Vegetable Oil', 'Salt'],
        allergens: ['Fish'],
        nutritionalFacts: NutritionalFacts(
          servingSize: '50g',
          caloriesKcal: 120,
          proteinG: 15,
          totalFatG: 5,
          saturatedFatG: 2.5,
          transFatG: 0,
          cholesterolMg: 20,
          sodiumMg: 350,
          carbsG: 0,
          fiberG: 0,
          sugarsG: 0,
        ),
      );

      VoiceAssistantService.setLatestScanProduct(sampleProduct);
      expect(VoiceAssistantService.latestScanProductNotifier.value, equals(sampleProduct));
      expect(VoiceAssistantService.latestScanProductNotifier.value?.name, equals('Century Tuna Flakes in Oil'));
    });

    test('Voice product search patterns correctly match English and Tagalog commands', () {
      final patterns = [
        RegExp(r'^(?:please\s+)?(?:find|search(?:\s+for)?|look\s+for|show|open)\s+(?:me\s+)?(.+?)(?:\s+(?:in|from)\s+(?:my\s+)?history|\s+from\s+last\s+week|\s+from\s+yesterday|\s+product|\s+details)?$', caseSensitive: false),
        RegExp(r'^(?:paki-?)?(?:hanapin|hanap|pahanap|buksan|tingnan|ipakita)\s+(?:po\s+)?(?:ang|yung|ng)?\s*(.+?)(?:\s+sa\s+(?:aking\s+)?history|\s+sa\s+mga\s+na-?scan)?$', caseSensitive: false),
      ];

      bool matchesAny(String input) => patterns.any((p) => p.hasMatch(input.trim()));

      expect(matchesAny('find blue bay tuna from last week'), isTrue);
      expect(matchesAny('search for century tuna in my history'), isTrue);
      expect(matchesAny('look for lucky 7 carne norte'), isTrue);
      expect(matchesAny('open star carne norte'), isTrue);
      expect(matchesAny('hanapin ang blue bay tuna sa history'), isTrue);
      expect(matchesAny('buksan ang 555 sardines'), isTrue);
      expect(matchesAny('pahanap ng century tuna'), isTrue);
    });

    test('Voice navigation patterns resolve profile, preferences, theme/darkmode, suggestions, and sub-tabs', () {
      String? targetFromTranscript(String transcript) {
        final normalized = transcript.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');

        // 1. Comparison Screen
        if (RegExp(r'\b(compare products|compare product|product comparison|ihambing|paghambingin|pagkumparahin|ikumpera|ikumpra)\b')
            .hasMatch(normalized)) {
          return 'compare_products';
        }

        // 2. Sub-tabs in History
        if (RegExp(r'\b(favorite|favorites|paborito|mga paborito|my favorites|paboritong produkto|saved products|saved product|saved items|saved)\b')
            .hasMatch(normalized)) {
          return 'history_favorites';
        }
        if (RegExp(r'\b(compare history|comparison history|comparison records|compared|history compare|kumpara|kasaysayan ng paghahambing|past comparisons)\b')
            .hasMatch(normalized)) {
          return 'history_compare';
        }
        if (RegExp(r'\b(reports|my reports|submitted reports|mga ulat|ulat|report history|view reports|show reports)\b')
            .hasMatch(normalized)) {
          return 'history_reports';
        }

        // 3. Main Tabs
        if (RegExp(r'\b(home|main|dashboard|simula|home page|home screen)\b').hasMatch(normalized)) {
          return 'home';
        }
        if (RegExp(r'\b(scan|scanner|camera|mag-scan|magscan|camera screen|scan screen)\b').hasMatch(normalized)) {
          return 'scan';
        }
        if (RegExp(r'\b(history|records|previous scans|mga na-scan|kasaysayan|scan history)\b').hasMatch(normalized)) {
          return 'history';
        }
        if (RegExp(r'\b(profile|my profile|account|my account|profile page|profile screen)\b').hasMatch(normalized)) {
          return 'profile';
        }

        // 4. Settings & Feature Screens
        if (RegExp(r'\b(personal information|personal info|my info|my information|account information|personal na impormasyon|personal details|profile details|personal)\b')
            .hasMatch(normalized)) {
          return 'personal_info';
        }
        // Voice Assistant ON / OFF
        if (RegExp(r'\b(voice assistant off|voice off|turn off voice assistant|turn off voice|disable voice assistant|disable voice|i\s*off ang voice assistant|patayin ang boses|patayin ang voice assistant)\b')
            .hasMatch(normalized)) {
          return 'voice_assistant_off';
        }
        if (RegExp(r'\b(voice assistant on|voice on|turn on voice assistant|turn on voice|enable voice assistant|enable voice|i\s*on ang voice assistant|buhayin ang boses|buhayin ang voice assistant)\b')
            .hasMatch(normalized)) {
          return 'voice_assistant_on';
        }

        // MFA ON / OFF
        if (RegExp(r'\b(turn off (?:mfa|multi factor|two factor|2fa)|disable (?:mfa|multi factor|two factor|2fa)|deactivate (?:mfa|multi factor|two factor|2fa)|switch off (?:mfa|2fa)|mfa off|2fa off|i\s*off ang (?:mfa|multi factor|two factor|2fa)|patayin ang (?:mfa|multi factor|two factor|2fa)|isara ang (?:mfa|multi factor|two factor|2fa)|i\s*disable ang (?:mfa|2fa)|i\s*deactivate ang (?:mfa|2fa))\b')
            .hasMatch(normalized)) {
          return 'mfa_off';
        }
        if (RegExp(r'\b(turn on (?:mfa|multi factor|two factor|2fa)|enable (?:mfa|multi factor|two factor|2fa)|activate (?:mfa|multi factor|two factor|2fa)|switch on (?:mfa|2fa)|mfa on|2fa on|i\s*on ang (?:mfa|multi factor|two factor|2fa)|buhayin ang (?:mfa|multi factor|two factor|2fa)|buksan ang (?:mfa|multi factor|two factor|2fa)|i\s*enable ang (?:mfa|2fa)|i\s*activate ang (?:mfa|2fa))\b')
            .hasMatch(normalized)) {
          return 'mfa_on';
        }
        if (RegExp(r'\b(multi factor authentication|two factor authentication|multi factor|two factor|mfa|2fa|dalawang yugtong pagpapatunay|mfa settings|2fa settings)\b')
            .hasMatch(normalized)) {
          return 'mfa';
        }

        // Theme: Turn OFF Dark Mode -> Light Mode
        if (RegExp(r'\b(dark mode off|darkmode off|turn off dark mode|turn off darkmode|disable dark mode|disable darkmode|i\s*off ang dark mode|patayin ang dark mode)\b')
            .hasMatch(normalized)) {
          return 'light_mode';
        }

        // Theme: Turn OFF Light Mode -> Dark Mode
        if (RegExp(r'\b(light mode off|lightmode off|turn off light mode|turn off lightmode|disable light mode|disable lightmode|i\s*off ang light mode|patayin ang light mode)\b')
            .hasMatch(normalized)) {
          return 'dark_mode';
        }

        // Theme: Turn ON Dark Mode -> Dark Mode
        if (RegExp(r'\b(turn on dark mode|turn on darkmode|enable dark mode|enable darkmode|switch to dark mode|dark mode on|darkmode on|diliman ang tema|dark theme|i\s*dark mode|madilim na tema|diliman|darkmode|dark mode)\b')
            .hasMatch(normalized)) {
          return 'dark_mode';
        }

        // Theme: Turn ON Light Mode -> Light Mode
        if (RegExp(r'\b(turn on light mode|turn on lightmode|enable light mode|enable lightmode|switch to light mode|light mode on|lightmode on|liwanagan ang tema|light theme|default theme|i\s*light mode|maliwanag na tema|liwanagan|lightmode|light mode)\b')
            .hasMatch(normalized)) {
          return 'light_mode';
        }

        // Language switching
        if (RegExp(r'\b((?:change|switch|set) (?:language|voice) to (?:tagalog|filipino)|magtagalog|tagalog voice|wika tagalog|palitan sa tagalog|gawing tagalog)\b')
            .hasMatch(normalized)) {
          return 'language_tagalog';
        }
        if (RegExp(r'\b((?:change|switch|set) (?:language|voice) to english|mag\s*english|english voice|wika ingles|palitan sa english|gawing english)\b')
            .hasMatch(normalized)) {
          return 'language_english';
        }
        if (RegExp(r'\b(language change|change language|switch language|language settings|language setting|wika|palitan ang wika|magpalit ng wika)\b')
            .hasMatch(normalized)) {
          return 'language';
        }
        if (RegExp(r'\b(theme screen|theme settings|theme setting|open theme|mga setting ng tema|mga tema|tema|appearance)\b')
            .hasMatch(normalized)) {
          return 'theme';
        }
        if (RegExp(r'\b(preference|preferences|health preference|health preferences|dietary preferences|kagustuhan|mga kagustuhan|health conditions|medical conditions)\b')
            .hasMatch(normalized)) {
          return 'preference';
        }
        if (RegExp(r'\b(suggestion|suggestions|feedback|feedbacks|mungkahi|komento|comment|comments|suggest)\b')
            .hasMatch(normalized)) {
          return 'suggestion';
        }
        if (RegExp(r'\b(app reviews|app review|review history|reviews|mga review|kasaysayan ng review|pagsusuri ng app)\b')
            .hasMatch(normalized)) {
          return 'review_history';
        }
        if (RegExp(r'\b(change password|reset password|palitan ang password|baguhin ang password|update password|password|security settings)\b')
            .hasMatch(normalized)) {
          return 'change_password';
        }
        if (RegExp(r'\b(about claro|tungkol sa claro|about app|about the app|about us)\b')
            .hasMatch(normalized)) {
          return 'about_claro';
        }
        if (RegExp(r'\b(privacy policy|privacy|patakaran sa privacy|data privacy|patakaran sa data)\b')
            .hasMatch(normalized)) {
          return 'privacy_policy';
        }
        if (RegExp(r'\b(terms and conditions|terms and condition|terms of service|terms of use|terms|mga tuntunin at kundisyon|mga tuntunin|kundisyon)\b')
            .hasMatch(normalized)) {
          return 'terms_conditions';
        }
        if (RegExp(r'\b(user guide|app guide|manual|gabay sa paggamit|gabay ng gumagamit|gabay|how to use|nutrition guide)\b')
            .hasMatch(normalized)) {
          return 'user_guide';
        }
        if (RegExp(r'\b(log out|logout|sign out|signout|mag log out|maglog out|mag sign out|magsign out|lumabas sa account|i\s*log out)\b')
            .hasMatch(normalized)) {
          return 'logout';
        }

        return null;
      }

      expect(targetFromTranscript('home'), equals('home'));
      expect(targetFromTranscript('dashboard'), equals('home'));
      expect(targetFromTranscript('scan'), equals('scan'));
      expect(targetFromTranscript('camera'), equals('scan'));
      expect(targetFromTranscript('favorites'), equals('history_favorites'));
      expect(targetFromTranscript('my favorites'), equals('history_favorites'));
      expect(targetFromTranscript('paborito'), equals('history_favorites'));
      expect(targetFromTranscript('compare history'), equals('history_compare'));
      expect(targetFromTranscript('reports'), equals('history_reports'));
      expect(targetFromTranscript('mga ulat'), equals('history_reports'));
      expect(targetFromTranscript('darkmode'), equals('dark_mode'));
      expect(targetFromTranscript('dark mode off'), equals('light_mode'));
      expect(targetFromTranscript('turn off dark mode'), equals('light_mode'));
      expect(targetFromTranscript('light mode off'), equals('dark_mode'));
      expect(targetFromTranscript('turn off light mode'), equals('dark_mode'));
      expect(targetFromTranscript('open dark mode'), equals('dark_mode'));
      expect(targetFromTranscript('theme settings'), equals('theme'));
      expect(targetFromTranscript('go to preferences'), equals('preference'));
      expect(targetFromTranscript('health preferences'), equals('preference'));
      expect(targetFromTranscript('my profile'), equals('profile'));
      expect(targetFromTranscript('personal information'), equals('personal_info'));
      expect(targetFromTranscript('suggestions'), equals('suggestion'));
      expect(targetFromTranscript('change password'), equals('change_password'));
      expect(targetFromTranscript('mga paborito'), equals('history_favorites'));
      expect(targetFromTranscript('kasaysayan ng paghahambing'), equals('history_compare'));
      expect(targetFromTranscript('aking mga ulat'), equals('history_reports'));
      expect(targetFromTranscript('diliman ang tema'), equals('dark_mode'));
      expect(targetFromTranscript('liwanagan ang tema'), equals('light_mode'));
      expect(targetFromTranscript('personal na impormasyon'), equals('personal_info'));
      expect(targetFromTranscript('mga kagustuhan'), equals('preference'));
      expect(targetFromTranscript('mungkahi at puna'), equals('suggestion'));
      expect(targetFromTranscript('palitan ang password'), equals('change_password'));
      expect(targetFromTranscript('tungkol sa claro'), equals('about_claro'));
      expect(targetFromTranscript('multi factor authentication'), equals('mfa'));
      expect(targetFromTranscript('two factor authentication'), equals('mfa'));
      expect(targetFromTranscript('turn on mfa'), equals('mfa_on'));
      expect(targetFromTranscript('enable two factor authentication'), equals('mfa_on'));
      expect(targetFromTranscript('i-on ang mfa'), equals('mfa_on'));
      expect(targetFromTranscript('mfa on'), equals('mfa_on'));
      expect(targetFromTranscript('turn off mfa'), equals('mfa_off'));
      expect(targetFromTranscript('disable 2fa'), equals('mfa_off'));
      expect(targetFromTranscript('i-off ang multi factor authentication'), equals('mfa_off'));
      expect(targetFromTranscript('mfa off'), equals('mfa_off'));
      expect(targetFromTranscript('turn off voice assistant'), equals('voice_assistant_off'));
      expect(targetFromTranscript('voice assistant off'), equals('voice_assistant_off'));
      expect(targetFromTranscript('turn on voice assistant'), equals('voice_assistant_on'));
      expect(targetFromTranscript('voice assistant on'), equals('voice_assistant_on'));
      expect(targetFromTranscript('change language to tagalog'), equals('language_tagalog'));
      expect(targetFromTranscript('change language to english'), equals('language_english'));
      expect(targetFromTranscript('language settings'), equals('language'));
      expect(targetFromTranscript('app reviews'), equals('review_history'));
      expect(targetFromTranscript('privacy policy'), equals('privacy_policy'));
      expect(targetFromTranscript('terms and conditions'), equals('terms_conditions'));
      expect(targetFromTranscript('user guide'), equals('user_guide'));
      expect(targetFromTranscript('log out'), equals('logout'));
      expect(targetFromTranscript('sign out'), equals('logout'));
      expect(targetFromTranscript('mag log out'), equals('logout'));
      expect(targetFromTranscript('mag sign out'), equals('logout'));
      expect(targetFromTranscript('turn off voice assistant'), equals('voice_assistant_off'));
      expect(targetFromTranscript('voice assistant off'), equals('voice_assistant_off'));
      expect(targetFromTranscript('turn on voice assistant'), equals('voice_assistant_on'));
      expect(targetFromTranscript('voice assistant on'), equals('voice_assistant_on'));
      expect(targetFromTranscript('change language to tagalog'), equals('language_tagalog'));
      expect(targetFromTranscript('change language to english'), equals('language_english'));
      expect(targetFromTranscript('language settings'), equals('language'));
      expect(targetFromTranscript('app reviews'), equals('review_history'));
      expect(targetFromTranscript('privacy policy'), equals('privacy_policy'));
      expect(targetFromTranscript('terms and conditions'), equals('terms_conditions'));
      expect(targetFromTranscript('user guide'), equals('user_guide'));
    });

    test('Voice navigation patterns resolve in-screen actions on result screen', () {
      String? targetFromTranscript(String transcript) {
        final normalized = transcript.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');

        // 1. In-screen action: Unlike / Unfavorite active product
        if (RegExp(r'\b(unfavorite this|unfavorite this product|unfavorite it|remove from favorites|unlike this product|unlike this|remove favorite|alisin sa paborito|tanggalin sa paborito|i\s*unfavorite ito|i\s*unfavorite)\b')
            .hasMatch(normalized)) {
          return 'unfavorite_product';
        }

        // In-screen action: Like / Favorite active product
        if (RegExp(r'\b(favorite this|favorite this product|favorite it|add to favorites|save to favorites|like this product|like this|i\s*favorite|i\s*paborito|paborito ito|gusto ko ito|i\s*save ito|isave ito|idagdag sa paborito|isama sa paborito)\b')
            .hasMatch(normalized)) {
          return 'favorite_product';
        }

        // 2. In-screen action: Report product
        if (RegExp(r'\b(report this product|report product|report issue|report error|i\s*report ito|ireport ito|i\s*report|ireport|i\s*ulat ito|iulat ito|i\s*ulat|iulat|mali ang impormasyon|maling produkto)\b')
            .hasMatch(normalized)) {
          return 'report_product';
        }

        // In-screen action: More Details
        if (RegExp(r'\b(more details|for more details|show more details|open more details|see more details|view more details|product details|ingredients|storage instructions|storage|karagdagang detalye|karagdagang impormasyon|mga sangkap|sangkap|paraan ng pag\s*imbak|imbak|detalye ng produkto|detalye)\b')
            .hasMatch(normalized)) {
          return 'more_details';
        }

        // 3. Comparison Screen for active product
        if (RegExp(r'\b(compare this product|compare this|compare product|compare scanned product|compare with alternatives|compare with others|ihambing ang produktong ito|paghambingin ito|pagkumparahin ito|ikumpera ito|ikumpra ito|ihambing ito)\b')
            .hasMatch(normalized)) {
          return 'compare_products';
        }

        if (RegExp(r'\b(compare history|comparison history|comparison records|history compare|kasaysayan ng paghahambing|mga pinaghambing|mga kinumpara|past comparisons)\b')
            .hasMatch(normalized)) {
          return 'history_compare';
        }

        if (RegExp(r'\b(compare|comparison|comparisons|compared|kumpara|ihambing|paghambingin|ikumpra|ikumpera)\b')
            .hasMatch(normalized)) {
          if (VoiceAssistantService.activeResultProductNotifier.value != null) {
            return 'compare_products';
          }
          return 'history_compare';
        }

        return null;
      }

      // Test when NOT on result screen (activeResultProductNotifier is null)
      VoiceAssistantService.activeResultProductNotifier.value = null;
      expect(targetFromTranscript('compare'), equals('history_compare'));
      expect(targetFromTranscript('comparison'), equals('history_compare'));
      expect(targetFromTranscript('kumpara'), equals('history_compare'));
      expect(targetFromTranscript('compare history'), equals('history_compare'));

      // Test when ON result screen (activeResultProductNotifier is set)
      final sampleProduct = Product(
        id: 'test-can-001',
        name: 'Century Tuna Flakes in Oil',
        brand: 'Century',
        category: 'canned_goods',
        variant: '155g',
        fdaStatus: 'Registered',
        ingredients: ['Tuna', 'Water', 'Vegetable Oil', 'Salt'],
        allergens: ['Fish'],
        nutritionalFacts: NutritionalFacts(
          servingSize: '50g',
          caloriesKcal: 120,
          proteinG: 15,
          totalFatG: 5,
          saturatedFatG: 2.5,
          transFatG: 0,
          cholesterolMg: 20,
          sodiumMg: 350,
          carbsG: 0,
          fiberG: 0,
          sugarsG: 0,
        ),
      );
      VoiceAssistantService.activeResultProductNotifier.value = sampleProduct;

      expect(targetFromTranscript('compare'), equals('compare_products'));
      expect(targetFromTranscript('comparison'), equals('compare_products'));
      expect(targetFromTranscript('kumpara'), equals('compare_products'));
      expect(targetFromTranscript('compare this product'), equals('compare_products'));
      expect(targetFromTranscript('compare this'), equals('compare_products'));
      expect(targetFromTranscript('ihambing ang produktong ito'), equals('compare_products'));

      expect(targetFromTranscript('more details'), equals('more_details'));
      expect(targetFromTranscript('for more details'), equals('more_details'));
      expect(targetFromTranscript('show more details'), equals('more_details'));
      expect(targetFromTranscript('karagdagang detalye'), equals('more_details'));
      expect(targetFromTranscript('mga sangkap'), equals('more_details'));

      expect(targetFromTranscript('favorite this product'), equals('favorite_product'));
      expect(targetFromTranscript('add to favorites'), equals('favorite_product'));
      expect(targetFromTranscript('like this product'), equals('favorite_product'));
      expect(targetFromTranscript('i-favorite ito'), equals('favorite_product'));
      expect(targetFromTranscript('idagdag sa paborito'), equals('favorite_product'));
      expect(targetFromTranscript('unfavorite this product'), equals('unfavorite_product'));
      expect(targetFromTranscript('remove from favorites'), equals('unfavorite_product'));
      expect(targetFromTranscript('alisin sa paborito'), equals('unfavorite_product'));
      expect(targetFromTranscript('report this product'), equals('report_product'));
      expect(targetFromTranscript('report issue'), equals('report_product'));
      expect(targetFromTranscript('i-ulat ito'), equals('report_product'));
      expect(targetFromTranscript('ireport ito'), equals('report_product'));

      // Reset
      VoiceAssistantService.activeResultProductNotifier.value = null;
    });

    test('isSummaryRequest correctly recognizes display results, advisory, and comparison commands in EN and FIL', () {
      bool isSummaryRequest(String transcript) {
        final normalized = transcript.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();
        if (RegExp(r'\b(summarize|summarise|summary|summaries|ibuod|buod|ipaliwanag|paliwanag|recap|overview)\b').hasMatch(normalized)) {
          return true;
        }
        if (RegExp(r'\b(display results|show results|read results|tell results|what are the results|comparison results|compare results|display comparison|scan results|scan result|product results|nutrition results|resulta|mga resulta|advisory|health advisory|health advisories|summarize advisory|summary advisory|payo sa kalusugan|payo|anong payo|buod ng resulta)\b').hasMatch(normalized)) {
          return true;
        }
        if (RegExp(r'^(?:the\s+)?(?:results|result|summary|resulta|advisory|health advisory|payo|buod)$').hasMatch(normalized)) {
          return true;
        }
        return RegExp(
          r'\b(summarize|summarise|summary|explain|describe|display|show|read|tell|what are the|anong|sabihin|ipakita|ipaliwanag|buod)\b.*\b(result|results|scan|report|product|nutrition|comparison|ranking|score|scores|resulta|advisory|health advisory|payo|rekomendasyon|kalusugan)\b',
        ).hasMatch(normalized);
      }

      expect(isSummaryRequest('summarize'), isTrue);
      expect(isSummaryRequest('summarize this'), isTrue);
      expect(isSummaryRequest('can you summarize'), isTrue);
      expect(isSummaryRequest('buod'), isTrue);
      expect(isSummaryRequest('ibuod ito'), isTrue);
      expect(isSummaryRequest('ipaliwanag'), isTrue);
      expect(isSummaryRequest('display results'), isTrue);
      expect(isSummaryRequest('show results'), isTrue);
      expect(isSummaryRequest('read results'), isTrue);
      expect(isSummaryRequest('summarize advisory'), isTrue);
      expect(isSummaryRequest('health advisory'), isTrue);
      expect(isSummaryRequest('payo sa kalusugan'), isTrue);
      expect(isSummaryRequest('anong payo'), isTrue);
      expect(isSummaryRequest('buod ng resulta'), isTrue);
      expect(isSummaryRequest('ipaliwanag ang resulta'), isTrue);
      expect(isSummaryRequest('comparison results'), isTrue);
      expect(isSummaryRequest('compare results'), isTrue);
      expect(isSummaryRequest('display comparison'), isTrue);
      expect(isSummaryRequest('what are the results'), isTrue);
      expect(isSummaryRequest('summarize the scan'), isTrue);
      expect(isSummaryRequest('ipakita ang resulta'), isTrue);
      expect(isSummaryRequest('sabihin ang resulta'), isTrue);
    });
  });
}
