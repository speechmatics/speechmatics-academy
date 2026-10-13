// Every consultation below is fictional, scripted, and timed synthetically.
import { DEFAULT_BATCH_REGION } from './batch-endpoints.js';
export const LANGUAGES = {
  en: { name: 'English', nativeName: 'English', dir: 'ltr', color: '#F76B15' },
  es: { name: 'Spanish', nativeName: 'Español', dir: 'ltr', color: '#29A383' },
  ar: { name: 'Arabic', nativeName: 'العربية', dir: 'rtl', color: '#0D3C48' },
  fr: { name: 'French', nativeName: 'Français', dir: 'ltr', color: '#FFC53D' },
  fi: { name: 'Finnish', nativeName: 'Suomi', dir: 'ltr', color: '#29A383' },
  sv: { name: 'Swedish', nativeName: 'Svenska', dir: 'ltr', color: '#0D3C48' },
  pl: { name: 'Polish', nativeName: 'Polski', dir: 'ltr', color: '#FFC53D' },
};

function turn(id, speaker, start, end, segments) {
  const tokens = segments.flatMap(([language, text]) => text.split(/\s+/u).map(text => ({ text, language })));
  const step = (end - start) / tokens.length;
  return {
    id, speaker, start, end,
    words: tokens.map((token, index) => ({
      ...token, start: start + step * index, end: index === tokens.length - 1 ? end : start + step * (index + 1),
    })),
  };
}

export const SAMPLES = [
  {
    id: 'diabetes-follow-up', title: 'Diabetes follow-up', subtitle: 'Spanish ↔ English',
    description: 'A fictional clinician and patient review symptoms, a reported medication, and questions about recent blood tests.',
    duration: 82, languages: ['es', 'en'], speakerNames: { S1: 'Dr. Morgan', S2: 'Patient' },
    specialty: 'Diabetes care', region: DEFAULT_BATCH_REGION, locale: 'en-US', diarization: 'speaker', isDemo: true,
    utterances: [
      turn('d1', 'S1', 1, 10, [['en', 'Good morning. We are reviewing your diabetes follow-up today. How have you been feeling since our last appointment?']]),
      turn('d2', 'S2', 11, 21, [['es', 'Buenos días, doctora. Me siento mejor, pero a veces tengo mucha sed.'], ['en', 'I brought my glucose notes from home.']]),
      turn('d3', 'S1', 22, 31, [['en', 'Thank you. These notes give us something to discuss alongside your blood tests. Are you still taking the medication listed here?']]),
      turn('d4', 'S2', 32, 42, [['en', 'Yes, I have been taking metformin as previously discussed.'], ['es', 'No he cambiado nada. Quería preguntar por el resultado de la hemoglobina.']]),
      turn('d5', 'S1', 43, 53, [['en', 'We can review the HbA1c result together. It describes blood glucose over time. What questions would you like to ask about it?']]),
      turn('d6', 'S2', 54, 63, [['es', 'Quiero entender cómo se relaciona con mis notas. También he notado cansancio por la tarde.'], ['en', 'Could that be relevant?']]),
      turn('d7', 'S1', 64, 73, [['en', 'Let us record when the tiredness happens and review the symptoms you described. We will discuss your questions and the available test results.']]),
      turn('d8', 'S2', 74, 81, [['es', 'Gracias. Me ayuda poder explicar los síntomas en español.'], ['en', 'I would like to go through the results together.']]),
    ],
  },
  {
    id: 'arabic-consultation', title: 'Respiratory consultation', subtitle: 'Arabic ↔ English ↔ French',
    description: 'A fictional three-language conversation about reported symptoms, inhaler history, and questions for a respiratory review.',
    duration: 70, languages: ['ar', 'en', 'fr'], speakerNames: { S1: 'Dr. Morgan', S2: 'Patient' },
    specialty: 'Respiratory care', region: DEFAULT_BATCH_REGION, locale: 'en-GB', diarization: 'speaker', isDemo: true,
    utterances: [
      turn('a1', 'S1', 1, 8, [['en', 'Welcome. Today we are reviewing your breathing symptoms.'], ['fr', 'Pouvez-vous décrire ce que vous avez remarqué cette semaine ?']]),
      turn('a2', 'S2', 9, 17, [['ar', 'أشعر بضيق في التنفس عندما أمشي بسرعة، وأحيانًا أسعل في الليل.'], ['en', 'It has been more noticeable recently.']]),
      turn('a3', 'S1', 18, 25, [['fr', 'Merci pour ces précisions. Vous aviez mentionné un inhalateur lors de votre dernière visite. Figure-t-il toujours sur votre liste de médicaments ?']]),
      turn('a4', 'S2', 26, 34, [['en', 'Yes, I have the inhaler listed in my notes.'], ['ar', 'أحضرت قائمة الأدوية معي. هل يمكننا مراجعتها معًا؟']]),
      turn('a5', 'S1', 35, 42, [['fr', 'Oui, nous pouvons revoir cette liste et le compte rendu de votre spirométrie.'], ['en', 'Are there other symptoms you would like to discuss?']]),
      turn('a6', 'S2', 43, 51, [['ar', 'أشعر بالتعب أحيانًا، ولدي أسئلة عن نتائج الفحص.'], ['fr', 'Je voudrais comprendre ce qui est écrit dans le compte rendu.']]),
      turn('a7', 'S1', 52, 60, [['en', 'We will go through the report together and record your questions. Could you tell me more about when the cough occurs?']]),
      turn('a8', 'S2', 61, 69, [['ar', 'يحدث السعال غالبًا في المساء. شكرًا لإتاحة الوقت لشرح الأعراض بالعربية.'], ['fr', 'Cela me permet de mieux expliquer ce que je ressens.']]),
    ],
  },
  {
    id: 'nordic-consultation', title: 'Nordic follow-up', subtitle: 'Finnish ↔ Swedish · two channels',
    description: 'A fictional Finnish–Swedish appointment with separate clinician and patient channels, discussing reported symptoms and questions about previous blood tests.',
    duration: 78, languages: ['fi', 'sv'], speakerNames: { L: 'Dr. Morgan · left', R: 'Patient · right' },
    specialty: 'General practice', region: DEFAULT_BATCH_REGION, locale: '', diarization: 'channel', isDemo: true,
    utterances: [
      turn('n1', 'L', 1, 9, [['fi', 'Hyvää päivää. Käymme tänään läpi viime käynnin jälkeen tekemiänne muistiinpanoja.'], ['sv', 'Hur har ni mått sedan vi sågs senast?']]),
      turn('n2', 'R', 10, 18, [['sv', 'God dag. Jag har känt mig trött på eftermiddagarna, och ibland har jag varit yr.'], ['fi', 'Kirjoitin muistiin, milloin huimausta esiintyy.']]),
      turn('n3', 'L', 19, 27, [['fi', 'Kiitos muistiinpanoista. Voitteko kuvailla huimausta tarkemmin? Milloin huomasitte sen ensimmäisen kerran, ja mitä olitte silloin tekemässä?']]),
      turn('n4', 'R', 28, 37, [['sv', 'Jag märkte det första gången för ungefär två veckor sedan. Det händer inte varje dag.'], ['fi', 'Olen merkinnyt muistiin myös unen määrän.']]),
      turn('n5', 'L', 38, 47, [['sv', 'Vi kan gå igenom anteckningarna tillsammans. Har ni några frågor om blodproverna från förra besöket eller om texten i journalen?']]),
      turn('n6', 'R', 48, 57, [['fi', 'Kyllä, minulla on kysymyksiä verikokeiden tuloksista. Haluaisin ymmärtää, mitä tässä lausunnossa lukee.'], ['sv', 'Kan vi titta på det tillsammans?']]),
      turn('n7', 'L', 58, 67, [['fi', 'Totta kai. Voimme käydä lausunnon läpi ja kirjata kysymyksenne.'], ['sv', 'Finns det några andra symtom som ni vill beskriva i dag?']]),
      turn('n8', 'R', 68, 77, [['sv', 'Det är allt just nu. Det känns bra att kunna använda båda språken under besöket.'], ['fi', 'Kiitos, että saan kertoa rauhassa omista oireistani.']]),
    ],
  },
  {
    id: 'polish-follow-up', title: 'Cardiology follow-up', subtitle: 'Polish ↔ English',
    description: 'A fictional bilingual follow-up about reported palpitations, a medication list, and questions about an earlier ECG report.',
    duration: 82, languages: ['pl', 'en'], speakerNames: { S1: 'Dr. Morgan', S2: 'Patient' },
    specialty: 'Cardiology', region: DEFAULT_BATCH_REGION, locale: 'en-GB', diarization: 'speaker', isDemo: true,
    utterances: [
      turn('p1', 'S1', 1, 10, [['en', 'Good afternoon. We are reviewing your cardiology appointment notes today. How have you been feeling since your last visit?']]),
      turn('p2', 'S2', 11, 21, [['pl', 'Dzień dobry. Czasami czuję kołatanie serca, szczególnie wieczorem. Zapisuję, kiedy to się zdarza.'], ['en', 'I brought those notes with me today.']]),
      turn('p3', 'S1', 22, 31, [['en', 'Thank you. We can look at those notes alongside your ECG report. Is the medication list in your record still accurate?']]),
      turn('p4', 'S2', 32, 42, [['en', 'The list is the same as at my last visit.'], ['pl', 'Mam też zapisane pomiary ciśnienia. Chciałbym zapytać o wyniki wcześniejszego badania.']]),
      turn('p5', 'S1', 43, 53, [['en', 'We can go through your questions together. Could you describe the palpitations and what you were doing when you noticed them?']]),
      turn('p6', 'S2', 54, 63, [['pl', 'Zwykle zauważam je, kiedy odpoczywam wieczorem. Mam wrażenie, że serce bije szybciej.'], ['en', 'I wrote down how long it lasted.']]),
      turn('p7', 'S1', 64, 73, [['en', 'Your notes help us understand the symptoms you described. Which part of the ECG report would you like to discuss first?']]),
      turn('p8', 'S2', 74, 81, [['pl', 'Chciałbym zacząć od tego zdania w opisie. Łatwiej mi opowiedzieć o objawach po polsku.'], ['en', 'Thank you for giving me time to explain.']]),
    ],
  },
];
