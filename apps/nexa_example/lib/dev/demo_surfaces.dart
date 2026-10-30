// DEVELOPMENT ONLY: demo Dynamic UI surfaces, one per category plus the
// non-ready states. Every surface carries `demo: true`, so the renderer
// labels it DEMO; none of this data is real.

/// One demo surface per [NexaSurfaceCategory] (wire JSON, schema 1.0).
List<Map<String, Object?>> demoSurfaces({required bool arabic}) {
  String t(String en, String ar) => arabic ? ar : en;
  Map<String, Object?> surface(
    String id,
    String category,
    String title,
    List<Map<String, Object?>> components, {
    List<Map<String, Object?>> actions = const [],
    String presentation = 'inline_card',
  }) => {
    'schema_version': '1.0',
    'surface_id': 'demo_$id',
    'category': category,
    'presentation': presentation,
    'title': title,
    'fallback_text': title,
    'demo': true,
    'status': {'state': 'ready'},
    'components': components,
    'actions': actions,
  };

  return [
    surface(
      'choices',
      'choices_forms',
      t('Plan your trip', 'خطط لرحلتك'),
      [
        {
          'type': 'single_choice',
          'id': 'c_when',
          'a11y_label': t('When', 'متى'),
          'choices': [
            {'id': 'today', 'label': t('Today', 'اليوم')},
            {'id': 'weekend', 'label': t('This weekend', 'نهاية الأسبوع')},
          ],
        },
        {
          'type': 'multi_choice',
          'id': 'c_with',
          'a11y_label': t('Interests', 'الاهتمامات'),
          'choices': [
            {'id': 'food', 'label': t('Food', 'طعام')},
            {'id': 'museums', 'label': t('Museums', 'متاحف')},
            {'id': 'parks', 'label': t('Parks', 'حدائق')},
          ],
        },
        {'type': 'switch', 'id': 'c_kids', 'label': t('With kids', 'مع أطفال')},
        {
          'type': 'slider',
          'id': 'c_budget',
          'label': t('Budget', 'الميزانية'),
          'min': 0,
          'max': 100,
          'step': 10,
          'value': 40,
        },
        {
          'type': 'text_input',
          'id': 'c_note',
          'hint': t('Anything else?', 'أي شيء آخر؟'),
          'max_length': 120,
        },
      ],
      actions: [
        {
          'id': 'a_go',
          'type': 'confirm',
          'label': t('Continue', 'متابعة'),
          'params_from': ['c_when', 'c_with', 'c_kids', 'c_budget', 'c_note'],
        },
        {'id': 'a_cancel', 'type': 'cancel', 'label': t('Cancel', 'إلغاء')},
      ],
    ),
    surface(
      'news',
      'news',
      t('Top stories', 'أهم الأخبار'),
      [
        {
          'type': 'filter_chips',
          'id': 'c_topic',
          'choices': [
            {'id': 'tech', 'label': t('Tech', 'تقنية')},
            {'id': 'sport', 'label': t('Sport', 'رياضة')},
          ],
        },
        {
          'type': 'news_list',
          'id': 'c_news',
          'items': [
            {
              'id': 'n1',
              'headline': t(
                'Demo headline: city opens new park',
                'خبر تجريبي: افتتاح حديقة جديدة',
              ),
              'publisher': 'Demo News',
              'published_at': '2026-10-28T08:00:00Z',
              'excerpt': t('Sample excerpt.', 'مقتطف تجريبي.'),
              'url': 'https://example.com/news/1',
            },
            {
              'id': 'n2',
              'headline': t(
                'Demo headline: rain expected',
                'خبر تجريبي: أمطار',
              ),
              'publisher': 'Demo Wire',
              'published_at': '2026-10-28T06:30:00Z',
              'url': 'https://example.com/news/2',
            },
          ],
        },
        {
          'type': 'attribution',
          'id': 'c_src',
          'source': 'Demo provider',
          'retrieved_at': '2026-10-28T09:00:00Z',
        },
      ],
      actions: [
        {'id': 'a_sum', 'type': 'summarize', 'label': t('Summarize', 'لخّص')},
      ],
    ),
    surface('sports', 'sports', t('Live scores', 'النتائج المباشرة'), [
      {
        'type': 'score_cards',
        'id': 'c_scores',
        'items': [
          {
            'id': 'm1',
            'competition': 'Demo League',
            'status': 'live',
            'minute': 67,
            'home': {'name': 'Demo FC', 'score': 2},
            'away': {'name': 'Sample United', 'score': 1},
          },
          {
            'id': 'm2',
            'competition': 'Demo League',
            'status': 'scheduled',
            'home': {'name': 'Example City'},
            'away': {'name': 'Test Rovers'},
          },
        ],
      },
    ]),
    surface(
      'research',
      'web_research',
      t('Research', 'بحث'),
      [
        {
          'type': 'summary',
          'id': 'c_sum',
          'text': t(
            'Demo summary with a citation [1].',
            'ملخص تجريبي مع مرجع [1].',
          ),
          'citations': [
            {'n': 1, 'title': 'Example source', 'url': 'https://example.com/a'},
          ],
        },
        {
          'type': 'search_results',
          'id': 'c_results',
          'items': [
            {
              'id': 'r1',
              'title': 'Example article',
              'domain': 'example.com',
              'url': 'https://example.com/a',
              'excerpt': t('Sample result.', 'نتيجة تجريبية.'),
            },
          ],
        },
        {
          'type': 'comparison',
          'id': 'c_cmp',
          'columns': ['A', 'B'],
          'rows': [
            {
              'label': t('Price', 'السعر'),
              'values': ['10', '12'],
            },
            {
              'label': t('Rating', 'التقييم'),
              'values': ['4.5', '4.1'],
            },
          ],
        },
      ],
      actions: [
        {'id': 'a_cmp', 'type': 'compare', 'label': t('Compare', 'قارن')},
      ],
    ),
    surface('places', 'places_maps', t('Nearby cafés', 'مقاهٍ قريبة'), [
      {
        'type': 'place_list',
        'id': 'c_places',
        'choices': [
          {
            'id': 'p1',
            'label': 'Demo Café',
            'place_id': 'demo_p1',
            'rating': 4.6,
            'distance_m': 350,
            'address': t('1 Example St', '١ شارع المثال'),
            'location': {'lat': 33.3152, 'lng': 44.3661},
          },
          {
            'id': 'p2',
            'label': 'Sample Roastery',
            'place_id': 'demo_p2',
            'rating': 4.2,
            'distance_m': 900,
            'location': {'lat': 33.3189, 'lng': 44.3702},
          },
        ],
      },
      {
        'type': 'map_preview',
        'id': 'c_map',
        'pins': [
          {'lat': 33.3152, 'lng': 44.3661, 'label': '1'},
          {'lat': 33.3189, 'lng': 44.3702, 'label': '2'},
        ],
      },
    ]),
    surface('media', 'images_media', t('Images', 'صور'), [
      {
        'type': 'image_grid',
        'id': 'c_images',
        'items': [
          {
            'id': 'i1',
            'url': 'https://example.com/demo-1.jpg',
            'alt': t('Demo image', 'صورة تجريبية'),
          },
          {
            'id': 'i2',
            'url': 'https://example.com/demo-2.jpg',
            'alt': t('Generated demo image', 'صورة مولدة تجريبية'),
            'generated': true,
          },
        ],
      },
    ]),
    surface('files', 'files_documents', t('Document', 'مستند'), [
      {
        'type': 'file_preview',
        'id': 'c_file',
        'name': 'demo-report.pdf',
        'pages': 4,
        'insights': [
          t('Demo insight one', 'ملاحظة تجريبية ١'),
          t('Demo insight two', 'ملاحظة تجريبية ٢'),
        ],
      },
      {
        'type': 'key_value',
        'id': 'c_meta',
        'rows': [
          {'k': t('Size', 'الحجم'), 'v': '1.2 MB'},
          {'k': t('Type', 'النوع'), 'v': 'PDF'},
        ],
      },
    ]),
    surface('device', 'device_actions', t('On this phone', 'على هذا الهاتف'), [
      {
        'type': 'banner',
        'id': 'c_note',
        'kind': 'info',
        'text': t(
          'Each action asks before it runs.',
          'كل إجراء يطلب الإذن قبل تنفيذه.',
        ),
      },
      {
        'type': 'action_list',
        'id': 'c_actions',
        'items': [
          {
            'id': 'd1',
            'label': t('Network status', 'حالة الشبكة'),
            'tool_id': 'device.network.get_status',
          },
          {
            'id': 'd2',
            'label': t('Open example.com', 'افتح example.com'),
            'tool_id': 'device.browser.open_url',
            'arguments': {'url': 'https://example.com'},
          },
        ],
      },
    ]),
    surface(
      'tasks',
      'tasks_workflows',
      t('Trip booking', 'حجز الرحلة'),
      [
        {
          'type': 'steps',
          'id': 'c_steps',
          'items': [
            {'id': 's1', 'label': t('Search', 'بحث'), 'state': 'done'},
            {'id': 's2', 'label': t('Compare', 'مقارنة'), 'state': 'running'},
            {'id': 's3', 'label': t('Book', 'حجز'), 'state': 'waiting'},
          ],
        },
        {
          'type': 'progress',
          'id': 'c_progress',
          'value': 0.5,
          'label': t('Halfway', 'في المنتصف'),
        },
      ],
      actions: [
        {
          'id': 'a_book',
          'type': 'approval',
          'label': t('Approve booking', 'وافق على الحجز'),
          'requires_confirmation': true,
        },
        {
          'id': 'a_stop',
          'type': 'workflow.cancel',
          'label': t('Stop', 'إيقاف'),
        },
      ],
    ),
  ];
}

/// The non-ready states (one surface each) and an unsupported schema.
List<Map<String, Object?>> demoStateSurfaces({required bool arabic}) {
  String t(String en, String ar) => arabic ? ar : en;
  Map<String, Object?> s(String state, {String? code, bool retry = false}) => {
    'schema_version': '1.0',
    'surface_id': 'demo_state_${code ?? state}',
    'category': 'news',
    'title': t('State: ', 'الحالة: ') + (code ?? state),
    'fallback_text': t('Demo fallback text', 'نص بديل تجريبي'),
    'demo': true,
    'status': {'state': state, 'code': ?code, 'retryable': retry},
    'components': const <Object>[],
  };
  return [
    s('loading'),
    s('partial'),
    s('empty'),
    s('disabled'),
    s('error', retry: true),
    s('offline', retry: true),
    s('error', code: 'provider_unavailable'),
    {
      'schema_version': '9.0',
      'surface_id': 'demo_state_future_schema',
      'category': 'news',
      'fallback_text': t(
        'A newer surface shown as text.',
        'واجهة أحدث معروضة كنص.',
      ),
      'demo': true,
    },
  ];
}
