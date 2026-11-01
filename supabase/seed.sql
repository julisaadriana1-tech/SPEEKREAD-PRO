-- SpeakRead Pro — datos iniciales
-- Ejecutar DESPUÉS de 0001_init.sql (SQL Editor > New query > pegar > Run)

-- ---------------------------------------------------------
-- Insignias
-- ---------------------------------------------------------
insert into public.badges (code, name, description, icon) values
  ('first_words',   'First Words',              'Completaste tu primera lección hablada',          'record_voice_over'),
  ('clear_speaker', 'Clear Speaker',            '10 oraciones seguidas con 85 o más',               'graphic_eq'),
  ('steering_ready','Steering Committee Ready', 'Lectura completa C1 con 85 o más',                 'workspace_premium'),
  ('on_track',      'On Track',                 'Racha de 7 días',                                  'local_fire_department'),
  ('quarter_close', 'Quarter Close',            'Racha de 90 días',                                 'calendar_month'),
  ('risk_manager',  'Risk Manager',             '10 lecciones del tema riesgos',                    'shield'),
  ('word_collector','Word Collector',           '500 palabras dominadas',                           'menu_book'),
  ('perfect_read',  'Perfect Read',             'Lectura completa con 100 en precisión',            'verified'),
  ('level_up',      'Level Up',                 'Subiste de nivel CEFR',                            'trending_up')
on conflict (code) do nothing;

-- ---------------------------------------------------------
-- Desafíos diarios (rotan cada día)
-- ---------------------------------------------------------
insert into public.challenges (period, title, metric, target, xp_reward) values
  ('daily',  'Completá 1 lección hoy',                         'lessons',        1, 25),
  ('daily',  'Pronunciá 5 oraciones con 80 o más',             'good_sentences', 5, 25),
  ('daily',  'Estudiá 10 minutos',                             'minutes',       10, 25),
  ('daily',  'Respondé bien 5 preguntas de comprensión',       'quiz_correct',   5, 25),
  ('weekly', 'Completá 5 lecciones esta semana',               'lessons',        5, 100);

-- =========================================================
-- LECCIÓN 1 · A2 · Trabajo · Daily stand-up
-- =========================================================
insert into public.lessons (id, cefr_level, unit, order_index, title, context, topic, body_en, body_es, est_minutes, published)
values (
  '11111111-1111-4111-8111-111111111111', 'A2', 1, 1,
  'The daily stand-up meeting', 'work', 'project-management',
  'Every morning at nine, our team has a short stand-up meeting. Each person answers three questions. What did I do yesterday? What will I do today? Is anything blocking my work? Yesterday I finished the report for the client. Today I need to update the tasks in Jira. I have one blocker: I am waiting for access to the database. The meeting only takes fifteen minutes, so we keep our answers short.',
  'Todas las mañanas a las nueve, nuestro equipo tiene una reunión corta de stand-up. Cada persona responde tres preguntas. ¿Qué hice ayer? ¿Qué haré hoy? ¿Hay algo que bloquee mi trabajo? Ayer terminé el informe para el cliente. Hoy necesito actualizar las tareas en Jira. Tengo un bloqueo: estoy esperando acceso a la base de datos. La reunión dura solo quince minutos, así que mantenemos las respuestas cortas.',
  8, true);

insert into public.lesson_sentences (lesson_id, idx, text_en, text_es) values
  ('11111111-1111-4111-8111-111111111111', 1, 'Every morning at nine, our team has a short stand-up meeting.', 'Todas las mañanas a las nueve, nuestro equipo tiene una reunión corta de stand-up.'),
  ('11111111-1111-4111-8111-111111111111', 2, 'What did I do yesterday?', '¿Qué hice ayer?'),
  ('11111111-1111-4111-8111-111111111111', 3, 'Yesterday I finished the report for the client.', 'Ayer terminé el informe para el cliente.'),
  ('11111111-1111-4111-8111-111111111111', 4, 'Today I need to update the tasks in Jira.', 'Hoy necesito actualizar las tareas en Jira.'),
  ('11111111-1111-4111-8111-111111111111', 5, 'I have one blocker: I am waiting for access to the database.', 'Tengo un bloqueo: estoy esperando acceso a la base de datos.'),
  ('11111111-1111-4111-8111-111111111111', 6, 'The meeting only takes fifteen minutes, so we keep our answers short.', 'La reunión dura solo quince minutos, así que mantenemos las respuestas cortas.');

insert into public.vocabulary (lesson_id, word, ipa, definition_en, translation_es, example_en) values
  ('11111111-1111-4111-8111-111111111111', 'stand-up',  '/ˈstænd ʌp/',   'A short daily team meeting, often done standing.', 'reunión diaria breve', 'Our stand-up starts at nine.'),
  ('11111111-1111-4111-8111-111111111111', 'blocker',   '/ˈblɒkər/',     'Something that stops you from making progress.', 'bloqueo, impedimento', 'Do you have any blockers today?'),
  ('11111111-1111-4111-8111-111111111111', 'update',    '/ʌpˈdeɪt/',     'To add the newest information to something.', 'actualizar', 'Please update the status of your task.'),
  ('11111111-1111-4111-8111-111111111111', 'access',    '/ˈækses/',      'Permission or the ability to use a system.', 'acceso', 'I requested access to the dashboard.'),
  ('11111111-1111-4111-8111-111111111111', 'report',    '/rɪˈpɔːrt/',    'A document that gives information about a topic.', 'informe', 'I sent the weekly report to the client.'),
  ('11111111-1111-4111-8111-111111111111', 'yesterday', '/ˈjestərdeɪ/',  'The day before today.', 'ayer', 'Yesterday we closed three tickets.');

insert into public.quiz_questions (lesson_id, idx, type, prompt, options, answer, explanation) values
  ('11111111-1111-4111-8111-111111111111', 1, 'mc', 'How long does the stand-up meeting take?',
   '["Five minutes","Fifteen minutes","Thirty minutes","One hour"]', 'Fifteen minutes',
   'The text says: "The meeting only takes fifteen minutes".'),
  ('11111111-1111-4111-8111-111111111111', 2, 'tf', 'The speaker finished the client report yesterday.',
   '["True","False"]', 'True',
   '"Yesterday I finished the report for the client."'),
  ('11111111-1111-4111-8111-111111111111', 3, 'gap', 'Today I need to ______ the tasks in Jira.',
   '["delete","update","print","close"]', 'update',
   'The speaker needs to update (actualizar) the tasks, not delete or close them.'),
  ('11111111-1111-4111-8111-111111111111', 4, 'context', 'What is the speaker''s blocker?',
   '["The client did not answer","Jira is not working","Waiting for database access","The report is late"]', 'Waiting for database access',
   'A blocker is something that stops progress. Here it is: "I am waiting for access to the database."'),
  ('11111111-1111-4111-8111-111111111111', 5, 'tf', 'Team members give long, detailed answers in the stand-up.',
   '["True","False"]', 'False',
   'They keep their answers short because the meeting only takes fifteen minutes.'),
  ('11111111-1111-4111-8111-111111111111', 6, 'mc', 'Which question is NOT part of the stand-up?',
   '["What did I do yesterday?","What will I do today?","How much is my salary?","Is anything blocking my work?"]', 'How much is my salary?',
   'The three stand-up questions are about yesterday, today and blockers.');

-- =========================================================
-- LECCIÓN 2 · B1 · Trabajo · Comunicar un retraso
-- =========================================================
insert into public.lessons (id, cefr_level, unit, order_index, title, context, topic, body_en, body_es, est_minutes, published)
values (
  '22222222-2222-4222-8222-222222222222', 'B1', 1, 1,
  'Communicating a delay to the client', 'work', 'risk',
  'Hi Laura, I wanted to give you a quick update on the implementation timeline. During testing, we identified a risk that could impact the delivery date. The integration with your payment system is taking longer than expected, because we found several data issues. Our team is working on a fix, and we expect to have it ready by Thursday. As a result, the go-live date will move from the fifteenth to the twenty-second. I know this is not ideal, so I would like to schedule a short call tomorrow to review the new plan and answer any questions. Thank you for your understanding.',
  'Hola Laura, quería darte una actualización rápida sobre el cronograma de implementación. Durante las pruebas identificamos un riesgo que podría afectar la fecha de entrega. La integración con tu sistema de pagos está llevando más tiempo de lo esperado, porque encontramos varios problemas en los datos. Nuestro equipo está trabajando en una solución y esperamos tenerla lista para el jueves. Como resultado, la fecha de salida a producción pasará del quince al veintidós. Sé que no es lo ideal, así que me gustaría agendar una llamada corta mañana para revisar el nuevo plan y responder cualquier pregunta. Gracias por tu comprensión.',
  12, true);

insert into public.lesson_sentences (lesson_id, idx, text_en, text_es) values
  ('22222222-2222-4222-8222-222222222222', 1, 'I wanted to give you a quick update on the implementation timeline.', 'Quería darte una actualización rápida sobre el cronograma de implementación.'),
  ('22222222-2222-4222-8222-222222222222', 2, 'During testing, we identified a risk that could impact the delivery date.', 'Durante las pruebas identificamos un riesgo que podría afectar la fecha de entrega.'),
  ('22222222-2222-4222-8222-222222222222', 3, 'The integration with your payment system is taking longer than expected.', 'La integración con tu sistema de pagos está llevando más tiempo de lo esperado.'),
  ('22222222-2222-4222-8222-222222222222', 4, 'Our team is working on a fix, and we expect to have it ready by Thursday.', 'Nuestro equipo está trabajando en una solución y esperamos tenerla lista para el jueves.'),
  ('22222222-2222-4222-8222-222222222222', 5, 'As a result, the go-live date will move from the fifteenth to the twenty-second.', 'Como resultado, la fecha de salida a producción pasará del quince al veintidós.'),
  ('22222222-2222-4222-8222-222222222222', 6, 'I would like to schedule a short call tomorrow to review the new plan.', 'Me gustaría agendar una llamada corta mañana para revisar el nuevo plan.');

insert into public.vocabulary (lesson_id, word, ipa, definition_en, translation_es, example_en) values
  ('22222222-2222-4222-8222-222222222222', 'timeline',       '/ˈtaɪmlaɪn/',        'A plan that shows when things will happen.', 'cronograma', 'The timeline includes three phases.'),
  ('22222222-2222-4222-8222-222222222222', 'risk',           '/rɪsk/',             'The possibility that something bad will happen.', 'riesgo', 'We added the risk to the risk register.'),
  ('22222222-2222-4222-8222-222222222222', 'impact',         '/ˈɪmpækt/',          'To have a strong effect on something.', 'impactar, afectar', 'This change could impact the budget.'),
  ('22222222-2222-4222-8222-222222222222', 'integration',    '/ˌɪntɪˈɡreɪʃən/',    'Connecting two systems so they work together.', 'integración', 'The integration with SAP is complete.'),
  ('22222222-2222-4222-8222-222222222222', 'go-live',        '/ˈɡoʊ laɪv/',        'The moment a new system starts being used for real.', 'salida a producción', 'Go-live is planned for Monday.'),
  ('22222222-2222-4222-8222-222222222222', 'schedule',       '/ˈskedʒuːl/',        'To plan something for a specific time.', 'agendar, programar', 'Can we schedule a call for Friday?'),
  ('22222222-2222-4222-8222-222222222222', 'understanding',  '/ˌʌndərˈstændɪŋ/',   'Patience and acceptance of a difficult situation.', 'comprensión', 'Thank you for your understanding.');

insert into public.quiz_questions (lesson_id, idx, type, prompt, options, answer, explanation) values
  ('22222222-2222-4222-8222-222222222222', 1, 'mc', 'Why is the project delayed?',
   '["The client changed the scope","The payment integration has data issues","A team member is sick","The budget was cut"]',
   'The payment integration has data issues',
   'The text explains that the integration "is taking longer than expected, because we found several data issues".'),
  ('22222222-2222-4222-8222-222222222222', 2, 'mc', 'What is the new go-live date?',
   '["The fifteenth","Thursday","The twenty-second","Tomorrow"]', 'The twenty-second',
   'The go-live date "will move from the fifteenth to the twenty-second".'),
  ('22222222-2222-4222-8222-222222222222', 3, 'tf', 'The fix is expected to be ready by Thursday.',
   '["True","False"]', 'True', '"We expect to have it ready by Thursday."'),
  ('22222222-2222-4222-8222-222222222222', 4, 'gap', 'We identified a risk that could ______ the delivery date.',
   '["impact","celebrate","confirm","cancel"]', 'impact',
   '"Impact" means to have an effect on something. A risk can impact a date.'),
  ('22222222-2222-4222-8222-222222222222', 5, 'context', 'What is the tone of the message?',
   '["Angry and defensive","Professional and transparent","Very informal","Indifferent"]', 'Professional and transparent',
   'The writer explains the cause, gives a new date, offers a call and thanks the client. That is a professional, transparent tone.'),
  ('22222222-2222-4222-8222-222222222222', 6, 'tf', 'The writer wants to wait until next week to talk with Laura.',
   '["True","False"]', 'False', 'The writer wants to "schedule a short call tomorrow".');

-- =========================================================
-- LECCIÓN 3 · A2 · Vida · Compras de la semana
-- =========================================================
insert into public.lessons (id, cefr_level, unit, order_index, title, context, topic, body_en, body_es, est_minutes, published)
values (
  '33333333-3333-4333-8333-333333333333', 'A2', 1, 2,
  'Grocery shopping after work', 'life', 'daily-life',
  'I need to stop by the supermarket after work to buy groceries for the week. Before I leave the office, I check our shopping list on my phone. We need chicken, rice, vegetables, coffee and some fruit for breakfast. The supermarket is busy at six, so I try to be quick. I compare prices and choose the store brand when it is cheaper. At the checkout, I pay with my debit card and ask for a receipt. Planning our meals for the week helps us save money and time.',
  'Necesito pasar por el supermercado después del trabajo para comprar las provisiones de la semana. Antes de salir de la oficina, reviso nuestra lista de compras en el teléfono. Necesitamos pollo, arroz, verduras, café y algo de fruta para el desayuno. El supermercado está lleno a las seis, así que intento ser rápido. Comparo precios y elijo la marca del supermercado cuando es más barata. En la caja pago con mi tarjeta de débito y pido un comprobante. Planificar las comidas de la semana nos ayuda a ahorrar dinero y tiempo.',
  8, true);

insert into public.lesson_sentences (lesson_id, idx, text_en, text_es) values
  ('33333333-3333-4333-8333-333333333333', 1, 'I need to stop by the supermarket after work to buy groceries for the week.', 'Necesito pasar por el supermercado después del trabajo para comprar las provisiones de la semana.'),
  ('33333333-3333-4333-8333-333333333333', 2, 'Before I leave the office, I check our shopping list on my phone.', 'Antes de salir de la oficina, reviso nuestra lista de compras en el teléfono.'),
  ('33333333-3333-4333-8333-333333333333', 3, 'We need chicken, rice, vegetables, coffee and some fruit for breakfast.', 'Necesitamos pollo, arroz, verduras, café y algo de fruta para el desayuno.'),
  ('33333333-3333-4333-8333-333333333333', 4, 'I compare prices and choose the store brand when it is cheaper.', 'Comparo precios y elijo la marca del supermercado cuando es más barata.'),
  ('33333333-3333-4333-8333-333333333333', 5, 'At the checkout, I pay with my debit card and ask for a receipt.', 'En la caja pago con mi tarjeta de débito y pido un comprobante.'),
  ('33333333-3333-4333-8333-333333333333', 6, 'Planning our meals for the week helps us save money and time.', 'Planificar las comidas de la semana nos ayuda a ahorrar dinero y tiempo.');

insert into public.vocabulary (lesson_id, word, ipa, definition_en, translation_es, example_en) values
  ('33333333-3333-4333-8333-333333333333', 'groceries',   '/ˈɡroʊsəriz/',   'Food and things for the home that you buy in a supermarket.', 'provisiones, compras del súper', 'I buy groceries on Saturdays.'),
  ('33333333-3333-4333-8333-333333333333', 'stop by',     '/stɒp baɪ/',     'To visit a place for a short time.', 'pasar por', 'Can you stop by the pharmacy?'),
  ('33333333-3333-4333-8333-333333333333', 'vegetables',  '/ˈvedʒtəbəlz/',  'Plants or parts of plants that you eat.', 'verduras', 'We need more vegetables this week.'),
  ('33333333-3333-4333-8333-333333333333', 'checkout',    '/ˈtʃekaʊt/',     'The place in a store where you pay.', 'caja', 'There was a long line at the checkout.'),
  ('33333333-3333-4333-8333-333333333333', 'receipt',     '/rɪˈsiːt/',      'A paper that shows what you paid.', 'comprobante, recibo', 'Keep the receipt in case you need to return it.'),
  ('33333333-3333-4333-8333-333333333333', 'cheaper',     '/ˈtʃiːpər/',     'Costing less money.', 'más barato', 'The store brand is cheaper.');

insert into public.quiz_questions (lesson_id, idx, type, prompt, options, answer, explanation) values
  ('33333333-3333-4333-8333-333333333333', 1, 'mc', 'When does the speaker go to the supermarket?',
   '["Before work","During lunch","After work","On Sunday morning"]', 'After work',
   '"I need to stop by the supermarket after work."'),
  ('33333333-3333-4333-8333-333333333333', 2, 'tf', 'The speaker keeps the shopping list on paper.',
   '["True","False"]', 'False', 'The list is on the phone: "I check our shopping list on my phone."'),
  ('33333333-3333-4333-8333-333333333333', 3, 'gap', 'At the checkout, I pay with my debit card and ask for a ______.',
   '["receipt","recipe","refund","discount"]', 'receipt',
   'A receipt (comprobante) shows what you paid. Careful: "recipe" is a cooking recipe.'),
  ('33333333-3333-4333-8333-333333333333', 4, 'mc', 'Why does the speaker choose the store brand?',
   '["It tastes better","It is cheaper","It is healthier","It is the only option"]', 'It is cheaper',
   '"I choose the store brand when it is cheaper."'),
  ('33333333-3333-4333-8333-333333333333', 5, 'context', 'What is the main benefit of planning meals, according to the text?',
   '["Eating more fruit","Saving money and time","Cooking new recipes","Avoiding the supermarket"]', 'Saving money and time',
   'The last sentence says planning meals "helps us save money and time".'),
  ('33333333-3333-4333-8333-333333333333', 6, 'tf', 'The supermarket is quiet at six.',
   '["True","False"]', 'False', 'It is busy at six, so the speaker tries to be quick.');
