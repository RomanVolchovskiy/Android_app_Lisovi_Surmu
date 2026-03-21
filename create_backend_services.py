import os
import sys
import json
from datetime import datetime

# Add the firebase-admin path to sys.path
sys.path.append('/home/user/.local/lib/python3.12/site-packages')

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    print("✅ firebase-admin imported successfully")
except ImportError as e:
    print(f"❌ Failed to import firebase-admin: {e}")
    print("📦 INSTALLATION REQUIRED:")
    print("pip install firebase-admin==7.1.0")
    print("💡 This package is required for Firebase operations.")
    exit(1)

# Use the Firebase Admin SDK file
firebase_config_path = "/opt/flutter/firebase-admin-sdk.json"

if not os.path.exists(firebase_config_path):
    print(f"❌ Firebase Admin SDK file not found at {firebase_config_path}")
    print("Please upload the Firebase Admin SDK configuration file first.")
    exit(1)

# Initialize Firebase Admin SDK
cred = credentials.Certificate(firebase_config_path)
firebase_admin.initialize_app(cred)

db = firestore.client()

def create_hunting_signals_collection():
    """Create hunting signals collection with sample data"""
    print("🎯 Creating hunting signals collection...")
    
    signals_collection = db.collection('signals')
    
    # Sample hunting signals data
    sample_signals = [
        {
            'id': 'signal_001',
            'name': 'Сигнал збору',
            'description': 'Сигнал для збору мисливців перед початком полювання',
            'category': 'Інформаційні',
            'audioUrl': 'https://example.com/signals/gathering.mp3',
            'duration': 15,
            'historicalInfo': 'Традиційний сигнал, який використовується для збору мисливців перед початком полювання. Виконується на ріжку або мисливському ріжку.',
            'usageInstructions': 'Виконувати за 15-30 хвилин до початку полювання. Сигнал повинен бути чутний на відстані до 1 км.',
            'tags': ['збір', 'інформаційний', 'традиція'],
            'isFavorite': False,
            'videoUrl': None,
            'notationUrl': None,
            'imageUrl': None,
            'createdAt': datetime.now()
        },
        {
            'id': 'signal_002',
            'name': 'Сигнал початку',
            'description': 'Сигнал для початку мисливського заходу',
            'category': 'Організаційні',
            'audioUrl': 'https://example.com/signals/start.mp3',
            'duration': 12,
            'historicalInfo': 'Сигнал, який означає офіційний початок мисливського заходу.',
            'usageInstructions': 'Виконувати в точно визначений час початку полювання.',
            'tags': ['початок', 'організаційний', 'час'],
            'isFavorite': False,
            'videoUrl': None,
            'notationUrl': None,
            'imageUrl': None,
            'createdAt': datetime.now()
        },
        {
            'id': 'signal_003',
            'name': 'Сигнал покоту',
            'description': 'Сигнал для початку полювання з гончими',
            'category': 'Сигнали покоту',
            'audioUrl': 'https://example.com/signals/hunt.mp3',
            'duration': 20,
            'historicalInfo': 'Спеціальний сигнал для полювання з гончими собаками.',
            'usageInstructions': 'Виконувати при випуску гончих собак на слід.',
            'tags': ['покіт', 'гончий', 'собаки'],
            'isFavorite': False,
            'videoUrl': None,
            'notationUrl': None,
            'imageUrl': None,
            'createdAt': datetime.now()
        },
        {
            'id': 'signal_004',
            'name': 'Святковий марш',
            'description': 'Сигнал для святкових мисливських подій',
            'category': 'Святкові',
            'audioUrl': 'https://example.com/signals/celebration.mp3',
            'duration': 25,
            'historicalInfo': 'Святковий марш, який виконується на мисливських святах і урочистих подіях.',
            'usageInstructions': 'Виконувати на святкових заходах, урочистих відкриттях сезону.',
            'tags': ['свято', 'марш', 'урочистість'],
            'isFavorite': False,
            'videoUrl': None,
            'notationUrl': None,
            'imageUrl': None,
            'createdAt': datetime.now()
        },
        {
            'id': 'signal_005',
            'name': 'Довільна мелодія',
            'description': 'Сигнал для вільного виконання',
            'category': 'Довільна програма',
            'audioUrl': 'https://example.com/signals/custom.mp3',
            'duration': 18,
            'historicalInfo': 'Сигнал для демонстрації майстерності виконання.',
            'usageInstructions': 'Виконувати на конкурсах, виступах, для практики.',
            'tags': ['довільна', 'практика', 'майстерність'],
            'isFavorite': False,
            'videoUrl': None,
            'notationUrl': None,
            'imageUrl': None,
            'createdAt': datetime.now()
        }
    ]
    
    # Add each signal to Firestore
    for signal in sample_signals:
        try:
            doc_ref = signals_collection.document(signal['id'])
            doc_ref.set(signal)
            print(f"✅ Added signal: {signal['name']}")
        except Exception as e:
            print(f"❌ Error adding signal {signal['name']}: {e}")

    print(f"✅ Hunting signals collection created with {len(sample_signals)} signals")

def create_education_materials_collection():
    """Create education materials collection with sample data"""
    print("🎯 Creating education materials collection...")
    
    education_collection = db.collection('education_materials')
    
    # Sample education materials
    sample_materials = [
        {
            'id': 'edu_001',
            'title': 'Як читати мисливські ноти',
            'description': 'Повний посібник з читання мисливських нот',
            'type': 'article',
            'content': '''
Мисливські ноти мають свої особливості compared to стандартній нотній грамоті.

Основні правила:
1. Ритмічна структура - мисливські сигнали мають чітку ритмічну організацію
2. Динаміка - важливо дотримуватись динамічних позначень
3. Артикуляція - правильне відтворення артикуляційних позначень

Приклади найпростіших сигналів:
- Сигнал збору: проста послідовність нот з чітким ритмом
- Сигнал початку: більш складна ритмічна структура

Практичні поради:
- Починайте з простих сигналів
- Звертайте увагу на ритм
- Використовуйте метроном для тренування
            ''',
            'category': 'Нотна грамота',
            'difficulty': 'beginner',
            'tags': ['ноти', 'грамота', 'основи'],
            'videoUrl': None,
            'imageUrl': None,
            'createdAt': datetime.now()
        },
        {
            'id': 'edu_002',
            'title': 'Основи мисливської сигнальної музики',
            'description': 'Вступ до мисливської сигнальної музики',
            'type': 'video',
            'content': 'Відео урок про основи мисливської сигнальної музики...',
            'category': 'Теорія',
            'difficulty': 'beginner',
            'tags': ['теорія', 'основи', 'сигнали'],
            'videoUrl': 'assets/video/basic_signals.mp4',
            'imageUrl': None,
            'createdAt': datetime.now()
        },
        {
            'id': 'edu_003',
            'title': 'Історія мисливської сигнальної музики',
            'description': 'Історичний розвиток мисливської сигнальної музики',
            'type': 'article',
            'content': '''
Мисливська сигнальна музика має багатовікову історію.

Середньовіччя:
- Перші згадки про мисливські сигнали
- Використання ріжків для спілкування

XVII-XVIII століття:
- Розквіт мисливської музики
- Створення перших збірників сигналів

Сучасність:
- Збереження традицій
- Осучаснення репертуару
            ''',
            'category': 'Історія',
            'difficulty': 'intermediate',
            'tags': ['історія', 'розвиток', 'традиції'],
            'videoUrl': None,
            'imageUrl': None,
            'createdAt': datetime.now()
        },
        {
            'id': 'edu_004',
            'title': 'Практичні вправи для початківців',
            'description': 'Практичні вправи для вивчення основних сигналів',
            'type': 'exercise',
            'content': '''
Вправа 1: Ритмічні паузи
- Вправи на утримання звуку
- Вправи на паузи різної тривалості

Вправа 2: Прості мелодії
- Сигнал збору (повільно)
- Сигнал початку (середній темп)

Вправа 3: Динамічні зміни
- Плавні зміни гучності
- Різкі акценти
            ''',
            'category': 'Практика',
            'difficulty': 'beginner',
            'tags': ['практика', 'вправи', 'початківці'],
            'videoUrl': None,
            'imageUrl': None,
            'createdAt': datetime.now()
        }
    ]
    
    # Add each material to Firestore
    for material in sample_materials:
        try:
            doc_ref = education_collection.document(material['id'])
            doc_ref.set(material)
            print(f"✅ Added education material: {material['title']}")
        except Exception as e:
            print(f"❌ Error adding education material {material['title']}: {e}")

    print(f"✅ Education materials collection created with {len(sample_materials)} materials")

def create_categories_collection():
    """Create categories collection with default categories"""
    print("🎯 Creating categories collection...")
    
    categories_collection = db.collection('categories')
    
    # Default categories
    default_categories = [
        {
            'id': '1',
            'name': 'Інформаційні',
            'description': 'Сигнали для передачі інформації',
            'iconName': 'info',
            'color': 0xFF2196F3
        },
        {
            'id': '2',
            'name': 'Організаційні',
            'description': 'Сигнали для організації полювання',
            'iconName': 'organization',
            'color': 0xFF4CAF50
        },
        {
            'id': '3',
            'name': 'Сигнали покоту',
            'description': 'Сигнали для полювання з гончими',
            'iconName': 'pets',
            'color': 0xFFFF9800
        },
        {
            'id': '4',
            'name': 'Святкові',
            'description': 'Сигнали для святкових подій',
            'iconName': 'celebration',
            'color': 0xFF9C27B0
        },
        {
            'id': '5',
            'name': 'Довільна програма',
            'description': 'Сигнали для вільного виконання',
            'iconName': 'custom',
            'color': 0xFF00BCD4
        }
    ]
    
    # Add each category to Firestore
    for category in default_categories:
        try:
            doc_ref = categories_collection.document(category['id'])
            doc_ref.set(category)
            print(f"✅ Added category: {category['name']}")
        except Exception as e:
            print(f"❌ Error adding category {category['name']}: {e}")

    print(f"✅ Categories collection created with {len(default_categories)} categories")

def main():
    print("🚀 Starting Firebase backend service creation...")
    
    try:
        # Create collections
        create_categories_collection()
        create_hunting_signals_collection()
        create_education_materials_collection()
        
        print("✅ All Firebase collections created successfully!")
        print("\n📝 Next steps for your Flutter app:")
        print("1. Update your HuntingDataService to use FirestoreService")
        print("2. Test the Firebase integration")
        print("3. Verify data synchronization between admin panel and user app")
        
    except Exception as e:
        print(f"❌ Error creating backend services: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit_code = main()
    exit(exit_code)