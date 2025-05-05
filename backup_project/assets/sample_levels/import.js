const admin = require('firebase-admin');
const fs = require('fs');

// Замените на имя вашего JSON-файла и нужный id документа
const jsonFile = 'level_001.json';
const docId = '1'; // id документа в коллекции levels

// Инициализация Firebase Admin SDK
const serviceAccount = require('./qazcros-firebase-adminsdk-fbsvc-13e34134fa.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

// Чтение и парсинг JSON-файла
let level;
try {
  level = JSON.parse(fs.readFileSync(jsonFile, 'utf8'));
} catch (err) {
  console.error('Ошибка чтения или парсинга JSON:', err);
  process.exit(1);
}

// Импорт в Firestore
db.collection('levels').doc(docId).set(level)
  .then(() => {
    console.log(`Уровень из файла ${jsonFile} успешно загружен в Firestore с id ${docId}!`);
    process.exit(0);
  })
  .catch((error) => {
    console.error('Ошибка загрузки в Firestore:', error);
    process.exit(1);
  });