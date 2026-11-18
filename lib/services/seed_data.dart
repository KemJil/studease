import 'package:cloud_firestore/cloud_firestore.dart';

/// A document to write during first-login seeding.
class SeedDoc {
  const SeedDoc({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

class SeedDeck {
  const SeedDeck({required this.id, required this.data, required this.cards});

  final String id;
  final Map<String, dynamic> data;
  final List<SeedDoc> cards;
}

class SeedQuiz {
  const SeedQuiz({
    required this.id,
    required this.data,
    required this.questions,
  });

  final String id;
  final Map<String, dynamic> data;
  final List<SeedDoc> questions;
}

/// Starter workspace content: the lessons, decks, quiz and open-access books
/// every new StudEase account receives (mirrors `docs/index.html`).
class SeedData {
  SeedData._();

  static Map<String, dynamic> _meta() => <String, dynamic>{
    'createdAt': FieldValue.serverTimestamp(),
  };

  /// The three subject courses every account starts with. Ids are stable so
  /// lessons, decks, quizzes and books can link to them deterministically.
  static final List<SeedDoc> subjectCourses = <SeedDoc>[
    SeedDoc(
      id: 'mathematics',
      data: <String, dynamic>{
        'name': 'Mathematics',
        'description': 'Algebra, calculus & problem solving',
        'colorIndex': 0,
        'order': 1,
        ..._meta(),
      },
    ),
    SeedDoc(
      id: 'science',
      data: <String, dynamic>{
        'name': 'Science',
        'description': 'Biology, physics & the natural world',
        'colorIndex': 1,
        'order': 2,
        ..._meta(),
      },
    ),
    SeedDoc(
      id: 'english',
      data: <String, dynamic>{
        'name': 'English',
        'description': 'Writing, rhetoric & literature',
        'colorIndex': 2,
        'order': 3,
        ..._meta(),
      },
    ),
    // SUBJECT_COURSES_END
  ];

  static final List<SeedDoc> courses = <SeedDoc>[
    SeedDoc(
      id: 'math-1',
      data: <String, dynamic>{
        'courseId': 'mathematics',
        'subject': 'Mathematics',
        'folder': 'Algebra & Functions',
        'title': 'Quadratic Equations & Discriminants',
        'summary':
            'A quadratic equation is a second-order polynomial equation in a '
            'single variable x. Understanding the discriminant allows you to '
            'immediately determine the nature and number of real or complex '
            'roots.',
        'formulas': <Map<String, String>>[
          <String, String>{
            'label': 'Standard Form',
            'expr': 'ax² + bx + c = 0  (where a ≠ 0)',
          },
          <String, String>{
            'label': 'Quadratic Formula',
            'expr': 'x = (-b ± √(b² - 4ac)) / 2a',
          },
          <String, String>{'label': 'Discriminant (Δ)', 'expr': 'Δ = b² - 4ac'},
        ],
        'notes': <String>[
          'If Δ > 0, the equation has two distinct real roots.',
          'If Δ = 0, the equation has exactly one repeated real root '
              '(the vertex touches the x-axis).',
          'If Δ < 0, the equation has two complex conjugate roots.',
        ],
        'durationLabel': '12 min read',
        'completed': false,
        'order': 1,
        ..._meta(),
      },
    ),
    SeedDoc(
      id: 'math-2',
      data: <String, dynamic>{
        'courseId': 'mathematics',
        'subject': 'Mathematics',
        'folder': 'Calculus Foundations',
        'title': 'Derivatives & Power Rule Essentials',
        'summary':
            'The derivative measures the instantaneous rate of change of a '
            'function with respect to one of its variables. The Power Rule '
            'gives the fastest shortcut for differentiating polynomial terms.',
        'formulas': <Map<String, String>>[
          <String, String>{
            'label': 'Power Rule',
            'expr': 'd/dx [xⁿ] = n · xⁿ⁻¹',
          },
          <String, String>{
            'label': 'Constant Multiple',
            'expr': 'd/dx [c · f(x)] = c · f′(x)',
          },
          <String, String>{
            'label': 'Limit Definition',
            'expr': 'f′(x) = lim(h→0) [f(x+h) - f(x)] / h',
          },
        ],
        'notes': <String>[
          'The derivative of any standalone constant is always 0.',
          'Linear terms like 5x differentiate directly to their coefficient (5).',
          'Rewrite radicals such as √x as fractional exponents before '
              'applying the Power Rule.',
        ],
        'durationLabel': '15 min read',
        'completed': false,
        'order': 2,
        ..._meta(),
      },
    ),
    SeedDoc(
      id: 'sci-1',
      data: <String, dynamic>{
        'courseId': 'science',
        'subject': 'Science',
        'folder': 'Cell Biology',
        'title': 'Cellular Respiration & ATP Synthesis',
        'summary':
            'Cellular respiration is the metabolic pathway that breaks down '
            'glucose in the presence of oxygen to generate Adenosine '
            'Triphosphate (ATP), the primary energy currency of living cells.',
        'formulas': <Map<String, String>>[
          <String, String>{
            'label': 'Overall Equation',
            'expr': 'C₆H₁₂O₆ + 6O₂ → 6CO₂ + 6H₂O + ~36 ATP',
          },
          <String, String>{
            'label': 'Stage 1 (Cytosol)',
            'expr': 'Glycolysis → Net 2 ATP + 2 Pyruvate',
          },
          <String, String>{
            'label': 'Stage 3 (Cristae)',
            'expr': 'Oxidative Phosphorylation → ~32 ATP',
          },
        ],
        'notes': <String>[
          'Glycolysis occurs anaerobically in the cytoplasm and does not '
              'require oxygen.',
          'The Krebs (Citric Acid) Cycle takes place inside the '
              'mitochondrial matrix.',
          'Oxygen acts as the final electron acceptor in the Electron '
              'Transport Chain.',
        ],
        'durationLabel': '14 min read',
        'completed': false,
        'order': 3,
        ..._meta(),
      },
    ),
    SeedDoc(
      id: 'sci-2',
      data: <String, dynamic>{
        'courseId': 'science',
        'subject': 'Science',
        'folder': 'Classical Physics',
        'title': "Newton's Laws of Motion & Free-Body Diagrams",
        'summary':
            'Isaac Newton’s three laws form the foundation of classical '
            'mechanics, describing the relationship between the motion of an '
            'object and the forces acting upon it.',
        'formulas': <Map<String, String>>[
          <String, String>{
            'label': 'Second Law',
            'expr': 'F_net = m · a  (Newtons, N)',
          },
          <String, String>{
            'label': 'Weight Force',
            'expr': 'W = m · g  (g ≈ 9.81 m/s²)',
          },
          <String, String>{
            'label': 'Kinetic Friction',
            'expr': 'f_k = μ_k · N',
          },
        ],
        'notes': <String>[
          'First Law (Inertia): objects maintain constant velocity unless '
              'acted on by a net external force.',
          'Acceleration is directly proportional to net force and inversely '
              'proportional to mass.',
          'Action-reaction force pairs always act on two different '
              'interacting bodies.',
        ],
        'durationLabel': '10 min read',
        'completed': false,
        'order': 4,
        ..._meta(),
      },
    ),
    SeedDoc(
      id: 'eng-1',
      data: <String, dynamic>{
        'courseId': 'english',
        'subject': 'English',
        'folder': 'Academic Writing',
        'title': 'Thesis Statements & Rhetorical Appeals',
        'summary':
            'Persuasive academic writing balances a clear, arguable thesis '
            'statement with Aristotle’s three classical modes of persuasion: '
            'Ethos, Pathos and Logos.',
        'formulas': <Map<String, String>>[
          <String, String>{
            'label': 'Ethos',
            'expr': 'Credibility, authority & ethical trustworthiness',
          },
          <String, String>{
            'label': 'Logos',
            'expr': 'Logical reasoning, data, evidence & structure',
          },
          <String, String>{
            'label': 'Pathos',
            'expr': 'Emotional resonance & vivid audience connection',
          },
        ],
        'notes': <String>[
          'A strong thesis makes a specific, debatable claim rather than '
              'stating a mere fact.',
          'Place your thesis at the end of the introductory paragraph to '
              'anchor the essay.',
          'Combine Logos (statistics) with Ethos (peer-reviewed citations) for '
              'academic rigor.',
        ],
        'durationLabel': '11 min read',
        'completed': false,
        'order': 5,
        ..._meta(),
      },
    ),
    // COURSES_END
  ];

  static final List<SeedDeck> decks = <SeedDeck>[
    SeedDeck(
      id: 'deck-math',
      data: <String, dynamic>{
        'subject': 'Mathematics',
        'title': 'Mathematics — Core Formulas',
        'courseId': 'mathematics',
        'source': 'manual',
        'cardCount': 4,
        ..._meta(),
      },
      cards: <SeedDoc>[
        SeedDoc(
          id: 'fc-m1',
          data: <String, dynamic>{
            'front': 'What is the derivative of sin(x)?',
            'back': 'cos(x)',
            'hint': 'Basic trigonometric derivative',
            'mastered': false,
          },
        ),
        SeedDoc(
          id: 'fc-m2',
          data: <String, dynamic>{
            'front': 'What does a discriminant Δ = 0 tell us?',
            'back': 'Exactly one repeated real root',
            'hint': 'b² - 4ac = 0',
            'mastered': false,
          },
        ),
        SeedDoc(
          id: 'fc-m3',
          data: <String, dynamic>{
            'front': 'What is the Pythagorean Identity?',
            'back': 'sin²(θ) + cos²(θ) = 1',
            'hint': 'Unit circle relation',
            'mastered': false,
          },
        ),
        SeedDoc(
          id: 'fc-m4',
          data: <String, dynamic>{
            'front': 'What is log₁₀(1000)?',
            'back': '3 (since 10³ = 1000)',
            'hint': 'Base-10 exponent',
            'mastered': false,
          },
        ),
      ],
    ),
    SeedDeck(
      id: 'deck-science',
      data: <String, dynamic>{
        'subject': 'Science',
        'title': 'Science — Biology & Physics Essentials',
        'courseId': 'science',
        'source': 'manual',
        'cardCount': 3,
        ..._meta(),
      },
      cards: <SeedDoc>[
        SeedDoc(
          id: 'fc-s1',
          data: <String, dynamic>{
            'front': 'Which organelle produces most of the cellular ATP?',
            'back': 'Mitochondria',
            'hint': 'Powerhouse of the cell',
            'mastered': false,
          },
        ),
        SeedDoc(
          id: 'fc-s2',
          data: <String, dynamic>{
            'front': 'What is the SI unit of force?',
            'back': 'Newton (N = kg·m/s²)',
            'hint': 'Named after Sir Isaac Newton',
            'mastered': false,
          },
        ),
        SeedDoc(
          id: 'fc-s3',
          data: <String, dynamic>{
            'front': 'Which bond shares electron pairs between atoms?',
            'back': 'Covalent bond',
            'hint': 'Common in organic molecules',
            'mastered': false,
          },
        ),
      ],
    ),
    SeedDeck(
      id: 'deck-english',
      data: <String, dynamic>{
        'subject': 'English',
        'title': 'English — Rhetoric & Grammar',
        'courseId': 'english',
        'source': 'manual',
        'cardCount': 3,
        ..._meta(),
      },
      cards: <SeedDoc>[
        SeedDoc(
          id: 'fc-e1',
          data: <String, dynamic>{
            'front': 'Define "Ethos" in rhetoric.',
            'back': 'An appeal to the speaker’s credibility and authority.',
            'hint': 'Greek for character',
            'mastered': false,
          },
        ),
        SeedDoc(
          id: 'fc-e2',
          data: <String, dynamic>{
            'front': 'What is a "Juxtaposition"?',
            'back':
                'Placing two contrasting ideas or images side by side '
                'for effect.',
            'hint': 'Literary contrast device',
            'mastered': false,
          },
        ),
        SeedDoc(
          id: 'fc-e3',
          data: <String, dynamic>{
            'front': 'What does an Oxford comma precede?',
            'back': 'The final conjunction in a list of three or more items.',
            'hint': 'Serial comma',
            'mastered': false,
          },
        ),
      ],
    ),
    // DECKS_END
  ];

  static final List<SeedQuiz> quizzes = <SeedQuiz>[
    SeedQuiz(
      id: 'quiz-daily',
      data: <String, dynamic>{
        'subject': 'Mixed Subjects',
        'title': 'Daily Quick Quiz',
        'source': 'manual',
        'questionCount': 4,
        ..._meta(),
      },
      questions: <SeedDoc>[
        SeedDoc(
          id: 'q1',
          data: <String, dynamic>{
            'question':
                'Using the Power Rule, what is the derivative of '
                'f(x) = 4x³ + 2x?',
            'options': <String>['12x² + 2', '12x³ + 2', '4x² + 2x', '7x² + 2'],
            'correctIndex': 0,
            'explanation':
                'Multiply the exponent by the coefficient and '
                'reduce the power by 1: 3·4x² + 1·2x⁰ = 12x² + 2.',
          },
        ),
        SeedDoc(
          id: 'q2',
          data: <String, dynamic>{
            'question':
                'Where does glycolysis take place inside a '
                'eukaryotic cell?',
            'options': <String>[
              'Mitochondrial matrix',
              'Nucleus',
              'Cytoplasm (cytosol)',
              'Ribosome',
            ],
            'correctIndex': 2,
            'explanation':
                'Glycolysis occurs in the cytoplasm and breaks '
                'glucose into 2 pyruvate molecules without needing oxygen.',
          },
        ),
        SeedDoc(
          id: 'q3',
          data: <String, dynamic>{
            'question':
                'Which rhetorical appeal relies primarily on '
                'statistics, facts and logical structure?',
            'options': <String>['Pathos', 'Logos', 'Ethos', 'Kairos'],
            'correctIndex': 1,
            'explanation':
                'Logos appeals to logic and reason through '
                'structured arguments and empirical evidence.',
          },
        ),
        SeedDoc(
          id: 'q4',
          data: <String, dynamic>{
            'question':
                'If a 5 kg object accelerates at 3 m/s², what is the '
                'net force acting on it?',
            'options': <String>['1.67 N', '8 N', '15 N', '45 N'],
            'correctIndex': 2,
            'explanation':
                'By Newton’s Second Law (F = m · a), '
                'F = 5 kg × 3 m/s² = 15 newtons.',
          },
        ),
      ],
    ),
  ];

  static final List<SeedDoc> books = <SeedDoc>[
    SeedDoc(
      id: 'book-physics',
      data: <String, dynamic>{
        'title': 'College Physics 2e',
        'author': 'OpenStax',
        'subject': 'Science',
        'courseId': 'science',
        'sourceType': 'url',
        'pdfUrl':
            'https://assets.openstax.org/oscms-prodcms/media/documents/'
            'College_Physics_2e-WEB.pdf',
        'totalPages': 0,
        'lastReadPage': 1,
        'bookmarked': true,
        'colorIndex': 0,
        ..._meta(),
      },
    ),
    SeedDoc(
      id: 'book-linear-algebra',
      data: <String, dynamic>{
        'title': 'Linear Algebra Done Wrong',
        'author': 'Sergei Treil · Brown University',
        'subject': 'Mathematics',
        'courseId': 'mathematics',
        'sourceType': 'url',
        'pdfUrl':
            'https://www.math.brown.edu/streil/papers/LADW/'
            'LADW_2017-09-04.pdf',
        'totalPages': 0,
        'lastReadPage': 1,
        'bookmarked': false,
        'colorIndex': 1,
        ..._meta(),
      },
    ),
    SeedDoc(
      id: 'book-pride-prejudice',
      data: <String, dynamic>{
        'title': 'Pride and Prejudice',
        'author': 'Jane Austen',
        'subject': 'English',
        'courseId': 'english',
        'sourceType': 'url',
        'pdfUrl':
            'https://www.planetebook.com/free-ebooks/'
            'pride-and-prejudice.pdf',
        'totalPages': 0,
        'lastReadPage': 1,
        'bookmarked': false,
        'colorIndex': 2,
        ..._meta(),
      },
    ),
    SeedDoc(
      id: 'book-alice',
      data: <String, dynamic>{
        'title': 'Alice’s Adventures in Wonderland',
        'author': 'Lewis Carroll',
        'subject': 'English',
        'courseId': 'english',
        'sourceType': 'url',
        'pdfUrl':
            'https://www.planetebook.com/free-ebooks/'
            'alices-adventures-in-wonderland.pdf',
        'totalPages': 0,
        'lastReadPage': 1,
        'bookmarked': false,
        'colorIndex': 3,
        ..._meta(),
      },
    ),
    SeedDoc(
      id: 'book-resnet',
      data: <String, dynamic>{
        'title': 'Deep Residual Learning for Image Recognition',
        'author': 'Kaiming He et al. · arXiv',
        'subject': 'Science',
        'courseId': 'science',
        'sourceType': 'url',
        'pdfUrl': 'https://arxiv.org/pdf/1512.03385v1',
        'totalPages': 0,
        'lastReadPage': 1,
        'bookmarked': false,
        'colorIndex': 4,
        ..._meta(),
      },
    ),
    // BOOKS_END
  ];
}
