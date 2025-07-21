# 📄 Техническое задание: RAG-система для работы с техническими, научными и нормативными документами

> **Цель:**  
Создать локальную Retrieval-Augmented Generation (RAG) систему, которая позволяет пользователям задавать вопросы по внутренним документам и получать точные, обоснованные ответы на основе этих документов.  
Все компоненты системы должны быть локальными — **без облака**, без внешних API.

---

## 🧩 Общая архитектура системы

```
[Пользовательский запрос]
        ↓
[Классификация запроса] → [Выбор стратегии ответа]
        ↓
[Поиск в базе знаний (RAG)]
        ↓
[Переранжирование результатов]
        ↓
[Генерация / резюмирование ответа]
        ↓
[Финальный ответ пользователю]
```

---

## 🔧 Основные модули системы

| Модуль | Отвечает за |
|--------|--------------|
| `QueryClassifier` | Классификация типа запроса (фактический поиск, мнение, рассуждение и т.п.) |
| `DocumentLoader` | Загрузка и парсинг различных форматов (PDF, DOCX, XLSX, TXT, JSON) |
| `Chunker` | Разбиение текста на фрагменты с учетом типа документа |
| `Embedder` | Векторизация фрагментов текста |
| `VectorDBManager` | Работа с векторной БД (FAISS, Chroma и др.) |
| `Retriever` | Поиск похожих фрагментов |
| `Reranker` | Переранжирование найденных фрагментов |
| `AnswerGenerator` | Генерация ответа с использованием LLM |
| `Summarizer` | Сокращение длинных фрагментов или ответов |
| `ResponseController` | Управление форматом и источниками ответа |

---

## 📁 Структура проекта

```
rag_system/
│
├── config/
│   ├── models.yaml           # Настройки моделей (классификаторы, эмбеддинги, LLM)
│   ├── vector_db.yaml        # Конфиги для векторной БД
│   └── document_types.yaml   # Типы документов и параметры чанкинга/эмбеддингов
│
├── core/
│   ├── classifier.py         # Классификация запроса
│   ├── chunker.py            # Разбиение на фрагменты
│   ├── embedder.py           # Векторизация
│   ├── retriever.py          # Поиск
│   ├── reranker.py           # Переранжирование
│   ├── generator.py          # Генерация ответа
│   └── response_controller.py # Управление ответом
│
├── parsers/
│   ├── pdf_parser.py
│   ├── docx_parser.py
│   └── html_parser.py
│
├── storage/
│   ├── vector_db_manager.py
│   └── document_db_manager.py
│
├── utils/
│   ├── logging.py
│   └── file_utils.py
│
└── main.py
```

---

## 🧪 Функциональные требования

### 1. **Поддержка типов документов**
Система должна уметь работать со следующими типами:
- Научные статьи
- Технические задания
- Приказы
- Служебные записки
- Карточки материалов
- Нормативные документы

Каждый тип может иметь свой способ чанкинга, модель эмбеддинга и метрику сравнения.

---

### 2. **Модульная структура**

#### Динамическая загрузка конфигов:

```yaml
# config/document_types.yaml
document_types:
  scientific_paper:
    chunker: semantic
    embedding_model: sbert_large_nlu_ru
    metric: cosine
    reranker: cross_encoder
    summarizer: rugpt3small_sum

  technical_spec:
    chunker: fixed_length
    embedding_model: all-MiniLM-L6-v2
    metric: l2
    reranker: none
    summarizer: none

  order:
    chunker: structural
    embedding_model: DeepPavlov/RuBERT
    metric: dot_product
    reranker: cross_encoder
    summarizer: rugpt3small_sum
```

Такой подход позволяет **не переписывать код при добавлении новых типов документов**.

---

### 3. **Парсинг и подготовка документов**

#### Поддерживаемые форматы:
- PDF (через `PyMuPDF`, `pdfplumber`)
- DOCX (`python-docx`)
- XLSX (`pandas`)
- HTML (`BeautifulSoup`)
- TXT (`open()`)
- JSON (`json`)

#### Пример интерфейса парсера:

```python
class DocumentParser:
    def parse(self, file_path):
        raise NotImplementedError()

class PDFParser(DocumentParser):
    def parse(self, file_path):
        # Реализация через PyMuPDF
        ...

class DocxParser(DocumentParser):
    def parse(self, file_path):
        # Реализация через python-docx
        ...
```

---

### 4. **Чанкер**

Разбиение должно зависеть от типа документа:

| Тип документа | Метод разбиения |
|----------------|------------------|
| Научная статья | Семантический |
| Приказ | По заголовкам |
| Техническое задание | Фиксированный размер |
| Карточки материалов | По полям таблицы |
| Нормативный документ | По пунктам / подзаголовкам |

Пример:

```python
class ChunkerFactory:
    @staticmethod
    def get_chunker(doc_type):
        if doc_type == "scientific":
            return SemanticChunker()
        elif doc_type == "spec":
            return FixedLengthChunker(max_tokens=512)
        elif doc_type == "order":
            return StructuralChunker()
```

---

### 5. **Эмбеддинг модели**

#### Поддерживаемые модели:
| Язык | Рекомендации |
|------|---------------|
| Русский | `sbert_large_nlu_ru`, `DeepPavlov/RuBERT` |
| Английский | `all-MiniLM-L6-v2`, `BGE`, `text-embedding-ada-002` |
| Домены | `BioBERT`, `CodeBERT`, `Legal-BERT` |

#### Пример конфига:

```yaml
# config/models.yaml
models:
  embeddings:
    sbert_large_nlu_ru:
      model_name: "sbert_large_nlu_ru"
      dimension: 768
      normalize: true
      metric: cosine
```

---

### 6. **Хранение векторов**

#### Поддерживаемые векторные БД:

| База | Плюсы | Минусы |
|-------|--------|--------|
| FAISS | ⚡ Очень быстро, Python-friendly | ❌ Не масштабируется |
| Chroma | ✅ Простота использования | ❌ Не очень масштабируется |
| Milvus | ✅ Производительность, кластеризация | ❌ Сложная установка |
| Weaviate | ✅ Масштабируемость, REST API | ❌ Сложнее в развёртке |

#### Пример конфига:

```yaml
# config/vector_db.yaml
vector_dbs:
  faiss:
    type: flat
    index_type: IndexFlatL2
    distance_metric: l2
    description: "Локальная, быстрая, Python-friendly"

  chroma:
    type: local
    persist_directory: "./chroma_db"
    description: "Простая, но не масштабируется"
```

---

### 7. **Поиск и переранжирование**

#### Поиск:
- Векторный поиск (`ANN`)
- BM25 (через `RankBM25` или `Elasticsearch`)
- Гибридный поиск (`BM25 + ANN`)

#### Переранжирование:
- `cross-encoder/ms-marco-MiniLM-L-6-v2` (быстро, бесплатно)
- GPT / Llama3 (локально)
- T5 / BART (для суммаризации)

---

### 8. **Генерация и суммаризация**

#### Локальные модели:
- Llama3, Mixtral, Qwen, Gemma, Mistral
- Sber AI Studio (локальный запуск)
- T5, BART, RuGPT3 — для резюмирования

#### Пример:

```python
from transformers import pipeline

summarizer = pipeline("summarization", model="sberbank-ai/rugpt3small_sum")
```

---

## 📊 Архитектурные особенности

| Особенность | Описание |
|------------|----------|
| **ООП и фабрики** | Использовать классы и фабрики для гибкости |
| **Конфигурации** | Все настройки вынести в YAML/JSON |
| **Метаданные** | Хранить информацию о типе документа, дате, авторе |
| **Модульность** | Каждый этап — отдельный модуль |
| **Поддержка расширений** | Возможность добавления новых типов документов и моделей без изменения основного кода |
| **Логирование и мониторинг** | Логировать запросы, время выполнения, источники ответа |

---

## 🤖 Интеграция LLM

LLM интегрируется через `transformers` или `vLLM`.  
Пример:

```python
from transformers import AutoTokenizer, AutoModelForCausalLM

tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen2-7B-Instruct")
model = AutoModelForCausalLM.from_pretrained("Qwen/Qwen2-7B-Instruct")

def generate_answer(context, query):
    prompt = f"""
Ты — помощник, который использует только предоставленные данные.
Используй следующую информацию:
{context}

Запрос: {query}
Ответ:
"""
    inputs = tokenizer(prompt, return_tensors="pt").to("cuda")
    outputs = model.generate(**inputs, max_new_tokens=512)
    answer = tokenizer.decode(outputs[0], skip_special_tokens=True)
    return answer
```

---

## 🔄 Гибридный поиск (BM25 + ANN)

```python
from rank_bm25 import BM25Okapi

bm25 = BM25Okapi([doc.split() for doc in documents])
bm25_scores = bm25.get_scores(query.split())

faiss_scores = ...  # из FAISS

final_scores = bm25_scores * 0.3 + faiss_scores * 0.7
```

---

## 📦 Метаданные документа

Каждый документ должен содержать:

```json
{
  "id": "doc-123",
  "type": "technical_spec",
  "title": "Техническое задание №456",
  "source": "internal_db",
  "date": "2024-04-05",
  "tags": ["проект", "материалы"],
  "content": "...",
  "embedding_model": "all-MiniLM-L6-v2"
}
```

---

## 🧠 Классификация запросов

### Пример реализации:

```python
from transformers import pipeline

class QueryClassifier:
    def __init__(self):
        self.classifier = pipeline("zero-shot-classification", model="facebook/bart-large-mnli")
        self.labels = ["фактический_поиск", "мнение", "резюмирование", "интерпретация_документа", "генерация_документа"]

    def classify(self, query):
        result = self.classifier(query, candidate_labels=self.labels)
        return result["labels"][0], result["scores"][0]
```

---

## 📦 Версионность и обновления

- Каждый документ хранится с версией
- При поиске можно указать диапазон дат или конкретную версию
- Можно сравнивать версии: «Как изменился ГОСТ с прошлого года?»

---

## 🧩 Расширяемость и поддержка новых функций

- Добавление новых типов документов через `document_types.yaml`
- Выбор модели через `models.yaml`
- Автоматическое определение метода чанкинга через конфиг
- Поддержка новых метрик и ранжировщиков

---

## 🧪 Тестирование и улучшение качества

- A/B-тестирование разных моделей эмбеддингов
- Логирование кликов и выбора пользователем лучшего ответа
- Автоматические тесты на семантическую близость
- Feedback loop: пользователь может отметить лучший ответ

---

## 📁 Предлагаемая структура каталога для документов

```
/documents
    /scientific_papers/
    /tech_specs/
    /orders/
    /material_cards/
```

---

## 🧭 Микросервисный подход?

✅ Да, можно сделать микросервисно:

| Сервис | Описание |
|--------|----------|
| `parser-service` | Парсинг документов |
| `chunking-service` | Разбиение на фрагменты |
| `embedding-service` | Векторизация |
| `retrieval-service` | Поиск |
| `reranking-service` | Переранжирование |
| `generation-service` | Генерация ответа |

💡 Это повысит отказоустойчивость и позволит масштабировать каждый компонент отдельно.

---

## 🧩 Дополнительные идеи

- **Сравнение версий документов**
- **Автоматическое создание аннотаций**
- **Извлечение требовой информации из ТЗ**
- **Автоматическое заполнение шаблонов (например, актов, протоколов)**

---

## 🧪 Как проверять качество?

| Метрика | Описание |
|---------|----------|
| Precision@K | Сколько из top-K результатов действительно релевантны |
| MRR | Mean Reciprocal Rank — как рано находится правильный ответ |
| ROUGE / BLEU | Для оценки качества генерации |
| MAP@K | Средняя точность по K документам |

---

## 📝 Пример CLI команды

```bash
rag-cli index --dir ./documents/scientific --type scientific_paper
rag-cli query "Какова температура сварки стали?" --top_k 3 --rerank True
```

---

## 📁 Конфигурационный файл `config/models.yaml`

```yaml
models:
  embeddings:
    all-MiniLM-L6-v2:
      name: "sentence-transformers/all-MiniLM-L6-v2"
      language: en
      dimension: 384
      normalize: true
      metric: cosine
      description: "Быстрый и универсальный"

    sbert_large_nlu_ru:
      name: "sbert_large_nlu_ru"
      language: ru
      dimension: 768
      normalize: true
      metric: cosine
      description: "Для русского языка"

    rubert-base-cased-syntheseda:
      name: "cointegrated/rubert-base-cased-nli-mean-tokens"
      language: ru
      dimension: 768
      normalize: true
      metric: cosine
      description: "Для юридических и нормативных документов"
```

---

## 📁 Конфигурационный файл `config/vector_db.yaml`

```yaml
vector_dbs:
  faiss:
    type: flat
    index_type: IndexFlatIP
    metric: dot_product
    description: "Подходит для нормализованных векторов"
    params:
      dimension: 768

  chroma:
    type: local
    path: "./chroma_db"
    description: "Удобно для тестирования"
```

---

## 📁 Конфигурационный файл `config/document_types.yaml`

```yaml
document_types:
  scientific_paper:
    chunker: semantic
    embedding_model: sbert_large_nlu_ru
    vector_db: faiss
    reranker: cross_encoder
    summarizer: rugpt3small_sum

  technical_spec:
    chunker: fixed_length
    embedding_model: all-MiniLM-L6-v2
    vector_db: faiss
    reranker: none
    summarizer: none

  material_card:
    chunker: by_fields
    embedding_model: DeepPavlov/RuBERT
    vector_db: chroma
    reranker: cross_encoder
    summarizer: rugpt3small_sum
```

---

## 📋 Подсказка по конфигам

### 📂 `models.yaml`

- `name`: имя модели в HuggingFace
- `language`: язык
- `dimension`: размер вектора
- `normalize`: нужно ли нормализовать векторы
- `metric`: рекомендуемая метрика
- `description`: описание и область применения

---

### 📂 `vector_db.yaml`

- `type`: тип БД (flat, ivf, hnsw и т.д.)
- `path`: путь для сохранения
- `metric`: рекомендуемая метрика
- `description`: преимущества и ограничения

---

### 📂 `document_types.yaml`

- `chunker`: тип чанкера
- `embedding_model`: модель эмбеддинга
- `vector_db`: рекомендуемая векторная БД
- `reranker`: модель переранжирования
- `summarizer`: модель резюмирования

---

## 📌 Что зависит от чего?

| Элемент | Зависимость |
|--------|-------------|
| Чанкер | От типа документа |
| Эмбеддинг | От языка и домена |
| Векторная БД | От количества данных и скорости |
| Переранжер | От типа запроса |
| Генератор | От языка, сложности ответа |
| Суммаризатор | От длины контекста и языка |

---

## 🛠 Следующие шаги

1. **Создание MVP системы**  
   - Парсер документов
   - Чанкер
   - Эмбеддинг
   - FAISS
   - Генератор

2. **Добавление классификации и управления ответом**

3. **Добавление переранжирования и гибридного поиска**

4. **Интеграция всех типов документов**

5. **Создание CLI и Web UI (FastAPI + Gradio)**

6. **Тестирование и оптимизация**

---

## 🧾 Финальная цель

Создать **гибкую, локальную, масштабируемую систему**, которая:
- Понимает типы документов
- Знает, как их обрабатывать
- Может отвечать на сложные запросы
- Умеет объяснять, где взят ответ
- Поддерживает обновления и новые типы документов

---

## 📄 Требования к окружению

- Python 3.10+
- CUDA (опционально)
- Доступ к HuggingFace (или локальные модели)

---

## 📌 Что будет в MVP

- Загрузка PDF/DOCX/TXT
- Разбиение на фрагменты
- Векторизация через SBERT
- Поиск через FAISS
- Генерация через Qwen / Llama3
- Пример CLI команд
