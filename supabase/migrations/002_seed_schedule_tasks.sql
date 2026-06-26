-- Seed 26 puppy schedule blocks from the HTML template

INSERT INTO schedule_tasks (id, sort_order, time_label, category, title, subtitle, icon, section) VALUES
  ('wake_potty_530',   1,  '5:30 AM',  'potty',  'Wake Up + Potty',           'Outside immediately — no delay',                    '🌿', 'Morning'),
  ('meal_1_540',       2,  '5:40 AM',  'feed',   'Meal #1',                   'Then outside again within 10 min',                  '🍽️', 'Morning'),
  ('play_600',         3,  '6:00 AM',  'play',   'Short Play',                '5–10 min gentle play',                              '🧸', 'Morning'),
  ('nap_630',          4,  '6:30 AM',  'sleep',  'Nap in Crate',              '~90 min — overtired pups get bitey',                '💤', 'Morning'),

  ('potty_800',        5,  '8:00 AM',  'potty',  'Potty Break',               NULL,                                                '🌿', 'Mid-Morning'),
  ('train_810',        6,  '8:10 AM',  'train',  'Training Session',          '5 min max — sit, name, recall',                     '⭐', 'Mid-Morning'),
  ('play_820',         7,  '8:20 AM',  'play',   'Explore / Socialize',       'Sounds, surfaces, gentle handling',                 '🧸', 'Mid-Morning'),
  ('potty_850',        8,  '8:50 AM',  'potty',  'Potty Break',               NULL,                                                '🌿', 'Mid-Morning'),
  ('nap_900',          9,  '9:00 AM',  'sleep',  'Nap in Crate',              '~90 min',                                           '💤', 'Mid-Morning'),

  ('potty_1030',       10, '10:30 AM', 'potty',  'Potty Break',               NULL,                                                '🌿', 'Midday'),
  ('play_1040',        11, '10:40 AM', 'play',   'Play + Short Training',     'Keep sessions brief and positive',                  '🧸', 'Midday'),
  ('potty_1130',       12, '11:30 AM', 'potty',  'Potty Break',               NULL,                                                '🌿', 'Midday'),
  ('meal_2_1140',      13, '11:40 AM', 'feed',   'Meal #2',                   'Outside again within 10 min',                       '🍽️', 'Midday'),
  ('nap_1200',         14, '12:00 PM', 'sleep',  'Long Midday Nap',           '1.5–2 hrs in crate',                                '💤', 'Midday'),

  ('potty_1330',       15, '1:30 PM',  'potty',  'Potty Break',               NULL,                                                '🌿', 'Afternoon'),
  ('play_1340',        16, '1:40 PM',  'play',   'Afternoon Play + Explore',  NULL,                                                '🧸', 'Afternoon'),
  ('train_1410',       17, '2:10 PM',  'train',  'Training Session',          '5 min max',                                         '⭐', 'Afternoon'),
  ('nap_1430',         18, '2:30 PM',  'sleep',  'Nap',                       '~90 min',                                           '💤', 'Afternoon'),

  ('potty_1600',       19, '4:00 PM',  'potty',  'Potty Break',               NULL,                                                '🌿', 'Evening'),
  ('meal_3_1700',      20, '5:00 PM',  'feed',   'Meal #3',                   'Outside within 10 min after eating',                '🍽️', 'Evening'),
  ('play_1730',        21, '5:30 PM',  'play',   'Active Play',               'Most energetic window — enjoy it!',                 '🧸', 'Evening'),
  ('nap_1830',         22, '6:30 PM',  'sleep',  'Evening Nap',               '~60–90 min',                                        '💤', 'Evening'),
  ('wind_2000',        23, '8:00 PM',  'wind',   'Wind Down',                 'Calm time, chew toy — no rough play. Limit water after 8 PM.', '🕯️', 'Evening'),
  ('potty_2115',       24, '9:15 PM',  'potty',  'Last Potty of Night',       NULL,                                                '🌿', 'Evening'),
  ('bedtime_2130',     25, '9:30 PM',  'sleep',  'Bedtime in Crate',          NULL,                                                '🌙', 'Evening'),

  ('overnight_potty_130', 26, '1:30 AM', 'night', 'Overnight Potty',          'Quiet & calm — no play. Straight back to crate.',   '🌿', 'Overnight');
